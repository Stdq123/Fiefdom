extends Node2D

const ART := preload("res://assets/world/road-rest.svg")
const FRAME := Vector2(64, 38)

@onready var hint: Label = $Hint

var focused := false

static func portrait() -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ART
	texture.region = Rect2(Vector2(FRAME.x, 0), FRAME)
	texture.filter_clip = true
	return texture

func _ready() -> void:
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.road_rest_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	visible = Global.road_rest_paid_day > 0
	var available := Global.road_rest_built() and Global.outcome == Global.Outcome.RUNNING
	if available and not is_in_group("interactable"):
		add_to_group("interactable")
	elif not available and is_in_group("interactable"):
		remove_from_group("interactable")
	set_interaction_focused(focused and available)
	queue_redraw()

func set_interaction_focused(active: bool) -> void:
	focused = active
	hint.text = "亭西备料 · 明日开用"
	if Global.road_rest_built():
		hint.text = GamepadInput.interact_hint("歇脚处") if focused else "歇脚处"
	hint.modulate = Color("#ffe2a4") if focused else Color("#d5c49a")

func interact() -> void:
	if Global.road_rest_built() and Global.outcome == Global.Outcome.RUNNING:
		GameEvents.road_rest_interacted.emit()

func _draw() -> void:
	var region := Rect2(Vector2(FRAME.x if Global.road_rest_built() else 0.0, 0), FRAME)
	var tint := Color(0.88, 0.94, 0.99) if Global.has_rain() else Color.WHITE
	draw_texture_rect_region(ART, Rect2(Vector2(-FRAME.x / 2, -FRAME.y + 2), FRAME), region, tint)
