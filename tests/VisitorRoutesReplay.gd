extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const HOME := Vector2(42, 98)
const FARM := [Vector2i(5, 5), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)]
const ROAD_KEEPER := VisitorData.ROAD_KEEPER

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
		event.pressed = pressed
		event.keycode = code
		event.physical_keycode = code
		tree.root.push_input(event, true)
	await tree.process_frame
	await tree.process_frame

func _click(point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	tree.root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.pressed = pressed
		event.position = point
		event.global_position = point
		event.button_index = button
		tree.root.push_input(event, true)
	await tree.process_frame

func _button(control: Control) -> void:
	await _click(control.get_global_rect().get_center())
	await tree.process_frame
	await tree.process_frame

func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)
	print("VISITOR_ROUTE_FRAME ", name, " ", image.get_size())

func _bind_estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame

func _title(continuing: bool) -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	var button: Button = tree.current_scene.continue_button if continuing else tree.current_scene.new_button
	await _button(button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.name == "Main", "The title action must open the estate."):
		return false
	await _bind_estate()
	return true

func _walk(point: Vector2) -> void:
	await Campaign.walk_to(tree, world.player, world.to_global(point))

func _meet(actor: Node2D, offset := Vector2(0, -12)) -> Control:
	await _walk(actor.position + offset)
	await _key(KEY_E)
	return ui.get_node_or_null("Control/DialoguePanel") as Control

func _choose(dialog: Control, prefix: String) -> bool:
	if dialog:
		for button: Button in dialog.options_container.get_children():
			if button.text.begins_with(prefix) and not button.disabled:
				await _button(button)
				return true
	return _expect(false, "The conversation should offer " + prefix)

func _night() -> void:
	await _button(ui.sleep_button)
	await tree.create_timer(1.05).timeout

func _cell_point(cell: Vector2i) -> Vector2:
	var tiles: TileMapLayer = world.tile_map
	return tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)

func _farm() -> void:
	await _walk(HOME)
	for cell: Vector2i in FARM:
		for action in range(3):
			if world.field_action(cell) not in [world.FieldAction.TILL, world.FieldAction.SOW,
				world.FieldAction.WATER, world.FieldAction.HARVEST]:
				break
			await _click(_cell_point(cell))

func _defend() -> void:
	if state.raid_day == 0:
		return
	for volley in range(20):
		var raider := tree.get_first_node_in_group("estate_raiders") as Node2D
		if not is_instance_valid(raider):
			break
		await _click(raider.get_global_transform_with_canvas().origin, MOUSE_BUTTON_RIGHT)
		for frame in range(10):
			await tree.physics_frame
	_expect(state.raid_day == 0 and state.outcome == state.Outcome.RUNNING, "The ordinary bow protects the fields on the way to the return visit.")

func _feed_household() -> void:
	if state.food_storage >= 4 or state.player_inventory == 0:
		return
	await _button(ui.reclaim_button)
	var survey := ui.get_node_or_null("Control/ReclamationPanel")
	if not _expect(survey != null and survey.market_button.visible, "Open the market through the preparation ledger."):
		return
	await _button(survey.market_button)
	var management: Control = ui.panel_manager.management_panel_instance
	var market: Control = management.market_panel
	await _button(market.all_crops)
	await _button(market.convert_button)
	await _button(management.get_node("CloseButton"))

func _read_road_journal() -> Control:
	await _button(ui.hud.neighbors_button)
	var journal: Control = ui.panel_manager.management_panel_instance.neighbor_journal
	await _button(journal.roster.get_node(ROAD_KEEPER))
	return journal

func _close_management() -> void:
	await _button(ui.panel_manager.management_panel_instance.get_node("CloseButton"))

func _build_rest_stop() -> bool:
	var arrived := false
	while state.current_day < 22 and failures == 0:
		await _defend()
		var day: int = state.current_day
		if day in [2, 7, 12]:
			var visitor: Visitor = world.current_visitor_actor()
			if not _expect(visitor != null and visitor.data.name == ROAD_KEEPER and visitor.position == VisitorData.SOUTH_POST,
				"Ji Qing uses the usual meeting place while the road work is pending."):
				return false
			var action: String = {2: "交谈", 7: "送路粮", 12: "修歇脚处"}[day]
			var dialog := await _meet(visitor)
			if not await _choose(dialog, action):
				return false
		await _farm()
		await _feed_household()
		if day == 13:
			_expect(state.road_rest_built() and state.road_rest_paid_day == 12, "The funded bench opens the following morning.")
			var journal := await _read_road_journal()
			_expect("第 22 天 · 亭西歇脚处" in journal.where.text, "The appointment predicts Ji Qing's new stop.")
			print("VISITOR_ROUTE_APPOINTMENT ", journal.where.text)
			await _close_management()
		if day == 21:
			await _walk(VisitorData.SOUTH_POST + Vector2(13, 11))
		await _night()
		arrived = state.current_day == 22
	return _expect(arrived and state.road_provisions_delivered and state.retainers.size() == 1,
		"Deliver the road provisions and fund the bench while Ji Qing stays a visitor.")

func _select_moving_visitor(actor: Visitor) -> bool:
	await _key(KEY_M)
	var map: Control = ui.estate_map
	var campaign := tree.current_scene.get_node("CampaignHUD")
	if not _expect(map.modal.visible and tree.paused, "Open the chart while the visitor is on the road."):
		return false
	_expect(not campaign.notice.text.is_empty() and not campaign.notice.visible, "The current world notice stays behind the chart.")
	await _button(map.tabs.get_node("People"))
	for button: Button in map.row_buttons:
		var entry: Dictionary = map.row_buttons[button]
		if entry.title == actor.data.name:
			_expect("正往亭西歇脚处" in entry.detail and entry.point == actor.position,
				"The chart plots the person's current position and reports the destination.")
			await _button(button)
			_expect(map.target.point == actor.position and ui.directions.tracked_neighbor == actor.data.name,
				"Set directions to the walking person.")
			await _capture("02-person-on-the-map")
			await _key(KEY_ESCAPE)
			_expect(campaign.notice.visible, "World notices return when the chart closes.")
			return true
	return _expect(false, "The chart must list the walking visitor.")

func _check_road_walk() -> bool:
	var visitor: Visitor = world.current_visitor_actor()
	if not _expect(visitor != null and visitor.data.name == ROAD_KEEPER and visitor.walking_to_stop
		and visitor.sprite.walking and "正往亭西歇脚处" in ui.hud.visitor_label.text,
		"On the promised morning Ji Qing walks toward the bench."):
		return false
	await _capture("01-walking-to-the-bench")
	if not await _select_moving_visitor(visitor):
		return false
	var mark: Dictionary = ui.directions.destination()
	for tick in range(7):
		await tree.physics_frame
	_expect(ui.directions.destination().point.distance_to(mark.point) > 3.0, "The direction follows the visitor as he walks.")
	_expect(world.player.interaction_target == visitor, "The walking visitor can be approached along the real path.")
	await _key(KEY_E)
	var dialog := ui.get_node_or_null("Control/DialoguePanel")
	if not _expect(dialog != null and dialog.name_label.text == ROAD_KEEPER and "正往亭西" in dialog.context_label.text,
		"E can stop a visiting neighbor on the way."):
		return false
	var waiting := visitor.position
	await tree.create_timer(0.3).timeout
	_expect(visitor.position == waiting and not visitor.sprite.walking, "The visitor waits in place while speaking.")
	await _key(KEY_ESCAPE)
	await tree.create_timer(2.0).timeout
	var stop: Node2D = world.get_node("RoadRest")
	if not _expect(not visitor.walking_to_stop and visitor.position.distance_to(stop.position) < 30.0
		and "照看水瓮" in visitor.hint.text and "照看水瓮" in ui.hud.visitor_label.text,
		"The conversation releases the visitor to the completed rest stop."):
		return false
	print("VISITOR_ROUTE_BENCH day=", state.current_day, " foot=", visitor.position, " stop=", stop.position)
	await _capture("03-at-the-water-jar")
	var journal := await _read_road_journal()
	_expect("亭西歇脚处" in journal.where.text and "照看水瓮" in journal.where.text and journal.locate_button.visible,
		"The neighbor journal describes the same occupied station.")
	await _close_management()
	dialog = await _meet(stop, Vector2(-12, 0))
	_expect(dialog != null and dialog.name_label.text == "亭西歇脚处", "The bench still has its own interaction beside the visitor.")
	await _key(KEY_ESCAPE)
	var arrived := visitor.position
	if not await _title(true):
		return false
	visitor = world.current_visitor_actor()
	return _expect(state.current_day == 22 and visitor != null and visitor.position == arrived and not visitor.walking_to_stop,
		"Continuing this dawn restores the visitor at the station.")

func _load_fixture(data: Dictionary) -> bool:
	var path := "user://visitor-route-check.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _expect(file != null, "Write the visitor fixture to the isolated profile."):
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	if not _expect(state.load_game(path) == OK, "Restore the existing story fields from a fixture."):
		return false
	await tree.scene_changed
	await _bind_estate()
	return true

func _handoff_at_the_garden() -> void:
	if not await _load_fixture({"current_day": 11, "visitor_encounters": [VisitorData.RAVINE_GUIDE],
		"ravine_journal": {"recorded_days": [5, 6, 7]}}):
		return
	var visitor: Visitor = world.neighbor_actor(VisitorData.RAVINE_GUIDE)
	if not _expect(visitor != null and visitor.data.name == VisitorData.RAVINE_GUIDE
		and visitor.position == VisitorData.BAMBOO_PATH, "Before the handoff Pu Ning still waits at the bamboo path."):
		return
	var dialog := await _meet(visitor)
	if not await _choose(dialog, "交溪行手记"):
		return
	_expect(visitor == world.neighbor_actor(VisitorData.RAVINE_GUIDE) and visitor.walking_to_stop and state.ravine_journal.garden_day == 11,
		"The same visitor starts walking when the handoff plants the garden.")
	for tick in 210:
		if not visitor.walking_to_stop:
			break
		await tree.physics_frame
	var garden: Node2D = world.get_node("HerbGarden")
	_expect(garden.visible and not visitor.walking_to_stop and visitor.position.distance_to(garden.position) < 33.0
		and "查看药苗" in ui.hud.visitor_label.text, "Pu Ning follows the new path to the actual herb plot.")
	await _capture("04-herb-garden-after-handoff")
	print("VISITOR_ROUTE_GARDEN day=", state.current_day, " foot=", visitor.position)

func _check_other_stops() -> void:
	var fixtures := [
		[{"current_day": 8, "first_channel_growth_day": 6, "channel_survey_day": 7}, VisitorData.WATER_GUIDE, "水源旁", "看量水尺"],
		[{"current_day": 9, "silk_sample_day": 4, "silk_workshop": {"built": true}}, VisitorData.SILK_MERCHANT, "西廊绸架", "整理样绸"],
		[{"current_day": 16, "raids_defeated": 1, "last_defense": {"day": 9, "kind": 0, "losses": 0, "guard": ""},
			"east_watch_day": 12}, VisitorData.EAST_WATCHER, "东岗守备牌", "查看守备"]
	]
	for fixture: Array in fixtures:
		if not await _load_fixture(fixture[0]):
			return
		var visitor: Visitor = world.current_visitor_actor()
		_expect(visitor != null and visitor.data.name == fixture[1] and visitor.visit_location() == fixture[2]
			and not visitor.walking_to_stop and visitor.position == visitor.visit_path[-1]
			and fixture[3] in visitor.visit_note() and fixture[3] in ui.hud.visitor_label.text,
			"Restore the completed activity at " + str(fixture[2]))
		print("VISITOR_ROUTE_RESTORED ", fixture[1], " ", fixture[2])

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_VISITOR_ROUTE_CAPTURES")
	seed(927)
	if tree.root.size.x < 900:
		tree.root.size = Vector2i(1280, 720)
	tree.root.notify_mouse_entered()
	if await _title(false) and await _build_rest_stop() and await _check_road_walk():
		await _handoff_at_the_garden()
		await _check_other_stops()
	tree.paused = false
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
