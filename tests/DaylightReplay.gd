extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const Terrain := preload("res://scripts/TerrainAudio.gd")
const PUBLIC := Vector2i(5, 5)
const FAST_DAY := 13.0

var tree: SceneTree
var state: Node
var world: Node2D
var ui: CanvasLayer
var capture_dir := ""
var rendered := false
var failures := 0

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		push_error(message)
	return condition

func _wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout

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
	if not _expect(button != null and button.is_visible_in_tree() and not button.disabled, "Use a visible enabled button."):
		return
	await _click(button.get_global_rect().get_center())
	await tree.process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)
	await tree.process_frame
	await tree.process_frame

func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for frame in frames:
		await tree.physics_frame
	Input.action_release(action)
	await Campaign.wait_for_map_change(tree)

func _capture(name: String) -> void:
	if capture_dir.is_empty() or not rendered:
		return
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(capture_dir.path_join(name + ".png")) == OK, "Save the " + name + " frame.")
	print("DAYLIGHT_FRAME ", name, " window=", tree.root.size, " image=", frame.get_size())

func _use_estate() -> bool:
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.name == "Main", "Use the actual estate scene."):
		return false
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame
	return true

func _wait_for_progress(progress: float) -> void:
	for frame in 1200:
		if state.day_progress >= progress:
			return
		await tree.process_frame
	_expect(false, "Reach the next part of the day during ordinary play.")

func _lamps_on(lighting: CanvasModulate) -> int:
	var count := 0
	for lamp in lighting.lamps:
		if lamp.visible and lamp.glow.enabled:
			count += 1
	return count

func _button_named(parent: Node, prefix: String) -> Button:
	for button: Button in parent.find_children("*", "Button", true, false):
		if button.text.begins_with(prefix):
			return button
	return null

func _read_save(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func _check_field_layout() -> void:
	var landscape := world.get_node("Landscape") as Node2D
	var field: Rect2 = landscape._field_bounds(PUBLIC)
	var tiles: TileMapLayer = world.tile_map
	var crops: TileMapLayer = world.crops_layer
	var water := landscape.to_local(tiles.to_global(tiles.map_to_local(state.irrigation.source_cell)))
	var soil := PackedVector2Array([field.position, Vector2(field.end.x, field.position.y), field.end,
		Vector2(field.position.x, field.end.y)])
	var ditch := PackedVector2Array([water + Vector2(0, -4), Vector2(field.position.x, water.y - 4),
		Vector2(field.position.x, water.y + 4), water + Vector2(0, 4)])
	_expect(field.get_center() == Vector2(104, 112) and water == Vector2(40, 112),
		"The farm and its water source sit together in the new meadow.")
	var boundary: Line2D = tiles.get_node("WellFieldMarker").marker_nodes[0].get_node("Boundary")
	_expect(not boundary.closed and boundary.points[0].distance_to(boundary.points[-1]) == WellFieldMarker.ENTRANCE_WIDTH,
		"The well field's south boundary has a real opening.")
	for y in range(-1, 2):
		for x in range(-1, 2):
			var cell := PUBLIC + Vector2i(x, y)
			var pointer := tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)
			_expect(world.field_at(pointer) == cell and tiles.get_cell_source_id(cell) >= 0
				and tiles.to_global(tiles.map_to_local(cell)) == crops.to_global(crops.map_to_local(cell)),
				"The visible soil, crop layer, and click target agree across all nine plots.")
	for track in landscape.track_shapes:
		_expect(not Geometry2D.triangulate_polygon(track.shoulder).is_empty(), "The rounded road shoulder is drawable.")
		_expect(Geometry2D.intersect_polygons(track.shoulder, soil).is_empty(), "Road shoulders clear all nine starter plots.")
		_expect(Geometry2D.intersect_polygons(track.shoulder, ditch).is_empty(), "The road leaves space from water source to field.")
	var entry := Vector2(field.get_center().x, field.end.y)
	_expect(landscape._surface_at(entry + Vector2(0, 1)) == Terrain.Surface.TRACK
		and landscape._surface_at(entry + Vector2(0, 12)) == Terrain.Surface.TRACK
		and landscape._surface_at(entry + Vector2(0, -1)) == Terrain.Surface.GRASS
		and landscape._surface_at(entry + Vector2(11, 10)) == Terrain.Surface.GRASS
		and landscape._surface_at(water + Vector2(16, 0)) == Terrain.Surface.GRASS,
		"The farm approach meets the opening, with grass on either side and along the canal strip.")
	print("DAYLIGHT_FIELD_LAYOUT field=", field, " water=", water, " tracks=", landscape.track_shapes.size())

func _save_dusk() -> Dictionary:
	await _button(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	await _button(_button_named(settings, "保存游戏"))
	var saved := _read_save(state.manual_save_path())
	_expect(int(saved.get("current_day", 0)) == 7 and float(saved.get("day_progress", 0.0)) > 0.71,
		"The normal manual save records the summer dusk.")
	await _button(_button_named(settings, "关闭"))
	return saved

func _capture_insects(terrain: Node) -> void:
	if not rendered:
		return
	var bus := AudioServer.get_bus_index(&"Ambience")
	var slot := AudioServer.get_bus_effect_count(bus)
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, recorder)
	recorder.set_recording_active(true)
	await _wait(2.2)
	recorder.set_recording_active(false)
	var wave := recorder.get_recording()
	AudioServer.remove_bus_effect(bus, slot)
	if not _expect(wave != null and wave.get_length() >= 1.7 and terrain.crickets.playing,
			"Capture real cricket playback on the ambience bus."):
		return
	var peak := 0
	var samples := wave.data
	for offset in range(0, samples.size() - 1, 2):
		peak = maxi(peak, absi(samples.decode_s16(offset)))
	_expect(peak > 200 and peak < 32000, "The nighttime recording is audible and unclipped.")
	if not capture_dir.is_empty():
		_expect(wave.save_to_wav(capture_dir.path_join("night-crickets")) == OK, "Save the live night insects.")
	print("DAYLIGHT_AUDIO insects seconds=", snappedf(wave.get_length(), 0.01), " peak_dbfs=", snappedf(linear_to_db(peak / 32768.0), 0.1))

func _cross_at_dusk() -> bool:
	var estate_progress: float = state.day_progress
	await _move(&"ui_up", 48)
	await _move(&"ui_right", 213)
	if not _expect(tree.current_scene.name == "Wilderness", "Walk through the East Gate to the ravine."):
		return false
	var ravine := tree.current_scene
	_expect(state.current_day == 7 and state.day_progress >= estate_progress
		and state.day_progress < estate_progress + 0.08 and "酉时" in ravine.get_node("CampaignHUD").trail_date.text,
		"The trail carries the same dusk and day across the gate.")
	for enemy in tree.get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await Campaign.walk_ravine_to(tree, ravine, RavineLayout.FRUIT + Vector2(-8, 16))
	var landscape := ravine.get_node("Landscape")
	var terrain: Node = landscape.terrain_audio
	state.balance.daylight_seconds = FAST_DAY
	await _wait_for_progress(1.0)
	await _wait(0.55)
	_expect(state.current_day == 7 and state.day_progress == 1.0 and "亥时" in ravine.get_node("CampaignHUD").trail_date.text,
		"After dark, the same day remains playable.")
	_expect(is_zero_approx(terrain.birds.volume_linear) and terrain.crickets.volume_linear > 0.24
		and terrain.crickets.bus == &"Ambience" and is_zero_approx(terrain.creek.volume_linear),
		"Summer nights replace birds with nearby insects by the dry grove.")
	_expect(_lamps_on(landscape.day_lighting) == 4, "The west gate, both bridge ends and the south trail carry lit lamps.")
	await _capture("03-ravine-night")
	await _capture_insects(terrain)
	print("DAYLIGHT_RAVINE day=", state.current_day, " watch=", state.day_watch_label(), " insects=", snappedf(terrain.crickets.volume_linear, 0.01))
	await Campaign.walk_to_ravine_exit(tree, ravine)
	await _move(&"ui_left", 24)
	return await _use_estate()

func _rest_at_hall() -> bool:
	var hall := world.get_node("HallRest") as Node2D
	var lighting: CanvasModulate = world.get_node("Landscape/DayLighting")
	await Campaign.walk_to(tree, world.player, hall.global_position + Vector2(4, 14))
	_expect(hall.get_node("InteractionHint").visible and ui.hud.watch_label.text == "亥时"
		and _lamps_on(lighting) == lighting.lamps.size(), "The estate remains lit at night and the hall offers its evening action.")
	await _capture("04-hall-night")
	await _key(KEY_E)
	var plan := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(plan != null and state.current_day == 7, "E at the hall opens the nightly plan without advancing the day."):
		return false
	var sleep := plan.get_node("%Sleep") as Button
	_expect("今夜预计 1 格生长" in plan.field_forecast.text
		and plan.get_node("Center/Window").get_global_rect().encloses(sleep.get_global_rect()),
		"The room shows the watered plot's forecast and a usable sleep button.")
	await _capture("05-hall-plan")
	var grain: int = state.food_storage
	state.balance.daylight_seconds = 150.0
	await _button(sleep)
	await _wait(0.55)
	_expect("卯时" in ui.dawn_caption.text and state.current_day == 8, "Rest shows the next morning and its first watch.")
	await _wait(0.57)
	var latest: Dictionary = state.latest_saved_game()
	var checkpoint := _read_save(latest.get("path", ""))
	_expect(state.current_day == 8 and state.active_crops.get(PUBLIC, {}).get("age", 0) == 1
		and state.food_storage == grain - 1 and state.current_stamina == state.max_stamina
		and checkpoint.get("day_progress", -1) == 0.0 and ui.hud.watch_label.text == "卯时" and _lamps_on(lighting) == 0,
		"Sleeping from the hall settles crops and food once, resets the clock, and saves dawn.")
	await _capture("06-hall-dawn")
	print("DAYLIGHT_DAWN day=", state.current_day, " crop_age=", state.active_crops.get(PUBLIC, {}).get("age"),
		" grain=", grain, "->", state.food_storage, " saved_clock=", checkpoint.get("day_progress"))
	return true

func _resume_dusk(saved: Dictionary) -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.archive_button)
	var archive := tree.current_scene.get_node_or_null("SaveArchive")
	if not _expect(archive != null, "Choose a checkpoint from the title archive."):
		return
	var manual := _button_named(archive, "手动存档")
	_expect(manual != null and "酉时" in manual.text, "The archive identifies the evening checkpoint before loading.")
	await _button(manual)
	if not await _use_estate():
		return
	_expect(state.current_day == 7 and absf(state.day_progress - float(saved.get("day_progress", 0))) < 0.025
		and ui.hud.watch_label.text == "酉时" and _lamps_on(world.get_node("Landscape/DayLighting")) > 0,
		"The archived manual save resumes dusk and its lighting after dawn was played.")
	print("DAYLIGHT_RESTORE day=", state.current_day, " watch=", state.day_watch_label(), " progress=", snappedf(state.day_progress, 0.001))
	if rendered:
		return
	saved.erase("day_progress")
	var legacy := "user://daylight-legacy-fixture.json"
	var file := FileAccess.open(legacy, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	if _expect(state.load_game(legacy) == OK, "Read an older save with no daylight field.") and await _use_estate():
		_expect(state.current_day == 7 and ui.hud.watch_label.text == "卯时" and state.day_progress < 0.02,
			"Old saves begin at dawn of the saved date.")
		print("DAYLIGHT_LEGACY day=", state.current_day, " watch=", state.day_watch_label())

func _play_day() -> void:
	_check_field_layout()
	await _wait(1.0)
	_expect(state.current_day == 1 and state.day_progress > 0.004 and ui.hud.watch_label.text == "卯时",
		"Real gameplay time begins advancing on the first morning.")
	for day in range(2, 8):
		await _button(ui.sleep_button)
		await _wait(1.07)
		if not _expect(state.current_day == day, "Reach summer through normal nights."):
			return
	var tiles: TileMapLayer = world.tile_map
	var plot := tiles.get_global_transform_with_canvas() * tiles.map_to_local(PUBLIC)
	for action in 3:
		await _click(plot)
	_expect(state.active_crops.has(PUBLIC), "Plant the public crop through the normal field controls.")
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(12, 12)
	pointer.global_position = pointer.position
	tree.root.push_input(pointer, true)
	state.balance.daylight_seconds = FAST_DAY
	await _wait_for_progress(0.43)
	var lighting: CanvasModulate = world.get_node("Landscape/DayLighting")
	_expect(lighting.color.is_equal_approx(Color.WHITE) and _lamps_on(lighting) == 0, "Midday shows the terrain without lit lamps.")
	await _capture("01-estate-noon")
	await _wait_for_progress(0.73)
	state.balance.daylight_seconds = 150.0
	_expect(ui.hud.watch_label.text == "酉时" and lighting.color.r > lighting.color.b and _lamps_on(lighting) > 0,
		"Dusk warms the scene and lights the first lamps.")
	await _capture("02-estate-dusk")
	await _key(KEY_M)
	var paused_at: float = state.day_progress
	await _wait(0.38)
	_expect(tree.paused and is_equal_approx(state.day_progress, paused_at), "Opening the estate map pauses the clock.")
	await _key(KEY_ESCAPE)
	var saved := await _save_dusk()
	if await _cross_at_dusk() and await _rest_at_hall():
		await _resume_dusk(saved)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated daylight replay profile."):
		tree.quit(1)
		return
	seed(650)
	state = tree.root.get_node("Global")
	rendered = DisplayServer.get_name() != "headless"
	capture_dir = OS.get_environment("FIEFDOM_DAYLIGHT_CAPTURES")
	tree.root.notify_mouse_entered()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.new_button)
	if await _use_estate():
		await _play_day()
	tree.paused = false
	tree.unload_current_scene()
	for player in tree.root.get_node("AudioManager").get_children():
		if player is AudioStreamPlayer:
			player.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
