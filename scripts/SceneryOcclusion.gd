extends Node

# Sample the head and torso within each 32-pixel character frame.
const BODY_SAMPLES := [Vector2(-2, -9), Vector2(2, -9), Vector2(-3, -2),
	Vector2(3, -2), Vector2(-3, 5), Vector2(3, 5)]
const BODY_BOUNDS := Rect2(-3, -9, 7, 15)
const OPACITY := [1.0, 0.76, 0.48, 0.30]
const FADE_RATE := 9.0
const RESTORE_RATE := 5.0

class Cover:
	var sprite: Sprite2D
	var sort_origin: Node2D
	var original_alpha: float

	func _init(art: Sprite2D, origin: Node2D) -> void:
		sprite = art
		sort_origin = origin
		original_alpha = art.modulate.a

var _player: Player
var _cover: Array[Cover] = []

func _init(player: Player) -> void:
	name = "SceneryOcclusion"
	_player = player

func watch(sprite: Sprite2D, sort_origin: Node2D = null) -> void:
	# A grouped prop sorts at its parent's foot even when the art is raised.
	_cover.append(Cover.new(sprite, sprite if sort_origin == null else sort_origin))

func _process(delta: float) -> void:
	var body := _player.sprite
	var outdoors := not Global.is_indoors() and body.is_visible_in_tree()
	var body_pose := body.global_transform.translated_local(body.offset)
	var foot_y := _player.global_position.y
	for cover in _cover:
		var sprite := cover.sprite
		var alpha := cover.original_alpha
		if outdoors and foot_y < cover.sort_origin.global_position.y and sprite.is_visible_in_tree():
			alpha *= _opacity_at(sprite, body_pose)
		var current := sprite.modulate.a
		if not is_equal_approx(current, alpha):
			var rate := FADE_RATE if alpha < current else RESTORE_RATE
			sprite.modulate.a = move_toward(current, alpha, delta * rate)

func _opacity_at(sprite: Sprite2D, body_pose: Transform2D) -> float:
	var pose := sprite.global_transform.affine_inverse() * body_pose
	if not sprite.get_rect().intersects(pose * BODY_BOUNDS):
		return 1.0
	var covered := 0
	for point: Vector2 in BODY_SAMPLES:
		if sprite.is_pixel_opaque(pose * point):
			covered += 1
			if covered == OPACITY.size() - 1:
				break
	return OPACITY[covered]
