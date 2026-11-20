extends PanelContainer

@onready var description: Label = %Description

var walker: Node2D
var target: Node2D
var source_label: Label
var source_color := Color.WHITE
var estate_obstacles := Callable()
var modal_open := false
var settings_open := false
var management_open := false
var font_size := 0

func _ready() -> void:
	InterfaceFont.scale_reading_text(description)
	GameEvents.modal_visibility_changed.connect(func(open: bool): modal_open = open)
	GameEvents.settings_visibility_changed.connect(func(open: bool): settings_open = open)
	GameEvents.management_visibility_changed.connect(func(open: bool): management_open = open)
	set_process(false)

func set_target(actor: Node2D) -> void:
	_restore_label()
	target = actor
	source_label = null
	if is_instance_valid(target):
		for candidate: Label in target.find_children("*", "Label", true, false):
			if candidate.is_in_group(&"interaction_prompt"):
				source_label = candidate
				source_color = candidate.self_modulate
				break
	set_process(source_label != null)
	_refresh()

func _exit_tree() -> void:
	_restore_label()

func _restore_label() -> void:
	if is_instance_valid(source_label):
		source_label.self_modulate = source_color

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(target) or not is_instance_valid(source_label):
		hide()
		set_process(false)
		return
	source_label.self_modulate.a = 0.0
	if (not source_label.is_visible_in_tree() or source_label.text.is_empty() or walker.world_controls_blocked()
		or walker.training_cart.visible or Global.outcome != Global.Outcome.RUNNING
		or modal_open or settings_open or management_open):
		hide()
		return
	var actual_size := description.get_theme_font_size(&"font_size")
	if description.text != source_label.text or actual_size != font_size:
		font_size = actual_size
		_set_description(source_label.text)
	var bounds := get_viewport_rect().grow(-8.0)
	var occupied: Array[Rect2] = []
	if estate_obstacles.is_valid():
		occupied.assign(estate_obstacles.call())
	for overlay: Control in get_tree().get_nodes_in_group(&"interaction_prompt_obstacle"):
		if overlay.is_visible_in_tree():
			occupied.append((overlay.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, overlay.size)).grow(4.0))
	var body: Sprite2D = walker.sprite
	if body.is_visible_in_tree():
		occupied.append((body.get_global_transform_with_canvas() * body.get_rect()).grow(4.0))
	var anchor: Node2D = target.art if target is Retainer else target
	var subject := anchor.get_global_transform_with_canvas() * Rect2(-14, -34, 28, 46)
	occupied.append(subject.grow(4.0))
	var preferred := source_label.get_global_transform_with_canvas() * (source_label.size * 0.5)
	var proposed := Rect2((preferred - size * 0.5).round(), size)
	if bounds.encloses(proposed) and HintPlacement.is_clear(proposed, occupied):
		position = proposed.position
		show()
		return
	var point := HintPlacement.around(subject.get_center(), subject.grow(4.0), size, bounds, occupied)
	visible = point != Vector2.INF
	if visible:
		position = point
	else:
		_restore_label()

func _set_description(text: String) -> void:
	var font := description.get_theme_font(&"font")
	var width := ceilf(font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	description.custom_minimum_size.x = minf(width, 360.0)
	description.size.x = description.custom_minimum_size.x
	description.text = text
	reset_size()
