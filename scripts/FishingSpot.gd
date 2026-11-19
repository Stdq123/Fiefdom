extends Node2D

const TACKLE := preload("res://assets/world/fishing-tackle.png")
const MARKER := Rect2(2, 1, 48, 58)
const CREEL := Rect2(56, 18, 37, 34)

@export var site: CreekFish.Site = CreekFish.Site.POOL
@export var water := Vector2(32, 0)

var hint: Label
var focused := false
var line_visible := false
var rod_tip := Vector2.ZERO
var phase_time := 0.0
var submerged := false
var tautness := 0.0

func _ready() -> void:
	hint = Label.new()
	hint.add_to_group(&"interaction_prompt")
	hint.material = preload("res://resources/world_hint_material.tres")
	hint.position = Vector2(-94, -48)
	hint.size.x = 188
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.z_index = 6
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_outline_color", Color("#26372c"))
	hint.add_theme_constant_override("outline_size", 3)
	add_child(hint)
	GameEvents.fish_changed.connect(_refresh)
	GameEvents.stamina_changed.connect(_refresh.unbind(1))
	_refresh()

func _refresh() -> void:
	if line_visible:
		hint.text = ""
		return
	var place: String = CreekFish.PLACES[site]
	hint.text = place if site == CreekFish.Site.POND else place + "钓点"
	if focused:
		var reason := Global.fishing_block_reason(false, site)
		var fish := Global.fish_at_today(site)
		var offer := ("%s · 体力 −%d" % [CreekFish.SPECIES[fish].name, Global.balance.fishing_stamina_cost]
			if reason.is_empty() else reason)
		hint.text += " · %s\n%s" % [GamepadInput.interact_key(), offer]
	hint.modulate = Color("#ffe2a4") if focused else Color("#d5d9ac")

func can_interact_from(foot: Vector2) -> bool:
	return visible and (site != CreekFish.Site.POND or global_position.distance_squared_to(foot) <= 25.0 * 25.0)

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh()

func interact() -> void:
	GameEvents.fishing_requested.emit(self)

func show_line(world_tip: Vector2, time: float, in_water: bool, pull: float) -> void:
	if not line_visible:
		line_visible = true
		_refresh()
	rod_tip = to_local(world_tip)
	phase_time = time
	submerged = in_water
	tautness = pull
	queue_redraw()

func clear_line() -> void:
	if not line_visible:
		return
	line_visible = false
	_refresh()
	queue_redraw()

func _draw() -> void:
	var shore := -1.0 if water.x > 0.0 else 1.0
	var post := Vector2(4.0 * shore, -2.0)
	draw_colored_polygon(PackedVector2Array([post + Vector2(-5, 1), post + Vector2(3, -1),
		post + Vector2(10, 3), post + Vector2(6, 4), post + Vector2(-3, 3)]), Color("#293b355e"))
	draw_texture_rect_region(TACKLE, Rect2(post + Vector2(-12, -26), MARKER.size * 0.5), MARKER)
	_draw_creel(self, post + Vector2(shore * 12.0, 4.0))
	if line_visible:
		_draw_line()

func _draw_creel(canvas: Node2D, foot: Vector2) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([foot + Vector2(-7, -1), foot + Vector2(2, -3),
		foot + Vector2(10, 0), foot + Vector2(7, 2), foot + Vector2(-4, 2)]), Color("#26372f73"))
	canvas.draw_texture_rect_region(TACKLE, Rect2(foot + Vector2(-9, -15), CREEL.size * 0.5), CREEL)

func _draw_line() -> void:
	var cast := smoothstep(0.02, 0.32, phase_time)
	var drift := Vector2(sin(phase_time * 5.0) * (1.0 + tautness), 1.0 if submerged else 0.0)
	var float_at := (rod_tip.lerp(water + drift, cast) + Vector2.UP * sin(cast * PI) * 7.0).snappedf(0.5)
	var slack := (1.0 - tautness) * minf(4.0, rod_tip.distance_to(float_at) * 0.18)
	var line := PackedVector2Array()
	for i in 7:
		var t := i / 6.0
		line.append(rod_tip.lerp(float_at, t) + Vector2.DOWN * (4.0 * t * (1.0 - t) * slack))
	draw_polyline(line, Color("#e0d8b5"), 0.72)
	if cast >= 1.0:
		var wave := fposmod((phase_time - 0.32) * (1.7 if submerged else 0.9), 1.0)
		var arc := PackedVector2Array()
		for i in 12:
			var ring := Vector2.from_angle(TAU * i / 12.0 + 0.45) * (2.0 + wave * 6.0)
			arc.append(float_at + ring * Vector2(1.0, 0.38))
		draw_polyline(arc, Color(0.72, 0.84, 0.73, 0.84 - 0.65 * wave), 0.83)
	if submerged:
		draw_rect(Rect2(float_at + Vector2(-1.0, -1.0), Vector2(2.5, 1.5)), Color("#f4dbaa"))
	else:
		draw_rect(Rect2(float_at - Vector2(1.0, 5.5), Vector2(2, 5.5)), Color("#684e38"))
		draw_rect(Rect2(float_at - Vector2(1.5, 4), Vector2(3, 2.5)), Color("#eedcaa"))
		draw_rect(Rect2(float_at - Vector2(1.0, 6.0), Vector2(2, 2)), Color("#d77b55"))
