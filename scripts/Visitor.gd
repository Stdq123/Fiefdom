extends CharacterBody2D
class_name Visitor

signal activity_reached

const WALK_SPEED := 58.0
const TASK_INTERVAL := 4.8
const TASK_DURATION := 0.9

var data: VisitorData
var gathering_guest := false
var observer: Player
var activity := VisitorData.VisitActivity.NONE
var visit_path := PackedVector2Array()
var next_stop := 0
var activity_focus := Vector2.ZERO
var task_time := 0.0

var walking_to_stop: bool:
	get: return next_stop < visit_path.size()

@onready var sprite: NeighborMotion = $Sprite2D
@onready var hint: Label = $InteractionHint

func _ready() -> void:
	var fallback := data.get_appearance_texture() if data else CharacterArt.visitor(VisitorData.School.CONFUCIAN)
	sprite.set_art(data.name if data else "", fallback)
	hint.visible = data != null
	set_interaction_focused(false)

func set_interaction_focused(focused: bool) -> void:
	observer = get_tree().get_first_node_in_group("player") as Player if focused else null
	if not walking_to_stop:
		_face_stop()
	_update_pose_processing()
	_update_hint()

func go_to_activity(next: VisitorData.VisitActivity, path: PackedVector2Array, look_at: Vector2, walk_in: bool) -> void:
	activity = next
	visit_path = path
	activity_focus = look_at
	next_stop = 0
	task_time = 0.0
	if not walk_in:
		position = path[-1]
		next_stop = path.size()
		_face_stop()
	_update_pose_processing()
	_update_hint()

func visit_location() -> String:
	return data.meeting_place if activity == VisitorData.VisitActivity.NONE else VisitorData.ACTIVITY_STOPS[activity].place

func visit_note() -> String:
	if walking_to_stop:
		return "正往%s" % visit_location()
	if activity != VisitorData.VisitActivity.NONE:
		return "%s · %s" % [visit_location(), _activity_task()]
	return visit_location()

func resting_at_pavilion() -> bool:
	return activity == VisitorData.VisitActivity.PAVILION_REST and not walking_to_stop

func _activity_task() -> String:
	if resting_at_pavilion() and Global.has_rain():
		return "檐下避雨"
	return VisitorData.ACTIVITY_STOPS[activity].task

func _update_pose_processing() -> void:
	set_physics_process(activity != VisitorData.VisitActivity.NONE or (is_instance_valid(observer) and sprite.directional))

func _update_hint() -> void:
	if data:
		var focused := is_instance_valid(observer)
		hint.text = data.name
		if focused:
			hint.text += " · " + GamepadInput.interact_key()
		elif activity != VisitorData.VisitActivity.NONE and not walking_to_stop:
			hint.text += " · " + _activity_task()
		hint.modulate = Color("#f6d493") if focused else Color.WHITE

func _physics_process(delta: float) -> void:
	if not walking_to_stop:
		_idle_at_stop(delta)
	elif is_instance_valid(observer) and observer.conversation_open:
		velocity = Vector2.ZERO
		sprite.stand()
		_face_stop()
	else:
		_walk_to_stop(delta)

func _idle_at_stop(delta: float) -> void:
	_face_stop()
	if activity == VisitorData.VisitActivity.NONE:
		return
	if resting_at_pavilion():
		sprite.stand(Vector2(0, 2))
		return
	if is_instance_valid(observer):
		sprite.stand()
		return
	task_time = fposmod(task_time + delta, TASK_INTERVAL)
	var bend := sin(PI * clampf(task_time / TASK_DURATION, 0.0, 1.0)) * 2.0
	var look := position.direction_to(activity_focus)
	sprite.stand((Vector2(look.x, 0.6) * bend).round())

func _walk_to_stop(delta: float) -> void:
	var offset := visit_path[next_stop] - position
	if offset.length_squared() <= 0.25:
		position = visit_path[next_stop]
		next_stop += 1
		if not walking_to_stop:
			velocity = Vector2.ZERO
			sprite.stand()
			_face_stop()
			_update_pose_processing()
			_update_hint()
			activity_reached.emit()
		return
	velocity = offset.limit_length(WALK_SPEED * delta) / delta
	move_and_slide()
	sprite.walk(get_position_delta())

func _face_stop() -> void:
	if is_instance_valid(observer):
		var toward := observer.global_position - global_position
		if toward.length_squared() > 4.0:
			sprite.face(toward)
	elif activity != VisitorData.VisitActivity.NONE:
		sprite.face(activity_focus - position)
	else:
		sprite.face(Vector2.DOWN)

func interact() -> void:
	if not data or data.is_recruited:
		return
	if gathering_guest:
		GameEvents.gathering_guest_interacted.emit(data)
	else:
		GameEvents.visitor_interacted.emit(data)
