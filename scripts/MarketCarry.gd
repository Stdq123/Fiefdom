extends Sprite2D
class_name MarketCarry

@export var sleeve := Color("#76685b")
@export var grip := Vector2(0, -12)
@export var support := Vector2.INF

@onready var body: NeighborMotion = $"../Body"

func hold(hang: float) -> void:
	body.carry_at(self, hang)
	queue_redraw()

func _draw() -> void:
	var side := -1.0 if body.flip_h else 1.0
	var profile := body.facing == NeighborMotion.Facing.PROFILE
	var bob := -0.75 if body.walking and body.frame_coords.x in [1, 2] else 0.0
	var shoulder := body.position + Vector2((0.5 if profile else 3.5) * side, -1.5 + bob)
	var far_shoulder := body.position + Vector2((-1.0 if profile else -3.5) * side, -2.0 + bob)
	var mirror := Vector2(side, 1.0)
	draw_set_transform_matrix(transform.affine_inverse())
	if support.is_finite():
		_draw_arm(far_shoulder, transform * (support * mirror), -side, true)
	_draw_arm(shoulder, transform * (grip * mirror), side, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_arm(shoulder: Vector2, hand: Vector2, outward: float, far: bool) -> void:
	var elbow := (shoulder.lerp(hand, 0.50) + Vector2(1.5 * outward, 2.0)).snappedf(0.5)
	ToolGesture.draw_sleeve(self, shoulder, elbow, hand, sleeve, far)
