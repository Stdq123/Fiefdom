extends "res://tests/ResearchRationsReplay.gd"

var pad: RefCounted

func _fixture() -> void:
	var file := FileAccess.open(state.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"save_version": 2, "current_day": 50, "current_rank": state.Rank.DA_FU,
		"tax_reform_choice": state.TaxReformChoice.DELAYED, "tax_reform_year": 3, "tax_reform_day": 49,
		"food_storage": 4, "money": 105, "king_storage": 30, "private_harvest_total": 65, "reputation": 325,
		"player_inventory": 1, "crop_stock": {"beans": 1},
		"well_fields": [
			{"center_pos": "5,5", "is_unlocked": true, "reclamation_progress": 4},
			{"center_pos": "9,5", "is_unlocked": true, "reclamation_progress": 4},
		],
		"retainers": [
			{"name": "渠伯", "school": RetainerData.School.NONE, "duty": RetainerData.Duty.FIELD, "loyalty": 80},
			{"name": "季青", "school": RetainerData.School.CONFUCIAN, "duty": RetainerData.Duty.FIELD, "loyalty": 70},
			{"name": "弋戎", "school": RetainerData.School.MILITARY, "duty": RetainerData.Duty.GUARD, "loyalty": 20},
		],
	}))
	file.close()

func _press(control: Button) -> void:
	if pad:
		await pad._click(control)
	else:
		await _click(control)
	await tree.process_frame

func _menu_key(code: Key) -> void:
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		await tree.process_frame

func _select_teaching(picker: OptionButton) -> void:
	var menu := picker.get_popup()
	var index := picker.get_item_index(RetainerData.Duty.TEACH)
	if pad:
		var row := (float(index) + 0.5) / menu.item_count
		var target := menu.get_screen_transform() * (Vector2(menu.size) * Vector2(0.50, row))
		await pad._aim(tree.root.get_screen_transform().affine_inverse() * target)
		await pad._tap(JOY_BUTTON_A)
	else:
		menu.set_focused_item(index)
		await _menu_key(KEY_ENTER)
	await tree.process_frame
	_expect(not menu.visible and state.retainers[1].duty == RetainerData.Duty.TEACH,
		"Confirm the teaching duty through the real popup.")

func _open_roster() -> Control:
	await _press(ui.manage_button)
	return ui.panel_manager.management_panel_instance

func _before_preview() -> void:
	await _save_manually()
	var roster := await _open_roster()
	var duty: OptionButton = roster.retainer_list_container.get_child(1).duty_picker
	await _press(duty)
	var title := duty.get_popup().get_item_text(duty.get_item_index(RetainerData.Duty.TEACH))
	_expect(duty.get_popup().visible and title == "礼仪教习", "The previous package's duty menu shows only the name.")
	await _capture("00-old-duty-list")
	await _select_teaching(duty)
	await _press(roster.close_button)
	var night := await _open()
	_expect(night != null and "预计离任 · 弋戎" in night.meal_forecast.text, "The previous package shows the consequence after assigning the duty.")
	await _capture("01-old-shortage-after-assignment")
	print("DUTY_RATIONS_BEFORE menu=", title, " served=", state.night_rations_plan().served,
		" need=", state.retainer_food_cost(), " departing=", state.night_rations_plan().departing)

func _check_steward_preview(roster: Control) -> void:
	var picker: OptionButton = roster.steward_picker
	for index in picker.item_count:
		if picker.get_item_metadata(index) == state.retainers[1]:
			picker.select(index)
			picker.item_selected.emit(index)
			_expect("今夜可供 3/5 份" in roster.steward_preview.text and "离任 弋戎" in roster.steward_preview.text,
				"Assigning the field steward shows the same projected meal before confirming the handover.")
			return
	_expect(false, "The unlocked second field allows a steward handover.")

func _prepare_and_assign() -> void:
	var roster := await _open_roster()
	var duty: OptionButton = roster.retainer_list_container.get_child(1).duty_picker
	var menu := duty.get_popup()
	var teaching := duty.get_item_index(RetainerData.Duty.TEACH)
	_expect("4 份" in roster.roster_meal_summary.text and tree.root.get_visible_rect().encloses(roster.roster_night_rations.get_global_rect()),
		"The ordinary roster shows today's food and its night-plan shortcut within the viewport.")
	_check_steward_preview(roster)
	await _press(duty)
	var warning := menu.get_item_text(teaching)
	_expect(menu.visible and "礼仪教习 · 2 份" in warning and "今夜可供 3/5 份 · 离任 弋戎" in warning,
		"See the specialist's portion, the household meal and who could leave before selecting.")
	_expect("再备 1 份粮" in menu.get_item_tooltip(teaching) and state.retainers[1].duty == RetainerData.Duty.FIELD
		and state.food_storage == 4 and state.money == 105 and state.retainers[2].loyalty == 20
		and state.crop_stock.count("beans") == 1, "Previewing an assignment leaves the role, grain, fee and loyalty untouched.")
	await _capture("00-before-assigning")
	if pad:
		await pad._tap(JOY_BUTTON_B)
	else:
		await _menu_key(KEY_ESCAPE)
	if not _expect(roster.visible and not menu.visible and state.retainers[1].duty == RetainerData.Duty.FIELD,
		"Cancel the popup and keep the original assignment."):
		return
	await _press(roster.roster_night_rations)
	var night := _panel()
	if not _expect(night != null and night.visible and "预留 100 铜钱" in night.research_fee.text,
		"The roster opens the genuine night sheet with the research installment protected."):
		return
	await _press(night.delegate)
	if pad:
		var budget: SpinBox = night.budget
		night.scroll.ensure_control_visible(budget)
		await tree.process_frame
		var bounds := budget.get_global_rect()
		await pad._aim(Vector2(bounds.end.x - 7, bounds.get_center().y - 7))
		for _portion in 5:
			await pad._tap(JOY_BUTTON_A)
	else:
		await _enter_budget(night, 5)
	await _press(night.close_button)
	if not _expect(roster.visible and _panel() == null and state.night_rations.copper_limit == 5,
		"Return to the same roster with a budget for one extra ration."):
		return
	_expect("今夜购粮 5 铜钱" in roster.steward_preview.text and "离任" not in roster.steward_preview.text,
		"The steward forecast also updates as soon as the night plan changes.")
	await _press(duty)
	var funded := menu.get_item_text(teaching)
	_expect("今夜购粮 5 铜钱" in funded and "离任" not in funded and state.retainers[1].duty == RetainerData.Duty.FIELD,
		"The re-opened menu quotes the actual purchase after accounting for protected crops and research.")
	await _capture("01-funded-role")
	await _select_teaching(duty)
	_expect("5 份" in roster.roster_meal_summary.text and "离任" not in roster.roster_meal_summary.text,
		"The roster updates after the real choice and shows the funded household meal.")
	await _capture("02-after-assignment")
	print("DUTY_RATIONS_PREVIEW window=", tree.root.size, " before=", warning, " funded=", funded)
	await _press(roster.close_button)
	await _press(ui.sleep_button)
	await _wait_for_dawn("03-real-night")
	var meal: Dictionary = state.night_rations.last
	_expect(state.current_day == 51 and meal.get("served") == 5 and meal.get("need") == 5 and meal.get("copper") == 5
		and not meal.has("departed") and state.retainers.size() == 3 and state.crop_stock.count("beans") == 1
		and state.money == 0 and state.last_dawn.get("research_paid") == 100 and state.research_days_remaining() == 22
		and state.player_stats.stats["RITES"]["xp"] == state.balance.confucian_teaching_rites_xp,
		"The actual night funds all meals, retains the guard and beans, pays the forecast research fee and starts teaching.")
	print("DUTY_RATIONS_DAWN day=", state.current_day, " served=", meal.get("served"), " spent=", meal.get("copper"),
		" fee=", state.last_dawn.get("research_paid", 0), " roster=", state.retainers.size())

func run_duty_rations(host: SceneTree, captures := "", variant := "duty-rations") -> void:
	tree = host
	state = tree.root.get_node("Global")
	capture_dir = captures
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated duty preview profile."):
		_end()
		return
	state.balance.raid_first_day = 10000
	tree.root.notify_mouse_entered()
	if variant not in ["duty-rations-resume", "duty-rations-pad"] or state.latest_saved_game().is_empty():
		_fixture()
	await _continue()
	if _expect(state.current_day == 50 and state.food_storage == 4 and state.money == 105
		and state.research_fee_due(51) == 100 and state.retainers.size() == 3 and state.retainer_food_cost() == 4,
		"The same evening starts with three retainers, four meals and 100 copper due for research."):
		if variant == "duty-rations-before":
			await _before_preview()
		else:
			if variant == "duty-rations-pad":
				pad = load("res://tests/GamepadReplay.gd").new()
				pad.tree = tree
				pad.pad = GamepadInput
			await _prepare_and_assign()
			if pad:
				_expect(pad.failures == 0, "The compact controller interaction stays usable.")
	tree.unload_current_scene()
	await tree.process_frame
	_end()
