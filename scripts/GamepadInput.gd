extends CanvasLayer

signal changed

const DEADZONE := 0.22
const TRIGGER_POINT := 0.45
const POINTER_SPEED := 740.0
const ACTION_BUTTONS := {
	JOY_BUTTON_Y: KeyBindings.MAP,
	JOY_BUTTON_BACK: KeyBindings.ALMANAC,
	JOY_BUTTON_START: KeyBindings.ROTATE,
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
	get_tree().scene_changed.connect(_refresh_pointer)
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
	_refresh_pointer.call_deferred()
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
		direction = _left_direction()
	if direction.is_zero_approx():
		return
	var previous := cursor.position
	cursor.position += direction * direction.length() * POINTER_SPEED * delta
	_clamp_pointer()
	if cursor.position != previous:
		_motion(cursor.position - previous)

func _clamp_pointer() -> void:
	var bounds := window.get_visible_rect()
	cursor.position = cursor.position.clamp(bounds.position, bounds.end - Vector2.ONE)

func _refresh_pointer() -> void:
	if not active or pointer_suspended:
		return
	var focus := window.gui_get_focus_owner()
	cursor.position = focus.get_global_rect().get_center() if focus else window.get_visible_rect().get_center()
	_clamp_pointer()
	window.notify_mouse_entered()
	_motion(Vector2.ZERO)

func _pad_button(id: int, button: JoyButton, pressed: bool) -> void:
	if id != device_id or (pointer_suspended and button != JOY_BUTTON_B):
		return
	match button:
		JOY_BUTTON_A:
			left_down = pressed
			_mouse_button(MOUSE_BUTTON_LEFT, pressed, cursor.position)
		JOY_BUTTON_B:
			_cancel(pressed)
		JOY_BUTTON_X:
			if get_tree().get_first_node_in_group("timed_practice"):
				_action(KeyBindings.RHYTHM, pressed)
			elif not _menu_controls():
				_action(KeyBindings.INTERACT, pressed)
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
			if pressed and not _menu_controls():
				GameEvents.seed_cycle_requested.emit(-1 if button == JOY_BUTTON_LEFT_SHOULDER else 1)
		JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK:
			if pressed:
				var wheel := MOUSE_BUTTON_WHEEL_UP if button == JOY_BUTTON_RIGHT_STICK else MOUSE_BUTTON_WHEEL_DOWN
				_mouse_button(wheel, true, cursor.position)
		_:
			if ACTION_BUTTONS.has(button):
				_action(ACTION_BUTTONS[button], pressed)

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
