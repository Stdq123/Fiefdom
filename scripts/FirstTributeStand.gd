extends Node2D

const STORAGE := preload("res://assets/world/estate-vessels.png")

@onready var hint: Label = $Hint

func _ready() -> void:
	GameEvents.crop_harvested.connect(_refresh.unbind(1))
	GameEvents.campaign_ended.connect(_refresh.unbind(1))
	_refresh()

func _refresh() -> void:
	visible = Global.outcome == Global.Outcome.RUNNING and Global.first_tribute_delivered()
	if visible:
		add_to_group("interactable")
	else:
		remove_from_group("interactable")
		hint.hide()

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-15, -1), Vector2(13, -1),
		Vector2(20, 3), Vector2(15, 5), Vector2(-12, 5)]), Color("#2a322c82"))
	draw_colored_polygon(PackedVector2Array([Vector2(-15, -7), Vector2(11, -7),
		Vector2(16, -3), Vector2(16, 2), Vector2(-14, 2), Vector2(-16, 0)]), Color("#674b31"))
	draw_colored_polygon(PackedVector2Array([Vector2(-15, -7), Vector2(11, -7),
		Vector2(16, -3), Vector2(-12, -3), Vector2(-16, -5)]), Color("#ac8b56"))
	draw_line(Vector2(-12, -2), Vector2(15, -2), Color("#886641"), 1.0)
	draw_texture_rect_region(STORAGE, Rect2(-14, -18, 18, 18), Rect2(16, 0, 16, 16))
	draw_colored_polygon(PackedVector2Array([Vector2(2, -7), Vector2(11, -6),
		Vector2(13, -3), Vector2(3, -4)]), Color("#e4c585"))
	draw_line(Vector2(6, -6), Vector2(9, -5), Color("#715437"), 1.0)

func can_interact_from(foot: Vector2) -> bool:
	return visible and not Global.is_indoors() and foot.distance_squared_to(global_position) <= 19.0 * 19.0

func set_interaction_focused(active: bool) -> void:
	hint.visible = active
	if active:
		hint.text = GamepadInput.interact_hint("翻看贡粮账")

func interact() -> void:
	GameEvents.first_tribute_ledger_requested.emit()
