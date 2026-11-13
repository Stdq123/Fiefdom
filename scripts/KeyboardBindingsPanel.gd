extends VBoxContainer

const WALK_AND_ACTIONS: Array[StringName] = [
	KeyBindings.UP, KeyBindings.LEFT, KeyBindings.DOWN, KeyBindings.RIGHT,
	KeyBindings.INTERACT, KeyBindings.MAP, KeyBindings.BACKPACK, KeyBindings.ALMANAC, KeyBindings.MEAL, KeyBindings.RHYTHM,
]
const INSTRUCTIONS := "点击要改的键位，再按单键。已占用的键可以互换。"
const MENU_NOTE := "方向键、回车、Tab 和 Esc 可用于通用菜单。"

var keys: Dictionary[StringName, Button] = {}
var pending: StringName = &""
var status: Label

func _ready() -> void:
	custom_minimum_size.x = 586.0
	add_theme_constant_override("separation", 10)
	var intro := Label.new()
	intro.text = INSTRUCTIONS
	intro.add_theme_font_size_override("font_size", 16)
	add_child(intro)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	add_child(columns)
	_add_column(columns, "移动与操作", WALK_AND_ACTIONS)
	columns.add_child(VSeparator.new())
	var field_actions := KeyBindings.SEEDS.duplicate()
	field_actions.append(KeyBindings.FILL)
	field_actions.append(KeyBindings.ROTATE)
	_add_column(columns, "田务", field_actions)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	add_child(footer)
	status = Label.new()
	status.name = "BindingStatus"
	status.text = MENU_NOTE
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_color", Color("#d4dfb7"))
	footer.add_child(status)
	var restore := Button.new()
	restore.name = "RestoreBindings"
	restore.text = "恢复默认"
	restore.pressed.connect(_restore_defaults)
	footer.add_child(restore)
	visibility_changed.connect(_visibility_changed)
	Preferences.bindings_changed.connect(_refresh_keys)
	_refresh_keys()

func _add_column(columns: HBoxContainer, title: String, actions: Array[StringName]) -> void:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 5)
	columns.add_child(section)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", Color("#e8c888"))
	section.add_child(heading)
	for action in actions:
		var row := HBoxContainer.new()
		section.add_child(row)
		var name_label := Label.new()
		name_label.text = KeyBindings.label(action)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var button := Button.new()
		button.name = action
		button.custom_minimum_size = Vector2(102.0, 34.0)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_begin.bind(action))
		row.add_child(button)
		keys[action] = button

func _refresh_keys() -> void:
	for action in keys:
		keys[action].text = "按下新键…" if action == pending else Preferences.key_label(action)
		keys[action].accessibility_name = "%s %s" % [KeyBindings.label(action), keys[action].text]

func _begin(action: StringName) -> void:
	pending = action
	_refresh_keys()
	status.text = "为「%s」按下一个键。Esc 取消。" % KeyBindings.label(action)

func _input(event: InputEvent) -> void:
	if pending == &"" or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo:
		return
	var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if code == KEY_ESCAPE:
		_finish("已取消改键。")
		return
	if event.alt_pressed or event.ctrl_pressed or event.meta_pressed or (event.shift_pressed and code != KEY_SHIFT):
		status.text = "请按单键。Esc 取消。"
		return
	var other := Preferences.bound_action(code)
	var result := Preferences.set_binding(pending, code)
	match result:
		OK:
			var action_name := KeyBindings.label(pending)
			var message := "%s已设为 %s。" % [action_name, Preferences.key_label(pending)]
			if other != &"" and other != pending:
				message = "已互换%s和%s的键位。" % [action_name, KeyBindings.label(other)]
			_finish(message)
		ERR_INVALID_PARAMETER:
			status.text = "此键留给菜单或专用操作。请换一个键。"
		ERR_ALREADY_IN_USE:
			status.text = "先为「%s」腾出这个键。" % KeyBindings.label(other)
		_:
			_finish("键位保存失败（%s）。" % error_string(result))

func _finish(message: String) -> void:
	pending = &""
	_refresh_keys()
	status.text = message

func _restore_defaults() -> void:
	var result := Preferences.reset_bindings()
	_finish("键位已恢复默认。" if result == OK else "键位保存失败（%s）。" % error_string(result))

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		_finish(MENU_NOTE)
