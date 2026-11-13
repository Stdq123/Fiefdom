extends CharacterBody2D

enum Type { WILD_DOG, SCOUT }
enum State { IDLE, PATROL, CHASE, ATTACK, EAT }
enum Attack { NONE, BITE, SHOT, CROP }

const ARROW_SCENE := preload("res://scenes/Arrow.tscn")
const ARROW := preload("res://scripts/Arrow.gd")
const FLOATING_TEXT := preload("res://scenes/FloatingText.tscn")
const GROWL := preload("res://assets/audio/combat/dog-windup.wav")
const SNARE_SNAP := preload("res://assets/audio/plank-2.wav")
const NO_CROP := Vector2i(-1, -1)
const BITE_REACH := 36.0
const BITE_HALF_ANGLE := PI / 5.0
const SNARE_REACH := 3.0
const WINDUP_INK := Color("#f1bc73")
const STRIKE_INK := Color("#f08d6b")

@export var type: Type = Type.WILD_DOG
var raid := false
var state: State = State.IDLE

var health := 20
var speed := 40.0
var player_ref: Player
var target_crop_pos := NO_CROP
var world_ref: Node2D
var attack_cooldown := 0.0
var attack_range := 30.0
var pending_attack := Attack.NONE
var windup_left := 0.0
var windup_duration := 0.0
var aim := Vector2.RIGHT
var aim_point := Vector2.ZERO
var pose_tween: Tween
var hit_tween: Tween
var crossing_snare := false
var raid_player: Player

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_cue: Node2D = $AttackCue

func _ready() -> void:
	add_to_group("enemies")
	_setup_stats()
	attack_cue.material = preload("res://resources/world_hint_material.tres")
	attack_cue.draw.connect(_draw_attack_cue)
	world_ref = get_parent()
	state = State.PATROL
	if raid:
		add_to_group("estate_raiders")
		raid_player = world_ref.player
		if Global.raid_health > 0:
			health = Global.raid_health
		crossing_snare = Global.watch_snare_armed
		if crossing_snare or Global.raid_snare_left > 0.0:
			sprite.flip_h = true
			set_collision_mask_value(2, false)
		else:
			_find_crop()

func _setup_stats() -> void:
	match type:
		Type.WILD_DOG:
			health = 10
			speed = 80.0
			attack_range = 30.0
			sprite.texture = CharacterArt.wild_dog()
		Type.SCOUT:
			health = 30
			speed = 50.0
			attack_range = 150.0
			sprite.texture = CharacterArt.scout()

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if raid and (crossing_snare or Global.raid_snare_left > 0.0) and raid_player.world_controls_blocked():
		return
	if raid and Global.raid_snare_left > 0.0:
		Global.raid_snare_left = maxf(0.0, Global.raid_snare_left - delta)
		attack_cue.queue_redraw()
		if Global.raid_snare_left == 0.0:
			_release_snare()
			GameEvents.watch_snare_changed.emit()
		return
	if crossing_snare:
		_cross_snare()
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if pending_attack != Attack.NONE:
		windup_left = maxf(0.0, windup_left - delta)
		if windup_left == 0.0:
			_release_attack()
		attack_cue.queue_redraw()
		return

	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if randf() < 0.01:
				state = State.PATROL
		State.PATROL:
			if velocity == Vector2.ZERO:
				var direction := Vector2(randf() - 0.5, randf() - 0.5).normalized()
				if raid:
					var target: Vector2 = world_ref.to_global(world_ref.get_crop_world_pos(Global.well_fields[0]["center_pos"]))
					direction = global_position.direction_to(target)
				velocity = direction * (speed * 0.5)
			if randf() < 0.01:
				state = State.IDLE
			if raid and randf() < 0.05:
				_find_crop()
		State.CHASE:
			if is_instance_valid(player_ref):
				velocity = global_position.direction_to(player_ref.global_position) * speed
				if global_position.distance_to(player_ref.global_position) <= attack_range:
					state = State.ATTACK
			else:
				_resume_patrol()
		State.EAT:
			_approach_crop()
		State.ATTACK:
			velocity = Vector2.ZERO
			if not is_instance_valid(player_ref):
				_resume_patrol()
			elif global_position.distance_to(player_ref.global_position) > attack_range * 1.2:
				state = State.CHASE
			elif attack_cooldown == 0.0:
				if type == Type.SCOUT:
					_start_attack(Attack.SHOT, player_ref.global_position, Global.balance.scout_shot_windup)
				else:
					_start_attack(Attack.BITE, player_ref.global_position, Global.balance.dog_bite_windup)

	move_and_slide()
	if not is_zero_approx(velocity.x):
		sprite.flip_h = velocity.x < 0.0

func _cross_snare() -> void:
	var destination := EstateLayout.EAST_RAID_SNARE
	velocity = position.direction_to(destination) * speed
	sprite.flip_h = velocity.x < 0.0
	move_and_slide()
	if position.distance_squared_to(destination) <= SNARE_REACH * SNARE_REACH:
		crossing_snare = false
		velocity = Vector2.ZERO
		Global.spring_watch_snare()
		AudioManager.play_world_sfx(SNARE_SNAP, self, -7.0, 280.0)
		attack_cue.queue_redraw()

func _release_snare() -> void:
	set_collision_mask_value(2, true)
	_resume_patrol()
	if is_instance_valid(player_ref):
		state = State.CHASE

func _resume_patrol() -> void:
	velocity = Vector2.ZERO
	state = State.PATROL
	_find_crop()

func _find_crop() -> void:
	if raid:
		target_crop_pos = world_ref.get_random_crop_pos()
		if target_crop_pos != NO_CROP:
			state = State.EAT

func _approach_crop() -> void:
	if not world_ref.active_crops.has(target_crop_pos):
		_resume_patrol()
		return
	var target: Vector2 = world_ref.to_global(world_ref.get_crop_world_pos(target_crop_pos))
	velocity = global_position.direction_to(target) * speed
	if global_position.distance_to(target) < 10.0:
		velocity = Vector2.ZERO
		if attack_cooldown == 0.0:
			_start_attack(Attack.CROP, target, Global.balance.raid_crop_windup)

func _start_attack(attack: Attack, target: Vector2, duration: float) -> void:
	pending_attack = attack
	aim_point = target
	aim = global_position.direction_to(target)
	if aim.is_zero_approx():
		aim = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	if not is_zero_approx(aim.x):
		sprite.flip_h = aim.x < 0.0
	windup_duration = duration
	windup_left = duration
	velocity = Vector2.ZERO
	if pose_tween:
		pose_tween.kill()
	pose_tween = create_tween().set_parallel()
	var brace := Vector2(0.92, 1.10) if attack == Attack.SHOT else Vector2(1.14, 0.83)
	pose_tween.tween_property(sprite, "scale", brace, 0.16)
	pose_tween.tween_property(sprite, "position", Vector2(0, -6) - aim * 3.0, 0.16)
	if type == Type.WILD_DOG:
		AudioManager.play_world_sfx(GROWL, self)
	attack_cue.queue_redraw()

func _release_attack() -> void:
	var attack := pending_attack
	pending_attack = Attack.NONE
	attack_cooldown = Global.balance.enemy_recovery
	match attack:
		Attack.SHOT:
			var arrow = ARROW_SCENE.instantiate()
			arrow.hostile = true
			arrow.damage = Global.balance.scout_arrow_damage
			arrow.set_collision_mask_value(4, false)
			arrow.set_collision_mask_value(2, true)
			arrow.position = position
			arrow.direction = aim
			arrow.rotation = aim.angle()
			get_parent().add_child(arrow)
		Attack.BITE:
			if is_instance_valid(player_ref) and _inside_bite(player_ref.global_position):
				player_ref.take_damage(Global.balance.wild_dog_damage)
		Attack.CROP:
			world_ref.destroy_crop(target_crop_pos)

	if pose_tween:
		pose_tween.kill()
	sprite.position = Vector2(0, -6) + aim * (2.0 if attack == Attack.SHOT else 7.0)
	pose_tween = create_tween().set_parallel()
	pose_tween.tween_property(sprite, "position", Vector2(0, -6), 0.18)
	pose_tween.tween_property(sprite, "scale", Vector2.ONE, 0.18)
	if is_instance_valid(player_ref):
		state = State.ATTACK
	else:
		_resume_patrol()

func _inside_bite(point: Vector2) -> bool:
	var offset := point - global_position
	return offset.length_squared() <= BITE_REACH * BITE_REACH and absf(aim.angle_to(offset)) <= BITE_HALF_ANGLE

func _draw_attack_cue() -> void:
	if raid and Global.raid_snare_left > 0.0:
		_draw_snare_cue()
		return
	if pending_attack == Attack.NONE:
		return
	var progress := 1.0 - windup_left / windup_duration
	var ink := WINDUP_INK.lerp(STRIKE_INK, progress)
	match pending_attack:
		Attack.BITE:
			var sector := PackedVector2Array([Vector2.ZERO])
			for edge in range(13):
				var angle := lerpf(-BITE_HALF_ANGLE, BITE_HALF_ANGLE, edge / 12.0)
				sector.append(aim.rotated(angle) * BITE_REACH)
			attack_cue.draw_colored_polygon(sector, Color(ink, 0.27))
			sector.append(Vector2.ZERO)
			attack_cue.draw_polyline(sector, Color(ink, 0.92), 1.0)
			attack_cue.draw_line(Vector2.ZERO, aim * BITE_REACH * progress, ink, 1.5)
		Attack.SHOT:
			var end := aim * ARROW.HOSTILE_REACH
			attack_cue.draw_line(Vector2.ZERO, end, Color(ink, 0.24), 6.0)
			attack_cue.draw_dashed_line(Vector2.ZERO, end, Color(ink, 0.86), 1.0, 4.0)
			attack_cue.draw_line(Vector2.ZERO, end * progress, ink, 1.5)
			var side := aim.orthogonal() * 4.0
			attack_cue.draw_polyline(PackedVector2Array([end - aim * 7.0 - side, end, end - aim * 7.0 + side]), ink, 1.2)
		Attack.CROP:
			var tile := Rect2(attack_cue.to_local(aim_point) - Vector2(8, 8), Vector2(16, 16))
			attack_cue.draw_rect(tile, Color(STRIKE_INK, 0.33))
			attack_cue.draw_rect(tile.grow(0.6), Color("#5e382c"), false, 2.6)
			attack_cue.draw_rect(tile, STRIKE_INK, false, 1.2)
			var start := tile.position + Vector2(1, 13)
			attack_cue.draw_line(start, start + Vector2(14 * progress, 0), ink, 1.5)

func _draw_snare_cue() -> void:
	var fraction := Global.raid_snare_left / Global.balance.raid_snare_seconds
	attack_cue.draw_arc(Vector2(0, 1), 13.0, 0.0, TAU, 24, Color("#e8c58c9e"), 1.25)
	var y := -41.0 if type == Type.SCOUT else -24.0
	attack_cue.draw_rect(Rect2(-12, y, 24, 4), Color("#392d26"))
	attack_cue.draw_rect(Rect2(-11, y + 1.0, 22.0 * fraction, 2), Color("#f4c878"))
	attack_cue.draw_polyline(PackedVector2Array([Vector2(-7, 4), Vector2(-1, -3), Vector2(5, 5),
		Vector2(-7, 4)]), Color("#d7b37a"), 1.1)

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is Player:
		player_ref = body
		if pending_attack == Attack.NONE and not crossing_snare:
			state = State.CHASE

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_ref = null
		if pending_attack == Attack.NONE and not crossing_snare:
			_resume_patrol()

func is_under_bow_pointer(world_point: Vector2) -> bool:
	return not is_queued_for_deletion() and sprite.is_visible_in_tree() and sprite.is_pixel_opaque(sprite.to_local(world_point))

func take_damage(amount: int, guard_name := "") -> void:
	if is_queued_for_deletion() or amount <= 0:
		return
	health -= amount
	if raid:
		Global.raid_health = maxi(0, health)
	var feedback := FLOATING_TEXT.instantiate() as Label
	feedback.text = "−%d" % amount
	feedback.modulate = Color("#ffdda2")
	feedback.scale = Vector2.ONE * 0.65
	feedback.position = position + Vector2(-9, -29)
	get_parent().add_child(feedback)
	if health <= 0:
		_die(guard_name)
		return
	if hit_tween:
		hit_tween.kill()
	sprite.modulate = Color("#ffb18c")
	hit_tween = create_tween()
	hit_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _die(guard_name: String) -> void:
	if raid:
		Global.defeat_raid(guard_name)
	Global.player_stats.add_xp(PlayerStats.Art.ARCHERY, 20)
	Global.money += 2
	GameEvents.money_changed.emit(Global.money)
	queue_free()
