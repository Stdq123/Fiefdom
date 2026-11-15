extends RefCounted

const LOAM := preload("res://assets/world/ninja-adventure/estate-loam.png")
const VERGE := preload("res://assets/world/ninja-adventure/estate-verge.png")
const TUFT_SIZE := Vector2(16, 16)
const POND_CENTER := Vector2(258, 705)
const POND_FAR_BANK := [4, 9, 13, 9, 15, 12, 6, 3]
const POND_WEST_FACE := [Vector2(1, -2), Vector2(3, -3), Vector2(5, -2), Vector2(6, 2), Vector2(5, 2)]
const SUBMERGED_STONES := [Vector3(218, 679, 10), Vector3(244, 677, 7), Vector3(292, 665, 13),
	Vector3(316, 681, 8), Vector3(323, 723, 9), Vector3(307, 737, 5), Vector3(263, 751, 12), Vector3(223, 750, 8)]
const LILY_PADS := [Vector2(299, 682), Vector2(305, 688), Vector2(311, 682), Vector2(318, 703),
	Vector2(206, 730), Vector2(211, 738)]
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
	Rect2(127, 739, 80, 64), Rect2(260, 795, 149, 71), Rect2(385, 899, 111, 65),
]
const FARM_YARD := [
	Vector2(10, 78), Vector2(28, 67), Vector2(52, 69), Vector2(81, 64), Vector2(115, 62),
	Vector2(150, 74), Vector2(169, 93), Vector2(167, 118), Vector2(151, 139), Vector2(129, 154),
	Vector2(101, 158), Vector2(72, 152), Vector2(46, 143), Vector2(29, 129), Vector2(15, 109),
]
const HALL_COURT := [
	Vector2(-61, 21), Vector2(-42, 23), Vector2(-16, 22), Vector2(12, 18), Vector2(30, 17),
	Vector2(45, 24), Vector2(54, 31), Vector2(46, 40), Vector2(32, 45), Vector2(18, 49),
	Vector2(10, 55), Vector2(-8, 57), Vector2(-26, 55), Vector2(-44, 52), Vector2(-57, 46),
	Vector2(-65, 41), Vector2(-68, 32),
]
const SPRING_APRON := [
	Vector2(-28, -2), Vector2(-24, -7), Vector2(-17, -8), Vector2(-8, -14), Vector2(6, -15),
	Vector2(17, -11), Vector2(21, -6), Vector2(19, 1), Vector2(22, 7), Vector2(15, 13),
	Vector2(9, 17), Vector2(-2, 18), Vector2(-14, 16), Vector2(-24, 13), Vector2(-27, 9), Vector2(-32, 6),
]
const SPRING_FLAGSTONES := [
	[Vector2(-30, 5), Vector2(-25, -3), Vector2(-18, -5), Vector2(-11, -1), Vector2(-10, 5),
		Vector2(-17, 8), Vector2(-25, 8)],
	[Vector2(-16, -8), Vector2(-8, -12), Vector2(0, -13), Vector2(3, -6), Vector2(-4, -4), Vector2(-11, -5)],
	[Vector2(2, -13), Vector2(8, -13), Vector2(16, -10), Vector2(14, -5), Vector2(6, -4)],
	[Vector2(17, -9), Vector2(20, -5), Vector2(18, 1), Vector2(20, 5), Vector2(13, 5), Vector2(12, 0)],
	[Vector2(-24, 10), Vector2(-14, 9), Vector2(-5, 10), Vector2(-6, 16), Vector2(-15, 14), Vector2(-22, 12)],
	[Vector2(-3, 10), Vector2(4, 9), Vector2(10, 12), Vector2(10, 16), Vector2(0, 17), Vector2(-4, 14)],
	[Vector2(5, 7), Vector2(13, 8), Vector2(19, 8), Vector2(16, 11), Vector2(11, 14), Vector2(10, 10)],
]
var crest := PackedVector2Array()
var north_edge: float
var meadow_sprigs := PackedVector2Array()
var pond := PackedVector2Array(EstateLayout.FESTIVAL_POND)
var pond_bank := Geometry2D.offset_polygon(pond, 8.0)[0]
var pond_waterline := pond.duplicate()
var _pond_shelf := PackedVector2Array()
var _pond_basin := PackedVector2Array()
var pond_paving := PackedVector2Array(EstateLayout.FESTIVAL_PAVING)
var _paving_margin := Geometry2D.offset_polygon(pond_paving, 5.0)[0]
var _paving_entrance := EstateLayout.FESTIVAL_LANE[-4]
var _paving_flagstones: Array[Dictionary] = []
var _hall_paving := PackedVector2Array(HALL_COURT)
var _hall_flagstones: Array[Dictionary] = []
var _spring_paving := PackedVector2Array(SPRING_APRON)

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
	for index in POND_FAR_BANK.size():
		pond_waterline[index].y += POND_FAR_BANK[index]
	_pond_shelf = _inset_pool(pond_waterline, Vector2(0.89, 0.85), Vector2(0, 0))
	_pond_basin = _inset_pool(pond_waterline, Vector2(0.74, 0.72), Vector2(9, 3))
	_paving_flagstones = _bake_flagstones(pond_paving)
	_hall_flagstones = _bake_flagstones(_hall_paving)

static func _bake_flagstones(outline: PackedVector2Array) -> Array[Dictionary]:
	var flagstones: Array[Dictionary] = []
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	for row in range(floori(bounds.position.y / 14.0), ceili(bounds.end.y / 14.0)):
		for column in range(floori(bounds.position.x / 23.0) - 1, ceili(bounds.end.x / 23.0)):
			var grain := posmod(column * 7 + row * 17, 13)
			var x := column * 23.0 + posmod(row, 2) * 12.0 + grain % 3 - 1
			var y := row * 14.0 + grain % 2
			var west := float(grain % 4)
			var east := float(20 + grain % 3)
			var stone := PackedVector2Array([Vector2(x, y + 3), Vector2(x + west + 1, y + 1),
				Vector2(x + east - 3, y), Vector2(x + east, y + 3 + grain % 2), Vector2(x + east - 1, y + 10),
				Vector2(x + east - 4, y + 11 + grain % 2), Vector2(x + west, y + 12)])
			for piece in Geometry2D.intersect_polygons(stone, outline):
				if not Geometry2D.triangulate_polygon(piece).is_empty():
					flagstones.append({"points": piece, "shade": grain, "grain": Vector2(x + 5, y + 4)})
	return flagstones

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

func draw_farm_yard(canvas: CanvasItem, grass: Color, winter: bool, wet: bool) -> void:
	var center := Vector2(84, 109)
	var tint := grass.lerp(Color("#738354") if not winter else Color("#a3b0a1"), 0.48)
	var colors := PackedColorArray([Color(tint, 0.56 if not wet else 0.31), Color(tint, 0.0), Color(tint, 0.0)])
	for index in FARM_YARD.size():
		canvas.draw_polygon(PackedVector2Array([center, FARM_YARD[index], FARM_YARD[(index + 1) % FARM_YARD.size()]]), colors)
	for index: int in [1, 3, 8, 11, 13]:
		var at: Vector2 = FARM_YARD[index].lerp(center, 0.20).round()
		_stamp(canvas, at, index, Color(tint.lightened(0.18), 0.65))

func hall_stone_at(foot: Vector2) -> bool:
	return EstateLayout.HALL_LANDING.has_point(foot) or Geometry2D.is_point_in_polygon(foot, _hall_paving)

func spring_stone_at(foot_from_source: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(foot_from_source, _spring_paving)

func draw_hall_court(canvas: CanvasItem, dirt: Color, winter: bool, wet: bool) -> void:
	var stone := Color("#a69d81").lerp(Color("#6e7970"), 0.41 if wet else 0.0)
	var grout := dirt.lerp(stone.darkened(0.23), 0.76)
	var frost := Color("#c0c9b4")
	var fall := Vector2(2, 3)
	# The curbs end on either side of the worn opening into the south road.
	for index: int in [5, 6, 7, 8, 12, 13, 14, 15]:
		var a := _hall_paving[index]
		var b := _hall_paving[index + 1]
		var edge_a := a.lerp(b, 0.05).round()
		var edge_b := a.lerp(b, 0.87).round()
		_quad(canvas, edge_a, edge_b, edge_b + fall, edge_a + fall, grout.darkened(0.22))
		canvas.draw_line(edge_a, edge_a.lerp(edge_b, 0.72), (frost if winter else stone).darkened(0.11), 1.0)
	canvas.draw_colored_polygon(_hall_paving, grout)
	_draw_flagstones(canvas, _hall_flagstones, grout, stone.lightened(0.055), winter)
	_draw_hall_steps(canvas, stone.lightened(0.08), winter)
	for at: Vector2 in [Vector2(-55, 49), Vector2(-43, 55), Vector2(-32, 55), Vector2(-8, 59),
		Vector2(8, 59), Vector2(21, 53), Vector2(41, 44), Vector2(52, 38)]:
		canvas.draw_rect(Rect2(at, Vector2(3, 1)), stone.lerp(dirt, 0.25))

static func _draw_hall_steps(canvas: CanvasItem, stone: Color, winter: bool) -> void:
	var at := EstateLayout.HALL_LANDING.position
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(1, 11), at + Vector2(43, 11),
		at + Vector2(48, 16), at + Vector2(43, 18), at + Vector2(2, 18), at + Vector2(-2, 15)]),
		Color("#3b3d2fa6"))
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(4, 0), at + Vector2(39, 0),
		at + Vector2(44, 9), at + Vector2(44, 14), at + Vector2(42, 16), at + Vector2(2, 16),
		at + Vector2(0, 14), at + Vector2(0, 8)]), stone.darkened(0.32))
	for step in 2:
		var from := at + Vector2(4 - step * 3, 2 + step * 6)
		var width := 36 + step * 6
		canvas.draw_rect(Rect2(from, Vector2(width, 6)), stone.darkened(0.06 * step))
		canvas.draw_rect(Rect2(from + Vector2(0, 4), Vector2(width, 2)), stone.darkened(0.23 + step * 0.05))
		canvas.draw_rect(Rect2(from + Vector2(1, 3), Vector2(width - 3, 1)), stone.lightened(0.20))
		for joint: float in [11.0 + step * 4, 25.0 + step * 3]:
			canvas.draw_rect(Rect2(from + Vector2(joint, 0), Vector2(1, 5)), stone.darkened(0.28))
		canvas.draw_rect(Rect2(from + Vector2(width - 2, 1), Vector2(2, 3)), stone.darkened(0.20))
	if winter:
		canvas.draw_rect(Rect2(at + Vector2(1, 11), Vector2(7, 1)), Color("#c4cdba"))
		canvas.draw_rect(Rect2(at + Vector2(37, 10), Vector2(5, 1)), Color("#c4cdba"))

func draw_spring_apron(canvas: CanvasItem, at: Vector2, dirt: Color, winter: bool, wet: bool) -> void:
	var pose := Transform2D(0.0, at)
	var stone := Color("#999888").lerp(Color("#637a6e"), 0.42 if wet else 0.12)
	var grout := dirt.lerp(stone.darkened(0.24), 0.78)
	var top := pose * _spring_paving
	var face := Transform2D(0.0, Vector2(2, 2)) * top
	canvas.draw_colored_polygon(face, grout.darkened(0.22))
	canvas.draw_colored_polygon(top, grout)
	for index in SPRING_FLAGSTONES.size():
		var slab := pose * PackedVector2Array(SPRING_FLAGSTONES[index])
		var tone := stone.lightened(0.04 + index % 3 * 0.07)
		canvas.draw_colored_polygon(slab, tone)
		var edge := tone.lerp(Color("#c0c9b4"), 0.68 if winter else 0.45)
		canvas.draw_line(slab[0].lerp(slab[1], 0.18), slab[0].lerp(slab[1], 0.81), edge, 1.0)
		var worn := slab[0].lerp(slab[3], 0.53).round()
		canvas.draw_line(worn, worn + Vector2(3, 1), tone.darkened(0.16), 1.0)
	# The two low approach chips sit flush in the lane edge.
	canvas.draw_rect(Rect2(at + Vector2(-32, 2), Vector2(3, 1)), dirt.lerp(stone, 0.50))
	canvas.draw_rect(Rect2(at + Vector2(-34, 8), Vector2(4, 2)), dirt.lerp(stone, 0.64))

func draw_pond(canvas: CanvasItem, grass: Color, water: Color, winter: bool, raining: bool, has_dock: bool) -> void:
	var silt := grass.lerp(Color("#9f9371"), 0.46)
	var shallow := water.lerp(Color("#98ae8f"), 0.39 if winter else 0.49)
	var deep := water.lerp(Color("#23464d"), 0.56)
	canvas.draw_colored_polygon(pond_bank, silt)
	# At the north bank, the foot of the rock sits below its grass edge in the image.
	canvas.draw_colored_polygon(pond_waterline, shallow)
	canvas.draw_colored_polygon(_pond_shelf, shallow.lerp(water, 0.43))
	var basin_colors := PackedColorArray()
	for point in _pond_basin:
		basin_colors.append(deep.lerp(water, clampf((point.y - 687.0) * 0.016, 0.0, 0.67)))
	canvas.draw_polygon(_pond_basin, basin_colors)
	_draw_pond_faces(canvas, pond, pond_waterline, POND_FAR_BANK.size() - 1, winter, raining)
	var west := PackedVector2Array()
	var feet := PackedVector2Array()
	for index in POND_WEST_FACE.size():
		var at := pond[pond.size() - POND_WEST_FACE.size() + index]
		west.append(at)
		feet.append(at + POND_WEST_FACE[index])
	_draw_pond_faces(canvas, west, feet, west.size() - 1, winter, raining)
	_draw_pond_gravel(canvas, silt, shallow, winter, has_dock)
	_draw_pond_details(canvas, shallow, winter)

func _inset_pool(outline: PackedVector2Array, scale: Vector2, shift: Vector2) -> PackedVector2Array:
	var inset := PackedVector2Array()
	for index in outline.size():
		var point := outline[index]
		var irregularity := Vector2(posmod(index * 7, 6) - 3, posmod(index * 3, 8) - 4)
		inset.append((POND_CENTER + (point - POND_CENTER) * scale + shift + irregularity).round())
	return inset

func _draw_pond_faces(canvas: CanvasItem, lip: PackedVector2Array, feet: PackedVector2Array,
		sections: int, winter: bool, raining: bool) -> void:
	var rock := Color("#7d7f6d").lerp(Color("#526862"), 0.31 if raining else 0.0)
	var moss := Color("#b9c8b9") if winter else Color("#99946a")
	for index in sections:
		var a := lip[index]
		var b := lip[index + 1]
		var foot_a := feet[index]
		var foot_b := feet[index + 1]
		var tone := rock.lightened(0.045 * (index % 4))
		_quad(canvas, a, b, foot_b, foot_a, tone)
		var split_a := a.lerp(foot_a, 0.56).round()
		var split_b := b.lerp(foot_b, 0.49 + (index % 3) * 0.10).round()
		_quad(canvas, split_a, split_b, foot_b, foot_a, tone.darkened(0.24))
		var crack := a.lerp(b, 0.48 + (index % 3) * 0.09).round()
		var crack_foot := foot_a.lerp(foot_b, 0.38 + (index % 3) * 0.08).round()
		canvas.draw_line(crack, crack_foot, tone.darkened(0.25), 1.0)
		if index % 4 != 3:
			canvas.draw_line(a.lerp(b, 0.08).round(), a.lerp(b, 0.78).round(), moss, 2.0 if winter else 1.0)
			canvas.draw_line(foot_a.lerp(foot_b, 0.15).round(), foot_a.lerp(foot_b, 0.58).round(), Color("#95beb0b5"), 1.0)
		for chip in 2:
			var vein := a.lerp(b, 0.17 + chip * 0.36).lerp(foot_a.lerp(foot_b, 0.20 + chip * 0.35), 0.40).round()
			if Geometry2D.is_point_in_polygon(vein, PackedVector2Array([a, b, foot_b, foot_a])):
				canvas.draw_rect(Rect2(vein, Vector2(3 + (index + chip) % 4, 1)), Color(tone.lightened(0.15), 0.71))

func _draw_pond_gravel(canvas: CanvasItem, silt: Color, shallow: Color, winter: bool, has_dock: bool) -> void:
	for index in range(8, pond.size()):
		var a := pond[index]
		var b := pond[(index + 1) % pond.size()]
		var at := a.lerp(b, 0.45).round()
		var inland := a.direction_to(b).orthogonal()
		var gravel := silt.lightened(0.22 + (index % 3) * 0.07)
		# Skip the row of stones where the fishing deck meets the path.
		if has_dock and EstateLayout.POND_DECK.grow(5.0).has_point(at):
			continue
		for chip in 4:
			var foot := a.lerp(b, 0.15 + 0.22 * chip).round()
			var stone := (foot - inland * (3 + (chip * 7 + index) % 5)).round()
			canvas.draw_rect(Rect2(stone, Vector2(3 + (index + chip) % 5, 2)), gravel.darkened(0.19))
			canvas.draw_rect(Rect2(stone - Vector2(0, 1), Vector2(2 + (index + chip) % 5, 1)), gravel)
			var wash := (foot + inland * (2 + chip % 3)).round()
			var rim := Color("#b6c8bf") if winter else shallow.lightened(0.24)
			canvas.draw_rect(Rect2(wash, Vector2(3 + chip % 3, 1)), Color(rim, 0.70))

func _draw_pond_details(canvas: CanvasItem, shallow: Color, winter: bool) -> void:
	for stone: Vector3 in SUBMERGED_STONES:
		var at := Vector2(stone.x, stone.y)
		canvas.draw_colored_polygon(PackedVector2Array([at, at + Vector2(stone.z - 2, -2),
			at + Vector2(stone.z, 1), at + Vector2(stone.z - 1, 3), at + Vector2(1, 4)]), shallow.darkened(0.21))
		canvas.draw_line(at, at + Vector2(stone.z * 0.68, -1), shallow.lightened(0.12), 1.0)
	if winter:
		return
	for index in LILY_PADS.size():
		var at: Vector2 = LILY_PADS[index]
		var leaf := Color("#728468").lerp(shallow, float(index % 3) * 0.10)
		canvas.draw_colored_polygon(PackedVector2Array([at, at + Vector2(2, -2), at + Vector2(6, -1),
			at + Vector2(7, 2), at + Vector2(4, 4), at + Vector2(1, 3), at + Vector2(3, 1)]), leaf)
		canvas.draw_rect(Rect2(at + Vector2(2, -2), Vector2(3, 1)), leaf.lightened(0.14))

func festival_stone_at(foot: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(foot, pond_paving)

func draw_festival_paving(canvas: CanvasItem, grass: Color, winter: bool, raining: bool) -> void:
	var grout := Color("#777763").lerp(grass, 0.42 if winter else 0.34)
	var stone := Color("#938d74").lerp(Color("#697977"), 0.37 if raining else 0.0)
	var frost := Color("#b9c3af")
	canvas.draw_colored_polygon(_paving_margin, Color(grout.darkened(0.20), 0.49))
	for index in pond_paving.size():
		var a := pond_paving[index]
		var b := pond_paving[(index + 1) % pond_paving.size()]
		if b.x > a.x or a.distance_to(_paving_entrance) < 26.0 or b.distance_to(_paving_entrance) < 26.0:
			continue
		var edge := Vector2(0, 4 if index % 2 == 0 else 5)
		_quad(canvas, a, b, b + edge, a + edge, grout.darkened(0.21 + (index % 3) * 0.06))
	canvas.draw_colored_polygon(pond_paving, grout)
	_draw_flagstones(canvas, _paving_flagstones, grout, stone, winter)
	for index in pond_paving.size():
		var a := pond_paving[index]
		var b := pond_paving[(index + 1) % pond_paving.size()]
		if a.distance_to(_paving_entrance) < 26.0 or b.distance_to(_paving_entrance) < 26.0:
			continue
		var edge := (frost if winter else stone).lerp(grout, 0.47 + (index % 4) * 0.11)
		canvas.draw_line(a.lerp(b, 0.08), a.lerp(b, 0.65), edge, 1.0)

static func _draw_flagstones(canvas: CanvasItem, stones: Array[Dictionary], grout: Color, stone: Color, winter: bool) -> void:
	var frost := Color("#b9c3af")
	for slab in stones:
		var shade: int = slab.shade
		var tint := grout.lerp(stone, 0.46 + (shade % 6) * 0.052)
		if winter:
			tint = tint.lerp(frost, 0.11 + shade * 0.007)
		var slabs: PackedVector2Array = slab.points
		canvas.draw_colored_polygon(slabs, tint)
		var grain: Vector2 = slab.grain
		if Geometry2D.is_point_in_polygon(grain, slabs) and Geometry2D.is_point_in_polygon(grain + Vector2(5, 1), slabs):
			canvas.draw_rect(Rect2(grain, Vector2(3 + shade % 4, 1)), tint.lightened(0.12))
			canvas.draw_rect(Rect2(grain + Vector2(2, 2), Vector2(3, 1)), tint.darkened(0.11))

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
