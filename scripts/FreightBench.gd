extends Node2D
class_name FreightBench

const ART := preload("res://assets/world/road-rest.svg")
const BENCH_ART := Rect2(76, 22, 32, 14)
const SEAT_OFFSET := Vector2(-14, 3)
const HANDOFF_OFFSET := Vector2(12, -15)

@onready var hint: Label = $Hint

func _ready() -> void:
	position = EstateLayout.FREIGHT_APPROACH

func pending_arrival() -> Dictionary:
	if Global.outcome != Global.Outcome.RUNNING or Global.is_indoors():
		return {}
	return Global.next_freight_arrival()

func can_interact_from(foot: Vector2) -> bool:
	return (global_position.distance_squared_to(foot) < 18.0 * 18.0 and not get_parent().player.resting
		and not pending_arrival().is_empty())

func set_interaction_focused(active: bool) -> void:
	hint.visible = active
	if active:
		hint.text = GamepadInput.interact_hint("候货座")

func interact() -> void:
	GameEvents.freight_bench_interacted.emit()

func _draw() -> void:
	draw_rect(Rect2(-31, 5, 34, 5), Color("#26362a9c"))
	draw_texture_rect_region(ART, Rect2(Vector2(-30, -7), BENCH_ART.size), BENCH_ART)
	draw_rect(Rect2(-16, -2, 12, 5), Color("#9c895d"))
	draw_rect(Rect2(-15, -2, 10, 1), Color("#c3af7b"))
