class_name HallDecorView
extends Node2D

@export var atlas: Texture2D

@onready var mat_sprite: Sprite2D = $Mat
@onready var display_sprite: Sprite2D = $Display

func _ready() -> void:
	show_saved()

func show_saved() -> void:
	show_selection(Global.hall_mat_id, Global.hall_shelf_id)

func show_selection(mat: String, shelf: String) -> void:
	mat_sprite.texture = texture_for(mat)
	display_sprite.texture = texture_for(shelf)

func texture_for(id: String, icon := false) -> AtlasTexture:
	var choice: Dictionary = HallDecor.CATALOG[id]
	var region: Rect2i = choice.get("icon", choice.region) if icon else choice.region
	if region == Rect2i():
		return null
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region
	texture.filter_clip = true
	return texture
