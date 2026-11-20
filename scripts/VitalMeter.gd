extends ProgressBar
class_name VitalMeter

const SPENT_INK := Color("#b87b50b3")
const RESTORED_INK := Color("#f1e5a0ad")
const PREVIEW_INK := Color("#ffe1a5")
const SHORTAGE_INK := Color("#ffc4a0")

var planned_cost := 0
var _reading_ready := false
var _trace := 0.0
var _motion: Tween

func set_amount(amount: int, capacity: int) -> void:
	var before := ratio
	var new_scale := not is_equal_approx(max_value, float(capacity))
	max_value = capacity
	value = amount
	var current := ratio
	if not _reading_ready or new_scale or not is_visible_in_tree():
		if _motion:
			_motion.kill()
		_set_trace(current)
		_reading_ready = true
	elif not is_equal_approx(before, current):
		if _motion:
			_motion.kill()
		# Successive deductions keep the previous mark until the latest drop settles.
		_set_trace(maxf(_trace, before) if current < before else before)
		_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		_motion.tween_interval(0.14)
		_motion.tween_method(_set_trace, _trace, current, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	queue_redraw()

func set_cost_preview(cost: int) -> void:
	if planned_cost != cost:
		planned_cost = cost
		queue_redraw()

func _set_trace(part: float) -> void:
	_trace = part
	queue_redraw()

func _fill_edge(part: float) -> float:
	# The horizontal ProgressBar adds the minimum size of the fill style to a nonempty fill.
	var minimum := int(get_theme_stylebox(&"fill").get_minimum_size().x)
	var width := roundf(part * (size.x - minimum))
	return width + minimum if width > 0.0 else 0.0

func _draw() -> void:
	if not _reading_ready:
		return
	var current := _fill_edge(ratio)
	var previous := _fill_edge(_trace)
	var left := maxf(1.0, minf(previous, current))
	var right := minf(size.x - 1.0, maxf(previous, current))
	if right > left:
		var gained := previous < current
		var shade := RESTORED_INK if gained else SPENT_INK
		var top := 1.0 if gained else 2.0
		draw_rect(Rect2(left, top, right - left, size.y - top - 2.0), shade)
		draw_line(Vector2(left, top), Vector2(right, top), shade.lightened(0.26), 1.0)
	if planned_cost > 0:
		_draw_preview(current)

func _draw_preview(current_edge: float) -> void:
	var short := planned_cost > value
	var ink := SHORTAGE_INK if short else PREVIEW_INK
	var after := maxf(0.0, value - planned_cost) / maxf(1.0, max_value)
	var left := maxf(1.0, _fill_edge(after))
	var right := minf(size.x - 1.0, current_edge)
	var bottom := size.y - 1.0
	if right > left:
		draw_rect(Rect2(left, 1.0, right - left, bottom - 1.0), Color(ink, 0.20))
		for x in range(ceili(left) + 2, floori(right) - 2, 5):
			draw_line(Vector2(x, bottom - 1.0), Vector2(x + 2.0, 2.0), ink, 0.9, true)
		draw_line(Vector2(left, 1.0), Vector2(left, bottom), ink, 1.5, true)
	if short:
		draw_line(Vector2(2.0, 2.0), Vector2(6.0, bottom - 1.0), ink, 1.3, true)
		draw_line(Vector2(6.0, 2.0), Vector2(2.0, bottom - 1.0), ink, 1.3, true)
