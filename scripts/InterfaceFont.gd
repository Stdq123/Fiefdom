extends Node

const BODY := preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")

func _enter_tree() -> void:
	# Install the imported font at runtime, after it is available on a cold build.
	ThemeDB.get_default_theme().default_font = BODY
	ThemeDB.fallback_font = BODY

func scale_reading_text(target: Node, item: StringName = &"font_size") -> void:
	var standard: int = target.get_theme_font_size(item)
	var apply := func(): target.add_theme_font_size_override(item, Preferences.reading_font_size(standard))
	Preferences.reading_size_changed.connect(apply)
	target.tree_exiting.connect(func(): Preferences.reading_size_changed.disconnect(apply), CONNECT_ONE_SHOT)
	apply.call()
