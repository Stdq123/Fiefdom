extends Node2D

var site := -1
var hint: Label
var focused := false

func _ready() -> void:
	hint = Label.new()
	hint.material = preload("res://resources/world_hint_material.tres")
	hint.position = Vector2(-72, -34)
	hint.size.x = 144
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.z_index = 6
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_outline_color", Color("#23352d"))
	hint.add_theme_constant_override("outline_size", 3)
	add_child(hint)
	GameEvents.ravine_journal_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	site = Global.ravine_site_today()
	visible = site >= 0
	if visible:
		position = RavineJournal.SITES[site].position
		if not is_in_group("interactable"):
			add_to_group("interactable")
	elif is_in_group("interactable"):
		remove_from_group("interactable")
	set_interaction_focused(false)

func set_interaction_focused(active: bool) -> void:
	focused = active
	hint.text = GamepadInput.interact_hint("竹简记事") if active else "今日水迹"
	hint.modulate = Color("#fff0ba") if active else Color("#e5cf94")
	queue_redraw()

func interact() -> void:
	Global.record_ravine_site(site)

func _draw() -> void:
	draw_rect(Rect2(-8, 0, 16, 3), Color("#334a39"))
	draw_rect(Rect2(-3, -12, 5, 14), Color("#624833"))
	draw_rect(Rect2(-2, -11, 2, 11), Color("#a88655"))
	draw_rect(Rect2(-7, -16, 14, 9), Color("#6f5238"))
	draw_rect(Rect2(-6, -15, 12, 7), Color("#e6cb8d") if focused else Color("#c5a66e"))
	draw_rect(Rect2(-4, -13, 8, 1), Color("#896540"))
	draw_rect(Rect2(-3, -10, 6, 1), Color("#896540"))
