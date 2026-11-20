extends SceneTree

const DAYLIGHT := 0.38
const DUSK := 0.67
const NIGHT := 0.95

var state: Node
var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		push_error("Run the snow light check with an isolated profile.")
		quit(1)
		return
	paused = true
	state = root.get_node("Global")
	var light := _day("小雪")
	var heavy := _day("大雪")
	var clear := _day("冬至")
	var rain := _day(state.balance.rain_solar_term)
	var views := {
		state.ESTATE_SCENE: "World/Landscape/DayLighting",
		state.WILDERNESS_SCENE: "Landscape/DayLighting",
		state.WEST_ROAD_SCENE: "DayLighting",
		state.WEST_MARKET_SCENE: "DayLighting",
	}
	for path: String in views:
		state.estate_room = state.EstateRoom.OUTDOORS
		state.current_day = light
		state.day_progress = DAYLIGHT
		if not await _open(path):
			quit(1)
			return
		var lighting := current_scene.get_node(views[path]) as CanvasModulate
		var first := _outdoor_sample(lighting, light, DAYLIGHT)
		var dense := _outdoor_sample(lighting, heavy, DAYLIGHT)
		var sunny := _outdoor_sample(lighting, clear, DAYLIGHT)
		var wet := _outdoor_sample(lighting, rain, DAYLIGHT)
		_expect(not first.cloud and not dense.cloud and first.sky.r > dense.sky.r + 0.06
			and first.sky.b > first.sky.r + 0.04 and dense.sky.b > dense.sky.r + 0.07
			and dense.sky.r >= 0.78 and not dense.lamp and not first.lamp,
			"Snow uses brighter or deeper diffuse light by density in " + path)
		_expect(sunny.cloud and sunny.sky == Color.WHITE and not wet.cloud and wet.sky == Color("#ccdbe0"),
			"The clear and rain palettes still match their conditions in " + path)
		var early_light := _outdoor_sample(lighting, light, DUSK)
		var early_heavy := _outdoor_sample(lighting, heavy, DUSK)
		var early_clear := _outdoor_sample(lighting, clear, DUSK)
		_expect(early_heavy.lamp and early_heavy.energy > early_light.energy + 0.08
			and early_heavy.last_energy > 0.08 and early_light.lamp and not early_clear.lamp,
			"Snowy dusk lights the route lanterns before the clear evening in " + path)
		var snowy_night := _outdoor_sample(lighting, heavy, NIGHT)
		var clear_night := _outdoor_sample(lighting, clear, NIGHT)
		_expect(snowy_night.sky == clear_night.sky and snowy_night.energy == clear_night.energy
			and snowy_night.energy > 0.55 and not snowy_night.cloud,
			"Snow shares the same night color and warm lanterns in " + path)

	state.silk_workshop.built = true
	for room: Array in [[state.EstateRoom.HALL, "HallInterior"], [state.EstateRoom.SILK_SHED, "SilkInterior"]]:
		state.estate_room = room[0]
		state.current_day = light
		state.day_progress = DAYLIGHT
		if not await _open(state.ESTATE_SCENE):
			quit(1)
			return
		var interior := current_scene.get_node("World/" + room[1]) as Node2D
		var ambient := current_scene.get_node("World/Landscape/DayLighting") as CanvasModulate
		_expect(interior.visible and root.get_camera_2d() == interior.room_camera, "Mount " + room[1])
		var light_sample := _room_sample(interior, ambient, light, DAYLIGHT)
		var heavy_sample := _room_sample(interior, ambient, heavy, DAYLIGHT)
		var clear_sample := _room_sample(interior, ambient, clear, DAYLIGHT)
		var rain_sample := _room_sample(interior, ambient, rain, DAYLIGHT)
		_expect(light_sample.beam == 0.0 and heavy_sample.beam == 0.0
			and light_sample.fill > heavy_sample.fill and heavy_sample.fill > 0.20
			and light_sample.sky.r > heavy_sample.sky.r and heavy_sample.sky.b > heavy_sample.sky.r
			and heavy_sample.lamp > light_sample.lamp + 0.06,
			"Snow leaves cool window fill and a warmer lamp in " + room[1])
		_expect(clear_sample.beam > 0.9 and rain_sample.beam == 0.0 and is_equal_approx(rain_sample.fill, 0.26),
			"The window responds to clear weather and rain in " + room[1])
		var dark := _room_sample(interior, ambient, heavy, NIGHT)
		_expect(dark.beam == 0.0 and dark.fill < 0.05 and dark.lamp > 0.80,
			"Oil light lights the work surface at night in " + room[1])
	_expect(paused and state.saved_games().is_empty(), "The lighting fixtures write no campaign saves.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _open(path: String) -> bool:
	if change_scene_to_file(path) != OK:
		_expect(false, "Mount the static light fixture " + path)
		return false
	await scene_changed
	current_scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	await process_frame
	return true

func _outdoor_sample(lighting: CanvasModulate, day: int, time: float) -> Dictionary:
	state.current_day = day
	state.day_progress = time
	lighting.refresh()
	var strongest := 0.0
	var latest := 1.0
	for lantern: Node2D in lighting.lamps:
		if lantern.is_visible_in_tree():
			strongest = maxf(strongest, lantern.glow.energy)
			latest = minf(latest, lantern.glow.energy)
	return {"sky": lighting.color, "cloud": lighting.get_node("CloudShadow").visible,
		"lamp": strongest > 0.005, "energy": strongest, "last_energy": latest}

func _room_sample(room: Node2D, ambient: CanvasModulate, day: int, time: float) -> Dictionary:
	state.current_day = day
	state.day_progress = time
	ambient.refresh()
	room._refresh_lighting()
	return {"sky": ambient.color, "beam": room.window_projection.get_shader_parameter("direct_light"),
		"fill": room.window_light.energy, "lamp": room.lamp.energy}

func _day(term: String) -> int:
	return state.SOLAR_TERMS.find(term) * state.balance.days_per_solar_term + 1

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
