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
		push_error("Run the Six Arts check with an isolated smoke profile.")
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
	ui._show_six_arts()
	var panel: Control = ui.panel_manager.management_panel_instance
	var cards: Array[Node] = panel.stats_container.get_children()
	_expect(cards.size() == 6 and panel.tabs.get_tab_title(panel.tabs.current_tab) == "君子六艺",
		"The normal management entry opens a sheet with all six cards.")
	var book: Control = cards[4]
	var font: int = book.xp_label.get_theme_font_size(&"font_size")

	var literacy: Dictionary = state.player_stats.stats.LITERACY
	literacy.xp = 75
	state.player_stats.xp_changed.emit("书", 75, 100)
	_expect(panel.stats_container.get_child(4) == book and book.xp_label.text == "本级经验 75/100"
		and book.meter.value == 75.0 and "本次研读可达书 2 级" in panel.study_progress.text,
		"A change in experience updates the same card and the study estimate.")
	_expect(preferences.set_reading_size(2) == OK and book.xp_label.get_theme_font_size(&"font_size") == font + 6,
		"Numerical progress follows the reading size preference.")

	var before := {"day": state.current_day, "practices": state.practice_days.duplicate(), "stock": state.food_storage}
	panel.open_silk.pressed.emit()
	_expect(panel.tabs.get_tab_title(panel.tabs.current_tab) == "蚕桑" and panel.silk_panel.study_button.visible,
		"Checking the workshop requirement opens the actual silk page.")
	panel.silk_panel.study_button.pressed.emit()
	_expect(panel.tabs.get_tab_title(panel.tabs.current_tab) == "君子六艺", "The study link returns to the sheet.")

	state.practice_days["LITERACY"] = state.current_day
	literacy.merge({"level": 2, "xp": 25, "max_xp": 150}, true)
	state.money = state.balance.silk_workshop_cost - 8
	state.player_stats.xp_changed.emit("书", 25, 150)
	_expect(panel.read_button.disabled and "明日可再读" in panel.study_progress.text
		and "还差 8 铜钱" in panel.silk_requirement.text and "还差 1 级" in panel.irrigation_requirement.text,
		"Spent study, building cost and the next milestone are distinct statuses.")
	state.money = state.balance.silk_workshop_cost
	events.money_changed.emit(state.money)
	_expect("钱袋 %d 铜钱" % state.money in panel.silk_requirement.text and "还差" not in panel.silk_requirement.text,
		"The shown cost refreshes when the purse changes.")
	literacy.merge({"level": 3, "xp": 25, "max_xp": 225}, true)
	state.player_stats.xp_changed.emit("书", 25, 225)
	panel.open_irrigation.pressed.emit()
	_expect(panel.tabs.get_tab_title(panel.tabs.current_tab) == "科技" and not panel.irrigation_button.disabled
		and not state.tech_unlocked["irrigation"], "The water shortcut opens the eligible technology page.")
	panel.show_six_arts()
	await process_frame
	await process_frame
	_expect(root.get_visible_rect().encloses(panel.read_button.get_global_rect())
		and not panel.arts_scroll.get_global_rect().intersects(panel.read_button.get_global_rect()),
		"The primary action stays within the window below the sheet.")
	for first in [0, 3]:
		var row_y: float = cards[first].meter.get_global_rect().position.y
		_expect(is_equal_approx(cards[first + 1].meter.get_global_rect().position.y, row_y)
			and is_equal_approx(cards[first + 2].meter.get_global_rect().position.y, row_y),
			"Wrapped activity names keep all three meters on the same line.")
	_expect(paused and state.current_day == before.day and state.food_storage == before.stock and not state.silk_workshop.built
		and state.practice_days.size() == before.practices.size() + 1 and state.saved_games().is_empty(),
		"Only the pre-set example fields change while reading.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
