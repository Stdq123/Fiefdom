extends RefCounted

const ESTATE_GROVES := [
	Rect2(-388, -154, 288, 152), Rect2(-168, -119, 285, 127), Rect2(129, -133, 256, 131),
	Rect2(330, -117, 201, 180), Rect2(-291, 97, 219, 168), Rect2(230, 182, 288, 136),
	Rect2(-374, 290, 218, 123), Rect2(63, 385, 143, 133), Rect2(218, 445, 107, 85),
	Rect2(-360, 480, 292, 145), Rect2(312, 499, 243, 130),
]
const RAVINE_GROVES := [
	Rect2(-528, -204, 255, 341), Rect2(-362, -253, 222, 219), Rect2(-201, -209, 176, 148),
	Rect2(-412, 73, 320, 186), Rect2(-106, 166, 295, 196), Rect2(4, -259, 151, 177),
	Rect2(185, -247, 164, 238), Rect2(319, -206, 270, 165), Rect2(349, 32, 230, 228),
	Rect2(327, 249, 243, 201),
]
const ESTATE_CLEARINGS := [
	Rect2(-158, 56, 332, 198), Rect2(87, 139, 335, 190),
	Rect2(-302, 366, 164, 148), Rect2(295, 376, 181, 126),
]
const RAVINE_CLEARINGS := [
	Rect2(-415, -16, 252, 99), Rect2(-230, -150, 126, 97), Rect2(-103, 61, 258, 114),
	Rect2(89, -226, 90, 118), Rect2(276, -131, 252, 173), Rect2(198, 157, 160, 143),
]
const ESTATE_DRIFTS := [
	Rect2(-272, -74, 147, 60), Rect2(-169, 58, 105, 57), Rect2(58, -87, 244, 57),
	Rect2(121, 166, 207, 72), Rect2(-117, 177, 157, 88), Rect2(286, 31, 189, 88),
	Rect2(58, 258, 161, 72), Rect2(316, 228, 153, 62),
	Rect2(-310, 466, 110, 51), Rect2(76, 423, 124, 81), Rect2(376, 467, 112, 63),
]
const RAVINE_DRIFTS := [
	Rect2(-367, -53, 125, 70), Rect2(-277, 63, 133, 68), Rect2(-219, -169, 119, 87),
	Rect2(55, -224, 117, 95), Rect2(193, -129, 138, 75), Rect2(366, -127, 143, 91),
	Rect2(-95, 138, 141, 84), Rect2(173, 202, 80, 68), Rect2(271, 232, 115, 66),
]
const PROFILE := [
	Vector2(-1.0, -0.12), Vector2(-0.94, -0.42), Vector2(-0.79, -0.42), Vector2(-0.74, -0.66),
	Vector2(-0.50, -0.72), Vector2(-0.43, -0.89), Vector2(-0.12, -0.95), Vector2(0.20, -1.0),
	Vector2(0.37, -0.82), Vector2(0.63, -0.77), Vector2(0.71, -0.62), Vector2(0.83, -0.58),
	Vector2(0.95, -0.33), Vector2(1.0, -0.03), Vector2(0.91, 0.19), Vector2(0.93, 0.37),
	Vector2(0.76, 0.40), Vector2(0.66, 0.67), Vector2(0.38, 0.75), Vector2(0.28, 0.9),
	Vector2(-0.03, 0.96), Vector2(-0.36, 1.0), Vector2(-0.56, 0.83), Vector2(-0.65, 0.64),
	Vector2(-0.83, 0.59), Vector2(-0.84, 0.35), Vector2(-0.97, 0.23),
]

var shade: Array[PackedVector2Array] = []
var sun: Array[PackedVector2Array] = []
var drifts: Array[PackedVector2Array] = []
var drift_edges: Array[PackedVector2Array] = []
var ground_marks: PackedVector2Array
var frost_marks: PackedVector2Array
var snow_flecks: PackedVector2Array

func _init(wilderness: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 69732 if wilderness else 12765
	var groves := RAVINE_GROVES if wilderness else ESTATE_GROVES
	for patch: Rect2 in groves:
		var outline := _outline(patch, rng)
		shade.append(outline)
		_scatter(ground_marks, patch, outline, rng, 23)
	for patch: Rect2 in (RAVINE_CLEARINGS if wilderness else ESTATE_CLEARINGS):
		sun.append(_outline(patch, rng))
	for patch: Rect2 in (RAVINE_DRIFTS if wilderness else ESTATE_DRIFTS):
		var outline := _outline(patch, rng)
		drifts.append(outline)
		drift_edges.append(_outline(patch.grow(4), rng))
		_scatter(frost_marks, patch, outline, rng, 25)
		for index in range(0, outline.size(), 2):
			var edge := patch.get_center().lerp(outline[index], rng.randf_range(0.89, 1.13))
			snow_flecks.append(edge.round())

func _outline(patch: Rect2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point: Vector2 in PROFILE:
		var scale := rng.randf_range(0.93, 1.07)
		points.append((patch.get_center() + point * patch.size * 0.5 * scale).snapped(Vector2(2, 2)))
	return points

func _scatter(marks: PackedVector2Array, patch: Rect2, outline: PackedVector2Array, rng: RandomNumberGenerator, count: int) -> void:
	for index in count:
		var point := (patch.position + Vector2(rng.randf(), rng.randf()) * patch.size).round()
		if Geometry2D.is_point_in_polygon(point, outline):
			marks.append(point)

func has_snow(point: Vector2) -> bool:
	for outline in drifts:
		if Geometry2D.is_point_in_polygon(point, outline):
			return true
	return false

func draw_cover(canvas: CanvasItem, shade_color: Color, sun_color: Color, winter: bool) -> void:
	for patch in shade:
		canvas.draw_colored_polygon(patch, Color(shade_color, 0.43))
	for patch in sun:
		canvas.draw_colored_polygon(patch, Color(sun_color, 0.40))
	if winter:
		for patch in drift_edges:
			canvas.draw_colored_polygon(patch, Color("#8faaa075"))
		for patch in drifts:
			canvas.draw_colored_polygon(patch, Color("#b2c3b8"))

func draw_marks(canvas: CanvasItem, season: int, raining: bool) -> void:
	if season == Global.Season.WINTER:
		for index in frost_marks.size():
			var point := frost_marks[index]
			var tone := Color("#c9d5c9") if index % 3 == 0 else Color("#9bafa6")
			canvas.draw_rect(Rect2(point, Vector2(3 + index % 5, 1)), tone)
		for index in snow_flecks.size():
			var point := snow_flecks[index]
			var width := 2 + index % 5
			canvas.draw_rect(Rect2(point, Vector2(width, 2)), Color("#adbfaf94"))
			if index % 3 == 0:
				canvas.draw_rect(Rect2(point + Vector2(2, -2), Vector2(width - 1, 1)), Color("#ccd7c4a3"))
		return
	for index in ground_marks.size():
		var point := ground_marks[index]
		match season:
			Global.Season.SPRING:
				if index % 3 == 0:
					canvas.draw_rect(Rect2(point, Vector2(2, 1)), Color("#c4a08e") if not raining else Color("#a59a86"))
			Global.Season.SUMMER:
				canvas.draw_rect(Rect2(point, Vector2(1, 4)), Color("#83905d"))
				canvas.draw_rect(Rect2(point + Vector2(2, 1), Vector2(1, 3)), Color("#627e55"))
			Global.Season.AUTUMN:
				var tone := Color("#b3824e") if index % 3 == 0 else Color("#8f6543")
				canvas.draw_rect(Rect2(point, Vector2(3, 1)), tone)
				canvas.draw_rect(Rect2(point + Vector2(1, 1), Vector2(2, 1)), tone.darkened(0.11))
