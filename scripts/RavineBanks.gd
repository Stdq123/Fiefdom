extends Node2D

# Each shelf follows the creek apart from the open bridge approaches.
const WEST_UPPER := [Vector3(108, -89, 2), Vector3(108, -74, 9), Vector3(114, -64, 21),
	Vector3(113, -51, 27), Vector3(119, -39, 26), Vector3(120, -27, 17), Vector3(125, -22, 19),
	Vector3(122, -14, 15), Vector3(127, -3, 10), Vector3(126, 9, 6), Vector3(130, 16, 2)]
const EAST_UPPER := [Vector3(160, -65, 2), Vector3(157, -55, 13), Vector3(162, -49, 18),
	Vector3(159, -38, 16), Vector3(166, -26, 19), Vector3(163, -18, 14), Vector3(169, -7, 12),
	Vector3(166, 4, 9), Vector3(171, 12, 6), Vector3(169, 20, 2)]
const WEST_LOWER := [Vector3(129, 55, 3), Vector3(129, 61, 11), Vector3(126, 69, 13),
	Vector3(130, 79, 19), Vector3(128, 89, 21), Vector3(135, 96, 17), Vector3(139, 106, 16),
	Vector3(147, 115, 11), Vector3(152, 128, 7), Vector3(156, 135, 2)]
const EAST_LOWER := [Vector3(168, 53, 3), Vector3(171, 62, 14), Vector3(169, 72, 21),
	Vector3(173, 80, 17), Vector3(176, 89, 28), Vector3(183, 98, 26), Vector3(181, 106, 23),
	Vector3(193, 115, 27), Vector3(200, 124, 19), Vector3(206, 130, 15), Vector3(210, 141, 7), Vector3(217, 148, 2)]

const MOSS := [Color("#697748"), Color("#6b7946"), Color("#80754c"), Color("#a3aaa0")]
const STONE := Color("#747568")
const CASCADE_LIP: Array[Vector2] = [Vector2(124, -58), Vector2(128, -60), Vector2(137, -55),
	Vector2(144, -55), Vector2(152, -57), Vector2(159, -54)]
const CASCADE_BASE: Array[Vector2] = [Vector2(124, -48), Vector2(130, -42), Vector2(138, -43),
	Vector2(149, -40), Vector2(154, -44), Vector2(160, -45)]
const FALL_BOUNDS := Rect2(122, -61, 40, 34)

var fall_time := 0.0
var frame := 0
var rng := RandomNumberGenerator.new()

func _process(delta: float) -> void:
	fall_time = fposmod(fall_time + delta, 12.0)
	var next := int(fall_time * 12.0)
	if next != frame and get_viewport_rect().intersects(get_global_transform_with_canvas() * FALL_BOUNDS):
		frame = next
		queue_redraw()

static func draw_banks(canvas: CanvasItem, season: int, wet: bool) -> void:
	_ledge(canvas, WEST_UPPER, -1.0, season, wet)
	_ledge(canvas, EAST_UPPER, 1.0, season, wet)
	_ledge(canvas, WEST_LOWER, -1.0, season, wet)
	_ledge(canvas, EAST_LOWER, 1.0, season, wet)

func _draw() -> void:
	var falling := Color("#538583") if Global.has_rain() else Color("#579694")
	var foam := Color("#b9d3bd")
	rng.seed = 78
	for index in CASCADE_LIP.size() - 1:
		var a := CASCADE_LIP[index]
		var b := CASCADE_LIP[index + 1]
		var bottom_a := CASCADE_BASE[index]
		var bottom_b := CASCADE_BASE[index + 1]
		var crest := a.lerp(b, 0.48).round()
		var splash := bottom_a.lerp(bottom_b, 0.55).round()
		_quad(self, a, b, bottom_b, bottom_a, falling.darkened(0.06 * (index % 3)))
		draw_line(a, crest, foam, 1.0)
		draw_line(crest, b, falling.lightened(0.31), 1.0)
		for strip in 3:
			var across := (float(strip) + rng.randf() * 0.7) / 3.0
			var from := a.lerp(b, across)
			var to := bottom_a.lerp(bottom_b, across)
			var phase := fposmod(float(frame) / 9.0 + rng.randf(), 1.0)
			var end := minf(1.0, phase + 0.20 + rng.randf() * 0.42)
			draw_line(from.lerp(to, phase).round(), from.lerp(to, end).round(), Color(foam, 0.3 + across * 0.42), 1.0)
		draw_line(bottom_a, splash, foam, 1.0)
		var ripple_y := float(posmod(frame + index * 9, 22)) * 0.5
		var ripple := (splash + Vector2(0, ripple_y)).round()
		draw_line(ripple, ripple + Vector2(3 + index % 3, 0), Color(foam, 0.70 - ripple_y * 0.06), 1.0)

static func _ledge(canvas: CanvasItem, profile: Array, side: float, season: int, wet: bool) -> void:
	var winter := season == Global.Season.WINTER
	var moss: Color = MOSS[season]
	var grass := moss.lerp(Color("#465942"), 0.36 if not winter else 0.25)
	var stone := STONE.lerp(Color("#5a6c64"), 0.28 if wet else 0.0)
	var count := profile.size() - 1
	for index in count:
		var left: Vector3 = profile[index]
		var right: Vector3 = profile[index + 1]
		var toe_a := Vector2(left.x, left.y)
		var toe_b := Vector2(right.x, right.y)
		var edge_a := toe_a + Vector2(side * left.z * 0.34, -left.z * 0.48).round()
		var edge_b := toe_b + Vector2(side * right.z * 0.34, -right.z * 0.48).round()
		var turf_a := edge_a + Vector2(side * left.z * 0.79, -left.z * 0.23).round()
		var turf_b := edge_b + Vector2(side * right.z * 0.79, -right.z * 0.23).round()
		var dark := stone.darkened(0.37 if side < 0.0 else 0.22)
		var face := stone.lightened(0.06 if index % 3 == 0 else 0.0)
		if side < 0.0:
			face = face.darkened(0.20)
		var seam_a := edge_a.lerp(toe_a, 0.45 + (index % 2) * 0.16).round()
		var seam_b := edge_b.lerp(toe_b, 0.45 + ((index + 1) % 2) * 0.16).round()
		var top_a := edge_a.lerp(turf_a, 0.42).round()
		var top_b := edge_b.lerp(turf_b, 0.46).round()
		_quad(canvas, top_a, top_b, turf_b, turf_a, Color(grass, 0.60))
		_quad(canvas, edge_a, edge_b, top_b, top_a, grass.lightened(0.08 if index % 3 == 1 else 0.02))
		_quad(canvas, edge_a, edge_b, seam_b, seam_a, face)
		_quad(canvas, seam_a, seam_b, toe_b, toe_a, dark)
		var cut := edge_a.lerp(edge_b, 0.48).round()
		var base := toe_a.lerp(toe_b, 0.68).round()
		_quad(canvas, cut, edge_b, toe_b, base, Color(dark, 0.65))
		canvas.draw_line(cut, base, dark.darkened(0.18), 1.0)
		for mark in range(0, 5):
			var along := (float(mark) + (index % 3) * 0.19) * 0.2
			var lip := edge_a.lerp(edge_b, along).round()
			var sprig := lip.lerp(turf_a.lerp(turf_b, along), 0.23 + (mark % 3) * 0.17).round()
			var chip := seam_a.lerp(seam_b, along).round()
			canvas.draw_rect(Rect2(chip, Vector2(2 + mark % 2, 1)), face.lightened(0.09))
			canvas.draw_rect(Rect2(lip, Vector2(2 + index % 3, 1)), moss.lightened(0.17 if winter else 0.09))
			if left.z >= 7.0 and (index + mark) % 3 != 2:
				canvas.draw_rect(Rect2(sprig + Vector2(0, -2), Vector2(1, 3)), moss.lightened(0.14))
				canvas.draw_rect(Rect2(sprig, Vector2(4, 1)), moss.lightened(0.08))

static func _quad(canvas: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	var first := PackedVector2Array([a, b, c])
	var second := PackedVector2Array([a, c, d])
	# Some bank faces pinch to a point at a bend.
	if absf((b - a).cross(c - a)) > 0.01:
		canvas.draw_colored_polygon(first, color)
	if absf((c - a).cross(d - a)) > 0.01:
		canvas.draw_colored_polygon(second, color)
