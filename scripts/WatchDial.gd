extends Control

const FACE_PATH := "res://assets/ui/watch-dial.png"
const CENTER := Vector2(24, 24)
const FACE_SIZE := 48.0
const METAL := Color("#ffe0a0")

@export var compact := false
@onready var face: Texture2D = load(FACE_PATH)
var watch := -1

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func show_watch(label: String) -> void:
	var next := Global.DAY_WATCHES.find(label.left(1))
	if next != watch:
		watch = next
		accessibility_name = label
		queue_redraw()

func _draw() -> void:
	var diameter := minf(size.x, size.y)
	draw_set_transform((size - Vector2.ONE * diameter) / 2.0, 0.0, Vector2.ONE * (diameter / FACE_SIZE))
	draw_texture_rect(face, Rect2(Vector2.ZERO, Vector2.ONE * FACE_SIZE), false)
	for index in Global.DAY_WATCHES.size():
		var direction := Vector2.UP.rotated(index * TAU / Global.DAY_WATCHES.size())
		var cardinal := index % 3 == 0
		draw_line(CENTER + direction * (15.5 if cardinal else 17.0), CENTER + direction * 19.0,
			Color("#d8b57a") if cardinal else Color("#ab936f"), 1.4 if cardinal else 1.0, true)
	if watch < 0:
		return
	var hand := Vector2.UP.rotated(watch * TAU / Global.DAY_WATCHES.size())
	var side := hand.orthogonal() * 2.6
	var tip := CENTER + hand * 20.5
	# The estate dial has its name at the centre. The travelling dial has room for a full hand.
	var base := CENTER + hand * (0.0 if compact else 14.0)
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color("#e0a158"))
	draw_colored_polygon(PackedVector2Array([tip, base + side, base]), METAL)
	if compact:
		draw_circle(CENTER, 3.1, Color("#35281e"), true, -1.0, true)
		draw_circle(CENTER, 1.9, METAL, true, -1.0, true)
