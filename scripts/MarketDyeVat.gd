extends StaticBody2D

enum Dye { MADDER, INDIGO }

const ART := preload("res://assets/world/west-market-fixtures.png")
const FOOTPRINT := Rect2(-8.5, -8.0, 17.0, 8.0)
const FRAME := Vector2(32, 28)

var dye: Dye
var covered := false

func _init(pigment: Dye) -> void:
	dye = pigment

func _ready() -> void:
	collision_mask = 0
	var base := RectangleShape2D.new()
	base.size = FOOTPRINT.size
	var feet := CollisionShape2D.new()
	feet.position = FOOTPRINT.get_center()
	feet.shape = base
	add_child(feet)

func set_covered(value: bool) -> void:
	if covered == value:
		return
	covered = value
	queue_redraw()

static func draw_shadow(canvas: CanvasItem, at: Vector2, vat_scale: float, shade: Color) -> void:
	var shape := PackedVector2Array([Vector2(-9, -3), Vector2(9, -3), Vector2(15, 1),
		Vector2(12, 4), Vector2(1, 5), Vector2(-8, 3)])
	canvas.draw_colored_polygon(Transform2D(0.0, Vector2.ONE * vat_scale, 0.0, at) * shape, shade)

func _draw() -> void:
	var frost := Global.season_index() == Global.Season.WINTER
	var row := int(covered) + (2 if frost else 0)
	var region := Rect2(Vector2(132 + FRAME.x * dye, FRAME.y * row), FRAME)
	var tint := Color("#c8d4d4") if Global.has_rain() else Color.WHITE
	draw_texture_rect_region(ART, Rect2(Vector2(-16, -27), FRAME), region, tint)
