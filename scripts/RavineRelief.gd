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
const TERRACE := [Vector2(397, -101), Vector2(405, -114), Vector2(426, -124), Vector2(449, -124),
	Vector2(464, -117), Vector2(471, -106), Vector2(462, -94), Vector2(448, -86),
	Vector2(441, -83), Vector2(419, -82), Vector2(407, -88), Vector2(397, -93)]
const TERRACE_FRONT := [Vector2(395, -96), Vector2(397, -93), Vector2(407, -88), Vector2(419, -82),
	Vector2(441, -83), Vector2(448, -86), Vector2(462, -94), Vector2(471, -106)]
const TERRACE_LIGHT := [Vector2(397, -101), Vector2(405, -114), Vector2(426, -124), Vector2(449, -124),
	Vector2(455, -116), Vector2(433, -108), Vector2(415, -105), Vector2(406, -95), Vector2(397, -93)]
const TERRACE_PLANES := [
	[Vector2(399, -100), Vector2(412, -101), Vector2(421, -98), Vector2(418, -88), Vector2(407, -88), Vector2(399, -93)],
	[Vector2(441, -107), Vector2(463, -114), Vector2(468, -106), Vector2(460, -96), Vector2(448, -89), Vector2(440, -94)],
]
const STAIR_WIDTH := 27.0
const STAIR_SPACING := 8.0
const STAIR_RISER := 3.0
const GATE_PAVING := Rect2(-24, -11, 37, 22)
const BLUFF_TOP_DEPTH := 1.45
const WEST_GATE_LAMP := RavineLayout.WEST_GATE + Vector2(17, -15)
const LOOKOUT_LAMP := RavineLayout.LOOKOUT + Vector2(-15, 10)
const MOSS := [Color("#778653"), Color("#69864c"), Color("#867a50"), Color("#bbc4b7")]

var steps: Array[PackedVector2Array] = []
var stair_outline := PackedVector2Array()
var terrace_surface := PackedVector2Array(TERRACE)

func _init() -> void:
	var approach := RavineLayout.RIDGE_LANE.slice(1, 5)
	var edges: Array[Vector2] = [approach[0]]
	for point: Vector2 in approach.slice(1):
		var start := edges[-1]
		var span := maxi(1, roundi((start.y - point.y) / STAIR_SPACING))
		for step in range(1, span + 1):
			edges.append(start.lerp(point, float(step) / span).round())
	var west := PackedVector2Array()
	var east := PackedVector2Array()
	for index in edges.size():
		var half_width := STAIR_WIDTH * 0.5
		west.append(edges[index] - Vector2(half_width + (index % 3), 0))
		east.append(edges[index] + Vector2(half_width + ((index + 1) % 3), 0))
		if index > 0:
			steps.append(PackedVector2Array([west[index], east[index], east[index - 1], west[index - 1]]))
	stair_outline = west.duplicate()
	east.reverse()
	stair_outline.append_array(east)

static func gate_stone_at(foot: Vector2, gate: Vector2) -> bool:
	return GATE_PAVING.has_point(foot - gate)

func lookout_stone_at(foot: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(foot, stair_outline) or Geometry2D.is_point_in_polygon(foot, terrace_surface)

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
	var rock := Color("#98917b").lerp(Color("#5b726b"), 0.46 if wet else 0.0)
	var moss: Color = MOSS[season]
	_draw_bluff(canvas, RavineLayout.LOOKOUT, LOOKOUT_WEST, rock, moss)
	_draw_bluff(canvas, RavineLayout.LOOKOUT, LOOKOUT_EAST, rock.darkened(0.10), moss.darkened(0.09))
	_draw_steps(canvas, rock, moss)
	_draw_terrace(canvas, rock, moss)

func _draw_steps(canvas: CanvasItem, rock: Color, moss: Color) -> void:
	var shadow := Transform2D(0.0, Vector2(7, 7)) * stair_outline
	canvas.draw_colored_polygon(shadow, Color("#283a32a6"))
	var side_tone := rock.lerp(Color("#45483a"), 0.52)
	for index in steps.size():
		var slab := steps[index]
		var shade := rock.lightened(0.04 + (index % 4) * 0.039)
		var tread_west := (slab[3] + Vector2(-1, -STAIR_RISER + index % 2)).round()
		var tread_east := (slab[2] + Vector2(0, -STAIR_RISER - index % 2)).round()
		var joint_ratio := 0.24 + posmod(index * 3, 5) * 0.13
		var joint := tread_west.lerp(tread_east, joint_ratio).round()
		var joint_back := joint.lerp(slab[0].lerp(slab[1], joint_ratio), 0.86).round()
		var riser_joint := slab[3].lerp(slab[2], joint_ratio).round()
		canvas.draw_colored_polygon(PackedVector2Array([slab[0], slab[1], tread_east, joint, tread_west]), shade)
		canvas.draw_colored_polygon(PackedVector2Array([slab[1], slab[2], slab[2] + Vector2(5, 4),
			slab[1] + Vector2(5, 4)]), side_tone)
		canvas.draw_colored_polygon(PackedVector2Array([tread_west, joint, riser_joint, slab[3]]), shade.darkened(0.31))
		canvas.draw_colored_polygon(PackedVector2Array([joint, tread_east, slab[2], riser_joint]), side_tone)
		canvas.draw_line(tread_west + Vector2(1, 0), joint - Vector2(2, 0), shade.lightened(0.26), 1.0)
		canvas.draw_line(joint + Vector2(1, 0), tread_east - Vector2(2, 0), shade.lightened(0.19), 1.0)
		canvas.draw_line(joint, joint_back, shade.darkened(0.23), 1.0)
		var verge := slab[0] if index % 3 == 1 else slab[2] + Vector2(2, 0)
		canvas.draw_rect(Rect2(verge - Vector2(1, 2), Vector2(3 + index % 2, 2)), moss.darkened(0.1))

func _draw_terrace(canvas: CanvasItem, rock: Color, moss: Color) -> void:
	var shadow := Transform2D(0.0, Vector2(8, 12)) * terrace_surface
	canvas.draw_colored_polygon(shadow, Color("#263b328e"))
	var walking_stone := rock.lightened(0.12)
	canvas.draw_colored_polygon(terrace_surface, walking_stone)
	canvas.draw_colored_polygon(PackedVector2Array(TERRACE_LIGHT), rock.lightened(0.24))
	for face in TERRACE_PLANES:
		canvas.draw_colored_polygon(PackedVector2Array(face), rock.lightened(0.058))
	for index in TERRACE_FRONT.size() - 1:
		var a: Vector2 = TERRACE_FRONT[index]
		var b: Vector2 = TERRACE_FRONT[index + 1]
		var seam := a.lerp(b, 0.42 + (index % 3) * 0.11).round()
		if index != 3: # The stair meets this side of the landing.
			var toe := Vector2(4, 8 + (index % 3) * 2)
			var shade := rock.darkened(0.27 + (index % 4) * 0.033)
			canvas.draw_colored_polygon(PackedVector2Array([a, b, b + toe, a + toe]), shade)
			canvas.draw_colored_polygon(PackedVector2Array([seam, b, b + toe, seam + toe + Vector2(-2, 0)]), shade.darkened(0.17))
			canvas.draw_line(seam + Vector2(2, 0), seam + toe * 0.76, shade.lightened(0.14), 1.0)
		canvas.draw_line(a, seam, walking_stone.lightened(0.17), 1.0)
		canvas.draw_rect(Rect2(seam - Vector2(2, 2), Vector2(3 + index % 4, 2)), moss)
	for at: Vector2 in [Vector2(406, -99), Vector2(419, -92), Vector2(430, -115), Vector2(442, -96), Vector2(452, -105)]:
		canvas.draw_polyline(PackedVector2Array([at, at + Vector2(5, -2), at + Vector2(9, -1)]), rock.darkened(0.13), 1.0)

static func install_ravine_edges(terrain: StaticBody2D) -> void:
	_add_bluff_edge(terrain, &"WestGateNorthRock", RavineLayout.WEST_GATE, GATE_NORTH)
	_add_bluff_edge(terrain, &"WestGateSouthRock", RavineLayout.WEST_GATE, GATE_SOUTH)
	_add_bluff_edge(terrain, &"LookoutWestRock", RavineLayout.LOOKOUT, LOOKOUT_WEST)
	_add_bluff_edge(terrain, &"LookoutEastRock", RavineLayout.LOOKOUT, LOOKOUT_EAST)

static func install_estate_edge(terrain: StaticBody2D) -> void:
	_add_bluff_edge(terrain, &"EastGateRock", EstateLayout.EAST_GATE, ESTATE_BANK)

static func _add_bluff_edge(terrain: StaticBody2D, edge_name: StringName, origin: Vector2, profile: Array[Vector3]) -> void:
	var boundary := PackedVector2Array()
	for point in profile:
		boundary.append(origin + Vector2(point.x, point.y))
	for index in range(profile.size() - 1, -1, -1):
		var point := profile[index]
		boundary.append(origin + Vector2(point.x, point.y - point.z * BLUFF_TOP_DEPTH))
	var edge := CollisionPolygon2D.new()
	edge.name = edge_name
	edge.polygon = boundary
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
