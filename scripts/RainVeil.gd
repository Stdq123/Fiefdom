extends Node2D

const AIR_INK := Color("#b0cec7")
const WATER_INK := Color("#c2dbd3")
const SNOW_INK := Color("#edf6f0")
# From far to near, each lane specifies speed, streak length and opacity.
const AIR_LANES := [Vector3(172, 9, 0.16), Vector3(222, 13, 0.23), Vector3(276, 18, 0.30)]
# Snow uses the same depth lanes, with size measured in viewport pixels.
const SNOW_LANES := [Vector3(18, 1.0, 0.30), Vector3(27, 1.5, 0.44), Vector3(38, 2.1, 0.58)]
const DRIP_FLIGHT := 0.55
const DRIP_SPLASH := 0.26
const RING_RADIUS := 3.5

class Roof:
	var anchor: Node2D
	var cover: Rect2
	# The x and y are the roof outlet. The z is its projected height above the ground.
	var outlets: Array[Vector3]

	func _init(at: Node2D, sheltered: Rect2, drips: Array[Vector3]) -> void:
		anchor = at
		cover = sheltered
		outlets = drips

class Contact:
	var point: Vector2
	var puddle: bool

	func _init(at: Vector2, in_water: bool) -> void:
		point = at
		puddle = in_water

var elapsed := 0.0
var snowflake_count := 0
var roofs: Array[Roof] = []
var contacts: Array[Contact] = []
@onready var splashes := Node2D.new()

func _ready() -> void:
	splashes.name = "RainSplashes"
	splashes.z_as_relative = false
	splashes.z_index = -2
	splashes.draw.connect(_draw_splashes)
	add_child(splashes)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.estate_room_changed.connect(_refresh.unbind(1))
	_refresh()

func add_roof(anchor: Node2D, cover: Rect2, outlets: Array[Vector3]) -> void:
	roofs.append(Roof.new(anchor, cover, outlets))

func add_puddles(bounds: Array[Rect2], outlines: Array[PackedVector2Array]) -> void:
	for index in bounds.size():
		add_surface(bounds[index], 3, outlines[index])

func add_surface(bounds: Rect2, drops: int, outline := PackedVector2Array()) -> void:
	var perimeter := Vector2(4, 2)
	var inner := Rect2(bounds.position + perimeter, (bounds.size - perimeter * 2.0).max(Vector2.ZERO))
	var in_water := not outline.is_empty()
	# Try the center first, then stagger the remaining hits across the exposed surface.
	for index in drops:
		var offset := Vector2(fposmod(index * 0.618 + 0.5, 1.0), fposmod(index * 0.379 + 0.5, 1.0))
		var point := (inner.position + inner.size * offset).round()
		if not in_water or _ring_inside(point, outline):
			contacts.append(Contact.new(point, in_water))

func _ring_inside(point: Vector2, outline: PackedVector2Array) -> bool:
	for index in 8:
		var rim := Vector2.from_angle(index * TAU / 8.0) * Vector2(RING_RADIUS + 0.45, 2.0)
		if not Geometry2D.is_point_in_polygon(point + rim, outline):
			return false
	return true

func _refresh() -> void:
	var weather := Global.Weather.CLEAR if Global.is_indoors() else Global.weather_on()
	var raining := weather == Global.Weather.RAIN
	snowflake_count = 0
	match weather:
		Global.Weather.LIGHT_SNOW: snowflake_count = 54
		Global.Weather.HEAVY_SNOW: snowflake_count = 96
	visible = raining or snowflake_count > 0
	splashes.visible = raining
	set_process(visible)
	queue_redraw()
	if raining:
		splashes.queue_redraw()

func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, 900.0)
	queue_redraw()
	if splashes.visible:
		splashes.queue_redraw()

func _draw() -> void:
	var viewport := get_viewport_rect()
	var screen_to_map := get_global_transform_with_canvas().affine_inverse()
	var view := (screen_to_map * viewport).grow(4.0)
	var world_to_rain := global_transform.affine_inverse()
	var cover: Array[Rect2] = []
	for roof in roofs:
		if not _roof_visible(roof):
			continue
		var roof_to_map := world_to_rain * roof.anchor.global_transform
		var shade := roof_to_map * roof.cover
		if shade.intersects(view):
			cover.append(shade)
		if snowflake_count > 0:
			continue
		for outlet in roof.outlets:
			var start := roof_to_map * Vector2(outlet.x, outlet.y)
			var landing := roof_to_map * _landing(outlet)
			if view.intersects(Rect2(start, Vector2.ZERO).expand(landing).grow(2.0)):
				_draw_drip(start, landing)
	if snowflake_count > 0:
		_draw_snow(viewport.size, screen_to_map, cover)
	else:
		_draw_air(viewport.size, screen_to_map, cover)

func _roof_visible(roof: Roof) -> bool:
	return is_instance_valid(roof.anchor) and roof.anchor.is_visible_in_tree()

func _draw_air(view_size: Vector2, screen_to_map: Transform2D, cover: Array[Rect2]) -> void:
	for drop in 84:
		var lane := drop % AIR_LANES.size()
		var streak: Vector3 = AIR_LANES[lane]
		var x := fposmod(float(drop * 137) - elapsed * (43.0 + 14.0 * lane), view_size.x + 40.0)
		var y := fposmod(float(drop * 109) + elapsed * streak.x, view_size.y + 40.0)
		var point := Vector2(x - 20.0, y - 20.0).floor()
		var start := screen_to_map * point
		var finish := screen_to_map * (point + Vector2(-streak.y * 0.25, streak.y))
		var footprint := Rect2(start, Vector2.ZERO).expand(finish).grow(0.45)
		if not _under_roof(footprint, cover):
			draw_line(start, finish, Color(AIR_INK, streak.z), 0.43 + 0.13 * lane)

func _draw_snow(view_size: Vector2, screen_to_map: Transform2D, cover: Array[Rect2]) -> void:
	var margin := Vector2(16, 16)
	var span := view_size + margin * 2.0
	draw_set_transform_matrix(screen_to_map)
	for flake in snowflake_count:
		var lane := flake % SNOW_LANES.size()
		var flight: Vector3 = SNOW_LANES[lane]
		var phase := flake * 2.39996
		var sway := sin(phase + elapsed * (0.60 + 0.13 * lane)) * (5.0 + 2.0 * lane)
		var start := Vector2(fposmod(flake * 0.6180339887, 1.0), fposmod(flake * 0.4142135624, 1.0)) * span
		var drift := Vector2(sway - elapsed * (6.0 + 3.0 * lane), elapsed * flight.x)
		var point := (start + drift).posmodv(span) - margin
		var footprint := screen_to_map * Rect2(point, Vector2.ZERO).grow(flight.y)
		if _under_roof(footprint, cover):
			continue
		var arm := Vector2.from_angle(phase + elapsed * 0.42) * flight.y
		var cross := arm.orthogonal() * 0.8
		draw_colored_polygon(PackedVector2Array([point + arm, point + cross, point - arm, point - cross]),
			Color(SNOW_INK, flight.z))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _under_roof(footprint: Rect2, cover: Array[Rect2]) -> bool:
	for area in cover:
		if area.intersects(footprint):
			return true
	return false

func _landing(outlet: Vector3) -> Vector2:
	return Vector2(outlet.x - 1.8, outlet.y + outlet.z)

func _cycle(at: Vector2, rate: float) -> float:
	return fposmod(elapsed * rate + at.dot(Vector2(0.049, 0.031)), 1.0)

func _draw_drip(start: Vector2, landing: Vector2) -> void:
	var phase := _cycle(start, 0.85)
	if phase >= DRIP_FLIGHT:
		return
	var progress := phase / DRIP_FLIGHT
	var fall := progress * progress
	var head := start.lerp(landing, fall)
	var tail := start.lerp(landing, maxf(0.0, fall - 0.08 - progress * 0.10))
	if progress < 0.20:
		draw_circle(head, 0.55, Color(WATER_INK, progress * 2.7))
	else:
		draw_line(tail, head, Color(AIR_INK, 0.49), 0.75)
		draw_line(head.lerp(tail, 0.35), head, Color(WATER_INK, 0.72), 0.85)

func _draw_splashes() -> void:
	var view := (get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()).grow(5.0)
	var world_to_rain := global_transform.affine_inverse()
	for hit in contacts:
		if not view.has_point(hit.point):
			continue
		var phase := _cycle(hit.point, 1.15)
		var duration := 0.48 if hit.puddle else 0.29
		if phase < duration:
			_draw_contact(hit.point, phase / duration, hit.puddle)
	for roof in roofs:
		if not _roof_visible(roof):
			continue
		var roof_to_map := world_to_rain * roof.anchor.global_transform
		for outlet in roof.outlets:
			var landing := roof_to_map * _landing(outlet)
			if not view.has_point(landing):
				continue
			var phase := _cycle(roof_to_map * Vector2(outlet.x, outlet.y), 0.85) - DRIP_FLIGHT
			if phase >= 0.0 and phase < DRIP_SPLASH:
				_draw_contact(landing, phase / DRIP_SPLASH, false)

func _draw_contact(point: Vector2, age: float, puddle: bool) -> void:
	var ink := Color(WATER_INK, (1.0 - age) * 0.58)
	if puddle:
		splashes.draw_set_transform(point, 0.0, Vector2(1.0, 0.43))
		splashes.draw_arc(Vector2.ZERO, lerpf(0.8, RING_RADIUS, age), 0.24, TAU - 0.52, 12, ink, 0.65)
		splashes.draw_set_transform(Vector2.ZERO)
	if not puddle or age < 0.22:
		var spread := 0.70 + age * 2.1
		var height := sin(age * PI) * 1.65 + 0.45
		splashes.draw_line(point + Vector2(-0.55, 0.1), point + Vector2(-spread, -height), ink, 0.72)
		splashes.draw_line(point + Vector2(0.55, 0.1), point + Vector2(spread, -height * 0.74), ink, 0.72)
