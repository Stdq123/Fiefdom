extends Node2D

const FLEECE := preload("res://assets/world/sheepfold/farm-sheep.webp")
const BLEAT := preload("res://assets/world/sheepfold/sheep-bleat.ogg")
const SHELTER := Vector2(-12, 7)
const FEEDING_SPOT := Vector2(3, 18)
const WALK_TO_FEED := 0.18
const AT_TROUGH := 0.23
const LEAVE_TROUGH := 0.43
const BACK_IN_SHELTER := 0.48
const ROUTE := [SHELTER, Vector2(-23, 30), Vector2(8, 40), Vector2(28, 27), Vector2(12, 20), SHELTER]
const YARD_COLORS := [Color("#57724c"), Color("#5d7248"), Color("#77714b"), Color("#8c8871")]
const PADDOCK := [Vector2(-43, 1), Vector2(42, 1), Vector2(44, 48),
	Vector2(37, 54), Vector2(13, 52), Vector2(9, 59), Vector2(-11, 59),
	Vector2(-15, 53), Vector2(-36, 55), Vector2(-44, 48)]

@onready var animal: Sprite2D = $Paddock/Sheep
@onready var short_coat: Texture2D = $Paddock/Sheep.texture
@onready var landscape: Node2D = $"../Landscape"
@onready var ground: Node2D = $Paddock/Yard
@onready var hay: Sprite2D = $Paddock/Trough/Fodder
@onready var haystack: Node2D = $Paddock/Haystack
@onready var clipping: Sprite2D = $Paddock/Clipping
@onready var hint: Label = $Paddock/Hint

var pose_time := 0.0
var focused := false

func _ready() -> void:
	ground.draw.connect(_draw_yard)
	landscape.day_lighting.place_lamp($Paddock, Vector2(-32, 4), 0.70)
	GameEvents.sheepfold_changed.connect(_refresh)
	GameEvents.sheep_sheared.connect(_on_sheared)
	_refresh()

func _refresh() -> void:
	var flock := Global.sheepfold
	visible = flock.owned()
	set_process(visible)
	for shape: CollisionShape2D in $Paddock/Barriers.get_children():
		shape.set_deferred("disabled", not visible)
	if not visible:
		return
	var grown := flock.wool_nights >= mini(3, Global.balance.sheep_wool_nights)
	animal.texture = FLEECE if grown else short_coat
	animal.scale = Vector2.ONE * (0.25 if grown else 1.0)
	hay.visible = flock.fodder > 0
	for bale: Sprite2D in haystack.get_children():
		bale.visible = bale.get_index() < flock.fodder
	var ready := Global.can_use_sheepfold(Sheepfold.Action.SHEAR)
	$Paddock/Wool.visible = ready
	_refresh_hint()
	ground.queue_redraw()
	_update_sheep(0.0)

func _process(delta: float) -> void:
	_update_sheep(delta)

func _update_sheep(delta: float) -> void:
	var foot := SHELTER
	var clock := Global.day_progress
	var pasture := Global.sheep_can_graze()
	var grazing := pasture and clock > 0.05 and clock < 0.76
	var at_trough := false
	if grazing:
		var progress := inverse_lerp(0.05, 0.76, clock) * (ROUTE.size() - 1)
		var segment := floori(progress)
		foot = ROUTE[segment].lerp(ROUTE[segment + 1], smoothstep(0.0, 0.65, fposmod(progress, 1.0)))
	elif not pasture and hay.visible:
		var trip := smoothstep(WALK_TO_FEED, AT_TROUGH, clock) * (1.0 - smoothstep(LEAVE_TROUGH, BACK_IN_SHELTER, clock))
		foot = SHELTER.lerp(FEEDING_SPOT, trip)
		at_trough = clock >= AT_TROUGH and clock <= LEAVE_TROUGH
	var motion := foot - animal.position
	animal.position = foot
	if at_trough:
		animal.flip_h = false
	elif absf(motion.x) > 0.01:
		animal.flip_h = motion.x < 0.0
	pose_time = fposmod(pose_time + delta, 4.0)
	var moving := motion.length_squared() > 0.0002
	var lift := -1.0 if moving and fposmod(pose_time, 0.50) < 0.23 else 0.0
	var tilt := 0.0
	if at_trough:
		tilt = 0.15 + sin(pose_time * TAU) * 0.035
	elif grazing and not moving and pose_time > 2.8:
		tilt = 0.09
	animal.rotation = -tilt if animal.flip_h else tilt
	animal.offset.y = (lift - 6.0) / animal.scale.y

func _draw_yard() -> void:
	ground.draw_colored_polygon(PackedVector2Array(PADDOCK), YARD_COLORS[Global.season_index()])
	var gravel: Color = landscape._track_dust()
	ground.draw_colored_polygon(PackedVector2Array([Vector2(-7, 65), Vector2(7, 65), Vector2(5, 48),
		Vector2(9, 37), Vector2(20, 18), Vector2(11, 17), Vector2(2, 31), Vector2(-3, 46)]), gravel)
	for stone: Vector2 in [Vector2(-3, 56), Vector2(2, 50), Vector2(1, 42), Vector2(8, 33), Vector2(12, 26)]:
		ground.draw_rect(Rect2(stone, Vector2(3, 1)), gravel.darkened(0.16))
	for spot: Vector2 in [Vector2(-32, 19), Vector2(-23, 36), Vector2(25, 40), Vector2(34, 21), Vector2(-12, 26)]:
		ground.draw_rect(Rect2(spot, Vector2(5, 1)), Color("#abb17b80"))
		ground.draw_rect(Rect2(spot + Vector2(2, -2), Vector2(1, 3)), Color("#abb17b80"))

func can_interact_from(foot: Vector2) -> bool:
	return visible and global_position.distance_squared_to(foot) <= 26.0 * 26.0

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh_hint()

func _refresh_hint() -> void:
	hint.visible = focused or clipping.visible
	if clipping.visible:
		hint.text = "羊毛 +1"
		return
	hint.text = GamepadInput.interact_hint("羊毛可剪" if $Paddock/Wool.visible else "西坡羊棚")

func interact() -> void:
	GameEvents.sheepfold_requested.emit()

func _on_sheared() -> void:
	AudioManager.play_world_sfx(BLEAT, animal, -15.0, 125.0)
	var landing := animal.position + Vector2(-13 if animal.flip_h else 13, 5)
	clipping.position = animal.position + Vector2(0, -11)
	clipping.modulate.a = 1.0
	clipping.show()
	var fall := create_tween().set_parallel(true)
	fall.tween_property(clipping, "position:x", landing.x, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall.tween_property(clipping, "position:y", clipping.position.y - 4.0, 0.08)
	fall.chain().tween_property(clipping, "position:y", landing.y, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.chain().tween_property(clipping, "modulate:a", 0.0, 0.25).set_delay(0.85)
	fall.chain().tween_callback(_finish_clipping)

func _finish_clipping() -> void:
	clipping.hide()
	_refresh_hint()
