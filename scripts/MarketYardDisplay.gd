extends StaticBody2D

const ART := preload("res://assets/world/west-market-fixtures.png")
const FOOTPRINT := Rect2(-13.5, -8.0, 29.0, 8.0)
const FRAME := Vector2(44, 32)

var kind: MarketStall.Kind

func _init(display_kind: MarketStall.Kind, wet: bool) -> void:
	kind = display_kind
	collision_mask = 0
	modulate = Color("#cbd8d6") if wet else Color.WHITE

func _ready() -> void:
	var feet := CollisionShape2D.new()
	var base := RectangleShape2D.new()
	base.size = FOOTPRINT.size
	feet.name = "Feet"
	feet.position = FOOTPRINT.get_center()
	feet.shape = base
	add_child(feet)

static func draw_shadow(canvas: CanvasItem, at: Vector2, shade: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-15, -5), at + Vector2(14, -9),
		at + Vector2(27, -5), at + Vector2(22, 1), at + Vector2(7, 4), at + Vector2(-16, 1)]), shade)

func _draw() -> void:
	var region := Rect2(Vector2(FRAME.x * kind, 0), FRAME)
	draw_texture_rect_region(ART, Rect2(Vector2(-22, -30), FRAME), region)
