extends RefCounted
class_name EstateLayout

const TILE_ORIGIN := Vector2(16, 24)
const TILE_SIZE := 16.0
const FIELD_ENTRANCE_WIDTH := TILE_SIZE
const EDGE_NORMALS := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]

const HALL_FOOT := Vector2i(-12, 26)
const HALL_BASE := Rect2(-51, -21, 102, 23)
const HALL_LANDING := Rect2(Vector2(HALL_FOOT) + Vector2(-22, 1), Vector2(44, 15))
const SILK_SHED_FOOT := Vector2(-29, 120)
const SILK_SHED_BASE := Rect2(-31, -14, 62, 14)
const SOUTH_PAVILION := Vector2(77, 247)
const PAVILION_SIZE := Vector2(72, 60)
const PAVILION_BOUNDS := Rect2(SOUTH_PAVILION + Vector2(-36, -56), PAVILION_SIZE)
const DRIVING_START := Vector2(279, 152)
const DRIVING_BAY := Rect2(DRIVING_START - Vector2(38, 28), Vector2(57, 41))
const DRIVING_PARKING := Rect2(30, 229, 28, 24)
const LANDMARKS := [
	Rect2(Vector2(HALL_FOOT) + HALL_BASE.position, HALL_BASE.size),
	HALL_LANDING,
	Rect2(SILK_SHED_FOOT + SILK_SHED_BASE.position, SILK_SHED_BASE.size),
	PAVILION_BOUNDS,
	DRIVING_BAY,
	DRIVING_PARKING,
]

const FIELD_TURN := Vector2(107, 165)
const EAST_LANE_JUNCTION := Vector2(29, 152)
const PAVILION_TURN := Vector2(44, 241)
const SOUTH_LANE := [
	Vector2(4, 43), Vector2(1, 72), Vector2(0, 101), Vector2(8, 128), EAST_LANE_JUNCTION,
	Vector2(46, 177), Vector2(50, 205), PAVILION_TURN, Vector2(23, 288),
]
const EAST_LANE := [
	EAST_LANE_JUNCTION, Vector2(62, 162), FIELD_TURN, Vector2(150, 164), Vector2(194, 160),
	Vector2(243, 153), Vector2(293, 150), Vector2(336, 151),
]
const ROADS := [
	[Vector2(-504, -33), Vector2(-397, -31), Vector2(-343, -28), Vector2(-308, -24), Vector2(-273, -21), Vector2(-249, -19),
		Vector2(-205, 0), Vector2(-140, 16), Vector2(-90, 28), Vector2(-40, 41),
		Vector2(4, 43), Vector2(39, 38), Vector2(91, 32), Vector2(148, 27), Vector2(213, 20),
		Vector2(283, 12), Vector2(345, 7), Vector2(400, 8), Vector2(460, 0), Vector2(516, 0),
		Vector2(579, -3), Vector2(676, 6)],
	SOUTH_LANE,
	EAST_LANE,
	[Vector2(-45, 127), Vector2(-18, 128), Vector2(8, 128)],
	[Vector2(HALL_FOOT) + Vector2(0, 17), Vector2(HALL_FOOT) + Vector2(0, 9)],
]
const ROAD_WIDTHS := [32.0, 22.0, 18.0, 16.0, 30.0]
const ROAD_SHOULDER := 2.5

static var road_lines: Array[PackedVector2Array] = _bake_roads()

static func field_bounds(cell: Vector2i) -> Rect2:
	var size := Vector2.ONE * TILE_SIZE * 3.0
	var center := TILE_ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_SIZE
	return Rect2(center - size * 0.5, size)

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
