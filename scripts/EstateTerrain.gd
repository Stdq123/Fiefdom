extends RefCounted

const LOAM := preload("res://assets/world/ninja-adventure/estate-loam.png")
const MEADOWS := [
	"res://assets/world/estate-meadow-grain.png", "res://assets/world/summer-meadow-grain.png",
	"res://assets/world/autumn-meadow-grain.png", "res://assets/world/winter-meadow-grain.png",
]
const VERGE := "res://assets/world/seasonal-roadside.png"
const TRAIL := "res://assets/world/ravine-trail-loam.png"
const SNOWDRIFTS := "res://assets/world/winter-snowdrifts.png"
const DRIFT_CELL := Vector2(128, 64)
const HALL_YARD_ART := preload("res://assets/world/estate-hall-yard.png")
const SITE_ART := preload("res://assets/world/estate-site-art.png")
const TRACK_GRAIN := preload("res://assets/world/estate-track-loam.png")
const STONE_GRAIN := preload("res://assets/world/estate-stone-grain.png")
const HALL_PAVING_AT := Vector2(-68, 17)
const SPRING_PAVING_AT := Vector2(-41, -15)
const WET_PAVING_TINT := Color(0.83, 0.90, 0.91)
const SPRIG_CELL := Vector2(32, 20)
static var _meadow_textures: Dictionary[int, Texture2D] = {}
static var _verge_texture: Texture2D
static var _trail_texture: Texture2D
static var _snow_texture: Texture2D
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
const HALL_CURB: Array[float] = [0, 0, 0, 0, 0, 2, 4, 5, 5, 3, 0, 0, 3, 5, 4, 3, 0]
const SPRING_APRON := [
	Vector2(-38, -1), Vector2(-33, -5), Vector2(-23, -5), Vector2(-17, -8), Vector2(-8, -14),
	Vector2(6, -15), Vector2(17, -11), Vector2(21, -6), Vector2(19, 1), Vector2(22, 7), Vector2(15, 13),
	Vector2(9, 17), Vector2(-2, 18), Vector2(-14, 16), Vector2(-24, 13), Vector2(-28, 9),
	Vector2(-35, 8), Vector2(-40, 5),
]
const SPRING_CURB: Array[float] = [0, 0, 0, 0, 0, 0, 0, 1.5, 2, 3.5, 4, 4, 3.5, 3, 2, 0.5, 0, 0]
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
var _hall_paving := PackedVector2Array(HALL_COURT)
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
		_quad(canvas, left, right, seam_right, seam_left, facet, STONE_GRAIN)
		_quad(canvas, seam_left, seam_right, base_right, base_left, facet.darkened(0.18), STONE_GRAIN)
		var seam_break := seam_left.lerp(seam_right, 0.43).round()
		var lower_break := base_left.lerp(base_right, 0.31).round()
		_quad(canvas, seam_break, seam_right, base_right, lower_break, facet.darkened(0.26), STONE_GRAIN)
		canvas.draw_line(seam_break, lower_break, facet.darkened(0.34), 1.0)
		var chip := seam_left.lerp(seam_right, 0.27).round()
		canvas.draw_rect(Rect2(chip - Vector2(2, 3), Vector2(4 + index % 5, 2)), facet.lightened(0.09))
		canvas.draw_rect(Rect2(chip + Vector2(3, 4), Vector2(3 + index % 3, 1)), facet.darkened(0.32))
		var moss_edge := Vector2(0, 2 + index % 4)
		_quad(canvas, left, right, right + moss_edge, left + moss_edge, lip.lerp(shade, 0.22 + (index % 3) * 0.17))

func _quad(canvas: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color,
		texture: Texture2D = null) -> void:
	var face := PackedVector2Array([a, b, c, d])
	if texture != null:
		draw_loam(canvas, face, color, texture)
	else:
		canvas.draw_colored_polygon(face, color)

static func draw_loam(canvas: CanvasItem, polygon: PackedVector2Array, soil: Color, texture: Texture2D = LOAM) -> void:
	draw_tiled_surface(canvas, polygon, PackedColorArray([soil]), texture)

static func meadow_texture(season: int) -> Texture2D:
	if not _meadow_textures.has(season):
		_meadow_textures[season] = load(MEADOWS[season])
	return _meadow_textures[season]

static func trail_texture() -> Texture2D:
	if not _trail_texture:
		_trail_texture = load(TRAIL)
	return _trail_texture

static func draw_grass(canvas: CanvasItem, area: Rect2, season: int, wet: bool, wooded := false) -> void:
	var light := Color("#bccdc7") if wet else Color.WHITE
	if wooded:
		light *= Color("#dde8df")
	draw_loam(canvas, EstateLayout.corners(area), light, meadow_texture(season))

static func draw_snow(canvas: CanvasItem, area: Rect2, variation: int) -> void:
	if not _snow_texture:
		_snow_texture = load(SNOWDRIFTS)
	var cell := Vector2(variation % 2, floori(variation / 2.0) % 2)
	canvas.draw_texture_rect_region(_snow_texture, area, Rect2(cell * DRIFT_CELL, DRIFT_CELL),
		Color("#c6d2c8"))

static func draw_tiled_surface(canvas: CanvasItem, polygon: PackedVector2Array,
		colors: PackedColorArray, texture: Texture2D) -> void:
	if texture == null:
		canvas.draw_polygon(polygon, colors)
		return
	var uvs := PackedVector2Array()
	var size := texture.get_size()
	for point in polygon:
		uvs.append(point / size)
	canvas.draw_polygon(polygon, colors, uvs, texture)

static func draw_tiled_band(canvas: CanvasItem, a: PackedVector2Array, b: PackedVector2Array,
		near: Color, far: Color, texture: Texture2D = null) -> void:
	var colors := PackedColorArray([near, near, far, far])
	for index in a.size() - 1:
		draw_tiled_surface(canvas, PackedVector2Array([a[index], a[index + 1], b[index + 1], b[index]]),
			colors, texture)

func draw_meadow(canvas: CanvasItem, season: int, wet: bool) -> void:
	for index in meadow_sprigs.size():
		if index % 2 != 0 or (season == Global.Season.WINTER and index % 3 != 0):
			continue
		draw_sprig(canvas, meadow_sprigs[index], index, season, wet)

func draw_farm_yard(canvas: CanvasItem, grass: Color, season: int, wet: bool) -> void:
	var center := Vector2(84, 109)
	var tint := grass.lerp(Color("#a3b0a1") if season == Global.Season.WINTER else Color("#738354"), 0.48)
	var colors := PackedColorArray([Color(tint, 0.56 if not wet else 0.31), Color(tint, 0.0), Color(tint, 0.0)])
	for index in FARM_YARD.size():
		canvas.draw_polygon(PackedVector2Array([center, FARM_YARD[index], FARM_YARD[(index + 1) % FARM_YARD.size()]]), colors)
	for index: int in [1, 3, 8, 11, 13]:
		var at: Vector2 = FARM_YARD[index].lerp(center, 0.20).round()
		draw_sprig(canvas, at, index, season, wet)

func hall_stone_at(foot: Vector2) -> bool:
	return EstateLayout.HALL_LANDING.has_point(foot) or Geometry2D.is_point_in_polygon(foot, _hall_paving)

func spring_stone_at(foot_from_source: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(foot_from_source, _spring_paving)

func draw_hall_court(canvas: CanvasItem, dirt: Color, winter: bool, wet: bool) -> void:
	var stone := Color("#aaa58f").lerp(Color("#657770"), 0.42 if wet else 0.0)
	_draw_stone_curb(canvas, _hall_paving, HALL_CURB, stone, winter)
	var paving := Rect2(128 if winter else 0, 276, 126, 48)
	var tint := WET_PAVING_TINT if wet else Color.WHITE
	canvas.draw_texture_rect_region(HALL_YARD_ART, Rect2(HALL_PAVING_AT, paving.size), paving, tint)
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

func draw_spring_apron(canvas: CanvasItem, at: Vector2, winter: bool, wet: bool) -> void:
	var stone := Color("#999888").lerp(Color("#637a6e"), 0.42 if wet else 0.12)
	var top := Transform2D(0.0, at) * _spring_paving
	_draw_stone_curb(canvas, top, SPRING_CURB, stone, winter)
	var paving := Rect2(460 if winter else 392, 276, 64, 38)
	var tint := WET_PAVING_TINT if wet else Color.WHITE
	canvas.draw_texture_rect_region(HALL_YARD_ART, Rect2(at + SPRING_PAVING_AT, paving.size), paving, tint)

func draw_gate_paving(canvas: CanvasItem, at: Vector2, winter: bool, wet: bool) -> void:
	var paving := Rect2(108 if winter else 68, 252, 37, 22)
	canvas.draw_texture_rect_region(SITE_ART, Rect2(at, paving.size), paving,
		WET_PAVING_TINT if wet else Color.WHITE)

static func _draw_stone_curb(canvas: CanvasItem, rim: PackedVector2Array, depths: Array[float],
		stone: Color, winter: bool) -> void:
	# A zero depth marks a tread that meets the adjacent dirt at grade.
	var fall := Vector2(0.29, 1.0)
	var shade := Color(stone.darkened(0.65), 0.45)
	var shadow_end := Color(shade, 0.0)
	for index in rim.size():
		var next := (index + 1) % rim.size()
		if depths[index] == 0.0 and depths[next] == 0.0:
			continue
		var a := rim[index]
		var b := rim[next]
		var foot_a := a + fall * depths[index]
		var foot_b := b + fall * depths[next]
		var shadow_offset := Vector2(1.35, 1.75) * minf(1.0, (depths[index] + depths[next]) * 0.20)
		canvas.draw_polygon(PackedVector2Array([foot_a, foot_b, foot_b + shadow_offset, foot_a + shadow_offset]),
			PackedColorArray([shade, shade, shadow_end, shadow_end]))
		var face := PackedVector2Array([a, b])
		if depths[next] > 0.0:
			face.append(foot_b)
		if depths[index] > 0.0:
			face.append(foot_a)
		var riser := stone.darkened(0.39 + posmod(index, 3) * 0.042)
		canvas.draw_colored_polygon(face, riser)
		var blocks := ceili(a.distance_to(b) / 10.0)
		for joint in range(1, blocks):
			var at := float(joint) / blocks
			var edge := a.lerp(b, at)
			var foot := foot_a.lerp(foot_b, at)
			canvas.draw_line(edge.lerp(foot, 0.20), foot, riser.darkened(0.21), 0.75)
		var lip := stone.lerp(Color("#c0c9b4"), 0.54 if winter else 0.10)
		canvas.draw_line(a.lerp(b, 0.12), a.lerp(b, 0.72), lip, 0.7)

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
		_quad(canvas, a, b, foot_b, foot_a, tone, STONE_GRAIN)
		var split_a := a.lerp(foot_a, 0.56).round()
		var split_b := b.lerp(foot_b, 0.49 + (index % 3) * 0.10).round()
		_quad(canvas, split_a, split_b, foot_b, foot_a, tone.darkened(0.24), STONE_GRAIN)
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
		_quad(canvas, a, b, b + edge, a + edge, grout.darkened(0.21 + (index % 3) * 0.06), STONE_GRAIN)
	var slabs := Rect2(560 if winter else 368, 288, 190, 113)
	canvas.draw_texture_rect_region(SITE_ART, Rect2(Vector2(270, 852), slabs.size), slabs,
		WET_PAVING_TINT if raining else Color.WHITE)
	for index in pond_paving.size():
		var a := pond_paving[index]
		var b := pond_paving[(index + 1) % pond_paving.size()]
		if a.distance_to(_paving_entrance) < 26.0 or b.distance_to(_paving_entrance) < 26.0:
			continue
		var edge := (frost if winter else stone).lerp(grout, 0.47 + (index % 4) * 0.11)
		canvas.draw_line(a.lerp(b, 0.08), a.lerp(b, 0.65), edge, 1.0)

static func draw_verge(canvas: CanvasItem, points: PackedVector2Array, width: float, season: int, wet: bool) -> void:
	# Measure along the actual road. Narrow field entrances and long creek segments have different sampling densities.
	var next := 12.0
	for index in range(1, points.size()):
		var start := points[index - 1]
		var direction := start.direction_to(points[index])
		var length := start.distance_to(points[index])
		while next < length:
			var foot := start + direction * next
			var variation := posmod(roundi(foot.x * 5.0 + foot.y * 11.0), 73)
			var side := 1.0 if variation % 2 == 0 else -1.0
			var gap := width * 0.5 + 3.0 + float(variation % 6)
			draw_sprig(canvas, (foot + direction.orthogonal() * side * gap).round(), variation, season, wet)
			next += 26.0 + float(variation % 24)
		next -= length

static func draw_sprig(canvas: CanvasItem, foot: Vector2, variation: int, season: int, wet: bool) -> void:
	if not _verge_texture:
		_verge_texture = load(VERGE)
	var source := Rect2(Vector2(variation % 3, season) * SPRIG_CELL, SPRIG_CELL)
	var span := 15.0 + float(variation % 8)
	var size := Vector2(span, span * SPRIG_CELL.y / SPRIG_CELL.x)
	var ground := Rect2((foot - size * Vector2(0.5, 0.85)).round(), size)
	var tint := Color("#b5c4b6") if wet else Color.WHITE
	canvas.draw_texture_rect_region(_verge_texture, ground, source, tint)
