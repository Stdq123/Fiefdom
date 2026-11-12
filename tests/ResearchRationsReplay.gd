extends "res://tests/RationPriorityReplay.gd"

const PUBLIC := Vector2i(5, 5)
const PRIVATE := Vector2i(6, 5)

func _fixture() -> void:
	var millet := {"id": "millet", "age": 2, "growth_nights": 2}
	var hemp := {"id": "hemp", "age": 2, "growth_nights": 2}
	var save := FileAccess.open(state.SAVE_PATH, FileAccess.WRITE)
	save.store_string(JSON.stringify({
		"save_version": 2, "current_day": 50, "current_rank": state.Rank.DA_FU,
		"tax_reform_choice": state.TaxReformChoice.DELAYED, "tax_reform_year": 3, "tax_reform_day": 49,
		"food_storage": 0, "money": 105, "king_storage": 30, "private_harvest_total": 65, "reputation": 325,
		"player_inventory": 2, "crop_stock": {"beans": 1, "hemp": 1},
		"retainers": [
			{"name": "石墨", "school": 2, "duty": 1, "loyalty": 20},
			{"name": "季青", "school": 1, "duty": 2, "loyalty": 20},
		],
		"silk_workshop": {"built": true, "cocoons": 3, "night_reeling": true},
		"active_crops": {"5,5": millet, "6,5": hemp},
	}))
	save.close()

func _save_manually() -> void:
	await _click(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _click(button)
			break
	_expect(settings.save_status.text == "游戏已保存", "Save the bedtime policy from Settings.")
	await _click(settings.close_button)

func _prepare() -> Control:
	var panel := await _open()
	if not legacy:
		await _click(panel.delegate)
		await _enter_budget(panel, 15)
	_expect(state.night_rations.enabled and state.night_rations.copper_limit == 15
		and state.current_day == 50 and state.money == 105, "Use the ordinary night budget the day before the research fee.")
	return panel

func _old_night(panel: Control) -> void:
	_expect("15 铜钱" in panel.forecast.text, "The previous program quotes the entire household meal.")
	await _capture("01-old-meal-quote")
	await _click(panel.close_button)
	await _save_manually()
	await _sleep("02-old-unpaid-fee")
	_expect(state.current_day == 51 and state.money == 90 and state.research_choice_pending
		and state.night_rations.last.served == 4, "The old automatic purchase causes the funded installment to fail.")
	print("RESEARCH_RATIONS_BASELINE day=", state.current_day, " copper=", state.money,
		" fed=", state.night_rations.last.served, " forced_choice=", state.research_choice_pending, " save=", state.manual_save_path())

func _new_night(panel: Control) -> void:
	_check_window(panel)
	var partial: CheckButton = panel.get_node("%PartialMeals")
	var fee: Label = panel.get_node("%ResearchFee")
	_expect(fee.visible and "预留 100 铜钱" in fee.text and not partial.button_pressed
		and "还差 2 份" in panel.forecast.text, "Reserve the due fee and continue the existing full-table policy.")
	await _capture("01-reserved-research-fee")
	await _click(partial)
	_expect("先补 2 份" in panel.forecast.text and "购粮 1 份（5 铜钱）" in panel.forecast.text
		and "领足 石墨" in panel.meal_forecast.text, "The partial quote uses one crop and one affordable portion.")
	if not await _choose(panel, 2):
		return
	_expect("领足 季青" in panel.meal_forecast.text and "预计离任 · 石墨" in panel.meal_forecast.text
		and "菽 1" in panel.keep.text, "The chosen worker gets a full meal while order stock stays reserved.")
	await _capture("02-partial-meal-and-fee")
	await _click(panel.get_node("%Market"))
	var management: Control = ui.panel_manager.management_panel_instance
	_expect("自动补 2 份 · 仍缺 2 份" in management.market_panel.food_label.text,
		"The market uses the same partial forecast.")
	await _click(management.get_node("CloseButton"))
	panel = await _open()
	if not legacy:
		await _click(panel.close_button)
		await _save_manually()
		await _continue()
		panel = await _open()
		_expect(panel.get_node("%PartialMeals").button_pressed and panel.priority_picker.selected == 2
			and state.current_day == 50 and state.money == 105, "Continue restores the selected meal policy before any charges.")
	var reputation: int = state.reputation
	await _overnight(panel, "03-fee-paid-at-dawn")
	var last: Dictionary = state.night_rations.last
	_expect(state.current_day == 51 and state.money == 0 and not state.research_choice_pending
		and state.research_days_remaining() == 22 and last.copper == 5 and last.served == 2 and last.need == 4
		and last.used.get("hemp", 0) == 1 and state.crop_stock.count("beans") == 1
		and state.food_storage == 0 and state.retainers.size() == 1 and state.retainers[0].name == "季青"
		and state.reputation == reputation + state.balance.confucian_teaching_reputation,
		"Pay the installment once and feed the selected teacher with exactly the forecast trade.")
	_expect("研究经费已缴 100" in ui.dawn_caption.text and "备粮 2 份" in ui.dawn_caption.text,
		"The dawn receipt shows both debits even though someone missed dinner.")
	print("RESEARCH_RATIONS_SETTLED day=", state.current_day, " money=", state.money, " remaining=", state.research_days_remaining(),
		" served=", last.served, "/", last.need, " purchase=", last.copper, " priority=", state.retainers[0].name)
	await _continue()
	_expect(state.current_day == 51 and state.money == 0 and state.night_rations.last == last
		and state.night_rations.partial_meals, "The morning checkpoint restores the receipts without charging again.")

func _check_whole_portions() -> void:
	var world: Node2D = tree.current_scene.get_node("World")
	var tiles: TileMapLayer = world.tile_map
	var treasury: int = state.king_storage
	var crops: int = state.player_inventory
	for cell in [PUBLIC, PRIVATE]:
		var point := tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)
		var mouse := InputEventMouseButton.new()
		mouse.position = point
		mouse.global_position = point
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = true
		tree.root.push_input(mouse, true)
		mouse = mouse.duplicate()
		mouse.pressed = false
		tree.root.push_input(mouse, true)
		await tree.process_frame
	_expect(state.king_storage == treasury + 1 and state.player_inventory == crops + 1,
		"The normal farm still credits both public and private harvests.")
	var panel := await _open()
	await _enter_budget(panel, 0)
	var plan: Dictionary = state.night_rations_plan()
	_expect(plan.served == 0 and plan.converted == 0 and plan.bought == 0 and plan.missing == 2,
		"Keep the one unreserved crop when it cannot fund a complete specialist ration.")
	await _capture("04-one-portion-in-hand")
	await _overnight(panel)
	_expect(state.current_day == 52 and state.crop_stock.count("hemp") == 1 and state.crop_stock.count("beans") == 1
		and state.night_rations.last.used.is_empty() and state.night_rations.last.served == 0,
		"The incomplete portion stays available in the morning.")
	var gap: int = state.balance.research_monthly_cost - state.money
	panel = await _open()
	_expect("还差 %d" % gap in panel.get_node("%ResearchFee").text, "Show the gap when the next installment is genuinely underfunded.")
	await _overnight(panel)
	_expect(state.current_day == 53 and state.research_choice_pending and "研究经费还差 %d" % gap in ui.dawn_caption.text,
		"An unpaid installment still returns the envoy for a decision.")
	print("RESEARCH_RATIONS_UNFUNDED day=", state.current_day, " gap=", gap, " forced_choice=", state.research_choice_pending)

func run_research_rations(game_tree: SceneTree, baseline := false, captures := "") -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the research ration replay."):
		_end()
		return
	state = tree.root.get_node("Global")
	state.balance.raid_first_day = 10000
	capture_dir = captures
	tree.root.notify_mouse_entered()
	if not legacy:
		_fixture()
	await _continue()
	var panel := await _prepare()
	if baseline:
		await _old_night(panel)
	else:
		await _new_night(panel)
		if not failed:
			await _check_whole_portions()
	tree.unload_current_scene()
	await tree.process_frame
	_end()
