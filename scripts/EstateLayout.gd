extends RefCounted
class_name EstateLayout

const TILE_ORIGIN := Vector2(16, 24)
const TILE_SIZE := 16.0
const BOUNDS := Rect2(-330, -205, 840, 931)
const FIELD_ENTRANCE_WIDTH := TILE_SIZE
const EDGE_NORMALS := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]

const HALL_FOOT := Vector2i(-12, 26)
const HALL_BASE := Rect2(-51, -21, 102, 23)
const HALL_LANDING := Rect2(Vector2(HALL_FOOT) + Vector2(-22, 1), Vector2(44, 15))
const SILK_SHED_FOOT := Vector2(-291, 169)
const SILK_SHED_YARD := SILK_SHED_FOOT + Vector2(8, 15)
const SILK_SHED_BASE := Rect2(-31, -14, 62, 14)
const WEST_FORK := Vector2(-273, -21)
const WEST_COURT_TURN := Vector2(-261, 62)
const WEST_COURT := Vector2(-282, 68)
const WEST_COURT_SHELTER := WEST_COURT + Vector2(-22, -14)
const SOUTH_PAVILION := Vector2(77, 391)
const PAVILION_SIZE := Vector2(72, 60)
const PAVILION_BOUNDS := Rect2(SOUTH_PAVILION + Vector2(-36, -56), PAVILION_SIZE)
const DRIVING_START := Vector2(392, 229)
const DRIVING_BAY := Rect2(DRIVING_START - Vector2(28, 19), Vector2(41, 57))
const DRIVING_FINISH := Vector2(481, 464)
const DRIVING_PARKING := Rect2(DRIVING_FINISH - Vector2(12, 14), Vector2(24, 28))
const BUILDING_GROUND := [
	Rect2(Vector2(HALL_FOOT) + HALL_BASE.position, HALL_BASE.size),
	HALL_LANDING,
	Rect2(SILK_SHED_FOOT + SILK_SHED_BASE.position, SILK_SHED_BASE.size),
]
const LANDMARKS := BUILDING_GROUND + [
	PAVILION_BOUNDS,
	DRIVING_BAY,
	DRIVING_PARKING,
]

const FIELD_TURN := Vector2(107, 165)
const EAST_LANE_JUNCTION := Vector2(29, 152)
const DRIVING_FORK := Vector2(345, 7)
const EAST_WATCH := Vector2(336, 151)
const FIELD_LANE_TURN := Vector2(44, 241)
const BAMBOO_BEND := Vector2(19, 321)
const PAVILION_TURN := Vector2(44, 385)
const PAVILION_JUNCTION := Vector2(23, 432)
const SOUTH_FORK := Vector2(29, 536)
const FREIGHT_STOP := Vector2(-94, 574)
const FREIGHT_JUNCTION := Vector2(-41, 574)
const FREIGHT_APPROACH := FREIGHT_STOP + Vector2(0, 23)
const HEARTH_APPROACH := Vector2(215, 571)
const FESTIVAL_FORK := Vector2(257, 586)
const FESTIVAL_GROUND := Vector2(353, 611)
const RAVINE_TRAIL_GATE := Vector2(477, 568)
const RAVINE_TRAIL_ARRIVAL := Vector2(437, 574)
const RAVINE_TRAIL_NAME := "竹涧小径"
const SHEEPFOLD_GATE := Vector2(-248, 650)
const PAVILION_SEATS := Vector2(151, 436)
const SOUTH_LANE := [
	Vector2(4, 43), Vector2(1, 72), Vector2(0, 101), Vector2(8, 128), EAST_LANE_JUNCTION,
	Vector2(46, 177), Vector2(50, 205), FIELD_LANE_TURN, Vector2(35, 268), Vector2(21, 294),
	BAMBOO_BEND, Vector2(24, 347), Vector2(38, 370), PAVILION_TURN,
	PAVILION_JUNCTION, Vector2(21, 463), Vector2(17, 489), Vector2(20, 514), SOUTH_FORK,
]
const EAST_LANE := [
	EAST_LANE_JUNCTION, Vector2(62, 162), FIELD_TURN, Vector2(150, 164), Vector2(194, 160),
	Vector2(243, 153), Vector2(293, 150), EAST_WATCH,
]
const DRIVING_APPROACH := [
	DRIVING_FORK, Vector2(363, 30), Vector2(378, 59), Vector2(388, 91), Vector2(388, 127),
	Vector2(382, 161), Vector2(386, 195), DRIVING_START,
]
const DRIVING_GATES := [Vector2(400, 314), Vector2(405, 401), Vector2(406, 449), Vector2(450, 460)]
const DRIVING_LANE := [
	DRIVING_START, DRIVING_GATES[0], DRIVING_GATES[1], Vector2(403, 429),
	DRIVING_GATES[2], Vector2(425, 458), DRIVING_GATES[3], DRIVING_FINISH + Vector2(7, 0),
]
const DRIVING_ROADS := [DRIVING_APPROACH, DRIVING_LANE]
const WEST_LANE := [
	WEST_FORK, Vector2(-268, 7), Vector2(-259, 34), WEST_COURT_TURN,
	Vector2(-265, 97), Vector2(-257, 124), Vector2(-251, 150), Vector2(-251, 176),
	Vector2(-258, 195), SILK_SHED_YARD + Vector2(0, 11), SILK_SHED_YARD,
]
const WEST_COURT_PATH := [WEST_COURT_TURN, Vector2(-269, 68), WEST_COURT, Vector2(-300, 71)]
const WEST_ROADS := [WEST_LANE, WEST_COURT_PATH]
const ROADS := [
	[Vector2(-504, -33), Vector2(-397, -31), Vector2(-343, -28), Vector2(-308, -24), WEST_FORK, Vector2(-249, -19),
		Vector2(-205, 0), Vector2(-140, 16), Vector2(-90, 28), Vector2(-40, 41),
		Vector2(4, 43), Vector2(39, 38), Vector2(91, 32), Vector2(148, 27), Vector2(213, 20),
		Vector2(283, 12), DRIVING_FORK, Vector2(400, 8), Vector2(460, 0), Vector2(516, 0),
		Vector2(579, -3), Vector2(676, 6)],
	SOUTH_LANE,
	EAST_LANE,
	[Vector2(HALL_FOOT) + Vector2(0, 17), Vector2(HALL_FOOT) + Vector2(0, 9)],
] + WEST_ROADS
const ROAD_WIDTHS := [32.0, 22.0, 18.0, 30.0, 13.0, 21.0]
const ROAD_SHOULDER := 2.5
const PAVILION_APPROACH := [
	PAVILION_JUNCTION, Vector2(48, 430), Vector2(68, 426), Vector2(77, 411), SOUTH_PAVILION + Vector2(0, 6),
]
const PAVILION_COURT := [
	PAVILION_APPROACH[1], Vector2(82, 438), Vector2(116, 448), PAVILION_SEATS + Vector2(0, 15),
]
const UNLOADING_LANE := [SOUTH_FORK, Vector2(4, 555), FREIGHT_JUNCTION, FREIGHT_STOP]
const FREIGHT_AISLE := [FREIGHT_JUNCTION, Vector2(-55, 591), FREIGHT_APPROACH]
const HEARTH_LANE := [
	SOUTH_FORK, Vector2(76, 540), Vector2(131, 557), Vector2(178, 572), HEARTH_APPROACH, FESTIVAL_FORK,
]
const FESTIVAL_LANE := [
	FESTIVAL_FORK, Vector2(280, 603), Vector2(295, 638), Vector2(332, 660), Vector2(368, 662),
	Vector2(368, 641), FESTIVAL_GROUND + Vector2(0, 18),
]
const RAVINE_TRAIL := [
	FESTIVAL_FORK, Vector2(292, 580), Vector2(331, 566), Vector2(375, 560),
	Vector2(409, 568), RAVINE_TRAIL_ARRIVAL, RAVINE_TRAIL_GATE, Vector2(564, 564), Vector2(640, 575),
]
const SHEEP_LANE := [
	SOUTH_FORK, Vector2(5, 592), Vector2(-42, 629), Vector2(-110, 649), Vector2(-181, 654),
	Vector2(-222, 655), SHEEPFOLD_GATE, SHEEPFOLD_GATE + Vector2(0, -10),
]
const SOUTH_ROADS := [
	PAVILION_APPROACH, PAVILION_COURT, UNLOADING_LANE, FREIGHT_AISLE,
	HEARTH_LANE, FESTIVAL_LANE, SHEEP_LANE, RAVINE_TRAIL,
]

static var road_lines: Array[PackedVector2Array] = _bake_roads()

static func festival_entrance() -> Array[Vector2]:
	var path: Array[Vector2] = []
	for point: Vector2 in FESTIVAL_LANE.slice(0, 4):
		path.append(point - FESTIVAL_GROUND)
	return path

static func tile_bounds(cell: Vector2i) -> Rect2:
	return Rect2(TILE_ORIGIN + Vector2(cell) * TILE_SIZE, Vector2.ONE * TILE_SIZE)

static func field_bounds(cell: Vector2i) -> Rect2:
	return tile_bounds(cell).grow(TILE_SIZE)

static func is_foundation(cell: Vector2i) -> bool:
	var tile := tile_bounds(cell)
	for ground: Rect2 in BUILDING_GROUND:
		if ground.intersects(tile):
			return true
	return false

static func corners(area: Rect2) -> PackedVector2Array:
	return PackedVector2Array([area.position, Vector2(area.end.x, area.position.y),
		area.end, Vector2(area.position.x, area.end.y)])

static func field_boundary(area: Rect2, entrance: Vector2, opening_width: float) -> PackedVector2Array:
	var points := corners(area)
	if entrance == Vector2.ZERO:
		points.append(points[0])
		return points
	var side := EDGE_NORMALS.find(entrance)
	var next := (side + 1) % 4
	var mouth := points[side].lerp(points[next], 0.5)
	var half_opening := points[side].direction_to(points[next]) * opening_width * 0.5
	var outline := PackedVector2Array([mouth + half_opening])
	for step in range(1, 5):
		outline.append(points[(side + step) % 4])
	outline.append(mouth - half_opening)
	return outline

static func sample_road(points: PackedVector2Array) -> PackedVector2Array:
	var curve := Curve2D.new()
	curve.bake_interval = 6.0
	for index in points.size():
		var at := points[index]
		var previous := points[maxi(0, index - 1)]
		var following := points[mini(points.size() - 1, index + 1)]
		var handle := previous.direction_to(following) * minf(at.distance_to(previous), at.distance_to(following)) * 0.28
		curve.add_point(at, -handle, handle)
	return curve.get_baked_points()

static func overlaps_road(area: Rect2) -> bool:
	for index in road_lines.size():
		var road := road_lines[index]
		# Include the shoulder and one pixel for the painted edge.
		var verge := area.grow(float(ROAD_WIDTHS[index]) * 0.5 + ROAD_SHOULDER + 1.0)
		for segment in range(1, road.size()):
			if _hits_rect(road[segment - 1], road[segment], verge):
				return true
	return false

static func field_approach(area: Rect2, occupied: Array[Rect2]) -> PackedVector2Array:
	var blockers: Array[Rect2] = []
	for bounds in occupied:
		blockers.append(bounds.grow(FIELD_ENTRANCE_WIDTH * 0.5))
	var nearest := INF
	var approach := PackedVector2Array()
	for normal: Vector2 in EDGE_NORMALS:
		var mouth := area.get_center() + normal * area.size * 0.5
		for road in road_lines:
			for segment in range(1, road.size()):
				var join := Geometry2D.get_closest_point_to_segment(mouth, road[segment - 1], road[segment])
				var depth := (join - mouth).dot(normal)
				if depth <= 0.0 or mouth.distance_to(join) >= nearest:
					continue
				var neck := mouth + normal * minf(6.0, depth * 0.5)
				var length := mouth.distance_to(neck) + neck.distance_to(join)
				if length < nearest and _clear_approach(join, neck, mouth, blockers):
					nearest = length
					approach = PackedVector2Array([join, neck, mouth])
	return approach

static func _bake_roads() -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	for points in ROADS:
		lines.append(sample_road(PackedVector2Array(points)))
	return lines

static func _clear_approach(join: Vector2, neck: Vector2, mouth: Vector2, blockers: Array[Rect2]) -> bool:
	for area in blockers:
		if _hits_rect(join, neck, area) or _hits_rect(neck, mouth, area):
			return false
	return true

static func _hits_rect(start: Vector2, finish: Vector2, area: Rect2) -> bool:
	if not area.intersects(Rect2(start, Vector2.ZERO).expand(finish), true):
		return false
	if area.has_point(start) or area.has_point(finish):
		return true
	var border := corners(area)
	for side in 4:
		if Geometry2D.segment_intersects_segment(start, finish, border[side], border[(side + 1) % 4]) != null:
			return true
	return false
