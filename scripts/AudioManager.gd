extends Node

const SFX_SAMPLE_RATE := 22050
# Indexed by Player.Action from TILL through HARVEST.
const FIELD_SOUND_PATHS := [
	"res://assets/audio/farm/till.wav",
	"res://assets/audio/farm/sow.wav",
	"res://assets/audio/farm/water.wav",
	"res://assets/audio/farm/harvest.wav",
]
const FIELD_REPEAT_SECONDS := 0.09
const CEREMONY_BELL := preload("res://assets/audio/music/bronze-bell.wav")
const BAMBOO_SLIPS := preload("res://assets/audio/rotation-slip.wav")
const TITLE_SCORE := "res://assets/audio/music/score-title.ogg"
const RAVINE_SCORE := "res://assets/audio/music/score-ravine.ogg"
const WEST_MARKET_SCORE := "res://assets/audio/music/score-west-market.ogg"
const SEASON_SCORES := [
	"res://assets/audio/music/score-spring.ogg",
	"res://assets/audio/music/score-summer.ogg",
	"res://assets/audio/music/score-autumn.ogg",
	"res://assets/audio/music/score-winter.ogg",
]
const SCORE_GAIN := 0.36
const CROSSFADE_SECONDS := 1.45
const TERRAIN_AUDIO := preload("res://scripts/TerrainAudio.gd")

var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var ui_sfx_player: AudioStreamPlayer
var terrain_audio: TERRAIN_AUDIO
var field_sounds: Array[AudioStreamWAV] = []
var _music_players: Array[AudioStreamPlayer] = []
var _music_gains: Array[float] = [0.0, 0.0]
var _music_bookmarks: Dictionary[AudioStream, float] = {}
var _music_focus: Dictionary[int, float] = {}
var _focus_gain := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect to game events
	GameEvents.rank_changed.connect(_on_rank_changed)
	GameEvents.tax_reform_triggered.connect(_on_tax_reform_triggered)
	GameEvents.tax_reform_choice_made.connect(_on_tax_reform_choice)
	GameEvents.well_field_added.connect(_on_well_field_added)
	GameEvents.well_field_reclaimed.connect(_on_well_field_reclaimed)
	GameEvents.campaign_ended.connect(_on_campaign_ended)
	GameEvents.day_advanced.connect(_sync_score.unbind(1))
	get_tree().scene_changed.connect(_sync_score)

	for bus in [&"Music", &"SFX", &"Ambience"]:
		if AudioServer.get_bus_index(bus) < 0:
			var index := AudioServer.bus_count
			AudioServer.add_bus()
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")
	Preferences.apply_music_volume()
	Preferences.apply_ambience_volume()

	terrain_audio = TERRAIN_AUDIO.new()
	terrain_audio.name = "TerrainAudio"
	add_child(terrain_audio)

	for index in _music_gains.size():
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % (index + 1)
		player.bus = &"Music"
		player.volume_linear = 0.0
		add_child(player)
		_music_players.append(player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	sfx_player.volume_db = -7.0
	add_child(sfx_player)

	ui_sfx_player = AudioStreamPlayer.new()
	ui_sfx_player.bus = "SFX"
	ui_sfx_player.volume_db = -8.0
	add_child(ui_sfx_player)
	if DisplayServer.get_name() != "headless":
		for path in FIELD_SOUND_PATHS:
			field_sounds.append(load(path))
	_sync_score.call_deferred()

func set_world_ambience(creek_distance: float, birds_distance: float, cricket_distance: float,
		under_roof := false) -> void:
	var season := Global.season_index()
	var birds := birds_distance if season != Global.Season.WINTER else INF
	var crickets := cricket_distance if season in [Global.Season.SUMMER, Global.Season.AUTUMN] else INF
	terrain_audio.set_ambience(creek_distance, Global.has_rain(), birds, crickets,
		Global.dusk_amount(), under_roof or Global.is_indoors())

func _sync_score() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path := ""
	match scene.scene_file_path:
		Global.TITLE_SCENE:
			terrain_audio.fade_out()
			path = TITLE_SCORE
		Global.ESTATE_SCENE, Global.WEST_ROAD_SCENE:
			path = SEASON_SCORES[Global.season_index()]
		Global.WEST_MARKET_SCENE:
			path = WEST_MARKET_SCORE
		Global.WILDERNESS_SCENE:
			path = RAVINE_SCORE
		_:
			terrain_audio.fade_out()
	if bgm_player and bgm_player.stream.resource_path == path:
		return
	bgm_player = null
	if path.is_empty():
		return
	var score := load(path) as AudioStreamOggVorbis
	if score == null:
		return
	for player in _music_players:
		if player.stream == score:
			bgm_player = player
			return
	# A third cue during a fade replaces the quieter player.
	var index := 0 if _music_gains[0] <= _music_gains[1] else 1
	bgm_player = _music_players[index]
	_stop_score(bgm_player)
	_music_gains[index] = 0.0
	bgm_player.volume_linear = 0.0
	bgm_player.stream = score
	if DisplayServer.get_name() != "headless":
		bgm_player.play(_music_bookmarks.get(score, 0.0))

func _process(delta: float) -> void:
	var focus := 1.0
	for gain in _music_focus.values():
		focus = minf(focus, gain)
	var focus_speed := 6.0 if focus < _focus_gain else 2.0
	_focus_gain = move_toward(_focus_gain, focus, delta * focus_speed)
	for index in _music_players.size():
		var player := _music_players[index]
		if player.stream == null:
			continue
		var target := 1.0 if player == bgm_player else 0.0
		var gain := move_toward(_music_gains[index], target, delta / CROSSFADE_SECONDS)
		_music_gains[index] = gain
		player.volume_linear = gain * SCORE_GAIN * _focus_gain
		if target == 0.0 and gain == 0.0:
			_stop_score(player)

func _stop_score(player: AudioStreamPlayer) -> void:
	if player.playing:
		_music_bookmarks[player.stream] = player.get_playback_position()
		player.stop()
	player.stream = null

func duck_music_for(owner: Node, gain: float) -> void:
	var key := owner.get_instance_id()
	if not _music_focus.has(key):
		owner.tree_exiting.connect(_release_music_focus.bind(key), CONNECT_ONE_SHOT)
	_music_focus[key] = clampf(gain, 0.0, 1.0)

func _release_music_focus(key: int) -> void:
	_music_focus.erase(key)

func play_field_action(action: int) -> void:
	if action < 0 or action >= field_sounds.size():
		return
	var sound := field_sounds[action]
	if sfx_player.playing and sfx_player.stream == sound and sfx_player.get_playback_position() < FIELD_REPEAT_SECONDS:
		return
	sfx_player.stream = sound
	sfx_player.play()

func play_sfx(stream: AudioStream, volume := 0.0, pitch := 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = pitch
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func play_world_sfx(stream: AudioStream, source: Node2D, volume := 0.0, hearing_range := 450.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var sound := AudioStreamPlayer2D.new()
	sound.bus = &"SFX"
	sound.max_distance = hearing_range
	sound.volume_db = volume
	sound.stream = stream
	source.get_parent().add_child(sound)
	sound.global_position = source.global_position
	sound.finished.connect(sound.queue_free)
	sound.play()

# Play UI sound effect (button clicks, etc.)
func play_ui_sfx(pitch: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	ui_sfx_player.pitch_scale = pitch
	if ui_sfx_player.stream == null:
		ui_sfx_player.stream = _make_tone_sequence([440], 0.08)
	ui_sfx_player.play()

# Play event sound (rank up, special events)
func play_event_sound(event_type: String) -> void:
	match event_type:
		"rank_up":
			# Ascending tone
			_play_tone_sequence([440, 554, 659], 0.1)  # A4, C#5, E5 (A major chord)
		"well_field_added":
			# Pleasant notification
			_play_tone_sequence([523, 659], 0.15)  # C5, E5
		"first_tribute":
			play_sfx(CEREMONY_BELL, -12.0, 1.26)
		"present_ledger":
			play_sfx(BAMBOO_SLIPS, -10.0)
		"hurt":
			_play_tone_sequence([185, 130], 0.055)

func _play_tone_sequence(frequencies: Array, duration: float) -> void:
	if DisplayServer.get_name() != "headless":
		play_sfx(_make_tone_sequence(frequencies, duration))

func _make_tone_sequence(frequencies: Array, duration: float) -> AudioStreamWAV:
	var frames_per_note := roundi(SFX_SAMPLE_RATE * duration)
	var samples := PackedByteArray()
	samples.resize(2 * frames_per_note * frequencies.size())
	for note in range(frequencies.size()):
		var step := TAU * float(frequencies[note]) / SFX_SAMPLE_RATE
		for frame in range(frames_per_note):
			var fade := minf(1.0, minf(frame, frames_per_note - frame - 1) / 64.0)
			var wave := sin(step * frame)
			var sample := roundi(wave * fade * 9000.0)
			samples.encode_s16(2 * (note * frames_per_note + frame), sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SFX_SAMPLE_RATE
	stream.data = samples
	return stream

# Event handlers
func _on_rank_changed(new_rank: Global.Rank) -> void:
	print("Audio: Playing rank up sound!")
	play_event_sound("rank_up")

func _on_tax_reform_triggered() -> void:
	play_sfx(CEREMONY_BELL, -12.0, 0.78)

func _on_tax_reform_choice(_choice: Global.TaxReformChoice) -> void:
	play_sfx(BAMBOO_SLIPS, -8.0)

func _on_well_field_added(field_id: int) -> void:
	print("Audio: Playing well field added sound!")
	play_event_sound("well_field_added")

func _on_well_field_reclaimed(_field_id: int, progress: int) -> void:
	if progress == Global.RECLAMATION_NIGHTS:
		play_sfx(CEREMONY_BELL, -14.0, 1.0)

func _on_campaign_ended(result: Global.Outcome) -> void:
	if result in [Global.Outcome.DEFEAT_COMBAT, Global.Outcome.DEFEAT_ESTATE]:
		_play_tone_sequence([247, 196, 147], 0.24)
