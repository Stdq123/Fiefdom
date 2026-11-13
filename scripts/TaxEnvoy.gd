extends Node2D

const MOTION_SHEET := preload("res://assets/characters/envoy-motion.svg")
const ROAD_OFFSET := Vector2(74, -16)
const WALK_SPEED := 52.0

@onready var motion: NeighborMotion = $Motion
@onready var hint: Label = $InteractionHint

var waiting_place: Vector2

func _ready() -> void:
	waiting_place = position
	motion.set_motion_sheet(MOTION_SHEET)
	GameEvents.tax_reform_triggered.connect(_arrive)
	GameEvents.tax_reform_choice_made.connect(_depart.unbind(1))
	if Global.tax_council_waiting():
		_wait_at_court()

func _arrive() -> void:
	position = waiting_place + ROAD_OFFSET
	show()
	_walk_to(waiting_place).finished.connect(_wait_at_court)

func _wait_at_court() -> void:
	show()
	motion.stand()
	motion.face(Vector2.DOWN)
	set_interaction_focused(false)
	hint.show()
	add_to_group("interactable")

func _depart() -> void:
	remove_from_group("interactable")
	hint.hide()
	_walk_to(waiting_place + ROAD_OFFSET).finished.connect(hide)

func _walk_to(target: Vector2) -> Tween:
	var walk := create_tween()
	walk.tween_method(_step, position, target, position.distance_to(target) / WALK_SPEED)
	return walk

func _step(point: Vector2) -> void:
	motion.walk(point - position)
	position = point

func set_interaction_focused(focused: bool) -> void:
	hint.text = "召简 · %s 议税" % GamepadInput.interact_key() if focused else "召简 · 候议"
	hint.modulate = Color("#ffe1a2") if focused else Color("#dac798")

func interact() -> void:
	motion.face(get_parent().player.global_position - global_position)
	GameEvents.tax_envoy_interacted.emit()
