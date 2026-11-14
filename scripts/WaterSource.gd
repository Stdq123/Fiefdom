extends Node2D

const ART := preload("res://assets/world/field-spring.svg")
const WATER := Color("#568e87")
const WATER_LIGHT := Color("#a5d4bc")
const REACH := 18.0

@onready var hint: Label = $Hint
@onready var basin: StaticBody2D = $Basin
@onready var glints: Node2D = $Basin/Glints
@onready var runoff: Node2D = $Runoff
@onready var hint_top := hint.position.y
@onready var player: Node2D = $"../Player"
var outlets: Array[Vector2i] = []
var water_frame := 0
var focused := false

func _ready() -> void:
	GamepadInput.changed.connect(_refresh_hint)
	Preferences.bindings_changed.connect(_refresh_hint)
	GameEvents.day_advanced.connect(_refresh_appearance.unbind(1))
	basin.draw.connect(_draw_basin)
	glints.draw.connect(_draw_glints)
	runoff.draw.connect(_draw_runoff)
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	_place_hint()

func refresh(at: Vector2) -> void:
	global_position = at
	outlets.clear()
	var network := Global.irrigation
	for direction: Vector2i in Irrigation.NEIGHBORS:
		var direct_gate: bool = network.field_gates.get(network.source_cell + direction * 2) == network.source_cell
		if network.channels.has(network.source_cell + direction) or direct_gate:
			outlets.append(direction)
	_refresh_hint()
	_refresh_appearance()

func animate_water(frame: int) -> void:
	water_frame = frame
	glints.queue_redraw()

func _refresh_appearance() -> void:
	basin.queue_redraw()
	runoff.queue_redraw()
	glints.queue_redraw()

func can_interact_from(foot: Vector2) -> bool:
	return (not Global.is_indoors() and Global.outcome == Global.Outcome.RUNNING
		and foot.distance_squared_to(global_position) <= REACH * REACH)

func interact() -> void:
	GameEvents.water_source_interacted.emit()

func set_interaction_focused(active: bool) -> void:
	focused = active
	set_physics_process(active)
	_place_hint()
	_refresh_hint()

func _place_hint() -> void:
	var behind := focused and player.global_position.y < global_position.y - 5.0
	hint.position.y = hint_top - (15.0 if behind else 0.0)

func _refresh_hint() -> void:
	var caption := "水源 · 量水尺" if Global.channel_survey_day > 0 else "水源"
	hint.text = GamepadInput.interact_hint(caption) if focused else caption
	hint.modulate = Color("#ffdfa0") if focused else Color("#c4e2ce")

func _draw_basin() -> void:
	var wall := -basin.position
	var stone_tint := Color("#cbd5cb") if Global.has_rain() else Color.WHITE
	basin.draw_texture(ART, wall + Vector2(-16, -12), stone_tint)
	for direction: Vector2i in outlets:
		var axis := Vector2(direction)
		var edge := axis * (13.0 if direction.x != 0 else (8.0 if direction.y < 0 else 12.0))
		basin.draw_line(wall + axis * 5.0, wall + edge, Color("#384e45"), 4.0)
		basin.draw_line(wall + axis * 5.0, wall + edge, WATER, 2.0)
		basin.draw_line(wall + edge - axis * 3.0, wall + edge - axis, Color("#77ada0"), 1.0)
	if Global.season_index() == Global.Season.WINTER:
		var frost := Color("#c4d0bf")
		basin.draw_rect(Rect2(wall + Vector2(-8, -7), Vector2(5, 1)), frost)
		basin.draw_rect(Rect2(wall + Vector2(5, -7), Vector2(4, 1)), frost)
		basin.draw_rect(Rect2(wall + Vector2(-10, 3), Vector2(3, 1)), frost.darkened(0.12))
	if Global.channel_survey_day > 0:
		basin.draw_rect(Rect2(wall + Vector2(8, -17), Vector2(4, 15)), Color("#44392e"))
		basin.draw_rect(Rect2(wall + Vector2(9, -16), Vector2(2, 13)), Color("#d8b276"))
		for mark in [-14, -11, -8, -5]:
			basin.draw_rect(Rect2(wall + Vector2(9, mark), Vector2(2, 1)), Color("#73583b"))

func _draw_glints() -> void:
	var water := -basin.position
	var drift := posmod(water_frame, 9)
	glints.draw_rect(Rect2(water + Vector2(drift - 5, 1), Vector2(3, 1)), WATER_LIGHT)
	glints.draw_rect(Rect2(water + Vector2(5 - drift, -1), Vector2(2, 1)), Color("#81b4a0"))

func _draw_runoff() -> void:
	runoff.draw_colored_polygon(PackedVector2Array([Vector2(-13, 5), Vector2(13, 5),
		Vector2(16, 10), Vector2(9, 14), Vector2(-8, 14), Vector2(-14, 11)]), Color("#26382d98"))
	for direction: Vector2i in outlets:
		var axis := Vector2(direction)
		runoff.draw_line(axis * 5.0, axis * 15.0, Color("#455a48"), 5.0)
		runoff.draw_line(axis * 5.0, axis * 15.0, WATER, 3.0)
