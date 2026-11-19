extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _tab(backward: bool) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.physical_keycode = KEY_TAB
		event.shift_pressed = backward
		event.pressed = down
		root.push_input(event, true)
	await process_frame

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run calendar-reading in an isolated profile.")
		quit(1)
		return
	var state := root.get_node("Global")
	var preferences := root.get_node("Preferences")
	var festival: int = state.SOLAR_TERMS.find("冬至") * state.balance.days_per_solar_term + 1
	state.current_day = festival - 2
	# Give focus a valid target behind the calendar to catch modal escapes.
	var hud_action := Button.new()
	hud_action.text = "HUD"
	root.add_child(hud_action)
	var book = load("res://scenes/SeasonCalendar.tscn").instantiate()
	book.controls_blocked = func(): return false
	root.add_child(book)
	book.open_day(festival)
	var event_note: Label = book.event_note
	var standard := event_note.get_theme_font_size("font_size")
	_expect(preferences.set_reading_size(2) == OK, "Set the largest reading size.")
	for frame in 6:
		await process_frame
	var modal: Control = book.modal
	_expect(event_note.get_theme_font_size("font_size") == standard + 6 and "冬至" in event_note.text,
		"The winter plan grows with the reading size.")
	_expect(book.date_context.text == "2 天后" and book.guide.is_visible_in_tree()
		and book.keep_soup.is_visible_in_tree(), "The upcoming date retains its route and pantry actions.")
	for backward in [false, true]:
		for step in 24:
			await _tab(backward)
			var focus := root.gui_get_focus_owner()
			_expect(focus != null and modal.is_ancestor_of(focus), "Tab must stay inside the calendar.")
	_expect(state.current_day == festival - 2 and state.saved_games().is_empty(),
		"Browsing the calendar keeps the date and the save catalog.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
