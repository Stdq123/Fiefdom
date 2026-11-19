extends Control

const WAIT_SECONDS := 2.8
const FINAL_APPROACH := SeasonOrders.TRAVEL_FRACTION * 0.09
const ARRIVAL_NOTICE := "货车已到 · "

@onready var progress: ProgressBar = %Progress
@onready var stand: Button = %Stand
@onready var status: Label = $Card/Stack/Status
@onready var shade: ColorRect = $Shade

var player: Player
var wait_day := 0
var start_progress := 0.0
var arrival_progress := 0.0
var approach_progress := 0.0
var extra_rate := 0.0
var handoff_position := Vector2.ZERO
var pavilion: PavilionRest
var appointment_id := ""

func _ready() -> void:
	stand.pressed.connect(_finish.bind(false))
	GamepadInput.changed.connect(_refresh_controls)
	GameEvents.raid_started.connect(_finish.bind(false))
	set_process(false)

func wait_for(estate_player: Player, arrival: float, watch: String, seat: Vector2) -> void:
	handoff_position = seat - FreightBench.SEAT_OFFSET + FreightBench.HANDOFF_OFFSET
	_begin_wait(estate_player, arrival, arrival - FINAL_APPROACH, "坐等货车 · %s到" % watch, seat)

func wait_for_pavilion(estate_player: Player, table: PavilionRest, id: String) -> void:
	pavilion = table
	appointment_id = id
	var arrival := PavilionRest.rest_start()
	_begin_wait(estate_player, arrival, arrival, "坐下候席 · %s起" % PavilionRest.rest_watch(), table.global_position)

func _begin_wait(estate_player: Player, arrival: float, approach: float, caption: String, seat: Vector2) -> void:
	player = estate_player
	wait_day = Global.current_day
	start_progress = Global.day_progress
	arrival_progress = arrival
	approach_progress = approach
	var seconds_to_approach := (approach_progress - start_progress) * Global.balance.daylight_seconds
	extra_rate = maxf(0.0, seconds_to_approach / WAIT_SECONDS - 1.0)
	progress.value = 0.0
	shade.color.a = 0.0
	status.text = caption
	player.arrive_at_position(seat, Vector2.DOWN)
	player.resting = true
	player.seated = true
	show()
	_refresh_controls()
	stand.grab_focus()
	GamepadInput.snap_pointer_to_focus()
	set_process(true)

func _process(delta: float) -> void:
	if wait_day != Global.current_day or Global.raid_day > 0 or Global.outcome != Global.Outcome.RUNNING:
		_finish(false)
		return
	if pavilion:
		if not pavilion.story_id.is_empty():
			_finish(true)
			return
		if pavilion.appointment_id != appointment_id or Global.day_progress >= 1.0:
			_finish(false)
			GameEvents.world_notice.emit("今日小谈暂缓 · 可查看今夜安排")
			return
	elif Global.day_progress >= arrival_progress:
		_finish(true)
		return
	# Leave the final approach to the actors' normal movement.
	var remaining := (approach_progress - Global.day_progress) * Global.balance.daylight_seconds
	Global.advance_daylight(minf(delta * extra_rate, maxf(0.0, remaining)))
	var clock_progress := inverse_lerp(start_progress, arrival_progress, Global.day_progress) if arrival_progress > start_progress else 1.0
	progress.value = minf(clock_progress, 1.0) * 0.8 if pavilion else clock_progress
	var approaching := Global.day_progress >= approach_progress
	shade.color.a = move_toward(shade.color.a, 0.18 if extra_rate > 0.0 and not approaching else 0.0, delta * 0.9)
	if approaching:
		status.text = "等两位入席 · %s" % Global.day_watch_label() if pavilion else "申禾正赶车过来"

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(false)

func _refresh_controls() -> void:
	stand.text = "起身 · B" if GamepadInput.active else "起身 · Esc"

func _finish(arrived: bool) -> void:
	if not visible:
		return
	set_process(false)
	player.resting = false
	player.seated = false
	hide()
	if pavilion:
		pavilion = null
		appointment_id = ""
		if arrived:
			GameEvents.world_notice.emit("两位已入席 · 按 %s 听小谈" % GamepadInput.interact_key())
	elif arrived:
		player.arrive_at_position(handoff_position, Vector2.UP)
		GameEvents.world_notice.emit(ARRIVAL_NOTICE + "按 %s 找申禾" % GamepadInput.interact_key())
