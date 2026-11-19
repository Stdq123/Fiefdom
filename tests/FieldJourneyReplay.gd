extends "res://tests/RotationGuideReplay.gd"

const FIRST_PRIVATE := Vector2i(6, 6)
const SECOND_FIELD := Vector2i(9, 5)
const SECOND_RIPE := Vector2i(10, 6)
const SECOND_ALTERNATE := Vector2i(8, 4)
const ESTATE_WEST_APPROACH := Vector2(-270, -21)

var variant := ""
var controller: RefCounted

func _ready_for_harvest() -> bool:
	var crops := {}
	for cell: Vector2i in [PUBLIC, FIRST_PRIVATE, SECOND_FIELD, SECOND_RIPE, SECOND_ALTERNATE]:
		crops[str(cell)] = {"id": "millet", "age": 2, "growth_nights": 2}
	var fixture := {
		"current_day": 31, "king_storage": 5, "money": 40, "food_storage": 24, "current_stamina": 80,
		"well_fields": [
			{"center_pos": str(PUBLIC), "is_unlocked": true, "reclamation_progress": 4},
			{"center_pos": str(SECOND_FIELD), "is_unlocked": true, "reclamation_progress": 4}],
		"active_crops": crops, "field_seed_plans": {str(SECOND_RIPE): "wheat", str(SECOND_ALTERNATE): "sorghum"},
	}
	var path := "user://field-journey-fixture.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	if not _expect(state.load_game(path) == OK, "Read the isolated two-field fixture."):
		return false
	await tree.scene_changed
	await _use_estate()
	await Campaign.walk_estate_road_to(tree, world, _second_field_mouth())
	var cell_point: Vector2 = world.to_global(world.get_crop_world_pos(SECOND_RIPE))
	await Campaign.walk_straight(tree, world.player, cell_point + Vector2(0, 8))
	await _click(ui.settings_button.get_global_rect().get_center())
	var settings: Control = ui.panel_manager.settings_panel_instance
	await _click(settings.save_button.get_global_rect().get_center())
	if not _expect(settings.save_status.text == "游戏已保存", "Write a manual save in the estate."):
		return false
	await _click(settings.close_button.get_global_rect().get_center())
	return _expect(state.current_day == 31 and state.field_route_status == -1
		and state.field_crop_is_ripe(SECOND_RIPE) and state.field_seed_plans.get(SECOND_RIPE) == "wheat"
		and world.player.global_position.distance_to(cell_point) < 18.0,
		"Use the ordinary checkpoint from beside the ripe second well. Foot %s, crop %s." % [world.player.global_position, cell_point])

func _second_field_mouth() -> Vector2:
	var mouth: Vector2 = world.get_node("Landscape").field_approaches[1][-1]
	return world.to_global(mouth)

func _choose_place(tab: String, label: String) -> bool:
	await _key(KEY_M)
	var chart: Control = ui.estate_map
	await _click(chart.tabs.get_node(tab).get_global_rect().get_center())
	for row: Button in chart.row_buttons:
		if chart.row_buttons[row].title != label:
			continue
		var parent: Node = row.get_parent()
		while parent != null and not parent is ScrollContainer:
			parent = parent.get_parent()
		if parent is ScrollContainer:
			parent.ensure_control_visible(row)
		await tree.process_frame
		await _click(row.get_global_rect().get_center())
		await _key(KEY_ESCAPE)
		return _expect(not chart.modal.visible, "Return to the estate with the selected itinerary.")
	return _expect(false, "Find the local chart row for " + label)

func _click_return(place: Node2D, old := false) -> bool:
	await tree.create_timer(0.12).timeout
	var button: Button = place.get_node("CampaignHUD").field_return_button
	var label := "回井田" if old else "接着田务"
	if not _expect(button.visible and button.text == label
		and tree.root.get_visible_rect().encloses(button.get_global_rect()),
		"The return action reads %s. Got %s, visible %s, at %s in %s." \
		% [label, button.text, button.visible, button.get_global_rect(), tree.root.get_visible_rect()]):
		return false
	if not old:
		_expect(not button.tooltip_text.is_empty() and "井田" in button.tooltip_text, "The tooltip names the earlier well.")
	await _capture("01-return-action")
	if controller:
		await controller._click(button)
	elif variant == "field-journey-worker":
		if not await _return_using_chart(place.market_map):
			return false
	else:
		await _click(button.get_global_rect().get_center())
	return _expect(state.market_trip_target == state.FIELD_RETURN, "The return action starts with the local exit.")

func _return_using_chart(market_chart: Control) -> bool:
	await _click(market_chart.open_button.get_global_rect().get_center())
	await _click(market_chart.get_node("%RegionMap").get_global_rect().get_center())
	var chart: Control = market_chart.region_map
	await _click(chart.region_buttons.get_node("Estate").get_global_rect().get_center())
	var choice: Button = chart.destination_buttons.get(state.FIELD_RETURN)
	if not _expect(choice != null and choice.is_visible_in_tree() and choice.text == "接着田务", "The same return is offered on the regional chart."):
		return false
	await _click(choice.get_global_rect().get_center())
	if not _expect(chart.route_button.text == "接着田务" and "井田 2 · 收获私田" in chart.place_detail.text
		and "田口" in chart.route_label.text, "The regional chart names the saved work and previews the road to the field mouth."):
		return false
	await _capture("01b-regional-return")
	await _click(chart.route_button.get_global_rect().get_center())
	return _expect(not tree.paused, "Confirm the return and resume walking.")

func _walk_to_well(field_id: int, work_label := "") -> bool:
	await _use_estate()
	await tree.process_frame
	var approaches: Dictionary = world.get_node("Landscape").field_approaches
	if not _expect(approaches.has(field_id), "The target well has a physical approach."):
		return false
	var path: PackedVector2Array = directions.road_path
	var entrance: Vector2 = approaches[field_id][-1]
	if not _expect(directions.tracked_place == state.FIELD_RETURN and not path.is_empty() and path[-1] == entrance,
		"The trail follows the road to well %d." % (field_id + 1)):
		return false
	if not work_label.is_empty():
		_expect(("井田 %d" % (field_id + 1)) in ui.hud.cancel_directions.text and work_label in ui.hud.cancel_directions.text,
			"On the estate, the wayfinding ribbon shows the well and the task.")
	await _capture("02-approach-to-well")
	for point: Vector2 in path.slice(1):
		await Campaign.walk_straight(tree, world.player, world.to_global(point))
	return _expect(world.player.global_position.distance_to(world.to_global(entrance)) < 5.0
		and state.market_trip_target.is_empty(), "Complete the trip on foot at the indicated field mouth.")

func _save_at_market(market: Node2D, wanted: Dictionary) -> bool:
	await _key(KEY_ESCAPE)
	var settings: Control = market.settings
	if not _expect(settings.visible, "Open the market settings."):
		return false
	await _click(settings.save_button.get_global_rect().get_center())
	if not _expect(settings.save_status.text == "游戏已保存", "Write a normal manual save while away from the field."):
		return false
	await _click(settings.close_button.get_global_rect().get_center())
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _click(tree.current_scene.continue_button.get_global_rect().get_center())
	if tree.current_scene == null:
		await tree.scene_changed
	return _expect(tree.current_scene.scene_file_path == state.WEST_MARKET_SCENE
		and state.get("field_return_work") == wanted and state.regional_destination() == state.FIELD_RETURN,
		"Continue restores the exact field job and the return route in the market.")

func _return_from_market() -> bool:
	var market := tree.current_scene as Node2D
	await Campaign.walk_to_market_exit(tree, market)
	if not _expect(await Campaign.walk_through_gates(tree, &"ui_right", state.WEST_ROAD_SCENE), "Leave the market for the bridge."):
		return false
	var road := tree.current_scene as Node2D
	var path: PackedVector2Array = road.network.route_between(road.player.position, road.get_node("EstateArrival").position)
	for point: Vector2 in path.slice(1):
		await Campaign.walk_straight(tree, road.player, road.to_global(point))
	return _expect(await Campaign.walk_through_gates(tree, &"ui_right", state.ESTATE_SCENE), "Cross the bridge home.")

func _take_private_batch(cell: Vector2i) -> void:
	var reach: Vector2 = world.to_global(world.get_crop_world_pos(cell)) + Vector2(0, 8)
	await Campaign.walk_straight(tree, world.player, reach)
	var tribute: int = state.king_storage
	var millet: int = state.crop_stock.count("millet")
	var shift := InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	shift.keycode = KEY_SHIFT
	if controller:
		await controller._aim(_point_on_field(cell))
		controller._axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	else:
		var point := _point_on_field(cell)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		tree.root.push_input(motion, true)
		shift.pressed = true
		Input.parse_input_event(shift)
		Input.flush_buffered_events()
	await tree.process_frame
	var hint: Label = world.tile_map.get_node("FieldCursor").label
	_expect(hint.is_visible_in_tree() and "私田" in hint.text and "续播" in hint.text,
		"The resumed batch previews private harvest and replanting.")
	await _capture("03-private-replant-preview")
	if controller:
		await controller._tap(JOY_BUTTON_A)
		controller._axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	else:
		await _click(_point_on_field(cell))
		shift = shift.duplicate() as InputEventKey
		shift.pressed = false
		Input.parse_input_event(shift)
		Input.flush_buffered_events()
	await tree.process_frame
	_expect(state.active_crops.get(cell, {}).get("id") == ("wheat" if cell == SECOND_RIPE else "sorghum")
		and state.king_storage == tribute and state.crop_stock.count("millet") > millet
		and state.field_crop_is_ripe(PUBLIC) and state.field_crop_is_ripe(SECOND_FIELD)
		and state.field_crop_is_ripe(FIRST_PRIVATE), "Take the scoped batch in the second well, replant and settle private stock only.")
	if controller:
		_expect(controller.failures == 0, "The gamepad pointer reached the controls and field.")
	print("FIELD_JOURNEY_HARVEST day=", state.current_day, " plot=", cell, " tribute=", state.king_storage,
		" millet=", state.crop_stock.count("millet"), " gamepad=", controller != null)

func _market_journey() -> void:
	if variant == "field-journey-previous":
		var manual_path: String = state.latest_saved_game().get("path", "")
		var digest := FileAccess.get_sha256(manual_path)
		if not _expect(not digest.is_empty(), "Use the previous export's ordinary save."):
			return
		await _click(tree.current_scene.continue_button.get_global_rect().get_center())
		await _use_estate()
		if not _expect(FileAccess.get_sha256(manual_path) == digest and state.current_day == 31,
			"Read the old save without rewriting it."):
			return
		print("FIELD_JOURNEY_PREVIOUS_SAVE sha256=", digest)
	elif not await _ready_for_harvest():
		return
	await _click(ui.hud.sow_from_plan.get_global_rect().get_center())
	await _click(ui.hud.replant_after_harvest.get_global_rect().get_center())
	await _click(ui.hud.farm_status.get_global_rect().get_center())
	await _click(ui.estate_map.private_harvest_route.get_global_rect().get_center())
	if not _expect(world.sow_from_plan and world.replant_after_harvest and directions.tracked_plot == SECOND_RIPE
		and state.field_route_scope == state.FieldScope.PRIVATE, "Set private harvest with replanting at the nearer plot in well 2."):
		return
	if not await _choose_place("Places", "西市"):
		return
	await Campaign.walk_straight(tree, world.player, _second_field_mouth())
	await Campaign.walk_estate_road_to(tree, world, ESTATE_WEST_APPROACH)
	if not _expect(world.player.global_position.distance_to(ESTATE_WEST_APPROACH) < 5.0,
		"Reach the estate's west approach. Foot %s." % world.player.global_position):
		return
	var arrived := await Campaign.walk_through_gates(tree, &"ui_left", state.WEST_MARKET_SCENE)
	if not _expect(arrived, "Walk along the west road into the market. Reached " + tree.current_scene.scene_file_path):
		return
	var market := tree.current_scene as Node2D
	var old := variant == "field-journey-before"
	var worked := variant == "field-journey-worker"
	var expected := SECOND_RIPE
	if worked:
		var worker := RetainerData.new("阿午", "士人", RetainerData.School.CONFUCIAN)
		worker.duty = RetainerData.Duty.HARVEST
		worker.assigned_area = SECOND_RIPE
		state.retainers.append(worker)
		await tree.create_timer(state._field_work_seconds(worker) + 0.08).timeout
		worker.duty = RetainerData.Duty.REEL
		expected = SECOND_ALTERNATE
		if not _expect(not state.field_crop_is_ripe(SECOND_RIPE) and state.field_crop_is_ripe(expected)
			and state.away_field_report.harvested == 1, "A single off-screen harvest finishes the original plot while the player is at the market."):
			return
	if not await _click_return(market, old):
		return
	if not old and not worked:
		var work: Dictionary = state.get("field_return_work")
		if not _expect(work.get("cell") == SECOND_RIPE and work.get("scope") == state.FieldScope.PRIVATE
			and work.get("plan") == true and work.get("replant") == true, "Retain the chosen plot, scope and replant mode after the trip changes."):
			return
		if not await _save_at_market(market, work.duplicate()):
			return
	if not await _return_from_market() or not await _walk_to_well(0 if old else 1, "" if old else "收获私田"):
		return
	if old:
		_expect(directions.tracked_plot == null and state.field_route_status == -1,
			"The previous package ends its return at well 1 with the earlier field task lost.")
		print("FIELD_JOURNEY_BEFORE selected=", SECOND_RIPE, " returned_well=1 mark=", directions.tracked_plot)
		return
	if not _expect(directions.tracked_plot == expected and state.field_route_scope == state.FieldScope.PRIVATE
		and world.sow_from_plan and world.replant_after_harvest and state.get("field_return_work").is_empty(),
		"At well 2, resume the chosen plot or the next eligible private plot, retaining the batch mode."):
		return
	print("FIELD_JOURNEY_RETURN selected=", SECOND_RIPE, " resumed=", expected, " returned_well=2 worker=", worked)
	await _take_private_batch(expected)

func _rotation_journey() -> void:
	await _click(tree.current_scene.new_button.get_global_rect().get_center())
	await _use_estate()
	var spawn: Vector2 = world.player.global_position
	if not await _first_batch() or not await _start_rotation():
		return
	await Campaign.walk_to(tree, world.player, spawn)
	if not await _choose(await _rotation_guide(), "标出这格私田 · 换菽种"):
		return
	var cell: Vector2i = directions.tracked_plot
	if not await _choose_place("Ravine", "野果坳"):
		return
	await Campaign.walk_estate_road_to(tree, world, world.get_node("EastArrival").global_position)
	if not _expect(await Campaign.walk_through_gates(tree, &"ui_right", state.WILDERNESS_SCENE), "Walk through the east gate."):
		return
	var ravine := tree.current_scene as Node2D
	var fruit := ravine.get_node("WildFruit") as Node2D
	await Campaign.walk_ravine_to(tree, ravine, fruit.global_position + Vector2(0, 16))
	var grain: int = state.food_storage
	await _key(KEY_E)
	if not _expect(state.food_storage > grain, "Pick up wild fruit during the outing."):
		return
	if not await _click_return(ravine):
		return
	await Campaign.walk_to_ravine_exit(tree, ravine)
	if not _expect(await Campaign.walk_through_gates(tree, &"ui_left", state.ESTATE_SCENE), "Return through the east gate."):
		return
	if not await _walk_to_well(0, "轮作私田"):
		return
	if not _expect(directions.tracked_plot == cell and state.rotation_route_cell == cell and world.current_seed_id == "beans",
		"Resume the original rotation plot with bean seed already selected."):
		return
	if not state.tilled_cells.has(cell):
		await _click(_point_on_field(cell))
	await _click(_point_on_field(cell))
	_expect(state.active_crops.get(cell, {}).get("id") == "beans", "Continue the actual rotation by planting beans on the saved plot.")
	await _capture("03-beans-planted-after-return")
	print("FIELD_JOURNEY_ROTATION day=", state.current_day, " plot=", cell, " fruit=", state.food_storage - grain)

func run_journey(game_tree: SceneTree, captures := "", scenario := "field-journey") -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated field journey profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = captures
	variant = scenario
	seed(66907)
	tree.root.notify_mouse_entered()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	print("FIELD_JOURNEY_DISPLAY driver=", DisplayServer.get_name(), " window=", DisplayServer.window_get_size(),
		" view=", tree.root.get_visible_rect().size)
	if variant == "field-journey-pad":
		controller = load("res://tests/GamepadReplay.gd").new()
		controller.tree = tree
		controller.pad = tree.root.get_node("GamepadInput")
	if variant == "field-journey-rotation":
		await _rotation_journey()
	else:
		await _market_journey()
	await _finish()
