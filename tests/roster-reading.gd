extends SceneTree

var failed := false

func _initialize() -> void:
	_check.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _check() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run roster-reading in an isolated profile.")
		quit(1)
		return
	paused = true
	if change_scene_to_file("res://scenes/Main.tscn") != OK:
		push_error("Load the paused estate for the roster panels.")
		quit(1)
		return
	await scene_changed
	var state := root.get_node("Global")
	var events := root.get_node("GameEvents")
	var prefs := root.get_node("Preferences")
	var retainer_data: GDScript = state.retainers[0].get_script()
	var scholar: Resource = retainer_data.new("季青", "士人", retainer_data.School.CONFUCIAN)
	var guard: Resource = retainer_data.new("弋戎", "弓手", retainer_data.School.MILITARY)
	guard.duty = retainer_data.Duty.GUARD
	guard.loyalty = 20.0
	var steward: Resource = retainer_data.new("陶辛", "织工")
	steward.duty = retainer_data.Duty.STEWARD
	steward.assigned_area = state.well_fields[0].center_pos
	state.retainers.assign([scholar, guard, steward])
	state.food_storage = 2
	var manager: Node = current_scene.get_node("UI").panel_manager
	manager.show_management_panel()
	var panel: Control = manager.management_panel_instance
	var roster: VBoxContainer = panel.retainer_list_container
	var first := roster.get_child(0)
	var second := roster.get_child(1)
	var third := roster.get_child(2)
	_expect(first.meal_cost.text == "每夜 1 份" and not first.meal_status.visible
		and second.meal_cost.text == "每夜 2 份" and second.meal_status.text == "预计离任"
		and third.meal_status.text == "预计缺餐" and third.field_picker.visible,
		"The forecast identifies the affected rows and the steward retains field selection.")
	var duty: OptionButton = first.duty_picker
	var menu := duty.get_popup()
	var teaching := duty.get_item_index(retainer_data.Duty.TEACH)
	var font := menu.get_theme_font_size("font_size")
	var summary: Label = panel.roster_meal_summary
	var summary_size := summary.get_theme_font_size("font_size")
	_expect(prefs.set_reading_size(2) == OK, "Set the largest reading size.")
	menu.about_to_popup.emit()
	_expect(menu.get_theme_font_size("font_size") == font + 6 and summary.get_theme_font_size("font_size") == summary_size + 6
		and menu.get_item_text(teaching) == "礼仪教习 · 2 份 · 今夜可供 2/6 份 · 离任 弋戎"
		and scholar.duty == retainer_data.Duty.FIELD, "The enlarged preview preserves the hypothetical meal and current duty.")
	panel.show_neighbors()
	state.food_storage = 5
	events.food_changed.emit(state.food_storage)
	panel.show_estate()
	_expect(summary.text == "今夜口粮齐 · 5 份" and not second.meal_status.visible and not third.meal_status.visible,
		"Returning from the full-width journal refreshes the roster forecast.")
	state.food_storage = 0
	events.food_changed.emit(state.food_storage)
	_expect(first.meal_status.visible and first.meal_status.text == "预计缺餐"
		and second.meal_status.visible and second.meal_status.text == "预计离任",
		"The visible roster updates when the available grain changes.")
	_expect(state.current_day == 1 and guard.loyalty == 20.0 and state.saved_games().is_empty(),
		"Reading the roster keeps the date, loyalty and save catalog.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
