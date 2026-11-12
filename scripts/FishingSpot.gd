extends Node2D

@export var site: CreekFish.Site = CreekFish.Site.POOL
@export var water := Vector2(32, 0)

var hint: Label
var focused := false
var line_visible := false
var rod_grip := Vector2.ZERO
var phase_time := 0.0
var submerged := false

func _ready() -> void:
	hint = Label.new()
	hint.material = preload("res://resources/world_hint_material.tres")
	hint.position = Vector2(-94, -34)
	hint.size.x = 188
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.z_index = 6
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_outline_color", Color("#26372c"))
	hint.add_theme_constant_override("outline_size", 3)
	add_child(hint)
	GameEvents.forage_taken.connect(_refresh)
	GameEvents.stamina_changed.connect(_refresh.unbind(1))
	_refresh()

func _refresh() -> void:
	hint.text = CreekFish.PLACES[site] + "钓点"
	if line_visible:
		hint.text = CreekFish.PLACES[site] + " · 垂钓中"
	elif focused:
		var reason := Global.fishing_block_reason()
		var fish := Global.fish_at_today(site)
		var offer := ("%s · 体力 −%d" % [CreekFish.SPECIES[fish].name, Global.balance.fishing_stamina_cost]
			if reason.is_empty() else reason)
		hint.text += " · %s\n%s" % [GamepadInput.interact_key(), offer]
	hint.modulate = Color("#ffe2a4") if focused else Color("#d5d9ac")

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh()

func interact() -> void:
	GameEvents.fishing_requested.emit(self)

func show_line(angler: Vector2, time: float, in_water: bool) -> void:
	if not line_visible:
		line_visible = true
		_refresh()
	rod_grip = to_local(angler) + Vector2(0, -9)
	phase_time = time
	submerged = in_water
	queue_redraw()

func clear_line() -> void:
	if not line_visible:
		return
	line_visible = false
	_refresh()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-9, 1, 20, 4), Color("#273c32"))
	draw_rect(Rect2(-6, -14, 3, 18), Color("#69543e"))
	draw_rect(Rect2(-10, -16, 19, 10), Color("#5a4735"))
	draw_rect(Rect2(-9, -15, 17, 7), Color("#ba9765"))
	draw_rect(Rect2(-6, -12, 7, 1), Color("#4c665e"))
	draw_rect(Rect2(-3, -13, 2, 3), Color("#4c665e"))
	draw_rect(Rect2(4, -2, 8, 6), Color("#75644d"))
	draw_rect(Rect2(4, -3, 8, 2), Color("#aa8d62"))
	if not line_visible:
		return
	var float_at := (water + Vector2(sin(phase_time * 8.0) * 1.3, 1.0 if submerged else 0.0)).round()
	var side := -1.0 if float_at.x < rod_grip.x else 1.0
	var rod_tip := rod_grip + Vector2(side * 12.0, -9.0)
	draw_line(rod_grip, rod_tip, Color("#503e30"), 2.3)
	draw_line(rod_grip + Vector2(0, -1), rod_tip, Color("#bd9d64"), 1.15)
	var bend := rod_tip.lerp(float_at, 0.55) + Vector2(0, -7)
	draw_polyline(PackedVector2Array([rod_tip, bend, float_at]), Color("#ded3a5"), 0.85)
	var ripple := 2.0 + fposmod(phase_time * 11.0, 6.0)
	draw_arc(float_at, ripple, 0.0, TAU, 10, Color("#b3d4c295"), 0.75)
	if submerged:
		draw_rect(Rect2(float_at - Vector2(1, 0), Vector2(2, 1)), Color("#f6dc9d"))
	else:
		draw_rect(Rect2(float_at - Vector2(1, 4), Vector2(2, 4)), Color("#f3c57a"))
		draw_rect(Rect2(float_at - Vector2(1, 4), Vector2(2, 2)), Color("#ce6951"))
