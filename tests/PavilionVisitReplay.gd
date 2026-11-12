extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const Landscape := preload("res://scripts/Landscape.gd")
const TerrainAudio := preload("res://scripts/TerrainAudio.gd")
const PUBLIC := Vector2i(5, 5)

var tree: SceneTree
var state: Node
var world: Node2D
var ui: CanvasLayer
var capture_dir := ""
var failures := 0

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		push_error(message)
	return condition

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)
	await tree.process_frame
	await tree.process_frame

func _click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame

func _button(button: Control) -> void:
	await tree.process_frame
	if _expect(button != null and button.is_visible_in_tree(), "Use a visible menu control."):
		await _click(button.get_global_rect().get_center())
	await tree.process_frame
	await tree.process_frame

func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(capture_dir.path_join(name + ".png")) == OK, "Save the " + name + " frame.")
	print("PAVILION_FRAME ", name, " window=", tree.root.size, " image=", frame.get_size())

func _bind_estate() -> bool:
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.name == "Main", "Use the real estate scene."):
		return false
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame
	return true

func _title(continuing: bool) -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	var button: Button = tree.current_scene.continue_button if continuing else tree.current_scene.new_button
	await _button(button)
	return await _bind_estate()

func _walk(point: Vector2) -> void:
	await Campaign.walk_to(tree, world.player, world.to_global(point))

func _meet(guest: Visitor, offset: Vector2) -> Control:
	await _walk(guest.position + offset)
	await _key(KEY_E)
	return ui.get_node_or_null("Control/DialoguePanel") as Control

func _sleep() -> void:
	await _button(ui.sleep_button)
	await tree.create_timer(1.10).timeout

func _skip_to(progress: float) -> void:
	state.advance_daylight(maxf(0.0, progress - state.day_progress) * state.balance.daylight_seconds)

func _wait_for_walk(guest: Visitor) -> bool:
	for frame in 210:
		if guest.activity == VisitorData.VisitActivity.PAVILION_REST and guest.sprite.walking:
			return true
		await tree.physics_frame
	return _expect(false, "The watch change starts a real walk.")

func _wait_for_arrival(guest: Visitor) -> bool:
	for frame in 840:
		if guest.resting_at_pavilion():
			return _expect(guest.position == Landscape.PAVILION_REST_FOOT, "The visitor settles at the pavilion.")
		await tree.physics_frame
	return _expect(false, "Finish walking to the pavilion.")

func _check_appointment(guest: Visitor) -> void:
	await _button(ui.hud.neighbors_button)
	var panel: Control = ui.panel_manager.management_panel_instance
	var journal: Control = panel.neighbor_journal
	await _button(journal.roster.get_node(guest.data.name))
	_expect("今日来访" in journal.where.text and "酉时到南路亭歇脚" in journal.where.text
		and journal.locate_button.visible, "Today's journal shows the current visit and evening appointment.")
	print("PAVILION_APPOINTMENT ", journal.where.text.replace("\n", " / "))
	await _capture("01-day-appointment")
	await _button(panel.get_node("CloseButton"))

func _check_moving_pin(guest: Visitor) -> void:
	await _key(KEY_M)
	var map: Control = ui.estate_map
	if not _expect(tree.paused and map.modal.visible, "The chart pauses while the visitor is in transit."):
		return
	await _button(map.tabs.get_node("People"))
	var chosen: Button
	for button: Button in map.row_buttons:
		var entry: Dictionary = map.row_buttons[button]
		if entry.title == guest.data.name:
			_expect(entry.point == guest.position and "正往南路亭" in entry.detail,
				"The chart pins the actor's current location and names the destination.")
			chosen = button
			break
	if _expect(chosen != null, "Find the walking visitor on the chart."):
		await _button(chosen)
		await _capture("02-visitor-in-transit")
	await _key(KEY_ESCAPE)
	var previous := guest.position
	for frame in 10:
		await tree.physics_frame
	_expect(guest.position.distance_to(previous) > 4.0 and ui.directions.destination().get("point") == guest.position,
		"Directions continue tracking the walking visitor after closing the chart.")

func _save() -> void:
	await _button(ui.settings_button)
	var panel: Control = ui.panel_manager.settings_panel_instance
	for button: Button in panel.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	await _button(panel.find_child("Close", true, false))

func _play_opening() -> void:
	var tiles: TileMapLayer = world.tile_map
	var at := tiles.get_global_transform_with_canvas() * tiles.map_to_local(PUBLIC)
	for action in 3:
		await _click(at)
	await _sleep()
	tiles = world.tile_map
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(PUBLIC))
	var guest: Visitor = world.current_visitor_actor()
	if not _expect(state.current_day == 2 and guest != null and guest.data.name == VisitorData.ROAD_KEEPER
		and guest.position == VisitorData.SOUTH_POST and not guest.walking_to_stop, "Meet Ji Qing at his daytime stop on a new game."):
		return
	var dialog := await _meet(guest, Vector2(0, -15))
	if not _expect(dialog != null and dialog.name_label.text == guest.data.name, "Open the first regular visit by walking up."):
		return
	await _button(dialog.options_container.get_child(0))
	await _check_appointment(guest)
	_skip_to(0.684)
	if not await _wait_for_walk(guest):
		return
	_expect("正往南路亭" in ui.hud.visitor_label.text, "The estate journal says where the visitor is going.")
	await _key(KEY_E)
	dialog = ui.get_node_or_null("Control/DialoguePanel") as Control
	if _expect(dialog != null and "正往南路亭" in dialog.context_label.text, "Speak to the visitor while he is walking."):
		var at_during_talk := guest.position
		var clock: float = state.day_progress
		await tree.create_timer(0.24).timeout
		_expect(guest.position == at_during_talk and is_equal_approx(state.day_progress, clock),
			"The visit and clock wait while the player is speaking.")
	await _key(KEY_ESCAPE)
	await _check_moving_pin(guest)
	if not await _wait_for_arrival(guest):
		return
	await _button(ui.hud.cancel_directions)
	_skip_to(0.91)
	await _walk(guest.position + Vector2(26, 1))
	await _capture("03-pavilion-by-lantern")
	await _key(KEY_E)
	dialog = ui.get_node_or_null("Control/DialoguePanel") as Control
	if _expect(dialog != null and "灯下歇脚" in dialog.context_label.text
		and dialog.text_label.text == VisitorData.PAVILION_LINES[VisitorData.ROAD_KEEPER], "Read Ji Qing's evening line in the regular conversation."):
		_expect(dialog.options_container.get_child(0).disabled and "交易" in dialog.options_container.get_child(1).text
			and "招募" in dialog.options_container.get_child(2).text, "Evening keeps trade, recruitment, and the once-a-day talk rule.")
		await _capture("04-evening-conversation")
	await _key(KEY_ESCAPE)
	await _save()
	if not await _title(true):
		return
	guest = world.current_visitor_actor()
	_expect(state.current_day == 2 and state.day_progress >= 0.91 and guest.resting_at_pavilion()
		and guest.position == Landscape.PAVILION_REST_FOOT, "Continue a manual save at the same evening station.")
	print("PAVILION_RESTORE day=", state.current_day, " watch=", state.day_watch_label(), " foot=", guest.position)
	await _sleep()
	guest = world.current_visitor_actor()
	_expect(state.current_day == 3 and state.day_progress < 0.03 and guest.data.name == VisitorData.WATER_GUIDE
		and guest.activity == VisitorData.VisitActivity.NONE and state.active_crops.get(PUBLIC, {}).get("age") == 2
		and state.king_storage == 0, "Morning resets the appointment while the public crop grows normally.")

func _load_fixture(data: Dictionary) -> bool:
	var path := "user://pavilion-visit-check.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _expect(file != null, "Use a dedicated save fixture."):
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	if not _expect(state.load_game(path) == OK, "Read the save fixture."):
		return false
	await tree.scene_changed
	return await _bind_estate()

func _rain_visit() -> void:
	if not await _load_fixture({"current_day": 6, "day_progress": 0.548}):
		return
	var guest: Visitor = world.current_visitor_actor()
	if not _expect(state.has_rain() and guest.data.name == VisitorData.EAST_WATCHER
		and guest.visit_location() == "东路岗" and VisitorData.pavilion_rest_plan().begins_with("申时"),
		"Rain keeps the daytime stop until Shen and then has an earlier shelter plan."):
		return
	_skip_to(0.563)
	if not await _wait_for_walk(guest):
		return
	var sampled_road := 0
	while guest.walking_to_stop and sampled_road < 420:
		await tree.physics_frame
		sampled_road += 1
		if guest.position.x > 142.0 and guest.position.y > 151.0:
			if not _expect(world.get_node("Landscape")._surface_at(guest.position) == TerrainAudio.Surface.TRACK,
				"The east visitor follows the dirt lane beside the field."):
				break
	if not await _wait_for_arrival(guest):
		return
	var gathering := world.get_node("SpringGathering") as Node2D
	_expect(guest.visit_note().ends_with("檐下避雨") and state.day_watch_label() == "申时"
		and gathering.get_node("Guests").get_child_count() == 3,
		"The rainy pavilion visit leaves the three festival guests available.")
	_expect(gathering.get_node("BookHint").global_position.y > guest.global_position.y + 8.0,
		"The scorebook label stays below the sheltering visitor.")
	await _walk(guest.position + Vector2(26, 1))
	await _capture("05-rain-shelter")
	await _key(KEY_E)
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	_expect(dialog != null and dialog.name_label.text == guest.data.name
		and dialog.text_label.text == VisitorData.PAVILION_RAIN_LINES[VisitorData.EAST_WATCHER], "Read the rainy conversation at the pavilion.")
	await _key(KEY_ESCAPE)
	await _walk(gathering.position + Vector2(0, 10))
	await _key(KEY_E)
	dialog = ui.get_node_or_null("Control/DialoguePanel") as Control
	_expect(dialog != null and dialog.name_label.text == "谷雨曲簿", "The scorebook keeps its own interaction beside the visitor.")
	await _key(KEY_ESCAPE)
	print("PAVILION_RAIN watch=", state.day_watch_label(), " road_ticks=", sampled_road, " foot=", guest.position)

func _move_through_gate(action: StringName) -> void:
	Input.action_press(action)
	for step in 35:
		await tree.physics_frame
	Input.action_release(action)
	await Campaign.wait_for_map_change(tree)

func _return_during_the_walk() -> void:
	if not await _load_fixture({"current_day": 11, "day_progress": 0.58}):
		return
	var guest: Visitor = world.current_visitor_actor()
	var before := guest.position
	await _walk(Vector2(361, 4))
	_skip_to(0.689)
	await _move_through_gate(&"ui_right")
	if not _expect(tree.current_scene.scene_file_path == state.WILDERNESS_SCENE, "Leave through the real east gate during the visit."):
		return
	await _move_through_gate(&"ui_left")
	if not await _bind_estate():
		return
	guest = world.current_visitor_actor()
	_expect(guest.data.name == VisitorData.EAST_WATCHER and guest.walking_to_stop and guest.position.distance_to(before) > 20.0
		and guest.position.distance_to(Landscape.PAVILION_REST_FOOT) > 30.0,
		"Returning from the ravine restores the visitor partway through the evening walk.")
	print("PAVILION_REENTRY watch=", state.day_watch_label(), " foot=", guest.position, " walking=", guest.walking_to_stop)
	var before_save := guest.position
	await _save()
	if not await _title(true):
		return
	guest = world.current_visitor_actor()
	_expect(guest.data.name == VisitorData.EAST_WATCHER and guest.walking_to_stop
		and guest.position.distance_to(before_save) < 30.0, "Continuing a mid-walk save resumes the same part of the lane.")
	await _wait_for_arrival(guest)

func _check_scheduled_guests() -> void:
	for index in range(3, 6):
		if not await _load_fixture({"current_day": index, "day_progress": 0.91}):
			return
		var guest: Visitor = world.current_visitor_actor()
		_expect(guest.resting_at_pavilion() and guest.position == Landscape.PAVILION_REST_FOOT
			and guest.data.pavilion_greeting() == VisitorData.PAVILION_LINES[guest.data.name],
			"Each ordinary weekday visit restores its own evening dialogue and location.")
	var priorities := [
		[{"current_day": 3, "first_channel_growth_day": 3}, VisitorData.WATER_GUIDE, "水源旁", "随石墨勘渠"],
		[{"current_day": 11, "ravine_journal": {"recorded_days": [5, 6, 7]}}, VisitorData.RAVINE_GUIDE, "南边竹径", "交溪行手记"],
		[{"current_day": 9, "raids_defeated": 1, "last_defense": {"day": 8, "kind": 0, "losses": 0, "guard": ""}},
			VisitorData.EAST_WATCHER, "东路岗", "复盘守备"],
	]
	for case: Array in priorities:
		var fixture: Dictionary = case[0]
		fixture["day_progress"] = 0.91
		fixture["visitor_encounters"] = [case[1]]
		if not await _load_fixture(fixture):
			return
		var guest: Visitor = world.neighbor_actor(case[1])
		if not _expect(guest != null and guest.data.name == case[1] and guest.visit_location() == case[2]
			and not guest.data.has_pavilion_rest(), "A priority visitor stays at the promised place after dark."):
			continue
		var dialog := await _meet(guest, Vector2(0, -17))
		var found := false
		if dialog != null:
			for button: Button in dialog.options_container.get_children():
				found = found or (button.text.begins_with(case[3]) and not button.disabled)
		_expect(found, "Use the ordinary night conversation to continue " + str(case[3]))
		await _key(KEY_ESCAPE)
		print("PAVILION_PRIORITY guest=", guest.data.name, " stop=", guest.visit_location(), " choice=", found)
	if await _load_fixture({"current_day": 3}):
		var guest: Visitor = world.current_visitor_actor()
		_expect(state.day_progress < 0.03 and guest.visit_location() == "水源旁" and not guest.resting_at_pavilion(),
			"An old save without clock progress starts with the daytime visit.")
	var duration: float = state.balance.daylight_seconds
	state.balance.daylight_seconds = 15.0
	if await _load_fixture({"current_day": 11, "day_progress": 1.0}):
		var guest: Visitor = world.current_visitor_actor()
		_expect(guest.resting_at_pavilion(), "A capped night clock restores the arrival even with a short daytime setting.")
	state.balance.daylight_seconds = duration

func _check_visits_from_facilities() -> void:
	var completed := [
		[{"current_day": 22, "road_rest_paid_day": 12, "road_provisions_delivered": true},
			VisitorData.VisitActivity.ROAD_REST, Landscape.ROAD_REST_TRACK[0]],
		[{"current_day": 15, "ravine_journal": {"recorded_days": [5, 6, 7], "garden_day": 11}},
			VisitorData.VisitActivity.HERBS, Landscape.GARDEN_TRACK[0]],
	]
	for case: Array in completed:
		if not await _load_fixture(case[0]):
			return
		var guest: Visitor = world.current_visitor_actor()
		if not _expect(guest != null and guest.activity == case[1] and not guest.walking_to_stop,
			"An established visitor spends the day at the completed facility."):
			continue
		_skip_to(0.689)
		if await _wait_for_walk(guest):
			_expect(case[2] in guest.visit_path, "The visitor uses the facility path on the way back to the pavilion.")
			await _wait_for_arrival(guest)
		print("PAVILION_FACILITY guest=", guest.data.name, " foot=", guest.position)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated pavilion profile."):
		tree.quit(1)
		return
	seed(425)
	tree.root.notify_mouse_entered()
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_PAVILION_CAPTURES")
	if await _title(false):
		await _play_opening()
		await _rain_visit()
		await _return_during_the_walk()
		await _check_scheduled_guests()
		if DisplayServer.get_name() == "headless":
			await _check_visits_from_facilities()
	tree.paused = false
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
