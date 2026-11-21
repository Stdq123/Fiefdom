extends CharacterBody2D

class_name Player

signal footstep(world_position: Vector2)

const SPEED = 100.0
const CART_SPEED := 145.0
const CART_ACCELERATION := 295.0
const CART_BRAKING := 390.0
const WALK_START := NeighborMotion.STEP_LENGTH * 3.0
const WALK_CYCLE := NeighborMotion.STEP_LENGTH * 4.0
const MIN_WALK_DISTANCE := 0.05
const CAMERA_ZOOMS := [1.5, 2.0, 3.0]

# Simple FSM
enum State { IDLE, RUN, TOOL_USE }
enum Facing { FRONT, BACK, PROFILE }
const Action = ToolGesture.Action
var current_state = State.IDLE

@onready var sprite: Sprite2D = $Sprite2D
@onready var tool_gesture: ToolGesture = $ToolGesture
@onready var silk_hands: SilkWorkHands = $SilkWorkHands
@onready var training_cart: TrainingCart = $TrainingCart
@onready var bow_target: Node2D = $BowTarget
@onready var camera: Camera2D = $Camera2D
@onready var meal_button: Button = $MealUI/MealButton
@onready var interaction_prompt: Control = $InteractionLayer/InteractionPrompt
@onready var _standing_pose := StandingPose.new(sprite)

var shake_strength: float = 0.0
var shake_decay: float = 5.0
var facing_row := Facing.FRONT
var facing_left := false
var walk_distance := WALK_START
var hurt_tween: Tween
var interaction_target: Node2D
var conversation_open := false
var resting := false
var seated: bool:
	get: return _seat_surface != SeatedPose.Surface.STANDING
var menu_open := false
var meal_controls_blocked := false
var bow_pointer := Vector2.INF
var _seat_surface := SeatedPose.Surface.STANDING
var _seated_art: SeatedPose
var _standing_free := false

var arrow_scene = preload("res://scenes/Arrow.tscn")

func _ready() -> void:
	add_to_group("player")
	interaction_prompt.walker = self
	_apply_camera_zoom()
	bow_target.draw.connect(_draw_bow_target)
	get_window().mouse_exited.connect(_clear_bow_pointer)
	get_viewport().size_changed.connect(_clear_bow_pointer)
	meal_button.pressed.connect(_eat_travel_meal)
	GameEvents.travel_meal_changed.connect(_refresh_travel_meal)
	_refresh_travel_meal()
	GameEvents.attire_changed.connect(_refresh_attire)
	_refresh_attire()
	GamepadInput.changed.connect(_refresh_interaction_hint)
	GamepadInput.changed.connect(_refresh_travel_meal)
	Preferences.bindings_changed.connect(_refresh_interaction_hint)
	Preferences.bindings_changed.connect(_refresh_travel_meal)

func _refresh_interaction_hint() -> void:
	if is_instance_valid(interaction_target) and interaction_target.has_method("set_interaction_focused"):
		interaction_target.set_interaction_focused(true)

func _refresh_attire() -> void:
	sprite.texture = PlayerAttire.texture(Global.attire_id)
	tool_gesture.sleeve = PlayerAttire.CATALOG[Global.attire_id].sleeve
	tool_gesture.queue_redraw()

static func input_direction() -> Vector2:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction.is_zero_approx():
		direction = Input.get_vector(KeyBindings.LEFT, KeyBindings.RIGHT, KeyBindings.UP, KeyBindings.DOWN)
	return GamepadInput.move_direction() if direction.is_zero_approx() else direction

func world_controls_blocked() -> bool:
	return combat_paused() or resting

func combat_paused() -> bool:
	return conversation_open or menu_open or MapTravel.active

func _physics_process(delta: float) -> void:
	var direction := input_direction()
	var blocked := world_controls_blocked()
	if blocked:
		direction = Vector2.ZERO
	meal_button.visible = _can_use_travel_meal()
	if training_cart.visible and not blocked:
		var rate := CART_BRAKING if direction.is_zero_approx() else CART_ACCELERATION
		velocity = velocity.move_toward(direction * CART_SPEED, rate * delta)
	else:
		velocity = direction * SPEED
	if not velocity.is_zero_approx():
		current_state = State.RUN
	else:
		current_state = State.TOOL_USE if tool_gesture.visible else State.IDLE

	move_and_slide()
	var movement := get_position_delta()
	
	# Camera Shake
	if shake_strength > 0.05:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		camera.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
	elif shake_strength > 0.0:
		shake_strength = 0.0
		camera.offset = Vector2.ZERO
	
	if training_cart.visible:
		_update_driver(movement.length())
	else:
		_update_walk_sprite(direction, movement)
	_set_interaction_target(_nearest_interactable())

func _set_interaction_target(next_target: Node2D) -> void:
	if next_target != interaction_target:
		if is_instance_valid(interaction_target) and interaction_target.has_method("set_interaction_focused"):
			interaction_target.set_interaction_focused(false)
		interaction_target = next_target
		if next_target and next_target.has_method("set_interaction_focused"):
			next_target.set_interaction_focused(true)
	interaction_prompt.set_target(next_target if next_target else _nearest_gate())

func _nearest_gate() -> Node2D:
	if world_controls_blocked() or Global.is_indoors() or training_cart.visible:
		return null
	var nearest: Node2D
	var distance := INF
	var heading := facing_direction()
	for gate in get_tree().get_nodes_in_group(&"outdoor_gates"):
		var approach: float = gate.approach_distance(global_position, heading)
		if approach < distance:
			distance = approach
			nearest = gate
	return nearest

func set_training_cart(mounted: bool) -> void:
	training_cart.visible = mounted
	velocity = Vector2.ZERO
	walk_distance = WALK_START
	tool_gesture.clear()
	silk_hands.clear()
	sprite.position.y = -15.0 if mounted else -6.0
	if mounted:
		_update_driver(0.0)
	else:
		training_cart.halt()

func _update_driver(distance: float) -> void:
	_set_standing_motion(false)
	if velocity.length_squared() > 144.0:
		_face(velocity)
	training_cart.face(facing_direction())
	training_cart.roll(distance)
	sprite.offset = Vector2.ZERO
	sprite.frame_coords = Vector2i(0, facing_row)

func take_damage(amount: int) -> void:
	if Global.outcome == Global.Outcome.RUNNING:
		apply_shake(3.0)
		if hurt_tween:
			hurt_tween.kill()
		sprite.modulate = Color("#f09377")
		hurt_tween = create_tween()
		hurt_tween.tween_property(sprite, "modulate", Color.WHITE, 0.24)
		AudioManager.play_event_sound("hurt")
		Global.hurt_player(amount)

func show_action(action: ToolGesture.Action, target: Vector2, impact := Callable()) -> void:
	_set_standing_motion(false)
	silk_hands.clear()
	var toward := target - global_position
	if velocity.is_zero_approx() and toward.length_squared() > 1.0:
		_face(toward)
	if action == Action.BOW:
		tool_gesture.perform(action, toward)
		AudioManager.play_field_action(action)
		return
	tool_gesture.perform(action, toward, 0.08, target)
	tool_gesture.at_contact(func():
		if velocity.is_zero_approx() and tool_gesture.work_pose() == 1:
			_update_walk_sprite(Vector2.ZERO)
		AudioManager.play_field_action(action)
		if impact.is_valid():
			impact.call()
	)

func show_silk_work(station: Node2D, grip: Vector2, support: Vector2, reach: float) -> void:
	_face(station.global_position - global_position)
	silk_hands.present(station, facing_direction(), to_local(grip), to_local(support), reach, tool_gesture.sleeve)
	_update_walk_sprite(Vector2.ZERO)

func clear_silk_work(station: Node2D) -> void:
	if silk_hands.station == station:
		silk_hands.clear()
		if velocity.is_zero_approx():
			_update_walk_sprite(Vector2.ZERO)

func set_seat_pose(surface: SeatedPose.Surface) -> void:
	_seat_surface = surface
	if seated:
		tool_gesture.clear()
		silk_hands.clear()
	_update_walk_sprite(Vector2.ZERO)

func _update_walk_sprite(direction: Vector2, movement := Vector2.ZERO) -> void:
	if not direction.is_zero_approx():
		_face(direction)
	if seated:
		_set_standing_motion(false)
		walk_distance = WALK_START
		sprite.offset = Vector2.ZERO
		sprite.flip_h = facing_left
		sprite.frame_coords = Vector2i(0, facing_row)
		if not _seated_art:
			_seated_art = SeatedPose.new(sprite)
			sprite.add_child(_seated_art, false, Node.INTERNAL_MODE_BACK)
		_seated_art.present(_seat_surface, tool_gesture.sleeve)
		return
	if _seated_art:
		_seated_art.restore_standing()
	var travelled := movement.length()
	if direction.is_zero_approx() or travelled < MIN_WALK_DISTANCE:
		walk_distance = WALK_START
		sprite.flip_h = facing_left
		var work := tool_gesture.work_pose()
		if work < 0:
			work = silk_hands.body_pose
		if work >= 0:
			sprite.offset = Vector2.ZERO
			sprite.frame_coords = Vector2i(PlayerAttire.WORK_COLUMN + work, facing_row)
		else:
			sprite.offset = tool_gesture.body_lean
			sprite.frame_coords = Vector2i(0, facing_row)
		_set_standing_motion(work < 0 and not tool_gesture.visible and not silk_hands.visible and not resting)
		return
	_set_standing_motion(false)
	silk_hands.clear()
	sprite.offset = Vector2.ZERO
	var previous := NeighborMotion.walk_column(walk_distance, PlayerAttire.PASS_COLUMN)
	walk_distance = fposmod(walk_distance + travelled, WALK_CYCLE)
	var column := NeighborMotion.walk_column(walk_distance, PlayerAttire.PASS_COLUMN)
	var row := _facing_for(movement)
	sprite.flip_h = row == Facing.PROFILE and movement.x < 0.0
	sprite.frame_coords = Vector2i(column, row)
	if column != previous and column in [1, 2]:
		footstep.emit(global_position)

func _set_standing_motion(enabled: bool) -> void:
	if _standing_free == enabled:
		return
	_standing_free = enabled
	if not enabled:
		_standing_pose.clear()

func footstep_contact(at: Vector2) -> Vector2:
	var frame := sprite.frame_coords
	if frame.x not in [1, 2]:
		return at
	var sole := PlayerAttire.planted_sole(frame, sprite.flip_h)
	return at + (sprite.to_global(sole) - global_position)

func _face(direction: Vector2) -> void:
	facing_row = _facing_for(direction)
	facing_left = facing_row == Facing.PROFILE and direction.x < 0.0
	sprite.flip_h = facing_left

static func _facing_for(direction: Vector2) -> Facing:
	if absf(direction.x) > absf(direction.y):
		return Facing.PROFILE
	return Facing.BACK if direction.y < 0.0 else Facing.FRONT

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		bow_pointer = event.position

func _process(delta: float) -> void:
	if _standing_free:
		_standing_pose.advance(delta)
	var target: Node2D
	var viewport := get_viewport()
	if (not world_controls_blocked() and not training_cart.visible and not Global.is_indoors()
			and viewport.get_visible_rect().has_point(bow_pointer)
			and viewport.gui_get_hovered_control() == null):
		target = _enemy_under_bow_pointer(get_canvas_transform().affine_inverse() * bow_pointer)
	bow_target.visible = target != null
	if target:
		bow_target.global_position = target.global_position

func _clear_bow_pointer() -> void:
	bow_pointer = Vector2.INF
	bow_target.hide()

func _draw_bow_target() -> void:
	for side: float in [-1.0, 1.0]:
		var bracket := PackedVector2Array([Vector2(13 * side, 2), Vector2(13 * side, 7), Vector2(8 * side, 7)])
		bow_target.draw_polyline(bracket, Color("#263630"), 3.2)
		bow_target.draw_polyline(bracket, Color("#e6efbd"), 1.3)

func _unhandled_input(event: InputEvent) -> void:
	if world_controls_blocked():
		return
	if event is InputEventMouseButton and event.pressed:
		if Global.is_indoors():
			return
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				if not training_cart.visible:
					shoot_arrow(get_canvas_transform().affine_inverse() * event.position)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if get_viewport().gui_get_hovered_control() == null:
					var step := 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
					var index := CAMERA_ZOOMS.find(Preferences.map_zoom)
					Preferences.map_zoom = CAMERA_ZOOMS[clampi(index + step, 0, CAMERA_ZOOMS.size() - 1)]
					_apply_camera_zoom()
					get_viewport().set_input_as_handled()
	elif event.is_pressed() and not event.is_echo():
		if Preferences.matches(event, KeyBindings.INTERACT) or event.is_action_pressed("ui_accept"):
			interact()
		elif Preferences.matches(event, KeyBindings.MEAL) and _can_use_travel_meal():
			_eat_travel_meal()
			get_viewport().set_input_as_handled()

func _can_use_travel_meal() -> bool:
	return (not Global.travel_meal.is_empty() and Global.outcome == Global.Outcome.RUNNING
		and not (meal_controls_blocked or conversation_open or resting or MapTravel.active or training_cart.visible))

func _refresh_travel_meal() -> void:
	meal_button.visible = _can_use_travel_meal()
	if not Global.travel_meal.is_empty():
		var meal := Global.travel_meal
		meal_button.icon = TravelMeal.icon(meal)
		var title: String = TravelMeal.RECIPES[meal].name
		meal_button.text = title if GamepadInput.active else "%s  ·  %s" % [Preferences.key_label(KeyBindings.MEAL), title]
		meal_button.tooltip_text = TravelMeal.describe_recovery(TravelMeal.benefits(meal, Global.balance))

func _eat_travel_meal() -> void:
	if _can_use_travel_meal() and Global.eat_travel_meal():
		AudioManager.play_ui_sfx(0.86)

func _apply_camera_zoom() -> void:
	camera.zoom = Vector2.ONE * Preferences.map_zoom
	camera.force_update_scroll()

func arrive_at(marker: Marker2D) -> void:
	arrive_at_position(marker.global_position, marker.global_transform.x)

func restore_walking_checkpoint(bounds: Rect2, fixtures: Array[Rect2] = []) -> void:
	var checkpoint := Global.restored_walking_checkpoint
	Global.restored_walking_checkpoint = {}
	if checkpoint.is_empty():
		return
	var feet: CollisionShape2D = $CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = feet.shape
	query.transform = feet.global_transform.translated(checkpoint.point - global_position)
	var footprint: Rect2 = query.transform * feet.shape.get_rect()
	if not bounds.encloses(footprint) or _overlaps_threshold(footprint):
		return
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	var offsets: Array[Vector2] = [Vector2.ZERO]
	const CLEARANCE := 0.8
	# Scene-built fixtures can take a physics tick to appear in the space query.
	for fixture in fixtures:
		if footprint.intersects(fixture):
			offsets.append_array([
				Vector2(fixture.position.x - footprint.end.x - CLEARANCE, 0),
				Vector2(fixture.end.x - footprint.position.x + CLEARANCE, 0),
				Vector2(0, fixture.position.y - footprint.end.y - CLEARANCE),
				Vector2(0, fixture.end.y - footprint.position.y + CLEARANCE),
			])
	offsets.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length_squared() < b.length_squared())
	var saved_transform := query.transform
	for offset in offsets:
		var candidate := Rect2(footprint.position + offset, footprint.size)
		if (not bounds.encloses(candidate) or _overlaps_threshold(candidate)
				or fixtures.any(func(fixture: Rect2) -> bool: return candidate.intersects(fixture))):
			continue
		query.transform = saved_transform.translated(offset)
		if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			arrive_at_position(checkpoint.point + offset, checkpoint.facing)
			return

func _overlaps_threshold(footprint: Rect2) -> bool:
	for area: Area2D in get_tree().get_nodes_in_group("travel_threshold"):
		if not area.monitoring:
			continue
		for child in area.get_children():
			var sensor := child as CollisionShape2D
			if sensor != null and not sensor.disabled and sensor.shape != null:
				var threshold: Rect2 = sensor.global_transform * sensor.shape.get_rect()
				if footprint.intersects(threshold):
					return true
	return false

func facing_direction() -> Vector2:
	match facing_row:
		Facing.BACK: return Vector2.UP
		Facing.PROFILE: return Vector2.LEFT if facing_left else Vector2.RIGHT
		_: return Vector2.DOWN

func arrive_at_position(position_in_world: Vector2, direction: Vector2) -> void:
	silk_hands.clear()
	global_position = position_in_world
	velocity = Vector2.ZERO
	_face(direction)
	_update_walk_sprite(Vector2.ZERO)
	camera.reset_smoothing()
	camera.force_update_scroll()

func _enemy_under_bow_pointer(world_point: Vector2) -> Node2D:
	var target: Node2D
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_under_bow_pointer(world_point) and (target == null or enemy.global_position.y >= target.global_position.y):
			target = enemy
	return target

func shoot_arrow(target_pos: Vector2) -> void:
	var target := _enemy_under_bow_pointer(target_pos)
	var aim_point := target.global_position if target else target_pos
	var arrow = arrow_scene.instantiate()
	arrow.position = position
	arrow.direction = global_position.direction_to(aim_point)
	arrow.rotation = arrow.direction.angle()
	get_parent().add_child(arrow)
	show_action(Action.BOW, aim_point)

func apply_shake(strength: float = 5.0) -> void:
	shake_strength = strength

func _nearest_interactable() -> Node2D:
	if training_cart.visible:
		return null
	var nearest_node: Node2D
	var min_dist := 60.0 * 60.0
	for candidate in get_tree().get_nodes_in_group("interactable"):
		var node := candidate as Node2D
		if node == null or node.is_queued_for_deletion() or not node.has_method("interact"):
			continue
		if node.has_method("can_interact_from") and not node.can_interact_from(global_position):
			continue
		var dist := global_position.distance_squared_to(node.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest_node = node
	return nearest_node

func interact() -> void:
	var nearest_node := _nearest_interactable()
	if nearest_node:
		var toward := nearest_node.global_position - global_position
		if toward.length_squared() > 4.0:
			_face(toward)
			if velocity.is_zero_approx():
				sprite.frame_coords = Vector2i(0, facing_row)
		nearest_node.interact()
