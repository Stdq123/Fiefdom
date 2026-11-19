extends ConfirmationDialog

signal return_requested

const DIALOG_THEME := preload("res://resources/estate_dialog_theme.tres")
const HUD_THEME := preload("res://resources/estate_hud_theme.tres")

var save_progress: Callable
var save_button: Button
var exits_game := false
var _prompt: String
var _opening_focus: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("gamepad_directional_menu")
	title = "退出游戏" if exits_game else "返回标题"
	var confirmation_theme := DIALOG_THEME.duplicate() as Theme
	confirmation_theme.set_constant(&"buttons_min_width", &"AcceptDialog", 126)
	confirmation_theme.set_constant(&"buttons_min_height", &"AcceptDialog", 42)
	theme = confirmation_theme
	dialog_autowrap = true
	dialog_hide_on_ok = not exits_game
	ok_button_text = "直接退出" if exits_game else "直接返回"
	save_button = add_button("保存并退出" if exits_game else "保存并返回", true, "save")
	for button in [get_ok_button(), get_cancel_button(), save_button]:
		button.theme = HUD_THEME
		button.theme_type_variation = &"HudButton"
		InterfaceFont.scale_reading_text(button)
	save_button.theme_type_variation = &"HudPrimary"
	InterfaceFont.scale_reading_text(get_label())
	confirmed.connect(return_requested.emit)
	custom_action.connect(_save_and_leave.unbind(1))
	visibility_changed.connect(_restore_opening_focus)

func ask(message: String, stay_caption := "继续游戏", can_save := true) -> void:
	_opening_focus = get_tree().root.gui_get_focus_owner()
	var current := "%s · 第 %d 天 · %s" % [Global.campaign_name, Global.current_day, Global.day_watch_label()]
	var checkpoint := Global.latest_campaign_save()
	var saved := "本局尚无存档。" if checkpoint.is_empty() else "最近存档 · " + Global.saved_game_caption(checkpoint)
	_prompt = current + "\n" + saved + "\n\n" + message
	dialog_text = _prompt
	get_cancel_button().text = stay_caption
	save_button.visible = can_save
	if exits_game:
		ok_button_text = "直接退出" if can_save else "退出游戏"
	popup_centered(Vector2i(568, 208))
	_focus_action(save_button if can_save else get_cancel_button())

func _focus_action(button: Button) -> void:
	button.grab_focus()
	GamepadInput.snap_pointer_to_focus.call_deferred()

func _restore_opening_focus() -> void:
	if visible:
		return
	if is_instance_valid(_opening_focus) and _opening_focus.is_visible_in_tree():
		_opening_focus.grab_focus()
	_opening_focus = null
	GamepadInput.snap_pointer_to_focus.call_deferred()

func _save_and_leave() -> void:
	var result: Error = save_progress.call()
	if result == OK:
		if not exits_game:
			hide()
		return_requested.emit()
	else:
		dialog_text = _prompt + "\n\n保存失败（%s）。可重试，或先留在当前画面。" % error_string(result)
		_focus_action(save_button)
