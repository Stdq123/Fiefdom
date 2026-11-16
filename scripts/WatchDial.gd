extends Control

const FACE := preload("res://assets/ui/watch-dial.png")
# Coordinates are native pixels on the cast rim, in the almanac's order.
const MARKS := [
	Vector2(24, 5), Vector2(33, 7), Vector2(40, 14), Vector2(42, 23),
	Vector2(40, 32), Vector2(33, 39), Vector2(24, 41), Vector2(15, 39),
	Vector2(8, 32), Vector2(6, 23), Vector2(8, 14), Vector2(15, 7),
]

var watch := 3

func show_watch(label: String) -> void:
	watch = Global.DAY_WATCHES.find(label.left(1))
	queue_redraw()

func _draw() -> void:
	draw_texture(FACE, Vector2.ZERO)
	for index in MARKS.size():
		var point: Vector2 = MARKS[index]
		if index == watch:
			draw_rect(Rect2(point - Vector2(2, 2), Vector2(5, 5)), Color("#6b3427"))
			draw_rect(Rect2(point - Vector2.ONE, Vector2(3, 3)), Color("#f0a563"))
			draw_rect(Rect2(point - Vector2.ONE, Vector2(2, 2)), Color("#ffe6a8"))
		elif index % 3 == 0:
			draw_rect(Rect2(point - Vector2.ONE, Vector2(3, 3)), Color("#504735"))
			draw_rect(Rect2(point - Vector2.ONE, Vector2(2, 1)), Color("#d3ae74"))
		else:
			draw_rect(Rect2(point, Vector2(2, 2)), Color("#c6a170"))
