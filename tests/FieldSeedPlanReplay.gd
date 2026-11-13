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
var steward_capture_path := ""
var failed := false
var steward_story := false

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
	state.current_day = 35 if steward_story else 32
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
			if id in ["beans", FieldSeedPlan.SEASONAL]:
				await _button(picker)
				var menu := picker.get_popup()
				_expect(menu.visible, "The seed picker opens its crop menu.")
				if id == "beans":
					await _snapshot("00-seed-menu")
				menu.hide()
				await tree.process_frame
			picker.select(index)
			picker.item_selected.emit(index)
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
	var crossed := await Campaign.walk_through_gates(tree, action, destination, 52)
	await tree.process_frame
	return _expect(crossed, "Walk through the gate to " + destination)

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

func _choose_from_menu(picker: OptionButton, item_id: int) -> void:
	await _button(picker)
	var menu := picker.get_popup()
	if _expect(menu.visible, "Open the assignment menu from the visible control."):
		var index := picker.get_item_index(item_id)
		picker.select(index)
		picker.item_selected.emit(index)
		menu.hide()
		await tree.process_frame

func _steward_handover() -> void:
	var panel := await _management()
	var keeper: RetainerData = state.retainers[0]
	var other: RetainerData = state.retainers[1]
	var public: Vector2i = state.FIRST_FIELD_CENTER
	state.tilled_cells[public] = true
	state.set_field_seed_plan(RICE, "rice")
	var current_rations: int = state.retainer_food_cost()
	await _field(panel, 0)
	await _choose_from_menu(panel.steward_picker, 0)
	_expect(keeper.duty == RetainerData.Duty.FIELD and not state.field_seed_plans.has(public)
		and not state.field_seed_plans.has(SITE), "Previewing a handover leaves the roster and crops alone.")
	_expect("公田 1 格" in panel.steward_preview.text and "私田 3 格" in panel.steward_preview.text
		and str(state.balance.specialist_food_per_night) in panel.steward_preview.text,
		"The quote lists the fillable public and private plots and the ration change.")
	var public_seed: String = state.tribute_seed()
	await _snapshot("00a-steward-handover")
	await _button(panel.apply_steward)
	_expect(keeper.duty == RetainerData.Duty.STEWARD and keeper.assigned_area == public
		and state.field_seed_plans.get(public) == public_seed and state.field_seed_plans.get(RICE) == "rice"
		and state.field_seed_plans.get(SITE) == FieldSeedPlan.SEASONAL and not state.field_seed_plans.has(PUBLIC)
		and state.retainer_food_cost() == current_rations + state.balance.specialist_food_per_night,
		"One handover fills only unplanned tilled plots of the selected field and preserves fixed rice.")
	await _field(panel, 1)
	state.tax_reform_choice = state.TaxReformChoice.REFORMED
	tree.root.get_node("GameEvents").tax_reform_choice_made.emit(state.tax_reform_choice)
	await _choose_from_menu(panel.steward_picker, 1)
	_expect("公田 1 格" not in panel.steward_preview.text and "私田 1 格" in panel.steward_preview.text,
		"After reform the tilled center is eligible for private sowing and the perennial mulberry is excluded.")
	await _button(panel.apply_steward)
	_expect(other.duty == RetainerData.Duty.STEWARD and other.assigned_area == PUBLIC
		and state.field_seed_plans.get(PUBLIC) == FieldSeedPlan.SEASONAL and not state.field_seed_plans.has(ORCHARD)
		and state.active_crops[PUBLIC].id == "millet" and state.active_crops[ORCHARD].id == "mulberry",
		"The second field uses the private plan after reform and preserves both standing crops.")
	await _button(panel.get_node("CloseButton"))
	print("FIELD_STEWARD_HANDOVER public=", public_seed, " fixed_rice=", state.field_seed_plans[RICE],
		" reformed_center=", state.field_seed_plans[PUBLIC], " ration=", state.retainer_food_cost())

func _steward_work() -> void:
	var steward: RetainerData = state.retainers[1]
	_expect(FieldSeedPlan.seasonal_seed(state.Season.SPRING, false) == "beans"
		and FieldSeedPlan.seasonal_seed(state.Season.WINTER, false) == "wheat",
		"Spring uses beans to restore the soil and winter uses wheat.")
	var outside: Vector2i = state.FIRST_FIELD_CENTER
	state.tilled_cells[outside] = true
	state.set_field_seed_plan(outside, "millet")
	state.silk_workshop.built = true
	state.assign_duty(state.retainers[0], RetainerData.Duty.REEL)
	var panel := await _management()
	var item: Control = panel.retainer_list_container.get_child(1)
	var ordinary_need: int = state.retainer_food_cost()
	await _choose_from_menu(item.duty_picker, RetainerData.Duty.STEWARD)
	if not _expect(steward.duty == RetainerData.Duty.STEWARD and item.field_picker.visible
		and item.field_picker.get_selected_id() == 1 and state.retainer_food_cost() == ordinary_need
		and state.retainer_night_ration(steward) == 1 + state.balance.specialist_food_per_night,
		"The new job keeps the current field and uses the specialist ration."):
		return
	await _choose_from_menu(item.field_picker, 0)
	_expect(steward.assigned_area == outside and panel.well_field_selector.get_selected_id() == 0,
		"The field selector assigns the first field and opens its overview.")
	await _choose_from_menu(item.field_picker, 1)
	_expect(steward.assigned_area == PUBLIC and panel.well_field_selector.get_selected_id() == 1
		and "季青" in panel.steward_note.text and item.get_global_rect().encloses(item.field_picker.get_global_rect()),
		"Reassign from the roster and show who manages the second field.")
	var public_tile := await _plan(panel, PUBLIC, FieldSeedPlan.SEASONAL)
	_expect("公田" in public_tile.text and "时令续播 · 黍" in public_tile.text
		and "夏稻（无渠水种黍）" in panel.seed_timing.text and not panel.rotate_seed.button_pressed,
		"The summer plan shows millet on the dry public plot and previews all four seasons.")
	await _snapshot("01-steward-assignment")
	var canal: Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 5)]
	if not _expect(state.build_channel_path(canal) == state.ChannelSite.AVAILABLE and state.irrigation.supplies(RICE),
		"Supply the west edge of the first field for the irrigated summer plan."):
		return
	await _field(panel, 0)
	var rice_tile := await _plan(panel, RICE, FieldSeedPlan.SEASONAL)
	await _button(panel.apply_private_plan)
	_expect("时令续播 · 稻" in rice_tile.text and state.field_seed_plans.get(SITE) == FieldSeedPlan.SEASONAL
		and state.field_seed_plans.get(outside) == "millet" and "续播在等" in panel.steward_note.text,
		"The private batch previews rice and shows that the first field is still waiting for a worker.")
	await _snapshot("02-seasonal-private-plans")
	await _button(panel.get_node("CloseButton"))
	if not _expect(state.save_game() == OK and state.load_game() == OK, "Save and reload the assigned steward."):
		return
	await tree.scene_changed
	_estate()
	steward = state.retainers[1]
	_expect(steward.duty == RetainerData.Duty.STEWARD and steward.assigned_area == PUBLIC
		and state.field_seed_plans.get(PUBLIC) == FieldSeedPlan.SEASONAL
		and state.field_seed_plans.get(RICE) == FieldSeedPlan.SEASONAL,
		"The saved role and its field survive reload.")
	var worker: Retainer = world.retainer_instances[steward]
	if not await _wait_for(func(): return state.king_storage == 1,
		"The steward cuts the ripe public crop at home."):
		return
	worker.set_physics_process(false)
	await _button(ui.sleep_button)
	await tree.create_timer(1.2).timeout
	_expect(state.current_day == 36 and state.food_storage == 24 - ordinary_need and not state.active_crops.has(outside),
		"The steward does not plant the other field and consumes the quoted nightly ration.")
	await Campaign.walk_estate_road_to(tree, world, Vector2(-270, -21))
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return
	if not await _wait_for(func(): return state.active_crops.get(PUBLIC, {}).get("watered", false),
		"The assigned steward sows and waters the next crop without the player."):
		return
	if not await _wait_for(func(): return state.player_inventory == 1, "The steward also harvests the private orchard."):
		return
	_expect(state.active_crops[PUBLIC].id == "millet" and not state.active_crops.has(outside)
		and not state.active_crops.has(RICE)
		and state.king_storage == 1 and state.silk_workshop.leaves > 0 and state.away_field_report.sown == 1
		and state.away_field_report.tribute == 0 and state.away_field_report.stock == 1,
		"The private mulberry harvest and the public tribute settle once, and the other field stays clear.")
	print("FIELD_STEWARD day=", state.current_day, " field=2 tribute=", state.king_storage,
		" private=", state.player_inventory, " meal=", ordinary_need, " next_crop=", state.active_crops[PUBLIC].id)
	await Campaign.walk_to_market_exit(tree, tree.current_scene)
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return
	_estate()
	await _button(ui.sleep_button)
	await tree.create_timer(1.2).timeout
	_expect(state.current_day == 37 and state.active_crops[PUBLIC].id == "millet"
		and state.active_crops[PUBLIC].age == 1, "Autumn begins while the summer millet keeps growing.")
	if not await _wait_for(func() -> bool: return not state.field_crop_is_dry(PUBLIC), "The steward waters the millet in autumn."):
		return
	await _button(ui.sleep_button)
	await tree.create_timer(1.2).timeout
	var autumn_sown := func() -> bool: return state.active_crops.get(PUBLIC, {}).get("id") == "sorghum"
	if not await _wait_for(autumn_sown, "After harvest the steward sows the autumn crop.", 15.0):
		return
	_expect(state.current_day == 38 and state.king_storage == 2 and state.food_storage == 24 - ordinary_need * 3
		and state.current_stamina == state.max_stamina and not state.active_crops.has(RICE),
		"Across the change of season, the steward keeps public tribute and rations and costs no player stamina.")
	panel = await _management()
	await _field(panel, 1)
	_expect("时令续播 · 稷" in _plot(panel, PUBLIC).text, "The overview now previews autumn sorghum.")
	await _snapshot("03-autumn-resowing")
	print("FIELD_STEWARD_SEASON day=", state.current_day, " tribute=", state.king_storage,
		" food_spent=", 24 - state.food_storage, " autumn_crop=", state.active_crops[PUBLIC].id, " manual_farming_clicks=0")

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated save profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = steward_capture_path if not steward_capture_path.is_empty() else OS.get_environment("FIEFDOM_SEED_CAPTURES")
	tree.root.notify_mouse_entered()
	seed(3112)
	if await _fixture():
		if steward_story:
			if state.has_method("night_ration_for_duty"):
				await _steward_handover()
				if not failed and await _fixture():
					await _steward_work()
			else:
				await _steward_work()
		elif not state.has_method("planned_field_seed"):
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
