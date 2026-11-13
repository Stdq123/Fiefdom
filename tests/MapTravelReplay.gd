extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const PUBLIC := Vector2i(5, 5)

var tree: SceneTree
var state: Node
var travel: CanvasLayer
var capture_dir := ""
var rendered := false
var failures := 0
var scene_changes := 0

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		push_error(message)
	return condition

func _click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame

func _button(button: Button) -> void:
	await tree.process_frame
	if _expect(button != null and button.is_visible_in_tree() and not button.disabled, "Use a visible enabled button."):
		await _click(button.get_global_rect().get_center())
	await tree.process_frame

func _press_key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)

func _player(scene: Node) -> Player:
	var path := "World/Player" if scene.scene_file_path == state.ESTATE_SCENE else "Player"
	return scene.get_node(path)

func _film_frame(frames: Array[Image]) -> void:
	await RenderingServer.frame_post_draw
	frames.append(tree.root.get_texture().get_image())

func _write_film(frames: Array[Image], gate: String) -> void:
	if frames.is_empty():
		return
	var directory := capture_dir.path_join(gate)
	DirAccess.make_dir_recursive_absolute(directory)
	for index in frames.size():
		_expect(frames[index].save_png(directory.path_join("frame-%03d.png" % index)) == OK, "Save the actual gate frame.")
	print("MAP_TRAVEL_FILM gate=", gate, " frames=", frames.size(), " window=", tree.root.size, " image=", frames[0].get_size())

func _walk_into_gate(action: StringName) -> bool:
	Input.action_press(action)
	for frame in 90:
		if travel.active:
			return true
		await tree.physics_frame
	Input.action_release(action)
	return _expect(false, "Walking into the gate should start a map change.")

func _cross(action: StringName, gate: String, expected_path: String, marker_path: String) -> bool:
	var origin := tree.current_scene
	var actor := _player(origin)
	var old_changes := scene_changes
	var frames: Array[Image] = []
	var filming := rendered and not capture_dir.is_empty() and gate in ["east", "west"]
	if filming:
		await _film_frame(frames)
	if not await _walk_into_gate(action):
		return false
	var started := Time.get_ticks_msec()
	var left_at := actor.global_position
	var day: int = state.current_day
	var time_at_gate: float = state.day_progress
	var saw_close := false
	var saw_cover := false
	var saw_open := false
	var held_position := true
	var held_clock := true
	var blocked_map := true
	var camera_ready := false
	var first_destination: Node
	for frame in 150:
		await tree.process_frame
		var scene := tree.current_scene
		if not travel.active:
			break
		var opacity: float = travel.cover.color.a
		held_clock = held_clock and is_equal_approx(state.day_progress, time_at_gate)
		if scene == origin:
			held_position = held_position and actor.global_position.is_equal_approx(left_at)
			if opacity > 0.1 and opacity < 0.92 and not saw_close:
				saw_close = true
				_press_key(KEY_M)
				blocked_map = blocked_map and not tree.paused
		elif scene != null:
			var arriving := _player(scene)
			var marker := scene.get_node(marker_path) as Marker2D
			if first_destination == null:
				first_destination = scene
				saw_cover = opacity >= 0.999
				camera_ready = arriving.camera.is_current() and arriving.camera.zoom == Vector2.ONE * tree.root.get_node("Preferences").map_zoom \
					and tree.root.get_visible_rect().has_point(arriving.get_global_transform_with_canvas().origin)
			held_position = held_position and arriving.global_position.is_equal_approx(marker.global_position)
			if opacity > 0.1 and opacity < 0.92 and not saw_open:
				saw_open = true
				_press_key(KEY_M)
				blocked_map = blocked_map and not tree.paused
		if filming and frame % 2 == 0:
			await _film_frame(frames)
	var elapsed := Time.get_ticks_msec() - started
	if not _expect(not travel.active and not travel.cover.visible and tree.current_scene != null
			and tree.current_scene.scene_file_path == expected_path and scene_changes == old_changes + 1,
			"One physical crossing reveals exactly one destination."):
		Input.action_release(action)
		return false
	var target := tree.current_scene
	var landing := target.get_node(marker_path) as Marker2D
	var arrived := _player(target)
	var camera := arrived.camera
	_expect(saw_close and saw_cover and saw_open, "The source fades out before the destination appears and fades in.")
	_expect(held_clock and day == state.current_day, "Crossing leaves the date and in-day clock in place.")
	_expect(held_position and blocked_map, "Walking and map input stay locked while crossing.")
	_expect(camera_ready, "The arrival is in view at the selected zoom before the cover opens.")
	_expect(arrived.facing_row == Player.Facing.PROFILE and arrived.sprite.flip_h == (action == &"ui_left"),
		"The player faces down the destination path.")
	if rendered:
		_expect(elapsed >= 300 and elapsed < 950, "The reveal remains brief in the Windows runtime.")
	for frame in 9:
		await tree.physics_frame
	Input.action_release(action)
	await tree.process_frame
	var moved := arrived.global_position - landing.global_position
	var forward := Vector2.LEFT if action == &"ui_left" else Vector2.RIGHT
	_expect(moved.dot(forward) > 6.0 and scene_changes == old_changes + 1, "Holding direction walks inward after reveal without a second crossing.")
	if filming:
		await _film_frame(frames)
		_write_film(frames, gate)
	print("MAP_TRAVEL_CROSS gate=", gate, " wall_ms=", elapsed, " arrival=", landing.global_position,
		" zoom=", camera.zoom.x, " clock=", snappedf(time_at_gate, 0.001), " paused=", tree.paused)
	return true

func _save_from_settings() -> void:
	var ui := tree.current_scene.get_node("UI")
	await _button(ui.settings_button)
	var panel: Control = ui.panel_manager.settings_panel_instance
	for button: Button in panel.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	await _button(panel.find_child("Close", true, false))

func _verify_manual_save() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(state.manual_save_path()))
	_expect(data is Dictionary and data.get("selected_seed") == "beans", "The regular save records the chosen seed.")
	tree.paused = false
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	var world := tree.current_scene.get_node_or_null("World")
	_expect(world != null and world.current_seed_id == "beans" and state.active_crops[PUBLIC].watered,
		"Continue restores the selected seed and the previously watered field.")
	print("MAP_TRAVEL_SAVE seed=", state.selected_seed_id, " watered=", state.active_crops[PUBLIC].watered)
	if not rendered and data is Dictionary:
		data.erase("selected_seed")
		var path := "user://map-travel-legacy-fixture.json"
		var legacy := FileAccess.open(path, FileAccess.WRITE)
		legacy.store_string(JSON.stringify(data))
		legacy.close()
		if _expect(state.load_game(path) == OK, "An older save still loads without a seed field."):
			await tree.scene_changed
			_expect(state.selected_seed_id == "millet" and state.active_crops[PUBLIC].watered,
				"An old save falls back to millet and keeps its watered crop.")
			print("MAP_TRAVEL_LEGACY seed=", state.selected_seed_id)

func _retry_and_arrive_at_council() -> void:
	var estate := tree.current_scene
	var gate := estate.get_node("World/EastGate")
	var marker: NodePath = gate.arrival_path
	var change_count := scene_changes
	gate.arrival_path = ^"UnavailableArrival"
	if not await _walk_into_gate(&"ui_right"):
		return
	await travel.finished
	for frame in 9:
		await tree.physics_frame
	Input.action_release(&"ui_right")
	_expect(tree.current_scene == estate and scene_changes == change_count and not travel.active and not travel.cover.visible
		and "暂时无法通行" in estate.get_node("CampaignHUD").notice.text,
		"A missing arrival fades back with feedback and clears the lock without retriggering.")
	print("MAP_TRAVEL_RECOVERED scene=", tree.current_scene.name, " active=", travel.active)
	gate.arrival_path = marker
	await Campaign.walk_to(tree, _player(estate), Vector2(355, 4))
	if not await _cross(&"ui_right", "retry", state.WILDERNESS_SCENE, "WestArrival"):
		return
	state.current_day = state.balance.days_per_year * 2 + 1
	state.current_rank = state.Rank.DA_FU
	state.king_storage = 10
	if await _cross(&"ui_left", "council", state.ESTATE_SCENE, "World/EastArrival"):
		var world := tree.current_scene.get_node("World")
		_expect(state.tax_council_waiting() and world.tax_envoy.visible and not tree.paused,
			"The eligible arrival summons the envoy without stopping the crossing or showing the council.")
		await Campaign.walk_to(tree, world.player, Vector2(66, 36))
		var council := await Campaign.meet_tax_envoy(tree)
		_expect(council != null and council.visible and tree.paused, "The arriving player can walk to the real council.")
		print("MAP_TRAVEL_COUNCIL visible=", council != null, " paused=", tree.paused)

func _play() -> void:
	var world := tree.current_scene.get_node("World")
	var tiles: TileMapLayer = world.tile_map
	var point := tiles.get_global_transform_with_canvas() * tiles.map_to_local(PUBLIC)
	for action in 3:
		await _click(point)
	if rendered and not capture_dir.is_empty():
		var pointer := InputEventMouseMotion.new()
		pointer.position = Vector2(12, 12)
		pointer.global_position = pointer.position
		tree.root.push_input(pointer, true)
		await tree.create_timer(0.58).timeout
		await RenderingServer.frame_post_draw
		var frame := tree.root.get_texture().get_image()
		_expect(frame.save_png(capture_dir.path_join("estate-layout.png")) == OK, "Save the starting estate layout.")
		print("MAP_TRAVEL_ESTATE window=", tree.root.size, " image=", frame.get_size())
	_press_key(KEY_5)
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.position = tree.root.get_visible_rect().get_center()
	wheel.global_position = wheel.position
	tree.root.push_input(wheel, true)
	_expect(state.selected_seed_id == "beans" and state.active_crops.get(PUBLIC, {}).get("watered", false)
		and world.player.camera.zoom == Vector2(3, 3), "Prepare a watered plot, a nondefault seed and close camera using normal input.")
	await Campaign.walk_to(tree, world.player, Vector2(66, 36))
	await Campaign.walk_to(tree, world.player, Vector2(365, 6))
	var stamina: int = state.current_stamina
	if not await _cross(&"ui_right", "east", state.WILDERNESS_SCENE, "WestArrival"):
		return
	if not await _cross(&"ui_left", "west", state.ESTATE_SCENE, "World/EastArrival"):
		return
	world = tree.current_scene.get_node("World")
	_expect(world.current_seed_id == "beans" and state.current_stamina == stamina and state.active_crops[PUBLIC].watered
		and world.crops_layer.get_cell_source_id(PUBLIC) >= 0,
		"The round trip restores the wet crop and keeps the stamina and seed selection.")
	await _save_from_settings()
	if not rendered:
		await _retry_and_arrive_at_council()
	await _verify_manual_save()

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated map travel replay profile."):
		tree.quit(1)
		return
	seed(650)
	state = tree.root.get_node("Global")
	travel = tree.root.get_node("MapTravel")
	rendered = DisplayServer.get_name() != "headless"
	capture_dir = OS.get_environment("FIEFDOM_MAP_TRAVEL_CAPTURES")
	tree.root.notify_mouse_entered()
	tree.scene_changed.connect(func(): scene_changes += 1)
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE, "Start a new estate from the title."):
		await _play()
	tree.paused = false
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
