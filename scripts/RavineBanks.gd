extends Node2D

# Creek-bed positions and the height of the bank above them.
const WEST_UPPER: Array[Vector3] = [Vector3(114, -98, 2), Vector3(114, -86, 10), Vector3(116, -76, 24),
	Vector3(115, -63, 35), Vector3(116, -50, 34), Vector3(120, -39, 27), Vector3(119, -25, 24),
	Vector3(126, -12, 17), Vector3(126, 2, 10), Vector3(129, 14, 2)]
const EAST_UPPER: Array[Vector3] = [Vector3(153, -93, 2), Vector3(151, -80, 10), Vector3(151, -67, 25),
	Vector3(152, -55, 34), Vector3(154, -43, 29), Vector3(156, -32, 18), Vector3(154, -19, 23),
	Vector3(163, -4, 20), Vector3(166, 8, 11), Vector3(165, 17, 2)]
const WEST_LOWER: Array[Vector3] = [Vector3(131, 58, 2), Vector3(131, 67, 8), Vector3(129, 78, 12),
	Vector3(134, 90, 19), Vector3(138, 101, 17), Vector3(144, 112, 16),
	Vector3(153, 122, 13), Vector3(159, 132, 8), Vector3(169, 145, 2)]
const EAST_LOWER: Array[Vector3] = [Vector3(167, 58, 3), Vector3(166, 70, 11), Vector3(167, 81, 22),
	Vector3(175, 92, 30), Vector3(179, 103, 32), Vector3(185, 112, 24),
	Vector3(194, 122, 30), Vector3(202, 134, 23), Vector3(209, 145, 13), Vector3(217, 153, 2)]

const MOSS := [Color("#87904f"), Color("#75874e"), Color("#9c8753"), Color("#bdc8bb")]
const CASCADE_LIP: Array[Vector2] = [Vector2(116, -69), Vector2(122, -67), Vector2(130, -67),
	Vector2(137, -64), Vector2(145, -65), Vector2(151, -68)]
const CASCADE_BASE: Array[Vector2] = [Vector2(120, -43), Vector2(126, -40), Vector2(134, -35),
	Vector2(141, -35), Vector2(148, -39), Vector2(153, -44)]
const PLUNGE_POOL := [Vector2(120, -43), Vector2(125, -48), Vector2(142, -46), Vector2(151, -42),
	Vector2(154, -34), Vector2(151, -27), Vector2(145, -18), Vector2(137, -15),
	Vector2(128, -22), Vector2(123, -30)]
const FALL_BOUNDS := Rect2(112, -78, 47, 72)

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
	var wet := Global.has_rain()
	var water := Color("#4d898f") if wet else Color("#579ea3")
	var foam := Color("#b5dcd4") if wet else Color("#d5ede0")
	var pool := PackedVector2Array(PLUNGE_POOL)
	var pool_colors := PackedColorArray()
	for point in pool:
		pool_colors.append(Color(water.darkened(0.12), 0.36 * (1.0 - smoothstep(-39.0, -16.0, point.y))))
	draw_polygon(pool, pool_colors)
	# Each tongue has a lit crest, a tinted face and a broken fan at the point of impact.
	rng.seed = 78
	for index in CASCADE_LIP.size() - 1:
		var lip := CASCADE_LIP[index]
		var next_lip := CASCADE_LIP[index + 1]
		var foot := CASCADE_BASE[index]
		var next_foot := CASCADE_BASE[index + 1]
		var face := water.lightened(0.06 + 0.035 * (index % 3))
		var upstream := Vector2(-1, -13 - index % 3)
		draw_polygon(PackedVector2Array([lip + upstream, next_lip + upstream, next_lip, lip]), PackedColorArray([
			Color(water, 0.0), Color(water, 0.0), Color(face.lightened(0.1), 0.87), Color(face.lightened(0.1), 0.92)]))
		draw_polygon(PackedVector2Array([lip, next_lip, next_foot, foot]), PackedColorArray([
			face.lightened(0.32), face.lightened(0.24), Color(face.darkened(0.06), 0.78), Color(face.darkened(0.20), 0.78)]))
		var crest := lip.lerp(next_lip, 0.52).round()
		draw_line(lip, crest, foam, 1.5)
		draw_line(crest, next_lip, face.lightened(0.29), 1.0)
		for strip in 3:
			var across := (float(strip) + rng.randf() * 0.75) / 3.0
			var start := lip.lerp(next_lip, across)
			var finish := foot.lerp(next_foot, across)
			var phase := fposmod(float(frame) / 12.0 + rng.randf(), 1.0)
			var end := minf(1.0, phase + 0.18 + rng.randf() * 0.30)
			draw_line(start.lerp(finish, phase).round(), start.lerp(finish, end).round(),
				Color(foam, 0.28 + across * 0.52), 1.0)
		var impact := foot.lerp(next_foot, 0.43).round()
		var spray := (impact + Vector2(0, float(posmod(frame + index * 3, 6)) - 2.0)).round()
		draw_rect(Rect2(spray - Vector2(2, 0), Vector2(4, 2)), Color(foam, 0.78))
		draw_rect(Rect2(spray + Vector2(2, 2), Vector2(3, 1)), Color(foam, 0.52))
		for ring in 2:
			var drift := float(posmod(frame + index * 11 + ring * 12, 24))
			var ripple := (impact + Vector2(2.0 + drift * 0.08, 4.0 + drift * 0.63)).round()
			if Geometry2D.is_point_in_polygon(ripple, pool):
				draw_rect(Rect2(ripple - Vector2(2, 0), Vector2(4 + index % 3, 1)), Color(foam, 0.66 - drift * 0.026))

static func _ledge(canvas: CanvasItem, profile: Array[Vector3], side: float, season: int, wet: bool) -> void:
	var winter := season == Global.Season.WINTER
	var moss: Color = MOSS[season]
	var turf := moss.lerp(Color("#4a6244"), 0.35 if not winter else 0.14).darkened(0.10 if wet else 0.0)
	var stone := Color("#888273") if side > 0.0 else Color("#77766a")
	if wet:
		stone = stone.lerp(Color("#4b625f"), 0.36)
	for index in profile.size() - 1:
		var a := profile[index]
		var b := profile[index + 1]
		var toe_a := Vector2(a.x, a.y)
		var toe_b := Vector2(b.x, b.y)
		var rim_a := toe_a + Vector2(side * a.z * 0.38, -a.z * 0.66).round()
		var rim_b := toe_b + Vector2(side * b.z * 0.38, -b.z * 0.66).round()
		var back_a := rim_a + Vector2(side * a.z * 0.82, -a.z * 0.28).round()
		var back_b := rim_b + Vector2(side * b.z * 0.82, -b.z * 0.28).round()
		var bank_a := rim_a.lerp(back_a, 0.43).round()
		var bank_b := rim_b.lerp(back_b, 0.43).round()
		var seam_a := rim_a.lerp(toe_a, 0.47 + (index % 3) * 0.08).round()
		var seam_b := rim_b.lerp(toe_b, 0.47 + ((index + 1) % 3) * 0.08).round()
		var face := stone.lightened(0.03 * posmod(index * 3, 5))
		var undercut := face.lerp(Color("#263d38"), 0.44)
		var shadow_a := toe_a + Vector2(-side * a.z * 0.24, a.z * 0.14).round()
		var shadow_b := toe_b + Vector2(-side * b.z * 0.24, b.z * 0.14).round()
		_quad(canvas, toe_a, toe_b, shadow_b, shadow_a, Color("#1e424a99"))
		var outer := Color(turf.darkened(0.15), 0.0)
		var inner := Color(turf, 0.72 if winter else 0.58)
		_gradient_quad(canvas, bank_a, bank_b, back_b, back_a, inner, outer)
		_quad(canvas, rim_a, rim_b, bank_b, bank_a, turf.lightened(0.08 if index % 3 == 1 else 0.0))
		_quad(canvas, seam_a, seam_b, toe_b, toe_a, undercut)
		_quad(canvas, rim_a, rim_b, seam_b, seam_a, face)
		var cut := rim_a.lerp(rim_b, 0.28 + (index % 4) * 0.13).round()
		var crack := seam_a.lerp(seam_b, 0.38 + (index % 4) * 0.13).round()
		var base := toe_a.lerp(toe_b, 0.31 + (index % 4) * 0.13).round()
		_quad(canvas, cut, rim_b, seam_b, crack, Color(undercut, 0.42))
		_quad(canvas, crack, seam_b, toe_b, base, Color(undercut.darkened(0.16), 0.48))
		if minf(a.z, b.z) > 8.0:
			canvas.draw_line(rim_a.lerp(rim_b, 0.1), cut, moss.lightened(0.22 if winter else 0.11), 1.5)
			canvas.draw_line(cut.lerp(crack, 0.6), seam_a.lerp(crack, 0.6), face.lightened(0.22), 1.0)
			var root := rim_a.lerp(rim_b, 0.16 + (index % 3) * 0.18).round()
			_draw_moss(canvas, root, side, moss, winter)

static func _draw_moss(canvas: CanvasItem, root: Vector2, side: float, moss: Color, winter: bool) -> void:
	var growth := PackedVector2Array([root + Vector2(-3 * side, 0), root + Vector2(-2 * side, -3),
		root + Vector2(3 * side, -5), root + Vector2(5 * side, -2), root + Vector2(4 * side, 1), root + Vector2(0, 2)])
	canvas.draw_colored_polygon(growth, moss.darkened(0.06))
	canvas.draw_line(root + Vector2(side * 2, -3), root + Vector2(side * 4, -4), moss.lightened(0.16), 1.0)
	if not winter:
		canvas.draw_line(root + Vector2(side * 4, -2), root + Vector2(side * 6, -6), moss.lightened(0.08), 1.0)

static func _quad(canvas: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	_gradient_quad(canvas, a, b, c, d, color, color)

static func _gradient_quad(canvas: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, near: Color, far: Color) -> void:
	# Some bank faces pinch to a point at a bend.
	if absf((b - a).cross(c - a)) > 0.01:
		canvas.draw_polygon(PackedVector2Array([a, b, c]), PackedColorArray([near, near, far]))
	if absf((c - a).cross(d - a)) > 0.01:
		canvas.draw_polygon(PackedVector2Array([a, c, d]), PackedColorArray([near, far, far]))
