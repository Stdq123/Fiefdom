extends Node2D

const ART := preload("res://assets/world/field-rotation-book.svg")
const TAP := preload("res://assets/audio/rotation-slip.wav")

@onready var hint: Label = $Hint

func _ready() -> void:
	GameEvents.field_rotation_changed.connect(_refresh)
	GameEvents.day_advanced.connect(queue_redraw.unbind(1))
	_refresh()

func _refresh() -> void:
	visible = Global.field_rotation.signed_day > 0
	if visible and not is_in_group("interactable"):
		add_to_group("interactable")
	set_interaction_focused(false)
	queue_redraw()

func set_interaction_focused(focused: bool) -> void:
	hint.text = GamepadInput.interact_hint("轮作簿") if focused else "轮作簿"
	hint.modulate = Color("#ffe1a2") if focused else Color("#dac798")

func interact() -> void:
	if visible:
		GameEvents.rotation_book_interacted.emit()

func _draw() -> void:
	var tint := Color(0.88, 0.94, 0.99) if Global.has_rain() else Color.WHITE
	draw_texture(ART, Vector2(-17, -26), tint)
