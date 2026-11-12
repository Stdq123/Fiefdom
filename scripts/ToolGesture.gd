extends Sprite2D
class_name ToolGesture

enum Action { TILL, SOW, WATER, HARVEST, BOW }

const HAND_TOOLS := "res://assets/characters/hand-tools.svg"
const RECOVERY := 0.18
const REPLAY_INTERVAL := 0.10
const WINDUP_ANGLES := [-0.96, -0.20, -0.08, -0.70, -0.12]
const CONTACT_ANGLES := [0.74, 0.47, 0.92, 0.50, 0.08]
const GRIPS := [Vector2(-1, -1), Vector2(-3, -1), Vector2(-1, -7), Vector2(-2, 2), Vector2(5, 0)]

var carrying := false
var sleeve := Color("#7d8e83")
var body_lean := Vector2.ZERO
var aim := Vector2.DOWN
var elapsed := 0.0
var contact_time := 0.08

func _ready() -> void:
	texture = load(HAND_TOOLS)
	hframes = Action.size()
	clear()

func perform(action: Action, toward: Vector2, windup := 0.08) -> void:
	_face(toward)
	if visible and not carrying and frame == action and elapsed < REPLAY_INTERVAL:
		_apply_pose()
		return
	carrying = false
	frame = action
	elapsed = 0.0
	contact_time = maxf(windup, 0.01)
	_apply_pose()
	show()
	set_process(true)

func carry_pail(toward: Vector2, step_height: float) -> void:
	if visible and not carrying:
		return
	_face(toward)
	carrying = true
	frame = Action.WATER
	position = Vector2(-9 if flip_h else 9, 1 + step_height)
	rotation = 0.0
	show()
	queue_redraw()

func clear() -> void:
	carrying = false
	body_lean = Vector2.ZERO
	hide()
	set_process(false)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= contact_time + RECOVERY:
		clear()
	else:
		_apply_pose()

func _face(toward: Vector2) -> void:
	if not toward.is_zero_approx():
		aim = toward.normalized()
	if absf(aim.x) > 0.20:
		flip_h = aim.x < 0.0

func _apply_pose() -> void:
	var side := -1.0 if flip_h else 1.0
	var swing := smoothstep(maxf(0.0, contact_time - 0.16), contact_time, elapsed)
	var release := smoothstep(contact_time, contact_time + RECOVERY, elapsed)
	var reach := swing * (1.0 - release)
	var rise := sin(PI * swing) * 4.0
	position = (Vector2(8.0 * side, -6.0 - rise) + aim * (2.0 + 5.0 * reach)).round()
	rotation = lerpf(WINDUP_ANGLES[frame], CONTACT_ANGLES[frame], reach) * side
	if frame == Action.BOW:
		rotation += Vector2(side, 0).angle_to(aim)
	body_lean = (aim * reach * 2.0).round()
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var side := -1.0 if flip_h else 1.0
	var local_from_actor := transform.affine_inverse()
	var shoulder := local_from_actor * (Vector2(5 * side, -8) + body_lean)
	var elbow := local_from_actor * (Vector2(8 * side, -5) + body_lean)
	var grip: Vector2 = GRIPS[frame] * Vector2(side, 1)
	var arm := PackedVector2Array([shoulder, elbow, grip])
	draw_polyline(arm, Color("#252d2a"), 4.0)
	draw_polyline(arm, sleeve, 2.0)
	draw_rect(Rect2(grip - Vector2(1, 1), Vector2(3, 2)), Color("#dfac81"))
