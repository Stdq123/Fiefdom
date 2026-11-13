@tool
extends EditorPlugin

var art_importer: EditorImportPlugin

func _enter_tree() -> void:
	art_importer = preload("res://addons/fiefdom_art/import_art.gd").new()
	add_import_plugin(art_importer)

func _exit_tree() -> void:
	remove_import_plugin(art_importer)
