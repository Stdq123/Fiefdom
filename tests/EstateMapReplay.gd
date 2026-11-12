extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const PUBLIC := Vector2i(5, 5)
const WORKSITE := Vector2i(12, 5)
const ROAD_KEEPER := VisitorData.ROAD_KEEPER
const MOVEMENT := [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]

var tree: SceneTree
var state: Node
var world: Node2D
var ui: CanvasLayer
var map: Control
var guide: Control
var failures := 0
var capture_dir := ""

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
	await tree.process_frame

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	tree.root.push_input(event, true)
	await tree.process_frame

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	tree.root.push_input(motion, true)
	await _mouse(point, true)
	await _mouse(point, false)
	await tree.process_frame

func _button(control: Control) -> void:
	await _click(control.get_global_rect().get_center())

func _walk(player: CharacterBody2D, point: Vector2) -> void:
	var scene := tree.current_scene
	var travel := tree.root.get_node_or_null("MapTravel")
	for frame in range(540):
		if tree.current_scene != scene or (travel and travel.active) or player.position.distance_to(point) <= 3.0:
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
	await Campaign.wait_for_map_change(tree)

func _bind_estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	map = ui.estate_map
	guide = ui.directions
	await tree.process_frame

func _row(title: String) -> Button:
	for button: Button in map.row_buttons:
		if map.row_buttons[button].title == title:
			return button
	return null

func _person(title: String) -> Dictionary:
	for entry: Dictionary in map.people:
		if entry.title == title:
			return entry
	return {}

func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var picture := tree.root.get_texture().get_image()
	_expect(picture.save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)
	print("ESTATE_MAP_FRAME ", name, " ", picture.get_size())

func _new_estate() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.name == "Main", "Start the estate through the title menu."):
		return
	await _bind_estate()
	var tiles: TileMapLayer = world.tile_map
	var plot := tiles.get_global_transform_with_canvas() * tiles.map_to_local(PUBLIC)
	await _mouse(plot, true)
	_expect(world.sweep_action == world.FieldAction.TILL, "A held click starts a farm gesture.")
	await _key(KEY_M)
	_expect(map.modal.visible and tree.paused and world.sweep_action == world.FieldAction.NONE,
		"Opening the survey ends the held farm gesture and pauses the world.")
	await _mouse(plot, false)
	await _button(map.tabs.get_node("People"))
	var keeper: Node2D = world.neighbor_actor(VisitorData.FIELD_KEEPER)
	_expect(map.people.size() == 1 and is_instance_valid(keeper)
		and _person(VisitorData.FIELD_KEEPER).get("point") == keeper.position,
		"The first morning shows the starter retainer at his actual position.")
	await _key(KEY_ESCAPE)
	_expect(not tree.paused and not map.modal.visible, "Escape closes the map on a new game.")
	print("ESTATE_MAP_NEW_GAME first_morning_people=", map.people.size())

func _load_expansion() -> bool:
	# Restore a funded expansion in mid-construction with both connected and dry ditches.
	var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if not _expect(file != null, "Write the expansion fixture in the isolated profile."):
		return false
	file.store_string(JSON.stringify({
		"current_day": 2, "current_rank": state.Rank.SHANG_SHI, "king_storage": 1, "reputation": 150,
		"money": 620, "food_storage": 260, "tech_unlocked": {"irrigation": true},
		"well_fields": [
			{"center_pos": str(PUBLIC), "is_unlocked": true, "reclamation_progress": 4},
			{"center_pos": str(WORKSITE), "reclamation_progress": 2},
			{"center_pos": "-5,7", "is_unlocked": true, "reclamation_progress": 4},
			{"center_pos": "10,-3", "is_unlocked": true, "reclamation_progress": 4}
		],
		"irrigation_channels": ["2,5", "3,5", "3,4", "3,6", "10,5", "10,6"],
		"active_crops": {"5,5": {"id": "millet", "age": 2, "growth_nights": 2}},
		"silk_workshop": {"built": true},
		"retainers": [{"name": VisitorData.WATER_GUIDE, "profession": "工匠",
			"school": RetainerData.School.MOHIST, "duty": RetainerData.Duty.REEL}]
	}))
	file.close()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.name == "Main", "Enter the saved estate through the title menu."):
		return false
	await _bind_estate()
	return _expect(state.current_day == 2 and state.well_fields.size() == 4, "Continue restores the fixture through the title menu.")

func _check_input_ownership() -> void:
	await _button(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	await _key(KEY_M)
	_expect(management.visible and not map.modal.visible and not tree.paused, "M leaves management open.")
	await _button(management.get_node("CloseButton"))
	await _button(ui.channel_button)
	await _key(KEY_M)
	_expect(world.channel_mode and not map.modal.visible, "M leaves channel editing in control.")
	await _key(KEY_ESCAPE)
	_expect(not world.channel_mode, "Escape keeps the normal channel editing shortcut.")
	tree.paused = true
	await _key(KEY_M)
	_expect(tree.paused and not map.modal.visible, "A pause already owned by another screen is respected.")
	tree.paused = false

func _check_layout() -> void:
	var resolutions: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1024, 768)]
	if not capture_dir.is_empty():
		resolutions.assign([tree.root.size])
	for resolution in resolutions:
		tree.root.size = resolution
		await tree.process_frame
		await tree.process_frame
		var panel := map.modal.get_node("Center/Panel") as Control
		var pane: Rect2 = map.scroll.get_global_rect()
		var first := _row("东关")
		_expect(tree.root.get_visible_rect().encloses(panel.get_global_rect()) and first != null
			and pane.encloses(first.get_global_rect()) and not pane.intersects(map.chart.get_global_rect()),
			"The panel, chart and index fit at %s." % resolution)
		var x_axis: Vector2 = map._map_point(Vector2.RIGHT * 16) - map._map_point(Vector2.ZERO)
		var y_axis: Vector2 = map._map_point(Vector2.DOWN * 16) - map._map_point(Vector2.ZERO)
		_expect(is_equal_approx(x_axis.length(), y_axis.length()), "The estate projection has the same scale on both axes.")
		print("ESTATE_MAP_LAYOUT window=", tree.root.size, " panel=", panel.size)

func _check_fields() -> bool:
	var money: int = state.money
	var food: int = state.food_storage
	var start: Vector2 = world.player.position
	await _button(ui.hud.map_button)
	if not _expect(map.modal.visible and tree.paused and map.fields.size() == 4, "The HUD opens the survey of the four actual fields."):
		return false
	await _check_layout()
	Input.action_press(&"ui_right")
	for frame in 12:
		await tree.physics_frame
	Input.action_release(&"ui_right")
	_expect(world.player.position == start and state.money == money and state.food_storage == food and state.current_day == 2,
		"The paused chart does not move the player or change the day's economy.")
	_expect(_row("蚕棚") != null and _row("药圃") == null, "Only facilities that exist are listed.")
	await _capture("01-estate-places")

	await _button(map.tabs.get_node("Fields"))
	var base: Dictionary = map.fields[0]
	var site: Dictionary = map.fields[1]
	_expect(base.detail == "渠水 3/9 格 · 可收 1 格" and base.watered.size() == 3
		and state.irrigation.is_channel_wet(Vector2i(2, 5)) and not state.irrigation.is_channel_wet(Vector2i(10, 5)),
		"The survey agrees with the saved network and crop maturity.")
	_expect(site.detail == "整地 · 还需 2 夜" and site.point == world.get_crop_world_pos(WORKSITE),
		"The worksite has the right position and remaining nights.")
	var point: Vector2 = map.chart.get_global_rect().position + map._map_point(site.point)
	await _click(point)
	_expect(guide.tracked_site == 1 and map.target.point == site.point and "井田 2 工地" in map.status.text,
		"Clicking the mapped footprint starts the existing worksite directions.")
	await _capture("02-field-survey")
	await _key(KEY_ESCAPE)
	_expect(not map.modal.visible and not tree.paused and guide.visible and guide.tracked_site == 1,
		"Return to the estate with the selected worksite highlighted.")
	await _walk(world.player, site.point)
	_expect(world.player.position.distance_to(site.point) < 5.0, "Walk to the selected worksite on the estate.")
	print("ESTATE_MAP_FIELDS watered=", base.watered.size(), " site=", site.point, " label=", site.detail)
	return true

func _meet_visitor() -> bool:
	await _key(KEY_M)
	_expect(map.category == map.Category.FIELDS, "Reopening the chart keeps the previous tab.")
	await _button(map.tabs.get_node("People"))
	var row := _row(ROAD_KEEPER)
	var actor: Node2D = world.neighbor_actor(ROAD_KEEPER)
	var visitor := _person(ROAD_KEEPER)
	if not _expect(row != null and is_instance_valid(actor) and visitor.get("point") == actor.position and visitor.icon != null,
		"The actual visitor is available in the current people index."):
		return false
	_expect(_row(VisitorData.WATER_GUIDE) != null and _row(VisitorData.RAVINE_GUIDE) == null,
		"Show the present retainer and omit the absent visitor.")
	await _button(row)
	_expect(guide.tracked_neighbor == ROAD_KEEPER and not map.target.is_empty() and row.button_pressed,
		"The index selects the actual visitor's direction.")
	var pavilion: Rect2 = map.captions.get("南路亭", Rect2())
	_expect(pavilion.has_area() and not pavilion.grow(13.0).has_point(map._map_point(visitor.point)),
		"The pavilion caption stays legible beside the selected visitor.")
	await _capture("03-present-neighbors")
	await _key(KEY_M)
	await _walk(world.player, actor.position + Vector2(13, -9))
	await _key(KEY_E)
	_expect(world.player.conversation_open and guide.tracked_neighbor.is_empty(),
		"E greets the marked visitor and clears the direction.")
	await _key(KEY_M)
	_expect(world.player.conversation_open and not map.modal.visible, "M leaves the active conversation in control.")
	await _key(KEY_ESCAPE)
	print("ESTATE_MAP_VISITOR met=", ROAD_KEEPER, " day=", state.current_day)
	return true

func _check_after_dawn() -> bool:
	await _button(ui.sleep_button)
	await _key(KEY_M)
	_expect(not map.modal.visible, "M cannot interrupt the dawn transition.")
	await tree.create_timer(1.10).timeout
	await _button(ui.sleep_button)
	await tree.create_timer(1.12).timeout
	await _key(KEY_M)
	if not _expect(map.modal.visible and state.current_day == 4 and state.get_well_field(1).is_unlocked,
		"The paid worksite becomes a regular field after two nights."):
		return false
	var visitor: VisitorData = world.current_visitor()
	_expect(_row(ROAD_KEEPER) == null and visitor != null and _row(visitor.name) != null,
		"Reopening the index after dawn removes the departed visitor and locates the new one.")
	await _button(map.tabs.get_node("Fields"))
	var row := _row("井田 2")
	if not _expect(row != null and _row("井田 2 工地") == null and not map.fields[1].worksite,
		"The completed field replaces the old worksite entry."):
		return false
	await _button(row)
	_expect(guide.tracked_place == "井田 2" and map.target.point == world.get_crop_world_pos(WORKSITE),
		"The finished field can be located at the same coordinates.")
	await _button(map.clear_button)
	_expect(map.target.is_empty() and map.clear_button.disabled and not ui.hud.cancel_directions.visible,
		"Clear directions from the survey.")
	print("ESTATE_MAP_DAWN day=", state.current_day, " site=", map.fields[1].title)
	return true

func _cross_east_gate() -> void:
	await _button(map.tabs.get_node("Places"))
	await _button(_row("东关"))
	var gate: Vector2 = world.get_node("EastGate").position
	_expect(guide.tracked_place == "东关" and map.target.point == gate, "The East Gate pin uses its actual entrance.")
	await _button(map.close_button)
	await _walk(world.player, gate)
	if not _expect(tree.current_scene.name == "Wilderness", "Walk through the selected East Gate into the ravine."):
		return
	var ravine := tree.current_scene
	var ravine_map: Control = ravine.get_node("CampaignHUD").view.get_node("RavineMap")
	await _key(KEY_M)
	if not _expect(ravine_map.modal.visible and tree.paused, "M opens the ravine's own map after leaving the estate."):
		return
	await _button(ravine_map.markers["西门回封地"])
	await _key(KEY_ESCAPE)
	await _walk(ravine.get_node("Player"), ravine.get_node("ExitArea").position)
	if not _expect(tree.current_scene.name == "Main", "West Gate returns inside the estate."):
		return
	await _bind_estate()
	await _key(KEY_M)
	_expect(map.modal.visible and map.target.is_empty() and world.player.position == world.get_node("EastArrival").position,
		"The estate's survey opens again at the new player position with no obsolete target.")
	print("ESTATE_MAP_ROUND_TRIP returned=", world.player.position)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use the survey replay's isolated profile."):
		tree.quit(1)
		return
	seed(4821)
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_ESTATE_MAP_CAPTURES")
	if tree.root.size.x < 900:
		tree.root.size = Vector2i(1280, 720)
	tree.root.notify_mouse_entered()
	await _new_estate()
	if await _load_expansion():
		await _check_input_ownership()
		if await _check_fields() and await _meet_visitor() and await _check_after_dawn():
			await _cross_east_gate()
	tree.paused = false
	tree.unload_current_scene()
	for stream in tree.root.get_node("AudioManager").get_children():
		if stream is AudioStreamPlayer:
			stream.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
