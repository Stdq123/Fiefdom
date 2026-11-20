extends Node2D
class_name SilkWorkHands

const ARM_REACH := 26.0

var station: Node2D
var body_pose := -1
var sleeve := Color.WHITE
var near_shoulder := Vector2.ZERO
var far_shoulder := Vector2.ZERO
var working_hand := Vector2.ZERO
var supporting_hand := Vector2.ZERO
var side := 1.0

func present(source: Node2D, facing: Vector2, grip: Vector2, support: Vector2, reach: float, dye: Color) -> void:
	station = source
	sleeve = dye
	side = -1.0 if facing == Vector2.LEFT else 1.0
	var profile := facing.x != 0.0
	body_pose = int(reach > 0.75)
	var lean := Vector2(side if profile else 0.0, float(body_pose) * 1.5)
	near_shoulder = Vector2((-0.5 if profile else 4.0) * side, -7.0) + lean
	far_shoulder = Vector2((1.0 if profile else -4.0) * side, -8.0) + lean
	working_hand = _reach(near_shoulder, grip, reach, side)
	supporting_hand = _reach(far_shoulder, support, reach, -side)
	show()
	queue_redraw()

func clear() -> void:
	station = null
	body_pose = -1
	hide()

func _reach(shoulder: Vector2, target: Vector2, reach: float, outward: float) -> Vector2:
	var rest := shoulder + Vector2(outward * 2.0, 4.0)
	var contact := shoulder + (target - shoulder).limit_length(ARM_REACH)
	return rest.lerp(contact, reach).snappedf(0.5)

func _draw() -> void:
	_draw_arm(far_shoulder, supporting_hand, -side, true)
	_draw_arm(near_shoulder, working_hand, side, false)

func _draw_arm(shoulder: Vector2, hand: Vector2, outward: float, far: bool) -> void:
	var elbow := shoulder.lerp(hand, 0.48) + Vector2(outward * 1.6, 1.8)
	ToolGesture.draw_sleeve(self, shoulder, elbow, hand, sleeve, far)
