extends Node2D

const GROUND := preload("res://scripts/EstateTerrain.gd")
const TERRAIN_AUDIO := preload("res://scripts/TerrainAudio.gd")
const FOOTSTEP_EFFECTS := preload("res://scripts/FootstepEffects.gd")
const OUTLINE := [
	Vector2(0.0, 0.44), Vector2(0.09, 0.44), Vector2(0.09, 0.23), Vector2(0.24, 0.23),
	Vector2(0.27, 0.10), Vector2(0.49, 0.10), Vector2(0.55, 0.0), Vector2(0.80, 0.0),
	Vector2(0.80, 0.22), Vector2(0.94, 0.26), Vector2(1.0, 0.48), Vector2(0.94, 0.68),
	Vector2(0.78, 0.68), Vector2(0.75, 0.92), Vector2(0.52, 0.92), Vector2(0.46, 1.0),
	Vector2(0.22, 0.93), Vector2(0.19, 0.73), Vector2(0.04, 0.70),
]

var cover := TERRAIN_AUDIO.Surface.GRASS
var bounds: Array[Rect2] = []
var patches: Array[PackedVector2Array] = []
@onready var audio: TERRAIN_AUDIO = AudioManager.terrain_audio
@onready var footstep_effects := FOOTSTEP_EFFECTS.new()
@onready var resident_footsteps := FOOTSTEP_EFFECTS.new()

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
	add_child(footstep_effects)
	resident_footsteps.name = "ResidentFootsteps"
	add_child(resident_footsteps)

func play_step(at: Vector2, movement: Vector2, surface: TERRAIN_AUDIO.Surface) -> void:
	audio.play_step(_show_contact(footstep_effects, at, movement, surface))

func show_resident_step(at: Vector2, movement: Vector2, surface: TERRAIN_AUDIO.Surface) -> void:
	if resident_footsteps.is_contact_near_view(at):
		_show_contact(resident_footsteps, at, movement, surface)

func _show_contact(effects: FOOTSTEP_EFFECTS, at: Vector2, movement: Vector2,
		surface: TERRAIN_AUDIO.Surface) -> TERRAIN_AUDIO.Surface:
	var foot := to_local(at)
	for outline in patches:
		if Geometry2D.is_point_in_polygon(foot, outline):
			if cover == TERRAIN_AUDIO.Surface.SHALLOWS:
				effects.splash(foot, movement, outline)
			else:
				effects.leave_snow(foot, movement)
			return cover
	if surface == TERRAIN_AUDIO.Surface.TRACK and cover != TERRAIN_AUDIO.Surface.SHALLOWS:
		effects.lift_dust(foot, movement)
	return surface

func _draw() -> void:
	for index in patches.size():
		if cover == TERRAIN_AUDIO.Surface.SHALLOWS:
			_draw_puddle(patches[index], bounds[index])
		else:
			draw_colored_polygon(patches[index], Color("#bccdc115"))
			GROUND.draw_snow(self, bounds[index], index)

func _draw_puddle(outline: PackedVector2Array, area: Rect2) -> void:
	draw_set_transform(Vector2(0, 2))
	draw_colored_polygon(outline, Color("#263b37a6"))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(outline, Color("#526a62e8"))
	var top := area.position + (area.size * Vector2(0.30, 0.28)).round()
	draw_rect(Rect2(top, Vector2(roundf(area.size.x * 0.38), 1)), Color("#8da69a"))
	var lower := area.position + (area.size * Vector2(0.54, 0.69)).round()
	draw_rect(Rect2(lower, Vector2(roundf(area.size.x * 0.21), 1)), Color("#6d8b80"))
