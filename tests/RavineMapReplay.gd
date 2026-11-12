extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const LANDSCAPE := preload("res://scripts/Landscape.gd")
const MOVEMENT := [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]

var tree: SceneTree
var state: Node
var ravine: Node
var player: CharacterBody2D
var map: Control
var guide: Node2D
var failures := 0
var map_capture_dir := ""

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failures += 1
		push_error(detail)
	return condition

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)
	await tree.process_frame

func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		tree.root.push_input(event, true)
		await tree.process_frame

func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for frame in frames:
		await tree.physics_frame
	Input.action_release(action)
	await Campaign.wait_for_map_change(tree)

func _capture_map_frame(name: String) -> void:
	if map_capture_dir.is_empty():
		return
	await tree.create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image != null and not image.is_empty() and image.save_png(map_capture_dir.path_join(name + ".png")) == OK,
		"Save the rendered ravine frame %s." % name)

func _plan_from_estate() -> bool:
	var ui: CanvasLayer = tree.current_scene.get_node("UI")
	var chart: Control = ui.estate_map
	await _key(KEY_M)
	await _click(chart.tabs.get_node("Ravine"))
	var herb_row: Button
	var details := {}
	for button: Button in chart.row_buttons:
		var entry: Dictionary = chart.row_buttons[button]
		details[entry.title] = entry.detail
		if entry.title == "望溪台":
			herb_row = button
	if not _expect(herb_row != null and details.get("野果坳") == "野果 · 粮食 +%d" % state.balance.wild_food_yield
		and "气血充足" in details.get("望溪台", "") and "蒲宁" in details.get("柳湾", "")
		and "野狗和斥候" in chart.ravine_note.text, "Before leaving, the chart explains fruit, herbs, fishing and the east bank."):
		return false
	await _click(herb_row)
	_expect(state.ravine_trip_target == "望溪台" and chart.target.point == ui.world.get_node("EastGate").position,
		"A ravine destination first points to the actual East Gate.")
	await _click(chart.clear_button)
	_expect(state.ravine_trip_target.is_empty(), "Clearing the planned trip cancels the handoff.")
	await _click(herb_row)
	await _key(KEY_ESCAPE)
	if not _expect(state.save_game() == OK, "Save the planned trip while still at the estate."):
		return false
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _click(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	ui = tree.current_scene.get_node("UI")
	return _expect(state.ravine_trip_target == "望溪台" and ui.directions.tracked_place == "竹涧 · 望溪台",
		"Continue keeps the chosen trip and its east gate cue.")

func _bind_ravine() -> bool:
	ravine = tree.current_scene
	if not _expect(ravine.name == "Wilderness", "East Gate must open the ravine scene."):
		return false
	player = ravine.get_node("Player")
	map = ravine.get_node("CampaignHUD").view.get_node("RavineMap")
	guide = ravine.get_node("RavineDirections")
	# The combat replay covers attacks. Keep enemies still to measure the route.
	for enemy in tree.get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	return true

func _layout_fits() -> bool:
	var panel: Control = map.modal.get_node("Center/Panel")
	if not tree.root.get_visible_rect().encloses(panel.get_global_rect()):
		return false
	var labels: Array[Rect2] = []
	for marker: Button in map.markers.values():
		if not marker.visible:
			continue
		var rect := marker.get_global_rect()
		if not map.chart.get_global_rect().encloses(rect):
			return false
		for prior in labels:
			if prior.intersects(rect):
				return false
		labels.append(rect)
	return (map.markers.has(SummerRaft.PLACE) and map.markers[RavineLayout.SOUTH_TRAIL_NAME].disabled
		and labels.size() == (11 if state.creek_traps_unlocked() else 9))

func _select_place(place: String) -> bool:
	await _key(KEY_M)
	if not _expect(map.modal.visible and tree.paused, "M opens the chart and pauses the ravine."):
		return false
	await _click(map.markers[place])
	return _expect(guide.destination_name == place and guide.route.size() >= 2, "Choose %s with the map button." % place)

func _walk_route(allow_exit := false) -> bool:
	var path: PackedVector2Array = guide.route.duplicate()
	var refreshed := false
	var travel := tree.root.get_node_or_null("MapTravel")
	for point in path:
		for frame in range(360):
			if tree.current_scene != ravine or (travel and travel.active) or player.position.distance_to(point) <= 3.0:
				break
			var direction := player.position.direction_to(point)
			var strengths := Vector4(-direction.x, direction.x, -direction.y, direction.y)
			for index in range(MOVEMENT.size()):
				if strengths[index] > 0.0:
					Input.action_press(MOVEMENT[index], strengths[index])
				else:
					Input.action_release(MOVEMENT[index])
			await tree.physics_frame
		for action in MOVEMENT:
			Input.action_release(action)
		if travel and travel.active:
			await travel.finished
		if tree.current_scene != ravine:
			if tree.current_scene == null:
				await tree.scene_changed
			return _expect(allow_exit and tree.current_scene.name == "Main", "Only a route to West Gate should leave the ravine.")
		if not _expect(player.position.distance_to(point) <= 3.0, "The player should reach %s from %s along the marked path." % [point, player.position]):
			return false
		if not guide.route.is_empty() and guide.route[0].distance_to(path[0]) >= 16.0:
			refreshed = true
	if path.size() > 2 and path[0].distance_to(path[-1]) >= 32.0:
		_expect(refreshed, "The guidance refreshes its starting point as the player walks.")
	return _expect(not allow_exit and guide.route.is_empty(), "The route clears on arrival, or returns to the estate at West Gate.")

func _cross_the_ravine() -> bool:
	await tree.process_frame
	if not _expect(guide.destination_name == "望溪台" and state.ravine_trip_target == "望溪台",
		"The forest continues the planned route without selecting it again."):
		return false
	await _capture_map_frame("00-west-woods")
	await _key(KEY_M)
	_expect(guide.route[0].is_equal_approx(player.position) and guide.destination == ravine.get_node("WildHerbs").position,
		"The chart joins the actual player location to the herb spot.")
	_expect(guide.route.has(LANDSCAPE.BRIDGE) and not guide.route.has(LANDSCAPE.FORD) and map.route_status.text.contains("木桥")
		and "气血充足" in map.route_status.text,
		"The northern destination from the west entrance uses the bridge.")
	var start := player.position
	await _move(&"ui_right", 10)
	_expect(player.position == start, "Movement input cannot move the player while the chart is open.")
	var original_size := tree.root.size
	for resolution in [Vector2i(1280, 720), Vector2i(1024, 768)]:
		tree.root.size = resolution
		await tree.process_frame
		await tree.process_frame
		_expect(_layout_fits(), "Chart labels and the panel fit at %s." % resolution)
		print("RAVINE_MAP_LAYOUT window=", tree.root.size, " panel=", map.modal.get_node("Center/Panel").size)
	tree.root.size = original_size
	await _capture_map_frame("01-ridge-route")
	await _key(KEY_ESCAPE)
	_expect(not map.modal.visible and not tree.paused and map.cancel_button.visible, "Esc returns to the trail and keeps directions.")
	if not await _walk_route():
		return false
	_expect(state.ravine_trip_target.is_empty(), "Reaching the herbs clears the persisted route.")
	await _key(KEY_E)
	_expect(state.last_forage_day != state.current_day, "Full health leaves the daily outing available.")
	print("RAVINE_TRIP_HERBS arrival=", player.position, " used=", state.last_forage_day == state.current_day)
	print("RAVINE_MAP_BRIDGE arrival=", player.position)
	await _capture_map_frame("02-east-lookout")

	if not await _select_place("砾滩"):
		return false
	await _click(map.close_button)
	if not await _walk_route():
		return false
	if not await _select_place("西门回封地"):
		return false
	_expect(guide.route.has(LANDSCAPE.FORD) and not guide.route.has(LANDSCAPE.BRIDGE) and map.route_status.text.contains("浅滩"),
		"The shortest road home from the east shoal crosses the ford.")
	await _capture_map_frame("03-ford-route")
	await _key(KEY_M)
	if not await _walk_route(true):
		return false
	var home: Vector2 = tree.current_scene.get_node("World/Player").position
	_expect(home.x > 310.0 and home.x < 381.0, "The marked way home returns inside the estate's East Gate.")
	print("RAVINE_MAP_FORD home=", home)
	return true

func _load_journal_waypoint(location: Dictionary) -> bool:
	await _click(map.journal_button)
	await _key(KEY_ESCAPE)
	await _click(map.get_parent().get_node("SettingsButton"))
	var settings: Panel = ravine.settings
	if not _expect(settings.visible and tree.paused, "The settings button pauses the trail after closing the chart."):
		return false
	var controls := {}
	for action: Button in settings.general.find_children("*", "Button", true, false):
		controls[action.text] = action
	await _click(controls["保存游戏"])
	await _click(controls["读取游戏"])
	var archive := settings.get_parent().get_node_or_null("SaveArchive") as Control
	if not _expect(archive != null and archive.preferred_campaign == state.campaign_id,
		"The archive opens this estate's records from the ravine."):
		return false
	await _click(archive.records.get_child(0))
	if tree.current_scene == null:
		await tree.scene_changed
	if not _bind_ravine():
		return false
	var restored := _expect(not tree.paused and guide.destination == location.position
		and guide.destination_name == location.name + "水迹" and guide.route.size() > 1,
		"Loading from the ravine restores the local water-mark route.")
	if restored:
		print("RAVINE_MAP_JOURNAL_RESUME waypoint=", guide.destination_name, " day=", state.current_day)
	return restored

func _check_journal() -> void:
	state.talk_to_visitor(VisitorData.RAVINE_GUIDE)
	await _move(&"ui_right", 36)
	if not _bind_ravine():
		return
	await _click(map.open_button)
	var site: int = state.ravine_site_today()
	if not _expect(map.modal.visible and map.journal_button.visible and site >= 0, "The map button opens the chart and shows the active journal site."):
		return
	var location: Dictionary = RavineJournal.SITES[site]
	await _click(map.journal_button)
	_expect(guide.destination == location.position and guide.destination_name == location.name + "水迹",
		"The journal shortcut points to the actual sign, with its own route label.")
	await _click(map.clear_button)
	_expect(guide.route.is_empty() and map.clear_button.disabled, "Clearing from inside the chart resets the highlighted route.")
	if not await _load_journal_waypoint(location):
		return
	if not await _walk_route():
		return
	if not await _select_place("望溪台"):
		return
	await _key(KEY_ESCAPE)
	await _key(KEY_E)
	_expect(state.ravine_journal.recorded_days[site] == state.current_day and not map.journal_button.visible,
		"The player records today's water mark at the real sign using E.")
	_expect(guide.destination_name == "望溪台", "Recording a water mark leaves a route to a place active.")
	await _click(map.cancel_button)
	_expect(guide.route.is_empty() and not map.cancel_button.visible, "The trail HUD can also clear directions.")
	print("RAVINE_MAP_JOURNAL site=", site, " day=", state.current_day)

	if not await _select_place(SummerRaft.PLACE):
		return
	await _key(KEY_ESCAPE)
	if not await _walk_route():
		return
	if not await _select_place("柳湾"):
		return
	_expect(guide.route.has(RavineLayout.DOCK_FORK) and guide.route.has(RavineLayout.WILLOW_FORK),
		"The upstream route leaves the raft landing and takes the shore path to its own cove.")
	await _capture_map_frame("04-upstream-route")
	await _key(KEY_ESCAPE)
	var clock: float = state.day_progress
	if not await _walk_route():
		return
	var travel_seconds: float = (state.day_progress - clock) * state.balance.daylight_seconds
	_expect(travel_seconds > 1.0, "The raft landing and fishing cove have a distinct stretch of shore between them.")
	print("RAVINE_MAP_UPSTREAM seconds=", snappedf(travel_seconds, 0.01))
	await _capture_map_frame("05-willow-cove")
	await _key(KEY_E)
	var fishing := ravine.get_node_or_null("FishingUI/FishingPanel")
	if not _expect(fishing != null and tree.paused, "E opens fishing at the chart's Willow Pool marker."):
		return
	await _key(KEY_M)
	_expect(is_instance_valid(fishing) and tree.paused and not map.modal.visible, "M leaves the active fishing panel in control.")
	await _key(KEY_ESCAPE)
	_expect(not tree.paused and not ravine.settings.visible, "Escape returns directly from fishing to the trail.")

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the ravine map replay's player profile."):
		tree.quit(1)
		return
	seed(650)
	if map_capture_dir.is_empty():
		tree.root.size = Vector2i(1280, 720)
	tree.root.notify_mouse_entered()
	state = tree.root.get_node("Global")
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	tree.current_scene.new_button.pressed.emit()
	await tree.scene_changed
	if await _plan_from_estate():
		await _move(&"ui_up", 48)
		await _move(&"ui_right", 213)
		if _bind_ravine() and await _cross_the_ravine():
			await _check_journal()
	tree.paused = false
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
