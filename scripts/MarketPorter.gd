extends Node2D

const ART := preload("res://assets/characters/market-porter.svg")
# Map position followed by the fraction of the day. Repeated positions are work stops.
const ROUTE := [
	Vector3(-199, 42, 0.0), Vector3(-178, 43, 0.006),
	Vector3(-162, 36, 0.014), Vector3(-162, 36, 0.235),
	Vector3(-130, 41, 0.242), Vector3(-78, 48, 0.254),
	Vector3(-16, 59, 0.266), Vector3(-16, 59, 0.670),
	Vector3(46, 60, 0.684), Vector3(103, 59, 0.698),
	Vector3(154, 49, 0.710), Vector3(216, 35, 0.725),
	Vector3(425, 35, 0.774),
]

@onready var body: NeighborMotion = $Body

func _ready() -> void:
	body.set_motion_sheet(ART)
	_follow_clock(false)

func _process(_delta: float) -> void:
	_follow_clock(true)

func _follow_clock(animate: bool) -> void:
	var progress := Global.day_progress
	visible = progress <= ROUTE.back().z
	if not visible:
		return
	var segment := 1
	while progress > ROUTE[segment].z:
		segment += 1
	var start: Vector3 = ROUTE[segment - 1]
	var finish: Vector3 = ROUTE[segment]
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
