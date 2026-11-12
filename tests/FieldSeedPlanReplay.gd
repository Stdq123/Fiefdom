extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const SITE := Vector2i(6, 5)
const RICE := Vector2i(4, 5)
const MANUAL := Vector2i(5, 6)
const FALLOW := Vector2i(6, 6)
const PUBLIC := Vector2i(9, 5)
const ORCHARD := Vector2i(10, 5)

var tree: SceneTree
var state: Node
var world: Node2D
var ui: CanvasLayer
var capture_dir := ""
var failed := false

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failed = true
		push_error(message)
	return condition

func _click(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		tree.root.push_input(event, true)
		await tree.process_frame

func _button(button: Button) -> void:
	await tree.process_frame
	var bounds := button.get_global_rect()
	if _expect(button.is_visible_in_tree() and tree.root.get_visible_rect().encloses(bounds), "Visible button: " + button.text):
		await _click(bounds.get_center())

func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		tree.root.push_input(event, true)
		await tree.process_frame

func _snapshot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)
	print("SEED_PLAN_FRAME ", name, " window=", tree.root.size, " image=", image.get_size())

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")

func _fixture() -> bool:
	if not _expect(state.start_new_game() == OK, "Start a normal estate for the prepared expansion fixture."):
		return false
	await tree.scene_changed
	state.current_day = 32
	state.day_progress = 0.16
	state.current_rank = state.Rank.ZHONG_SHI
	state._update_max_well_fields()
	state.money = 300
	state.food_storage = 24
	state.balance.raid_first_day = 10000
	state.tech_unlocked.irrigation = true
	var teacher := RetainerData.new("季青", "士人", RetainerData.School.CONFUCIAN)
	teacher.duty = RetainerData.Duty.TEACH
	teacher.assigned_area = PUBLIC
	state.retainers.append(teacher)
	if not _expect(state.add_well_field(PUBLIC), "Prepare the second well field."):
		return false
	for night in range(4):
		state.advance_reclamation(1)
	for cell: Vector2i in [SITE, RICE, MANUAL, FALLOW, PUBLIC, ORCHARD]:
		state.tilled_cells[cell] = true
	for cell: Vector2i in [PUBLIC, ORCHARD]:
		var id := "millet" if cell == PUBLIC else "mulberry"
		state.active_crops[cell] = {"id": id, "data": tree.root.get_node("ItemManager").get_crop(id),
			"age": 6, "growth_nights": 6, "watered": false, "requires_channel": false}
	if not _expect(state.save_game() == OK and state.load_game() == OK, "Load the expansion fixture through a save."):
		return false
	await tree.scene_changed
	_estate()
	await tree.process_frame
	return true

func _management() -> Control:
	await _button(ui.manage_button)
	return ui.panel_manager.management_panel_instance

func _field(panel: Control, field_id: int) -> void:
	var index: int = panel.well_field_selector.get_item_index(field_id)
	panel.well_field_selector.select(index)
	panel.well_field_selector.item_selected.emit(index)
	await tree.process_frame

func _plot(panel: Control, cell: Vector2i) -> Button:
	for tile: Button in panel.map_grid_container.get_children():
		if tile.grid_pos == cell:
			return tile
	return null

func _plan(panel: Control, cell: Vector2i, id: String) -> Button:
	var picker: OptionButton = panel.seed_plan_picker
	for index in range(1, picker.item_count):
		if picker.get_item_metadata(index) == id:
			if id == "beans":
				await _button(picker)
				var menu := picker.get_popup()
				_expect(menu.visible, "The seed picker opens its crop menu.")
				await _snapshot("00-seed-menu")
				menu.hide()
				await tree.process_frame
			picker.select(index)
			break
	var tile := _plot(panel, cell)
	await _button(tile)
	return tile

func _wait_for(test: Callable, message: String, seconds := 10.0) -> bool:
	for frame in roundi(seconds * Engine.physics_ticks_per_second):
		if test.call():
			return true
		await tree.physics_frame
	return _expect(false, message)

func _at_estate() -> bool:
	var start_stamina: int = state.current_stamina
	var panel := await _management()
	var site_tile := await _plan(panel, SITE, "beans")
	var rice_tile := await _plan(panel, RICE, "rice")
	await _plan(panel, FALLOW, "hemp")
	var fallow_tile := await _plan(panel, FALLOW, "")
	_expect("续播 菽" in site_tile.text and "待渠水" in rice_tile.text and "续播" not in fallow_tile.text,
		"The grid shows the actual plan, blocked rice and a cleared tile.")
	await _snapshot("01-first-field-plans")
	await _field(panel, 1)
	var public_tile := await _plan(panel, PUBLIC, "sorghum")
	var orchard_tile := await _plan(panel, ORCHARD, "hemp")
	_expect("公田" in public_tile.text and "续播 稷" in public_tile.text and "续播" not in orchard_tile.text,
		"The second field preserves public identity and leaves perennial mulberry in place.")
	await _snapshot("02-second-field-plans")
	await _field(panel, 0)
	await _plan(panel, MANUAL, "hemp")
	await _button(panel.get_node("CloseButton"))
	var worker: Retainer = world.retainer_instances[state.retainers[0]]
	var sowing := func() -> bool:
		return (worker.target_grid_pos == MANUAL and worker.current_state == Retainer.State.WORK
			and worker.tool_gesture.frame == ToolGesture.Action.SOW)
	if not await _wait_for(sowing, "The worker goes to the planned empty tile and takes out seed."):
		return false
	var tile_map: TileMapLayer = world.tile_map
	world.player.global_position = world.to_global(world.get_crop_world_pos(MANUAL)) + Vector2(0, 24)
	world.player.camera.force_update_scroll()
	await tree.process_frame
	await _key(KEY_4)
	await _click(tile_map.get_global_transform_with_canvas() * tile_map.map_to_local(MANUAL))
	if not await _wait_for(func(): return state.active_crops.get(SITE, {}).get("watered", false),
		"The same worker sows and waters the other planned plot."):
		return false
	var crops: Dictionary = state.active_crops
	_expect(crops.has(SITE) and crops[SITE].id == "beans" and crops.has(MANUAL) and crops[MANUAL].id == "wheat"
		and state.field_seed_plans[MANUAL] == "hemp" and state.current_stamina == start_stamina - 2
		and not crops.has(RICE) and not crops.has(FALLOW),
		"Only the manual sow costs stamina and the retainer preserves that crop, the next plan and the fallow tiles.")
	print("SEED_PLAN_ESTATE beans=", crops.has(SITE), " manual=", crops.get(MANUAL, {}).get("id"),
		" stamina_spent=", start_stamina - state.current_stamina)
	return not failed

func _cross(action: StringName, destination: String) -> bool:
	Input.action_press(action)
	for frame in 52:
		await tree.physics_frame
		if tree.root.get_node("MapTravel").active:
			break
	Input.action_release(action)
	await Campaign.wait_for_map_change(tree)
	await tree.process_frame
	return _expect(tree.current_scene.scene_file_path == destination, "Walk through the gate to " + destination)

func _market() -> bool:
	for point: Vector2 in [Vector2(66, 67), Vector2(-181, 67), Vector2(-181, 0), Vector2(-270, -21)]:
		await Campaign.walk_to(tree, world.player, point)
	var panel := await _management()
	var picker: OptionButton = panel.retainer_list_container.get_child(1).duty_picker
	picker.item_selected.emit(picker.get_item_index(RetainerData.Duty.HARVEST))
	await _button(panel.get_node("CloseButton"))
	return await _cross(&"ui_left", state.WEST_MARKET_SCENE)

func _market_work() -> bool:
	var finished := func() -> bool:
		return (state.away_field_report.get("sown", 0) == 1 and state.away_field_report.get("harvested", 0) == 2
			and state.active_crops.get(PUBLIC, {}).get("watered", false))
	if not await _wait_for(finished, "The market visit completes both harvests and sows and waters the public field.", 15.0):
		return false
	var report: Dictionary = state.away_field_report
	var crop: Dictionary = state.active_crops[PUBLIC]
	_expect(crop.id == "sorghum" and crop.age == 0 and report.sown == 1 and report.tribute == 1
		and report.stock == 1 and state.king_storage == 1 and state.player_inventory == 1
		and state.active_crops[ORCHARD].id == "mulberry" and not state.active_crops.has(RICE)
		and not state.active_crops.has(FALLOW), "The planned public resowing keeps the original tribute and the private mulberry harvest.")
	print("SEED_PLAN_AWAY ", state.away_field_summary(), " crop=", crop.id)
	await _key(KEY_ESCAPE)
	for button: Button in tree.current_scene.settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	if not _expect(tree.current_scene.settings.save_status.text == "游戏已保存", "Save using the market settings."):
		return false
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	return _expect(tree.current_scene.scene_file_path == state.WEST_MARKET_SCENE and state.away_field_report.sown == 1
		and state.field_seed_plans.size() == 4 and state.field_seed_plans[PUBLIC] == "sorghum"
		and state.active_crops[PUBLIC].watered, "Continue in the market with the plans and the completed work.")

func _dawn() -> void:
	await Campaign.walk_to_market_exit(tree, tree.current_scene)
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return
	_estate()
	var notice: Label = tree.current_scene.get_node("CampaignHUD").notice
	_expect(notice.visible and "补播 1 格" in notice.text, "Returning shows the resowing in the field report.")
	await Campaign.walk_to(tree, world.player, Vector2(-181, 15))
	await _button(ui.hud.rations_button)
	var rations: Control = ui.get_node("Control/NightRationsPanel")
	_expect("补播 1 格" in rations.field_forecast.text and "国库 +1" in rations.field_forecast.text,
		"Tonight's plan shows the resowing and tribute together.")
	await _snapshot("03-field-work-report")
	var evening_food: int = state.food_storage
	await _button(rations.get_node("%Sleep"))
	await tree.create_timer(1.2).timeout
	_expect(state.current_day == 33 and state.food_storage == evening_food - 3 and state.active_crops[PUBLIC].age == 1
		and state.field_seed_plans.size() == 4 and not state.active_crops.has(RICE),
		"The watered plot grows overnight, plans stay, and the rice waits for water.")
	var route: Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 5)]
	if not _expect(state.build_channel_path(route) == state.ChannelSite.AVAILABLE, "Connect the existing channel to the rice plot."):
		return
	if await _wait_for(func(): return state.active_crops.has(RICE), "The rice gets planted after the channel is connected."):
		var rice: Dictionary = state.active_crops[RICE]
		_expect(rice.id == "rice" and rice.requires_channel and rice.growth_nights == state.sowing_nights(rice.data)
			and state.irrigation.supplies(RICE), "Delegated rice uses the current season and the normal irrigation rules.")
		print("SEED_PLAN_DAWN day=", state.current_day, " food_spent=", evening_food - state.food_storage,
			" public_age=", state.active_crops[PUBLIC].age, " irrigated_rice_nights=", rice.growth_nights)
		var panel := await _management()
		await _snapshot("04-irrigated-rice")
		await _button(panel.get_node("CloseButton"))
		await _check_repeated_sowing()

func _check_repeated_sowing() -> void:
	var public_crop: Dictionary = state.active_crops[PUBLIC]
	for night in public_crop.growth_nights - public_crop.age:
		if not await _wait_for(func(): return public_crop.watered, "The keeper waters the planned crop before sleep."):
			return
		await _button(ui.sleep_button)
		await tree.create_timer(1.2).timeout
	var repeated := func() -> bool:
		return state.king_storage == 2 and state.active_crops.get(PUBLIC, {}).get("id") == "sorghum"
	if await _wait_for(repeated, "After the next public harvest the same plan sows another crop."):
		print("SEED_PLAN_REPEAT day=", state.current_day, " tribute=", state.king_storage, " crop=", state.active_crops[PUBLIC].id)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated save profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_SEED_CAPTURES")
	tree.root.notify_mouse_entered()
	seed(3112)
	if await _fixture():
		if not state.has_method("planned_field_seed"):
			if await _market():
				await tree.create_timer(13.0).timeout
				_expect(state.king_storage == 1 and not state.active_crops.has(PUBLIC) and not state.active_crops.has(SITE),
					"The earlier package settles the harvest and leaves the empty plots for the player to sow.")
				print("SEED_PLAN_BASELINE tribute=", state.king_storage, " public_empty=", not state.active_crops.has(PUBLIC),
					" first_plot_empty=", not state.active_crops.has(SITE))
		elif await _at_estate() and await _market() and await _market_work():
			await _dawn()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
