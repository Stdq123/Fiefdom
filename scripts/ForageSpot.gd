extends Node2D

@export var medicinal := false
@export var player: Player

@onready var pack_button: Button = $PackHerbs if medicinal else null

var hint: Label
var focused := false

func _ready() -> void:
	hint = Label.new()
	hint.material = preload("res://resources/world_hint_material.tres")
	hint.position = Vector2(-41, -28)
	hint.size.x = 82
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.z_index = 2
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_outline_color", Color("#26372c"))
	hint.add_theme_constant_override("outline_size", 3)
	add_child(hint)
	GameEvents.forage_taken.connect(_refresh)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.health_changed.connect(_refresh.unbind(1))
	if medicinal:
		pack_button.pressed.connect(_pack_herbs)
		GameEvents.wild_herbs_changed.connect(_refresh)
	_refresh()

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh()

func _refresh() -> void:
	var name_on_map := "野药" if medicinal else "野果"
	var gathered := Global.last_forage_day == Global.current_day
	hint.text = name_on_map
	if focused:
		if gathered:
			hint.text += " · 今日采集已用"
		elif medicinal and Global.wild_herb_recovery() == 0:
			hint.text += " · 气血充足"
		else:
			var reward := "气血 +%d" % Global.wild_herb_recovery() if medicinal else "粮食 +%d" % Global.balance.wild_food_yield
			hint.text = GamepadInput.interact_hint(hint.text) + "\n" + reward
		if medicinal and not gathered and Global.wild_herbs_packed:
			hint.text += "\n已带一份野药"
	if medicinal:
		pack_button.visible = focused and not gathered and not Global.wild_herbs_packed
		pack_button.text = "带走一份" if GamepadInput.active else "带走一份 · Shift+" + GamepadInput.interact_key()
	hint.modulate = Color("#e4cc98") if focused else Color("#d0d9bd")
	queue_redraw()

func _shortcut_input(event: InputEvent) -> void:
	if medicinal and focused and event is InputEventKey and event.pressed and not event.echo \
			and event.shift_pressed and Preferences.matches(event, KeyBindings.INTERACT):
		get_viewport().set_input_as_handled()
		_pack_herbs()

func _pack_herbs() -> void:
	if player.world_controls_blocked():
		return
	if Global.wild_herbs_packed:
		GameEvents.world_notice.emit("背包已带一份野药。")
	elif Global.pack_wild_herbs():
		AudioManager.play_ui_sfx(0.86)

func interact() -> void:
	if medicinal:
		Global.forage_herbs()
	else:
		Global.forage_food()

func _draw() -> void:
	var gathered := Global.last_forage_day == Global.current_day
	if medicinal:
		draw_rect(Rect2(-9, 2, 18, 4), Color("#2e4735"))
		for offset: Vector2 in [Vector2(-6, 0), Vector2(0, -5), Vector2(5, -2)]:
			draw_rect(Rect2(offset + Vector2(0, -8), Vector2(2, 10)), Color("#577f64"))
			draw_rect(Rect2(offset + Vector2(-3, -5), Vector2(7, 3)), Color("#7fa281"))
			if not gathered:
				draw_rect(Rect2(offset + Vector2(-1, -10), Vector2(4, 3)), Color("#bad5b5"))
		return
	draw_rect(Rect2(-12, 3, 24, 5), Color("#273e31"))
	draw_rect(Rect2(-11, -5, 22, 10), Color("#39583e"))
	draw_rect(Rect2(-8, -10, 15, 13), Color("#56764a"))
	draw_rect(Rect2(-3, -13, 7, 12), Color("#718952"))
	draw_rect(Rect2(-9, -6, 6, 5), Color("#7d965a"))
	draw_rect(Rect2(5, -6, 7, 6), Color("#617e50"))
	if not gathered:
		for berry: Vector2 in [Vector2(-8, -3), Vector2(-3, -8), Vector2(3, -5), Vector2(7, -1)]:
			draw_rect(Rect2(berry, Vector2(3, 3)), Color("#cb8359"))
			draw_rect(Rect2(berry, Vector2.ONE), Color("#f5c281"))
