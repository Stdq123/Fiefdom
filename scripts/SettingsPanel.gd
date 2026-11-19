extends Panel

const PADDING := 22
const SAVE_ARCHIVE := preload("res://scenes/SaveArchive.tscn")
const BINDINGS_PANEL := preload("res://scripts/KeyboardBindingsPanel.gd")
const FRAME := preload("res://resources/estate_archive_frame.tres")
const TITLE_CONFIRMATION := preload("res://scripts/ReturnToTitleDialog.gd")
const VOLUME_THEME := preload("res://resources/estate_volume_theme.tres")
const HUD_THEME := preload("res://resources/estate_hud_theme.tres")

var session_controls := true
var save_status: Label
var save_button: Button
var preferences_status: Label
var contents: VBoxContainer
var heading: Label
var general: VBoxContainer
var bindings_page: BINDINGS_PANEL
var close_button: Button
var shortcuts: Button
var master_slider: HSlider
var fullscreen_button: CheckButton
var window_size_picker: OptionButton
var reading_size_picker: OptionButton

func _ready() -> void:
	add_theme_stylebox_override("panel", FRAME)
	contents = VBoxContainer.new()
	contents.add_theme_constant_override("separation", 8)
	add_child(contents)
	
	heading = Label.new()
	heading.text = "系统设置"
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color("#ebce95"))
	contents.add_child(heading)
	general = VBoxContainer.new()
	general.add_theme_constant_override("separation", 8)
	contents.add_child(general)
	
	if session_controls:
		_add_session_controls(general)
	
	master_slider = _add_volume_control(general, &"MasterVolume", "主音量", Preferences.volume, Preferences.set_volume)
	_add_volume_control(general, &"MusicVolume", "音乐", Preferences.music_volume, Preferences.set_music_volume)
	_add_volume_control(general, &"SfxVolume", "音效与脚步", Preferences.sfx_volume, Preferences.set_sfx_volume)
	_add_volume_control(general, &"AmbienceVolume", "环境声", Preferences.ambience_volume, Preferences.set_ambience_volume)
	
	_add_display_controls(general)
	_add_reading_control(general)
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

	shortcuts = Button.new()
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
	close_button.custom_minimum_size = Vector2(100, 38)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.pressed.connect(_back_or_close)
	contents.add_child(close_button)
	for button: Button in contents.find_children("*", "Button", true, false):
		if button is not CheckButton:
			button.theme = HUD_THEME
			button.theme_type_variation = &"HudButton"
	visibility_changed.connect(_on_visibility_changed)
	_set_focus_edges()
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, PADDING)
	contents.minimum_size_changed.connect(_fit_contents)
	_fit_contents()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		AudioManager.play_menu_cue(AudioManager.MenuCue.OPEN)
		_sync_display_controls()
		var first: Control = bindings_page.keys[KeyBindings.UP] if bindings_page.visible else master_slider
		first.grab_focus()
	elif not visible:
		AudioManager.play_menu_cue(AudioManager.MenuCue.CLOSE)

func _set_focus_edges() -> void:
	var first: Control = save_button if session_controls else master_slider
	if bindings_page.visible:
		first = bindings_page.keys[KeyBindings.UP]
	first.focus_previous = first.get_path_to(close_button)
	close_button.focus_next = close_button.get_path_to(first)

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
	if bindings_page.visible != show_page:
		AudioManager.play_menu_cue(AudioManager.MenuCue.PAGE)
	general.visible = not show_page
	bindings_page.visible = show_page
	heading.text = "键盘键位" if show_page else "系统设置"
	close_button.text = "返回设置" if show_page else "关闭"
	_set_focus_edges()
	_fit_contents()
	if show_page:
		bindings_page.keys[KeyBindings.UP].grab_focus()
	else:
		shortcuts.grab_focus()

func _fit_contents() -> void:
	var content := contents.get_combined_minimum_size() + Vector2.ONE * PADDING * 2
	custom_minimum_size = Vector2(maxf(452.0, content.x), content.y)
	size = custom_minimum_size
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)

func _add_volume_control(vbox: VBoxContainer, control_name: StringName, text: String, value: float, save: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 86
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = control_name
	slider.accessibility_name = text
	slider.custom_minimum_size = Vector2(148, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.theme = VOLUME_THEME
	slider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	row.add_child(slider)
	var amount := Label.new()
	amount.custom_minimum_size.x = 46
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.text = "%d%%" % roundi(slider.value * 100)
	row.add_child(amount)
	slider.value_changed.connect(func(volume: float):
		amount.text = "%d%%" % roundi(volume * 100)
		_show_preference_result(save.call(volume))
	)
	return slider

func _add_display_controls(vbox: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	var label := Label.new()
	label.text = "窗口尺寸"
	label.custom_minimum_size.x = 86
	row.add_child(label)
	window_size_picker = OptionButton.new()
	window_size_picker.name = "WindowSize"
	window_size_picker.accessibility_name = label.text
	window_size_picker.custom_minimum_size.y = 38
	window_size_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window_size_picker.allow_reselect = true
	for preset in Preferences.WINDOW_SIZES:
		window_size_picker.add_item("%d × %d" % [preset.x, preset.y])
	_style_picker(window_size_picker)
	window_size_picker.item_selected.connect(_on_window_size_selected, CONNECT_DEFERRED)
	row.add_child(window_size_picker)
	fullscreen_button = CheckButton.new()
	fullscreen_button.name = "Fullscreen"
	fullscreen_button.text = "全屏"
	fullscreen_button.toggled.connect(_on_fullscreen_toggled)
	row.add_child(fullscreen_button)
	get_window().size_changed.connect(_sync_display_controls, CONNECT_DEFERRED)
	_sync_display_controls()

func _add_reading_control(vbox: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	var label := Label.new()
	label.text = "阅读字号"
	label.custom_minimum_size.x = 86
	row.add_child(label)
	reading_size_picker = OptionButton.new()
	reading_size_picker.name = "ReadingSize"
	reading_size_picker.accessibility_name = label.text
	reading_size_picker.tooltip_text = "调整对白、封地手记和邻里手记的文字大小。"
	reading_size_picker.custom_minimum_size.y = 34
	reading_size_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option in ["标准", "较大", "最大"]:
		reading_size_picker.add_item(option)
	_style_picker(reading_size_picker)
	reading_size_picker.select(Preferences.reading_size)
	reading_size_picker.item_selected.connect(func(index: int):
		_show_preference_result(Preferences.set_reading_size(index))
		_sync_reading_size()
	)
	Preferences.reading_size_changed.connect(_sync_reading_size)
	row.add_child(reading_size_picker)

func _style_picker(picker: OptionButton) -> void:
	var popup := picker.get_popup()
	popup.add_theme_stylebox_override("panel", FRAME)
	popup.add_theme_stylebox_override("hover", HUD_THEME.get_stylebox("hover", "HudButton"))

func _sync_reading_size() -> void:
	reading_size_picker.select(Preferences.reading_size)

func _sync_display_controls() -> void:
	fullscreen_button.set_pressed_no_signal(Preferences.fullscreen)
	window_size_picker.disabled = Preferences.fullscreen
	window_size_picker.tooltip_text = "退出全屏后可调整窗口尺寸。" if Preferences.fullscreen else ""
	var size_to_show := Preferences.window_size
	if not Preferences.fullscreen and DisplayServer.get_name() != "headless":
		size_to_show = get_window().size
	if size_to_show == Vector2i.ZERO:
		size_to_show = Preferences.WINDOW_SIZES[0]
	var index := Preferences.WINDOW_SIZES.find(size_to_show)
	var custom_index := Preferences.WINDOW_SIZES.size()
	if index == -1:
		var caption := "当前 %d × %d" % [size_to_show.x, size_to_show.y]
		if window_size_picker.item_count == custom_index:
			window_size_picker.add_item(caption)
			window_size_picker.set_item_disabled(custom_index, true)
		else:
			window_size_picker.set_item_text(custom_index, caption)
		index = custom_index
	elif window_size_picker.item_count > custom_index:
		window_size_picker.remove_item(custom_index)
	window_size_picker.select(index)

func _on_window_size_selected(index: int) -> void:
	if not Preferences.fullscreen and index >= 0 and index < Preferences.WINDOW_SIZES.size():
		_show_preference_result(Preferences.set_window_size(Preferences.WINDOW_SIZES[index]))
	_sync_display_controls()

func _add_session_controls(vbox: VBoxContainer) -> void:
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	vbox.add_child(actions)
	save_button = Button.new()
	save_button.text = "保存游戏"
	save_button.tooltip_text = "手动档记录当前地点、站位和面向"
	save_button.pressed.connect(_on_save_pressed)

	var load_btn := Button.new()
	load_btn.text = "读取游戏"
	load_btn.pressed.connect(_on_load_pressed)

	var title_confirmation := TITLE_CONFIRMATION.new()
	title_confirmation.name = "TitleConfirmation"
	title_confirmation.save_progress = _on_save_pressed
	title_confirmation.return_requested.connect(_return_to_title, CONNECT_DEFERRED)
	add_child(title_confirmation)

	var title_btn := Button.new()
	title_btn.text = "返回标题"
	title_btn.pressed.connect(title_confirmation.ask.bind("保存会更新本局手动档。直接返回会放弃尚未保存的进度。"))
	for button: Button in [save_button, load_btn, title_btn]:
		button.custom_minimum_size.y = 38
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)

	save_status = Label.new()
	save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(save_status)

func _return_to_title() -> void:
	var tree := get_tree()
	var result := tree.change_scene_to_file(Global.TITLE_SCENE)
	if result == OK:
		tree.paused = false
	else:
		save_status.text = "返回标题失败（%s）" % error_string(result)

func _on_save_pressed() -> Error:
	var result := Global.save_game()
	save_status.text = "游戏已保存" if result == OK else "保存失败（%s）" % error_string(result)
	return result

func _on_load_pressed() -> void:
	if Global.has_saved_game():
		var archive := SAVE_ARCHIVE.instantiate()
		archive.preferred_campaign = Global.campaign_id
		get_parent().add_child(archive)
	else:
		save_status.text = "还没有存档"

func _on_fullscreen_toggled(toggled: bool) -> void:
	_show_preference_result(Preferences.set_fullscreen(toggled))
	_sync_display_controls()

func _show_preference_result(result: Error) -> void:
	preferences_status.text = "设置已保存" if result == OK else "设置保存失败（%s）" % error_string(result)
