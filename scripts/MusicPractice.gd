extends Panel

const BEAT_SECONDS := 0.85
const BEATS := Global.GATHERING_BEATS
const HIT_WINDOW := 0.2
const REWARD := 30
const BELL_PATH := "res://assets/audio/music/bronze-bell.wav"
const NOTES := [1.0, 1.12, 1.25, 1.5]

var recital_day := 0
var elapsed := 0.0
var hits := 0
var scored_beats: Array[int] = []
var previous_beat := -1
var finished := false
var owns_pause := false
var progress: ProgressBar
var feedback: Label
var strike_button: Button
var close_button: Button
var beat_labels: Array[Label] = []
var bell: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("timed_practice")
	AudioManager.duck_music_for(self, 0.22)
	owns_pause = not get_tree().paused
	if owns_pause:
		get_tree().paused = true
	if recital_day > 0:
		elapsed = -0.8
	if DisplayServer.get_name() != "headless":
		bell = AudioStreamPlayer.new()
		bell.name = "BellStrike"
		bell.bus = "SFX"
		bell.volume_db = -5.0
		bell.stream = load(BELL_PATH)
		add_child(bell)
	size = Vector2(440, 232)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	var layout := VBoxContainer.new()
	add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	layout.add_theme_constant_override("separation", 7)
	var title := Label.new()
	title.text = "谷雨亭集 · 迎客曲" if recital_day > 0 else "乐 · 编钟练习"
	title.add_theme_font_size_override("font_size", 22)
	layout.add_child(title)
	var instructions := Label.new()
	instructions.text = "光条进入绿段时敲钟。四拍中命中三拍即可。"
	layout.add_child(instructions)
	var beats := HBoxContainer.new()
	layout.add_child(beats)
	for beat in BEATS:
		var marker := Label.new()
		marker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		beats.add_child(marker)
		beat_labels.append(marker)
	_show_beats(-1)
	progress = ProgressBar.new()
	progress.max_value = 1.0
	progress.show_percentage = false
	progress.custom_minimum_size.y = 24
	layout.add_child(progress)
	var band := ColorRect.new()
	band.color = Color(0.38, 0.68, 0.49, 0.58)
	band.anchor_left = 1.0 - HIT_WINDOW / BEAT_SECONDS
	band.anchor_right = 1.0
	band.anchor_bottom = 1.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_child(band)
	feedback = Label.new()
	feedback.text = "准备 · 0/4"
	layout.add_child(feedback)
	var actions := HBoxContainer.new()
	layout.add_child(actions)
	strike_button = Button.new()
	strike_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	strike_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strike_button.custom_minimum_size.y = 36
	strike_button.pressed.connect(_strike)
	actions.add_child(strike_button)
	close_button = Button.new()
	close_button.text = "回亭边" if recital_day > 0 else "结束练习"
	close_button.custom_minimum_size = Vector2(112, 36)
	close_button.pressed.connect(queue_free)
	actions.add_child(close_button)
	GamepadInput.changed.connect(_refresh_shortcut)
	Preferences.bindings_changed.connect(_refresh_shortcut)
	_refresh_shortcut()

func _refresh_shortcut() -> void:
	strike_button.text = "敲钟 · %s" % GamepadInput.rhythm_key()

func _process(delta: float) -> void:
	# Keep the hit band visible through a long render frame.
	elapsed += minf(delta, HIT_WINDOW / 4.0)
	if elapsed < 0.0:
		return
	if elapsed >= BEATS * BEAT_SECONDS:
		finished = true
		set_process(false)
		progress.value = 1.0
		strike_button.disabled = true
		_show_beats(BEATS)
		_finish()
		return
	var beat := floori(elapsed / BEAT_SECONDS)
	if beat != previous_beat:
		AudioManager.play_ui_sfx(1.0 + 0.1 * beat)
		previous_beat = beat
		_show_beats(beat)
	progress.value = fposmod(elapsed, BEAT_SECONDS) / BEAT_SECONDS

func _finish() -> void:
	if recital_day > 0:
		var recorded := Global.record_gathering_recital(recital_day, hits)
		feedback.text = ("命中 %d/4 · 已记入曲簿 · 乐经验 +%d" % [hits, Global.GATHERING_MUSIC_XP] if recorded
			else "命中 %d/4 · 可回亭边找商音再奏" % hits)
	else:
		var reward := hits >= Global.GATHERING_MIN_HITS and Global.award_practice(PlayerStats.Art.MUSIC, REWARD)
		feedback.text = ("命中 %d/4 · 乐经验 +%d" % [hits, REWARD] if reward else "命中 %d/4 · 可以再练一次" % hits)

func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
	elif Preferences.matches(event, KeyBindings.RHYTHM):
		get_viewport().set_input_as_handled()
		_strike()

func _strike() -> void:
	if finished or elapsed < 0.0:
		return
	var beat := floori(elapsed / BEAT_SECONDS)
	if beat in scored_beats:
		feedback.text = "本拍已击中 · %d/4" % hits
	elif fposmod(elapsed, BEAT_SECONDS) >= BEAT_SECONDS - HIT_WINDOW:
		scored_beats.append(beat)
		hits += 1
		feedback.text = "击中编钟 · %d/4" % hits
		_show_beats(beat)
		if bell:
			bell.pitch_scale = NOTES[beat]
			bell.play()
	else:
		feedback.text = "等光条进入绿段 · %d/4" % hits

func _show_beats(active: int) -> void:
	for beat in BEATS:
		var marker := beat_labels[beat]
		marker.text = "第 %d 拍" % (beat + 1)
		marker.modulate = Color("#c7c1ac")
		if beat in scored_beats:
			marker.text += " ✓"
			marker.modulate = Color("#bde3a1")
		elif beat == active:
			marker.modulate = Color("#f6cf86")
		elif beat < active:
			marker.text += " ×"
			marker.modulate = Color("#d79883")

func _exit_tree() -> void:
	if owns_pause:
		get_tree().paused = false
