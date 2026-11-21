extends RefCounted
class_name StandingPose

const PERIOD := 4.4
const LIFT := &"shoulder_lift"
const MATERIAL := preload("res://resources/standing-motion.tres")

var _body: Sprite2D
var _phase: float
var _settle_wait: float
var _lift := 0.0

func _init(body: Sprite2D, settle_wait := 0.0) -> void:
	_body = body
	_body.material = MATERIAL
	_settle_wait = settle_wait
	_phase = -settle_wait

func advance(delta: float) -> void:
	_phase += delta
	if _phase >= PERIOD:
		_phase = fposmod(_phase, PERIOD)
	show_at(_phase)

func show_at(seconds: float) -> void:
	var inhale := smoothstep(0.32, 1.68, seconds)
	var exhale := 1.0 - smoothstep(1.86, 3.76, seconds)
	_set_lift(snappedf(0.85 * inhale * exhale, 0.05))

func clear() -> void:
	_phase = -_settle_wait
	_set_lift(0.0)

func _set_lift(value: float) -> void:
	if value != _lift:
		_lift = value
		_body.set_instance_shader_parameter(LIFT, value)
