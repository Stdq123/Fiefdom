extends Node

const BODY := preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")

func _enter_tree() -> void:
	# Install the imported font at runtime, after it is available on a cold build.
	ThemeDB.get_default_theme().default_font = BODY
	ThemeDB.fallback_font = BODY
