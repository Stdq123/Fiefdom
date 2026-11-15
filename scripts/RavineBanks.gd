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
const WILLOW_LEDGE := [1.0, 5.0, 11.0, 12.0, 9.0, 7.0, 5.0, 1.0]
const GRAVEL_LEDGE := [1.0, 3.0, 6.0, 6.0, 7.0, 5.0, 1.0]
const FORD_STONES: Array[Vector3] = [Vector3(-26, 1, 5), Vector3(-16, -1, 4), Vector3(-7, 2, 4),
	Vector3(3, 0, 5), Vector3(14, 3, 5), Vector3(25, 1, 6)]
const CASCADE_LIP: Array[Vector2] = [Vector2(116, -69), Vector2(122, -67), Vector2(130, -67),
	Vector2(137, -64), Vector2(145, -65), Vector2(151, -68)]
const CASCADE_BASE: Array[Vector2] = [Vector2(120, -43), Vector2(126, -40), Vector2(134, -35),
	Vector2(141, -35), Vector2(148, -39), Vector2(153, -44)]
const PLUNGE_POOL := [Vector2(119, -43), Vector2(123, -48), Vector2(137, -49), Vector2(150, -45),
	Vector2(154, -41), Vector2(156, -34), Vector2(155, -19), Vector2(150, -11), Vector2(142, -9),
	Vector2(132, -14), Vector2(126, -22), Vector2(123, -33)]
# Tops begin at the water lip. The feet sit against the wet bank below it.
const CASCADE_BANKS := [
	{
		"top": [Vector2(116, -69), Vector2(110, -69), Vector2(103, -66), Vector2(99, -72),
			Vector2(96, -87), Vector2(105, -96), Vector2(115, -93), Vector2(118, -84)],
		"foot": [Vector2(120, -49), Vector2(114, -52), Vector2(106, -54), Vector2(100, -64)],
	},
	{
		"top": [Vector2(151, -68), Vector2(161, -70), Vector2(169, -69), Vector2(178, -78),
			Vector2(193, -87), Vector2(188, -92), Vector2(176, -96), Vector2(163, -94), Vector2(155, -87)],
		"foot": [Vector2(153, -47), Vector2(164, -52), Vector2(175, -57), Vector2(183, -72)],
	},
]
const FALL_BOUNDS := Rect2(111, -83, 49, 78)
const FORD_RIPPLES := [Vector2(-9, 6), Vector2(1, 9), Vector2(12, 7)]
const FORD_BOUNDS := Rect2(RavineLayout.FORD - Vector2(15, 0), Vector2(36, 27))

# The water edge follows the collision ribbon. Its depth and the width of the soil beyond it vary independently.
class Channel:
	var sides: Array[PackedVector2Array] = []
	var shoals: Array[PackedVector2Array] = []
	var shoulders: Array[PackedVector2Array] = []
	var bed: Array[PackedVector2Array] = []
	var pebbles: Array[Vector3] = []
	var wet_stones: Array[Vector3] = []

	func _init(center: PackedVector2Array, half_width: float, crossings: Array[Rect2]) -> void:
		var rows := PackedVector2Array([center[0]])
		for index in range(1, center.size()):
			var first := center[index - 1]
			var last := center[index]
			var count := ceili((last.y - first.y) / 12.0)
			for sample in range(1, count + 1):
				rows.append(first.lerp(last, float(sample) / count))
		for side: float in [-1.0, 1.0]:
			var edge := PackedVector2Array()
			var shallow := PackedVector2Array()
			var shoulder := PackedVector2Array()
			var stone_bed := PackedVector2Array()
			for index in rows.size():
				var at := rows[index]
				var bend := sin(at.y * 0.027 + side) * 0.5 + cos(at.y * 0.061) * 0.5
				var wet_edge := at + Vector2(side * half_width, 0.0)
				var breadth := 7.5 + 4.5 * bend
				if wet_edge.y > -45.0 and wet_edge.y < 12.0:
					breadth *= 0.58
				edge.append(wet_edge)
				shallow.append(wet_edge - Vector2(side * (7.0 + 3.0 * bend), 0.0))
				shoulder.append(wet_edge + Vector2(side * breadth, 0.0))
				stone_bed.append(wet_edge + Vector2(side * breadth * 0.48, 0.0))
				if crossings.any(func(crossing: Rect2) -> bool: return crossing.has_point(wet_edge)):
					continue
				if (index + int(side)) % 3 != 0:
					var pebble := (wet_edge + Vector2(side * (1.0 + index % 5), index % 4)).round()
					pebbles.append(Vector3(pebble.x, pebble.y, 2 + index % 4))
				if (index + int(side)) % 5 < 2:
					var submerged := (wet_edge - Vector2(side * (3.5 + index % 4), index % 3)).round()
					wet_stones.append(Vector3(submerged.x, submerged.y, 2 + index % 4))
			sides.append(edge)
			shoals.append(shallow)
			shoulders.append(shoulder)
			bed.append(stone_bed)

	func draw_shoulder(canvas: CanvasItem, meadow: Color, season: int, wet: bool) -> void:
		var winter := season == Global.Season.WINTER
		var outer := meadow.lerp(Color("#344a40"), 0.54)
		var dark := Color(outer, 0.82 if wet else 0.56)
		var silt := Color("#6d8178") if winter else Color("#747959")
		silt = silt.lerp(Color("#4c655a"), 0.26 if wet else 0.0)
		for side in sides.size():
			_draw_band(canvas, sides[side], bed[side], Color(silt, 0.88), dark)
			_draw_band(canvas, bed[side], shoulders[side], dark, Color(outer, 0.0))
		for stone in pebbles:
			var at := Vector2(stone.x, stone.y)
			var tone := silt.lightened(0.14 + stone.z * 0.013)
			canvas.draw_rect(Rect2(at + Vector2(1, 1), Vector2(stone.z, 2)), outer)
			canvas.draw_line(at, at + Vector2(stone.z - 1.0, 0), tone, 1.0)
			if stone.z > 3.0:
				canvas.draw_rect(Rect2(at + Vector2(1, -1), Vector2(stone.z - 2, 1)), tone.lightened(0.19))

	func draw_water(canvas: CanvasItem, water: Color, season: int, wet: bool) -> void:
		var winter := season == Global.Season.WINTER
		var deep := water.darkened(0.16)
		var shallows := water.lerp(Color("#8eaf87"), 0.40 if not wet else 0.24)
		_draw_band(canvas, shoals[0], shoals[1], deep, deep.lightened(0.045))
		_draw_band(canvas, sides[0], shoals[0], shallows, deep)
		_draw_band(canvas, sides[1], shoals[1], shallows.darkened(0.09), deep.lightened(0.045))
		var stone_tint := shallows.lerp(Color("#a2b39e"), 0.38)
		var ripple := Color("#b5c9bc") if winter else shallows.lightened(0.29)
		for stone in wet_stones:
			var at := Vector2(stone.x, stone.y)
			canvas.draw_rect(Rect2(at, Vector2(stone.z, 2.0)), Color(stone_tint, 0.43))
			canvas.draw_rect(Rect2(at + Vector2(1, 2), Vector2(stone.z - 1.0, 1.0)), Color(deep, 0.39))
			if stone.z > 3.0:
				canvas.draw_line(at + Vector2(-1, -1), at + Vector2(stone.z - 2, -1), Color(ripple, 0.55), 1.0)

	func _draw_band(canvas: CanvasItem, a: PackedVector2Array, b: PackedVector2Array, near: Color, far: Color) -> void:
		for index in a.size() - 1:
			canvas.draw_polygon(PackedVector2Array([a[index], a[index + 1], b[index + 1], b[index]]),
				PackedColorArray([near, near, far, far]))

var water_time := 0.0
var frame := 0
var water_effect_bounds := FALL_BOUNDS.merge(FORD_BOUNDS)
var rng := RandomNumberGenerator.new()

func _process(delta: float) -> void:
	water_time = fposmod(water_time + delta, 12.0)
	var next := int(water_time * 12.0)
	if next == frame:
		return
	if get_viewport_rect().intersects(get_global_transform_with_canvas() * water_effect_bounds):
		frame = next
		queue_redraw()

static func draw_banks(canvas: CanvasItem, season: int, wet: bool) -> void:
	_ledge(canvas, WEST_UPPER, -1.0, season, wet)
	_ledge(canvas, EAST_UPPER, 1.0, season, wet)
	_ledge(canvas, WEST_LOWER, -1.0, season, wet)
	_ledge(canvas, EAST_LOWER, 1.0, season, wet)
	_draw_cascade_banks(canvas, season, wet)
	_shelf_faces(canvas, RavineLayout.WILLOW_WATERLINE, WILLOW_LEDGE, 1.0, season, wet)
	_shelf_faces(canvas, RavineLayout.GRAVEL_WATERLINE, GRAVEL_LEDGE, -1.0, season, wet)

static func _draw_cascade_banks(canvas: CanvasItem, season: int, wet: bool) -> void:
	var moss: Color = MOSS[season]
	var rock := Color("#9b9575").lerp(Color("#587267"), 0.44 if wet else 0.0)
	if season == Global.Season.WINTER:
		rock = rock.lerp(Color("#a5b4aa"), 0.35)
	for bank_index in CASCADE_BANKS.size():
		var bank: Dictionary = CASCADE_BANKS[bank_index]
		var top := PackedVector2Array(bank.top)
		var foot := PackedVector2Array(bank.foot)
		for index in foot.size() - 1:
			var a := top[index]
			var b := top[index + 1]
			var base_a := foot[index]
			var base_b := foot[index + 1]
			var face := rock.darkened(0.13 + (index + bank_index) * 0.051)
			var seam_a := a.lerp(base_a, 0.46).round()
			var seam_b := b.lerp(base_b, 0.60).round()
			_gradient_quad(canvas, base_a, base_b, base_b + Vector2(4, 5), base_a + Vector2(4, 5),
				Color("#183d4794"), Color("#183d4700"))
			_gradient_quad(canvas, a, b, seam_b, seam_a, face, face.darkened(0.15))
			_gradient_quad(canvas, seam_a, seam_b, base_b, base_a, face.darkened(0.24), Color("#405852"))
			var joint := (a.lerp(b, 0.63)).round()
			var split := seam_a.lerp(seam_b, 0.40).round()
			var toe := base_a.lerp(base_b, 0.67).round()
			canvas.draw_polyline(PackedVector2Array([joint, split, toe]), face.darkened(0.28), 1.0)
			canvas.draw_line(seam_a, split, face.lightened(0.087), 1.0)
		canvas.draw_colored_polygon(top, rock.lightened(0.08 - bank_index * 0.04))
		var cap := top.slice(3)
		cap.append(top[-1].lerp(top[1], 0.37).round())
		cap.append(top[3].lerp(top[1], 0.45).round())
		var turf := moss.darkened(0.16 if wet else 0.06)
		var colors := PackedColorArray()
		for index in cap.size():
			colors.append(Color(turf, 0.36 if index == 0 or index >= cap.size() - 2 else 0.95))
		canvas.draw_polygon(cap, colors)
		var ledge := top[0].lerp(top[1], 0.38).round()
		canvas.draw_polyline(PackedVector2Array([ledge, top[1], top[1].lerp(top[2], 0.72).round()]),
			rock.lightened(0.17), 1.0)

static func draw_fishing_shelves(canvas: CanvasItem, season: int, wet: bool) -> void:
	_shelf_top(canvas, RavineLayout.WILLOW_BANK, Color("#878471"), season, wet)
	_shelf_top(canvas, RavineLayout.GRAVEL_BAR, Color("#959078"), season, wet)

static func _shelf_top(canvas: CanvasItem, outline: Array, stone: Color, season: int, wet: bool) -> void:
	var winter := season == Global.Season.WINTER
	var surface := stone.lerp(Color("#58675a"), 0.30 if wet else 0.0)
	var rim: Color = MOSS[season]
	var shelf := PackedVector2Array(outline)
	var center := Vector2.ZERO
	var bounds := Rect2(shelf[0], Vector2.ZERO)
	for point in shelf:
		center += point
		bounds = bounds.expand(point)
	center /= shelf.size()
	for index in shelf.size():
		var a := shelf[index]
		var b := shelf[(index + 1) % shelf.size()]
		var a_out := a + center.direction_to(a) * 5.0
		var b_out := b + center.direction_to(b) * 5.0
		_gradient_quad(canvas, a, b, b_out, a_out, Color(rim.darkened(0.18), 0.71), Color(rim, 0.0))
	canvas.draw_colored_polygon(shelf, surface)
	for index in shelf.size():
		var a := shelf[index]
		var b := shelf[(index + 1) % shelf.size()]
		var tone := surface.lightened(0.045 + posmod(index * 3, 5) * 0.023)
		_quad(canvas, a, b, b.lerp(center, 0.26), a.lerp(center, 0.26), tone)
		if index % 4 != 1:
			canvas.draw_line(a.lerp(b, 0.11).round(), a.lerp(b, 0.65).round(), Color(rim, 0.82), 1.0)
	# Small gravel clusters sit flush with the bank and stay below the path markings.
	var rng := RandomNumberGenerator.new()
	rng.seed = 253
	for index in 112:
		var at := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y)).round()
		if not Geometry2D.is_point_in_polygon(at + Vector2(4, 2), shelf) or not Geometry2D.is_point_in_polygon(at, shelf):
			continue
		var width := rng.randi_range(2, 5)
		if index % 5 == 0:
			canvas.draw_rect(Rect2(at, Vector2(width, 1)), rim.lightened(0.10 if winter else 0.03))
		else:
			canvas.draw_rect(Rect2(at + Vector2(1, 1), Vector2(width, 1)), surface.darkened(0.13))
			canvas.draw_rect(Rect2(at, Vector2(width, 1)), surface.lightened(0.15 if index % 3 == 0 else 0.10))

static func _shelf_faces(canvas: CanvasItem, waterline: Array, heights: Array, inward: float, season: int, wet: bool) -> void:
	var winter := season == Global.Season.WINTER
	var rim: Color = MOSS[season]
	var stone := Color("#777661") if inward > 0.0 else Color("#918a73")
	stone = stone.lerp(Color("#506561"), 0.35 if wet else 0.0)
	for index in waterline.size() - 1:
		var a: Vector2 = waterline[index]
		var b: Vector2 = waterline[index + 1]
		var foot_a := (a + Vector2(inward * (1.0 + heights[index] * 0.36), heights[index])).round()
		var foot_b := (b + Vector2(inward * (1.0 + heights[index + 1] * 0.36), heights[index + 1])).round()
		var shadow := Vector2(inward * 4.0, 4.0)
		_gradient_quad(canvas, foot_a, foot_b, foot_b + shadow, foot_a + shadow, Color("#263e438c"), Color("#263e4300"))
		var seam_a := a.lerp(foot_a, 0.51).round()
		var seam_b := b.lerp(foot_b, 0.54).round()
		var face := stone.lightened(0.025 * posmod(index * 3, 5))
		_quad(canvas, seam_a, seam_b, foot_b, foot_a, face.lerp(Color("#384f48"), 0.49))
		_quad(canvas, a, b, seam_b, seam_a, face)
		var joint := a.lerp(b, 0.47 + (index % 3) * 0.1).round()
		var split := seam_a.lerp(seam_b, 0.54 + (index % 3) * 0.1).round()
		_quad(canvas, joint, b, seam_b, split, Color(face.darkened(0.22), 0.65))
		if winter:
			canvas.draw_line(a.lerp(b, 0.15).round(), joint, rim.lightened(0.20), 2.0)
		if index % 3 != 2:
			canvas.draw_line(a, joint, rim.lightened(0.19 if winter else 0.11), 1.0)
			canvas.draw_line(foot_a.lerp(foot_b, 0.1).round(), foot_a.lerp(foot_b, 0.62).round(), Color("#9dbdb189"), 1.0)

static func draw_ford(canvas: CanvasItem, shoal: PackedVector2Array, water: Color, season: int, wet: bool) -> void:
	var center := RavineLayout.FORD
	var shallow := water.lerp(Color("#92ae98"), 0.38 if wet else 0.54)
	var shoal_colors := PackedColorArray()
	for vertex in shoal:
		var fade := 1.0 - 0.50 * smoothstep(4.0, 17.0, absf(vertex.y - center.y))
		shoal_colors.append(Color(shallow, fade))
	canvas.draw_polygon(shoal, shoal_colors)
	var stone := Color("#96917a").lerp(Color("#668179"), 0.40 if wet else 0.0)
	var lit := Color("#bcba9e") if season == Global.Season.WINTER else stone.lightened(0.23)
	for index in FORD_STONES.size():
		var step := FORD_STONES[index]
		var at := center + Vector2(step.x, step.y)
		var width := step.z
		var top := PackedVector2Array([at + Vector2(-width, -2), at + Vector2(-width + 2, -5 - index % 2),
			at + Vector2(width - 2, -5), at + Vector2(width, -2 + index % 2), at + Vector2(width - 1, 1),
			at + Vector2(0, 3), at + Vector2(-width + 1, 1)])
		var shadow := Transform2D(0.0, Vector2(1, 4)) * top
		canvas.draw_colored_polygon(shadow, Color("#304f527d"))
		canvas.draw_line(at + Vector2(-width - 1, 5), at + Vector2(-1, 6), Color("#aac9b48f"), 1.0)
		var drop := Vector2(0, 3 + index % 2)
		_quad(canvas, top[3], top[4], top[4] + drop, top[3] + drop, stone.darkened(0.40))
		_quad(canvas, top[4], top[5], top[5] + drop, top[4] + drop, stone.darkened(0.23))
		_quad(canvas, top[5], top[6], top[6] + drop, top[5] + drop, stone.darkened(0.16))
		canvas.draw_colored_polygon(top, stone.lightened(0.04 * (index % 3)))
		canvas.draw_polyline(PackedVector2Array([top[0], top[1], top[1].lerp(top[2], 0.72)]), lit, 1.0)
		canvas.draw_rect(Rect2(at + Vector2(0, -2), Vector2(2 + index % 3, 1)), stone.darkened(0.14))

func _draw() -> void:
	var wet := Global.has_rain()
	var water := Color("#4d898f") if wet else Color("#579ea3")
	var foam := Color("#b5dcd4") if wet else Color("#d5ede0")
	_draw_ford_ripples(Color(foam, 0.27 if wet else 0.51))
	var pool := PackedVector2Array(PLUNGE_POOL)
	var pool_colors := PackedColorArray()
	for point in pool:
		pool_colors.append(Color(water.lerp(Color("#274d59"), 0.72), 0.72 * (1.0 - smoothstep(-38.0, -10.0, point.y))))
	draw_polygon(pool, pool_colors)
	# Each tongue has a lit crest, a tinted face and a broken fan at the point of impact.
	rng.seed = 78
	for index in CASCADE_LIP.size() - 1:
		var lip := CASCADE_LIP[index]
		var next_lip := CASCADE_LIP[index + 1]
		var foot := CASCADE_BASE[index]
		var next_foot := CASCADE_BASE[index + 1]
		var face := water.lightened(0.07 + 0.045 * (index % 3))
		var upstream := Vector2(-1, -16 - index % 3)
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
		var spray := impact + Vector2(float(posmod(frame + index * 5, 5)) - 2.0, -float(posmod(frame + index * 3, 7)))
		draw_rect(Rect2(spray, Vector2(2, 1)), Color(foam, 0.54))
		var broken_edge := (impact + Vector2(-2, float(posmod(frame + index * 2, 4)))).round()
		draw_rect(Rect2(broken_edge, Vector2(4 + index % 2, 2)), Color(foam, 0.75))
		draw_rect(Rect2(broken_edge + Vector2(2, 3), Vector2(3, 1)), Color(foam, 0.55))
	_draw_pool_wakes(foam)

func _draw_pool_wakes(foam: Color) -> void:
	for index in 3:
		var phase := float(posmod(frame + index * 8, 24)) / 24.0
		var center := (Vector2(135, -38) + Vector2(5, 24) * phase).round()
		var span := 5.0 + phase * 8.0
		var front := (center + Vector2(0, 1.0 + phase * 4.0)).round()
		var left := (center - Vector2(span, 0)).round()
		var right := (center + Vector2(span, 0)).round()
		var white := Color(foam, lerpf(0.73, 0.0, phase))
		draw_polyline(PackedVector2Array([left, left.lerp(front, 0.48).round(), front + Vector2(-2, 0)]), white, 1.0)
		draw_polyline(PackedVector2Array([front + Vector2(1, 0), front.lerp(right, 0.55).round(), right]), white, 1.0)

func _draw_ford_ripples(foam: Color) -> void:
	for index in FORD_RIPPLES.size():
		var phase := float(posmod(frame + index * 7, 18)) / 18.0
		var at: Vector2 = RavineLayout.FORD + FORD_RIPPLES[index] + Vector2(3.0, 9.0) * phase
		var width := 3.0 + phase * 4.0
		var ripple := Color(foam, foam.a * (1.0 - phase))
		draw_rect(Rect2(at.round(), Vector2(width, 1)), ripple)
		draw_rect(Rect2(at.round() + Vector2(1, 2), Vector2(width - 2.0, 1)), Color(ripple, ripple.a * 0.62))

static func _ledge(canvas: CanvasItem, profile: Array[Vector3], side: float, season: int, wet: bool) -> void:
	var winter := season == Global.Season.WINTER
	var moss: Color = MOSS[season]
	var turf := moss.lerp(Color("#486543"), 0.28 if not winter else 0.14).darkened(0.10 if wet else 0.0)
	var stone := Color("#918975") if side > 0.0 else Color("#7b7969")
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
		var bank_a := rim_a.lerp(back_a, 0.34 + (index % 4) * 0.065).round()
		var bank_b := rim_b.lerp(back_b, 0.34 + ((index + 1) % 4) * 0.065).round()
		var seam_a := rim_a.lerp(toe_a, 0.47 + (index % 3) * 0.08).round()
		var seam_b := rim_b.lerp(toe_b, 0.47 + ((index + 1) % 3) * 0.08).round()
		var face := stone.lightened(0.03 * posmod(index * 3, 5))
		var undercut := face.lerp(Color("#263d38"), 0.44)
		var shadow_a := toe_a + Vector2(-side * a.z * 0.24, a.z * 0.14).round()
		var shadow_b := toe_b + Vector2(-side * b.z * 0.24, b.z * 0.14).round()
		_gradient_quad(canvas, toe_a, toe_b, shadow_b, shadow_a, Color("#183d47b5"), Color("#183d4730"))
		var outer := Color(turf.darkened(0.15), 0.0)
		var inner := Color(turf, 0.76 if winter else 0.70)
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
			if not winter and index % 4 != 0:
				var grass_tip := root + Vector2(side * 5.0, -7 - index % 3)
				canvas.draw_line(root + Vector2(side * 2, -1), grass_tip, moss.lightened(0.14), 1.0)
				canvas.draw_line(root + Vector2(side * 3, -1), grass_tip + Vector2(side * 3, 3), turf.darkened(0.11), 1.0)
			var fracture := cut.lerp(crack, 0.62).round()
			canvas.draw_polyline(PackedVector2Array([fracture, seam_b.lerp(fracture, 0.69).round(),
				(seam_b + Vector2(side * 2, 2)).round()]), face.darkened(0.16), 1.0)

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
