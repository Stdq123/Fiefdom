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
	print("SCENARIO_OK")
	quit()
