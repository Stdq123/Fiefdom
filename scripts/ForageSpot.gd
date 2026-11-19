extends Node2D

const FORAGE_ART := preload("res://assets/world/ravine-forage.svg")
const BUSH_REGION := Rect2(0, 0, 40, 28)
const FRUIT_REGION := Rect2(40, 0, 40, 28)
const STONE_REGION := Rect2(80, 0, 28, 28)
const HERBS_REGION := Rect2(108, 0, 28, 28)
const CONTACT_Y := 24.0

@export var medicinal := false
@export var player: Player

@onready var pack_button: Button = $PackHerbs if medicinal else null

var hint: Label
var focused := false

func _ready() -> void:
	hint = Label.new()
	hint.material = preload("res://resources/world_hint_material.tres")
	hint.position.x = -41.0
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
	hint.position.y = -CONTACT_Y - hint.get_minimum_size().y
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
	var tint := Color(0.88, 0.94, 0.99) if Global.has_rain() else Color.WHITE
	var base := STONE_REGION if medicinal else BUSH_REGION
	var footprint := Rect2(Vector2(-base.size.x / 2.0, -CONTACT_Y), base.size)
	draw_texture_rect_region(FORAGE_ART, footprint, base, tint, false, true)
	if not gathered:
		var harvest := HERBS_REGION if medicinal else FRUIT_REGION
		draw_texture_rect_region(FORAGE_ART, footprint, harvest, tint, false, true)
