extends Node2D

const TERRAIN_AUDIO := preload("res://scripts/TerrainAudio.gd")
const SNOW_FOOTPRINTS := preload("res://scripts/SnowFootprints.gd")
const SPLASH_SECONDS := 0.56
const OUTLINE := [
	Vector2(0.0, 0.44), Vector2(0.09, 0.44), Vector2(0.09, 0.23), Vector2(0.24, 0.23),
	Vector2(0.27, 0.10), Vector2(0.49, 0.10), Vector2(0.55, 0.0), Vector2(0.80, 0.0),
	Vector2(0.80, 0.22), Vector2(0.94, 0.26), Vector2(1.0, 0.48), Vector2(0.94, 0.68),
	Vector2(0.78, 0.68), Vector2(0.75, 0.92), Vector2(0.52, 0.92), Vector2(0.46, 1.0),
	Vector2(0.22, 0.93), Vector2(0.19, 0.73), Vector2(0.04, 0.70),
]

class Ripple:
	var position: Vector2
	var age := 0.0

	func _init(at: Vector2) -> void:
		position = at.round()

var cover := TERRAIN_AUDIO.Surface.GRASS
var bounds: Array[Rect2] = []
var patches: Array[PackedVector2Array] = []
var ripples: Array[Ripple] = []
var snow_footprints: SNOW_FOOTPRINTS

@onready var audio: TERRAIN_AUDIO = AudioManager.terrain_audio

func _init(puddles: Array[Rect2], drifts: Array[Rect2]) -> void:
	if Global.has_rain():
		cover = TERRAIN_AUDIO.Surface.SHALLOWS
		bounds = puddles
	elif Global.season_index() == Global.Season.WINTER:
		cover = TERRAIN_AUDIO.Surface.SNOW
		bounds = drifts

	for index in bounds.size():
		var patch := bounds[index]
		var outline := PackedVector2Array()
		for point: Vector2 in OUTLINE:
			var x := point.x if index % 2 == 0 else 1.0 - point.x
			outline.append((patch.position + Vector2(x, point.y) * patch.size).round())
		patches.append(outline)

func _ready() -> void:
	set_process(false)
	if cover == TERRAIN_AUDIO.Surface.SNOW:
		snow_footprints = SNOW_FOOTPRINTS.new()
		add_child(snow_footprints)

func play_step(at: Vector2, movement: Vector2, surface: TERRAIN_AUDIO.Surface) -> void:
	var foot := to_local(at)
	for outline in patches:
		if Geometry2D.is_point_in_polygon(foot, outline):
			surface = cover
			break
	audio.play_step(surface)
	if surface == TERRAIN_AUDIO.Surface.SHALLOWS:
		ripples.append(Ripple.new(foot))
		set_process(true)
		queue_redraw()
	elif surface == TERRAIN_AUDIO.Surface.SNOW:
		snow_footprints.leave(foot, movement, audio.step_variant % 2 == 0)

func _process(delta: float) -> void:
	for ripple in ripples:
		ripple.age += delta
	while not ripples.is_empty() and ripples.front().age >= SPLASH_SECONDS:
		ripples.pop_front()
	if ripples.is_empty():
		set_process(false)
	queue_redraw()

func _draw() -> void:
	for index in patches.size():
		if cover == TERRAIN_AUDIO.Surface.SHALLOWS:
			_draw_puddle(patches[index], bounds[index])
		else:
			_draw_drift(patches[index], bounds[index].get_center())
	for ripple in ripples:
		var age := ripple.age / SPLASH_SECONDS
		draw_set_transform(ripple.position, 0.0, Vector2(1.0, 0.57))
		draw_arc(Vector2.ZERO, lerpf(2.0, 11.0, age), 0.0, TAU, 12,
			Color(0.77, 0.87, 0.81, (1.0 - age) * 0.77), 1.0)

func _draw_puddle(outline: PackedVector2Array, area: Rect2) -> void:
	draw_set_transform(Vector2(0, 2))
	draw_colored_polygon(outline, Color("#263b37a6"))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(outline, Color("#526a62e8"))
	var top := area.position + (area.size * Vector2(0.30, 0.28)).round()
	draw_rect(Rect2(top, Vector2(roundf(area.size.x * 0.38), 1)), Color("#8da69a"))
	var lower := area.position + (area.size * Vector2(0.54, 0.69)).round()
	draw_rect(Rect2(lower, Vector2(roundf(area.size.x * 0.21), 1)), Color("#6d8b80"))

func _draw_drift(outline: PackedVector2Array, center: Vector2) -> void:
	draw_set_transform(Vector2(1, 3))
	draw_colored_polygon(outline, Color("#90a59ba6"))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(outline, Color("#b5c5b8"))
	for index in range(0, outline.size(), 3):
		var edge := outline[index]
		var flake := edge.lerp(center, 0.35).round()
		draw_rect(Rect2(flake, Vector2(3 + index % 4, 1)), Color("#c9d6c8"))
		var scatter := edge.lerp(center, -0.13).round()
		draw_rect(Rect2(scatter, Vector2(2 + index % 3, 1)), Color("#a8bcb0"))
