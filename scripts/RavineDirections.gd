extends Node2D

signal changed

const LANDSCAPE := preload("res://scripts/Landscape.gd")
const REJOIN_DISTANCE := 16.0
const ARRIVAL_DISTANCE := 10.0

var player: Player
var route := PackedVector2Array()
var destination_name := ""
var destination := Vector2.ZERO
var graph := AStar2D.new()
var roads: Array[Vector2i] = []
var clearance := PhysicsShapeQueryParameters2D.new()

func _ready() -> void:
	z_index = -2
	var ids := {}
	for track in LANDSCAPE.WILD_TRACKS:
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
	set_physics_process(false)

func follow(place: String, point: Vector2) -> bool:
	var next := _route_between(to_local(player.global_position), point)
	if next.is_empty():
		return false
	destination = point
	destination_name = place
	Global.market_trip_target = ""
	if place != Global.ravine_trip_target:
		Global.ravine_trip_target = ""
	_update_route(next)
	set_physics_process(true)
	return true

func clear() -> void:
	destination_name = ""
	Global.ravine_trip_target = ""
	route.clear()
	set_physics_process(false)
	queue_redraw()
	changed.emit()

func _physics_process(_delta: float) -> void:
	var origin := to_local(player.global_position)
	var actor := player.interaction_target
	var trip_in_reach := ((Global.ravine_trip_target == destination_name or destination_name in CreekTrap.PLACES) and is_instance_valid(actor)
		and to_local(actor.global_position).is_equal_approx(destination))
	if origin.distance_to(destination) <= ARRIVAL_DISTANCE or trip_in_reach:
		clear()
	elif origin.distance_to(route[0]) >= REJOIN_DISTANCE:
		var next := _route_between(origin, destination)
		if next.is_empty():
			clear()
		else:
			_update_route(next)

func _reachable_road(origin: Vector2) -> Dictionary:
	var entry := {}
	var best_distance := INF
	clearance.transform = Transform2D(0.0, to_global(origin))
	var space := get_world_2d().direct_space_state
	for edge in roads:
		var point := Geometry2D.get_closest_point_to_segment(origin, graph.get_point_position(edge.x), graph.get_point_position(edge.y))
		var distance := origin.distance_squared_to(point)
		if distance >= best_distance:
			continue
		clearance.motion = to_global(point) - clearance.transform.origin
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

func _route_between(origin: Vector2, target: Vector2) -> PackedVector2Array:
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

func _update_route(next: PackedVector2Array) -> void:
	route = next
	queue_redraw()
	changed.emit()

func _draw() -> void:
	for index in range(1, route.size()):
		draw_dashed_line(route[index - 1], route[index], Color("#3c3a29b0"), 3.5, 5.5)
		draw_dashed_line(route[index - 1], route[index], Color("#efd28edb"), 1.8, 5.5)
	if not route.is_empty():
		draw_arc(destination, 8.0, 0.0, TAU, 24, Color("#efd28e"), 1.5, true)
