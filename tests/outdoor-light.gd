extends SceneTree

const MORNING := 0.19
const AFTERNOON := 0.54
const EARLY_DUSK := 0.675
const NIGHT := 0.97

var tree: SceneTree
var state: Node
var capture_dir := ""
var baseline := false
var failed := false

func _initialize() -> void:
	_run.call_deferred(self)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _run(test_tree: SceneTree) -> void:
	tree = test_tree
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		push_error("Run outdoor-light only in an isolated smoke profile.")
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	var args := OS.get_cmdline_user_args()
	baseline = "baseline" in args
	if args.size() >= 2:
		capture_dir = args[1]
	tree.paused = true
	var rain_index: int = state.SOLAR_TERMS.find(state.balance.rain_solar_term)
	var clear_day: int = rain_index * state.balance.days_per_solar_term
	var rain_day := clear_day + 1
	_expect(not state.has_rain(clear_day) and state.has_rain(rain_day)
		and state.season_index(clear_day) == state.season_index(rain_day), "Use clear and rainy dates from the same season.")
	var views := [
		["estate", state.ESTATE_SCENE, Vector2(56, 74), "World/Landscape/DayLighting"],
		["ravine", state.WILDERNESS_SCENE, Vector2(165, 35), "Landscape/DayLighting"],
		["road", state.WEST_ROAD_SCENE, Vector2(-25, 33), "DayLighting"],
		["market", state.WEST_MARKET_SCENE, Vector2(78, 74), "DayLighting"],
	]
	var first: Dictionary = {}
	for view: Array in views:
		var dry := await _review(view, clear_day, false)
		var wet := await _review(view, rain_day, true)
		_expect(dry.foot == wet.foot and dry.camera == wet.camera and dry.zoom == wet.zoom,
			"Both weather fixtures use the same framing for " + view[0])
		if not baseline:
			_expect(wet.morning.r < dry.morning.r and wet.morning.b - wet.morning.r > 0.04
				and wet.dusk_lamps > dry.dusk_lamps and dry.night == wet.night,
				"Use a cooler daytime palette, warmer route landmarks in rainy dusk, and a common night value for " + view[0])
			if first.is_empty():
				first = {"dry": dry, "wet": wet}
			_expect(dry.morning == first.dry.morning and wet.morning == first.wet.morning
				and dry.phase == first.dry.phase,
				"Every outdoor map uses the same sky palette and cloud phase.")
		print("OUTDOOR_LIGHT_MAP ", view[0], " dry=", dry.morning.to_html(false), " wet=", wet.morning.to_html(false),
			" early_dusk_lamps=", dry.dusk_lamps, "/", wet.dusk_lamps, " night=", wet.night.to_html(false))
	if not baseline:
		await _check_rooms(views[0], clear_day)
	_expect(tree.paused and state.saved_games().is_empty(), "The visual check uses static outdoor and room fixtures.")
	print("OUTDOOR_LIGHT_REVIEW renderer=", RenderingServer.get_current_rendering_method(), " driver=",
		RenderingServer.get_current_rendering_driver_name(), " window=", tree.root.size, " baseline=", baseline)
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func _open(view: Array, day: int) -> CanvasModulate:
	state.current_day = day
	state.day_progress = MORNING
	state.estate_room = state.EstateRoom.OUTDOORS
	_expect(tree.change_scene_to_file(view[1]) == OK, "Mount " + view[0] + " with the fixed visual fixture.")
	await tree.scene_changed
	await tree.process_frame
	var actor: Node = tree.get_first_node_in_group("player")
	actor.arrive_at_position(view[2], Vector2.DOWN)
	await tree.process_frame
	return tree.current_scene.get_node(view[3]) as CanvasModulate

func _review(view: Array, day: int, wet: bool) -> Dictionary:
	var lighting := await _open(view, day)
	var sky := lighting.get_node_or_null("CloudShadow") as ColorRect
	var actor: Node = tree.get_first_node_in_group("player")
	var camera := tree.root.get_camera_2d()
	var record := {"foot": actor.global_position, "camera": camera.get_screen_center_position(), "zoom": camera.zoom}
	lighting.refresh()
	record.morning = lighting.color
	if not baseline:
		_expect(sky != null, "Each outdoor map installs the shared cloud shade.")
		if sky != null:
			_expect(sky.visible != wet and sky.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"Cloud shade belongs to clear daytime and allows pointer input.")
			record.phase = sky.material.get_shader_parameter("cloud_offset")
	await _capture(view[0] + ("-rain" if wet else "-sun-a"))
	if not wet:
		state.day_progress = AFTERNOON
		lighting.refresh()
		if not baseline and sky != null:
			_expect(lighting.color == record.morning and sky.visible
				and sky.material.get_shader_parameter("cloud_offset") != record.phase,
				"Cloud shade moves against the ground at a constant daylight color.")
		await _capture(view[0] + "-sun-b")
	state.day_progress = EARLY_DUSK
	lighting.refresh()
	var lamp_count := 0
	for lamp: Node2D in lighting.lamps:
		if lamp.visible and lamp.glow.enabled:
			lamp_count += 1
	record.dusk_lamps = lamp_count
	if wet:
		await _capture(view[0] + "-rain-dusk")
	state.day_progress = NIGHT
	lighting.refresh()
	record.night = lighting.color
	if not baseline and sky != null:
		_expect(not sky.visible and lighting.lamps[0].glow.energy > 0.55,
			"The cloud pass is hidden by night, with the first lantern at full strength.")
	return record

func _check_rooms(estate: Array, day: int) -> void:
	var lighting := await _open(estate, day)
	var sky := lighting.get_node("CloudShadow") as ColorRect
	var events := tree.root.get_node("GameEvents")
	for room: int in [state.EstateRoom.HALL, state.EstateRoom.SILK_SHED]:
		state.estate_room = room
		events.estate_room_changed.emit(room)
		_expect(not sky.visible and lighting.color == Color("#efe0c6"), "Room light comes from the existing indoor palette.")
	state.estate_room = state.EstateRoom.OUTDOORS
	events.estate_room_changed.emit(state.estate_room)
	_expect(sky.visible, "Clouds return as soon as the room state returns outdoors.")

func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Save " + name + " in the private review folder.")
