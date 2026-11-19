extends Node

# Sample the head and torso within each 32-pixel character frame.
const BODY_SAMPLES := [Vector2(-2, -9), Vector2(2, -9), Vector2(-3, -2),
	Vector2(3, -2), Vector2(-3, 5), Vector2(3, 5)]
const BODY_BOUNDS := Rect2(-3, -9, 7, 15)
const OPACITY := [1.0, 0.76, 0.48, 0.30]
const PROP_COVER_SAMPLES := 4
const FADE_RATE := 9.0
const RESTORE_RATE := 5.0

class Cover:
	var sprite: Sprite2D
	var sort_origin: Node2D
	var original_alpha: float
	var first_fade_sample: int

	func _init(art: Sprite2D, origin: Node2D, first_sample: int) -> void:
		sprite = art
		sort_origin = art if origin == null else origin
		original_alpha = art.modulate.a
		first_fade_sample = first_sample

var _player: Player
var _room: Global.EstateRoom
var _cover: Array[Cover] = []

func _init(player: Player, room := Global.EstateRoom.OUTDOORS) -> void:
	name = "SceneryOcclusion"
	_player = player
	_room = room

func watch(sprite: Sprite2D, sort_origin: Node2D = null) -> void:
	# A grouped prop sorts at its parent's foot even when the art is raised.
	_cover.append(Cover.new(sprite, sort_origin, 1))

func watch_prop(sprite: Sprite2D, sort_origin: Node2D = null) -> void:
	# Keep foreground props solid when they only cover part of the body.
	_cover.append(Cover.new(sprite, sort_origin, PROP_COVER_SAMPLES))

func _process(delta: float) -> void:
	var body := _player.sprite
	var room_visible := Global.estate_room == _room and body.is_visible_in_tree()
	var body_pose := body.global_transform.translated_local(body.offset)
	var foot_y := _player.global_position.y
	for cover in _cover:
		var sprite := cover.sprite
		var alpha := cover.original_alpha
		if room_visible and foot_y < cover.sort_origin.global_position.y and sprite.is_visible_in_tree():
			alpha *= _opacity_at(cover, body_pose)
		var current := sprite.modulate.a
		if not is_equal_approx(current, alpha):
			var rate := FADE_RATE if alpha < current else RESTORE_RATE
			sprite.modulate.a = move_toward(current, alpha, delta * rate)

func _opacity_at(cover: Cover, body_pose: Transform2D) -> float:
	var sprite := cover.sprite
	var pose := sprite.global_transform.affine_inverse() * body_pose
	if not sprite.get_rect().intersects(pose * BODY_BOUNDS):
		return 1.0
	var covered := 0
	var fully_faded := cover.first_fade_sample + OPACITY.size() - 2
	for point: Vector2 in BODY_SAMPLES:
		if sprite.is_pixel_opaque(pose * point):
			covered += 1
			if covered == fully_faded:
				break
	return OPACITY[maxi(0, covered - cover.first_fade_sample + 1)]
