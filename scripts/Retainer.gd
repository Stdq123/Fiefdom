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
var observer: Node2D

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
	observer = get_tree().get_first_node_in_group("player") as Node2D if focused else null

func interact() -> void:
	GameEvents.retainer_interacted.emit(data)

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
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
		if current_state == State.IDLE and not tool_gesture.visible and is_instance_valid(observer):
			sprite.face(observer.global_position - global_position)
		sprite.stand(tool_gesture.body_lean)

func _guard(delta: float) -> void:
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
	target_grid_pos = NO_CELL
	if data.duty in [RetainerData.Duty.FIELD, RetainerData.Duty.HARVEST]:
		target_grid_pos = world.find_work_crop(self)
	if target_grid_pos != NO_CELL:
		_walk_to(world.to_global(world.get_crop_world_pos(target_grid_pos)))
	elif global_position.distance_to(home_position) > navigation_agent.target_desired_distance:
		_walk_to(home_position)

func _walk_to(destination: Vector2) -> void:
	navigation_agent.target_position = destination
	current_state = State.MOVE

func _walk() -> void:
	var next_step := navigation_agent.get_next_path_position()
	if navigation_agent.is_navigation_finished():
		field_job = get_parent().crop_job(self, target_grid_pos) if target_grid_pos != NO_CELL else Global.FieldJob.NONE
		if field_job != Global.FieldJob.NONE:
			set_state(State.WORK)
		else:
			set_state(State.IDLE)
		return
	last_heading = global_position.direction_to(next_step)
	velocity = last_heading * move_speed
	move_and_slide()
	var step_height := sprite.walk(get_position_delta())
	if target_grid_pos != NO_CELL and data.duty == RetainerData.Duty.FIELD and Global.field_crop_is_dry(target_grid_pos):
		tool_gesture.carry_pail(last_heading, step_height)
