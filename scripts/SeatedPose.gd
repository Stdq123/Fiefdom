extends Node2D
class_name SeatedPose

enum Surface { STANDING, MAT, BENCH }

const CELL := 32
const UPPER_HEIGHT := 23.5
const REAR_ROW := 1
const SIDE_ROW := 2
const SETTLE_SECONDS := 0.16

var surface := Surface.STANDING
var _standing_sprite: Sprite2D
var _standing_alpha := 1.0
var _fabric := Color.WHITE
var _mirrored := false
var _lift := 0.0
var _settle: Tween

func _init(body: Sprite2D) -> void:
	name = "SeatedPose"
	_standing_sprite = body
	hide()

func _ready() -> void:
	_standing_sprite.frame_changed.connect(_redraw_if_seated)
	_standing_sprite.texture_changed.connect(_redraw_if_seated)

func present(next: Surface, fabric: Color) -> void:
	if surface == next and _fabric == fabric and _mirrored == _standing_sprite.flip_h:
		return
	var first := surface == Surface.STANDING
	surface = next
	_fabric = fabric
	_mirrored = _standing_sprite.flip_h
	if first:
		position = -_standing_sprite.position
		self_modulate = _standing_sprite.self_modulate
		_standing_alpha = _standing_sprite.self_modulate.a
		# Hide the standing art while keeping its transform, light and tint for this child.
		_standing_sprite.self_modulate.a = 0.0
		show()
		if can_process():
			_lift = 1.5
			_settle = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_settle.tween_method(_set_lift, _lift, 0.0, SETTLE_SECONDS)
	queue_redraw()

func restore_standing() -> void:
	if surface == Surface.STANDING:
		return
	if _settle and _settle.is_valid():
		_settle.kill()
	_lift = 0.0
	surface = Surface.STANDING
	_standing_sprite.self_modulate.a = _standing_alpha
	hide()

func _set_lift(value: float) -> void:
	_lift = snappedf(value, 0.5)
	queue_redraw()

func _redraw_if_seated() -> void:
	if surface != Surface.STANDING:
		queue_redraw()

func _draw() -> void:
	if surface == Surface.STANDING or _standing_sprite.texture == null:
		return
	var row := _standing_sprite.frame_coords.y
	var side := row == SIDE_ROW
	var bench := surface == Surface.BENCH
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if _mirrored else 1.0, 1.0))
	_draw_ground_shadow(7.0 if bench else 3.0)
	if bench:
		_draw_bench_legs(side)
	else:
		_draw_folded_legs(side, row == REAR_ROW)
	var frame := Vector2(_standing_sprite.frame_coords * CELL)
	var top := -19.0 if bench else -20.0
	var height := 22.0 if bench else UPPER_HEIGHT
	draw_texture_rect_region(_standing_sprite.texture, Rect2(-16.0, top - _lift, CELL, height),
		Rect2(frame, Vector2(CELL, height)))

func _draw_ground_shadow(y: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, y + 0.5), Vector2(-7, y - 0.75), Vector2(5, y - 1),
		Vector2(9, y), Vector2(7.5, y + 1.5), Vector2(-5.5, y + 1.75),
	]), Color("#29251f67"))

func _draw_folded_legs(side: bool, rear: bool) -> void:
	var outline := _fabric.lerp(Color("#261e22"), 0.74)
	var hem := _fabric.lerp(Color("#2e2630"), 0.43)
	var crest := _fabric.lerp(Color("#d4ad80"), 0.16)
	if side:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-5.5, -3.5), Vector2(0, -4), Vector2(4, -2.5), Vector2(7.5, -0.5),
			Vector2(8.5, 1), Vector2(8, 3), Vector2(5.5, 4.5), Vector2(-6, 4.5), Vector2(-7.5, 3),
			Vector2(-7.5, 1),
		]), outline)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-5, -3), Vector2(0, -3.5), Vector2(5.5, -1), Vector2(7.5, 1),
			Vector2(7, 2.5), Vector2(4.5, 3.5), Vector2(-5.5, 3.5), Vector2(-6.5, 2.5),
		]), hem)
		draw_line(Vector2(3, -1.5), Vector2(6.5, 0.5), crest, 0.5)
		draw_line(Vector2(5.5, 2.5), Vector2(-3.5, 3.5), outline, 0.5)
		return
	for side_sign: float in [-1.0, 1.0]:
		var rim := Color("#382b29") if rear else Color("#47332c")
		draw_colored_polygon(PackedVector2Array([
			Vector2(-0.5, -3.75), Vector2(5.0 * side_sign, -3.25), Vector2(7.75 * side_sign, -1.5),
			Vector2(8.5 * side_sign, 0.5), Vector2(8.0 * side_sign, 3.0), Vector2(5.0 * side_sign, 4.75),
			Vector2(0, 4.5),
		]), outline)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -3), Vector2(4.75 * side_sign, -2.75), Vector2(7.5 * side_sign, -0.75),
			Vector2(7.5 * side_sign, 1.75), Vector2(5.25 * side_sign, 3.5), Vector2(0, 3.5),
		]), hem)
		draw_line(Vector2(5 * side_sign, -2.0), Vector2(7 * side_sign, -0.5), crest, 0.5)
		draw_line(Vector2(6.5 * side_sign, 2.0), Vector2(4.0 * side_sign, 3.5), rim, 0.5)

func _draw_bench_legs(side: bool) -> void:
	var trousers := _fabric.lerp(Color("#2e2629"), 0.57)
	var fold := _fabric.lerp(Color("#ad8e6b"), 0.18)
	var shoe := Color("#342a27")
	for leg: float in [-1.0, 1.0]:
		var hip := leg * 2.75
		var knee := 2.75 + leg * 2.5 if side else leg * 5.25
		var ankle := knee - (1.5 if side else leg * 1.5)
		draw_rect(Rect2(ankle - 1.5, 5.0, 3.5, 2.5), shoe)
		draw_rect(Rect2(ankle - 1.0, 6.5, 2.5, 0.5), Color("#7a6048"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(hip - 2, -3), Vector2(hip + 2, -3), Vector2(knee + 3, 0.5),
			Vector2(knee + 2.5, 2.5), Vector2(ankle + 1.75, 6), Vector2(ankle - 1.5, 6.0),
			Vector2(knee - 2.5, 2.0), Vector2(knee - 3.0, 0.75),
		]), trousers)
		draw_line(Vector2(knee - 1.5, 1), Vector2(knee + 1.75, 1.25), fold, 0.5)
		draw_line(Vector2(knee - 1.0, 2.5), Vector2(ankle - 0.75, 5.5), trousers.lightened(0.12), 0.5)
