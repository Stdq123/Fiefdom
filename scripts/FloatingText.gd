extends Node2D
class_name FloatingText

const NOTE := preload("res://scenes/FloatingText.tscn")
const HUD_THEME := preload("res://resources/estate_hud_theme.tres")
const UNLIT := preload("res://resources/world_hint_material.tres")
const FADE_SECONDS := 0.30
const FIELD_HOLD := 1.1
const DAMAGE_HOLD := 0.65

class Message:
	var label: Label
	var anchor: Vector2
	var above: bool
	var age := 0.0
	var offset := Vector2.INF

	func _init(view: Label, point: Vector2, above_anchor: bool) -> void:
		label = view
		anchor = point
		above = above_anchor

@onready var walker := get_parent().get_node_or_null("Player") as Player
var messages: Array[Message] = []
var open_panels: Dictionary[StringName, bool] = {}

static func present(world: Node2D, at: Vector2, text: String, ink: Color, above := false) -> void:
	if text.is_empty():
		return
	var overlay := world.get_node_or_null("FloatingText") as FloatingText
	if not overlay:
		overlay = FloatingText.new()
		overlay.name = "FloatingText"
		world.add_child(overlay)
	overlay._add_note(at, text, ink, above)

func _ready() -> void:
	z_index = 52
	process_priority = 15
	material = UNLIT
	set_process(false)
	GameEvents.modal_visibility_changed.connect(_panel_changed.bind(&"modal"))
	GameEvents.settings_visibility_changed.connect(_panel_changed.bind(&"settings"))
	GameEvents.management_visibility_changed.connect(_panel_changed.bind(&"management"))
	GameEvents.day_advanced.connect(_clear.unbind(1))
	Preferences.reading_size_changed.connect(_remeasure)

func _add_note(at: Vector2, text: String, ink: Color, above: bool) -> void:
	if not above:
		for entry in messages:
			if not entry.above and entry.anchor == at and entry.label.text == text and entry.label.get_theme_color(&"font_color") == ink:
				entry.age = 0.0
				entry.label.modulate.a = 1.0
				return
	var label := NOTE.instantiate() as Label
	label.text = text
	label.use_parent_material = true
	label.add_theme_color_override(&"font_color", ink)
	if not above:
		label.add_theme_stylebox_override(&"normal", HUD_THEME.get_stylebox(&"panel", &"HudRail"))
	label.hide()
	add_child(label)
	var entry := Message.new(label, at, above)
	messages.append(entry)
	_measure(entry)
	set_process(true)

func _panel_changed(open: bool, panel: StringName) -> void:
	if open:
		open_panels[panel] = true
		hide()
	else:
		open_panels.erase(panel)

func _clear() -> void:
	for entry in messages:
		entry.label.queue_free()
	messages.clear()
	hide()
	set_process(false)

func _remeasure() -> void:
	for entry in messages:
		_measure(entry)
		entry.offset = Vector2.INF

func _measure(entry: Message) -> void:
	var label := entry.label
	var font_size := Preferences.reading_font_size(16 if entry.above else 15)
	label.add_theme_font_size_override(&"font_size", font_size)
	var font := label.get_theme_font(&"font")
	var padding := label.get_theme_stylebox(&"normal").get_minimum_size().x
	var text := label.text
	var width := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var fitted_width := minf(360.0, ceilf(width + padding) + 1.0)
	# Set the wrap width before shaping the text so the previous width cannot force a tall label.
	label.text = ""
	label.custom_minimum_size.x = fitted_width
	label.size = Vector2(fitted_width, 0.0)
	label.text = text
	label.size.y = label.get_combined_minimum_size().y

func _process(delta: float) -> void:
	if not open_panels.is_empty() or MapTravel.active or (is_instance_valid(walker) and walker.combat_paused()):
		hide()
		return
	if messages.is_empty():
		set_process(false)
		return
	show()
	var canvas := get_canvas_transform()
	# Keep the labels at a fixed screen size while their anchors follow the map.
	global_transform = canvas.affine_inverse()
	var bounds := get_viewport_rect().grow(-10.0)
	var occupied := _obstacles()
	for entry: Message in messages.duplicate():
		entry.age += delta
		var hold := DAMAGE_HOLD if entry.above else FIELD_HOLD
		var lifetime := hold + FADE_SECONDS
		if entry.age >= lifetime:
			entry.label.hide()
			entry.label.queue_free()
			messages.erase(entry)
			continue
		var anchor := canvas * entry.anchor - Vector2(0, 8.0 * entry.age / lifetime)
		var at := _position_note(entry, anchor, bounds, occupied) if bounds.grow(30.0).has_point(anchor) else Vector2.INF
		entry.label.visible = at != Vector2.INF
		if entry.label.visible:
			entry.label.position = at
			entry.label.modulate.a = 1.0 - smoothstep(hold, lifetime, entry.age)
			occupied.append(Rect2(at, entry.label.size).grow(3.0))

func _position_note(entry: Message, anchor: Vector2, bounds: Rect2, occupied: Array[Rect2]) -> Vector2:
	var size := entry.label.size
	var subject := Rect2(anchor - Vector2(5, 4), Vector2(10, 8))
	var preferred := Vector2(-size.x * 0.5, -size.y - 4.0 if entry.above else 4.0)
	var offset := preferred if entry.offset == Vector2.INF else entry.offset
	var at := (anchor + offset).round()
	var box := Rect2(at, size)
	if bounds.encloses(box) and HintPlacement.is_clear(box, occupied):
		entry.offset = offset
		return at
	at = HintPlacement.around(anchor, subject, size, bounds, occupied, not entry.above)
	if at != Vector2.INF:
		entry.offset = at - anchor
	return at

func _obstacles() -> Array[Rect2]:
	var occupied: Array[Rect2] = []
	if is_instance_valid(walker):
		var prompt = walker.interaction_prompt
		if prompt.estate_obstacles.is_valid():
			for area: Rect2 in prompt.estate_obstacles.call():
				occupied.append(area.grow(1.0))
		if prompt.is_visible_in_tree():
			occupied.append((prompt.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, prompt.size)).grow(3.0))
		if walker.sprite.is_visible_in_tree():
			occupied.append((walker.sprite.get_global_transform_with_canvas() * walker.sprite.get_rect()).grow(3.0))
	for group: StringName in [&"interaction_prompt_obstacle", &"world_feedback_obstacle"]:
		for node: Control in get_tree().get_nodes_in_group(group):
			if node.is_visible_in_tree():
				occupied.append((node.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, node.size)).grow(3.0))
	return occupied
