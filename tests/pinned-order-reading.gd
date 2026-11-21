extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the tracked order views with an isolated profile.")
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	var prefs := root.get_node("Preferences")
	var events := root.get_node("GameEvents")
	var season_days: int = SeasonOrders.TERMS_PER_SEASON * state.balance.days_per_solar_term
	var winter_day := season_days * 7 + 1
	state.current_day = winter_day - 1
	state.crop_stock.lots["wheat"] = 2
	state.silk_workshop.bolts = 1
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	var ui := current_scene.get_node("UI")
	var ticket: Button = ui.hud.pinned_order
	state.pin_season_order(true, true)
	var standard := ticket.get_theme_font_size(&"font_size")
	var ready := _state(state)
	_expect(prefs.set_reading_size(2) == OK and ticket.get_theme_font_size(&"font_size") == standard + 6,
		"The tracking button uses the selected reading size.")
	var rows := ticket.text.split("\n")
	_expect(rows.size() >= 2 and "第 %d 天开收" % winter_day in rows[0]
		and "麦 2/2" in rows[-1] and "丝绸 1/1" in rows[-1],
		"The next action and every cargo count have dedicated lines.")
	ticket.pressed.emit()
	await _settle()
	var panel: Control = ui.panel_manager.management_panel_instance
	var ledger: Control = panel.season_order_panel
	_expect(ledger.is_visible_in_tree() and ledger.scroll.scroll_vertical > 0 and ledger.next_plan_button.has_focus(),
		"A ready early order opens and focuses the forecast for the tracked season.")
	var first_good := ledger.next_cargo.get_child(0).get_node("Goods/Counts/ItemName") as Label
	_expect(ledger.next_details.get_theme_color(&"font_color").get_luminance() > 0.7
		and ledger.request.get_theme_color(&"font_color").get_luminance() > 0.7
		and first_good.get_theme_color(&"font_color").get_luminance() > 0.7,
		"The request and cargo names use light ink over the dark order sheets.")
	ui.panel_manager.hide_management_panel()
	paused = true
	_expect(ready == _state(state), "Visiting the next ledger preserves the staged inventory, calendar and pin.")

	state.current_day = winter_day
	state.pin_season_order(true)
	_expect("去西市交货" in ticket.text, "The same stock can be delivered at the opening of the season.")
	ticket.pressed.emit()
	_expect(state.market_trip_target == state.MARKET_ORDERS, "The ready order still follows the market route.")
	ui.directions.cancel_tracking()

	state.silk_workshop.bolts = 0
	events.silk_changed.emit()
	var missing := _state(state)
	_expect("丝绸 0/1" in ticket.text and "去西市交货" not in ticket.text, "A stock change refreshes the displayed task.")
	ticket.pressed.emit()
	await _settle()
	_expect(ledger.is_visible_in_tree() and ledger.scroll.scroll_vertical == 0,
		"A current order without field work opens its own ledger.")
	_expect(ledger.deadline.get_theme_color(&"font_color").get_luminance() > 0.7,
		"The deadline remains readable with more than two days left.")
	ui.panel_manager.hide_management_panel()
	paused = true
	_expect(missing == _state(state) and state.saved_games().is_empty(), "The stationary review creates no save and changes no goods.")

	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _settle() -> void:
	for frame in 6:
		await process_frame

func _state(state: Node) -> Array:
	return [state.current_day, state.day_progress, state.money, state.food_storage, state.king_storage,
		state.current_stamina, state.pinned_season_start, hash(state.crop_stock.lots), state.silk_workshop.bolts]

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
