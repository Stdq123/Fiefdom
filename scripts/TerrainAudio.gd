extends Node

enum Surface { GRASS, TRACK, PLANK, SHALLOWS, SNOW, STONE }

const CREEK := preload("res://assets/audio/creek.wav")
const RAIN := preload("res://assets/audio/rain.wav")
const BIRDS := preload("res://assets/audio/woodland-birds.wav")
const CRICKETS_PATH := "res://assets/audio/night-crickets.wav"
const RAIN_BUS := &"Rain"
const OPEN_AIR_CUTOFF := 20000.0
const SHELTERED_CUTOFF := 1500.0
const SHELTER_FADE_SECONDS := 0.32
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

var _creek_gain := 0.0
var _rain_gain := 0.0
var _bird_gain := 0.0
var _cricket_gain := 0.0
var _sheltered := false
var _shelter_mix := 0.0
var _rain_filter := AudioEffectLowPassFilter.new()

func _ready() -> void:
	var weather_bus := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(weather_bus, RAIN_BUS)
	AudioServer.set_bus_send(weather_bus, &"Ambience")
	_rain_filter.db = AudioEffectFilter.FILTER_12DB
	_rain_filter.cutoff_hz = OPEN_AIR_CUTOFF
	AudioServer.add_bus_effect(weather_bus, _rain_filter)
	creek = _add_loop("Creek", CREEK)
	rain = _add_loop("Rain", RAIN)
	rain.bus = RAIN_BUS
	birds = _add_loop("WoodlandBirds", BIRDS)
	crickets = _add_loop("NightCrickets", load(CRICKETS_PATH))
	footsteps = AudioStreamPlayer.new()
	footsteps.name = "Footsteps"
	footsteps.bus = "Ambience"
	footsteps.volume_db = -13.0
	add_child(footsteps)

func set_ambience(creek_distance: float, raining: bool, birds_distance: float,
	cricket_distance: float, dusk: float, sheltered: bool) -> void:
	_sheltered = sheltered
	_creek_gain = (1.0 - smoothstep(20.0, 145.0, creek_distance)) * 0.50
	_rain_gain = (0.12 if sheltered else 0.39) if raining else 0.0
	_bird_gain = 0.0 if raining else (1.0 - smoothstep(28.0, 134.0, birds_distance)) * 0.28 * (1.0 - dusk)
	_cricket_gain = 0.0 if raining else (1.0 - smoothstep(24.0, 127.0, cricket_distance)) * 0.34 * dusk

func fade_out() -> void:
	set_ambience(INF, false, INF, INF, 0.0, false)

func _process(delta: float) -> void:
	_fade_loop(creek, _creek_gain, delta)
	_fade_loop(rain, _rain_gain, delta)
	_fade_loop(birds, _bird_gain, delta)
	_fade_loop(crickets, _cricket_gain, delta)
	var mix := move_toward(_shelter_mix, float(_sheltered), delta / SHELTER_FADE_SECONDS)
	if mix != _shelter_mix:
		_shelter_mix = mix
		_rain_filter.cutoff_hz = exp(lerpf(log(OPEN_AIR_CUTOFF), log(SHELTERED_CUTOFF), _shelter_mix))

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
