extends RefCounted

const LOAM := preload("res://assets/world/ninja-adventure/estate-loam.png")
const VERGE := preload("res://assets/world/ninja-adventure/estate-verge.png")
const TUFT_SIZE := Vector2(16, 16)
const RIDGE_PROFILE := [
	Vector2(-540, -13), Vector2(-430, -16), Vector2(-368, -21), Vector2(-334, -25),
	Vector2(-305, -24), Vector2(-288, -32), Vector2(-259, -34), Vector2(-221, -31),
	Vector2(-195, -23), Vector2(-168, -22), Vector2(-139, -25), Vector2(-106, -19),
	Vector2(-74, -15), Vector2(-49, -17), Vector2(-14, -24), Vector2(25, -28),
	Vector2(54, -26), Vector2(72, -34), Vector2(109, -36), Vector2(143, -28),
	Vector2(169, -27), Vector2(197, -18), Vector2(232, -16), Vector2(262, -18),
	Vector2(290, -23), Vector2(329, -22), Vector2(359, -27), Vector2(382, -32),
	Vector2(417, -30), Vector2(451, -23), Vector2(488, -21), Vector2(545, -15),
	Vector2(616, -18), Vector2(722, -11),
]
const MEADOW_PATCHES := [
	Rect2(-287, 58, 105, 75), Rect2(-222, 138, 93, 64), Rect2(-170, 221, 108, 75),
	Rect2(-171, -151, 151, 69), Rect2(59, -165, 129, 68), Rect2(223, -119, 106, 64),
	Rect2(257, 68, 93, 57), Rect2(259, 247, 119, 74), Rect2(83, 181, 79, 41),
	Rect2(-128, 292, 107, 54), Rect2(69, 290, 97, 69), Rect2(177, 397, 103, 86),
	Rect2(-308, 513, 132, 58), Rect2(-309, 670, 111, 54), Rect2(-107, 664, 134, 61),
	Rect2(82, 581, 106, 99), Rect2(204, 624, 77, 58), Rect2(386, 657, 116, 60),
]

var crest := PackedVector2Array()
var north_edge: float
var meadow_sprigs := PackedVector2Array()

func _init(north: float) -> void:
	north_edge = north
	for point: Vector2 in RIDGE_PROFILE:
		crest.append(point + Vector2(0, north_edge))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6793
	for patch: Rect2 in MEADOW_PATCHES:
		for index in 9:
			var offset := Vector2(rng.randf(), rng.randf()) * patch.size
			meadow_sprigs.append((patch.position + offset).round())

func draw_north_bank(canvas: CanvasItem, background_top: float, shade: Color, sun: Color, winter: bool) -> void:
	var slope := crest.duplicate()
	slope.append(Vector2(crest[-1].x, background_top))
	slope.append(Vector2(crest[0].x, background_top))
	canvas.draw_colored_polygon(slope, shade.darkened(0.15))
	var stone := Color("#656a60").lerp(shade, 0.46)
	var lip := Color("#9eae9f") if winter else sun.lightened(0.09)
	for index in crest.size() - 1:
		var left := crest[index]
		var right := crest[index + 1]
		var base_left := Vector2(left.x, north_edge + float(index % 3))
		var base_right := Vector2(right.x, north_edge + float((index + 1) % 3))
		var shade_edge := Vector2(0, 4 if index % 3 == 0 else 2)
		_quad(canvas, base_left, base_right, base_right + shade_edge, base_left + shade_edge, shade)
		var seam_left := left.lerp(base_left, 0.45 + float(index % 4) * 0.04).round()
		var seam_right := right.lerp(base_right, 0.45 + float((index + 1) % 4) * 0.04).round()
		var facet := stone.lightened(0.07) if index % 3 == 0 else stone
		_quad(canvas, left, right, seam_right, seam_left, facet)
		_quad(canvas, seam_left, seam_right, base_right, base_left, facet.darkened(0.18))
		var seam_break := seam_left.lerp(seam_right, 0.43).round()
		var lower_break := base_left.lerp(base_right, 0.31).round()
		_quad(canvas, seam_break, seam_right, base_right, lower_break, facet.darkened(0.26))
		canvas.draw_line(seam_break, lower_break, facet.darkened(0.34), 1.0)
		var chip := seam_left.lerp(seam_right, 0.27).round()
		canvas.draw_rect(Rect2(chip - Vector2(2, 3), Vector2(4 + index % 5, 2)), facet.lightened(0.09))
		canvas.draw_rect(Rect2(chip + Vector2(3, 4), Vector2(3 + index % 3, 1)), facet.darkened(0.32))
		var moss_edge := Vector2(0, 2 + index % 4)
		_quad(canvas, left, right, right + moss_edge, left + moss_edge, lip.lerp(shade, 0.22 + (index % 3) * 0.17))

func _quad(canvas: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([a, b, c, d]), color)

static func draw_loam(canvas: CanvasItem, polygon: PackedVector2Array, soil: Color) -> void:
	var uvs := PackedVector2Array()
	var size := LOAM.get_size()
	for point in polygon:
		uvs.append(point / size)
	canvas.draw_polygon(polygon, PackedColorArray([soil]), uvs, LOAM)

func draw_meadow(canvas: CanvasItem, grass: Color, winter: bool) -> void:
	for index in meadow_sprigs.size():
		if winter and index % 3 != 0:
			continue
		var ink := grass.lightened(0.17) if index % 3 == 0 else grass.darkened(0.12)
		_stamp(canvas, meadow_sprigs[index], index, Color(ink, 0.59 if winter else 0.76))

func draw_verge(canvas: CanvasItem, points: PackedVector2Array, width: float, grass: Color, winter: bool) -> void:
	for index in range(3, points.size() - 2, 5):
		if winter and index % 3 != 0:
			continue
		var normal := points[index - 1].direction_to(points[index + 1]).orthogonal()
		var side := 1.0 if index % 2 == 0 else -1.0
		var at := points[index] + normal * side * (width * 0.5 + 5.0 + float(index % 4))
		_stamp(canvas, at.round(), index, Color(grass.lerp(Color("#89965f"), 0.42), 0.74))

func _stamp(canvas: CanvasItem, at: Vector2, index: int, color: Color) -> void:
	var source := Rect2(Vector2((index % 4) * 16, 0), TUFT_SIZE)
	canvas.draw_texture_rect_region(VERGE, Rect2(at - TUFT_SIZE * 0.5, TUFT_SIZE), source, color)
