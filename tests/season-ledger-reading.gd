extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _settle() -> void:
	for frame in 5:
		await process_frame

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the season ledger check with an isolated profile.")
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	var events := root.get_node("GameEvents")
	var prefs := root.get_node("Preferences")
	var year_end: int = SeasonOrders.TERMS_PER_SEASON * state.balance.days_per_solar_term * 4
	state.current_day = year_end
	state.day_progress = 0.35
	state.crop_stock.lots.merge({"wheat": 2, "hemp": 1, "beans": 2, "millet": 2}, true)
	if change_scene_to_file("res://scenes/Main.tscn") != OK:
		quit(1)
		return
	await scene_changed
	var ui := current_scene.get_node("UI")
	var world := current_scene.get_node("World")
	ui.panel_manager.show_management_panel()
	var management: Control = ui.panel_manager.management_panel_instance
	management.show_season_orders()
	var book: Control = management.season_order_panel
	var current_wheat := book.cargo.get_child(0) as PanelContainer
	var next_wheat := book.next_cargo.get_child(2) as PanelContainer
	var current_amount := current_wheat.get_node("Goods/Counts/Quantity") as Label
	var next_amount := next_wheat.get_node("Goods/Counts/Quantity") as Label
	var reservation := next_wheat.get_node("Goods/Counts/Reservation") as Label
	_expect("已备齐 · 2/2" == current_amount.text and "0/1" in next_amount.text and reservation.visible
		and reservation.text == "仓内 2 份 · 本季先留 2 份", "Two wheat can fill winter's order only.")
	_expect(book.order_route.visible and not book.food_button.disabled, "Ready goods expose a route and the existing reward choice.")
	var standard := next_amount.get_theme_font_size(&"font_size")
	_expect(prefs.set_reading_size(2) == OK and next_amount.get_theme_font_size(&"font_size") == standard + 6,
		"Both seasons' cargo slips use the reading preference.")
	events.daylight_changed.emit()
	state.crop_stock.lots["wheat"] = 3
	events.inventory_changed.emit(state.player_inventory)
	_expect(book.cargo.get_child(0) == current_wheat and book.next_cargo.get_child(2) == next_wheat
		and "1/1" in next_amount.text and reservation.text == "仓内 3 份 · 本季先留 2 份",
		"One more wheat is available for spring and the live cards stay in place.")
	await _settle()
	var fixed_deadline: Rect2 = book.deadline.get_global_rect()
	book.next_bookmark.pressed.emit()
	await _settle()
	_expect(book.scroll.scroll_vertical > 0 and book.scroll.get_global_rect().encloses(next_amount.get_global_rect())
		and book.next_plan_button.has_focus() and book.deadline.get_global_rect() == fixed_deadline,
		"The bookmark reveals spring, focuses its plan, and keeps the current deadline fixed.")
	book.current_bookmark.pressed.emit()
	await _settle()
	_expect(prefs.set_reading_size(0) == OK and prefs.set_reading_size(2) == OK, "Resize the open book.")
	management.show_season_orders(true)
	await _settle()
	_expect(book.next_plan_button.has_focus() and book.scroll.get_global_rect().encloses(book.next_plan_button.get_global_rect()),
		"The calendar link opens the forecast after the new size is laid out.")
	var position: Vector2 = world.player.position
	var food: int = state.food_storage
	var money: int = state.money
	book.order_route.pressed.emit()
	_expect(not management.visible and state.market_trip_target == state.MARKET_ORDERS
		and world.player.position == position and state.food_storage == food and state.money == money and state.season_order_receipts.is_empty(),
		"The ready route marks the West Market collection board.")

	state.season_order_receipts["winter"] = {"day": year_end, "dispatch_day": year_end + 1, "paid_in_food": false}
	state.current_day = year_end + 1
	state.day_progress = 0.1
	state.crop_stock.lots["wheat"] = 1
	if change_scene_to_file("res://scenes/WestMarket.tscn") != OK:
		quit(1)
		return
	await scene_changed
	var counter: Control = current_scene.counter
	counter.open_orders()
	book = counter.orders
	await _settle()
	_expect(not counter.scroll.visible and book.scroll.visible and root.get_visible_rect().encloses(counter.close_button.get_global_rect()),
		"The market book has one scroll below the fixed header and close button.")
	_expect(book.freight_route.visible and "上一季货车" in book.status.text and SeasonOrders.arrival_caption(state.season_order_receipts["winter"]) in book.status.text,
		"The previous season's arrival is readable in the new season.")
	_expect(paused and state.current_day == year_end + 1 and is_equal_approx(state.day_progress, 0.1)
		and state.crop_stock.count("wheat") == 1 and state.food_storage == food and state.money == money
		and state.season_order_receipts.size() == 1 and state.saved_games().is_empty(),
		"Reading uses the supplied fixture without delivering, moving the clock, or saving.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
