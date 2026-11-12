extends CanvasModulate

const DAWN := Color("#ffe3c2")
const NIGHT := Color("#8298bd")

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
	_glow.width = 128
	_glow.height = 128
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	GameEvents.daylight_changed.connect(refresh)
	refresh()

func place_lamp(layer: Node2D, foot: Vector2, radius_scale := 1.0, ignition := -1.0) -> void:
	var lamp := Lantern.new()
	lamp.name = "Lantern%d" % (lamps.size() + 1)
	lamp.position = foot
	lamp.ignition = ignition if ignition >= 0.0 else float(lamps.size()) * 0.055
	lamp.glow.texture = _glow
	lamp.glow.texture_scale = radius_scale
	layer.add_child(lamp)
	lamps.append(lamp)

func refresh(delta := 0.0) -> void:
	var dusk := Global.dusk_amount()
	color = Color("#efe0c6").lerp(Color("#be9b88"), dusk) if Global.is_indoors() else _sky.sample(Global.day_progress)
	_flicker = fposmod(_flicker + delta, TAU * 4.0)
	for index in lamps.size():
		var phase := _flicker * 4.0 + float(index) * 2.1
		var flicker := 0.72 + 0.045 * sin(phase) + 0.025 * sin(phase * 2.75)
		var ignition := lamps[index].ignition
		lamps[index].set_glow(smoothstep(ignition, ignition + 0.64, dusk) * flicker)

class Lantern extends Node2D:
	var glow := PointLight2D.new()
	var ignition := 0.0
	var _lit := false

	func _init() -> void:
		glow.position = Vector2(0, -11)
		glow.color = Color("#ffbc75")
		glow.range_z_max = 4
		glow.enabled = false
		add_child(glow)

	func set_glow(strength: float) -> void:
		glow.enabled = strength > 0.005
		glow.energy = strength
		if glow.enabled != _lit:
			_lit = glow.enabled
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-5, -1, 10, 2), Color("#26333088"))
		draw_rect(Rect2(-3, -3, 6, 3), Color("#777460"))
		draw_rect(Rect2(-1, -10, 2, 8), Color("#78583d"))
		draw_rect(Rect2(-4, -16, 8, 7), Color("#493a2c"))
		draw_rect(Rect2(-3, -15, 6, 4), Color("#edac5c") if _lit else Color("#8a7756"))
		if _lit:
			draw_rect(Rect2(-1, -14, 2, 3), Color("#ffe0a1"))
		draw_rect(Rect2(-5, -17, 10, 2), Color("#624b38"))
		draw_rect(Rect2(-3, -18, 6, 1), Color("#907454"))
