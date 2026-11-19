extends Node2D

var elapsed := 0.0
var shelter_bounds := Rect2()

func _ready() -> void:
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.estate_room_changed.connect(_refresh.unbind(1))
	_refresh()

func _refresh() -> void:
	var raining := Global.has_rain() and not Global.is_indoors()
	visible = raining
	set_process(raining)

func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, 900.0)
	queue_redraw()

func _draw() -> void:
	var view_size := get_viewport_rect().size
	var screen_to_map := get_global_transform_with_canvas().affine_inverse()
	for drop in 84:
		var lane := float(drop % 3)
		var x := fposmod(float(drop * 137) - elapsed * (61.0 + 7.0 * lane), view_size.x + 40.0)
		var y := fposmod(float(drop * 109) + elapsed * (232.0 + 23.0 * lane), view_size.y + 40.0)
		var point := Vector2(x - 20.0, y - 20.0).floor()
		var start := screen_to_map * point
		var finish := screen_to_map * (point + Vector2(-4, 13 + lane * 3))
		if shelter_bounds.has_point(start) or shelter_bounds.has_point(finish):
			continue
		draw_line(start, finish,
			Color(0.69, 0.81, 0.78, 0.23 + lane * 0.055), 0.6)
