extends Node2D
class_name DrivingPractice

const PLACE := "驾御场"
const START_POINT := EstateLayout.DRIVING_START
const ROUTE := EstateLayout.DRIVING_GATES
const PARKING := EstateLayout.DRIVING_PARKING
const LIMIT := 25.0
const REWARD := 30
const FLAG_GOLD := Color("#f3cc78")
const FLAG_LINEN := Color("#a98d64")

@onready var player: Player = $"../Player"
@onready var parked_cart: TrainingCart = $ParkedCart
@onready var marks: Node2D = $LaneMarks
@onready var hint: Label = $Hint

var elapsed := 0.0
var next_marker := 0
var last_second := -1

func _ready() -> void:
	marks.position = -position
	marks.draw.connect(_draw_course)
	_park_at_start()
	GameEvents.day_advanced.connect(_on_day_advanced)
	GameEvents.campaign_ended.connect(_on_campaign_ended)
	set_process(false)

func can_interact_from(at: Vector2) -> bool:
	return at.distance_squared_to(get_parent().to_global(START_POINT)) <= 25.0 * 25.0

func set_interaction_focused(focused: bool) -> void:
	hint.text = GamepadInput.interact_hint("上车练习") if focused else PLACE
	hint.modulate = FLAG_GOLD if focused else Color("#e2d2a9")

func interact() -> void:
	if not Global.can_practice_today(PlayerStats.Art.DRIVING):
		GameEvents.practice_feedback.emit("今日已练御 · 明日可再来")
		return
	get_parent().set_channel_mode(false)
	elapsed = 0.0
	next_marker = 0
	last_second = -1
	parked_cart.hide()
	player.arrive_at_position(get_parent().to_global(START_POINT), Vector2.DOWN)
	player.set_training_cart(true)
	set_process(true)
	GameEvents.driving_practice_changed.emit(true)
	_show_progress()
	marks.queue_redraw()

func _process(delta: float) -> void:
	if player.world_controls_blocked() or (elapsed == 0.0 and player.velocity.length_squared() < 1.0):
		return
	elapsed += delta
	if elapsed >= LIMIT:
		_finish("练习超时 · 可回驾御场重试")
		return
	if next_marker < ROUTE.size():
		if player.position.distance_squared_to(ROUTE[next_marker]) <= 16.0 * 16.0:
			next_marker += 1
			last_second = -1
			AudioManager.play_ui_sfx(1.12 if next_marker == ROUTE.size() else 0.98)
			marks.queue_redraw()
	elif PARKING.has_point(player.position) and player.velocity.length_squared() < 10.0 * 10.0:
		_complete()
		return
	var seconds_left := ceili(LIMIT - elapsed)
	if last_second != seconds_left:
		last_second = seconds_left
		_show_progress()

func _show_progress() -> void:
	var step := "沿路穿过金旗"
	var clock := "余 %d 秒" % last_second
	if elapsed == 0.0:
		step = "按方向起步"
		clock = "计时待发"
	elif next_marker == ROUTE.size():
		step = "松开方向，在停车线内停稳"
	GameEvents.driving_practice_progress.emit("驾御 · 旗门 %d/%d · %s" % [next_marker, ROUTE.size(), clock], step)

func _complete() -> void:
	var time_ms := roundi(elapsed * 1000.0)
	var improved := Global.best_driving_ms == 0 or time_ms < Global.best_driving_ms
	if improved:
		Global.best_driving_ms = time_ms
	Global.award_practice(PlayerStats.Art.DRIVING, REWARD)
	var record := " · 新纪录" if improved else ""
	_finish("驾御完成 · %.1f 秒%s · 御经验 +%d" % [time_ms / 1000.0, record, REWARD], true)

func _unhandled_key_input(event: InputEvent) -> void:
	if is_processing() and not player.world_controls_blocked() and event.is_action_pressed("ui_cancel"):
		dismount()
		get_viewport().set_input_as_handled()

func dismount() -> void:
	if is_processing():
		_finish("已下车 · 可回驾御场重试")

func _on_day_advanced(_day: int) -> void:
	if is_processing():
		_finish("过夜结束了驾御练习")
	else:
		_park_at_start()
		GameEvents.practice_feedback.emit("")

func _on_campaign_ended(_outcome: Global.Outcome) -> void:
	if is_processing():
		_finish("")

func _finish(message: String, leave_cart := false) -> void:
	set_process(false)
	if leave_cart:
		parked_cart.global_position = player.global_position
		parked_cart.face(player.facing_direction())
		parked_cart.show()
		player.arrive_at_position(player.global_position + Vector2(5, 19), Vector2.DOWN)
	else:
		_park_at_start()
	player.set_training_cart(false)
	marks.queue_redraw()
	GameEvents.driving_practice_changed.emit(false)
	GameEvents.practice_feedback.emit(message)

func _park_at_start() -> void:
	parked_cart.position = START_POINT - position
	parked_cart.face(Vector2.DOWN)
	parked_cart.show()

func _draw() -> void:
	draw_rect(Rect2(-8, -1, 17, 3), Color("#29372e"))
	draw_rect(Rect2(-2, -14, 4, 15), Color("#584432"))
	draw_rect(Rect2(-10, -20, 20, 12), Color("#473729"))
	draw_rect(Rect2(-8, -18, 16, 8), Color("#ad8957"))
	draw_line(Vector2(-5, -14), Vector2(5, -14), Color("#eed49b"), 2.0)
	draw_line(Vector2(-6, -14), Vector2(-2, -17), Color("#eed49b"), 1.0)
	draw_line(Vector2(-6, -14), Vector2(-2, -11), Color("#eed49b"), 1.0)

func _draw_course() -> void:
	if not is_processing():
		return
	var previous := START_POINT
	for index in ROUTE.size():
		var gate: Vector2 = ROUTE[index]
		var lane := (gate - previous).normalized()
		var across := lane.orthogonal()
		var ribbon := FLAG_GOLD if next_marker == index else FLAG_LINEN
		if index < next_marker:
			ribbon = Color("#8e9b71")
		for side: float in [-1.0, 1.0]:
			_draw_flag(gate + across * side * 15.0, lane, ribbon)
		if index == next_marker:
			marks.draw_line(gate - across * 9.0, gate + across * 9.0, Color(FLAG_GOLD, 0.66), 2.0)
		previous = gate
	var parking_color := FLAG_GOLD if next_marker == ROUTE.size() else FLAG_LINEN
	marks.draw_rect(PARKING, Color(parking_color, 0.20))
	marks.draw_rect(PARKING.grow(-1.0), parking_color, false, 1.0)
	for y in [PARKING.position.y + 4.0, PARKING.end.y - 4.0]:
		marks.draw_line(Vector2(PARKING.position.x + 4.0, y), Vector2(PARKING.end.x - 4.0, y),
			Color(parking_color, 0.6), 1.0)

func _draw_flag(foot: Vector2, forward: Vector2, color: Color) -> void:
	var post := foot.round()
	var top := post - Vector2(0, 15)
	var tip := top + Vector2(8.0 if forward.x > 0.0 else -8.0, 4.0)
	marks.draw_rect(Rect2(post - Vector2(3, 0), Vector2(7, 2)), Color("#3b3f30"))
	marks.draw_line(post, top, Color("#574434"), 3.0)
	marks.draw_line(post - Vector2(1, 1), top - Vector2(1, 0), Color("#b09263"), 1.0)
	marks.draw_colored_polygon(PackedVector2Array([top, tip, top + Vector2(0, 8)]), color)
