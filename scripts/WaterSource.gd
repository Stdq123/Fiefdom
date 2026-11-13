extends Node2D

const ART := preload("res://assets/world/field-spring.svg")
const WATER := Color("#568e87")
const REACH := 18.0

@onready var hint: Label = $Hint
var focused := false

func _ready() -> void:
	GamepadInput.changed.connect(_refresh_hint)
	Preferences.bindings_changed.connect(_refresh_hint)

func refresh(at: Vector2) -> void:
	position = at
	_refresh_hint()
	queue_redraw()

func can_interact_from(foot: Vector2) -> bool:
	return (not Global.is_indoors() and Global.outcome == Global.Outcome.RUNNING
		and foot.distance_squared_to(global_position) <= REACH * REACH)

func interact() -> void:
	GameEvents.water_source_interacted.emit()

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh_hint()

func _refresh_hint() -> void:
	var caption := "水源 · 量水尺" if Global.channel_survey_day > 0 else "水源"
	hint.text = GamepadInput.interact_hint(caption) if focused else caption
	hint.modulate = Color("#ffdfa0") if focused else Color("#c4e2ce")

func _draw() -> void:
	draw_texture(ART, Vector2(-13, -14))
	var network := Global.irrigation
	for direction: Vector2i in Irrigation.NEIGHBORS:
		var direct_gate: bool = network.field_gates.get(network.source_cell + direction * 2) == network.source_cell
		if network.channels.has(network.source_cell + direction) or direct_gate:
			var axis := Vector2(direction)
			draw_line(axis * 4.0, axis * 9.0, Color("#455a48"), 7.0)
			draw_line(axis * 3.0, axis * 9.0, WATER, 5.0)
	if Global.channel_survey_day > 0:
		draw_rect(Rect2(7, -14, 4, 15), Color("#44392e"))
		draw_rect(Rect2(8, -13, 2, 13), Color("#d8b276"))
		for mark in [-11, -8, -5, -2]:
			draw_rect(Rect2(8, mark, 2, 1), Color("#73583b"))
