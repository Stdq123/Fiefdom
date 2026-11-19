extends StaticBody2D

const ART := preload("res://assets/world/silk-interior.png")
const REEL_HUB := Vector2(3, -25)
const LEAF_SIZE := Vector2(8, 6)
const WORM := Rect2(26, 212, 6, 4)
const COCOON := Rect2(34, 212, 4, 5)
const BOLT := Rect2(42, 212, 13, 6)
const SHUTTLE := Rect2(58, 212, 9, 4)
const HUB := Rect2(70, 212, 5, 5)

@export var action := SilkWorkshop.Action.START_BATCH
@onready var hint: Label = $Hint
@onready var details: Node2D = $Details

var phase := 1.0
var movement: Tween

func _ready() -> void:
	details.draw.connect(_draw_details)
	GameEvents.silk_changed.connect(details.queue_redraw)
	GameEvents.silk_changed.connect(_refresh_hint)
	GameEvents.retainer_duty_changed.connect(_refresh_hint.unbind(1))
	GamepadInput.changed.connect(_refresh_hint)

func can_interact_from(point: Vector2) -> bool:
	return is_visible_in_tree() and global_position.distance_squared_to(point) <= 25.0 * 25.0

func set_interaction_focused(active: bool) -> void:
	hint.visible = active
	_refresh_hint()

func _refresh_hint() -> void:
	if not hint.visible:
		return
	var workshop := Global.silk_workshop
	var balance := Global.balance
	var detail := workshop.material_shortage(action, balance)
	var title := ""
	match action:
		SilkWorkshop.Action.START_BATCH:
			title = "养蚕"
			if workshop.nights_left > 0:
				detail = "余 %d 夜" % workshop.nights_left if detail.is_empty() else "今夜" + detail
			elif detail.is_empty():
				detail = "首夜用 %d 片桑叶" % balance.silk_leaves_per_night
		SilkWorkshop.Action.REEL:
			title = "缫丝"
			if detail.is_empty():
				detail = "1 茧 → %d 份生丝" % Global.silk_thread_yield()
		SilkWorkshop.Action.WEAVE:
			title = "织绸"
			if detail.is_empty():
				detail = "%d 份生丝 → 1 匹" % balance.silk_thread_per_bolt
	hint.text = "%s\n%s" % [GamepadInput.interact_hint(title), detail]

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
		AudioManager.play_workshop_cue(action, self)
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
	if action == SilkWorkshop.Action.START_BATCH and Global.silk_workshop.nights_left > 0:
		return "这批蚕还需养 %d 夜" % Global.silk_workshop.nights_left
	return Global.silk_workshop.material_shortage(action, Global.balance)

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
			var variant := (bundle + shelf) % 3
			var leaf := Vector2(-16 + bundle * 6, -27 + shelf * 15 + (bundle + shelf) % 2)
			_draw_at(leaf, Rect2(Vector2(variant * LEAF_SIZE.x, 212), LEAF_SIZE))
		var crawl := Vector2(-11 + roundf(phase * 5.0), -25 + shelf * 15)
		_draw_at(crawl, WORM)

func _draw_reel(silk: SilkWorkshop) -> void:
	for cocoon in mini(4, silk.cocoons):
		var at := Vector2(-23 + cocoon * 4, -13 + cocoon % 2)
		_draw_at(at, COCOON)
	for spoke in 4:
		var angle := phase * TAU * 2.0 + float(spoke) * PI * 0.5
		var end := (REEL_HUB + Vector2.from_angle(angle) * 9.0).round()
		details.draw_line(REEL_HUB, end, Color("#715639"), 3.0)
		details.draw_line(REEL_HUB + Vector2.UP, end + Vector2.UP, Color("#b49665"), 1.0)
	if silk.raw_silk > 0:
		details.draw_polyline(PackedVector2Array([Vector2(-19, -10), Vector2(-13, -18), REEL_HUB]),
			Color("#d1bd91"), 1.0)
	_draw_at(REEL_HUB - Vector2(2, 2), HUB)

func _draw_loom(bolts: int) -> void:
	if phase < 1.0:
		var shuttle := roundf(sin(phase * TAU * 1.5) * 12.0)
		_draw_at(Vector2(shuttle - 4.0, -23), SHUTTLE)
	for bolt in mini(3, bolts):
		var at := Vector2(13, -7 - bolt * 3)
		_draw_at(at, BOLT)

func _draw_at(at: Vector2, region: Rect2) -> void:
	details.draw_texture_rect_region(ART, Rect2(at, region.size), region)
