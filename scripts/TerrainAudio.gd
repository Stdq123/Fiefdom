extends Node

enum Surface { GRASS, TRACK, PLANK, SHALLOWS, SNOW, STONE }

const CREEK := preload("res://assets/audio/creek.wav")
const RAIN := preload("res://assets/audio/rain.wav")
const BIRDS := preload("res://assets/audio/woodland-birds.wav")
const CRICKETS_PATH := "res://assets/audio/night-crickets.wav"
const STEPS := {
	Surface.GRASS: [preload("res://assets/audio/grass-1.wav"), preload("res://assets/audio/grass-2.wav")],
	Surface.TRACK: [preload("res://assets/audio/track-1.wav"), preload("res://assets/audio/track-2.wav")],
	Surface.PLANK: [preload("res://assets/audio/plank-1.wav"), preload("res://assets/audio/plank-2.wav")],
	Surface.SHALLOWS: [preload("res://assets/audio/water-1.wav"), preload("res://assets/audio/water-2.wav")],
	Surface.SNOW: [preload("res://assets/audio/snow-1.wav"), preload("res://assets/audio/snow-2.wav")],
	Surface.STONE: [preload("res://assets/audio/stone-1.wav"), preload("res://assets/audio/stone-2.wav")],
}

var creek: AudioStreamPlayer
var rain: AudioStreamPlayer
var birds: AudioStreamPlayer
var crickets: AudioStreamPlayer
var footsteps: AudioStreamPlayer
var step_variant := 0
var play_audio := DisplayServer.get_name() != "headless"

func _ready() -> void:
	creek = _add_loop("Creek", CREEK)
	rain = _add_loop("Rain", RAIN)
	birds = _add_loop("WoodlandBirds", BIRDS)
	crickets = _add_loop("NightCrickets", load(CRICKETS_PATH))
	footsteps = AudioStreamPlayer.new()
	footsteps.name = "Footsteps"
	footsteps.bus = "Ambience"
	footsteps.volume_db = -13.0
	add_child(footsteps)

func update_ambience(delta: float, creek_distance: float, raining: bool, birds_distance: float,
	cricket_distance: float, dusk: float, sheltered: bool) -> void:
	var creek_gain := (1.0 - smoothstep(20.0, 145.0, creek_distance)) * 0.50
	var birds_gain := (1.0 - smoothstep(28.0, 134.0, birds_distance)) * 0.28 * (1.0 - dusk)
	var cricket_gain := (1.0 - smoothstep(24.0, 127.0, cricket_distance)) * 0.34 * dusk
	_fade_loop(creek, creek_gain, delta)
	var rain_gain := 0.12 if sheltered else 0.39
	_fade_loop(rain, rain_gain if raining else 0.0, delta)
	_fade_loop(birds, 0.0 if raining else birds_gain, delta)
	_fade_loop(crickets, 0.0 if raining else cricket_gain, delta)

func play_step(surface: Surface) -> void:
	var samples: Array = STEPS[surface]
	footsteps.stream = samples[step_variant % samples.size()]
	step_variant += 1
	if play_audio:
		footsteps.play()

func _add_loop(player_name: StringName, stream: AudioStreamWAV) -> AudioStreamPlayer:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	var loop := AudioStreamPlayer.new()
	loop.name = player_name
	loop.stream = stream
	loop.bus = "Ambience"
	loop.volume_linear = 0.0
	add_child(loop)
	return loop

func _fade_loop(loop: AudioStreamPlayer, target: float, delta: float) -> void:
	var gain := move_toward(loop.volume_linear, target, delta * 0.85)
	loop.volume_linear = gain
	if not play_audio:
		return
	if gain > 0.0 and not loop.playing:
		loop.play()
	elif is_zero_approx(gain) and loop.playing:
		loop.stop()
