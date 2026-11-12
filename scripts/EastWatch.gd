extends Node2D

const BOARD := preload("res://assets/world/east-watch.svg")

var hint: Label
var focused := false

func _ready() -> void:
	hint = Label.new()
	hint.material = preload("res://resources/world_hint_material.tres")
	hint.position = Vector2(-64, -47)
	hint.size.x = 128
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.z_index = 6
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_outline_color", Color("#293c30"))
	hint.add_theme_constant_override("outline_size", 3)
	add_child(hint)
	GameEvents.east_watch_built.connect(_refresh)
	GameEvents.raid_started.connect(_refresh)
	GameEvents.raid_defeated.connect(_refresh)
	_refresh()

func _refresh() -> void:
	visible = Global.east_watch_day > 0
	var readable := visible and Global.raid_day == 0
	if readable and not is_in_group("interactable"):
		add_to_group("interactable")
	elif not readable and is_in_group("interactable"):
		remove_from_group("interactable")
	hint.text = "东岗警旗 · 来敌" if Global.raid_day > 0 else "东岗守备牌"
	if readable and focused:
		hint.text = GamepadInput.interact_hint(hint.text)
	hint.modulate = Color("#f2b08c") if Global.raid_day > 0 else Color("#e1cd98")
	queue_redraw()

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh()

func interact() -> void:
	if visible and Global.raid_day == 0:
		GameEvents.east_watch_read_requested.emit()

func _draw() -> void:
	draw_texture(BOARD, Vector2(-16, -32))
	if Global.raid_day > 0:
		draw_colored_polygon(PackedVector2Array([Vector2(10, -28), Vector2(-7, -26),
			Vector2(-3, -23), Vector2(-7, -20), Vector2(10, -21)]), Color("#b65a48"))
		draw_line(Vector2(9, -28), Vector2(-6, -26), Color("#e28d68"), 1.0)
