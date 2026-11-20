extends Sprite2D
class_name ToolGesture

enum Action { TILL, SOW, WATER, HARVEST, BOW }

const HAND_TOOLS := "res://assets/characters/hand-tools.png"
const RECOVERY := 0.18
const REPLAY_INTERVAL := 0.10
const FIELD_REACH := 25.0
const EDGE_ADJUSTMENT := 12.0
# Grip positions are in the native tool frame, measured from its centre.
const GRIPS := [Vector2(0, -5), Vector2(-4, -2), Vector2(0, -9), Vector2(-6, 6), Vector2(5, 0)]
const HOE_REAR_GRIP := Vector2(-8, -5)
const HOE_EDGE := Vector2(10, 6)
const SICKLE_EDGE := Vector2(6, -5)
const PAIL_BASE := Vector2(4, 6)
const PAIL_LIP := Vector2(5, -1)

var carrying := false
var sleeve := Color("#82766d")
var body_lean := Vector2.ZERO
var aim := Vector2.DOWN
var elapsed := 0.0
var contact_time := 0.08
var reach := 0.0
var _field_point := Vector2.INF
var _contact_effects: Array[Callable] = []

func _ready() -> void:
	texture = load(HAND_TOOLS)
	hframes = Action.size()
	clear()

func perform(action: Action, toward: Vector2, windup := 0.08, field_point := Vector2.INF) -> void:
	if visible and not carrying and frame == action and elapsed < REPLAY_INTERVAL:
		_field_point = field_point
		_face(toward)
		_apply_pose()
		return
	_finish_contact()
	show_sample(action, toward, windup, 0.0, field_point)
	set_process(true)

func at_contact(effect: Callable) -> void:
	if elapsed >= contact_time:
		effect.call()
	else:
		_contact_effects.append(effect)

func _finish_contact() -> void:
	var effects := _contact_effects
	_contact_effects = []
	for effect in effects:
		if effect.is_valid():
			effect.call()

# Both the wardrobe and world actors use this same pose at a given point in a stroke.
func show_sample(action: Action, toward: Vector2, windup: float, time: float, field_point := Vector2.INF) -> void:
	set_process(false)
	_field_point = field_point
	_contact_effects.clear()
	contact_time = maxf(windup, 0.01)
	if time >= contact_time + RECOVERY:
		clear()
		return
	_face(toward)
	carrying = false
	frame = action
	elapsed = maxf(0.0, time)
	show()
	_apply_pose()

func carry_pail(toward: Vector2, step_height: float) -> void:
	if visible and not carrying:
		return
	_face(toward)
	carrying = true
	frame = Action.WATER
	reach = 0.0
	position = Vector2(-9 if flip_h else 9, 2 + step_height)
	rotation = 0.0
	show()
	queue_redraw()

func clear() -> void:
	carrying = false
	_field_point = Vector2.INF
	_contact_effects.clear()
	reach = 0.0
	body_lean = Vector2.ZERO
	hide()
	set_process(false)

func work_pose() -> int:
	if not visible or carrying or frame == Action.BOW:
		return -1
	return int(elapsed >= contact_time - 0.018 and elapsed < contact_time + RECOVERY * 0.72)

func _process(delta: float) -> void:
	if not _contact_effects.is_empty() and elapsed < contact_time and elapsed + delta >= contact_time:
		elapsed = contact_time
		_apply_pose()
		_finish_contact()
		return
	elapsed += delta
	if elapsed >= contact_time + RECOVERY:
		clear()
	else:
		_apply_pose()

func _face(toward: Vector2) -> void:
	if not toward.is_zero_approx():
		aim = toward.normalized()
	flip_h = aim.x < 0.0 if absf(aim.x) > 0.20 else aim.y > 0.0
	show_behind_parent = aim.y < 0.0 and absf(aim.y) >= absf(aim.x)

func _apply_pose() -> void:
	var side := -1.0 if flip_h else 1.0
	var swing := smoothstep(maxf(0.0, contact_time - 0.16), contact_time, elapsed)
	var release := smoothstep(contact_time, contact_time + RECOVERY, elapsed)
	reach = swing * (1.0 - release)
	var lift := sin(PI * swing)
	var hand := Vector2.ZERO
	var edge := Vector2.INF
	match frame:
		Action.TILL:
			edge = HOE_EDGE
			hand = Vector2((5.0 + reach * 2.0) * side, -10.0 + reach * 10.0 - lift * 2.0) + aim * (1.0 + reach * 3.0)
			var strike := clampf(atan2(aim.y + 0.38, absf(aim.x) + 0.20) - 0.60, -1.80, 1.04)
			rotation = lerpf(maxf(-2.55, strike - 1.45), strike, reach) * side
		Action.SOW:
			# The other hand broadcasts the grain. The pouch stays against the hip.
			hand = Vector2(-side * ((11.0 if show_behind_parent else 8.5) - reach), -0.5 - lift) + aim
			rotation = lerpf(-0.09, 0.16, reach) * side
		Action.WATER:
			hand = Vector2(side * (7.0 + reach * 3.5), -8.5 + reach * 1.5 - lift) + aim * (2.0 + reach)
			rotation = lerpf(-0.05, 1.03, reach) * side
		Action.HARVEST:
			edge = SICKLE_EDGE
			hand = Vector2(6.5 * side, -1.5 + lift) + aim * (3.0 + 3.0 * (1.0 - reach))
			var sweep := 1.38 + clampf(atan2(aim.y, absf(aim.x) + 0.20), -1.10, 0.70)
			rotation = lerpf(sweep - 1.10, sweep, reach) * side
		Action.BOW:
			var width := 10.0 if show_behind_parent else 8.0
			position = Vector2(width * side, -6.0 - lift * 4.0) + aim * (2.0 + 5.0 * reach)
			rotation = lerpf(-0.12, 0.08, reach) * side + Vector2(side, 0).angle_to(aim)
	if frame != Action.BOW:
		var mirror := Vector2(side, 1.0)
		var grip: Vector2 = GRIPS[frame] * mirror
		var ground := _near_field_point()
		if ground.is_finite() and edge.is_finite():
			if frame == Action.HARVEST:
				ground.y -= 3.0
			var blade := edge * mirror - grip
			rotation = lerp_angle(rotation, blade.angle_to(ground - hand), reach)
			hand += (ground - hand - blade.rotated(rotation)).limit_length(EDGE_ADJUSTMENT) * reach
		position = hand - grip.rotated(rotation)
	position = position.round()
	body_lean = (aim * reach * 2.0).round()
	queue_redraw()

func _near_field_point() -> Vector2:
	if not _field_point.is_finite():
		return Vector2.INF
	var ground := (get_parent() as Node2D).to_local(_field_point)
	var distance := ground.length()
	return ground if distance >= 8.0 and distance <= FIELD_REACH else Vector2.INF

func _water_stream(lip: Vector2, side: float, flow: float) -> PackedVector2Array:
	var ground := _near_field_point()
	if not ground.is_finite():
		return PackedVector2Array([lip, lip + Vector2(side * 3, 2) * flow, lip + Vector2(side * 4, 8) * flow])
	var end := lip.lerp(ground, flow)
	var bend := lip.lerp(end, 0.44) - Vector2(0, 1.5 * flow)
	return PackedVector2Array([lip, bend, end])

func _draw_grains(hand: Vector2, side: float) -> void:
	var ground := _near_field_point()
	if ground.is_finite():
		var release := contact_time * 0.50
		if elapsed >= release and elapsed < contact_time + 0.035:
			var progress := clampf(inverse_lerp(release, contact_time, elapsed), 0.0, 1.0)
			for grain in 3:
				var scatter := Vector2((grain - 1) * 2.0, absf(grain - 1.0))
				var at := hand.lerp(ground + scatter, progress) - Vector2(0, sin(progress * PI) * 4.0)
				draw_rect(Rect2(at.round(), Vector2(2, 1)), Color("#e7c474"))
	elif elapsed >= contact_time and elapsed < contact_time + RECOVERY * 0.74:
		var flight := (elapsed - contact_time) / RECOVERY
		for grain in 3:
			var at := hand + (aim + Vector2(side * 0.55, 0)) * (2 + grain * 2 + flight * 5)
			at.y += flight * 6 + absi(1 - grain)
			draw_rect(Rect2(at.round(), Vector2(2, 1)), Color("#e7c474"))

func _draw() -> void:
	if not visible:
		return
	var side := -1.0 if flip_h else 1.0
	var shift := body_lean
	var pose := work_pose()
	var profile := absf(aim.x) > absf(aim.y)
	if pose >= 0:
		shift = Vector2(side * (1.0 + pose) if profile else 0.0, pose * 2.0)
	var near_shoulder := Vector2((-0.5 if profile else 4.0) * side, -6.0) + shift
	var far_shoulder := Vector2((1.0 if profile else -4.0) * side, -6.5) + shift
	var mirror := Vector2(side, 1.0)
	var grip: Vector2 = transform * (GRIPS[frame] * mirror)
	# Hands, grains and water are drawn in actor space so gravity stays vertical as the tool turns.
	draw_set_transform_matrix(transform.affine_inverse())
	match frame:
		Action.TILL:
			_draw_arm(far_shoulder, transform * (HOE_REAR_GRIP * mirror), -side, true)
		Action.WATER:
			if not carrying:
				_draw_arm(far_shoulder, transform * (PAIL_BASE * mirror), -side, true)
				if reach > 0.67:
					var lip := transform * (PAIL_LIP * mirror)
					var stream := (reach - 0.67) / 0.33
					var water := _water_stream(lip, side, stream)
					draw_polyline(water, Color("#86b8aa"), 1.3)
					draw_rect(Rect2(water[-1].round() + Vector2(0, 2), Vector2(1, 2)), Color("#c4d9ba"))
		Action.SOW:
			_draw_arm(far_shoulder, grip, -side, true)
			grip = (Vector2(side * (1.0 + 7.0 * reach), -3.5) + aim * (4.0 * reach)).round()
			_draw_grains(grip, side)
		Action.HARVEST:
			var gathered := Vector2(side * 2.0, -3.0) + aim * (4.0 + 4.0 * (1.0 - reach))
			_draw_arm(far_shoulder, gathered, -side, true)
	_draw_arm(near_shoulder, grip, side, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_arm(shoulder: Vector2, hand: Vector2, outward: float, far: bool) -> void:
	var elbow := (shoulder.lerp(hand, 0.47) + Vector2(1.25 * outward, 2.25)).snappedf(0.5)
	draw_sleeve(self, shoulder, elbow, hand, sleeve, far)

# The rod and farm implements share the same cloth, cuff and grip at the actor's scale.
static func draw_sleeve(canvas: CanvasItem, shoulder: Vector2, elbow: Vector2, hand: Vector2, dye: Color, far: bool) -> void:
	var cloth := dye.darkened(0.23 if far else 0.06)
	var seam := cloth.darkened(0.40)
	var upper := shoulder.direction_to(elbow).orthogonal()
	var lower := elbow.direction_to(hand).orthogonal()
	var wrist := hand.move_toward(elbow, 1.15)
	if upper != Vector2.ZERO:
		canvas.draw_colored_polygon(PackedVector2Array([shoulder + upper * 1.8, elbow + upper * 1.5,
			elbow - upper * 1.5, shoulder - upper * 1.8]), cloth)
		canvas.draw_line(shoulder + Vector2(-0.5, -1.0), elbow + Vector2(-0.5, -0.5), cloth.lightened(0.18), 0.65)
	if lower != Vector2.ZERO and elbow.distance_to(wrist) > 0.15:
		canvas.draw_colored_polygon(PackedVector2Array([elbow + lower * 1.5, wrist + lower,
			wrist - lower, elbow - lower * 1.5]), cloth.darkened(0.10))
		canvas.draw_line(elbow + Vector2(0.0, 1.0), wrist + Vector2(0.0, 0.65), seam, 0.6)
		canvas.draw_line(wrist - lower * 0.85, wrist + lower * 0.85, cloth.lightened(0.22), 0.75)
	canvas.draw_circle(hand, 1.15, Color("#aa7453") if far else Color("#c18a63"))
	canvas.draw_circle(hand + Vector2(-0.35, -0.35), 0.67, Color("#cd9a71") if far else Color("#e0ae7f"))
