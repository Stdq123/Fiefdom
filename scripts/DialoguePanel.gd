extends Control

@onready var name_label: Label = $Panel/NameLabel
@onready var context_label: Label = $Panel/ContextLabel
@onready var text_label: RichTextLabel = $Panel/TextLabel
@onready var options_container: HBoxContainer = $Panel/OptionsContainer
@onready var portrait: TextureRect = $Panel/Portrait

signal option_selected(index: int)

func setup(speaker: String, context: String, text: String, options: Array[String], disabled_options: Array[int], appearance: Texture2D) -> void:
	name_label.text = speaker
	context_label.text = context
	text_label.text = text
	portrait.texture = appearance
	var extra := maxf(0.0, text_label.get_content_height() + 6.0 - text_label.size.y)
	$Panel.offset_top -= extra
	text_label.offset_bottom += extra
	$Panel/PortraitFrame.position.y += extra * 0.5
	portrait.position.y += extra * 0.5
	for i in options.size():
		var btn := Button.new()
		btn.text = options[i]
		btn.custom_minimum_size = Vector2(84, 38)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.disabled = i in disabled_options
		btn.pressed.connect(_on_option_pressed.bind(i))
		options_container.add_child(btn)

func _on_option_pressed(index: int) -> void:
	if is_queued_for_deletion():
		return
	queue_free()
	option_selected.emit(index)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
