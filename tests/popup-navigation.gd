extends SceneTree

const DEVICE := 31

var pad: Node
var picker: OptionButton
var popup: PopupMenu
var choice := 0
var behind := 0
var section_events := 0
var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	pad = root.get_node("GamepadInput")
	root.get_node("GameEvents").management_section_requested.connect(func(_step: int): section_events += 1)
	var button := Button.new()
	button.position = Vector2(720, 80)
	button.text = "Outside the list"
	button.pressed.connect(func(): behind += 1)
	root.add_child(button)
	picker = OptionButton.new()
	picker.position = Vector2(160, 100)
	picker.size = Vector2(196, 50)
	picker.add_item("原选项")
	picker.add_item("暂不可选")
	picker.set_item_disabled(1, true)
	picker.add_item("下一项")
	picker.add_separator("分隔")
	picker.add_item("末项")
	picker.item_selected.connect(func(_index: int): choice += 1)
	root.add_child(picker)
	picker.select(0)
	picker.grab_focus()
	popup = picker.get_popup()
	await process_frame
	await _pad(JOY_BUTTON_A)
	_expect(popup.visible and popup.get_focused_item() == 0 and not pad.cursor.visible, "A opens the list on the current item.")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect(popup.get_focused_item() == 2 and picker.selected == 0, "Down skips the disabled row without choosing.")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect(popup.get_focused_item() == 4, "Down skips the separator.")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect(popup.get_focused_item() == 0, "Down can wrap to the first available row.")
	await _pad(JOY_BUTTON_DPAD_UP)
	_expect(popup.get_focused_item() == 4, "Up can wrap back to the last available row.")
	await _button(JOY_BUTTON_A, true)
	_expect(not popup.visible and choice == 1 and picker.selected == 4, "A confirms the highlighted row once on press.")
	await _button(JOY_BUTTON_A, false)
	_expect(not popup.visible and choice == 1 and behind == 0 and _returned(), "A release leaves the list closed and restores the pointer.")

	await _pad(JOY_BUTTON_A)
	await _pad(JOY_BUTTON_DPAD_UP)
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(popup.get_focused_item() == 2 and section_events == 0, "The list owns navigation while it is open.")
	await _pad(JOY_BUTTON_B)
	_expect(not popup.visible and picker.selected == 4 and choice == 1 and _returned(), "B cancels and returns to the same picker.")

	await _key(KEY_ENTER)
	await _key(KEY_DOWN)
	_expect(popup.visible and popup.get_focused_item() == 0 and not pad.active, "Keyboard arrows remain available.")
	await _key(KEY_ENTER)
	_expect(not popup.visible and picker.selected == 0 and choice == 2, "Enter still chooses the keyboard focus.")

	await _pad(JOY_BUTTON_A)
	var box := Rect2(Vector2(popup.position), Vector2(popup.size))
	pad.cursor.position = Vector2(box.get_center().x, box.end.y - 14.0)
	await _nudge_pointer()
	_expect(pad.cursor.visible and box.has_point(pad.cursor.position), "Stick motion restores the cursor inside the list.")
	await _pad(JOY_BUTTON_A)
	_expect(not popup.visible and picker.selected == 4 and choice == 3 and _returned(), "A also clicks the row under the stick pointer.")

	await _pad(JOY_BUTTON_A)
	pad.cursor.position = button.get_global_rect().get_center()
	await _nudge_pointer()
	await _pad(JOY_BUTTON_A)
	_expect(not popup.visible and picker.selected == 4 and choice == 3 and behind == 0 and _returned(),
		"A pointer click outside dismisses the list without changing the picker or clicking through.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _returned() -> bool:
	return picker.has_focus() and pad.cursor.visible and pad.cursor.position.is_equal_approx(picker.get_global_rect().get_center())

func _pad(button: JoyButton) -> void:
	await _button(button, true)
	await _button(button, false)

func _button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE
	event.button_index = button
	event.pressed = pressed
	await _deliver(event)

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		await _deliver(event)

func _nudge_pointer() -> void:
	for value: float in [0.65, 0.0]:
		var event := InputEventJoypadMotion.new()
		event.device = DEVICE
		event.axis = JOY_AXIS_RIGHT_X
		event.axis_value = value
		await _deliver(event)

func _deliver(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for frame in 4:
		await process_frame

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
