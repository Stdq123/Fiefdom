extends CharacterBody2D
class_name Retainer

enum State { IDLE, MOVE, WORK }
const ARROW_SCENE := preload("res://scenes/Arrow.tscn")
const WATER_SOUND := preload("res://assets/audio/farm/retainer-water.wav")
const SOW_SOUND := preload("res://assets/audio/farm/sow.wav")
const HARVEST_SOUND := preload("res://assets/audio/farm/harvest.wav")
const WORK_GESTURES := {
	Global.FieldJob.WATER: ToolGesture.Action.WATER,
	Global.FieldJob.SOW: ToolGesture.Action.SOW,
	Global.FieldJob.HARVEST: ToolGesture.Action.HARVEST,
}
const NO_CELL := RetainerData.NO_ASSIGNMENT

@export var move_speed := 100.0
@export var data: RetainerData

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: NeighborMotion = $Sprite2D
@onready var tool_gesture: ToolGesture = $ToolGesture
@onready var hint: Label = $InteractionHint

var current_state := State.IDLE
var target_grid_pos := NO_CELL
var home_position := Vector2.ZERO
var guard_cooldown := 0.0
var work_left := 0.0
var field_job := Global.FieldJob.NONE
var last_heading := Vector2.LEFT
var observer: Player
var evening_seat := Vector2.INF
var evening_path: Array[Vector2] = []

func _ready() -> void:
	if data == null:
		data = RetainerData.new()
	sprite.set_art(data.name, data.get_appearance_texture())
	tool_gesture.sleeve = CharacterArt.neighbor_sleeve(data.name)
	home_position = global_position

func set_interaction_focused(focused: bool) -> void:
	hint.visible = focused
	if focused:
		hint.text = "%s · %s" % [data.name, GamepadInput.interact_key()]
	observer = get_tree().get_first_node_in_group("player") as Player if focused else null

func interact() -> void:
	GameEvents.retainer_interacted.emit(data)

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if evening_seat.is_finite():
		if get_parent().pavilion_rest.seat_for(data) != evening_seat:
			set_state(State.IDLE)
		elif is_instance_valid(observer) and observer.conversation_open:
			velocity = Vector2.ZERO
			_stand_at_stop()
			return
	match current_state:
		State.IDLE:
			if Engine.get_physics_frames() % 60 == 0:
				find_work()
		State.MOVE:
			_walk()
		State.WORK:
			work_left -= delta
			if work_left <= 0.0:
				_finish_field_work()
				set_state(State.IDLE)
	if data.duty == RetainerData.Duty.GUARD:
		_guard(delta)
	if current_state != State.MOVE:
		_stand_at_stop()

func _stand_at_stop() -> void:
	if current_state != State.WORK and not tool_gesture.visible and is_instance_valid(observer):
		sprite.face(observer.global_position - global_position)
	elif resting_at_pavilion():
		var pavilion: PavilionRest = get_parent().pavilion_rest
		sprite.face(pavilion.gathering_center() - position)
	sprite.stand(Vector2(0, 2) if resting_at_pavilion() else tool_gesture.body_lean)

func resting_at_pavilion() -> bool:
	return evening_seat.is_finite() and current_state == State.IDLE

func pavilion_note() -> String:
	if not evening_seat.is_finite():
		return ""
	if Global.has_rain():
		return "亭东雨棚 · 檐下避雨" if resting_at_pavilion() else "正往亭东雨棚避雨"
	return "南路亭 · 灯下歇脚" if resting_at_pavilion() else "正往南路亭"

func restore_evening() -> void:
	var seat: Vector2 = get_parent().pavilion_rest.seat_for(data)
	if seat.is_finite() and VisitorData.seconds_since(PavilionRest.rest_start()) >= 6.0 and _field_target() == NO_CELL:
		position = seat
		evening_seat = seat
		_stand_at_stop()

func resume_duty_at_dawn() -> void:
	if evening_seat.is_finite():
		global_position = home_position
		set_state(State.IDLE)

func _guard(delta: float) -> void:
	var player: Player = get_parent().player
	if player.combat_paused():
		return
	guard_cooldown = maxf(0.0, guard_cooldown - delta)
	if guard_cooldown > 0.0:
		return
	var target: Node2D
	var nearest := 185.0
	for enemy in get_tree().get_nodes_in_group("estate_raiders"):
		if enemy.is_queued_for_deletion():
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < nearest:
			nearest = distance
			target = enemy
	if target:
		var aim := global_position.direction_to(target.global_position)
		var arrow = ARROW_SCENE.instantiate()
		arrow.position = position
		arrow.direction = aim
		arrow.rotation = aim.angle()
		arrow.guard_name = data.name
		get_parent().add_child(arrow)
		sprite.face(aim)
		tool_gesture.perform(ToolGesture.Action.BOW, aim)
		guard_cooldown = 1.25

func set_state(next: State) -> void:
	current_state = next
	if next == State.IDLE:
		velocity = Vector2.ZERO
		if tool_gesture.carrying or work_left > 0.0:
			tool_gesture.clear()
		work_left = 0.0
		sprite.stand(tool_gesture.body_lean)
		find_work()
	elif next == State.WORK:
		velocity = Vector2.ZERO
		work_left = 1.0 / maxf(data.get_work_efficiency(), 0.1)
		sprite.face(last_heading)
		sprite.stand()
		tool_gesture.perform(WORK_GESTURES[field_job], last_heading, work_left)

func _finish_field_work() -> void:
	var world := get_parent()
	var sound: AudioStream
	match field_job:
		Global.FieldJob.WATER:
			if world.water_crop(target_grid_pos):
				sound = WATER_SOUND
		Global.FieldJob.SOW:
			if world.sow_crop(target_grid_pos, Global.planned_field_seed(target_grid_pos)):
				sound = SOW_SOUND
		Global.FieldJob.HARVEST:
			if world.harvest_crop(target_grid_pos, self):
				sound = HARVEST_SOUND
	if sound:
		AudioManager.play_world_sfx(sound, self, -9.0, 190.0)
	else:
		tool_gesture.clear()

func find_work() -> void:
	var world := get_parent()
	if not world.has_method("find_work_crop"):
		return
	target_grid_pos = _field_target()
	if target_grid_pos != NO_CELL:
		_leave_pavilion()
		_walk_to(world.to_global(world.get_crop_world_pos(target_grid_pos)))
		return
	var seat: Vector2 = world.pavilion_rest.seat_for(data)
	if seat.is_finite():
		if evening_seat != seat or not position.is_equal_approx(seat):
			evening_seat = seat
			evening_path = world.path_to_pavilion_seat(position, seat)
			_walk_next_pavilion_step()
			GameEvents.retainer_location_changed.emit()
		return
	_leave_pavilion()
	if global_position.distance_to(home_position) > navigation_agent.target_desired_distance:
		_walk_to(home_position)

func _field_target() -> Vector2i:
	if data.works_fields():
		return get_parent().find_work_crop(self)
	return NO_CELL

func _leave_pavilion() -> void:
	if evening_seat.is_finite():
		evening_seat = Vector2.INF
		evening_path.clear()
		GameEvents.retainer_location_changed.emit()

func _walk_next_pavilion_step() -> void:
	_walk_to(get_parent().to_global(evening_path.pop_front()))

func _walk_to(destination: Vector2) -> void:
	navigation_agent.target_position = destination
	current_state = State.MOVE

func _walk() -> void:
	var next_step := navigation_agent.get_next_path_position()
	if navigation_agent.is_navigation_finished():
		if not evening_path.is_empty():
			_walk_next_pavilion_step()
			return
		var arrived_at_pavilion := evening_seat.is_finite()
		if arrived_at_pavilion:
			position = evening_seat
		field_job = get_parent().crop_job(self, target_grid_pos) if target_grid_pos != NO_CELL else Global.FieldJob.NONE
		if field_job != Global.FieldJob.NONE:
			set_state(State.WORK)
		else:
			set_state(State.IDLE)
			if arrived_at_pavilion and resting_at_pavilion():
				GameEvents.retainer_location_changed.emit()
		return
	last_heading = global_position.direction_to(next_step)
	velocity = last_heading * move_speed
	move_and_slide()
	var step_height := sprite.walk(get_position_delta())
	if target_grid_pos != NO_CELL and Global.field_job(data, target_grid_pos) == Global.FieldJob.WATER:
		tool_gesture.carry_pail(last_heading, step_height)
