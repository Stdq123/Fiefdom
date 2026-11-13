extends Node2D

const STORE := preload("res://assets/world/estate-storage.svg")
const NINJA := preload("res://assets/world/ninja-adventure/tileset_village_abandoned.png")
const PEBBLES := Rect2(160, 64, 16, 16)
const SACK := Rect2(0, 0, 16, 16)
const STAKES := [Vector2(-20, -17), Vector2(20, -17), Vector2(20, 21), Vector2(-20, 21)]
const UNEVEN := [Vector2(-18, -10), Vector2(-9, -14), Vector2(4, -12), Vector2(15, -15),
	Vector2(20, -4), Vector2(18, 11), Vector2(10, 17), Vector2(-2, 19), Vector2(-16, 14), Vector2(-21, 2)]
const LEVELED := [Vector2(-19, -19), Vector2(18, -19), Vector2(22, -13), Vector2(22, 16),
	Vector2(17, 22), Vector2(-16, 22), Vector2(-22, 17), Vector2(-22, -13)]

var stage := 0

func _draw() -> void:
	var rain := Global.has_rain()
	var soil := Color("#866443") if rain else Color("#a08155")
	var cord := Color("#c8a779") if rain else Color("#dfc08a")
	if stage > 0:
		var edge := PackedVector2Array(UNEVEN if stage == 1 else LEVELED)
		draw_colored_polygon(edge, soil.darkened(0.38))
		draw_set_transform(Vector2(0, -1), 0.0, Vector2(0.9, 0.88))
		draw_colored_polygon(edge, soil)
		draw_set_transform(Vector2.ZERO)
		_draw_loose_soil(soil)
	if stage == 1:
		draw_texture_rect_region(NINJA, Rect2(-13, -7, 12, 12), PEBBLES, Color("#b9ae99"))
	elif stage == 2:
		for y in range(-12, 16, 6):
			draw_line(Vector2(-15, y + 1), Vector2(15, y + 1), soil.darkened(0.28))
			draw_line(Vector2(-13, y), Vector2(15, y), soil.lightened(0.12))
	elif stage == 3:
		for offset in [-8, 8]:
			_draw_cord(Vector2(offset, -17), Vector2(offset, 19), cord)
			_draw_cord(Vector2(-19, offset), Vector2(19, offset), cord)
		_draw_stake(Vector2(0, 2), cord)

	_draw_cord(STAKES[0] + Vector2(0, -3), STAKES[1] + Vector2(0, -3), cord)
	_draw_cord(STAKES[0] + Vector2(0, -3), STAKES[3] + Vector2(0, -3), cord)
	_draw_cord(STAKES[1] + Vector2(0, -3), STAKES[2] + Vector2(0, -3), cord)
	for point: Vector2 in STAKES:
		_draw_stake(point, cord)
	if stage < 3:
		draw_texture_rect_region(STORE, Rect2(9, 5, 10, 10), SACK, Color("#cdbb8b"))

func _draw_loose_soil(soil: Color) -> void:
	for point: Vector2 in [Vector2(-15, -5), Vector2(-10, 11), Vector2(-4, -8), Vector2(-1, 6),
			Vector2(5, 13), Vector2(10, -7), Vector2(14, -2), Vector2(15, 10)]:
		draw_rect(Rect2(point, Vector2(3, 1)), soil.darkened(0.24))
		draw_rect(Rect2(point - Vector2(1, 1), Vector2(2, 1)), soil.lightened(0.16))

func _draw_cord(from: Vector2, to: Vector2, cord: Color) -> void:
	draw_line(from + Vector2.DOWN, to + Vector2.DOWN, Color("#3b3325"), 1.0)
	draw_line(from, to, cord, 1.0)

func _draw_stake(point: Vector2, cord: Color) -> void:
	draw_rect(Rect2(point + Vector2(-2, 0), Vector2(5, 2)), Color("#302f249a"))
	draw_rect(Rect2(point + Vector2(-1, -7), Vector2(3, 8)), Color("#563e2b"))
	draw_rect(Rect2(point + Vector2(-1, -7), Vector2(1, 7)), Color("#a47b4e"))
	draw_rect(Rect2(point + Vector2(-1, -5), Vector2(3, 1)), cord)
