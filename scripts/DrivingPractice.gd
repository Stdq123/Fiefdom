extends Node2D

const ROUTE := [Vector2(100, 165), Vector2(191, 160), Vector2(49, 205)]
const LIMIT := 25.0
const REWARD := 30

@onready var world = get_parent()
var remaining := 0.0
var next_marker := 0
var last_second := -1

func _ready() -> void:
	GameEvents.driving_practice_requested.connect(start)
	GameEvents.day_advanced.connect(_on_day_advanced)
	set_process(false)

func start() -> void:
	if is_processing() or not Global.can_practice_today(PlayerStats.Art.DRIVING):
		return
	remaining = LIMIT
	next_marker = 0
	last_second = -1
	world.player.set_training_cart(true)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		_finish("驾御练习超时，可以重试。")
		return
	var target: Vector2 = ROUTE[next_marker]
	if world.player.position.distance_to(target) <= 15.0:
		next_marker += 1
		if next_marker == ROUTE.size():
			Global.award_practice(PlayerStats.Art.DRIVING, REWARD)
			_finish("驾御完成 · 御经验 +%d" % REWARD)
			return
		queue_redraw()
		last_second = -1
	var second := ceili(remaining)
	if last_second != second:
		last_second = second
		GameEvents.practice_feedback.emit("驾御 · 前往金色路标 %d/%d · 剩余 %d 秒 · Esc 停止" % [
			next_marker + 1, ROUTE.size(), second])

func _draw() -> void:
	if not is_processing():
		return
	var target: Vector2 = ROUTE[next_marker]
	draw_arc(target, 12.0, 0.0, TAU, 32, Color("#e9bf70"), 2.0)
	draw_line(target + Vector2(-3, 2), target + Vector2(0, -4), Color("#e9bf70"), 2.0)
	draw_line(target + Vector2(0, -4), target + Vector2(3, 2), Color("#e9bf70"), 2.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if is_processing() and event.is_action_pressed("ui_cancel"):
		_finish("已结束驾御练习。")
		get_viewport().set_input_as_handled()

func _on_day_advanced(_day: int) -> void:
	if is_processing():
		_finish("过夜结束了当天的驾御练习。")
	else:
		GameEvents.practice_feedback.emit("")

func _finish(message: String) -> void:
	world.player.set_training_cart(false)
	set_process(false)
	queue_redraw()
	GameEvents.practice_feedback.emit(message)
