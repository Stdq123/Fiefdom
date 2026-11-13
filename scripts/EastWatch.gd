extends Node2D

const BOARD := preload("res://assets/world/east-watch.svg")
const STORAGE := preload("res://assets/world/estate-storage.png")
const POLE := EstateLayout.WATCH_RELIEF_POST - EstateLayout.EAST_WATCH
const SNARE := EstateLayout.EAST_RAID_SNARE - EstateLayout.EAST_WATCH
const SNARE_NORTH := Vector2(-1, -16)
const SNARE_SOUTH := Vector2(1, 15)

var hint: Label
var focused := false
var relief_day := 0
var wind := 0.0

func _ready() -> void:
	hint = Label.new()
	hint.material = preload("res://resources/world_hint_material.tres")
	hint.position = Vector2(-64, -47)
	hint.size.x = 128
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.z_index = 6
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_outline_color", Color("#293c30"))
	hint.add_theme_constant_override("outline_size", 3)
	add_child(hint)
	GameEvents.east_watch_built.connect(_refresh)
	GameEvents.raid_started.connect(_refresh)
	GameEvents.raid_defeated.connect(_refresh)
	GameEvents.inventory_changed.connect(_refresh.unbind(1))
	GameEvents.watch_snare_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	relief_day = Global.watch_relief_day()
	var has_board := Global.east_watch_day > 0
	visible = has_board or relief_day > 0
	set_process(Global.season_order_receipts.has(SeasonOrders.WATCH_RELIEF))
	var readable := visible and Global.raid_day == 0
	if readable and not is_in_group("interactable"):
		add_to_group("interactable")
	elif not readable and is_in_group("interactable"):
		remove_from_group("interactable")
	hint.visible = readable or has_board
	hint.text = "东岗守备牌" if has_board else "东岗巡粮簿"
	if Global.raid_day > 0:
		hint.text = "东岗警旗 · 来敌"
	elif Global.watch_snare_armed:
		hint.text = "东岗 · 拦索已备"
	hint.position.x = -75.0 if relief_day > 0 else -64.0
	if readable and focused:
		hint.text = GamepadInput.interact_hint(hint.text)
	hint.modulate = Color("#f2b08c") if Global.raid_day > 0 else Color("#e1cd98")
	queue_redraw()

func _process(delta: float) -> void:
	if relief_day != Global.watch_relief_day():
		_refresh()
	if relief_day > 0 and Global.raid_day == 0:
		wind = fposmod(wind + delta * 4.0, TAU)
		queue_redraw()

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh()

func interact() -> void:
	if visible and Global.raid_day == 0:
		GameEvents.east_watch_read_requested.emit()

func _draw() -> void:
	if Global.east_watch_day > 0:
		draw_texture(BOARD, Vector2(-16, -32))
	if Global.east_watch_day > 0 and Global.raid_day > 0:
		draw_colored_polygon(PackedVector2Array([Vector2(10, -28), Vector2(-7, -26),
			Vector2(-3, -23), Vector2(-7, -20), Vector2(10, -21)]), Color("#b65a48"))
		draw_line(Vector2(9, -28), Vector2(-6, -26), Color("#e28d68"), 1.0)
	if relief_day > 0:
		_draw_relief()
	if Global.watch_snare_armed or Global.raid_snare_left >= 0.0:
		_draw_snare()

func _draw_snare() -> void:
	var north := SNARE + SNARE_NORTH
	var south := SNARE + SNARE_SOUTH
	var anchor := north + Vector2(0, -4)
	var stake := south + Vector2(0, -5)
	if Global.watch_snare_armed:
		draw_line(north + Vector2(1, 0), south + Vector2(1, 0), Color("#68513b"), 2.0)
		draw_line(anchor, stake, Color("#513b2a"), 3.0)
		draw_line(anchor, stake, Color("#e2b970"), 1.2)
		var pennant := anchor.lerp(stake, 0.32)
		draw_colored_polygon(PackedVector2Array([pennant - Vector2(1, 2), pennant + Vector2(6, 1),
			pennant + Vector2(0, 4)]), Color("#b9684e"))
	else:
		draw_polyline(PackedVector2Array([anchor, north + Vector2(4, 3), SNARE + Vector2(5, -2)]), Color("#bb9361"), 1.4)
		draw_line(stake, south + Vector2(5, -7), Color("#bb9361"), 1.4)
	for foot: Vector2 in [north, south]:
		draw_rect(Rect2(foot + Vector2(-3, -1), Vector2(8, 3)), Color("#72583c"))
		draw_rect(Rect2(foot + Vector2(-2, -10), Vector2(4, 11)), Color("#594230"))
		draw_rect(Rect2(foot + Vector2(-1, -10), Vector2(2, 8)), Color("#a0784b"))
		draw_rect(Rect2(foot + Vector2(-2, -6), Vector2(4, 2)), Color("#c9a675"))

func _draw_relief() -> void:
	draw_rect(Rect2(POLE + Vector2(-16, -1), Vector2(26, 5)), Color("#3e4940"))
	draw_rect(Rect2(POLE + Vector2(-16, -4), Vector2(25, 4)), Color("#72583c"))
	draw_texture_rect_region(STORAGE, Rect2(POLE + Vector2(-17, -18), Vector2(16, 16)), Rect2(0, 0, 16, 16), Color("#dac290"))
	draw_texture_rect_region(STORAGE, Rect2(POLE + Vector2(-5, -15), Vector2(16, 16)), Rect2(16, 0, 16, 16), Color("#baad88"))
	draw_rect(Rect2(POLE + Vector2(-2, -45), Vector2(4, 45)), Color("#4c3d30"))
	draw_rect(Rect2(POLE + Vector2(-1, -44), Vector2(1, 40)), Color("#a98051"))
	for knot in [-40, -37, -34]:
		draw_rect(Rect2(POLE + Vector2(-3, knot), Vector2(7, 1)), Color("#e0b984"))
	draw_rect(Rect2(POLE + Vector2(-4, -20), Vector2(8, 9)), Color("#d8ba81"))
	draw_rect(Rect2(POLE + Vector2(-2, -17), Vector2(4, 1)), Color("#86653e"))
	draw_rect(Rect2(POLE + Vector2(-2, -15), Vector2(3, 1)), Color("#86653e"))
	if Global.raid_day > 0:
		return
	var tip := roundf(sin(wind) * 2.0)
	var fold := roundf(sin(wind - 1.4) * 1.5)
	var cloth := PackedVector2Array([POLE + Vector2(3, -41), POLE + Vector2(12, -41 + fold),
		POLE + Vector2(25, -40 + tip), POLE + Vector2(21, -34 + tip), POLE + Vector2(25, -27 + tip),
		POLE + Vector2(12, -29 + fold), POLE + Vector2(3, -28)])
	draw_colored_polygon(cloth, Color("#53786c"))
	draw_polyline(PackedVector2Array([cloth[0] + Vector2.DOWN, cloth[1] + Vector2.DOWN,
		cloth[2] + Vector2(-1, 1)]), Color("#c6ac6d"), 1.0)
	draw_rect(Rect2(POLE + Vector2(6, -37), Vector2(2, 7)), Color("#8fb28f"))
