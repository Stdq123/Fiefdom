extends RefCounted

# Profiles store the bottom of the rock face and its height relative to a landmark.
const ESTATE_BANK: Array[Vector3] = [
	Vector3(27, -28, 3), Vector3(43, -32, 12), Vector3(55, -29, 19), Vector3(68, -25, 24),
	Vector3(81, -31, 19), Vector3(96, -29, 28), Vector3(118, -29, 29), Vector3(139, -35, 23),
	Vector3(160, -31, 25), Vector3(185, -35, 15), Vector3(209, -32, 4),
]
const GATE_NORTH: Array[Vector3] = [
	Vector3(-222, -36, 27), Vector3(-194, -35, 44), Vector3(-167, -27, 46), Vector3(-151, -31, 38),
	Vector3(-131, -27, 43), Vector3(-115, -31, 31), Vector3(-98, -26, 40), Vector3(-78, -24, 35),
	Vector3(-61, -29, 27), Vector3(-44, -25, 29), Vector3(-29, -29, 22), Vector3(-10, -27, 29),
	Vector3(12, -26, 33), Vector3(31, -27, 26), Vector3(49, -20, 17), Vector3(64, -18, 14),
	Vector3(79, -15, 4),
]
const GATE_SOUTH: Array[Vector3] = [
	Vector3(-204, 85, 24), Vector3(-177, 77, 28), Vector3(-156, 81, 33), Vector3(-134, 97, 39),
	Vector3(-100, 88, 34), Vector3(-78, 98, 36), Vector3(-52, 109, 33), Vector3(-33, 116, 22),
	Vector3(-16, 110, 11), Vector3(0, 117, 5),
]
const LOOKOUT_WEST: Array[Vector3] = [
	Vector3(-118, 10, 4), Vector3(-104, 14, 19), Vector3(-88, 18, 29), Vector3(-77, 9, 36),
	Vector3(-65, 4, 24), Vector3(-54, -9, 32), Vector3(-41, -13, 22), Vector3(-30, -16, 17),
	Vector3(-19, -19, 4),
]
const LOOKOUT_EAST: Array[Vector3] = [
	Vector3(-15, 71, 4), Vector3(-4, 73, 10), Vector3(12, 71, 16), Vector3(24, 66, 23),
	Vector3(35, 57, 32), Vector3(47, 50, 40), Vector3(61, 51, 36), Vector3(80, 42, 37),
	Vector3(97, 50, 23), Vector3(114, 47, 16), Vector3(130, 40, 5),
]
# The east bank opens into sunlit grass between the cascade and the ridge.
const BRIDGE_CLEARING := [
	Vector2(166, -58), Vector2(188, -100), Vector2(234, -117), Vector2(271, -114),
	Vector2(296, -102), Vector2(347, -115), Vector2(385, -88), Vector2(386, -48),
	Vector2(361, -12), Vector2(347, 23), Vector2(321, 49), Vector2(276, 71),
	Vector2(231, 77), Vector2(188, 68), Vector2(158, 43), Vector2(155, 6), Vector2(164, -24),
]
const RIDGE_CLEARING := [
	Vector2(315, 6), Vector2(327, -45), Vector2(360, -74), Vector2(400, -77),
	Vector2(445, -84), Vector2(493, -74), Vector2(534, -57), Vector2(560, -26),
	Vector2(572, 4), Vector2(555, 32), Vector2(524, 53), Vector2(483, 73),
	Vector2(443, 87), Vector2(390, 68), Vector2(360, 49), Vector2(335, 39),
]
# Walkable slopes run out into grass at their toes, except for exposed seams in the turf.
const BRIDGE_VERGE: Array[Vector3] = [
	Vector3(168, 62, 3), Vector3(179, 59, 8), Vector3(193, 65, 9), Vector3(204, 68, 14),
	Vector3(222, 66, 16), Vector3(236, 63, 15), Vector3(252, 63, 17), Vector3(267, 58, 15),
	Vector3(286, 52, 12), Vector3(300, 49, 9), Vector3(315, 46, 6), Vector3(329, 43, 2),
]
const RIDGE_VERGE: Array[Vector3] = [
	Vector3(347, 40, 2), Vector3(360, 38, 7), Vector3(373, 34, 11), Vector3(387, 32, 12),
	Vector3(402, 24, 13), Vector3(418, 19, 17), Vector3(433, 13, 15), Vector3(447, 6, 13),
	Vector3(461, 1, 15), Vector3(478, -8, 13), Vector3(495, -17, 9), Vector3(512, -21, 2),
]
const VERGE_EXPOSURES := [
	[Vector2(180, 57), Vector2(186, 51), Vector2(197, 51), Vector2(205, 53), Vector2(200, 58), Vector2(190, 61)],
	[Vector2(220, 58), Vector2(230, 55), Vector2(240, 55), Vector2(251, 51), Vector2(258, 53),
		Vector2(252, 58), Vector2(240, 61), Vector2(228, 60)],
	[Vector2(277, 49), Vector2(283, 43), Vector2(295, 43), Vector2(292, 48), Vector2(286, 50)],
	[Vector2(373, 27), Vector2(377, 23), Vector2(390, 22), Vector2(391, 25), Vector2(383, 28)],
	[Vector2(405, 13), Vector2(410, 7), Vector2(422, 5), Vector2(432, 3), Vector2(431, 7),
		Vector2(424, 11), Vector2(414, 14)],
	[Vector2(446, -1), Vector2(455, -7), Vector2(462, -5), Vector2(473, -10), Vector2(481, -8),
		Vector2(474, -4), Vector2(461, 1), Vector2(452, 2)],
]
const VERGE_TUFTS: Array[Vector3] = [
	Vector3(177, 55, 4), Vector3(190, 49, 5), Vector3(208, 56, 6), Vector3(215, 49, 4),
	Vector3(219, 61, 3), Vector3(248, 48, 5), Vector3(259, 52, 5), Vector3(266, 60, 3),
	Vector3(278, 46, 6), Vector3(301, 41, 4), Vector3(310, 40, 3),
	Vector3(207, -17, 4), Vector3(215, -13, 4), Vector3(220, -18, 6), Vector3(249, -71, 5),
	Vector3(259, -68, 4), Vector3(290, -32, 5), Vector3(296, -28, 3), Vector3(299, -35, 4),
	Vector3(358, 38, 4), Vector3(365, 32, 6), Vector3(389, 26, 5), Vector3(400, 12, 6),
	Vector3(413, 17, 4), Vector3(437, 6, 5), Vector3(442, 0, 4), Vector3(454, -7, 6),
	Vector3(480, -10, 5), Vector3(490, -14, 3), Vector3(501, -19, 4),
]
# Paving is described at the actual bridge and first stair, with bevels below the walkable tops.
const BRIDGE_APRON := [Vector2(-3, -12), Vector2(7, -12), Vector2(12, -9), Vector2(23, -8),
	Vector2(27, -4), Vector2(25, 2), Vector2(27, 6), Vector2(21, 9), Vector2(13, 8),
	Vector2(8, 12), Vector2(-3, 12)]
const BRIDGE_APRON_SLABS := [
	[Vector2(-3, -11), Vector2(6, -11), Vector2(10, -8), Vector2(9, 1), Vector2(3, 2), Vector2(-3, 0)],
	[Vector2(-3, 2), Vector2(3, 4), Vector2(10, 3), Vector2(13, 7), Vector2(7, 11), Vector2(-3, 11)],
	[Vector2(12, -8), Vector2(23, -7), Vector2(26, -4), Vector2(23, 1), Vector2(17, 2), Vector2(11, 1)],
	[Vector2(12, 3), Vector2(17, 4), Vector2(24, 3), Vector2(26, 6), Vector2(21, 8), Vector2(15, 7)],
]
const STAIR_APRON := [Vector2(-14, -2), Vector2(15, -2), Vector2(16, 3), Vector2(12, 8),
	Vector2(8, 8), Vector2(5, 15), Vector2(-5, 19), Vector2(-14, 16), Vector2(-15, 11),
	Vector2(-20, 9), Vector2(-18, 3)]
const STAIR_APRON_SLABS := [
	[Vector2(-14, -2), Vector2(-2, -2), Vector2(1, 5), Vector2(-5, 8), Vector2(-13, 7), Vector2(-17, 4)],
	[Vector2(0, -2), Vector2(14, -2), Vector2(15, 3), Vector2(11, 7), Vector2(3, 6)],
	[Vector2(-17, 6), Vector2(-13, 9), Vector2(-6, 10), Vector2(-7, 16), Vector2(-13, 15), Vector2(-14, 10), Vector2(-19, 9)],
	[Vector2(-4, 10), Vector2(2, 7), Vector2(7, 9), Vector2(4, 14), Vector2(-5, 18), Vector2(-6, 15)],
]
const TERRACE := [Vector2(397, -101), Vector2(405, -114), Vector2(426, -124), Vector2(449, -124),
	Vector2(464, -117), Vector2(471, -106), Vector2(462, -94), Vector2(448, -86),
	Vector2(441, -83), Vector2(419, -82), Vector2(407, -88), Vector2(397, -93)]
const TERRACE_FRONT := [Vector2(395, -96), Vector2(397, -93), Vector2(407, -88), Vector2(419, -82),
	Vector2(441, -83), Vector2(448, -86), Vector2(462, -94), Vector2(471, -106)]
const TERRACE_FOOT := [Vector2(378, -84), Vector2(385, -76), Vector2(396, -68), Vector2(413, -64),
	Vector2(444, -54), Vector2(455, -52), Vector2(474, -61), Vector2(481, -77)]
# The opening between these two faces is where the upper stair joins the terrace.
const STAIR_OPENING := 3
const TERRACE_LIGHT := [Vector2(397, -101), Vector2(405, -114), Vector2(426, -124), Vector2(449, -124),
	Vector2(455, -116), Vector2(433, -108), Vector2(415, -105), Vector2(406, -95), Vector2(397, -93)]
const TERRACE_PLANES := [
	[Vector2(399, -100), Vector2(412, -101), Vector2(421, -98), Vector2(418, -88), Vector2(407, -88), Vector2(399, -93)],
	[Vector2(441, -107), Vector2(463, -114), Vector2(468, -106), Vector2(460, -96), Vector2(448, -89), Vector2(440, -94)],
]
const ROCK_SLOPES := [
	[Vector2(291, -130), Vector2(316, -151), Vector2(358, -165), Vector2(389, -159), Vector2(418, -137),
		Vector2(421, -114), Vector2(391, -94), Vector2(369, -77), Vector2(339, -66), Vector2(315, -75),
		Vector2(301, -98)],
	[Vector2(376, -29), Vector2(399, -56), Vector2(430, -74), Vector2(472, -105), Vector2(513, -102),
		Vector2(541, -94), Vector2(561, -67), Vector2(569, -49), Vector2(537, -30), Vector2(499, -24),
		Vector2(464, -16), Vector2(417, -18), Vector2(392, -11)],
]
const SLOPE_MARKS := [
	[Vector2(309, -125), Vector2(321, -137), Vector2(346, -142), Vector2(371, -152), Vector2(391, -141)],
	[Vector2(455, -76), Vector2(475, -99), Vector2(503, -93), Vector2(530, -78), Vector2(546, -66)],
	[Vector2(427, -25), Vector2(454, -30), Vector2(478, -38), Vector2(513, -43), Vector2(548, -49)],
]
const LOOKOUT_SCREE := [Vector3(310, -91, 4), Vector3(333, -76, 6), Vector3(348, -80, 3),
	Vector3(380, -74, 5), Vector3(366, -59, 3), Vector3(395, -27, 4), Vector3(437, -29, 7),
	Vector3(454, -39, 3), Vector3(476, -33, 5), Vector3(497, -44, 4), Vector3(531, -58, 6)]
# Rows give the ridge-lane segment, fraction along it, and widths west and east of the tread center.
const STAIR_ROWS: Array[Vector4] = [
	Vector4(1, 0.0, 17, 15), Vector4(1, 0.24, 16, 14), Vector4(1, 0.50, 14, 16),
	Vector4(2, 0.0, 18, 17), Vector4(2, 0.24, 16, 14), Vector4(2, 0.55, 15, 14),
	Vector4(2, 0.83, 16, 14), Vector4(3, 0.0, 15, 14), Vector4(3, 1.0, 12, 13),
]
const STAIR_RISER := 3.0
const GATE_PAVING := Rect2(-24, -11, 37, 22)
const BLUFF_TOP_DEPTH := 1.45
const WEST_GATE_LAMP := RavineLayout.WEST_GATE + Vector2(17, -15)
const LOOKOUT_LAMP := RavineLayout.LOOKOUT + Vector2(-15, 10)
const MOSS := [Color("#778653"), Color("#69864c"), Color("#867a50"), Color("#bbc4b7")]

var steps: Array[PackedVector2Array] = []
var stair_outline := PackedVector2Array()
var terrace_surface := PackedVector2Array(TERRACE)
var bridge_aprons: Array[PackedVector2Array] = []
var stair_apron := PackedVector2Array()

func _init() -> void:
	for side: float in [-1.0, 1.0]:
		bridge_aprons.append(_bridge_apron_transform(side) * PackedVector2Array(BRIDGE_APRON))
	stair_apron = Transform2D(0.0, RavineLayout.RIDGE_LANE[1]) * PackedVector2Array(STAIR_APRON)
	var west := PackedVector2Array()
	var east := PackedVector2Array()
	for index in STAIR_ROWS.size():
		var row := STAIR_ROWS[index]
		var segment := int(row.x)
		var start: Vector2 = RavineLayout.RIDGE_LANE[segment]
		var center := start.lerp(RavineLayout.RIDGE_LANE[segment + 1], row.y).round()
		west.append(center - Vector2(row.z, 0))
		east.append(center + Vector2(row.w, 0))
		if index > 0:
			steps.append(PackedVector2Array([west[index], east[index], east[index - 1], west[index - 1]]))
	stair_outline = west.duplicate()
	east.reverse()
	stair_outline.append_array(east)

static func gate_stone_at(foot: Vector2, gate: Vector2) -> bool:
	return GATE_PAVING.has_point(foot - gate)

func lookout_stone_at(foot: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(foot, stair_outline) or Geometry2D.is_point_in_polygon(foot, terrace_surface)

func approach_stone_at(foot: Vector2) -> bool:
	for apron in bridge_aprons:
		if Geometry2D.is_point_in_polygon(foot, apron):
			return true
	return Geometry2D.is_point_in_polygon(foot, stair_apron)

static func _bridge_apron_transform(side: float) -> Transform2D:
	var deck := RavineLayout.BRIDGE_DECK
	var sill := deck.get_center() + Vector2(side * deck.size.x * 0.5, 0)
	# Both tracks turn upstream after leaving the deck.
	return Transform2D(Vector2(side if side > 0.0 else -0.78, -0.18), Vector2.DOWN, sill)

func draw_trail_verges(canvas: CanvasItem, season: int, wet: bool) -> void:
	var frost := season == Global.Season.WINTER
	var stone := Color("#a0987c").lerp(Color("#586a60"), 0.56 if wet else 0.0)
	var tips: Color = MOSS[season].darkened(0.19 if wet else 0.0)
	var turf := tips.lerp(Color("#465f43"), 0.73 if frost else 0.48)
	var sunlit := Color(turf.lightened(0.15 if not wet else 0.06), 0.52 if not wet else 0.37)
	_draw_clearing(canvas, BRIDGE_CLEARING, Vector2(254, -25), sunlit)
	_draw_clearing(canvas, RIDGE_CLEARING, Vector2(425, -7), Color(sunlit, sunlit.a * 0.85))
	_draw_low_verge(canvas, BRIDGE_VERGE, turf)
	_draw_low_verge(canvas, RIDGE_VERGE, turf)
	_draw_verge_details(canvas, stone, turf, tips)

static func _draw_clearing(canvas: CanvasItem, outline: Array, center: Vector2, light: Color) -> void:
	var edge := Color(light, 0.0)
	for index in outline.size():
		canvas.draw_polygon(PackedVector2Array([center, outline[index], outline[(index + 1) % outline.size()]]),
			PackedColorArray([light, edge, edge]))

static func _draw_low_verge(canvas: CanvasItem, profile: Array[Vector3], turf: Color) -> void:
	var crest := turf.lightened(0.055)
	var grassy_face := turf.darkened(0.105)
	var contact := Color("#243d2d", 0.35)
	for index in profile.size() - 1:
		var a := profile[index]
		var b := profile[index + 1]
		var toe_a := Vector2(a.x, a.y)
		var toe_b := Vector2(b.x, b.y)
		var rim_a := toe_a - Vector2(0, a.z)
		var rim_b := toe_b - Vector2(0, b.z)
		var cap_a := rim_a - Vector2(3, 12 + a.z * 0.8)
		var cap_b := rim_b - Vector2(3, 12 + b.z * 0.8)
		var lip_a := rim_a.lerp(toe_a, 0.51)
		var lip_b := rim_b.lerp(toe_b, 0.51)
		canvas.draw_polygon(PackedVector2Array([rim_a, rim_b, cap_b, cap_a]),
			PackedColorArray([crest, crest, Color(turf, 0.0), Color(turf, 0.0)]))
		canvas.draw_polygon(PackedVector2Array([rim_a, rim_b, lip_b, lip_a]), PackedColorArray([
			crest, crest, grassy_face, grassy_face]))
		canvas.draw_polygon(PackedVector2Array([lip_a, lip_b, toe_b, toe_a]),
			PackedColorArray([grassy_face, grassy_face, contact, contact]))
		var drift := Vector2(12, 10)
		canvas.draw_polygon(PackedVector2Array([toe_a, toe_b, toe_b + drift, toe_a + drift]),
			PackedColorArray([contact, contact, Color(contact, 0.0), Color(contact, 0.0)]))

static func _draw_verge_details(canvas: CanvasItem, rock: Color, turf: Color, tips: Color) -> void:
	for index in VERGE_EXPOSURES.size():
		var top := PackedVector2Array(VERGE_EXPOSURES[index])
		var stone := rock.lerp(turf, 0.32 + (index % 3) * 0.075)
		var base := Transform2D(0.0, Vector2(2, 3 + index % 2)) * top
		canvas.draw_colored_polygon(base, stone.lerp(Color("#3c4b39"), 0.55))
		canvas.draw_colored_polygon(top, stone)
		canvas.draw_polyline(top.slice(0, 3), stone.lightened(0.15), 1.0)
		var cleft := top[2].lerp(top[3], 0.39).round()
		canvas.draw_line(cleft, cleft.lerp(top[-2], 0.60).round(), stone.darkened(0.30), 1.0)
	for index in VERGE_TUFTS.size():
		var tuft := VERGE_TUFTS[index]
		var root := Vector2(tuft.x, tuft.y)
		var reach := tuft.z
		canvas.draw_colored_polygon(PackedVector2Array([root + Vector2(-reach, 0), root + Vector2(1, -2),
			root + Vector2(reach + 3, 0), root + Vector2(3, 2), root + Vector2(-reach + 1, 2)]), turf.darkened(0.19))
		var leaning := Vector2(-reach, -reach * 0.62).round()
		var tallest := Vector2(1.0 - index % 4, -reach - index % 3)
		canvas.draw_colored_polygon(PackedVector2Array([root + Vector2(-2, 1), root + leaning,
			root + Vector2(-1, -2), root + tallest, root + Vector2(2, -2),
			root + Vector2(reach, -reach * 0.68).round(), root + Vector2(3, 1)]), Color(tips, 0.82))
		canvas.draw_line(root + Vector2(-1, -1), root + tallest, tips.lightened(0.11), 1.0)

func draw_bridge_aprons(canvas: CanvasItem, season: int, wet: bool) -> void:
	var stone := Color("#938975").lerp(Color("#52675f"), 0.42 if wet else 0.0)
	if season == Global.Season.WINTER:
		stone = stone.lerp(Color("#929e9a"), 0.30)
	var moss: Color = MOSS[season]
	for index in bridge_aprons.size():
		var pose := _bridge_apron_transform(-1.0 if index == 0 else 1.0)
		_draw_apron(canvas, bridge_aprons[index], pose, BRIDGE_APRON_SLABS, stone, moss)

static func _draw_apron(canvas: CanvasItem, outline: PackedVector2Array, pose: Transform2D,
		slabs: Array, stone: Color, moss: Color) -> void:
	var shade := stone.lerp(Color("#3b493e"), 0.58)
	var side_shift := Vector2(1, 2)
	var bottom := Transform2D(0.0, side_shift)
	canvas.draw_colored_polygon(bottom * outline, shade)
	canvas.draw_colored_polygon(outline, stone.darkened(0.20))
	for index in slabs.size():
		var slab := pose * PackedVector2Array(slabs[index])
		var tone := stone.lightened(0.055 + (index % 3) * 0.052)
		canvas.draw_colored_polygon(slab, tone)
		canvas.draw_line(slab[0], slab[0].lerp(slab[1], 0.85), tone.lightened(0.18), 1.0)
		var nick := slab[0].lerp(slab[2], 0.49).round()
		canvas.draw_line(nick + Vector2(-2, 1), nick + Vector2(2, 0), tone.lightened(0.11), 1.0)
		canvas.draw_rect(Rect2(nick + Vector2(1, 2), Vector2(2 + index % 2, 1)), tone.darkened(0.09))
		var seam := slab[1].lerp(slab[2], 0.68)
		canvas.draw_line(seam, seam.lerp(slab[0], 0.25).round(), Color(moss.lightened(0.13), 0.78), 1.0)

static func draw_gate(canvas: CanvasItem, gate: Vector2, wilderness: bool, season: int, wet: bool) -> void:
	var rock := Color("#8c8876").lerp(Color("#5b7068"), 0.38 if wet else 0.0)
	var moss: Color = MOSS[season]
	var paving := Rect2(gate + GATE_PAVING.position, GATE_PAVING.size)
	var at := paving.position
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(5, -2), at + Vector2(30, -3),
		at + Vector2(44, 3), at + Vector2(42, 19), at + Vector2(36, 24), at + Vector2(-4, 21),
		at + Vector2(-5, 7)]), Color("#605c4a"))
	canvas.draw_rect(paving, rock.darkened(0.25))
	for row in 3:
		var start := 0
		for end: int in [10 - row * 2, 23 - row * 3, 32 - row, int(GATE_PAVING.size.x)]:
			var tile := at + Vector2(start, row * 7 + 1)
			var length := end - start - 1
			canvas.draw_rect(Rect2(tile, Vector2(length, 6)), rock.lightened(float(posmod(row + start, 5)) * 0.025))
			canvas.draw_rect(Rect2(tile, Vector2(length - 1, 1)), rock.lightened(0.24))
			canvas.draw_rect(Rect2(tile + Vector2(2, 3), Vector2(2, 1)), rock.darkened(0.11))
			start = end
	if wilderness:
		_draw_bluff(canvas, gate, GATE_NORTH, rock, moss)
		_draw_bluff(canvas, gate, GATE_SOUTH, rock.darkened(0.09), moss.darkened(0.1))
	else:
		_draw_bluff(canvas, gate, ESTATE_BANK, rock, moss)

func draw_lookout(canvas: CanvasItem, season: int, wet: bool) -> void:
	var rock := Color("#a1987d").lerp(Color("#617368"), 0.48 if wet else 0.0)
	if season == Global.Season.WINTER:
		rock = rock.lerp(Color("#929e9a"), 0.43)
	var moss: Color = MOSS[season]
	_draw_lookout_slopes(canvas, rock, moss, season == Global.Season.WINTER, wet)
	_draw_bluff(canvas, RavineLayout.LOOKOUT, LOOKOUT_WEST, rock, moss)
	_draw_bluff(canvas, RavineLayout.LOOKOUT, LOOKOUT_EAST, rock.darkened(0.10), moss.darkened(0.09))
	_draw_terrace_faces(canvas, rock, moss)
	_draw_apron(canvas, stair_apron, Transform2D(0.0, RavineLayout.RIDGE_LANE[1]),
		STAIR_APRON_SLABS, rock.darkened(0.095), moss)
	_draw_steps(canvas, rock, moss)
	_draw_terrace(canvas, rock, moss)

func _draw_lookout_slopes(canvas: CanvasItem, rock: Color, moss: Color, frost: bool, wet: bool) -> void:
	var light := Color(moss.lerp(Color("#4e6551"), 0.32), 0.42 if wet else 0.51)
	var dark := Color("#263e31", 0.15 if frost else 0.40)
	for slope in ROCK_SLOPES:
		var outline := PackedVector2Array(slope)
		var colors := PackedColorArray()
		var top := outline[0].y
		var bottom := top
		for point in outline:
			top = minf(top, point.y)
			bottom = maxf(bottom, point.y)
		for point in outline:
			colors.append(light.lerp(dark, inverse_lerp(top, bottom, point.y)))
		canvas.draw_polygon(outline, colors)
	for marks: Array in SLOPE_MARKS:
		for index in marks.size() - 1:
			var a: Vector2 = marks[index]
			var b: Vector2 = marks[index + 1]
			var lip := a.lerp(b, 0.73).round()
			var width := 3.0 + index % 3
			canvas.draw_colored_polygon(PackedVector2Array([a, lip, lip + Vector2(4, width), a + Vector2(6, width + 1)]),
				Color(moss.darkened(0.16), 0.50))
			canvas.draw_line(a.lerp(lip, 0.2).round(), lip, Color(moss.lightened(0.12), 0.57), 1.0)
	for stone: Vector3 in LOOKOUT_SCREE:
		var at := Vector2(stone.x, stone.y)
		var width := stone.z
		canvas.draw_line(at + Vector2(0, 2), at + Vector2(width + 3, 2), dark, 2.0)
		canvas.draw_colored_polygon(PackedVector2Array([at, at + Vector2(1, -2), at + Vector2(width - 2, -3),
			at + Vector2(width, -1), at + Vector2(width - 1, 1), at + Vector2(2, 1)]), rock.darkened(0.15))
		var highlight := moss.lightened(0.13) if frost else rock.lightened(0.15)
		canvas.draw_line(at + Vector2(1, -2), at + Vector2(width - 2, -3), highlight, 1.0)

func _draw_steps(canvas: CanvasItem, rock: Color, moss: Color) -> void:
	var side_tone := rock.lerp(Color("#47473a"), 0.55)
	var footing := rock.lerp(Color("#2d4336"), 0.72)
	var shadow := Color("#26382e83")
	# The exposed right-hand face grows uphill into the bedrock beside the landing.
	for index in steps.size():
		var slab := steps[index]
		var front := slab[2]
		var back := slab[1]
		var toe_front := front + Vector2(5 + index * 1.1, 4 + index * 1.85)
		var toe_back := back + Vector2(6.1 + index * 1.1, 5.85 + index * 1.85)
		var edge_front := front.lerp(toe_front, 0.47).round()
		var edge_back := back.lerp(toe_back, 0.47).round()
		var shadow_drift := Vector2(6, 5)
		canvas.draw_polygon(PackedVector2Array([toe_back, toe_front, toe_front + shadow_drift, toe_back + shadow_drift]),
			PackedColorArray([shadow, shadow, Color(shadow, 0.0), Color(shadow, 0.0)]))
		canvas.draw_polygon(PackedVector2Array([edge_back, edge_front, toe_front, toe_back]), PackedColorArray([
			footing.lightened(0.06), footing.lightened(0.05), footing.darkened(0.16), footing.darkened(0.16)]))
		var side := side_tone.lightened(0.03 * (index % 3))
		canvas.draw_colored_polygon(PackedVector2Array([back, front, edge_front, edge_back]), side)
		var fissure := edge_front.lerp(edge_back, 0.45).round()
		canvas.draw_line(fissure, fissure.lerp(toe_front, 0.72).round(), footing.darkened(0.24), 1.0)
		if index % 3 == 2:
			canvas.draw_line(edge_front.lerp(edge_back, 0.16).round(), fissure, moss.darkened(0.13), 1.5)
	for index in steps.size():
		var slab := steps[index]
		var shade := rock.lightened(0.11 + (index % 4) * 0.034)
		var riser := minf(STAIR_RISER, (slab[2].y - slab[1].y) / 2.0)
		var tread_west := (slab[3] + Vector2(-1, -riser + index % 2)).round()
		var tread_east := (slab[2] + Vector2(0, -riser)).round()
		var joint_ratio := 0.24 + posmod(index * 3, 5) * 0.13
		var joint := (tread_west.lerp(tread_east, joint_ratio) + Vector2(0, -1)).round()
		var joint_back := slab[0].lerp(slab[1], joint_ratio + 0.07).round()
		var joint_kink := (joint.lerp(joint_back, 0.58) + Vector2(-2, 0)).round()
		var riser_joint := slab[3].lerp(slab[2], joint_ratio).round()
		canvas.draw_colored_polygon(PackedVector2Array([slab[0], joint_back, joint_kink, joint, tread_west]), shade)
		canvas.draw_colored_polygon(PackedVector2Array([joint_back, slab[1], tread_east, joint, joint_kink]), shade.darkened(0.07))
		canvas.draw_colored_polygon(PackedVector2Array([tread_west, joint, riser_joint, slab[3]]), shade.darkened(0.31))
		canvas.draw_colored_polygon(PackedVector2Array([joint, tread_east, slab[2], riser_joint]), side_tone)
		canvas.draw_line(tread_west + Vector2(1, 0), joint - Vector2(2, 0), shade.lightened(0.26), 1.0)
		canvas.draw_line(joint + Vector2(1, 0), tread_east - Vector2(2, 0), shade.lightened(0.19), 1.0)
		canvas.draw_polyline(PackedVector2Array([joint, joint_kink, joint_back]), shade.darkened(0.20), 1.0)
		var nick := tread_west.lerp(joint, 0.48).round() - Vector2(0, 2)
		canvas.draw_line(nick, nick + Vector2(3 + index % 3, 0), Color(shade.lightened(0.15), 0.72), 1.0)

func _draw_terrace_faces(canvas: CanvasItem, rock: Color, moss: Color) -> void:
	var contact := Color("#26382eae")
	var shadow := Color(contact, 0.0)
	for index in TERRACE_FRONT.size() - 1:
		if index == STAIR_OPENING:
			continue
		var a: Vector2 = TERRACE_FRONT[index]
		var b: Vector2 = TERRACE_FRONT[index + 1]
		var foot_a: Vector2 = TERRACE_FOOT[index]
		var foot_b: Vector2 = TERRACE_FOOT[index + 1]
		var seam_a := a.lerp(foot_a, 0.36 + (index % 4) * 0.075).round()
		var seam_b := b.lerp(foot_b, 0.36 + ((index + 1) % 4) * 0.075).round()
		var shade := rock.darkened(0.17 + (index % 3) * 0.039)
		if index > STAIR_OPENING:
			shade = shade.lerp(Color("#4f5a49"), 0.30)
		var base := shade.lerp(Color("#333d34"), 0.61)
		var drift := Vector2(9, 6)
		canvas.draw_polygon(PackedVector2Array([foot_a, foot_b, foot_b + drift, foot_a + drift]),
			PackedColorArray([contact, contact, shadow, shadow]))
		canvas.draw_polygon(PackedVector2Array([seam_a, seam_b, foot_b, foot_a]),
			PackedColorArray([shade.darkened(0.14), shade.darkened(0.14), base, base]))
		canvas.draw_colored_polygon(PackedVector2Array([a, b, seam_b, seam_a]), shade)
		var split := 0.35 + (index % 3) * 0.09
		var crest := a.lerp(b, split).round()
		var cut := seam_a.lerp(seam_b, split + 0.14).round()
		var cleft := foot_a.lerp(foot_b, split - 0.09).round()
		canvas.draw_colored_polygon(PackedVector2Array([crest, b, seam_b, cut]), Color(base, 0.53))
		canvas.draw_colored_polygon(PackedVector2Array([cut, seam_b, foot_b, cleft]), Color(base.darkened(0.19), 0.45))
		canvas.draw_polyline(PackedVector2Array([crest, cut, cleft]), base.darkened(0.15), 1.0)
		canvas.draw_line(seam_a.lerp(cut, 0.27), cut.lerp(seam_b, 0.32), Color(shade.lightened(0.19), 0.7), 1.0)
		if index in [1, 4, 6]:
			var patch := seam_a.lerp(seam_b, 0.22).round()
			canvas.draw_colored_polygon(PackedVector2Array([patch + Vector2(-4, 0), patch + Vector2(-1, -4),
				patch + Vector2(4, -3), patch + Vector2(5, 0), patch + Vector2(2, 3)]), moss.darkened(0.16))

func _draw_terrace(canvas: CanvasItem, rock: Color, moss: Color) -> void:
	var walking_stone := rock.lightened(0.12)
	canvas.draw_colored_polygon(terrace_surface, walking_stone)
	canvas.draw_colored_polygon(PackedVector2Array(TERRACE_LIGHT), rock.lightened(0.24))
	for face in TERRACE_PLANES:
		canvas.draw_colored_polygon(PackedVector2Array(face), rock.lightened(0.058))
	for index in TERRACE_FRONT.size() - 1:
		var a: Vector2 = TERRACE_FRONT[index]
		var b: Vector2 = TERRACE_FRONT[index + 1]
		var seam := a.lerp(b, 0.42 + (index % 3) * 0.11).round()
		if index != STAIR_OPENING:
			canvas.draw_line(a, seam, walking_stone.lightened(0.12), 1.0)
			canvas.draw_rect(Rect2(seam - Vector2(2, 2), Vector2(3 + index % 4, 2)), moss)
	for at: Vector2 in [Vector2(406, -99), Vector2(419, -92), Vector2(430, -115), Vector2(442, -96), Vector2(452, -105)]:
		canvas.draw_polyline(PackedVector2Array([at, at + Vector2(5, -2), at + Vector2(9, -1)]), rock.darkened(0.13), 1.0)

static func install_ravine_edges(terrain: StaticBody2D) -> void:
	_add_bluff_edge(terrain, &"WestGateNorthRock", RavineLayout.WEST_GATE, GATE_NORTH)
	_add_bluff_edge(terrain, &"WestGateSouthRock", RavineLayout.WEST_GATE, GATE_SOUTH)
	_add_bluff_edge(terrain, &"LookoutWestRock", RavineLayout.LOOKOUT, LOOKOUT_WEST)
	_add_bluff_edge(terrain, &"LookoutEastRock", RavineLayout.LOOKOUT, LOOKOUT_EAST)
	_add_terrace_edge(terrain, &"LookoutWestFace", 0, STAIR_OPENING - 1)
	_add_terrace_edge(terrain, &"LookoutEastFace", STAIR_OPENING + 1, TERRACE_FRONT.size() - 1)

static func _add_terrace_edge(terrain: StaticBody2D, edge_name: StringName, first: int, last: int) -> void:
	var face := PackedVector2Array(TERRACE_FRONT.slice(first, last + 1))
	for index in range(last, first - 1, -1):
		face.append(TERRACE_FOOT[index])
	_install_edge(terrain, edge_name, face)

static func install_estate_edge(terrain: StaticBody2D) -> void:
	_add_bluff_edge(terrain, &"EastGateRock", EstateLayout.EAST_GATE, ESTATE_BANK)

static func _add_bluff_edge(terrain: StaticBody2D, edge_name: StringName, origin: Vector2, profile: Array[Vector3]) -> void:
	var boundary := PackedVector2Array()
	for point in profile:
		boundary.append(origin + Vector2(point.x, point.y))
	for index in range(profile.size() - 1, -1, -1):
		var point := profile[index]
		boundary.append(origin + Vector2(point.x, point.y - point.z * BLUFF_TOP_DEPTH))
	_install_edge(terrain, edge_name, boundary)

static func _install_edge(terrain: StaticBody2D, edge_name: StringName, outline: PackedVector2Array) -> void:
	var edge := CollisionPolygon2D.new()
	edge.name = edge_name
	edge.polygon = outline
	terrain.add_child(edge)

static func _draw_bluff(canvas: CanvasItem, origin: Vector2, profile: Array[Vector3], rock: Color, moss: Color) -> void:
	for index in profile.size() - 1:
		var a := profile[index]
		var b := profile[index + 1]
		var foot_a := origin + Vector2(a.x, a.y)
		var foot_b := origin + Vector2(b.x, b.y)
		var rim_a := foot_a - Vector2(0, a.z)
		var rim_b := foot_b - Vector2(0, b.z)
		var turf_a := foot_a - Vector2(0, a.z * BLUFF_TOP_DEPTH)
		var turf_b := foot_b - Vector2(0, b.z * BLUFF_TOP_DEPTH)
		var seam_a := rim_a.lerp(foot_a, 0.41 + (index % 3) * 0.11)
		var seam_b := rim_b.lerp(foot_b, 0.41 + ((index + 1) % 3) * 0.11)
		var shade := rock.darkened(0.12 + (index % 4) * 0.035)
		var shadow := Vector2(2, 5)
		canvas.draw_colored_polygon(PackedVector2Array([foot_a, foot_b, foot_b + shadow, foot_a + shadow]), Color("#283c3288"))
		canvas.draw_polygon(PackedVector2Array([rim_a, rim_b, turf_b, turf_a]), PackedColorArray([
			moss.darkened(0.25), moss.darkened(0.25), Color(moss, 0.09), Color(moss, 0.09)]))
		canvas.draw_colored_polygon(PackedVector2Array([rim_a, rim_b, seam_b, seam_a]), shade.lightened(0.13))
		canvas.draw_colored_polygon(PackedVector2Array([seam_a, seam_b, foot_b, foot_a]), shade.darkened(0.27))
		var cut := 0.29 + (index % 5) * 0.11
		var crest := rim_a.lerp(rim_b, cut)
		var split := seam_a.lerp(seam_b, cut + 0.08)
		var toe := foot_a.lerp(foot_b, cut - 0.11)
		var scarp := Color(shade.darkened(0.34), 0.35)
		canvas.draw_colored_polygon(PackedVector2Array([crest, rim_b, seam_b, split]), scarp)
		canvas.draw_colored_polygon(PackedVector2Array([split, seam_b, foot_b, toe]), scarp)
		canvas.draw_polyline(PackedVector2Array([crest, split, toe]), shade.darkened(0.43), 1.0)
		canvas.draw_line(rim_a, rim_a.lerp(rim_b, 0.64), moss.lightened(0.16), 1.5)
		for chip in 4:
			var along := float(chip + 1) / 5.0
			var seam := seam_a.lerp(seam_b, along).round()
			var lip := rim_a.lerp(rim_b, along).round()
			var mark := lip.lerp(seam, 0.24 + ((index + chip) % 4) * 0.23).round()
			canvas.draw_line(mark, mark + Vector2(3 + (index + chip) % 4, 1 - (index % 3)), shade.lightened(0.20), 1.0)
			if (index + chip) % 3 != 1 and minf(a.z, b.z) > 8.0:
				canvas.draw_rect(Rect2(lip - Vector2(1, 2 + chip % 3), Vector2(5, 2)), moss)
				canvas.draw_rect(Rect2(lip - Vector2(0, 5 + chip % 3), Vector2(1, 4)), moss.lightened(0.15))
