extends Node2D

enum Phase { LANDING, COUNTDOWN, RUNNING, RESULT }

const LANDSCAPE := preload("res://scripts/Landscape.gd")
const GATE_TOLERANCE := 4.25
const BANK_CLEARANCE := 8.0
const CURRENT := 12.0
const COUNTDOWN := 3.0
const WAITING := -1
const MISSED := 0
const PASSED := 1
const INK := Color("#d8dfc1")
const GOLD := Color("#f5ce83")
const JADE := Color("#a2d9b8")
const CLAY := Color("#e2a487")

var landing: RaftLanding
var player: Player
var trail_hud: Control
var pool_hint: Label
var phase := Phase.LANDING
var date := 0
var countdown := 0.0
var elapsed := 0.0
var course_y := SummerRaft.START_Y
var lateral := 0.0
var lateral_speed := 0.0
var next_gate := 0
var passed := 0
var gate_results: Array[int] = []
var next_paddle := 0.0
var rider: Texture2D
var meal_layer: CanvasLayer

@onready var camera: Camera2D = $Camera
@onready var status: Label = %Status
@onready var steps: HBoxContainer = %Steps
@onready var detail: Label = %Detail
@onready var keys: Label = %Keys
@onready var start_button: Button = %Start
@onready var close_button: Button = %Leave
@onready var paddle: AudioStreamPlayer = $Paddle

func _ready() -> void:
	date = Global.current_day
	rider = PlayerAttire.preview(Global.attire_id, Player.Facing.FRONT)
	meal_layer = player.get_node("MealUI")
	meal_layer.hide()
	trail_hud.hide()
	landing.hint.hide()
	pool_hint.hide()
	get_tree().paused = true
	camera.make_current()
	camera.force_update_scroll()
	AudioManager.duck_music_for(self, 0.62)
	start_button.pressed.connect(_start)
	close_button.pressed.connect(queue_free)
	GamepadInput.changed.connect(_refresh_keys)
	Preferences.bindings_changed.connect(_refresh_keys)
	for _gate in SummerRaft.GATES:
		var marker := Label.new()
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		steps.add_child(marker)
	gate_results.resize(SummerRaft.GATES.size())
	gate_results.fill(WAITING)
	steps.hide()
	start_button.visible = landing.open_today
	if landing.open_today:
		status.text = "陆汀 · 西岸埠头"
		detail.text = "顺流过四道竹标。第一次过三道，就能领御经验。" + _best_today()
		start_button.grab_focus()
	else:
		status.text = "夏至首日开筏"
		detail.text = _ledger()
		close_button.grab_focus()
	_refresh_keys()
	set_physics_process(false)

func _start() -> void:
	phase = Phase.COUNTDOWN
	countdown = COUNTDOWN
	elapsed = 0.0
	course_y = SummerRaft.START_Y
	lateral = -4.0
	lateral_speed = 0.0
	next_gate = 0
	passed = 0
	next_paddle = 0.0
	gate_results.fill(WAITING)
	landing.set_boat_away(true)
	player.hide()
	GamepadInput.suspend_pointer(true)
	start_button.hide()
	steps.show()
	_update_steps()
	status.modulate = Color.WHITE
	status.text = "准备下水 · %d" % ceili(countdown)
	detail.text = "看金色竹标，从两根竹竿之间穿过。"
	_refresh_keys()
	_play_paddle()
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if phase == Phase.COUNTDOWN:
		countdown -= delta
		if countdown > 0.0:
			status.text = "准备下水 · %d" % ceili(countdown)
			return
		phase = Phase.RUNNING
		AudioManager.play_ui_sfx(1.05)
	var direction := Player.input_direction()
	var speed := CURRENT + (10.0 if direction.y > 0.0 else 6.0) * direction.y
	var step := minf(delta, (SummerRaft.FINISH_Y - course_y) / speed)
	var from_y := course_y
	var from_lateral := lateral
	var steering := direction.x * 19.0
	lateral_speed = move_toward(lateral_speed, steering, 66.0 * step)
	lateral = clampf(lateral + lateral_speed * step, -BANK_CLEARANCE, BANK_CLEARANCE)
	course_y += speed * step
	elapsed += step
	if next_gate < SummerRaft.GATES.size():
		var gate: Vector2 = SummerRaft.GATES[next_gate]
		if course_y >= gate.y:
			var crossing := lerpf(from_lateral, lateral, inverse_lerp(from_y, course_y, gate.y))
			_check_gate(absf(crossing - gate.x) <= GATE_TOLERANCE)
	if elapsed >= next_paddle and not direction.is_zero_approx():
		next_paddle = elapsed + 0.68
		_play_paddle()
	status.text = SummerRaft.score_text(passed, roundi(elapsed * 1000.0))
	if course_y >= SummerRaft.FINISH_Y - 0.001:
		_finish()
	queue_redraw()

func _check_gate(cleared: bool) -> void:
	gate_results[next_gate] = PASSED if cleared else MISSED
	next_gate += 1
	if cleared:
		passed += 1
	AudioManager.play_ui_sfx(1.34 if cleared else 0.73)
	var feedback := "穿过竹标" if cleared else "擦过外侧"
	detail.text = feedback + (" · 顺流到木桥前" if next_gate == SummerRaft.GATES.size() else " · 看下一道金色竹标")
	_update_steps()

func _finish() -> void:
	phase = Phase.RESULT
	set_physics_process(false)
	GamepadInput.suspend_pointer(false)
	var result := Global.record_summer_raft(date, passed, roundi(elapsed * 1000.0))
	var experience: int = result.get("experience", 0)
	status.modulate = JADE if passed >= SummerRaft.MIN_GATES else INK
	if experience > 0:
		detail.text = "陆汀把成绩写进筏簿。御经验 +%d。" % experience
	elif result.get("improved", false):
		detail.text = "陆汀把新的最好成绩写进筏簿。"
	else:
		detail.text = "筏簿保留了原来的最好成绩。"
	detail.text += _best_today()
	start_button.text = "再试一趟"
	start_button.show()
	start_button.grab_focus()
	_refresh_keys()

func _best_today() -> String:
	var best: Dictionary = Global.summer_raft_results.get(date, {})
	return "\n最好成绩 · " + SummerRaft.score_text(best.gates, best.time_ms) if not best.is_empty() else ""

func _ledger() -> String:
	var days := Global.summer_raft_results.keys()
	days.sort()
	days.reverse()
	var rows := PackedStringArray(["近年筏簿" if not days.is_empty() else "筏簿还没有成绩。"])
	for day in days.slice(0, 3):
		var best: Dictionary = Global.summer_raft_results[day]
		rows.append("第 %d 天 · %s" % [day, SummerRaft.score_text(best.gates, best.time_ms)])
	return "\n".join(rows)

func _update_steps() -> void:
	for index in SummerRaft.GATES.size():
		var marker := steps.get_child(index) as Label
		var label := "待"
		var ink := INK
		if index == next_gate:
			label = "当前"
			ink = GOLD
		elif gate_results[index] != WAITING:
			label = "过" if gate_results[index] == PASSED else "错过"
			ink = JADE if gate_results[index] == PASSED else CLAY
		marker.text = "%d %s" % [index + 1, label]
		marker.modulate = ink

func _refresh_keys() -> void:
	close_button.text = "回岸  " + ("B" if GamepadInput.active else "Esc")
	keys.visible = landing.open_today and phase != Phase.RESULT
	if GamepadInput.active:
		keys.text = "摇杆或十字键 · 左右转向\n上减速，下划快"
	else:
		keys.text = "%s / %s 转向 · %s 减速 · %s 划快\n也可用方向键" % [
			Preferences.key_label(KeyBindings.LEFT), Preferences.key_label(KeyBindings.RIGHT),
			Preferences.key_label(KeyBindings.UP), Preferences.key_label(KeyBindings.DOWN)]

func _play_paddle() -> void:
	if DisplayServer.get_name() != "headless":
		paddle.pitch_scale = 0.93 + 0.12 * sin(elapsed * 4.0)
		paddle.play()

func _draw() -> void:
	if not landing.open_today:
		return
	for index in SummerRaft.GATES.size():
		var gate: Vector2 = SummerRaft.GATES[index]
		_draw_gate(Vector2(LANDSCAPE.creek_x(gate.y) + gate.x, gate.y).round(), index)
	var finish := Vector2(LANDSCAPE.creek_x(SummerRaft.FINISH_Y), SummerRaft.FINISH_Y).round()
	draw_line(finish - Vector2(14, 0), finish + Vector2(14, 0), Color("#ebd8a697"), 1.0)
	for offset in [-13, -5, 3, 11]:
		draw_rect(Rect2(finish + Vector2(offset, -1), Vector2(3, 2)), Color("#eadab0"))
	if phase == Phase.LANDING:
		return
	var boat := Vector2(LANDSCAPE.creek_x(course_y) + lateral, course_y).round()
	landing.draw_boat(self, boat, int(elapsed * 8.0), phase == Phase.RUNNING)
	draw_texture(rider, boat - Vector2(16, 26))
	var swing := sin(elapsed * 10.0) * 3.0
	var handle := boat + Vector2(5, -6)
	var blade := boat + Vector2(10.0 + 0.15 * lateral_speed, 6.0 + swing)
	draw_line(handle, blade, Color("#dec491"), 1.2)
	draw_rect(Rect2(blade.round() - Vector2(1, 0), Vector2(3, 4)), Color("#9c784d"))
	if phase == Phase.RUNNING:
		var trail := fposmod(elapsed * 9.0, 8.0)
		for side: float in [-1.0, 1.0]:
			draw_line(boat + Vector2(5 * side, -11 - trail), boat + Vector2(8 * side, -16 - trail),
				Color("#a7d2bd9a"), 1.0)

func _draw_gate(center: Vector2, index: int) -> void:
	var ink := Color("#d7c691")
	if index == next_gate:
		ink = GOLD
	elif gate_results[index] != WAITING:
		ink = JADE if gate_results[index] == PASSED else CLAY
	for side: float in [-1.0, 1.0]:
		var foot := center + Vector2(9 * side, 0)
		draw_rect(Rect2(foot - Vector2(2, 1), Vector2(4, 2)), Color("#aacbb287"))
		draw_rect(Rect2(foot - Vector2(1, 13), Vector2(2, 14)), Color("#523e2a"))
		draw_rect(Rect2(foot - Vector2(0, 13), Vector2(1, 12)), Color("#ac9059"))
		draw_rect(Rect2(foot + Vector2(0, -13) - Vector2(4 if side > 0 else 0, 0), Vector2(5, 4)), ink)
	for offset in [-6, 0, 6]:
		draw_rect(Rect2(center + Vector2(offset - 1, 0), Vector2(3, 1)), Color(ink, 0.83))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()

func _exit_tree() -> void:
	GamepadInput.suspend_pointer(false)
	if landing.is_inside_tree():
		landing.set_boat_away(false)
		landing.hint.show()
	if player.is_inside_tree():
		pool_hint.show()
		player.show()
		meal_layer.show()
		trail_hud.show()
		player.camera.make_current()
		player.camera.force_update_scroll()
	if Global.outcome == Global.Outcome.RUNNING:
		get_tree().paused = false
