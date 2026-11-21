extends SceneTree

var state: Node
var ui: Node
var failed := false
var threshold: int
var public_plot: Vector2i

func _initialize() -> void:
	_review.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run tribute-bedtime-reading in an isolated profile.")
		quit(1)
		return
	state = root.get_node("Global")
	threshold = state.balance.rank_strip_threshold
	state.current_day = 20
	state.king_storage = 1
	state.days_without_contribution = state.balance.no_contribution_threshold - 1
	state.reputation = threshold + state.balance.no_contribution_penalty
	state.wait_for_fields_before_sleep = false
	var retainer_data: GDScript = state.retainers[0].get_script()
	var teacher: Resource = retainer_data.new("季青", "士人", retainer_data.School.CONFUCIAN)
	teacher.duty = retainer_data.Duty.TEACH
	teacher.loyalty = 10.0
	state.retainers.clear()
	paused = true
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		_expect(false, "Mount the fixed estate.")
		quit(1)
		return
	await scene_changed
	ui = current_scene.get_node("UI")
	ui.world.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	public_plot = state.well_fields[0].center_pos
	await _check_ripe_public_plot()
	await _check_estate_loss_from_ledger()
	await _check_combined_warning(teacher)
	_check_no_rank_loss(teacher)
	_expect(state.saved_games().is_empty(), "Opening and closing the warnings does not write a game save.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _set_ripe(cell: Vector2i) -> void:
	var crop: Resource = root.get_node("ItemManager").get_crop("millet")
	var nights: int = state.sowing_nights(crop)
	state.tilled_cells[cell] = true
	state.active_crops[cell] = {"id": "millet", "data": crop, "age": nights, "growth_nights": nights,
		"requires_channel": false, "watered": false}

func _warning(consequence: String, choices: Array[String]) -> Control:
	var warning := ui.get_node_or_null("Control/DialoguePanel") as Control
	_expect(warning != null and not ui.world.player.resting,
		"After the first tribute, intercept sleep before %s." % consequence)
	_stop_sleep()
	if warning:
		_expect(warning.context_label.text == "本期纳贡" and consequence in warning.text_label.text
			and "扣后余 %d" % threshold in warning.text_label.text, "Give the same score and consequence as the ledger.")
		var labels: Array = warning.choices.map(func(button: Button) -> String: return button.text)
		_expect(labels == choices and warning.choices[0].has_focus(), "Offer the safe default and an explicit sleep option.")
	return warning

func _check_ripe_public_plot() -> void:
	state.current_rank = state.Rank.ZHONG_SHI
	_set_ripe(public_plot)
	var before := _snapshot()
	ui.hud.sleep_button.pressed.emit()
	var warning := _warning("将削爵为下士", ["找熟公田", "查看今夜安排", "仍然过夜"])
	if warning:
		warning.choices[0].pressed.emit()
		await _settle()
		_expect(ui.directions.tracked_plot == public_plot and state.field_route_scope == state.FieldScope.PUBLIC,
			"Following the warning marks the ripe public plot without harvesting it.")
		ui.directions.cancel_tracking()
	_expect(_snapshot() == before, "Viewing the warning and marking a plot preserves the pending tribute and date.")

func _check_estate_loss_from_ledger() -> void:
	state.current_rank = state.Rank.XIA_SHI
	state.active_crops.erase(public_plot)
	_set_ripe(public_plot + Vector2i.RIGHT)
	var before := _snapshot()
	ui._show_night_rations()
	var book := ui.get_node("Control/NightRationsPanel") as Control
	_expect("将失去封地" in book.tribute_details.text, "The fixed night ledger already forecasts the estate loss.")
	book.sleep_button.pressed.emit()
	await _settle()
	var warning := _warning("将失去封地", ["查看今夜安排", "仍然过夜"])
	if warning:
		_expect("没有成熟的公田" in warning.text_label.text, "Ripe private crops cannot prevent a missed tribute.")
		warning.choices[0].pressed.emit()
		await _settle()
		book = ui.get_node_or_null("Control/NightRationsPanel") as Control
		_expect(book != null and "将失去封地" in book.tribute_details.text, "The safe default returns to the night ledger.")
		if book:
			book.free()
	_expect(_snapshot() == before, "The warning and ledger do not advance the evening.")

func _check_combined_warning(teacher: Resource) -> void:
	state.retainers.append(teacher)
	state.current_rank = state.Rank.DA_FU
	state.tax_reform_choice = state.TaxReformChoice.DELAYED
	state.tax_reform_day = state.tax_council_start_day()
	state.current_day = state.tax_reform_day + state.research_payment_interval() - 1
	state.food_storage = 0
	state.money = state.balance.research_monthly_cost - 7
	state.current_stamina = 0
	_set_ripe(public_plot)
	var before := _snapshot()
	ui.hud.sleep_button.pressed.emit()
	var warning := _warning("将削爵为上士", ["查看今夜安排", "打开市场备款", "仍然过夜"])
	if warning:
		var body: String = warning.text_label.text
		_expect("收割需" in body and "当前 0" in body and "讲学门客缺餐" in body
			and "还差 7" in body and "季青缺餐后将离任" in body, "Put all three risks and the harvest cost in one warning.")
		warning.free()
	_expect(_snapshot() == before, "Reading the combined warning does not spend, harvest or dismiss.")
	await _settle()

func _check_no_rank_loss(teacher: Resource) -> void:
	state.current_day = 20
	state.tax_reform_choice = state.TaxReformChoice.NONE
	state.food_storage = state.retainer_food_cost()
	_expect(teacher in state.night_rations_plan().fed, "The fixed meal reaches the teacher.")
	_expect(state.tribute_penalty_forecast().remaining > threshold, "A meal puts the score above the threshold.")
	_check_transition_without_warning()
	state.tax_reform_choice = state.TaxReformChoice.REFORMED
	state.food_storage = state.retainer_food_cost()
	_expect(state.tribute_penalty_forecast().is_empty(), "The reformed route has no tribute penalty.")
	_check_transition_without_warning()

func _check_transition_without_warning() -> void:
	var before := _snapshot()
	ui.hud.sleep_button.pressed.emit()
	var warning := ui.get_node_or_null("Control/DialoguePanel") as Control
	_expect(warning == null and ui.world.player.resting, "The tribute warning only interrupts a night with a rank consequence.")
	_stop_sleep()
	if warning:
		warning.free()
	_expect(_snapshot() == before, "Stop the transition before any overnight changes.")

func _stop_sleep() -> void:
	if ui.sleep_tween and ui.sleep_tween.is_running():
		ui.sleep_tween.kill()
		ui._clear_fader()

func _settle() -> void:
	for frame in 5:
		await process_frame

func _snapshot() -> Array:
	return [state.current_day, state.day_progress, state.current_rank, state.reputation, state.outcome,
		state.days_without_contribution, state.king_storage, state.money, state.food_storage,
		state.current_stamina, hash(state.active_crops), hash(state.tilled_cells), state.retainers.duplicate()]
