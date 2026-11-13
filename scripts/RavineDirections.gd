extends Node2D

signal changed

const LANDSCAPE := preload("res://scripts/Landscape.gd")
const ROAD_NETWORK := preload("res://scripts/RoadNetwork.gd")
const REJOIN_DISTANCE := 16.0
const ARRIVAL_DISTANCE := 10.0

var player: Player
var route := PackedVector2Array()
var destination_name := ""
var destination := Vector2.ZERO
var network: ROAD_NETWORK

func _ready() -> void:
	z_index = -2
	network = ROAD_NETWORK.new(LANDSCAPE.WILD_TRACKS, self, player)
	set_physics_process(false)

func follow(place: String, point: Vector2, market_destination := "") -> bool:
	var next := network.route_between(to_local(player.global_position), point)
	if next.is_empty():
		return false
	destination = point
	destination_name = place
	Global.market_trip_target = market_destination
	if place != Global.ravine_trip_target:
		Global.ravine_trip_target = ""
	_update_route(next)
	set_physics_process(true)
	return true

func clear() -> void:
	destination_name = ""
	Global.ravine_trip_target = ""
	Global.market_trip_target = ""
	route.clear()
	set_physics_process(false)
	queue_redraw()
	changed.emit()

func _physics_process(_delta: float) -> void:
	var origin := to_local(player.global_position)
	var actor := player.interaction_target
	var trip_in_reach := ((Global.ravine_trip_target == destination_name or destination_name in CreekTrap.PLACES) and is_instance_valid(actor)
		and to_local(actor.global_position).is_equal_approx(destination))
	if (origin.distance_to(destination) <= ARRIVAL_DISTANCE or trip_in_reach) and Global.market_trip_target.is_empty():
		clear()
	elif origin.distance_to(route[0]) >= REJOIN_DISTANCE:
		var next := network.route_between(origin, destination)
		if next.is_empty():
			clear()
		else:
			_update_route(next)

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
