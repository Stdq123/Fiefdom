extends RefCounted

const TURN_DISTANCE := 4.0
const REJOIN_DISTANCE := 6.0
const DESTINATION_DISTANCE := 10.0

var frame: Node2D
var graph := AStar2D.new()
var roads: Array[Vector2i] = []
var clearance := PhysicsShapeQueryParameters2D.new()

func _init(tracks: Array, road_frame: Node2D, player: Player) -> void:
	frame = road_frame
	var ids := {}
	for track: Array in tracks:
		var previous := -1
		for point: Vector2 in track:
			if not ids.has(point):
				var id := graph.get_available_point_id()
				ids[point] = id
				graph.add_point(id, point)
			var current: int = ids[point]
			if previous >= 0:
				graph.connect_points(previous, current)
				roads.append(Vector2i(previous, current))
			previous = current
	var collider := player.get_node("CollisionShape2D") as CollisionShape2D
	clearance.shape = collider.shape
	clearance.collision_mask = player.collision_mask
	clearance.exclude = [player.get_rid()]

func _reachable_road(origin: Vector2) -> Dictionary:
	var entry := {}
	var best_distance := INF
	clearance.transform = Transform2D(0.0, frame.to_global(origin))
	var space := frame.get_world_2d().direct_space_state
	for edge in roads:
		var point := Geometry2D.get_closest_point_to_segment(origin, graph.get_point_position(edge.x), graph.get_point_position(edge.y))
		var distance := origin.distance_squared_to(point)
		if distance >= best_distance:
			continue
		clearance.motion = frame.to_global(point) - clearance.transform.origin
		if is_zero_approx(distance) or space.cast_motion(clearance)[0] >= 1.0:
			entry = {"edge": edge, "point": point}
			best_distance = distance
	return entry

func _add_road_entry(entry: Dictionary) -> int:
	var id := graph.get_available_point_id()
	var edge: Vector2i = entry.edge
	graph.add_point(id, entry.point)
	graph.connect_points(id, edge.x)
	graph.connect_points(id, edge.y)
	return id

func route_between(origin: Vector2, target: Vector2) -> PackedVector2Array:
	var from_road := _reachable_road(origin)
	var to_road := _reachable_road(target)
	if from_road.is_empty() or to_road.is_empty():
		return PackedVector2Array()
	var start := _add_road_entry(from_road)
	var finish := _add_road_entry(to_road)
	if from_road.edge == to_road.edge:
		graph.connect_points(start, finish)
	var path := graph.get_point_path(start, finish)
	graph.remove_point(start)
	graph.remove_point(finish)
	if path.is_empty():
		return path
	path.append(target)
	var points := PackedVector2Array([origin])
	for point in path:
		if not points[-1].is_equal_approx(point):
			points.append(point)
	return points

static func route_length(path: PackedVector2Array) -> float:
	if path.is_empty():
		return INF
	var length := 0.0
	for index in range(1, path.size()):
		length += path[index - 1].distance_to(path[index])
	return length

static func next_direction(path: PackedVector2Array, foot: Vector2) -> Vector2:
	if path.size() < 2:
		return Vector2.ZERO
	var next := 1
	var nearest := path[0]
	var distance_squared := INF
	# The cached route can start behind the walker between updates. Join its closest segment.
	for index in range(1, path.size()):
		var point := Geometry2D.get_closest_point_to_segment(foot, path[index - 1], path[index])
		var gap := foot.distance_squared_to(point)
		if gap < distance_squared:
			distance_squared = gap
			nearest = point
			next = index
	var remaining := sqrt(distance_squared) + nearest.distance_to(path[next])
	for index in range(next + 1, path.size()):
		remaining += path[index - 1].distance_to(path[index])
	if remaining <= DESTINATION_DISTANCE:
		return Vector2.ZERO
	if distance_squared > REJOIN_DISTANCE * REJOIN_DISTANCE:
		return foot.direction_to(nearest)
	for index in range(next, path.size()):
		if foot.distance_squared_to(path[index]) > TURN_DISTANCE * TURN_DISTANCE:
			return foot.direction_to(path[index])
	return Vector2.ZERO
