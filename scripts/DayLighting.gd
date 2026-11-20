extends CanvasModulate

const CLOUD_SHADER := preload("res://resources/cloud-shadow.gdshader")
const CLOUD_COVER := preload("res://resources/cloud-cover.tres")
const DAWN := Color("#ffe3c2")
const NIGHT := Color("#8298bd")
const LAMP_RISE := 0.64
const SNOW_IGNITION_LIMIT := 0.12
# Indexed by Global.Weather.
const ROOM_DAY: Array[Color] = [Color("#efe0c6"), Color("#d6dbd2"), Color("#dce3de"), Color("#cad7dc")]
const EARLY_LAMP: Array[float] = [0.0, 0.32, 0.21, 0.38]

var lamps: Array[Lantern] = []
var _skies: Array[Gradient] = []
var _glow := GradientTexture2D.new()
var _cloud_shadow: ColorRect
var _cloud_material: ShaderMaterial
var _flicker := 0.0

func _ready() -> void:
	var clear := Gradient.new()
	clear.set_color(0, DAWN)
	clear.set_color(1, NIGHT)
	clear.add_point(0.12, Color.WHITE)
	clear.add_point(0.57, Color.WHITE)
	clear.add_point(0.72, Color("#f7c79f"))
	clear.add_point(0.83, Color("#a590a4"))
	clear.add_point(0.94, NIGHT)
	var rain := Gradient.new()
	rain.set_color(0, Color("#c6d1d9"))
	rain.set_color(1, NIGHT)
	rain.add_point(0.12, Color("#ccdbe0"))
	rain.add_point(0.57, Color("#ccdbe0"))
	rain.add_point(0.73, Color("#abb8c7"))
	rain.add_point(0.85, Color("#8d9eb7"))
	rain.add_point(0.94, NIGHT)
	_skies = [
		clear, rain,
		_snow_sky(Color("#d6e5ee"), Color("#e4edf4"), Color("#a7b7cf")),
		_snow_sky(Color("#becfdc"), Color("#d0dfe9"), Color("#96abc3")),
	]
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
	GameEvents.estate_room_changed.connect(refresh.unbind(1))
	refresh()

static func _snow_sky(morning: Color, daylight: Color, evening: Color) -> Gradient:
	var sky := Gradient.new()
	sky.set_color(0, morning)
	sky.set_color(1, NIGHT)
	sky.add_point(0.12, daylight)
	sky.add_point(0.57, daylight)
	sky.add_point(0.74, evening)
	sky.add_point(0.94, NIGHT)
	return sky

func add_cloud_shadows(bounds: Rect2) -> void:
	_cloud_material = ShaderMaterial.new()
	_cloud_material.shader = CLOUD_SHADER
	_cloud_material.set_shader_parameter(&"cloud_cover", CLOUD_COVER)
	_cloud_shadow = ColorRect.new()
	_cloud_shadow.name = "CloudShadow"
	_cloud_shadow.position = bounds.position
	_cloud_shadow.size = bounds.size
	_cloud_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cloud_shadow.z_as_relative = false
	# Tint the scenery and actors below the rain streaks and the HUD canvas.
	_cloud_shadow.z_index = 8
	_cloud_shadow.material = _cloud_material
	add_child(_cloud_shadow)
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
	var indoors := Global.is_indoors()
	var weather := Global.weather_on()
	if indoors:
		color = ROOM_DAY[weather].lerp(Color("#aaa5a6"), dusk)
	else:
		color = _skies[weather].sample(Global.day_progress)
		dusk = maxf(dusk, EARLY_LAMP[weather] * smoothstep(0.50, 0.75, Global.day_progress))
	if _cloud_shadow != null:
		_update_cloud_shadow(not indoors and weather == Global.Weather.CLEAR)
	var snowy_outdoors := not indoors and weather in [Global.Weather.LIGHT_SNOW, Global.Weather.HEAVY_SNOW]
	_flicker = fposmod(_flicker + delta, TAU * 4.0)
	for index in lamps.size():
		var phase := _flicker * 4.0 + float(index) * 2.1
		var flicker := 0.72 + 0.045 * sin(phase) + 0.025 * sin(phase * 2.75)
		var ignition := lamps[index].ignition
		if snowy_outdoors:
			ignition = minf(ignition, SNOW_IGNITION_LIMIT)
		lamps[index].set_glow(smoothstep(ignition, ignition + LAMP_RISE, dusk) * flicker, winter)

func _update_cloud_shadow(sun_visible: bool) -> void:
	var time := Global.day_progress
	var sunlight := smoothstep(0.07, 0.18, time) * (1.0 - smoothstep(0.59, 0.77, time))
	_cloud_shadow.visible = sun_visible and sunlight > 0.005
	if _cloud_shadow.visible:
		var date := float(Global.current_day - 1) + time
		var offset := (Vector2(0.46, 0.16) * date).posmod(1.0)
		_cloud_material.set_shader_parameter(&"cloud_offset", offset)
		_cloud_material.set_shader_parameter(&"shadow_strength", 0.15 * sunlight)

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
