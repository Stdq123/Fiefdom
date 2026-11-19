extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run first-tribute-reading in an isolated profile.")
		quit(1)
		return
	var state := root.get_node("Global")
	var preferences := root.get_node("Preferences")
	paused = true
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		push_error("Cannot mount the paused estate.")
		quit(1)
		return
	await scene_changed
	var ui := current_scene.get_node("UI")
	var handover: Control = ui.handover
	paused = false
	ui._open_handover()
	_expect(paused and handover.modal.visible, "Open the handover from the estate UI.")
	var due: int = state.tribute_deadline()
	_expect(handover.tribute_due.text == "首贡 1 份 · 第 %d 天过夜前" % due,
		"The handover shows the actual deadline.")
	_expect(handover.sketch.get_child(4).get_child(0).text == "公田"
		and handover.sketch.get_child(0).get_child(0).text == "私", "Text identifies public and private plots.")
	var letter := handover.get_node("%Letter") as Label
	var standard := letter.get_theme_font_size("font_size")
	_expect(preferences.set_reading_size(2) == OK and letter.get_theme_font_size("font_size") == standard + 6,
		"The handover follows the selected reading size.")
	handover.close_map()
	paused = true

	state.current_day = due
	state.days_without_contribution = state.balance.no_contribution_threshold - 1
	state.estate_room = state.EstateRoom.HALL
	_expect(ui._warn_before_first_tribute(""), "The unsown public plot has a deadline warning.")
	var warning := ui.get_node("Control/DialoguePanel") as Control
	_expect("从南门出去" in warning.text_label.text and "声望" in warning.text_label.text,
		"The indoor warning shows the way back and the consequence.")
	_expect(warning.choices[0].has_focus() and warning.choices.back().text == "仍然过夜",
		"The field action remains the default.")
	warning.free()
	_expect(state.current_day == due and state.active_crops.is_empty() and state.saved_games().is_empty(),
		"Opening both screens leaves the seeded estate on the same day.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
