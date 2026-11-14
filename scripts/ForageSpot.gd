extends Node2D

const BERRY_PILES := [Vector2(-9, 0), Vector2(-6, -8), Vector2(4, -6), Vector2(7, 1)]
const HERB_LEAVES := [Vector2(-4, -5), Vector2(0, 1), Vector2(6, -4)]

@export var medicinal := false
@export var player: Player

@onready var pack_button: Button = $PackHerbs if medicinal else null

var hint: Label
var focused := false

func _ready() -> void:
	hint = Label.new()
	hint.material = preload("res://resources/world_hint_material.tres")
	hint.position = Vector2(-41, -35)
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
		_draw_herbs(gathered)
	else:
		_draw_berry_bush(gathered)

func _draw_herbs(gathered: bool) -> void:
	var dark := Color("#345341")
	var leaf := Color("#668c5b")
	var upper := Color("#9bb37a")
	if gathered:
		upper = leaf
	draw_rect(Rect2(-10, 2, 21, 4), Color("#38463899"))
	draw_rect(Rect2(-7, 0, 14, 5), Color("#574f3e"))
	draw_rect(Rect2(-5, 0, 11, 2), Color("#8b7f5f"))
	for index in HERB_LEAVES.size():
		var node: Vector2 = HERB_LEAVES[index]
		var side := -1.0 if index == 0 else 1.0
		var head := node + Vector2(side * 4, -8)
		draw_line(Vector2(node.x * 0.48, 3), head + Vector2(0, 2), dark, 2.0)
		_draw_leaf(node, Vector2(5, -5), leaf, dark, upper)
		_draw_leaf(node - Vector2(0, 3), Vector2(-5, -3), leaf, dark, upper)
		if not gathered:
			draw_rect(Rect2(head - Vector2(2, 1), Vector2(5, 3)), Color("#779668"))
			draw_rect(Rect2(head - Vector2(1, 2), Vector2(2, 2)), Color("#c0cd98"))
			draw_rect(Rect2(head + Vector2(1, -1), Vector2(2, 1)), Color("#a9bc85"))

func _draw_leaf(base: Vector2, direction: Vector2, leaf: Color, underside: Color, rim: Color) -> void:
	var tip := base + direction
	var right := base + direction * 0.56 + Vector2(1, 2)
	var left := base + direction * 0.30 - Vector2(0, 2)
	draw_colored_polygon(PackedVector2Array([base, left, tip, right]), underside)
	draw_colored_polygon(PackedVector2Array([base, left, tip]), leaf)
	draw_line(base.lerp(tip, 0.32), tip, rim, 1.0)

func _draw_berry_bush(gathered: bool) -> void:
	draw_rect(Rect2(-13, 3, 27, 5), Color("#263c2d99"))
	draw_rect(Rect2(-9, 1, 20, 6), Color("#31482e"))
	draw_rect(Rect2(-2, -1, 3, 8), Color("#554d35"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -5), Vector2(-8, -12), Vector2(-1, -15), Vector2(7, -13), Vector2(12, -8),
		Vector2(14, -2), Vector2(10, 3), Vector2(4, 5), Vector2(-7, 4), Vector2(-13, 0),
	]), Color("#36533a"))
	for tip: Vector2 in [Vector2(-10, -8), Vector2(-5, -13), Vector2(2, -14), Vector2(10, -10), Vector2(12, -5), Vector2(7, -2)]:
		var stem := tip.lerp(Vector2(1, 3), 0.62).round()
		_draw_leaf(stem, tip - stem, Color("#708c51"), Color("#4f6d43"), Color("#8ca25e"))
	for tip: Vector2 in [Vector2(-12, 0), Vector2(-8, 3), Vector2(8, 4), Vector2(13, 0)]:
		_draw_leaf(Vector2(0, -4), tip - Vector2(0, -4), Color("#587741"), Color("#3d5e39"), Color("#6b864e"))
	if not gathered:
		for berry: Vector2 in BERRY_PILES:
			draw_rect(Rect2(berry + Vector2(-1, 1), Vector2(5, 3)), Color("#512f28"))
			draw_rect(Rect2(berry, Vector2(3, 3)), Color("#c26f50"))
			draw_rect(Rect2(berry + Vector2(2, 2), Vector2(2, 2)), Color("#af5542"))
			draw_rect(Rect2(berry, Vector2.ONE), Color("#ffcb8a"))
