extends Node

enum TradeCue { SALE, PURCHASE, STORE_FOOD }
enum MenuCue { PAGE, CLOSE, OPEN }

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
const FIRST_TRIBUTE_CUE := preload("res://assets/audio/ledger/first-tribute.wav")
const TRADITION_CUE := preload("res://assets/audio/ledger/council-tribute.wav")
const REFORM_CUE := preload("res://assets/audio/ledger/council-tax.wav")
const RESEARCH_CUE := preload("res://assets/audio/ledger/council-research.wav")
const LEDGER_MUSIC_GAIN := 0.70
const SILK_SAMPLE_CUE := preload("res://assets/audio/silk/sample-delivered.wav")
const WORKSHOP_CUES := {
	SilkWorkshop.Action.START_BATCH: preload("res://assets/audio/silk/leaves.wav"),
	SilkWorkshop.Action.REEL: preload("res://assets/audio/silk/reel.wav"),
	SilkWorkshop.Action.WEAVE: preload("res://assets/audio/silk/loom.wav"),
}
const TRADE_CUES := [
	preload("res://assets/audio/market/coins-received.wav"),
	preload("res://assets/audio/market/purchase.wav"),
	preload("res://assets/audio/market/grain-stored.wav"),
]
const MENU_CUES := [
	preload("res://assets/audio/ui/page-turn.wav"),
	preload("res://assets/audio/ui/book-close.wav"),
	preload("res://assets/audio/ui/book-open.wav"),
]
const MENU_PAGE_INTERVAL := 0.065
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
const WIND_GAIN_BY_SEASON: Array[float] = [0.115, 0.100, 0.138, 0.175]
const TERRAIN_AUDIO := preload("res://scripts/TerrainAudio.gd")

var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var ui_sfx_player: AudioStreamPlayer
var terrain_audio: TERRAIN_AUDIO
var field_sounds: Array[AudioStreamWAV] = []
var _workshop_sound: AudioStreamPlayer
var _menu_sound: AudioStreamPlayer
var _pending_menu_cue := -1
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
	GameEvents.silk_sample_delivered.connect(_on_silk_sample_delivered)
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
	Preferences.apply_sfx_volume()
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

	_menu_sound = AudioStreamPlayer.new()
	_menu_sound.name = "MenuSound"
	_menu_sound.bus = &"SFX"
	_menu_sound.volume_db = -14.0
	add_child(_menu_sound)

	_workshop_sound = AudioStreamPlayer.new()
	_workshop_sound.name = "WorkshopCue"
	_workshop_sound.bus = &"SFX"
	_workshop_sound.volume_db = -11.0
	add_child(_workshop_sound)
	if DisplayServer.get_name() != "headless":
		for path in FIELD_SOUND_PATHS:
			field_sounds.append(load(path))
	_sync_score.call_deferred()

func set_world_ambience(creek_distance: float, birds_distance: float, cricket_distance: float,
		under_roof := false, wind_exposure := 1.0) -> void:
	var season := Global.season_index()
	var indoors := Global.is_indoors()
	var raining := Global.has_rain()
	var dusk := Global.dusk_amount()
	var birds := birds_distance if not indoors and season != Global.Season.WINTER else INF
	var crickets := cricket_distance if not indoors and season in [Global.Season.SUMMER, Global.Season.AUTUMN] else INF
	var wind_gain := WIND_GAIN_BY_SEASON[season] * wind_exposure * lerpf(1.0, 0.80, dusk)
	if raining:
		wind_gain *= 0.70
	terrain_audio.set_ambience(creek_distance, raining, birds, crickets, dusk, under_roof or indoors, wind_gain)

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

func play_trade_cue(cue: TradeCue) -> void:
	play_sfx(TRADE_CUES[cue], -9.0)

func play_workshop_cue(action: SilkWorkshop.Action, station: Node2D = null) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var cue := WORKSHOP_CUES.get(action) as AudioStream
	if cue == null:
		return
	if station != null:
		play_world_sfx(cue, station, -9.0, 260.0)
	elif not _workshop_sound.playing or _workshop_sound.stream != cue:
		_workshop_sound.stream = cue
		_workshop_sound.play()

func play_sfx(stream: AudioStream, volume := 0.0, pitch := 1.0, music_gain := 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = pitch
	player.finished.connect(player.queue_free)
	add_child(player)
	if music_gain < 1.0 and not is_zero_approx(Preferences.sfx_volume):
		duck_music_for(player, music_gain)
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

func play_menu_cue(cue: MenuCue) -> void:
	if _pending_menu_cue < 0:
		_play_pending_menu_cue.call_deferred()
	# A new panel takes precedence when an action also closes or turns a page below it.
	_pending_menu_cue = maxi(_pending_menu_cue, cue)

func _play_pending_menu_cue() -> void:
	var cue := _pending_menu_cue
	_pending_menu_cue = -1
	if cue == MenuCue.PAGE and _menu_sound.playing and _menu_sound.get_playback_position() < MENU_PAGE_INTERVAL:
		return
	_menu_sound.stream = MENU_CUES[cue]
	if DisplayServer.get_name() != "headless":
		_menu_sound.play()

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
			play_sfx(FIRST_TRIBUTE_CUE, -7.0, 1.0, LEDGER_MUSIC_GAIN)
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
	var record := Global.rank_record
	if record.get("day") == Global.current_day and record.get("rank") == new_rank and record.previous > new_rank:
		play_sfx(BAMBOO_SLIPS, -11.0, 0.82)
	else:
		play_event_sound("rank_up")

func _on_tax_reform_triggered() -> void:
	play_sfx(CEREMONY_BELL, -12.0, 0.78)

func _on_tax_reform_choice(choice: Global.TaxReformChoice) -> void:
	match choice:
		Global.TaxReformChoice.TRADITIONAL:
			play_sfx(TRADITION_CUE, -7.0, 1.0, LEDGER_MUSIC_GAIN)
		Global.TaxReformChoice.REFORMED:
			play_sfx(REFORM_CUE, -7.0, 1.0, LEDGER_MUSIC_GAIN)
		Global.TaxReformChoice.DELAYED:
			play_sfx(RESEARCH_CUE, -7.0)

func _on_well_field_added(field_id: int) -> void:
	print("Audio: Playing well field added sound!")
	play_event_sound("well_field_added")

func _on_well_field_reclaimed(_field_id: int, progress: int) -> void:
	if progress == Global.RECLAMATION_NIGHTS:
		play_sfx(CEREMONY_BELL, -14.0, 1.0)

func _on_silk_sample_delivered() -> void:
	play_sfx(SILK_SAMPLE_CUE, -10.0)

func _on_campaign_ended(result: Global.Outcome) -> void:
	if result in [Global.Outcome.DEFEAT_COMBAT, Global.Outcome.DEFEAT_ESTATE]:
		_play_tone_sequence([247, 196, 147], 0.24)
