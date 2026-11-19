extends SceneTree

const BODY := "res://assets/fonts/NotoSansCJKsc-Regular.otf"
const SAMPLE := "系统设置｜封地手记・首贡到期。收菽、缫丝与井田；0–100%，𠮷、翟、荀"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if change_scene_to_file("res://scenes/Title.tscn") != OK:
		push_error("Could not open the title to check the packaged font.")
		quit(1)
		return
	await scene_changed
	var settings := current_scene.get_node("Center/Menu/Settings") as Button
	var font := settings.get_theme_font(&"font") as FontFile
	if font == null or font.resource_path != BODY:
		push_error("The title must use the bundled Chinese body font.")
		quit(1)
		return
	font.allow_system_fallback = false
	var line := TextLine.new()
	line.add_string(SAMPLE, font, 16, "zh_CN")
	for glyph in TextServerManager.get_primary_interface().shaped_text_get_glyphs(line.get_rid()):
		if not glyph.font_rid.is_valid() or glyph.index == 0:
			push_error("No packaged glyph for %s." % SAMPLE.substr(glyph.start, glyph.end - glyph.start))
			quit(1)
			return
	var dialog := load("res://scenes/DialoguePanel.tscn").instantiate() as Control
	current_scene.add_child(dialog)
	var caption := dialog.get_node("%TextLabel") as RichTextLabel
	if caption.get_theme_font(&"normal_font") != font:
		push_error("Dialogue text must also resolve to the bundled font.")
		quit(1)
		return
	if not await _check_reading_size(dialog, caption):
		quit(1)
		return
	dialog.free()
	if not await _check_session_settings():
		quit(1)
		return
	print("SCENARIO_OK")
	quit()

func _check_reading_size(dialog: Control, caption: RichTextLabel) -> bool:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the reading-size preference check with an isolated smoke profile.")
		return false
	var preferences := root.get_node("Preferences")
	var options: Array[String] = ["接着听", "离开"]
	var disabled: Array[int] = []
	dialog.setup("渠伯", "井田南口", "水到了，田苗今晚会接着长。", options, disabled, null)
	var speech := dialog.get_node("%Speech") as ScrollContainer
	var bar := speech.get_v_scroll_bar()
	await _settle()
	if caption.get_theme_font_size(&"normal_font_size") != 18 or bar.visible:
		push_error("The standard short dialogue should fit at its natural size.")
		return false
	var frame := dialog.get_node("Panel") as PanelContainer
	var short_height := frame.size.y
	if preferences.set_reading_size(2) != OK or caption.get_theme_font_size(&"normal_font_size") != 24:
		push_error("The large font setting must apply to open dialogue and save.")
		return false
	var settings := ConfigFile.new()
	if settings.load(preferences.PATH) != OK or settings.get_value("display", "reading_size", 0) != 2:
		push_error("The reading size is missing from the settings file.")
		return false
	preferences.reading_size = 0
	preferences.restore()
	if preferences.reading_size != 2 or caption.get_theme_font_size(&"normal_font_size") != 24:
		push_error("Restoring the settings must reapply the saved reading size.")
		return false
	caption.text = "\n".join(range(38).map(func(index: int) -> String:
		return "第 %d 条 · 井田要等水到渠口，再挨格看看田苗。" % (index + 1)))
	await _settle()
	var choices := dialog.get_node("%OptionsContainer") as HFlowContainer
	var last := choices.get_child(1) as Button
	var bounds := root.get_visible_rect()
	if not bar.visible or not bounds.encloses(frame.get_global_rect()) or not last.has_focus() \
			or speech.get_global_rect().intersects(choices.get_global_rect()):
		push_error("A long dialogue needs an in-bounds reading pane, visible choices and the existing focus.")
		return false
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_PAGEDOWN
		key.pressed = pressed
		root.push_input(key, true)
	await _settle()
	if speech.scroll_vertical == 0 or not last.has_focus():
		push_error("Page Down must scroll the text while leaving the choice focused.")
		return false
	settings.erase_section_key("display", "reading_size")
	if settings.save(preferences.PATH) != OK:
		return false
	preferences.restore()
	if preferences.reading_size != 0 or caption.get_theme_font_size(&"normal_font_size") != 18:
		push_error("Older settings without a reading size should use the standard font size.")
		return false
	caption.text = "水到了，田苗今晚会接着长。"
	await _settle()
	if bar.visible or not is_equal_approx(frame.size.y, short_height):
		push_error("Shortening the dialogue should restore its natural reading height.")
		return false
	return true

func _settle() -> void:
	for frame in 7:
		await process_frame

func _check_session_settings() -> bool:
	var script := load("res://scripts/SettingsPanel.gd") as GDScript
	var settings: Panel = script.new()
	settings.hide()
	current_scene.add_child(settings)
	var entry := current_scene.get_node("Center/Menu/Settings") as Button
	entry.grab_focus()
	settings.show()
	await _settle()
	var area := root.get_visible_rect()
	var picker := settings.find_child("ReadingSize", true, false) as OptionButton
	var close := settings.find_child("Close", true, false) as Button
	var volume_label := settings.master_slider.get_parent().get_child(0) as Label
	var before := volume_label.get_theme_font_size(&"font_size")
	var menu_font := picker.get_popup().get_theme_font_size(&"font_size")
	picker.item_selected.emit(2)
	await _settle()
	if not area.encloses(settings.get_global_rect()) or not area.encloses(close.get_global_rect()) \
			or not area.encloses(picker.get_global_rect()):
		push_error("Session settings and the reading size picker must stay within the viewport.")
		return false
	if volume_label.get_theme_font_size(&"font_size") != before + 6 \
			or picker.get_popup().get_theme_font_size(&"font_size") != menu_font + 6:
		push_error("The setting and its popup must apply the maximum reading size immediately.")
		return false
	close.grab_focus()
	for key: Key in [KEY_RIGHT, KEY_DOWN, KEY_TAB, KEY_UP, KEY_TAB]:
		await _send_key(key)
		var focus := root.gui_get_focus_owner()
		if focus == null or not settings.is_ancestor_of(focus):
			push_error("Keyboard focus escaped the settings panel.")
			return false
	settings.shortcuts.pressed.emit()
	await _settle()
	var bindings: VBoxContainer = settings.bindings_page
	var binding: Button = bindings.keys[&"walk_up"]
	var max_font := binding.get_theme_font_size(&"font_size")
	var restore := bindings.find_child("RestoreBindings", true, false) as Button
	restore.grab_focus()
	await _settle()
	if not settings.body_scroll.get_global_rect().encloses(restore.get_global_rect()) \
			or settings.body_scroll.is_ancestor_of(bindings.status) \
			or not area.encloses(bindings.status.get_global_rect()):
		push_error("Scroll to the last key control while the status remains visible.")
		return false
	root.get_node("Preferences").set_reading_size(0)
	await _settle()
	if max_font != binding.get_theme_font_size(&"font_size") + 6:
		push_error("Key labels must shrink again when the reading size changes.")
		return false
	await _send_key(KEY_ESCAPE)
	if not settings.shortcuts.has_focus():
		push_error("Closing the key page should focus the keyboard settings shortcut.")
		return false
	await _send_key(KEY_ESCAPE)
	if not entry.has_focus() or settings.visible:
		push_error("Closing settings should focus its opening button.")
		return false
	print("SETTINGS_READING labels=", before, "/", before + 6, " keyboard_follow_focus=true")
	settings.free()
	return true

func _send_key(code: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = pressed
		root.push_input(key, true)
	await _settle()
