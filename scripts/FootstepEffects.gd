extends Node2D

const SNOW_FOOTPRINTS := preload("res://scripts/SnowFootprints.gd")
const DUST_SECONDS := 0.32
const SPLASH_SECONDS := 0.52
const SPRAY_SECONDS := 0.22
const MAX_STEPS := 12
const WATER_INK := Color("#c1ded0")
const DUST_INK := Color("#d3b78d")
const SPRAY := [Vector3(-7.4, 1.8, 3.8), Vector3(7.0, 2.2, 3.0), Vector3(1.3, -2.8, 3.2)]
const DUST := [Vector3(-2.2, 4.9, 1.9), Vector3(2.6, 4.2, 2.5), Vector3(0.4, 6.3, 1.3)]

class StepMark:
	var position: Vector2
	var heading: Vector2
	var water: PackedVector2Array
	var stones: Array[PackedVector2Array]
	var age := 0.0
	var duration: float

	func _init(at: Vector2, direction: Vector2, pool := PackedVector2Array(),
			obstacles: Array[PackedVector2Array] = []) -> void:
		position = at
		heading = direction
		water = pool
		stones = obstacles
		duration = DUST_SECONDS if water.is_empty() else SPLASH_SECONDS

var _marks: Array[StepMark] = []
@onready var snow_footprints := SNOW_FOOTPRINTS.new()

func _init() -> void:
	name = "FootstepEffects"
	z_as_relative = false
	z_index = -2

func _ready() -> void:
	snow_footprints.name = "SnowFootprints"
	add_child(snow_footprints)
	set_process(false)
	GameEvents.day_advanced.connect(clear.unbind(1))
	GameEvents.estate_room_changed.connect(clear.unbind(1))

func leave_snow(foot: Vector2, movement: Vector2, left: bool) -> void:
	snow_footprints.leave(foot, movement, left)

func lift_dust(foot: Vector2, movement: Vector2, left: bool) -> void:
	var heading := movement.normalized()
	if not heading.is_zero_approx():
		_add_mark(StepMark.new(_shoe(foot, heading, left), heading))

func splash(foot: Vector2, movement: Vector2, left: bool, water: PackedVector2Array,
		stones: Array[PackedVector2Array] = []) -> void:
	var heading := movement.normalized()
	if heading.is_zero_approx():
		return
	var shoe := _shoe(foot, heading, left)
	if not Geometry2D.is_point_in_polygon(shoe, water):
		if not Geometry2D.is_point_in_polygon(foot, water):
			return
		# A shallow edge can fall between the body anchor and the painted toe.
		shoe = foot.lerp(shoe, 0.5)
		if not Geometry2D.is_point_in_polygon(shoe, water):
			shoe = foot
	for stone in stones:
		if Geometry2D.is_point_in_polygon(shoe, stone):
			return
	_add_mark(StepMark.new(shoe, heading, water, stones))

func clear() -> void:
	_marks.clear()
	snow_footprints.clear()
	set_process(false)
	queue_redraw()

func _shoe(foot: Vector2, heading: Vector2, left: bool) -> Vector2:
	var spread := heading.orthogonal() * (2.5 if left else -2.5) * Vector2(1.0, 0.65)
	# The image places the soles below the collision anchor.
	return (foot + Vector2(0, 5.0) - heading * 1.5 + spread).snappedf(0.5)

func _add_mark(mark: StepMark) -> void:
	if _marks.size() == MAX_STEPS:
		_marks.pop_front()
	_marks.append(mark)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	for index in range(_marks.size() - 1, -1, -1):
		var mark := _marks[index]
		mark.age += delta
		if mark.age >= mark.duration:
			_marks.remove_at(index)
	if _marks.is_empty():
		set_process(false)
	queue_redraw()

func _draw() -> void:
	for mark in _marks:
		if mark.water.is_empty():
			_draw_dust(mark, mark.age / DUST_SECONDS)
		else:
			_draw_splash(mark, mark.age / SPLASH_SECONDS)

func _draw_dust(mark: StepMark, phase: float) -> void:
	var spread := 1.0 - (1.0 - phase) * (1.0 - phase)
	var alpha := (1.0 - smoothstep(0.06, 1.0, phase)) * 0.64
	for fleck: Vector3 in DUST:
		var at := mark.position - mark.heading * fleck.y * spread
		at += mark.heading.orthogonal() * fleck.x * spread * Vector2(1.0, 0.65)
		at.y -= fleck.z * sin(phase * PI * 0.75)
		var size := Vector2(1.65 if fleck.y < 5.0 else 1.0, 0.85)
		draw_rect(Rect2(at.snappedf(0.5) - size * 0.5, size), Color(DUST_INK, alpha))

func _draw_splash(mark: StepMark, phase: float) -> void:
	var radius := lerpf(1.8, 9.5, 1.0 - pow(1.0 - phase, 2.0))
	var alpha := (1.0 - smoothstep(0.14, 1.0, phase)) * 0.62
	_draw_wake(mark, radius, 0.16, 2.78, Color(WATER_INK, alpha))
	_draw_wake(mark, radius, 3.55, 5.86, Color(WATER_INK, alpha * 0.68))
	if mark.age >= SPRAY_SECONDS:
		return
	var flight := mark.age / SPRAY_SECONDS
	var spread := 1.0 - pow(1.0 - flight, 2.8)
	var lift := 4.0 * flight * (1.0 - flight)
	for drop: Vector3 in SPRAY:
		var at := mark.position + Vector2(drop.x, drop.y) * spread - mark.heading * flight
		at.y -= drop.z * lift
		var size := Vector2(1.10, 1.25)
		draw_rect(Rect2(at.snappedf(0.5) - size * 0.5, size), Color(WATER_INK, (1.0 - flight) * 0.90))

func _draw_wake(mark: StepMark, radius: float, start: float, finish: float, ink: Color) -> void:
	var stroke := PackedVector2Array()
	for index in 13:
		var angle := lerpf(start, finish, float(index) / 12.0)
		stroke.append(mark.position + Vector2.from_angle(angle) * radius * Vector2(1.0, 0.52))
	# Trim both the spread along the shore and the part that goes behind a stepping stone.
	var visible := Geometry2D.intersect_polyline_with_polygon(stroke, mark.water)
	for stone in mark.stones:
		var remaining: Array[PackedVector2Array] = []
		for part in visible:
			remaining.append_array(Geometry2D.clip_polyline_with_polygon(part, stone))
		visible = remaining
	for part in visible:
		draw_polyline(part, ink, 0.82)
