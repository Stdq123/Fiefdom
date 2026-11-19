extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the technology sheet check with an isolated smoke profile.")
		quit(1)
		return
	paused = true
	if change_scene_to_file("res://scenes/Main.tscn") != OK:
		quit(1)
		return
	await scene_changed
	var state := root.get_node("Global")
	var events := root.get_node("GameEvents")
	var preferences := root.get_node("Preferences")
	var ui := current_scene.get_node("UI")
	var world := current_scene.get_node("World")
	ui._show_water_technology()
	var panel: Control = ui.panel_manager.management_panel_instance
	_expect(panel.tabs.get_tab_title(panel.tabs.current_tab) == "科技"
		and panel.water_next.visible and "书艺 1/3 级" in panel.water_status.text
		and panel.bow_study.visible and "射艺 1/2 级" in panel.bow_status.text,
		"The normal entrance shows both unmet research requirements.")
	var cost: int = state.channel_cost()
	_expect("解锁免费" in panel.water_budget.text and "每格 %d 铜钱" % cost in panel.water_budget.text,
		"Research and construction have distinct prices.")
	var font: int = panel.rank_progress_label.get_theme_font_size(&"font_size")
	_expect(preferences.set_reading_size(2) == OK and panel.rank_progress_label.get_theme_font_size(&"font_size") == font + 6,
		"Rank progress uses the reading size preference.")
	panel.water_next.pressed.emit()
	_expect(panel.tabs.get_tab_title(panel.tabs.current_tab) == "君子六艺" and panel.read_button.has_focus(),
		"The literacy shortcut focuses study without spending the daily turn.")
	panel.show_technology()
	panel.bow_study.pressed.emit()
	_expect(panel.tabs.get_tab_title(panel.tabs.current_tab) == "君子六艺" and panel.arts_scroll.scroll_vertical == 0,
		"The archery shortcut shows the cards from the top.")
	panel.show_technology()
	var literacy: Dictionary = state.player_stats.stats.LITERACY
	var archery: Dictionary = state.player_stats.stats.ARCHERY
	literacy.level = 3
	archery.level = 2
	state.player_stats.xp_changed.emit("射", 0, 150)
	_expect(panel.irrigation_button.visible and not panel.irrigation_button.disabled
		and panel.bow_button.visible and not panel.bow_button.disabled,
		"Reaching each original level enables its own research action.")

	state.tech_unlocked.irrigation = true
	state.tech_unlocked.composite_bow = true
	state.money = maxi(0, cost - 2)
	events.irrigation_unlocked.emit()
	state.player_stats.xp_changed.emit("书", 0, 225)
	_expect(panel.water_next.text == "指路去泉眼" and "0 块井田接水" in panel.water_status.text
		and "挖一格还差 2 铜钱" in panel.water_budget.text and not panel.bow_button.visible,
		"Unlocked water and bow show their new status, including a construction shortage.")
	state.money = cost
	events.money_changed.emit(state.money)
	_expect("钱袋 %d 铜钱" % cost in panel.water_budget.text and "还差" not in panel.water_budget.text,
		"The construction note follows the purse.")
	state.irrigation.add_channels(world.irrigation_overlay.starter_canal_cells())
	events.channels_changed.emit()
	_expect("1 块井田接水" in panel.water_status.text, "The page reports connected fields from the existing canal network.")
	var position: Vector2 = world.player.position
	var channels: Dictionary = state.irrigation.channels.duplicate()
	panel.water_next.pressed.emit()
	_expect(not panel.visible and ui.directions.tracked_place == state.WATER_SOURCE and world.player.position == position,
		"The water shortcut marks the spring and returns to the map.")

	ui._show_water_technology()
	var target: int = state.promotion_reputation()
	state.reputation = target
	state.zhou_li_score = "下下"
	events.reputation_changed.emit(state.reputation)
	_expect("周礼为「下下」" in panel.rank_requirement.text and not panel.rank_next.visible
		and "井田上限 1 → 2 块" in panel.rank_progress_label.text,
		"Reputation alone cannot meet the first promotion requirement.")
	state.zhou_li_score = "中"
	state.days_without_contribution = 1
	events.reputation_changed.emit(state.reputation)
	_expect("第 %d 天晚" % state.tribute_deadline() in panel.rank_tribute.text,
		"An upcoming contribution deadline stays visible before the penalty is due.")
	state.days_without_contribution = state.balance.no_contribution_threshold - 1
	events.reputation_changed.emit(state.reputation)
	_expect("先补纳贡" in panel.rank_next.text and "扣后余 %d" % (target - state.tribute_penalty_tonight()) in panel.rank_tribute.text,
		"Tonight's tribute penalty can put an otherwise eligible promotion below its threshold.")
	state.tax_reform_choice = state.TaxReformChoice.REFORMED
	events.tax_reform_choice_made.emit(state.tax_reform_choice)
	_expect(not panel.rank_tribute.visible and "过夜核定爵位" in panel.rank_next.text,
		"Changing the tax choice updates the warning immediately.")

	state.current_rank = state.Rank.ZHONG_SHI
	events.rank_changed.emit(state.current_rank)
	_expect("最高 3 级" in panel.rank_requirement.text and panel.rank_arts.visible,
		"The middle rank shows progress toward its best-art threshold.")
	state.current_rank = state.Rank.DA_FU
	literacy.level = state.balance.minister_rank_art_level
	events.rank_changed.emit(state.current_rank)
	_expect("六艺 1/6 项达 %d 级" % literacy.level in panel.rank_requirement.text,
		"The minister requirement counts every art separately.")
	state.current_rank = state.Rank.QING
	events.rank_changed.emit(state.current_rank)
	_expect(not panel.rank_meter.visible and not panel.rank_arts.visible and "已至最高爵位" in panel.rank_progress_label.text,
		"The highest rank shows no promotion meter.")
	_expect(paused and world.player.position == position and state.current_day == 1 and state.money == cost
		and state.irrigation.channels == channels and state.practice_days.is_empty() and state.saved_games().is_empty(),
		"Reading the sheet and setting a marker leave the paused game and user saves untouched.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
