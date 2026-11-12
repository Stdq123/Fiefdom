extends CharacterBody2D

class_name Player

signal footstep(world_position: Vector2)

const SPEED = 100.0
const STEP_DISTANCE := 20.0
const WALK_FRAMES := [1, 0, 2, 0]
const WALK_FPS := 10.0
const CAMERA_ZOOMS := [1.5, 2.0, 3.0]

# Simple FSM
enum State { IDLE, RUN, TOOL_USE }
enum Facing { FRONT, BACK, PROFILE }
const Action = ToolGesture.Action
var current_state = State.IDLE

@onready var sprite: Sprite2D = $Sprite2D
@onready var tool_gesture: ToolGesture = $ToolGesture
@onready var training_cart: Sprite2D = $TrainingCart
@onready var bow_target: Node2D = $BowTarget
@onready var camera: Camera2D = $Camera2D
@onready var meal_button: Button = $MealUI/MealButton

var shake_strength: float = 0.0
var shake_decay: float = 5.0
var facing_row := Facing.FRONT
var walk_phase := 0.0
var step_distance_left := STEP_DISTANCE * 0.5
var hurt_tween: Tween
var interaction_target: Node2D
var conversation_open := false
var resting := false
var menu_open := false
var meal_controls_blocked := false
var bow_pointer := Vector2.INF

var arrow_scene = preload("res://scenes/Arrow.tscn")

func _ready() -> void:
	add_to_group("player")
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

func _world_controls_blocked() -> bool:
	return conversation_open or resting or menu_open or MapTravel.active

func _physics_process(delta: float) -> void:
	var direction := input_direction()
	if _world_controls_blocked():
		direction = Vector2.ZERO
	meal_button.visible = _can_use_travel_meal()
	if direction:
		velocity = direction * SPEED * (1.5 if training_cart.visible else 1.0)
		current_state = State.RUN
	else:
		velocity = Vector2.ZERO
		current_state = State.TOOL_USE if tool_gesture.visible else State.IDLE

	move_and_slide()
	_update_footsteps(get_position_delta().length())
	
	# Camera Shake
	if shake_strength > 0.05:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		camera.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
	elif shake_strength > 0.0:
		shake_strength = 0.0
		camera.offset = Vector2.ZERO
	
	_update_walk_sprite(direction, delta)
	var next_target := _nearest_interactable()
	if next_target != interaction_target:
		if is_instance_valid(interaction_target) and interaction_target.has_method("set_interaction_focused"):
			interaction_target.set_interaction_focused(false)
		interaction_target = next_target
		if next_target and next_target.has_method("set_interaction_focused"):
			next_target.set_interaction_focused(true)

func set_training_cart(mounted: bool) -> void:
	training_cart.visible = mounted

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

func show_action(action: ToolGesture.Action, target: Vector2) -> void:
	var toward := target - global_position
	if velocity.is_zero_approx() and toward.length_squared() > 1.0:
		_face(toward)
	tool_gesture.perform(action, toward)
	AudioManager.play_field_action(action)

func _update_walk_sprite(direction: Vector2, delta: float) -> void:
	if direction.is_zero_approx():
		walk_phase = 0.0
		sprite.offset = tool_gesture.body_lean
		sprite.frame_coords = Vector2i(0, facing_row)
		return
	sprite.offset = Vector2.ZERO
	_face(direction)
	walk_phase = fposmod(walk_phase + delta * WALK_FPS, WALK_FRAMES.size())
	sprite.frame_coords = Vector2i(WALK_FRAMES[int(walk_phase)], facing_row)

func _update_footsteps(travelled: float) -> void:
	if training_cart.visible or travelled < 0.05:
		step_distance_left = STEP_DISTANCE * 0.5
		return
	step_distance_left -= travelled
	if step_distance_left <= 0.0:
		step_distance_left += STEP_DISTANCE
		footstep.emit(global_position)

func _face(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		facing_row = Facing.PROFILE
		sprite.flip_h = direction.x < 0.0
	else:
		facing_row = Facing.BACK if direction.y < 0.0 else Facing.FRONT
		sprite.flip_h = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		bow_pointer = event.position

func _process(_delta: float) -> void:
	var target: Node2D
	var viewport := get_viewport()
	if (not _world_controls_blocked() and not Global.is_indoors()
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
	if _world_controls_blocked():
		return
	if event is InputEventMouseButton and event.pressed:
		if Global.is_indoors():
			return
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
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
		and not (meal_controls_blocked or conversation_open or resting or MapTravel.active))

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

func facing_direction() -> Vector2:
	match facing_row:
		Facing.BACK: return Vector2.UP
		Facing.PROFILE: return Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
		_: return Vector2.DOWN

func arrive_at_position(position_in_world: Vector2, direction: Vector2) -> void:
	global_position = position_in_world
	velocity = Vector2.ZERO
	_face(direction)
	_update_walk_sprite(Vector2.ZERO, 0.0)
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
