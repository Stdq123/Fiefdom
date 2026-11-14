extends Control

const WAIT_SECONDS := 2.8
const FINAL_APPROACH := SeasonOrders.TRAVEL_FRACTION * 0.09

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

func _ready() -> void:
	stand.pressed.connect(_finish.bind(false))
	GamepadInput.changed.connect(_refresh_controls)
	GameEvents.raid_started.connect(_finish.bind(false))
	set_process(false)

func wait_for(estate_player: Player, arrival: float, watch: String, seat: Vector2) -> void:
	player = estate_player
	wait_day = Global.current_day
	start_progress = Global.day_progress
	arrival_progress = arrival
	approach_progress = arrival - FINAL_APPROACH
	var seconds_to_approach := (approach_progress - start_progress) * Global.balance.daylight_seconds
	extra_rate = maxf(0.0, seconds_to_approach / WAIT_SECONDS - 1.0)
	handoff_position = seat - FreightBench.SEAT_OFFSET + FreightBench.HANDOFF_OFFSET
	progress.value = 0.0
	shade.color.a = 0.0
	status.text = "坐等货车 · %s到" % watch
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
	if Global.day_progress >= arrival_progress:
		_finish(true)
		return
	# Let the loaded cart cover its last few paces at its ordinary speed.
	var remaining := (approach_progress - Global.day_progress) * Global.balance.daylight_seconds
	Global.advance_daylight(minf(delta * extra_rate, maxf(0.0, remaining)))
	progress.value = inverse_lerp(start_progress, arrival_progress, Global.day_progress)
	var approaching := Global.day_progress >= approach_progress
	shade.color.a = move_toward(shade.color.a, 0.18 if extra_rate > 0.0 and not approaching else 0.0, delta * 0.9)
	if approaching:
		status.text = "申禾正赶车过来"

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
	if arrived:
		player.arrive_at_position(handoff_position, Vector2.UP)
		GameEvents.world_notice.emit("货车已到 · 按 %s 找申禾" % GamepadInput.interact_key())
