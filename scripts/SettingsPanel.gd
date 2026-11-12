extends Panel

const PADDING := 16
const SAVE_ARCHIVE := preload("res://scenes/SaveArchive.tscn")
const BINDINGS_PANEL := preload("res://scripts/KeyboardBindingsPanel.gd")

var session_controls := true
var save_resume_hint := "":
	set(value):
		save_resume_hint = value
		if is_instance_valid(save_button):
			save_button.tooltip_text = value
var save_status: Label
var save_button: Button
var preferences_status: Label
var contents: VBoxContainer
var heading: Label
var general: VBoxContainer
var bindings_page: VBoxContainer
var close_button: Button

func _ready() -> void:
	contents = VBoxContainer.new()
	contents.add_theme_constant_override("separation", 8)
	add_child(contents)
	
	heading = Label.new()
	heading.text = "系统设置"
	heading.add_theme_font_size_override("font_size", 24)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(heading)
	general = VBoxContainer.new()
	general.add_theme_constant_override("separation", 8)
	contents.add_child(general)
	
	if session_controls:
		_add_session_controls(general)
	
	_add_volume_control(general, &"MasterVolume", "主音量", Preferences.volume, Preferences.set_volume)
	_add_volume_control(general, &"MusicVolume", "音乐", Preferences.music_volume, Preferences.set_music_volume)
	_add_volume_control(general, &"AmbienceVolume", "环境与脚步", Preferences.ambience_volume, Preferences.set_ambience_volume)
	
	# Fullscreen
	var fs_btn = CheckButton.new()
	fs_btn.name = "Fullscreen"
	fs_btn.text = "全屏"
	fs_btn.set_pressed_no_signal(Preferences.fullscreen)
	fs_btn.toggled.connect(_on_fullscreen_toggled)
	general.add_child(fs_btn)
	var autosave_button := CheckButton.new()
	autosave_button.name = "Autosave"
	autosave_button.text = "自动保存"
	autosave_button.tooltip_text = "每天过夜结算和选择初税亩方案后保存，保留最近三份。"
	autosave_button.set_pressed_no_signal(Preferences.autosave)
	autosave_button.toggled.connect(func(enabled: bool): _show_preference_result(Preferences.set_autosave(enabled)))
	general.add_child(autosave_button)
	preferences_status = Label.new()
	preferences_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	general.add_child(preferences_status)

	var shortcuts := Button.new()
	shortcuts.name = "KeyboardBindings"
	shortcuts.text = "键盘键位"
	shortcuts.pressed.connect(_show_bindings.bind(true))
	general.add_child(shortcuts)

	var gamepad_help := Label.new()
	gamepad_help.text = ("手柄 · 左摇杆移动，右摇杆指向\n"
		+ "A 确认或耕作 · X 互动或节奏操作 · B 返回\n"
		+ "LB/RB 换种 · Y 舆图 · View 历书 · RT 射箭")
	gamepad_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gamepad_help.add_theme_font_size_override("font_size", 16)
	general.add_child(gamepad_help)

	bindings_page = BINDINGS_PANEL.new()
	bindings_page.hide()
	contents.add_child(bindings_page)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "关闭"
	close_button.pressed.connect(_back_or_close)
	contents.add_child(close_button)
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, PADDING)
	contents.minimum_size_changed.connect(_fit_contents)
	_fit_contents()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_back_or_close()
		get_viewport().set_input_as_handled()

func _back_or_close() -> void:
	if bindings_page.visible:
		_show_bindings(false)
	else:
		hide()

func _show_bindings(show_page: bool) -> void:
	general.visible = not show_page
	bindings_page.visible = show_page
	heading.text = "键盘键位" if show_page else "系统设置"
	close_button.text = "返回设置" if show_page else "关闭"
	_fit_contents()

func _fit_contents() -> void:
	var content := contents.get_combined_minimum_size() + Vector2.ONE * PADDING * 2
	custom_minimum_size = Vector2(maxf(396.0, content.x), content.y)
	size = custom_minimum_size
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)

func _add_volume_control(vbox: VBoxContainer, control_name: StringName, text: String, value: float, save: Callable) -> void:
	var label := Label.new()
	label.text = text
	vbox.add_child(label)

	var slider := HSlider.new()
	slider.name = control_name
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.value_changed.connect(func(volume: float): _show_preference_result(save.call(volume)))
	vbox.add_child(slider)

func _add_session_controls(vbox: VBoxContainer) -> void:
	save_button = Button.new()
	save_button.text = "保存游戏"
	save_button.tooltip_text = save_resume_hint
	save_button.pressed.connect(_on_save_pressed)
	vbox.add_child(save_button)

	var load_btn := Button.new()
	load_btn.text = "读取游戏"
	load_btn.pressed.connect(_on_load_pressed)
	vbox.add_child(load_btn)

	save_status = Label.new()
	save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(save_status)

	var title_confirmation := ConfirmationDialog.new()
	title_confirmation.name = "TitleConfirmation"
	title_confirmation.title = "返回标题"
	title_confirmation.dialog_text = "返回标题后可继续最近的存档。当天未保存的改动会丢失。"
	title_confirmation.ok_button_text = "返回标题"
	title_confirmation.get_cancel_button().text = "继续游戏"
	title_confirmation.confirmed.connect(_return_to_title)
	add_child(title_confirmation)

	var title_btn := Button.new()
	title_btn.text = "返回标题"
	title_btn.pressed.connect(func(): title_confirmation.popup_centered())
	vbox.add_child(title_btn)

func _return_to_title() -> void:
	var tree := get_tree()
	var result := tree.change_scene_to_file(Global.TITLE_SCENE)
	if result == OK:
		tree.paused = false
	else:
		save_status.text = "返回标题失败（%s）" % error_string(result)

func _on_save_pressed() -> void:
	var result := Global.save_game()
	save_status.text = "游戏已保存" if result == OK else "保存失败（%s）" % error_string(result)
	if result == OK and not save_resume_hint.is_empty():
		save_status.text += " · " + save_resume_hint

func _on_load_pressed() -> void:
	if Global.has_saved_game():
		var archive := SAVE_ARCHIVE.instantiate()
		archive.preferred_campaign = Global.campaign_id
		get_parent().add_child(archive)
	else:
		save_status.text = "还没有存档"

func _on_fullscreen_toggled(toggled: bool) -> void:
	_show_preference_result(Preferences.set_fullscreen(toggled))

func _show_preference_result(result: Error) -> void:
	preferences_status.text = "设置已保存" if result == OK else "设置保存失败（%s）" % error_string(result)
