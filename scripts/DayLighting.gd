extends CanvasModulate

const DAWN := Color("#ffe3c2")
const NIGHT := Color("#8298bd")
const LAMP_RISE := 0.64

var lamps: Array[Lantern] = []
var _sky := Gradient.new()
var _glow := GradientTexture2D.new()
var _flicker := 0.0

func _ready() -> void:
	_sky.set_color(0, DAWN)
	_sky.set_color(1, NIGHT)
	_sky.add_point(0.12, Color.WHITE)
	_sky.add_point(0.57, Color.WHITE)
	_sky.add_point(0.72, Color("#f7c79f"))
	_sky.add_point(0.83, Color("#a590a4"))
	_sky.add_point(0.94, NIGHT)
	var falloff := Gradient.new()
	falloff.set_color(0, Color.WHITE)
	falloff.set_color(1, Color.BLACK)
	falloff.add_point(0.27, Color(0.58, 0.58, 0.58))
	falloff.add_point(0.58, Color(0.14, 0.14, 0.14))
	_glow.gradient = falloff
	_glow.width = 152
	_glow.height = 112
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	GameEvents.daylight_changed.connect(refresh)
	refresh()

func place_lamp(layer: Node2D, foot: Vector2, radius_scale := 1.0, ignition := -1.0) -> Lantern:
	var lamp := Lantern.new()
	lamp.name = "Lantern%d" % (lamps.size() + 1)
	lamp.position = foot
	# Leave enough dusk for every automatic lamp to reach full strength at night.
	lamp.ignition = ignition if ignition >= 0.0 else minf(float(lamps.size()) * 0.055, 1.0 - LAMP_RISE)
	lamp.glow.texture = _glow
	lamp.glow.texture_scale = radius_scale
	layer.add_child(lamp)
	lamps.append(lamp)
	return lamp

func refresh(delta := 0.0) -> void:
	var dusk := Global.dusk_amount()
	var winter := Global.season_index() == Global.Season.WINTER
	if Global.is_indoors():
		var room_day := Color("#d6dbd2") if Global.has_rain() else Color("#efe0c6")
		color = room_day.lerp(Color("#aaa5a6"), dusk)
	else:
		color = _sky.sample(Global.day_progress)
	_flicker = fposmod(_flicker + delta, TAU * 4.0)
	for index in lamps.size():
		var phase := _flicker * 4.0 + float(index) * 2.1
		var flicker := 0.72 + 0.045 * sin(phase) + 0.025 * sin(phase * 2.75)
		var ignition := lamps[index].ignition
		lamps[index].set_glow(smoothstep(ignition, ignition + LAMP_RISE, dusk) * flicker, winter)

class Lantern extends Node2D:
	const ART := preload("res://assets/world/bronze-path-lamps.png")
	const CELL := Vector2(16, 24)
	const AT := Vector2(-8, -22)
	const WINDOW := Rect2(3, 5, 10, 9)
	var glow := PointLight2D.new()
	var ignition := 0.0
	var _ember := 0
	var _frost := false

	func _init() -> void:
		glow.position = AT + WINDOW.get_center()
		glow.offset = Vector2(1.5, 9.0)
		glow.color = Color("#ffbc75")
		glow.range_z_max = 4
		glow.enabled = false
		add_child(glow)

	func set_glow(strength: float, winter: bool) -> void:
		glow.enabled = strength > 0.005
		glow.energy = strength
		var ember := clampi(roundi(strength * 10.0), 0, 7)
		if ember != _ember or _frost != winter:
			_ember = ember
			_frost = winter
			queue_redraw()

	func _draw() -> void:
		var source := Vector2(0, CELL.y if _frost else 0.0)
		draw_set_transform(Vector2(1, 0.5), 0.0, Vector2(1.0, 0.31))
		draw_circle(Vector2.ZERO, 4.8, Color("#26333060"))
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect_region(ART, Rect2(AT, CELL), Rect2(source, CELL))
		if _ember > 0:
			var flame := Rect2(source + Vector2(CELL.x, 0) + WINDOW.position, WINDOW.size)
			draw_texture_rect_region(ART, Rect2(AT + WINDOW.position, WINDOW.size),
				flame, Color(1, 1, 1, _ember / 7.0))
