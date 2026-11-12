extends "res://tests/WestMarketReplay.gd"

const FIRST_PRIVATE := Vector2i(4, 4)
const RICE := Vector2i(4, 5)
const SECOND_FIELD := Vector2i(9, 5)
const SECOND_DRY := Vector2i(10, 4)
const SECOND_RIPE := Vector2i(10, 6)
const CANAL_JOIN := Vector2i(2, 5)

var legacy := false
var capture_path := ""
var world: Node2D
var ui: CanvasLayer

func _use_estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame
	await tree.process_frame

func _plot(cell: Vector2i, clicks := 1) -> void:
	var tiles := world.tile_map as TileMapLayer
	for click in clicks:
		await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))
	await tree.process_frame

func _pause_worker() -> void:
	world.retainer_instances[state.retainers.front()].set_physics_process(false)

func _fixture() -> bool:
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await _use_estate()
	_pause_worker()
	await _plot(PUBLIC, 2)
	await _plot(FIRST_PRIVATE, 2)
	if not _expect(state.field_night_forecast().dry == 2, "Plant two dry plots through the farm controls."):
		return false

	# Stage the second field and different crop ages for the map and routing checks.
	state.reputation = state.promotion_reputation()
	state.zhou_li_score = "中"
	if not _expect(state.check_rank_up() and state.add_well_field(SECOND_FIELD), "Stage a second field at a valid site."):
		return false
	state.well_fields[1].is_unlocked = true
	state.well_fields[1].reclamation_progress = state.RECLAMATION_NIGHTS
	state.tech_unlocked.irrigation = true
	state.money = 40
	var channels: Dictionary[Vector2i, bool] = {Vector2i(3, 5): true}
	state.irrigation.restore(Vector2i(1, 5), channels)
	var items := tree.root.get_node("ItemManager")
	for cell in [RICE, SECOND_FIELD, SECOND_DRY, SECOND_RIPE]:
		var id := "rice" if cell == RICE else "millet"
		var crop: CropData = items.get_crop(id)
		var nights: int = state.sowing_nights(crop)
		state.tilled_cells[cell] = true
		state.active_crops[cell] = {"id": id, "data": crop, "growth_nights": nights,
			"age": nights if cell in [SECOND_FIELD, SECOND_RIPE] else 0,
			"watered": false, "requires_channel": crop.is_water_crop}
	tree.change_scene_to_file(state.ESTATE_SCENE)
	await tree.scene_changed
	await _use_estate()
	_pause_worker()
	return true

func _continue_estate() -> bool:
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE, "Continue from the title into the estate."):
		return false
	await _use_estate()
	_pause_worker()
	return true

func _water_from_map() -> bool:
	await _button(ui.hud.farm_status)
	var map: Control = ui.estate_map
	if not _expect(map.modal.visible and tree.paused and map.category == map.Category.FIELDS,
		"The seed belt opens the paused survey directly to the fields."):
		return false
	_expect("可收 2" in map.harvest_route.text and "待浇 3" in map.water_route.text and "断水 1" in map.canal_route.text
		and map.field_tasks.size() == 6 and map.field_tasks[PUBLIC] == state.NightGrowth.DRY
		and map.field_tasks[RICE] == state.NightGrowth.BLOCKED and map.field_tasks[SECOND_RIPE] == state.NightGrowth.READY,
		"The counts and plot positions distinguish ripe, dry and disconnected crops in two fields.")
	print("FIELD_ROUTE_MAP ", map.harvest_route.text, " / ", map.water_route.text, " / ", map.canal_route.text)
	await _snapshot("01-field-map")
	await _button(map.water_route)
	if not _expect(not tree.paused and ui.directions.tracked_plot == PUBLIC and "待浇公田" in ui.directions.destination().get("title", ""),
		"Start with public land and return to the farm."):
		return false
	var stamina: int = state.current_stamina
	await _plot(PUBLIC)
	_expect(ui.directions.tracked_plot == FIRST_PRIVATE and state.active_crops[PUBLIC].watered
		and state.current_stamina == stamina - world.field_cost(world.FieldAction.WATER),
		"A normal watering action charges stamina and marks the closest remaining plot.")
	_expect(not world.tile_map.get_node("FieldCursor").visible, "The completed plot tooltip no longer covers the next plot.")
	print("FIELD_ROUTE_WATER public=", PUBLIC, " next=", ui.directions.tracked_plot)
	await _snapshot("02-next-dry-plot")
	return true

func _save_and_leave() -> bool:
	await _button(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	if not _expect(settings.save_status.text == "游戏已保存", "Save the active route from settings."):
		return false
	await _button(settings.close_button)
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	if not await _continue_estate():
		return false
	_expect(state.field_route_status == state.NightGrowth.DRY and ui.directions.tracked_plot == FIRST_PRIVATE,
		"Continue recomputes the same day's active route from crop state.")
	print("FIELD_ROUTE_CONTINUE day=", state.current_day, " next=", ui.directions.tracked_plot)
	await _plot(FIRST_PRIVATE)
	_expect(ui.directions.tracked_plot == SECOND_DRY, "Watering advances to the second field without opening a panel.")
	await _walk(world.player, [Vector2(-181, 54), Vector2(-181, 0), Vector2(-270, -21)])
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return false
	var market := tree.current_scene as Node2D
	await tree.create_timer(3.6).timeout
	_expect(state.field_route_status == state.NightGrowth.DRY and state.active_crops[SECOND_DRY].watered
		and state.away_field_report.get("watered", 0) == 1, "The last watering job is completed by the retainer while away.")
	await _walk(market.player, [Vector2(176, 34)])
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return false
	await _use_estate()
	_pause_worker()
	var notice: Label = tree.current_scene.get_node("CampaignHUD").notice
	_expect(state.field_route_status == -1 and ui.directions.tracked_plot == null and not ui.hud.cancel_directions.visible
		and notice.visible and "今日外出田务" in notice.text, "Returning clears the finished route and preserves the work report.")
	print("FIELD_ROUTE_RETURN ", state.away_field_summary(), " route=", state.field_route_status)
	return true

func _harvest_and_repair() -> void:
	await _walk(world.player, [Vector2(-181, 0), Vector2(-181, 65), Vector2(31, 65), Vector2(66, 98)])
	await _button(ui.hud.farm_status)
	var map: Control = ui.estate_map
	_expect(map.water_route.disabled and "待浇 0" in map.water_route.text, "A category with no work cannot start a route.")
	await _button(map.harvest_route)
	_expect(ui.directions.tracked_plot == SECOND_FIELD, "Harvest marks the public plot before the private plot.")
	var stamina: int = state.current_stamina
	var copper: int = state.money
	var private_price: int = state.active_crops[SECOND_RIPE].data.sell_price
	await _plot(SECOND_FIELD)
	_expect(ui.directions.tracked_plot == SECOND_RIPE, "Harvest continues to the ripe private plot.")
	await _plot(SECOND_RIPE)
	_expect(ui.directions.tracked_plot == null and state.king_storage == 1 and state.player_inventory == 1
		and state.money == copper + private_price and state.current_stamina == stamina - 2 * world.field_cost(world.FieldAction.HARVEST),
		"Both harvests preserve public and private yields and the normal stamina cost.")
	print("FIELD_ROUTE_HARVEST tribute=", state.king_storage, " private=", state.player_inventory, " copper=", state.money - copper)

	await _button(ui.hud.farm_status)
	await _button(map.canal_route)
	_expect(ui.directions.tracked_plot == RICE, "The canal route points to the disconnected rice.")
	await _button(ui.sleep_button)
	await tree.create_timer(1.16).timeout
	_expect(state.current_day == 2 and state.field_route_status == -1 and ui.directions.tracked_plot == null
		and state.last_field_night.get("blocked", 0) == 1, "Dawn clears directions and records disconnected rice as usual.")
	await _button(ui.hud.farm_status)
	await _button(map.canal_route)
	await _button(ui.channel_button)
	_expect(world.channel_mode and ui.directions.tracked_plot == RICE and ui.directions.visible,
		"The rice marker remains usable while editing canals.")
	await _snapshot("03-disconnected-rice")
	copper = state.money
	await _plot(CANAL_JOIN)
	_expect(state.irrigation.supplies(RICE) and state.money == copper - state.channel_cost()
		and state.field_route_status == -1 and not ui.directions.visible, "Digging the connector supplies the rice and ends the route.")
	print("FIELD_ROUTE_CANAL day=", state.current_day, " wet=", state.irrigation.supplies(RICE), " route=", state.field_route_status)
	await _button(ui.channel_button)

func _play() -> void:
	capture_dir = capture_path
	if legacy:
		if not await _continue_estate():
			return
		_expect(state.field_route_status == -1 and state.field_night_forecast().dry == 2, "The previous release save has no selected route and preserves its dry crops.")
		await _button(ui.hud.rations_button)
		var plan: Control = ui.get_node("Control/NightRationsPanel")
		await _button(plan.find_plot)
		_expect(ui.directions.tracked_plot == PUBLIC, "Tonight's plan starts the route at the public plot.")
		await _plot(PUBLIC)
		_expect(ui.directions.tracked_plot == RICE, "Tonight's plan now continues to the remaining private plot.")
		print("FIELD_ROUTE_LEGACY day=", state.current_day, " next=", ui.directions.tracked_plot)
		return
	if await _fixture() and await _water_from_map() and await _save_and_leave():
		await _harvest_and_repair()
