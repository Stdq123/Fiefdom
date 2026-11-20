extends CanvasLayer

signal changed

const PANEL_FOCUS := preload("res://scripts/PanelFocus.gd")
const DEADZONE := 0.22
const TRIGGER_POINT := 0.45
const POINTER_SPEED := 740.0
const ACTION_BUTTONS := {
	JOY_BUTTON_Y: KeyBindings.MAP,
	JOY_BUTTON_BACK: KeyBindings.ALMANAC,
	JOY_BUTTON_START: KeyBindings.ROTATE,
}
const DIALOGUE_MOVES := {
	JOY_BUTTON_DPAD_LEFT: -1, JOY_BUTTON_DPAD_UP: -1,
	JOY_BUTTON_DPAD_RIGHT: 1, JOY_BUTTON_DPAD_DOWN: 1,
}
const UI_DIRECTIONS := {
	JOY_BUTTON_DPAD_LEFT: &"ui_left", JOY_BUTTON_DPAD_UP: &"ui_up",
	JOY_BUTTON_DPAD_RIGHT: &"ui_right", JOY_BUTTON_DPAD_DOWN: &"ui_down",
}

class AimCursor extends Node2D:
	func _draw() -> void:
		var edge := Color("#22281d")
		var ink := Color("#fff1bc")
		for axis: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(axis * 4.0, axis * 10.0, edge, 4.0)
			draw_line(axis * 4.0, axis * 9.0, ink, 2.0)
		draw_rect(Rect2(-2, -2, 4, 4), edge)
		draw_rect(Rect2(-1, -1, 2, 2), ink)

var active := false
var device_id := -1
var left_down := false
var right_down := false
var filling := false
var pointer_suspended := false
var _popup: PopupMenu
var _popup_uses_pointer := false
var _popup_a_pressed := false
var cursor := AimCursor.new()
@onready var window := get_tree().root

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1025 # Above embedded confirmation and option windows.
	add_child(cursor)
	cursor.hide()
	set_process(false)
	# The gamepad drives the pointer. Keep Godot's keyboard UI shortcuts,
	# and let each gamepad button reach the UI only once.
	for action in [&"ui_accept", &"ui_select", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
		for binding in InputMap.action_get_events(action):
			if binding is InputEventJoypadButton or binding is InputEventJoypadMotion:
				InputMap.action_erase_event(action, binding)
	window.window_input.connect(_window_input)
	window.size_changed.connect(_clamp_pointer)
	get_tree().scene_changed.connect(snap_pointer_to_focus)
	Input.joy_connection_changed.connect(_joy_connection_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_use_mouse()

func _joy_connection_changed(id: int, connected: bool) -> void:
	if id == device_id and not connected:
		_use_mouse()

func _window_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or (event is InputEventMouseMotion and not event.relative.is_zero_approx()) \
			or (event is InputEventKey and event.pressed):
		_use_mouse()
	elif event is InputEventJoypadButton:
		if event.pressed:
			_use_gamepad(event.device)
		if active and event.device == device_id:
			_pad_button.call_deferred(event.device, event.button_index, event.pressed)
	elif event is InputEventJoypadMotion:
		var threshold := TRIGGER_POINT if event.axis >= JOY_AXIS_TRIGGER_LEFT else DEADZONE
		if absf(event.axis_value) > threshold:
			_use_gamepad(event.device)
		if active and event.device == device_id and event.axis >= JOY_AXIS_TRIGGER_LEFT:
			_pad_trigger.call_deferred(event.device, event.axis, event.axis_value > TRIGGER_POINT)

func _use_gamepad(id: int) -> void:
	if device_id == id:
		return
	if active:
		_release_pointer()
		device_id = id
		return
	device_id = id
	active = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	cursor.visible = not pointer_suspended
	set_process(true)
	snap_pointer_to_focus.call_deferred(_menu_controls())
	changed.emit()

func _use_mouse() -> void:
	if not active:
		return
	active = false
	device_id = -1
	_release_pointer()
	cursor.hide()
	set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	changed.emit()

func _release_pointer() -> void:
	_popup_a_pressed = false
	_popup_uses_pointer = false
	if left_down:
		left_down = false
		# End a drag without clicking the button that was under the pointer.
		_mouse_button(MOUSE_BUTTON_LEFT, false, window.get_visible_rect().end + Vector2.ONE)
	if right_down:
		right_down = false
		_mouse_button(MOUSE_BUTTON_RIGHT, false, cursor.position)
	if filling:
		filling = false
		_action(KeyBindings.FILL, false)
	if get_tree().get_first_node_in_group("timed_practice"):
		_action(KeyBindings.RHYTHM, false)

func _menu_controls() -> bool:
	var actor := get_tree().get_first_node_in_group("player")
	return get_tree().paused or actor == null or actor.conversation_open or actor.resting or actor.menu_open

func _stick(x_axis: JoyAxis, y_axis: JoyAxis) -> Vector2:
	var vector := Vector2(Input.get_joy_axis(device_id, x_axis), Input.get_joy_axis(device_id, y_axis))
	var magnitude := inverse_lerp(DEADZONE, 1.0, clampf(vector.length(), DEADZONE, 1.0))
	return vector.normalized() * magnitude

func _left_direction() -> Vector2:
	var pad := Vector2(
		int(Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_RIGHT)) - int(Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_LEFT)),
		int(Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_DOWN)) - int(Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_UP)))
	return _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y) if pad.is_zero_approx() else pad.normalized()

func move_direction() -> Vector2:
	return _left_direction() if active else Vector2.ZERO

func suspend_pointer(suspended: bool) -> void:
	pointer_suspended = suspended
	cursor.visible = active and not suspended
	if suspended:
		_release_pointer()

func interact_key() -> String:
	return "X" if active else Preferences.key_label(KeyBindings.INTERACT)

func back_key() -> String:
	return "B" if active else "Esc"

func bow_instruction() -> String:
	return "用右摇杆瞄准，按 RT 放箭" if active else "右键朝来敌射箭"

func interact_hint(caption: String) -> String:
	return "%s · %s" % [caption, interact_key()]

func meal_hint() -> String:
	return "点路餐按钮" if active else "按 %s" % Preferences.key_label(KeyBindings.MEAL)

func rhythm_key() -> String:
	return "X" if active else Preferences.key_label(KeyBindings.RHYTHM)

func _process(delta: float) -> void:
	if pointer_suspended:
		return
	var direction := _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	if direction.is_zero_approx() and _menu_controls():
		var directional_focus := _active_dialogue() or _active_backpack() or _menu_has_directional_focus()
		direction = _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y) if directional_focus else _left_direction()
	if direction.is_zero_approx():
		return
	var previous := cursor.position
	cursor.position += direction * direction.length() * POINTER_SPEED * delta
	_clamp_pointer()
	if cursor.position != previous:
		var popup := _focused_window() as PopupMenu
		if popup:
			_watch_popup(popup)
			if not _popup_uses_pointer:
				popup.set_focused_item(-1)
				_popup_uses_pointer = true
		cursor.show()
		_motion(cursor.position - previous)

func _clamp_pointer() -> void:
	var bounds := window.get_visible_rect()
	cursor.position = cursor.position.clamp(bounds.position, bounds.end - Vector2.ONE)

func _focused_window() -> Window:
	for subwindow in window.get_embedded_subwindows():
		if subwindow.has_focus():
			return subwindow
	return window

func snap_pointer_to_focus(use_focus := true) -> void:
	if not active or pointer_suspended:
		return
	var focus_window := _focused_window()
	if focus_window is PopupMenu:
		_watch_popup(focus_window)
		if not _popup_uses_pointer:
			_focus_popup(focus_window)
		return
	cursor.show()
	var offset := Vector2(focus_window.position) if focus_window != window else Vector2.ZERO
	var focus := focus_window.gui_get_focus_owner() if use_focus else null
	if focus:
		var bounds := focus.get_global_rect()
		cursor.position = bounds.get_center() + offset
		if focus_window == window and _active_dialogue():
			cursor.position.x = bounds.position.x + 10.0
	else:
		cursor.position = focus_window.get_visible_rect().get_center() + offset
	_clamp_pointer()
	_motion(Vector2.ZERO)

func _active_dialogue() -> Node:
	var dialogue := get_tree().get_first_node_in_group("dialogue_panel")
	return null if dialogue and PANEL_FOCUS.has_popup(window) else dialogue

func _active_backpack() -> Control:
	var backpack := get_tree().get_first_node_in_group("backpack_panel") as Control
	if backpack and backpack.is_visible_in_tree() and not PANEL_FOCUS.has_popup(window):
		return backpack
	return null

func _menu_has_directional_focus() -> bool:
	var focus_window := _focused_window()
	if focus_window is PopupMenu:
		return true
	if focus_window != window:
		return focus_window.is_in_group("gamepad_directional_menu") and focus_window.gui_get_focus_owner() != null
	for panel in get_tree().get_nodes_in_group("gamepad_directional_menu"):
		if panel is Control and PANEL_FOCUS.input_owner(panel):
			return true
	return false

func _pad_button(id: int, button: JoyButton, pressed: bool) -> void:
	if id != device_id or (pointer_suspended and button != JOY_BUTTON_B):
		return
	if button == JOY_BUTTON_A and _popup_a_pressed:
		# The list can close on A press. Keep the release off the screen behind it.
		if not pressed:
			_popup_a_pressed = false
		return
	var popup := _focused_window() as PopupMenu
	if popup and _handle_popup_button(popup, button, pressed):
		return
	var dialogue := _active_dialogue()
	if dialogue and DIALOGUE_MOVES.has(button):
		if pressed:
			dialogue.move_choice(DIALOGUE_MOVES[button])
			snap_pointer_to_focus()
		return
	var backpack := _active_backpack()
	if UI_DIRECTIONS.has(button) and (backpack or _menu_has_directional_focus()):
		_action(UI_DIRECTIONS[button], pressed)
		if pressed:
			snap_pointer_to_focus()
		return
	match button:
		JOY_BUTTON_A:
			left_down = pressed
			_mouse_button(MOUSE_BUTTON_LEFT, pressed, cursor.position)
			if not pressed and _focused_window() is PopupMenu:
				snap_pointer_to_focus()
		JOY_BUTTON_B:
			_cancel(pressed)
		JOY_BUTTON_X:
			if get_tree().get_first_node_in_group("timed_practice"):
				_action(KeyBindings.RHYTHM, pressed)
			elif dialogue or not _menu_controls():
				_action(KeyBindings.INTERACT, pressed)
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
			if pressed:
				var step := -1 if button == JOY_BUTTON_LEFT_SHOULDER else 1
				if dialogue:
					if not left_down:
						dialogue.page_speech(step)
				elif backpack:
					if not left_down:
						backpack.cycle_page(step)
						snap_pointer_to_focus()
				elif not _menu_controls():
					GameEvents.seed_cycle_requested.emit(step)
				elif not left_down:
					GameEvents.management_section_requested.emit(step)
		JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK:
			if pressed:
				var wheel := MOUSE_BUTTON_WHEEL_UP if button == JOY_BUTTON_RIGHT_STICK else MOUSE_BUTTON_WHEEL_DOWN
				_mouse_button(wheel, true, cursor.position)
		_:
			if ACTION_BUTTONS.has(button):
				_action(ACTION_BUTTONS[button], pressed)

func _handle_popup_button(popup: PopupMenu, button: JoyButton, pressed: bool) -> bool:
	_watch_popup(popup)
	if UI_DIRECTIONS.has(button):
		if pressed:
			_focus_popup(popup)
		_action(UI_DIRECTIONS[button], pressed)
		return true
	match button:
		JOY_BUTTON_A:
			if not pressed or left_down:
				return false
			var bounds := Rect2(Vector2(popup.position), Vector2(popup.size))
			if _popup_uses_pointer and bounds.has_point(cursor.position):
				return false
			_popup_a_pressed = true
			if _popup_uses_pointer:
				_cancel(true)
			else:
				_focus_popup(popup)
				_action(&"ui_accept", true)
			return true
		JOY_BUTTON_B:
			return false
		JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK:
			return not _popup_uses_pointer
		_:
			return true

func _focus_popup(popup: PopupMenu) -> void:
	_popup_uses_pointer = false
	cursor.hide()
	if popup.get_focused_item() >= 0:
		return
	var picker := popup.get_parent() as OptionButton
	if (picker and picker.selected >= 0 and not popup.is_item_disabled(picker.selected)
			and not popup.is_item_separator(picker.selected)):
		popup.set_focused_item(picker.selected)

func _watch_popup(popup: PopupMenu) -> void:
	if _popup == popup:
		return
	_popup = popup
	_popup_uses_pointer = false
	var restore := _on_popup_closed.bind(popup)
	if not popup.popup_hide.is_connected(restore):
		popup.popup_hide.connect(restore, CONNECT_ONE_SHOT)

func _on_popup_closed(popup: PopupMenu) -> void:
	if _popup != popup:
		return
	_popup = null
	_popup_uses_pointer = false
	# Selecting a reading size can move the picker while its page relays out.
	var tree := get_tree()
	await tree.process_frame
	await tree.process_frame
	if (active and not pointer_suspended and not is_instance_valid(_popup)
			and _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y).is_zero_approx()
			and _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y).is_zero_approx()):
		snap_pointer_to_focus()

func _pad_trigger(id: int, axis: JoyAxis, pressed: bool) -> void:
	if id != device_id or pointer_suspended:
		return
	if axis == JOY_AXIS_TRIGGER_LEFT and filling != pressed:
		filling = pressed
		_action(KeyBindings.FILL, pressed)
	elif axis == JOY_AXIS_TRIGGER_RIGHT and right_down != pressed:
		if pressed and _menu_controls():
			return
		right_down = pressed
		_mouse_button(MOUSE_BUTTON_RIGHT, pressed, cursor.position)

func _cancel(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = pressed
	window.push_input(event, true)

func _action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	window.push_input(event, true)

func _motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	_send_pointer(event, cursor.position)

func _mouse_button(button: MouseButton, pressed: bool, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	_send_pointer(event, point)

func _send_pointer(event: InputEventMouse, point: Vector2) -> void:
	event.position = point
	event.global_position = point
	event.shift_pressed = filling
	event.button_mask = (MOUSE_BUTTON_MASK_LEFT if left_down else 0) | (MOUSE_BUTTON_MASK_RIGHT if right_down else 0)
	window.push_input(event, true)
