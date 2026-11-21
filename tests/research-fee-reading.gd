extends SceneTree

var state: Node
var events: Node
var ui: Node
var failed := false
var fee: int
var price: int

func _initialize() -> void:
	_review.call_deferred()

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error(detail)

func _settle() -> void:
	for frame in 5:
		await process_frame

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run research-fee-reading in an isolated profile.")
		quit(1)
		return
	state = root.get_node("Global")
	events = root.get_node("GameEvents")
	state.tax_reform_choice = state.TaxReformChoice.DELAYED
	state.tax_reform_day = state.tax_council_start_day()
	state.current_day = state.tax_reform_day + state.research_payment_interval() - 1
	state.current_rank = state.Rank.DA_FU
	state.king_storage = 9
	state.wait_for_fields_before_sleep = false
	var retainer_data: GDScript = state.retainers[0].get_script()
	var teacher: Resource = retainer_data.new("季青", "士人", retainer_data.School.CONFUCIAN)
	teacher.duty = retainer_data.Duty.TEACH
	teacher.loyalty = 10.0
	state.retainers.clear()
	state.retainers.append(teacher)
	state.crop_stock.lots.clear()
	price = state.balance.market_food_price
	fee = state.balance.research_monthly_cost
	state.money = fee - 7
	state.food_storage = state.retainer_food_cost() - 1
	state.set_night_rations(true, price)
	paused = true
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		_expect(false, "Mount the fixed estate.")
		quit(1)
		return
	await scene_changed
	current_scene.get_node("World").process_mode = Node.PROCESS_MODE_DISABLED
	ui = current_scene.get_node("UI")
	paused = false
	_expect(root.get_node("Preferences").set_reading_size(2) == OK, "Use the maximum reading size in the fixed estate.")
	await _settle()
	await _check_shortfall()
	await _check_departure()
	await _check_funded()
	_expect(state.current_day == state.tax_reform_day + state.research_payment_interval() - 1
		and state.saved_games().is_empty(), "The fee review never advances the date or writes a game save.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _stop_sleep() -> void:
	if ui.sleep_tween and ui.sleep_tween.is_running():
		ui.sleep_tween.kill()
		ui._clear_fader()

func _check_shortfall() -> void:
	var plan: Dictionary = state.night_rations_plan()
	var gap := 7 + price
	_expect(plan.copper == price and plan.uncovered == 0 and plan.get("research_gap", -1) == gap,
		"The fee forecast includes the copper spent on the last serving.")
	_expect("缺经费" in ui.hud.rations_button.text and "还差 %d" % gap in ui.hud.rations_button.tooltip_text,
		"Flag the same shortfall above the sleep button.")
	var before := _snapshot()
	ui._request_sleep()
	var warning := ui.get_node_or_null("Control/DialoguePanel") as Control
	_expect(warning != null and not ui.world.player.resting, "A fee shortfall opens a warning before starting the sleep transition.")
	if not warning:
		_stop_sleep()
		return
	_expect("研究费 %d" % fee in warning.text_label.text and "还差 %d" % gap in warning.text_label.text
		and "召简" in warning.text_label.text and warning.choices[0].has_focus()
		and warning.choices[0].text == "查看今夜安排" and warning.choices[1].text == "打开市场备款"
		and warning.choices.back().text == "仍然过夜", "Name the consequence and offer a safe default and a way to raise funds.")
	warning.choices[0].pressed.emit()
	await _settle()
	var book := ui.get_node_or_null("Control/NightRationsPanel") as Control
	_expect(book != null, "Following the fee warning opens tonight's plan.")
	if book:
		var note: Label = book.research_fee
		var line := note.get_global_rect()
		_expect(note.is_visible_in_tree() and "还差 %d" % gap in note.text
			and note.get_theme_font_size(&"font_size") == 22
			and line.end.y <= book.scroll.get_global_rect().position.y,
			"The fixed fee line is legible above the scroll area at the maximum size.")
		book.scroll.scroll_vertical = 200
		await _settle()
		_expect(book.scroll.scroll_vertical > 0 and note.get_global_rect() == line,
			"The forecast stays visible while reading the body.")
		_expect(book.get_node("%Market").text == "打开市场备款", "The fee plan points to the existing market.")
		book.free()
	_expect(_snapshot() == before, "Opening the plan from the warning leaves the ledger and date intact.")

func _check_departure() -> void:
	state.set_night_rations(false, 0)
	state.food_storage = 0
	events.food_changed.emit(state.food_storage)
	var before := _snapshot()
	ui._request_sleep()
	var warning := ui.get_node_or_null("Control/DialoguePanel") as Control
	_expect(warning != null, "Fees and a pending departure use one warning.")
	if not warning:
		_stop_sleep()
		return
	_expect("还差 7" in warning.text_label.text and "季青缺餐后将离任" in warning.text_label.text,
		"Read both the fee shortfall and departing retainer in the same warning.")
	if warning.choices.size() == 3:
		warning.choices[1].pressed.emit()
		await _settle()
		var office: Control = ui.panel_manager.management_panel_instance
		_expect(office.visible and office.market_panel.is_visible_in_tree(), "The warning can go directly to the market.")
		ui.panel_manager.hide_management_panel()
	else:
		warning.free()
	_expect(_snapshot() == before, "Reviewing the two risks does not spend money or dismiss the retainer.")

func _check_funded() -> void:
	state.food_storage = state.retainer_food_cost() - 1
	state.money = fee + price
	state.set_night_rations(true, price)
	events.money_changed.emit(state.money)
	var before := _snapshot()
	var plan: Dictionary = state.night_rations_plan()
	_expect(plan.research_reserve == fee and plan.copper == price and plan.get("research_gap", -1) == 0,
		"Exact funding protects the installment and allows the remaining purchase.")
	_expect("缺经费" not in ui.hud.rations_button.text, "A funded fee clears the shortfall flag.")
	ui._show_night_rations()
	var book := ui.get_node_or_null("Control/NightRationsPanel") as Control
	_expect(book != null and "预留 %d 铜钱" % fee in book.research_fee.text,
		"A funded fee shows the reserve in the planner.")
	if book:
		book.free()
	ui._request_sleep()
	_expect(ui.get_node_or_null("Control/DialoguePanel") == null and ui.world.player.resting,
		"Exact funding does not require extra confirmation.")
	_stop_sleep()
	_expect(_snapshot() == before, "The review stops the transition before any overnight settlement.")

func _snapshot() -> Array:
	return [state.current_day, state.day_progress, state.money, state.food_storage, state.crop_stock.lots.duplicate(),
		state.retainers.size(), state.retainers[0].loyalty, state.research_choice_pending, state.night_rations.last.duplicate()]
