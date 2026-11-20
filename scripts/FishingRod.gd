extends Node2D
class_name FishingRod

enum Pose { WAIT, BITE, PULL, EASE }

const CAST_SECONDS := 0.32

var grip := Vector2.ZERO
var tip := Vector2.ZERO
var bend := Vector2.ZERO
var side := 1.0
var above := false
var sleeve := Color.WHITE
var last_time := -1.0
var lift := 0.0
var strain := 0.0

@onready var angler := get_parent() as Player
var old_frame: Vector2i
var old_flip: bool
var old_offset: Vector2
var tool_visible: bool

func _ready() -> void:
	old_frame = angler.sprite.frame_coords
	old_flip = angler.sprite.flip_h
	old_offset = angler.sprite.offset
	tool_visible = angler.tool_gesture.visible
	angler.tool_gesture.hide()
	sleeve = angler.tool_gesture.sleeve

func _exit_tree() -> void:
	if is_instance_valid(angler) and is_instance_valid(angler.sprite):
		angler.sprite.frame_coords = old_frame
		angler.sprite.flip_h = old_flip
		angler.sprite.offset = old_offset
		if is_instance_valid(angler.tool_gesture):
			angler.tool_gesture.visible = tool_visible

func present(water: Vector2, pose: Pose, seconds: float, tension: float) -> void:
	var target := to_local(water)
	var direction := target.normalized()
	side = -1.0 if direction.x < -0.05 else 1.0
	var profile := absf(direction.x) >= absf(direction.y)
	above = not profile and direction.y < 0.0
	var row := Player.Facing.PROFILE if profile else (Player.Facing.BACK if above else Player.Facing.FRONT)
	var casting := 1.0 - smoothstep(0.0, CAST_SECONDS, seconds)
	var beat := sin(seconds * 9.0)
	var lift_to := casting
	var strain_to := 0.0
	match pose:
		Pose.BITE:
			lift_to = -0.17
			strain_to = 0.55
		Pose.PULL:
			lift_to = 0.79 + 0.14 * beat
			strain_to = 0.45 + 0.55 * tension
		Pose.EASE:
			lift_to = 0.18 + 0.10 * beat
			strain_to = 0.20 + 0.55 * tension
	var weight := 1.0 if last_time < 0.0 or seconds < last_time else 1.0 - exp(-18.0 * (seconds - last_time))
	lift = lerpf(lift, lift_to, weight)
	strain = lerpf(strain, strain_to, weight)
	last_time = seconds
	angler.sprite.flip_h = profile and side < 0.0
	angler.sprite.offset = Vector2.ZERO
	var braced := pose == Pose.BITE or pose == Pose.PULL or casting > 0.65
	angler.sprite.frame_coords = Vector2i(PlayerAttire.WORK_COLUMN + int(braced), row)
	grip = (Vector2(side * (6.0 if profile else 4.0), -6.0 - lift * 4.0) + direction * 2.0).round()
	var reach := minf(23.0 - 11.0 * lift, maxf(4.0, target.length() * 0.65))
	tip = (grip + direction * reach + Vector2.UP * (11.0 + 13.0 * lift - 2.0 * strain)).snappedf(0.5)
	bend = (grip.lerp(tip, 0.56) + Vector2.UP * (3.0 + 6.0 * strain)).snappedf(0.5)
	queue_redraw()

func _point(t: float) -> Vector2:
	return grip.lerp(bend, t).lerp(bend.lerp(tip, t), t).snappedf(0.5)

func _draw() -> void:
	var profile := angler.sprite.frame_coords.y == Player.Facing.PROFILE
	var braced := angler.sprite.frame_coords.x == PlayerAttire.WORK_COLUMN + 1
	var lean := Vector2(side * (2.0 if braced else 0.0) if profile else 0.0, 1.5 if braced else -0.5)
	var cuff := Vector2(side * (1.0 if profile else -3.5), -6.5) + lean
	var support := _point(0.19)
	if not above:
		ToolGesture.draw_sleeve(self, cuff, cuff.lerp(support, 0.5) + Vector2(-side, 2), support, sleeve, true)
	var heel := grip + grip.direction_to(bend) * -3.0
	var start := heel
	for i in range(1, 7):
		var t := i / 6.0
		var end := _point(t)
		draw_line(start, end, Color("#51432e"), lerpf(3.3, 1.2, t))
		draw_line(start + Vector2.UP * 0.5, end + Vector2.UP * 0.5, Color("#c3aa69"), lerpf(1.6, 0.7, t))
		if i < 6:
			draw_line(end + Vector2.UP, end + Vector2.DOWN * 0.5, Color("#766442"), 1.0)
		start = end
	var near_shoulder := Vector2(side * (-0.5 if profile else 4.0), -6.0) + lean
	var elbow := near_shoulder.lerp(grip, 0.46) + Vector2(side, 2.25)
	ToolGesture.draw_sleeve(self, near_shoulder, elbow, grip, sleeve, false)
