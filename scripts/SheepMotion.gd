extends Node2D
class_name SheepMotion

const ART := preload("res://assets/characters/sheep.png")
const CELL_WIDTH := 22.0
const ART_ORIGIN := Vector2(-11, -17)
const BODY := Rect2(0, 0, 14, 14)
const WOOL_EDGE := Rect2(14, 0, 5, 7)
const HEAD := Rect2(13, 7, 9, 7)
const MUZZLE := Rect2(17, 14, 4, 2)
const HEAD_PIVOT := Vector2(2.5, -8.5)
const NOSE := Vector2(9.0, -4.5)
const STRIDE := 8.0
const STANCE := 0.64
const HIPS := [Vector2(-5, -4), Vector2(4, -4), Vector2(-3, -4.5), Vector2(1.5, -5)]
const HOOVES := [Vector2(-5, 0), Vector2(4, 0), Vector2(-3, -1.5), Vector2(2, -1.5)]
const OFFSETS := [0.0, 0.5, 0.75, 0.25]

var full_fleece := false
var flip_h := false
var walking := false
var head_drop := 0.0
var gait := 0.0
var _stride_direction := Vector2.RIGHT
var _body_lift := 0.0

func present(foot: Vector2, heading: Vector2, dip: float, delta: float) -> void:
	var travel := foot - position
	position = foot
	if absf(heading.x) > 0.01:
		flip_h = heading.x < 0.0
	var distance := travel.length()
	walking = delta > 0.0 and distance > 0.001
	if walking:
		_stride_direction = Vector2(travel.x * _side(), travel.y) / distance
		gait = fposmod(gait + distance / STRIDE, 1.0)
	else:
		gait = 0.0
	_body_lift = -roundf(absf(sin(gait * TAU)) * 0.9) * 0.5
	head_drop = move_toward(head_drop, dip, delta * 4.7) if delta > 0.0 else dip
	queue_redraw()

func hoof_position(index: int) -> Vector2:
	var rest: Vector2 = HOOVES[index]
	if not walking:
		return rest
	var cycle := fposmod(gait + float(OFFSETS[index]), 1.0)
	var reach := STRIDE * STANCE * 0.5
	var sweep := lerpf(reach, -reach, cycle / STANCE)
	var lift := 0.0
	if cycle >= STANCE:
		var swing := (cycle - STANCE) / (1.0 - STANCE)
		sweep = lerpf(-reach, reach, smoothstep(0.0, 1.0, swing))
		lift = sin(swing * PI) * 1.65
	return (rest + _stride_direction * sweep - Vector2(0, lift)).snappedf(0.5)

func nose_position() -> Vector2:
	var at := _head_transform() * NOSE
	return Vector2(at.x * _side(), at.y)

func fleece_contact() -> Vector2:
	return Vector2(-2 * _side(), -10.0 + _body_lift)

func _side() -> float:
	return -1.0 if flip_h else 1.0

func _head_transform() -> Transform2D:
	var shift := Vector2(0, _body_lift + head_drop * 1.2)
	return Transform2D(head_drop * 0.36, HEAD_PIVOT + shift).translated_local(-HEAD_PIVOT)

func _draw() -> void:
	var shadow := PackedVector2Array()
	for i in 10:
		shadow.append(Vector2(0.6, -0.3) + Vector2.from_angle(TAU * i / 10.0) * Vector2(8.7, 2.25))
	draw_colored_polygon(shadow, Color("#323a3068"))
	var facing := Transform2D(0.0, Vector2(_side(), 1.0), 0.0, Vector2.ZERO)
	draw_set_transform_matrix(facing)
	_draw_leg(2, true)
	_draw_leg(3, true)
	_draw_leg(0, false)
	_draw_leg(1, false)
	draw_set_transform_matrix(facing * _head_transform())
	_draw_part(HEAD)
	_draw_part(MUZZLE)
	draw_set_transform_matrix(facing.translated_local(Vector2(0, _body_lift)))
	_draw_part(BODY)
	_draw_part(WOOL_EDGE)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_part(region: Rect2) -> void:
	var sample := Rect2(region.position + Vector2(CELL_WIDTH * int(full_fleece), 0), region.size)
	draw_texture_rect_region(ART, Rect2(ART_ORIGIN + region.position, region.size), sample)

func _draw_leg(index: int, far: bool) -> void:
	var hip: Vector2 = HIPS[index] + Vector2(0, _body_lift)
	var hoof := hoof_position(index)
	var knee := hip.lerp(hoof, 0.55) + Vector2(-0.45 if index % 2 == 0 else 0.45, 0)
	var border := Color("#302d28")
	var wool := Color("#554e40") if far else Color("#79705d")
	draw_line(hip, knee, border, 2.65)
	draw_line(knee, hoof - Vector2(0, 0.75), border, 2.25)
	draw_line(hip, knee, wool, 1.2)
	draw_rect(Rect2(hoof - Vector2(1.0, 1.0), Vector2(2.1, 1.3)), border)
