extends "res://tests/OrderPreparationReplay.gd"

const PROTECTED_PLOT := Vector2i(8, 4)
const PUBLIC_PLOT := Vector2i(5, 5)
const STEWARD := {"name": "渠伯", "school": RetainerData.School.MOHIST,
	"duty": RetainerData.Duty.STEWARD, "assigned_area": "9,5", "loyalty": 90}

var manual_actions := 0

func run_steward(host: SceneTree, mode := "", captures := "") -> void:
	tree = host
	state = tree.root.get_node("Global")
	capture_dir = captures
	baseline = mode == "order-steward-baseline"
	from_older_save = mode == "order-steward-resume"
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated order profile."):
		tree.quit(1)
		return
	tree.root.notify_mouse_entered()
	state.balance.raid_first_day = 10000
	var loaded := await _continue_estate() if from_older_save else await _winter_checkpoint()
	if loaded:
		await _prepare_wheat()
	if not failed and not baseline and not from_older_save:
		await _check_other_orders()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func _winter_checkpoint() -> bool:
	return await _fixture(AUTUMN_DAY, {
		"retainers": [STEWARD], "wait_for_fields_before_sleep": true,
		"crop_stock": {"wheat": 1}, "player_inventory": 1,
		"silk_workshop": {"built": true, "bolts": 1},
		"season_order_receipts": {"autumn_watch_relief": {"day": 39}},
		"tilled_cells": ["8,4", "5,5"], "field_seed_plans": {"8,4": "beans"},
		"active_crops": {
			"8,4": {"id": "beans", "age": 0, "growth_nights": 2, "watered": true},
			"5,5": {"id": "wheat", "age": 3, "growth_nights": 3},
		},
	})

func _hold_workers() -> void:
	# Keep all actions on the measured sleep and wait controls.
	for worker: Retainer in world.retainer_instances.values():
		worker.set_physics_process(false)

func _save_checkpoint() -> void:
	await _button(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	_expect(settings.save_status.text == "游戏已保存", "Use the ordinary Settings save button.")
	await _button(settings.close_button)

func _prepare_wheat() -> void:
	_hold_workers()
	if not _expect(state.current_day == AUTUMN_DAY and state.crop_stock.count("wheat") == 1
			and state.king_storage == 4 and state.field_seed_plans.get(PROTECTED_PLOT) == "beans",
			"Both paths begin with the same missing wheat, tribute, and prepared bean plot."):
		return
	if baseline:
		await _save_checkpoint()
	var book := await _open_order_section()
	var cell: Vector2i
	if baseline:
		await _capture("01-winter-preview")
		await _button(book.next_field_work_button)
		cell = ui.directions.order_work.cell
		if not _expect(not state.tilled_cells.has(cell), "The old work starts on a raw private plot."):
			return
		await _do_field_work(cell)
		await _do_field_work(cell)
		await _do_field_work(cell)
	else:
		if not _expect(book.next_steward_work.is_visible_in_tree() and book.next_field_work_button.visible
				and "麦 1 格" in book.next_details.text and "第 43 天可收完" in book.next_details.text,
				"The book offers one wheat plot for the next order and shows today's estimated harvest."):
			return
		await _capture("01-winter-preview")
		if tree.root.size.x <= 1024 and DisplayServer.get_name() != "headless":
			var pad = load("res://tests/GamepadReplay.gd").new()
			pad.tree = tree
			pad.pad = tree.root.get_node("GamepadInput")
			await pad._click(book.next_steward_work)
			_expect(pad.failures == 0, "Use the order button with the controller in the compact window.")
		else:
			await _button(book.next_steward_work)
		if not _expect(state.field_seed_plans.size() == 2 and state.pinned_season_order().get("start") == WINTER_DAY
				and not book.next_field_work_button.visible and book.next_plan_button.text == "取消下季跟踪",
				"Accepting enough work tracks the winter order and removes the redundant sowing cue."):
			return
		for position: Vector2i in state.field_seed_plans:
			if position != PROTECTED_PLOT:
				cell = position
		var keeper: RetainerData = state.retainers[0]
		var helper := RetainerData.new()
		_expect(Rect2i(8, 4, 3, 3).has_point(cell) and not state.is_public_plot(cell)
			and not state.tilled_cells.has(cell) and not state.active_crops.has(cell)
			and state.next_seed_for_plan(cell, state.field_seed_plans[cell]) == "wheat"
			and state.field_job(keeper, cell) == state.FieldJob.TILL and state.field_job(helper, cell) == state.FieldJob.NONE,
			"Only the steward on the chosen private field can begin the order's raw ground.")
		await _capture("02-winter-queued")
		await _button(book.next_steward_work)
		_expect(not state.field_seed_plans.has(cell) and state.field_seed_plans.get(PROTECTED_PLOT) == "beans",
			"Withdrawal only clears unsown order work.")
		await _button(book.next_steward_work)
		await _close_management()
		await _save_checkpoint()
		if not await _continue_estate():
			return
		_hold_workers()
		for position: Vector2i in state.field_seed_plans:
			if position != PROTECTED_PLOT:
				cell = position
		if not _expect(state.field_seed_plans.get(cell, "").begins_with("order:")
				and state.pinned_season_order().get("start") == WINTER_DAY,
				"Pending order work and its date are restored through Continue."):
			return
	var after_planting: Dictionary = {}
	for day in range(AUTUMN_DAY + 1, WINTER_DAY + 1):
		await _night()
		if not _expect(state.current_day == day and state.active_crops.get(cell, {}).get("id") == "wheat",
				"Normal daylight work plants the wheat and normal sleep advances after preparation."):
			return
		if day == AUTUMN_DAY + 1:
			after_planting = state.last_dawn.get("field_wait", {})
			if not baseline:
				_expect(not state.field_seed_plans.has(cell) and after_planting.get("tilled", 0) >= 1
					and after_planting.get("sown", 0) >= 1 and state.active_crops[cell].age == 1,
					"The completed sowing consumes its one-off instruction and appears in the morning work report.")
				await _capture("03-wheat-after-steward")
		if baseline and day < WINTER_DAY and world.is_crop_dry(cell):
			await _do_field_work(cell)
	if baseline:
		await _do_field_work(cell)
	else:
		var night := await _open_rations()
		night.scroll.ensure_control_visible(night.wait_button)
		await _button(night.wait_button)
		_expect(state.field_wait_report.get("harvested", 0) >= 1,
			"The workday control credits actual harvests on the order's opening day.")
		await _button(night.close_button)
	if not _expect(state.can_deliver_season_order(state.season_order()) and state.crop_stock.count("wheat") == 2
			and state.king_storage == 4 and state.active_crops.has(PUBLIC_PLOT) and not state.active_crops.has(cell)
			and state.field_seed_plans.get(PROTECTED_PLOT) == "beans",
			"Both paths produce the two wheat on opening day and preserve the existing plan and public field."):
		return
	await _capture("04-winter-ready")
	print("ORDER_STEWARD_WINTER baseline=", baseline, " day=", state.current_day, " manual=", manual_actions,
		" wheat=", state.crop_stock.count("wheat"), " evening=", after_planting)
	await _deliver_at_market()

func _do_field_work(cell: Vector2i) -> void:
	manual_actions += 1
	await _plot(cell)

func _check_other_orders() -> void:
	if not await _fixture(45, {
		"retainers": [STEWARD], "crop_stock": {"beans": 2, "millet": 2}, "player_inventory": 4,
		"tilled_cells": ["4,4", "8,4", "9,5"], "field_seed_plans": {"8,4": "wheat"},
		"active_crops": {"4,4": {"id": "wheat", "age": 1, "growth_nights": 2, "watered": true},
			"9,5": {"id": "wheat", "age": 2, "growth_nights": 2}},
	}):
		return
	_hold_workers()
	var spring: Dictionary = state.steward_order_offer(state.season_order(49))
	_expect(spring.plans.size() == 1 and spring.plans.values() == ["wheat"]
		and not spring.plans.has(Vector2i(9, 5)),
		"With two wheat claims, account for the plant and the existing steward plan and ignore the public crop.")
	if not await _fixture(46, {"retainers": [STEWARD], "silk_workshop": {"built": true, "bolts": 1},
			"crop_stock": {"beans": 2, "millet": 2}, "player_inventory": 4}):
		return
	_hold_workers()
	var book := await _open_order_section()
	await _button(book.next_steward_work)
	_expect(state.field_seed_plans.size() == 3 and not book.steward_work.visible,
		"Three wheat can serve both seasons. The pending next-order plots suppress redundant current work.")
	await _button(book.next_steward_work)
	if not _expect(book.steward_work.visible, "The last feasible day offers a current order plan."):
		return
	await _button(book.steward_work)
	_expect(state.field_seed_plans.size() == 2 and state.pinned_season_order().get("start") == 49,
		"Two unfilled wheat belong to the current order and the next season's tracking remains in place.")
	await _close_management()
	await _night()
	_expect(state.current_day == 47 and state.field_seed_plans.is_empty() and state.active_crops.is_empty(),
		"Pending work clears as soon as late sowing cannot meet the deadline.")
	if not await _fixture(5, {"retainers": [STEWARD]}):
		return
	_hold_workers()
	book = await _open_order_section()
	_expect(not book.next_steward_work.visible and book.next_water_button.visible,
		"Without canal water, the summer order still points to water instead of queuing dry rice.")
	print("ORDER_STEWARD_BOUNDARIES shared_wheat=3 new_plots=1 expired_day=47 water_route=true")
