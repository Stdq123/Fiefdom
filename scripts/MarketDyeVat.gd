extends StaticBody2D

const FOOTPRINT := Rect2(-8.5, -8.0, 17.0, 8.0)
const RIM := [Vector2(-13, -17), Vector2(-10, -21), Vector2(-5, -23), Vector2(6, -23),
	Vector2(11, -21), Vector2(13, -17), Vector2(10, -14), Vector2(5, -12),
	Vector2(-6, -12), Vector2(-11, -14)]

var glaze: Color
var dye: Color
var covered := false

func _init(clay_glaze: Color, pigment: Color) -> void:
	glaze = clay_glaze
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
	var wall := glaze.darkened(0.16) if Global.has_rain() else glaze
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -17), Vector2(12, -17), Vector2(13, -11),
		Vector2(10, -3), Vector2(6, 0), Vector2(-7, 0), Vector2(-11, -3), Vector2(-13, -10)]), wall.darkened(0.38))
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -15), Vector2(8, -15), Vector2(8, -8),
		Vector2(5, -3), Vector2(-7, -2), Vector2(-10, -5), Vector2(-11, -10)]), wall)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -14), Vector2(-4, -12), Vector2(-5, -6),
		Vector2(-7, -4), Vector2(-9, -7), Vector2(-10, -11)]), wall.lightened(0.19))
	draw_colored_polygon(PackedVector2Array([Vector2(8, -17), Vector2(12, -17), Vector2(12, -10),
		Vector2(9, -4), Vector2(5, -2), Vector2(8, -8)]), wall.darkened(0.23))
	draw_line(Vector2(-9, -8), Vector2(-3, -7), wall.lightened(0.27), 0.7)
	draw_colored_polygon(PackedVector2Array(RIM), wall.lightened(0.20))
	draw_line(Vector2(-9, -21), Vector2(3, -22), wall.lightened(0.40), 1.0)
	if covered:
		_draw_cover()
	else:
		_draw_dye()
	if Global.season_index() == Global.Season.WINTER:
		draw_line(Vector2(-8, -21.5), Vector2(-3, -22.0), Color("#c5cfc0"), 0.9)

func _draw_dye() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -17), Vector2(-7, -20), Vector2(6, -20),
		Vector2(10, -17), Vector2(7, -15), Vector2(-6, -15)]), dye.darkened(0.56))
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -17.5), Vector2(-3, -18.5), Vector2(7, -18.5),
		Vector2(9, -17), Vector2(6, -15.5), Vector2(-6, -15.5)]), dye)
	draw_line(Vector2(-5.5, -17.5), Vector2(0, -17.8), dye.lightened(0.36), 0.7)

func _draw_cover() -> void:
	var reed := Color("#b2a17a") if not Global.has_rain() else Color("#939077")
	draw_colored_polygon(PackedVector2Array([Vector2(-10.5, -17.5), Vector2(-8, -21), Vector2(6, -22),
		Vector2(10.5, -20), Vector2(11.5, -17.5), Vector2(7, -15), Vector2(-7, -15)]), reed)
	draw_line(Vector2(-8, -19.5), Vector2(8, -19.5), reed.darkened(0.29), 0.75)
	draw_line(Vector2(-9, -17.3), Vector2(9, -17.3), reed.darkened(0.20), 0.65)
	draw_rect(Rect2(-2.5, -23.5, 5.5, 3), reed.darkened(0.33))
	draw_rect(Rect2(-2, -23.5, 4, 1), reed.lightened(0.2))
