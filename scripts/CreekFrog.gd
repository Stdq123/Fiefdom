extends Node2D

enum Phase { BANK, LEAP, WATER }

const FROG := preload("res://assets/world/scriptoy/creek-frog.png")
const CROAK := preload("res://assets/audio/creek-frog.wav")
const HEARING_RANGE := 104.0
const STARTLE_DISTANCE := 30.0
const RETURN_DISTANCE := 78.0
const LEAP_SECONDS := 0.36
const RIPPLE_SECONDS := 0.61
const HIDE_SECONDS := 6.0

@export var player: Node2D
@export var water_offset := Vector2(33, -3)

@onready var body := Sprite2D.new()
@onready var croak := AudioStreamPlayer2D.new()
var phase := Phase.BANK
var phase_time := 0.0
var next_call := 0.45
var play_audio := DisplayServer.get_name() != "headless"

func _ready() -> void:
	body.texture = FROG
	body.hframes = 2
	body.offset = Vector2(0, -7)
	body.scale = Vector2(0.67, 0.67)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(body)
	croak.stream = CROAK
	croak.bus = &"Ambience"
	croak.max_distance = HEARING_RANGE
	croak.volume_db = -12.0
	add_child(croak)
	GameEvents.day_advanced.connect(_update_weather.unbind(1))
	_update_weather()

func _update_weather() -> void:
	var active := Global.season_index() <= Global.Season.SUMMER
	if active != visible:
		_return_to_bank()
	visible = active
	set_process(active)
	if not active:
		croak.stop()
	body.self_modulate = Color("#9fae81") if Global.has_rain() else Color("#bbc68e")

func _return_to_bank() -> void:
	phase = Phase.BANK
	phase_time = 0.0
	next_call = 0.45
	body.position = Vector2.ZERO
	body.frame = 0
	body.show()
	queue_redraw()

func _process(delta: float) -> void:
	var distance := global_position.distance_to(player.global_position)
	match phase:
		Phase.BANK:
			if distance < STARTLE_DISTANCE:
				phase = Phase.LEAP
				body.frame = 1
			elif distance < HEARING_RANGE:
				next_call -= delta
				if next_call <= 0.0:
					if play_audio:
						croak.play()
					next_call = 8.0
		Phase.LEAP:
			phase_time += delta
			var progress := minf(1.0, phase_time / LEAP_SECONDS)
			body.position = (water_offset * progress - Vector2(0, sin(PI * progress) * 9.0)).round()
			if progress >= 1.0:
				phase = Phase.WATER
				phase_time = 0.0
				body.hide()
			queue_redraw()
		Phase.WATER:
			var last_time := phase_time
			phase_time += delta
			if last_time < RIPPLE_SECONDS:
				queue_redraw()
			if phase_time >= HIDE_SECONDS and distance > RETURN_DISTANCE:
				_return_to_bank()

func _draw() -> void:
	if phase == Phase.BANK:
		draw_rect(Rect2(-4, -1, 8, 2), Color("#263a2b9e"))
	elif phase == Phase.LEAP:
		var shadow := (water_offset * minf(1.0, phase_time / LEAP_SECONDS)).round()
		draw_rect(Rect2(shadow - Vector2(3, 0), Vector2(6, 1)), Color("#263a2b66"))
	elif phase_time < RIPPLE_SECONDS:
		var progress := phase_time / RIPPLE_SECONDS
		var spread := roundf(3.0 + 8.0 * progress)
		var points := PackedVector2Array()
		for vertex in 9:
			var angle := vertex * TAU / 8.0
			points.append(water_offset + (Vector2(cos(angle), sin(angle) * 0.43) * spread).round())
		draw_polyline(points, Color(0.72, 0.86, 0.79, (1.0 - progress) * 0.88), 1.0)
