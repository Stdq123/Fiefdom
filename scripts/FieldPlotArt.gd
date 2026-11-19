extends RefCounted
class_name FieldPlotArt

const PADDY_WATER := Color("#4e796e")
const PADDY_RIM := Color("#584d37")
const PADDY_REFLECTION := Color("#92b8a2")
const RIPE_BADGE: Array[Vector2] = [Vector2(0, -3), Vector2(3, 0), Vector2(0, 3), Vector2(-3, 0)]
const RIPE_GRAIN: Array[Vector2] = [Vector2(0, -1.8), Vector2(1.8, 0), Vector2(0, 1.8), Vector2(-1.8, 0)]
const DROP_BADGE: Array[Vector2] = [Vector2(0, -3), Vector2(2.5, 0.5), Vector2(2.5, 1.5),
	Vector2(1, 2.5), Vector2(-1, 2.5), Vector2(-2.5, 1.5), Vector2(-2.5, 0.5)]
const DROP_FILL: Array[Vector2] = [Vector2(0, -1.6), Vector2(1.5, 0.7), Vector2(1, 1.6),
	Vector2(-1, 1.6), Vector2(-1.5, 0.7)]

static func draw_crop_mark(ink: CanvasItem, status: int) -> void:
	match status:
		Global.NightGrowth.READY:
			ink.draw_colored_polygon(RIPE_BADGE, Color("#543a29"))
			ink.draw_colored_polygon(RIPE_GRAIN, Color("#f4ce76"))
		Global.NightGrowth.DRY:
			ink.draw_colored_polygon(DROP_BADGE, Color("#253e39"))
			ink.draw_colored_polygon(DROP_FILL, Color("#a4d4d0"))
		Global.NightGrowth.BLOCKED:
			ink.draw_rect(Rect2(-2.5, -2.5, 5, 5), Color("#49362c"))
			ink.draw_line(Vector2(-1.6, -1.6), Vector2(1.6, 1.6), Color("#efa07b"), 1.3)
			ink.draw_line(Vector2(-1.6, 1.6), Vector2(1.6, -1.6), Color("#efa07b"), 1.3)

static func draw_paddy(ink: CanvasItem, soil: Rect2, rain: bool) -> void:
	var inset := soil.grow(-1.0)
	var origin := inset.position
	var size := inset.size
	var water := PADDY_WATER.darkened(0.12) if rain else PADDY_WATER
	ink.draw_colored_polygon(PackedVector2Array([
		origin + Vector2(2, 0), origin + Vector2(size.x - 2, 0), origin + Vector2(size.x, 2),
		origin + size - Vector2(0, 2), origin + size - Vector2(2, 0), origin + Vector2(2, size.y),
		origin + Vector2(0, size.y - 2), origin + Vector2(0, 2),
	]), PADDY_RIM)
	ink.draw_colored_polygon(PackedVector2Array([
		origin + Vector2(2, 1.5), origin + Vector2(size.x - 2, 1.5), origin + Vector2(size.x - 1, 3),
		origin + size - Vector2(1, 3), origin + size - Vector2(3, 1.5), origin + Vector2(2, size.y - 1.5),
		origin + Vector2(1, size.y - 3), origin + Vector2(1, 3),
	]), water)
	ink.draw_rect(Rect2(origin + Vector2(3, 1.5), Vector2(size.x - 6, 1)), water.darkened(0.24))
	ink.draw_rect(Rect2(origin + Vector2(1.5, 4), Vector2(1, size.y - 7)), water.darkened(0.16))
	ink.draw_rect(Rect2(origin + Vector2(4, size.y - 2.0), Vector2(size.x - 7, 0.5)), water.lightened(0.17))
	ink.draw_rect(Rect2(origin + Vector2(size.x - 5, 4), Vector2(2.5, 0.5)), PADDY_REFLECTION.darkened(0.25))

static func draw_soil_moisture(ink: CanvasItem, soil: Rect2, rained_on: bool) -> void:
	var origin := soil.position
	var size := soil.size
	if rained_on:
		ink.draw_rect(soil, Color("#332f285c"))
		return
	var damp := soil.grow(-0.5)
	ink.draw_rect(damp, Color("#382d235c"))
	# Water settles into the open furrows, leaving the raised corner marks legible.
	for row in 3:
		var y := origin.y + 3.5 + row * 4
		var left := origin.x + (1.5 if row == 1 else 3.0)
		var right := origin.x + size.x - (3.0 if row == 2 else 1.5)
		var furrow := PackedVector2Array([Vector2(left, y + 0.5), Vector2(left + 2, y),
			Vector2(right - 2, y + 0.5), Vector2(right, y), Vector2(right - 1, y + 1),
			Vector2(left + 2, y + 1)])
		ink.draw_colored_polygon(furrow, Color("#2c302959"))
	ink.draw_rect(Rect2(origin + Vector2(3, size.y - 4.5), Vector2(2.5, 0.5)), Color("#b1b8a566"))
	ink.draw_rect(Rect2(origin + Vector2(size.x - 6, 4), Vector2(1.5, 0.5)), Color("#b1b8a558"))
