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
	var sample_mask := 0
	var target_alpha: float

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
	var depth := PackedInt32Array()
	depth.resize(BODY_SAMPLES.size())
	var blockers := 0
	for cover in _cover:
		cover.sample_mask = 0
		cover.target_alpha = cover.original_alpha
		if (not room_visible or cover.original_alpha <= 0.0 or foot_y >= cover.sort_origin.global_position.y
				or not cover.sprite.is_visible_in_tree()):
			continue
		cover.sample_mask = _covered_samples(cover.sprite, body_pose)
		if cover.sample_mask == 0:
			continue
		blockers += 1
		var covered := 0
		for sample in BODY_SAMPLES.size():
			if cover.sample_mask & (1 << sample):
				covered += 1
				depth[sample] += 1
		var level := clampi(covered - cover.first_fade_sample + 1, 0, OPACITY.size() - 1)
		cover.target_alpha *= OPACITY[level]
	if blockers > 1:
		_share_opacity(depth)
	for cover in _cover:
		var sprite := cover.sprite
		var alpha := cover.target_alpha
		var current := sprite.modulate.a
		if not is_equal_approx(current, alpha):
			var rate := FADE_RATE if alpha < current else RESTORE_RATE
			sprite.modulate.a = move_toward(current, alpha, delta * rate)

func _covered_samples(sprite: Sprite2D, body_pose: Transform2D) -> int:
	var pose := sprite.global_transform.affine_inverse() * body_pose
	if not sprite.get_rect().intersects(pose * BODY_BOUNDS):
		return 0
	var mask := 0
	for sample in BODY_SAMPLES.size():
		if sprite.is_pixel_opaque(pose * BODY_SAMPLES[sample]):
			mask |= 1 << sample
	return mask

func _share_opacity(depth: PackedInt32Array) -> void:
	var covered := 0
	for layers in depth:
		covered += int(layers > 0)
	if covered < PROP_COVER_SAMPLES:
		return
	var maximum: float = OPACITY[covered - PROP_COVER_SAMPLES + 1]
	var limits := PackedFloat32Array()
	# Light from the character passes through each foreground layer at a shared sample.
	for layers in depth:
		limits.append(1.0 - pow(1.0 - maximum, 1.0 / maxi(layers, 1)))
	for cover in _cover:
		if cover.sample_mask == 0:
			continue
		for sample in BODY_SAMPLES.size():
			if cover.sample_mask & (1 << sample):
				cover.target_alpha = minf(cover.target_alpha, limits[sample])
