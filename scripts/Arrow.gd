extends Area2D

const HOSTILE_REACH := 210.0
const RELEASE_SOUND := preload("res://assets/audio/combat/bow-release.wav")

var speed := 400.0
var direction := Vector2.RIGHT
var damage := 10
var hostile := false
var guard_name := ""
var distance_left := 800.0
var collision_pending := false

@onready var actor := get_tree().get_first_node_in_group("player") as Player

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	AudioManager.play_world_sfx(RELEASE_SOUND, self)
	if hostile:
		distance_left = HOSTILE_REACH
	elif Global.tech_unlocked.get("composite_bow", false):
		damage = 25
		speed = 600.0
		distance_left = 1200.0

func _physics_process(delta: float) -> void:
	if _waiting_for_player():
		return
	if collision_pending:
		collision_pending = false
		for body in get_overlapping_bodies():
			_on_body_entered(body)
			if is_queued_for_deletion():
				return
	if distance_left <= 0.0:
		queue_free()
		return
	var step := minf(speed * delta, distance_left)
	position += direction * step
	distance_left -= step

func _waiting_for_player() -> bool:
	return is_instance_valid(actor) and actor.combat_paused()

func _draw() -> void:
	var ink := Color("#e8876d") if hostile else Color("#ecd7a2")
	draw_line(Vector2(-10, 0), Vector2(-3, 0), Color(ink, 0.38), 1.0)
	draw_line(Vector2(-4, 0), Vector2(9, 0), Color("#382c24"), 3.0)
	draw_line(Vector2(-4, 0), Vector2(6, 0), ink, 1.3)
	draw_colored_polygon(PackedVector2Array([Vector2(5, -2), Vector2(10, 0), Vector2(5, 2)]), ink)

func _on_body_entered(body: Node2D) -> void:
	if is_queued_for_deletion():
		return
	if _waiting_for_player():
		collision_pending = true
		return
	if hostile and body.is_in_group("player"):
		queue_free()
		body.take_damage(damage)
	elif not hostile and body.is_in_group("enemies"):
		queue_free()
		body.take_damage(damage, guard_name)
	elif body is TileMapLayer:
		queue_free()
