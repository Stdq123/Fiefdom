extends "res://tests/SecondYearOrdersReplay.gd"

const AUTUMN_DAY := 40
const WINTER_DAY := 43

var baseline := false
var from_older_save := false
var capture_path := ""
var start_planting_early := false

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated order profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = capture_path
	tree.root.notify_mouse_entered()
	state.balance.raid_first_day = 10000
	if start_planting_early:
		await _plant_for_winter()
		if not failed:
			await _check_early_work_boundaries()
	else:
		var loaded := await _continue_estate() if from_older_save else await _autumn_checkpoint()
		if loaded:
			if baseline:
				await _old_preview()
			else:
				await _prepare_winter()
				if not failed and not from_older_save:
					await _shared_wheat()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func _autumn_checkpoint() -> bool:
	return await _fixture(AUTUMN_DAY, {"food_storage": 0, "money": 20,
		"crop_stock": {"wheat": 2}, "player_inventory": 2,
		"silk_workshop": {"built": true, "cocoons": 2},
		"night_rations": {"enabled": true, "copper_limit": 5},
		"retainers": [{"name": "渠伯", "school": 2, "duty": 0}]})

func _plant_for_winter() -> void:
	if not await _fixture(AUTUMN_DAY, {
		"player_inventory": 1,
		"crop_stock": {"wheat": 1},
		"silk_workshop": {"built": true, "bolts": 1},
		"season_order_receipts": {"autumn_watch_relief": {"day": 39}},
		"tilled_cells": ["5,6", "9,5"],
		"field_seed_plans": {"5,6": "beans"},
	}):
		return
	var book := await _open_order_section()
	if not _expect(book.next_field_work_button.is_visible_in_tree() and "换麦种" in book.next_field_work_button.text
		and "麦最早第 43 天可收" in book.next_details.text and "第 43 天起可交货" in book.next_details.text,
		"Autumn offers a winter plot with the actual off-season growing time visible."):
		return
	await _capture("01-autumn-winter-planting")
	var seed_plans: Dictionary = state.field_seed_plans.duplicate()
	if DisplayServer.get_name() != "headless" and tree.root.size.x <= 1024:
		var controller = load("res://tests/GamepadReplay.gd").new()
		controller.tree = tree
		controller.pad = tree.root.get_node("GamepadInput")
		await controller._click(book.next_field_work_button)
		_expect(controller.failures == 0 and controller.pad.active, "Select the next-season plot with the controller.")
	else:
		await _button(book.next_field_work_button)
	var plan: Dictionary = ui.directions.order_work
	if not _expect(not plan.is_empty(), "The next-season button opens a live field route."):
		return
	var cell: Vector2i = plan.cell
	if not _expect(state.pinned_season_order().start == WINTER_DAY and world.current_seed_id == "wheat"
		and not state.is_public_plot(cell) and cell != Vector2i(5, 6) and state.field_seed_plans == seed_plans
		and state.active_crops.is_empty(), "Preview picks a private plot without planting or overwriting the bean plan."):
		return
	await _capture("02-marked-ground-for-wheat")
	if not state.tilled_cells.has(cell):
		await _plot(cell)
	await _plot(cell)
	await _plot(cell)
	var crop: Dictionary = state.active_crops.get(cell, {})
	if not _expect(crop.get("id") == "wheat" and crop.get("watered") == true
		and crop.get("growth_nights") == 3 and ui.directions.order_work.get("action") == state.OrderWork.WAIT
		and not state.can_deliver_season_order(state.pinned_season_order()), "Early sowing and watering produce %s. Route %s." % [
			crop, ui.directions.order_work]):
		return
	await _capture("03-wheat-growing-before-winter")
	if not _expect(state.save_game() == OK, "Save the autumn field plan.") or not await _continue_estate():
		return
	if not _expect(ui.directions.tracked_plot == cell and state.pinned_season_order().start == WINTER_DAY,
		"The next-season route survives return to the title and Continue."):
		return
	for day in range(AUTUMN_DAY + 1, WINTER_DAY + 1):
		await _night()
		_expect(state.current_day == day and ui.directions.tracked_plot == cell, "One private plot remains marked across each dawn.")
		if day < WINTER_DAY:
			_expect(ui.directions.order_work.get("action") == state.OrderWork.WATER, "Dawn requests the next watering.")
			await _plot(cell)
	_expect(ui.directions.order_work.get("action") == state.OrderWork.HARVEST, "The tagged wheat is ripe as soon as winter opens.")
	await _plot(cell)
	if not _expect(state.current_day == WINTER_DAY and state.crop_stock.count("wheat") == 2 and state.king_storage == 4
		and "去西市交货" in ui.hud.pinned_order.text and ui.directions.tracked_plot == null,
		"One early sowing finishes the order on opening day and the original tribute stays in the treasury."):
		return
	print("ORDER_AHEAD_OPENING ripe_day=", state.current_day, " crop=wheat plot=", cell, " tribute=", state.king_storage)
	await _capture("04-order-ready-on-opening-day")
	await _deliver_at_market()

func _check_early_work_boundaries() -> void:
	if not await _fixture(5, {}):
		return
	var book := await _open_order_section()
	_expect(not book.next_field_work_button.visible and book.next_water_button.is_visible_in_tree(),
		"Dry summer rice points to the water source instead of an unsupplied plot.")
	if not await _fixture(45, {
		"player_inventory": 4,
		"crop_stock": {"millet": 2, "beans": 2},
		"tilled_cells": ["4,4", "5,5", "9,5"],
		"active_crops": {
			"4,4": {"id": "wheat", "age": 1, "growth_nights": 2, "watered": true},
			"5,5": {"id": "wheat", "age": 2, "growth_nights": 2},
			"9,5": {"id": "wheat", "age": 2, "growth_nights": 2},
		},
	}):
		return
	var spring: Dictionary = state.season_order(49)
	var work: Dictionary = state.season_order_work(spring)
	_expect(state.season_order_work(state.season_order(55)).is_empty() and work.get("crop_id") == "wheat"
		and work.get("action") == state.OrderWork.SOW and not state.is_public_plot(work.cell),
		"Two outstanding orders share wheat. The growing private plot only covers part of both, even with two ripe public plots.")
	print("ORDER_AHEAD_BOUNDARIES shared_wheat=3 water_route=true public_ignored=true")

func _continue_estate() -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE, "Continue the prepared estate from the title."):
		return false
	_estate()
	await tree.process_frame
	return true

func _open_order_section() -> Control:
	var panel := await _manage()
	var index: int = panel.tabs.get_tab_idx_from_control(panel.season_order_panel)
	await _button(panel.section_buttons[index])
	return panel.season_order_panel

func _open_rations() -> Control:
	await _button(ui.hud.rations_button)
	return ui.get_node("Control/NightRationsPanel")

func _old_preview() -> void:
	var book := await _open_order_section()
	_expect("岁末麦帛" in book.next_details.text and book.get_node_or_null("Next/Content/HeadingRow/Plan") == null,
		"The previous build lists next winter's order without a preparation control.")
	await _capture("01-next-order")
	await _close_management()
	if not _expect(state.save_game() == OK, "Save an actual previous-build autumn checkpoint."):
		return
	print("ORDER_PREP_OLD_SAVE path=", ProjectSettings.globalize_path(state.manual_save_path()))
	var panel := await _open_rations()
	var plan: Dictionary = state.night_rations_plan()
	_expect(plan.used.get("wheat", 0) == 1 and plan.bought == 0, "Before the winter window, the old plan takes a wheat for tonight.")
	await _capture("02-before-sleep")
	await _button(panel.get_node("%Sleep"))
	await tree.create_timer(1.15).timeout
	_expect(state.current_day == AUTUMN_DAY + 1 and state.crop_stock.count("wheat") == 1,
		"The old overnight settlement actually consumes the wheat.")
	print("ORDER_PREP_BASELINE day=", state.current_day, " wheat=", state.crop_stock.count("wheat"))

func _prepare_winter() -> void:
	_expect(state.current_day == AUTUMN_DAY and not ui.hud.pinned_order.visible and state.crop_stock.count("wheat") == 2,
		"The autumn checkpoint starts with two wheat and no preparation plan.")
	var book := await _open_order_section()
	_expect("岁末麦帛" in book.next_heading.text and "2/2" in _forecast_amount(book, "麦")
		and "0/1" in _forecast_amount(book, "丝绸"),
		"See which winter supplies are ready while still in autumn.")
	await _button(book.next_plan_button)
	_expect(book.next_plan_button.button_pressed and not book.pin_button.button_pressed,
		"Selecting the winter plan tracks that order in the field.")
	await _capture("01-next-order")
	await _button(book.next_silk_button)
	var panel: Control = ui.panel_manager.management_panel_instance
	var workshop: Control = panel.silk_panel
	_expect(workshop.is_visible_in_tree(), "The order opens the production workshop.")
	await _button(workshop.buttons[SilkWorkshop.Action.REEL])
	await _button(workshop.buttons[SilkWorkshop.Action.REEL])
	await _button(workshop.buttons[SilkWorkshop.Action.WEAVE])
	_expect(state.silk_workshop.bolts == 1, "Weave the silk in autumn.")
	var market_index: int = panel.tabs.get_tab_idx_from_control(panel.market_panel)
	await _button(panel.section_buttons[market_index])
	var market: Control = panel.market_panel
	var wheat_index := CropStock.IDS.find("wheat") + 1
	market.crop_choice.select(wheat_index)
	market.crop_choice.item_selected.emit(wheat_index)
	_expect("含下季留货" in market.debit_plan.text and not market.convert_button.disabled,
		"An explicit wheat trade warns that it takes a reserved ingredient and remains available.")
	await _close_management()
	_expect(ui.hud.pinned_order.visible and "第 43 天开收" in ui.hud.pinned_order.text and "丝绸 1/1" in ui.hud.pinned_order.text,
		"Field tracking updates after weaving.")
	await _capture("02-field-preparation")
	if not _expect(state.save_game() == OK, "Save the preparation plan before going to sleep.") or not await _continue_estate():
		return
	var tracked: Dictionary = state.pinned_season_order()
	_expect(tracked.get("start") == WINTER_DAY and "丝绸 1/1" in ui.hud.pinned_order.text,
		"Continue restores the future date and the prepared silk.")
	var night := await _open_rations()
	var plan: Dictionary = state.night_rations_plan()
	_expect(night.keep.text.begins_with("下季「岁末麦帛」留货") and plan.used.is_empty() and plan.reserved.get("wheat", 0) == 2 and plan.bought == 1,
		"Tonight's forecast leaves both wheat and buys the missing ration.")
	await _capture("03-night-reservation")
	await _button(night.get_node("%Sleep"))
	await tree.create_timer(1.15).timeout
	_expect(state.current_day == AUTUMN_DAY + 1 and state.night_rations.last.bought == 1 and state.crop_stock.count("wheat") == 2,
		"The same forecast is applied when sleeping.")
	for day in range(AUTUMN_DAY + 1, WINTER_DAY):
		await _night()
	_expect(state.current_day == WINTER_DAY and state.crop_stock.count("wheat") == 2 and state.money == 5
		and "去西市交货" in ui.hud.pinned_order.text and state.season_order_crops_to_keep().get("wheat") == 2,
		"Rollover makes the plan the current order and keeps each ingredient once.")
	print("ORDER_PREP_DAWN day=", state.current_day, " wheat=", state.crop_stock.count("wheat"), " silk=", state.silk_workshop.bolts)
	await _capture("04-winter-ready")
	await _deliver_at_market()

func _deliver_at_market() -> void:
	await _button(ui.hud.pinned_order)
	_expect(state.market_trip_target == state.MARKET_ORDERS, "The ready order sends the player to the actual market board.")
	await Campaign.walk_estate_road_to(tree, world, Vector2(-270, -21))
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return
	var market := tree.current_scene as Node2D
	await Campaign.walk_market_to(tree, market, market.market_map.places[state.MARKET_ORDERS])
	await _key(KEY_E)
	var book: Control = market.counter.orders
	await _capture("05-west-market-delivery")
	await _button(book.copper_button)
	_expect(state.season_order_delivered_at(state.season_order()) == WINTER_DAY and state.crop_stock.count("wheat") == 0
		and state.silk_workshop.bolts == 0 and state.pinned_season_order().is_empty() and state.king_storage == 4,
		"Deliver the reserved goods once while leaving public tribute intact.")
	print("ORDER_PREP_DELIVERED day=", state.current_day, " copper=", state.money)

func _shared_wheat() -> void:
	if not await _fixture(45, {"player_inventory": 2, "crop_stock": {"wheat": 2},
			"silk_workshop": {"built": true, "bolts": 1}}):
		return
	var book := await _open_order_section()
	await _button(book.next_plan_button)
	_expect("0/1" in _forecast_amount(book, "麦") and state.season_order_crops_to_keep().get("wheat") == 3,
		"Wheat promised to winter is not counted toward the next spring order.")
	state.crop_stock.add("wheat", 1)
	state.crop_stock.add("hemp", 1)
	tree.root.get_node("GameEvents").inventory_changed.emit(state.player_inventory)
	_expect("1/1" in _forecast_amount(book, "麦") and state.market_crop_plan(1) == {"hemp": 1},
		"The third wheat counts toward spring, and bulk trade uses other crops first.")
	var night: Dictionary = state.night_rations_plan()
	_expect(night.current_reserved.get("wheat", 0) == 2 and night.upcoming_reserved.get("wheat", 0) == 1,
		"The night forecast assigns the held wheat to the correct orders.")
	await _close_management()
	await _button(ui.hud.pinned_order)
	_expect(ui.directions.order_work.get("crop_id") in ["beans", "millet"]
		and state.market_trip_target.is_empty() and state.can_deliver_season_order(state.season_order()),
		"The spring tracker marks missing spring crops while winter goods remain ready.")
	book = await _open_order_section()
	await _capture("06-shared-wheat")
	await _button(book.next_plan_button)
	_expect(state.pinned_season_order().is_empty() and state.market_crop_plan(1) == {"wheat": 1},
		"Cancelling early preparation releases the surplus wheat and keeps the current order reserve.")
	print("ORDER_PREP_OVERLAP current_wheat=2 future_wheat=1 cancelled=true")
