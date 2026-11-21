extends CharacterBody2D
class_name Retainer

enum State { IDLE, MOVE, WORK }
const ARROW_SCENE := preload("res://scenes/Arrow.tscn")
const TILL_SOUND := preload("res://assets/audio/farm/till.wav")
const WATER_SOUND := preload("res://assets/audio/farm/retainer-water.wav")
const SOW_SOUND := preload("res://assets/audio/farm/sow.wav")
const HARVEST_SOUND := preload("res://assets/audio/farm/harvest.wav")
const WORK_GESTURES := {
	Global.FieldJob.TILL: ToolGesture.Action.TILL,
	Global.FieldJob.WATER: ToolGesture.Action.WATER,
	Global.FieldJob.SOW: ToolGesture.Action.SOW,
	Global.FieldJob.HARVEST: ToolGesture.Action.HARVEST,
}
const NO_CELL := RetainerData.NO_ASSIGNMENT
const FIELD_STANCE_DISTANCE := 15.0
const STANCE_SETTLE_TIME := 0.16

@export var move_speed := 100.0
@export var data: RetainerData

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var art: Node2D = $Art
@onready var sprite: NeighborMotion = $Art/Sprite2D
@onready var tool_gesture: ToolGesture = $Art/ToolGesture
@onready var hint: Label = $Art/InteractionHint

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
var pavilion_partner: Node2D:
	set(value):
		pavilion_partner = value
		if is_node_ready() and resting_at_pavilion():
			_stand_at_stop()

var _stance := Vector2.INF
var _stance_start := Vector2.ZERO
var _work_point := Vector2.INF
var _work_duration := 0.0
var _raise_carried_tool := false
var _carried_tool_pose := Transform2D.IDENTITY
var _carried_tool_flipped := false

func _ready() -> void:
	if data == null:
		data = RetainerData.new()
	sprite.set_motion_sheet(CharacterArt.retainer_motion(data.name, data.school, data.visitor_appearance),
		CharacterArt.WORKER_COLUMNS, data.name)
	tool_gesture.visibility_changed.connect(func(): sprite.hands_busy = tool_gesture.visible)
	tool_gesture.sleeve = CharacterArt.retainer_sleeve(data.name, data.school, data.visitor_appearance)
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
			_walk(delta)
		State.WORK:
			if _advance_field_pose(delta):
				_finish_field_work()
				set_state(State.IDLE)
	if data.duty == RetainerData.Duty.GUARD:
		_guard(delta)
	if current_state == State.IDLE:
		if not tool_gesture.visible:
			art.position = art.position.move_toward(Vector2.ZERO, move_speed * delta)
		_stand_at_stop()

func _stand_at_stop() -> void:
	var on_mat := resting_at_pavilion()
	if on_mat and is_instance_valid(pavilion_partner):
		sprite.face(pavilion_partner.global_position - global_position)
	elif current_state != State.WORK and not tool_gesture.visible and is_instance_valid(observer):
		sprite.face(observer.global_position - global_position)
	elif on_mat:
		var pavilion: PavilionRest = get_parent().pavilion_rest
		sprite.face(pavilion.gathering_center() - position)
	if on_mat:
		art.position = Vector2.ZERO
		sprite.sit(tool_gesture.sleeve)
	else:
		sprite.stand(tool_gesture.body_lean, tool_gesture.work_pose())

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
		_stance = Vector2.INF
		if tool_gesture.carrying or work_left > 0.0:
			tool_gesture.clear()
		work_left = 0.0
		sprite.stand(tool_gesture.body_lean, tool_gesture.work_pose())
		find_work()
	elif next == State.WORK:
		velocity = Vector2.ZERO
		_raise_carried_tool = tool_gesture.carrying and tool_gesture.frame == WORK_GESTURES[field_job]
		if _raise_carried_tool:
			_carried_tool_pose = tool_gesture.transform
			_carried_tool_flipped = tool_gesture.flip_h
		_work_duration = 1.0 / maxf(data.get_work_efficiency(), 0.1)
		work_left = _work_duration
		var world := get_parent()
		_work_point = world.to_global(world.get_crop_world_pos(target_grid_pos))
		if not _stance.is_finite():
			_stance = global_position
			if _stance.distance_to(_work_point) <= ToolGesture.FIELD_REACH:
				_stance = _stance_for_plot(_work_point)
		_stance_start = art.global_position
		_advance_field_pose(0.0)

func _stance_for_plot(plot: Vector2) -> Vector2:
	var toward := global_position.direction_to(plot)
	if toward.is_zero_approx():
		toward = last_heading if not last_heading.is_zero_approx() else Vector2.UP
	# Seen from behind, the actor's head would cover the plant directly ahead.
	if toward.y < -0.8 and absf(toward.x) < 0.56:
		var side := -1.0 if toward.x < 0.0 else 1.0
		toward = Vector2(0.56 * side, -0.83).normalized()
	return plot - toward * FIELD_STANCE_DISTANCE

func _advance_field_pose(delta: float) -> bool:
	work_left = maxf(0.0, work_left - delta)
	var time := _work_duration - work_left
	var settled := smoothstep(0.0, minf(STANCE_SETTLE_TIME, _work_duration * 0.24), time)
	var previous_foot := art.global_position
	art.global_position = _stance_start.lerp(_stance, settled)
	var facing := _stance.direction_to(_work_point)
	var sample_time := maxf(_work_duration, 0.01) - work_left
	tool_gesture.show_sample(WORK_GESTURES[field_job], facing, _work_duration, sample_time, _work_point)
	var moved := art.global_position.distance_to(previous_foot)
	if settled < 1.0 and moved > 0.04:
		var rise := sprite.walk(facing * moved)
		tool_gesture.position.y += rise
	else:
		sprite.face(facing)
		_stand_at_stop()
	if _raise_carried_tool and settled < 1.0:
		var carried := _carried_tool_pose
		if _carried_tool_flipped != tool_gesture.flip_h:
			carried = Transform2D(-carried.get_rotation(), carried.origin * Vector2(-1.0, 1.0))
		tool_gesture.transform = carried.interpolate_with(tool_gesture.transform, settled)
	return work_left <= 0.0

func _finish_field_work() -> void:
	var world := get_parent()
	var sound: AudioStream
	match field_job:
		Global.FieldJob.TILL:
			if Global.field_job(data, target_grid_pos) == Global.FieldJob.TILL and world.till_plot(target_grid_pos):
				sound = TILL_SOUND
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
		tool_gesture.set_process(true)
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
	_stance = Vector2.INF
	navigation_agent.target_position = destination
	current_state = State.MOVE

func _walk(delta: float) -> void:
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
	var previous_foot := art.global_position
	move_and_slide()
	# Follow the ordinary navigation path while the visible feet plant beside the crop.
	var plot := navigation_agent.target_position
	if not _stance.is_finite() and target_grid_pos != NO_CELL and global_position.distance_to(plot) <= FIELD_STANCE_DISTANCE:
		_stance = _stance_for_plot(plot)
	var next_foot := _stance if _stance.is_finite() else global_position
	art.global_position = previous_foot.move_toward(next_foot, move_speed * 1.2 * delta)
	_show_approach(art.global_position - previous_foot, plot)

func _show_approach(visible_step: Vector2, plot: Vector2) -> void:
	var step_height := sprite.walk(visible_step)
	var job := Global.field_job(data, target_grid_pos) if target_grid_pos != NO_CELL else Global.FieldJob.NONE
	if job == Global.FieldJob.NONE:
		if tool_gesture.carrying:
			tool_gesture.clear()
		return
	var facing := visible_step if sprite.walking else last_heading
	if not sprite.walking and _stance.is_finite():
		facing = _stance.direction_to(plot)
		sprite.face(facing)
	var swing := sin(sprite.walk_distance * TAU / (4.0 * sprite.step_length))
	tool_gesture.carry_field_tool(WORK_GESTURES[job], facing, step_height, swing)
