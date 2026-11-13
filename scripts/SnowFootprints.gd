extends Node2D

const LIFETIME := 3.8
const LIMIT := 16

class Footprint:
	var position: Vector2
	var angle: float
	var age := 0.0

	func _init(at: Vector2, heading: Vector2) -> void:
		position = at.round()
		angle = heading.angle() + PI * 0.5

var prints: Array[Footprint] = []

func _ready() -> void:
	z_as_relative = false
	z_index = -2
	set_process(false)

func leave(foot: Vector2, movement: Vector2, left: bool) -> void:
	var heading := movement.normalized()
	var offset := heading.orthogonal() * (2.5 if left else -2.5)
	prints.append(Footprint.new(foot + offset - heading * 2.0, heading))
	if prints.size() > LIMIT:
		prints.pop_front()
	set_process(true)
	queue_redraw()

func clear() -> void:
	prints.clear()
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	for mark in prints:
		mark.age += delta
	while not prints.is_empty() and prints.front().age >= LIFETIME:
		prints.pop_front()
	if prints.is_empty():
		set_process(false)
	queue_redraw()

func _draw() -> void:
	for mark in prints:
		var fade := 1.0 - smoothstep(0.5, LIFETIME, mark.age)
		draw_set_transform(mark.position, mark.angle)
		draw_rect(Rect2(-1.5, -3, 3, 3), Color(0.29, 0.42, 0.41, fade * 0.47))
		draw_rect(Rect2(-1, 1, 2, 2), Color(0.29, 0.42, 0.41, fade * 0.40))
		draw_rect(Rect2(-1.5, 3, 3, 1), Color(0.86, 0.92, 0.87, fade * 0.69))
