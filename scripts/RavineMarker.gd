extends Node2D

const OAK_BOARD := preload("res://assets/world/estate-site-art.png")
const BOARD_REGION := Rect2(158, 252, 32, 28)

var site := -1
var hint: Label
var focused := false

func _ready() -> void:
	hint = Label.new()
	hint.material = preload("res://resources/world_hint_material.tres")
	hint.position = Vector2(-72, -38)
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
	draw_texture_rect_region(OAK_BOARD, Rect2(-12, -18, 24, 21), BOARD_REGION)
	var bamboo := Color("#e5ca89") if focused else Color("#c3a473")
	for i in 5:
		var x := -6.5 + i * 2.5
		var top := -12.5 + (i % 2) * 0.5
		draw_rect(Rect2(x, top, 2.5, 8), Color("#886945"))
		draw_rect(Rect2(x, top, 1.8, 7), bamboo)
		draw_rect(Rect2(x, top + 3.0 + (i % 3) * 0.5, 1.5, 0.8), Color("#466862"))
	for y: float in [-11.5, -6.0]:
		draw_line(Vector2(-7, y), Vector2(6, y + 0.5), Color("#70513b"), 0.9)
