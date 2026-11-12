extends Node2D

const ART := preload("res://assets/world/bamboo-herb-bed.svg")
const FRAME := Vector2(44, 28)

var hint: Label
var focused := false
var wait_days := 0

func _ready() -> void:
	hint = Label.new()
	hint.material = preload("res://resources/world_hint_material.tres")
	hint.position = Vector2(-74, -35)
	hint.size.x = 148
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.z_index = 6
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_outline_color", Color("#26372c"))
	hint.add_theme_constant_override("outline_size", 3)
	add_child(hint)
	GameEvents.ravine_journal_changed.connect(_refresh)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.health_changed.connect(_refresh.unbind(1))
	_refresh()

func _refresh() -> void:
	visible = Global.ravine_journal.garden_day > 0
	if visible and not is_in_group("interactable"):
		add_to_group("interactable")
	elif not visible and is_in_group("interactable"):
		remove_from_group("interactable")
	wait_days = Global.herb_garden_wait()
	hint.text = "竹径药圃"
	if focused:
		if wait_days > 0:
			hint.text += "\n新叶还需 %d 夜" % wait_days
		elif Global.health < Global.balance.player_max_health:
			hint.text = GamepadInput.interact_hint(hint.text) + "\n气血 +%d" % mini(Global.balance.wild_herb_healing, Global.balance.player_max_health - Global.health)
		else:
			hint.text += "\n草药已长成"
	hint.modulate = Color("#ecd99c") if focused else Color("#d0d9bd")
	queue_redraw()

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh()

func interact() -> void:
	if wait_days > 0:
		GameEvents.herb_garden_feedback.emit("新叶还需 %d 夜" % wait_days)
	else:
		Global.harvest_herb_garden()

func _draw() -> void:
	var frame_x := FRAME.x if wait_days == 0 else 0.0
	draw_texture_rect_region(ART, Rect2(-22, -23, FRAME.x, FRAME.y), Rect2(frame_x, 0, FRAME.x, FRAME.y))
