extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _click(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		root.push_input(event, true)
		await process_frame

func _type_quantity(digits: String) -> void:
	var select_all := InputEventKey.new()
	select_all.keycode = KEY_A
	select_all.ctrl_pressed = true
	select_all.pressed = true
	root.push_input(select_all, true)
	for index in digits.length():
		var digit := InputEventKey.new()
		digit.unicode = digits.unicode_at(index)
		digit.keycode = digit.unicode
		digit.pressed = true
		root.push_input(digit, true)
		await process_frame

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run market-flow with an isolated save.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/Title.tscn")
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	var state := root.get_node("Global")
	var events := root.get_node("GameEvents")
	var world := current_scene.get_node("World")
	var ui := current_scene.get_node("UI")
	var cells := [Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 5)]
	for cell in cells:
		world.handle_interaction(cell)
		world.handle_interaction(cell)
	for night in range(2):
		for cell in cells:
			world.handle_interaction(cell)
		ui.sleep_button.pressed.emit()
		await create_timer(1.1).timeout
	for cell in cells:
		world.handle_interaction(cell)
	_expect(state.player_inventory == 3 and state.king_storage == 1 and state.money == 15,
		"Only private harvests reach the market inventory.")

	state.balance.market_food_price = 7
	state.balance.market_crop_price = 9
	await _click(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	management.get_node("HBoxContainer/RightPanel").current_tab = 1
	await process_frame
	var market: VBoxContainer = management.market_panel
	await _click(market.all_crops)
	_expect(market.quantity.value == 3 and market.buy_button.disabled and state.player_inventory == 3,
		"Selecting all crops previews a batch without spending anything.")
	var edit: LineEdit = market.quantity.get_line_edit()
	await _click(edit)
	await _type_quantity("12")
	_expect(market.quantity.value == 12 and market.sell_button.disabled and market.buy_button.disabled,
		"Multi-digit amounts update live and cannot exceed the resources in stock.")
	await _type_quantity("0")
	_expect(market.quantity.value == 0 and market.convert_button.disabled and market.buy_button.disabled and state.food_storage == 8,
		"A zero quantity is visible and cannot make a trade.")
	await _type_quantity("2")
	_expect(market.quantity.value == 2 and "18 铜钱" in market.sell_button.text and "14 铜钱" in market.buy_button.text,
		"Typing a quantity updates both prices before submitting the field.")
	await _click(market.sell_button)
	_expect(state.player_inventory == 1 and state.money == 33 and state.king_storage == 1,
		"Selling two crops credits the configured price and keeps tribute intact.")
	await _click(market.buy_button)
	_expect(state.money == 19 and state.food_storage == 10, "Buying two rations charges exactly fourteen copper.")
	await _click(market.all_crops)
	await _click(market.convert_button)
	_expect(state.food_storage == 11 and state.player_inventory == 0 and state.money == 19,
		"Converting a private crop increases only food and reduces crop stock.")
	_expect(not state.convert_inventory_to_food(-1) and not state.buy_market_food(0) and not state.sell_crops(1),
		"Invalid or unaffordable market orders are rejected at the state boundary.")

	# Isolate a shortfall with only one crop and insufficient copper for the remainder.
	state.food_storage = 0
	state.player_inventory = 1
	state.money = 8
	events.food_changed.emit(state.food_storage)
	events.inventory_changed.emit(state.player_inventory)
	events.money_changed.emit(state.money)
	_expect(market.reserve_button.disabled and "14 铜钱" in market.reserve_label.text and "还差 6" in market.reserve_label.text,
		"The three-night plan previews the full price and explains the shortfall.")
	market.reserve_button.pressed.emit()
	_expect(state.food_storage == 0 and state.player_inventory == 1 and state.money == 8,
		"A reserve plan cannot partially convert crops when copper is insufficient.")
	state.money = 14
	events.money_changed.emit(state.money)
	_expect(not market.reserve_button.disabled, "Exact funds enable the three-night plan.")
	await _click(market.reserve_button)
	_expect(state.food_storage == 3 and state.player_inventory == 0 and state.money == 0 and market.reserve_button.disabled,
		"The plan spends the crop and copper together and fills exactly three nights.")
	market.reserve_button.pressed.emit()
	_expect(state.food_storage == 3 and state.money == 0, "Repeated reserve presses cannot charge again.")
	_expect(state.save_game() == OK and state.load_game() == OK, "Market resources can be saved.")
	await scene_changed
	_expect(state.food_storage == 3 and state.player_inventory == 0 and state.money == 0 and state.king_storage == 1,
		"Food, stock, cash and tribute survive reload.")

	# Compare the quoted next field against the money actually available for grain.
	state.food_storage = 62
	state.crop_stock.add("beans", 1)
	state.money = 146
	ui = current_scene.get_node("UI")
	await process_frame
	await _click(ui.manage_button)
	management = ui.panel_manager.management_panel_instance
	management.show_market()
	market = management.market_panel
	market.reserve_kind.select(market.ReserveKind.RECLAMATION)
	market.reserve_kind.item_selected.emit(market.ReserveKind.RECLAMATION)
	var construction: Dictionary = state.reclamation_food_plan()
	_expect(construction.target == 64 and construction.copper_short == 1 and market.reserve_button.disabled
		and "含本季交货作物" in market.reserve_label.text and "还差 1 铜钱" in market.reserve_label.text,
		"The construction quote uses the next rank's cost, four current rations and the seasonal lot warning.")
	market.reserve_button.pressed.emit()
	_expect(state.food_storage == 62 and state.player_inventory == 1 and state.money == 146,
		"The grain shortcut cannot dip into copper needed for stakes or partly debit crops.")
	state.money = 147
	events.money_changed.emit(state.money)
	await _click(market.reserve_button)
	_expect(state.food_storage == 64 and state.player_inventory == 0 and state.money == 140 and market.reserve_button.disabled,
		"Exact funds buy the missing grain while leaving the quoted stake money.")
	var resident: Resource = state.retainers.front()
	state.assign_duty(resident, resident.Duty.HARVEST)
	_expect(state.reclamation_food_plan().target == 68 and market.reserve_button.disabled and "共 68 份" in market.reserve_label.text,
		"The same quote uses the current roster's duty and ration costs.")

	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
