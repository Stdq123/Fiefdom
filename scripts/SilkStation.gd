extends StaticBody2D

const SOUNDS := {
	SilkWorkshop.Action.START_BATCH: preload("res://assets/audio/silk/leaves.wav"),
	SilkWorkshop.Action.REEL: preload("res://assets/audio/silk/reel.wav"),
	SilkWorkshop.Action.WEAVE: preload("res://assets/audio/silk/loom.wav"),
}
const REEL_HUB := Vector2(3, -25)

@export var action := SilkWorkshop.Action.START_BATCH
@onready var hint: Label = $Hint
@onready var details: Node2D = $Details

var phase := 1.0
var movement: Tween

func _ready() -> void:
	details.draw.connect(_draw_details)
	GameEvents.silk_changed.connect(details.queue_redraw)

func can_interact_from(point: Vector2) -> bool:
	return is_visible_in_tree() and global_position.distance_squared_to(point) <= 25.0 * 25.0

func set_interaction_focused(active: bool) -> void:
	hint.visible = active
	if active:
		var key := GamepadInput.interact_key()
		match action:
			SilkWorkshop.Action.START_BATCH: hint.text = key + "  养蚕"
			SilkWorkshop.Action.REEL: hint.text = key + "  缫丝"
			SilkWorkshop.Action.WEAVE: hint.text = key + "  织绸"

func interact() -> void:
	if Global.estate_room != Global.EstateRoom.SILK_SHED:
		return
	if not Global.use_workshop(action):
		GameEvents.silk_station_feedback.emit(_materials_needed())
		return
	if movement == null or not movement.is_running():
		_set_phase(0.0)
		movement = create_tween()
		movement.tween_method(_set_phase, 0.0, 1.0, 0.54)
		AudioManager.play_world_sfx(SOUNDS[action], self, -9.0, 260.0)
	var message := ""
	match action:
		SilkWorkshop.Action.START_BATCH:
			message = "蚕匾已开养 · %d 夜结茧" % Global.silk_workshop.nights_left
		SilkWorkshop.Action.REEL:
			message = "缫完一只蚕茧 · 生丝 +%d" % Global.silk_thread_yield()
		SilkWorkshop.Action.WEAVE:
			message = "织成一匹丝绸"
	GameEvents.silk_station_feedback.emit(message)

func _materials_needed() -> String:
	match action:
		SilkWorkshop.Action.START_BATCH:
			if Global.silk_workshop.nights_left > 0:
				return "这批蚕还需养 %d 夜" % Global.silk_workshop.nights_left
			return "养蚕还缺 %d 片桑叶" % (Global.balance.silk_leaves_per_night - Global.silk_workshop.leaves)
		SilkWorkshop.Action.REEL:
			return "等蚕结茧后再缫丝"
		SilkWorkshop.Action.WEAVE:
			return "织绸还缺 %d 份生丝" % (Global.balance.silk_thread_per_bolt - Global.silk_workshop.raw_silk)
	return ""

func _set_phase(value: float) -> void:
	phase = value
	details.queue_redraw()

func _draw_details() -> void:
	var silk := Global.silk_workshop
	match action:
		SilkWorkshop.Action.START_BATCH:
			if silk.nights_left > 0:
				_draw_leaves()
		SilkWorkshop.Action.REEL:
			_draw_reel(silk)
		SilkWorkshop.Action.WEAVE:
			_draw_loom(silk.bolts)

func _draw_leaves() -> void:
	for shelf in 2:
		for bundle in 5:
			var leaf := Vector2(-15 + bundle * 6, -25 + shelf * 15 + (bundle * 3 + shelf) % 3)
			details.draw_rect(Rect2(leaf, Vector2(6, 3)), Color("#708052"))
			details.draw_rect(Rect2(leaf + Vector2(1, 0), Vector2(3, 1)), Color("#a6b36a"))
		var crawl := Vector2(-10 + roundf(phase * 5.0), -23 + shelf * 15)
		details.draw_rect(Rect2(crawl, Vector2(3, 1)), Color("#dbcd9e"))

func _draw_reel(silk: SilkWorkshop) -> void:
	for cocoon in mini(4, silk.cocoons):
		var at := Vector2(-23 + cocoon * 3, -12 + cocoon % 2)
		details.draw_rect(Rect2(at, Vector2(2, 3)), Color("#e2d3aa"))
	for spoke in 4:
		var angle := phase * TAU * 2.0 + float(spoke) * PI * 0.5
		var end := (REEL_HUB + Vector2.from_angle(angle) * 8.0).round()
		details.draw_line(REEL_HUB, end, Color("#a78255"), 1.0)
	details.draw_rect(Rect2(REEL_HUB - Vector2.ONE, Vector2(3, 3)), Color("#e4c897"))
	if silk.raw_silk > 0:
		details.draw_line(Vector2(-19, -10), REEL_HUB, Color("#dbca9e"), 1.0)

func _draw_loom(bolts: int) -> void:
	if phase < 1.0:
		var shuttle := roundf(sin(phase * TAU * 1.5) * 12.0)
		details.draw_rect(Rect2(Vector2(shuttle - 3.0, -22), Vector2(7, 2)), Color("#794b31"))
	for bolt in mini(3, bolts):
		var at := Vector2(13, -7 - bolt * 3)
		details.draw_rect(Rect2(at, Vector2(11, 4)), Color("#d1bc90"))
		details.draw_rect(Rect2(at, Vector2(9, 1)), Color("#e7d9b4"))
