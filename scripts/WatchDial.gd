extends Control

# A game clock that reads the same earthly branches as the almanac.
const MARKS := [Vector2i(22, 5), Vector2i(31, 7), Vector2i(37, 13), Vector2i(39, 22),
	Vector2i(37, 31), Vector2i(31, 37), Vector2i(22, 39), Vector2i(13, 37),
	Vector2i(7, 31), Vector2i(5, 22), Vector2i(7, 13), Vector2i(13, 7)]

var cast_edge := PackedVector2Array([Vector2(14, 0), Vector2(30, 0), Vector2(30, 2), Vector2(35, 2),
	Vector2(35, 5), Vector2(39, 5), Vector2(39, 9), Vector2(42, 9), Vector2(42, 14),
	Vector2(44, 14), Vector2(44, 30), Vector2(42, 30), Vector2(42, 35), Vector2(39, 35),
	Vector2(39, 39), Vector2(35, 39), Vector2(35, 42), Vector2(30, 42), Vector2(30, 44),
	Vector2(14, 44), Vector2(14, 42), Vector2(9, 42), Vector2(9, 39), Vector2(5, 39),
	Vector2(5, 35), Vector2(2, 35), Vector2(2, 30), Vector2(0, 30), Vector2(0, 14),
	Vector2(2, 14), Vector2(2, 9), Vector2(5, 9), Vector2(5, 5), Vector2(9, 5), Vector2(9, 2), Vector2(14, 2)])

var watch := 3

func show_watch(label: String) -> void:
	watch = Global.DAY_WATCHES.find(label.left(1))
	queue_redraw()

func _draw() -> void:
	draw_colored_polygon(cast_edge, Color("#302920"))
	draw_set_transform(Vector2(1, 1), 0.0, Vector2(0.95, 0.95))
	draw_colored_polygon(cast_edge, Color("#a77841"))
	draw_set_transform(Vector2(3, 3), 0.0, Vector2(0.86, 0.86))
	draw_colored_polygon(cast_edge, Color("#526052"))
	draw_set_transform(Vector2(4, 4), 0.0, Vector2(0.82, 0.82))
	draw_colored_polygon(cast_edge, Color("#353f35"))
	draw_set_transform(Vector2.ZERO)
	for index in MARKS.size():
		var point := Vector2(MARKS[index])
		var size := Vector2(3, 3) if index % 3 == 0 else Vector2(2, 2)
		if index == watch:
			draw_rect(Rect2(point - Vector2(3, 3), Vector2(7, 7)), Color("#662d22"))
			draw_rect(Rect2(point - Vector2(2, 2), Vector2(5, 5)), Color("#f9c884"))
		else:
			draw_rect(Rect2(point - Vector2.ONE, size), Color("#ad9860"))
