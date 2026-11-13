extends Node2D

const ART := preload("res://assets/characters/market-porter.svg")
const LAYOUT := preload("res://scripts/WestMarketLayout.gd")
const GRAIN_STOP := Vector2(-355, 134)
const FISH_STOP := Vector2(-129, -90)
const NET_START := CreekFish.ORDER_PICKUP - 0.045
const AT_BASIN := CreekFish.ORDER_PICKUP - 0.023
const LEAVE_BASIN := 0.706
const LEAVE_MARKET := 0.845

@onready var body: NeighborMotion = $Body
@onready var creel: Sprite2D = $Creel

var route := PackedVector3Array()

func _ready() -> void:
	body.set_motion_sheet(ART)
	var fork := LAYOUT.MAIN_ROAD.find(LAYOUT.FISH_JUNCTION)
	var fish_lane := LAYOUT.FISH_LANE.slice(1, -1)
	_append_leg([Vector2(-396, 145), GRAIN_STOP], 0.0, 0.014)
	_append_leg([GRAIN_STOP] + LAYOUT.MAIN_ROAD.slice(0, fork + 1) + fish_lane + [FISH_STOP], 0.235, 0.324)
	fish_lane.reverse()
	var apron := Vector2(-171, -96)
	_append_leg([FISH_STOP, apron, LAYOUT.FISH_PICKUP], NET_START, AT_BASIN)
	_append_leg([LAYOUT.FISH_PICKUP, apron] + fish_lane + LAYOUT.MAIN_ROAD.slice(fork) + [LAYOUT.EAST_OUTSIDE],
		LEAVE_BASIN, LEAVE_MARKET)
	_follow_clock(false)

func _append_leg(points: Array, start: float, finish: float) -> void:
	var distances := PackedFloat32Array([0.0])
	for index in range(1, points.size()):
		distances.append(distances[-1] + points[index - 1].distance_to(points[index]))
	for index in points.size():
		var foot: Vector2 = points[index]
		var watch := lerpf(start, finish, distances[index] / distances[-1])
		route.append(Vector3(foot.x, foot.y, watch))

func _process(_delta: float) -> void:
	_follow_clock(true)

func _follow_clock(animate: bool) -> void:
	var progress := Global.day_progress
	visible = progress <= route[-1].z
	if not visible:
		return
	creel.visible = progress >= CreekFish.ORDER_PICKUP and Global.fish_order_for_porter()
	var segment := 1
	while progress > route[segment].z:
		segment += 1
	var start := route[segment - 1]
	var finish := route[segment]
	var from := Vector2(start.x, start.y)
	var to := Vector2(finish.x, finish.y)
	var point := from.lerp(to, inverse_lerp(start.z, finish.z, progress))
	var movement := point - position
	position = point
	if animate and movement.length_squared() > 0.0016:
		body.walk(movement)
	else:
		body.stand()
		body.face(Vector2.UP if from == to else to - from)
	creel.position.x = -8.0 if body.flip_h else 8.0
