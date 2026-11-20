extends StaticBody2D

const ART := preload("res://assets/world/silk-interior.png")
const REEL_HUB := Vector2(3, -25)
const REEL_CRANK := Vector2(11, -10)
const TRAY_HAND := Vector2(0, -7)
const WORK_SECONDS := 0.54
const CONTACT_PHASE := 0.25
const LEAF_SIZE := Vector2(8, 6)
const WORM := Rect2(26, 212, 6, 4)
const COCOON := Rect2(34, 212, 4, 5)
const BOLT := Rect2(42, 212, 13, 6)
const SHUTTLE := Rect2(58, 212, 9, 4)
const HUB := Rect2(70, 212, 5, 5)

@export var action := SilkWorkshop.Action.START_BATCH
@onready var hint: Label = $Hint
@onready var details: Node2D = $Details
@onready var player: Player = $"../../Player"

var phase := 1.0
var movement: Tween
var _work_foot := Vector2.INF
var _leaf_release := TRAY_HAND

func _ready() -> void:
	details.draw.connect(_draw_details)
	GameEvents.silk_changed.connect(details.queue_redraw)
	GameEvents.silk_changed.connect(_refresh_hint)
	GameEvents.retainer_duty_changed.connect(_refresh_hint.unbind(1))
	GamepadInput.changed.connect(_refresh_hint)
	visibility_changed.connect(_stop_when_hidden)

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
	_present_work()
	var message := ""
	match action:
		SilkWorkshop.Action.START_BATCH:
			message = "蚕匾已开养 · %d 夜结茧" % Global.silk_workshop.nights_left
		SilkWorkshop.Action.REEL:
			message = "缫完一只蚕茧 · 生丝 +%d" % Global.silk_thread_yield()
		SilkWorkshop.Action.WEAVE:
			message = "织成一匹丝绸"
	GameEvents.silk_station_feedback.emit(message)

func _present_work() -> void:
	if movement and movement.is_running():
		return
	_work_foot = player.global_position
	_leaf_release = TRAY_HAND
	_set_phase(0.0)
	movement = create_tween()
	movement.tween_method(_set_phase, 0.0, CONTACT_PHASE, WORK_SECONDS * CONTACT_PHASE)
	movement.tween_callback(_play_contact)
	movement.tween_method(_set_phase, CONTACT_PHASE, 1.0, WORK_SECONDS * (1.0 - CONTACT_PHASE))

func _play_contact() -> void:
	var hands := player.silk_hands
	if action == SilkWorkshop.Action.START_BATCH and hands.station == self:
		_leaf_release = to_local(hands.to_global(hands.working_hand))
	if is_visible_in_tree():
		AudioManager.play_workshop_cue(action, self)

func _materials_needed() -> String:
	if action == SilkWorkshop.Action.START_BATCH and Global.silk_workshop.nights_left > 0:
		return "这批蚕还需养 %d 夜" % Global.silk_workshop.nights_left
	return Global.silk_workshop.material_shortage(action, Global.balance)

func _set_phase(value: float) -> void:
	phase = value
	details.queue_redraw()
	if not _work_foot.is_finite():
		return
	if (phase >= 1.0 or not player.global_position.is_equal_approx(_work_foot)
			or not player.velocity.is_zero_approx() or player.seated):
		_work_foot = Vector2.INF
		player.clear_silk_work(self)
		return
	var reach := smoothstep(0.04, CONTACT_PHASE, phase) * (1.0 - smoothstep(0.80, 1.0, phase))
	var grip := TRAY_HAND
	var support := Vector2(-14, -6)
	match action:
		SilkWorkshop.Action.REEL:
			grip = _reel_handle()
			support = Vector2(-9, -7)
		SilkWorkshop.Action.WEAVE:
			grip = Vector2(8, _beater_height())
			support = Vector2(-9, grip.y)
	player.show_silk_work(self, to_global(grip), to_global(support), reach)

func _stop_when_hidden() -> void:
	if not is_visible_in_tree() and movement and movement.is_running():
		movement.kill()
		_set_phase(1.0)

func _reel_angle() -> float:
	return TAU * smoothstep(CONTACT_PHASE, 0.90, phase)

func _reel_handle() -> Vector2:
	return (REEL_CRANK + Vector2.from_angle(_reel_angle()) * Vector2(4.0, 2.5)).snappedf(0.5)

func _beater_height() -> float:
	var stroke := smoothstep(CONTACT_PHASE, 0.78, phase)
	return snappedf(-8.0 + sin(stroke * PI) * 3.0, 0.5)

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
	if phase >= CONTACT_PHASE and phase < 0.68:
		var drop := smoothstep(CONTACT_PHASE, 0.68, phase)
		var leaf := _leaf_release.lerp(Vector2(5, -9), drop) - Vector2(0, sin(drop * PI) * 3.0)
		_draw_at(leaf.round() - LEAF_SIZE * 0.5, Rect2(Vector2(8, 212), LEAF_SIZE))

func _draw_reel(silk: SilkWorkshop) -> void:
	for cocoon in mini(4, silk.cocoons):
		var at := Vector2(-23 + cocoon * 4, -13 + cocoon % 2)
		_draw_at(at, COCOON)
	for spoke in 4:
		var angle := _reel_angle() + float(spoke) * PI * 0.5
		var end := (REEL_HUB + Vector2.from_angle(angle) * 9.0).round()
		details.draw_line(REEL_HUB, end, Color("#715639"), 3.0)
		details.draw_line(REEL_HUB + Vector2.UP, end + Vector2.UP, Color("#b49665"), 1.0)
	if silk.raw_silk > 0:
		var bend := Vector2(-13, -18) + Vector2(0, 1.5 * sin(_reel_angle()))
		details.draw_polyline(PackedVector2Array([Vector2(-19, -10), bend, REEL_HUB]),
			Color("#d1bd91"), 1.0)
	_draw_at(REEL_HUB - Vector2(2, 2), HUB)
	details.draw_line(REEL_HUB + Vector2(5, 8), REEL_CRANK, Color("#6d5138"), 2.0)
	var handle := _reel_handle()
	details.draw_line(REEL_CRANK, handle, Color("#b19668"), 2.0)
	details.draw_rect(Rect2(handle - Vector2(1, 1), Vector2(3, 2)), Color("#d0ac78"))

func _draw_loom(bolts: int) -> void:
	if phase < 1.0:
		var passed := smoothstep(CONTACT_PHASE, 0.80, phase)
		var shuttle := roundf(lerpf(-12.0, 12.0, passed))
		_draw_at(Vector2(shuttle - 4.0, -23), SHUTTLE)
		var beater := _beater_height()
		details.draw_line(Vector2(-13, beater), Vector2(14, beater), Color("#7d5d3d"), 3.0)
		details.draw_line(Vector2(-13, beater - 1.0), Vector2(14, beater - 1.0), Color("#c2a573"), 1.0)
	for bolt in mini(3, bolts):
		var at := Vector2(13, -7 - bolt * 3)
		_draw_at(at, BOLT)

func _draw_at(at: Vector2, region: Rect2) -> void:
	details.draw_texture_rect_region(ART, Rect2(at, region.size), region)
