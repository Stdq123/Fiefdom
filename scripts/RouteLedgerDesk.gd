extends Node2D

const ART := preload("res://assets/world/route-ledgers.png")
const CELL := Vector2(128, 96)
const CONTACT := Color("#29342b55")

var volume: Sprite2D
var tribute := false

static func stand_texture(traditional: bool) -> AtlasTexture:
	# The last row bakes the tabletop and its book together for the map sprite and its map pin.
	var stand := AtlasTexture.new()
	stand.atlas = ART
	stand.region = Rect2(12 if traditional else 140, 300, 104, 72)
	stand.filter_clip = true
	return stand

static func volume_texture(traditional: bool) -> AtlasTexture:
	var book := AtlasTexture.new()
	book.atlas = ART
	book.region = Rect2(Vector2(0 if traditional else CELL.x, CELL.y * 2), CELL)
	book.filter_clip = true
	return book

func volume_home() -> Vector2:
	return Vector2(7, -17) if tribute else Vector2(-8, -18)

func arrange(traditional: bool) -> void:
	tribute = traditional
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not volume:
		volume = Sprite2D.new()
		volume.name = "Ledger"
		add_child(volume)
	volume.texture = volume_texture(tribute)
	volume.scale = Vector2.ONE * 0.12
	volume.position = volume_home()
	queue_redraw()

func _draw() -> void:
	var column := 0.0 if tribute else CELL.x
	draw_colored_polygon(PackedVector2Array([Vector2(-20, -5), Vector2(16, -7),
		Vector2(26, -2), Vector2(22, 2), Vector2(4, 3), Vector2(-20, 1)]), CONTACT)
	var setting := Vector2(-27, -9) if tribute else Vector2(0, -26)
	if tribute:
		draw_colored_polygon(PackedVector2Array([Vector2(-37, -4), Vector2(-20, -6),
			Vector2(-13, -1), Vector2(-21, 2), Vector2(-35, 2)]), CONTACT)
	_draw_piece(Vector2(column, CELL.y), setting)
	_draw_piece(Vector2(column, 0), Vector2(0, -11 if tribute else -15))

func _draw_piece(source: Vector2, center: Vector2) -> void:
	var size := CELL * 0.5
	draw_texture_rect_region(ART, Rect2(center - size * 0.5, size), Rect2(source, CELL))
