extends Control

@onready var name_label: Label = %NameLabel
@onready var context_label: Label = %ContextLabel
@onready var text_label: RichTextLabel = %TextLabel
@onready var options_container: HFlowContainer = %OptionsContainer
@onready var portrait: TextureRect = %Portrait
@onready var controls_hint: Label = %ControlsHint

signal option_selected(index: int)

var choices: Array[Button] = []

func setup(speaker: String, context: String, text: String, options: Array[String], disabled_options: Array[int], appearance: Texture2D) -> void:
	name_label.text = speaker
	context_label.text = context
	context_label.visible = not context.is_empty()
	text_label.text = text
	portrait.texture = appearance
	%PortraitFrame.visible = appearance != null
	for i in options.size():
		var btn := Button.new()
		btn.text = options[i]
		btn.custom_minimum_size = Vector2(84, 38)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.disabled = i in disabled_options
		btn.pressed.connect(_on_option_pressed.bind(i))
		options_container.add_child(btn)
		if btn.disabled:
			btn.focus_mode = Control.FOCUS_NONE
		else:
			choices.append(btn)
			btn.mouse_entered.connect(func():
				if GamepadInput.active:
					btn.grab_focus()
			)
	_link_choices()
	GamepadInput.changed.connect(_refresh_controls_hint)
	Preferences.bindings_changed.connect(_refresh_controls_hint)
	_refresh_controls_hint()

func _link_choices() -> void:
	for index in choices.size():
		var choice := choices[index]
		var previous := choice.get_path_to(choices[posmod(index - 1, choices.size())])
		var next := choice.get_path_to(choices[(index + 1) % choices.size()])
		choice.focus_neighbor_left = previous
		choice.focus_neighbor_top = previous
		choice.focus_previous = previous
		choice.focus_neighbor_right = next
		choice.focus_neighbor_bottom = next
		choice.focus_next = next
	if not choices.is_empty():
		choices.back().grab_focus()
		GamepadInput.snap_pointer_to_focus.call_deferred()

func move_choice(step: int) -> void:
	if choices.is_empty():
		return
	var selected := choices.find(get_viewport().gui_get_focus_owner())
	var next: Button = choices.back() if selected < 0 else choices[posmod(selected + step, choices.size())]
	next.grab_focus()

func _refresh_controls_hint() -> void:
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if choices.size() == 1 else HORIZONTAL_ALIGNMENT_RIGHT
	if choices.size() == 1:
		controls_hint.text = "%s 继续" % GamepadInput.interact_key()
	else:
		controls_hint.text = "十字键 选择  ·  A 确认  ·  B 返回" if GamepadInput.active \
			else "方向键 选择  ·  回车 确认  ·  Esc 返回"

func _on_option_pressed(index: int) -> void:
	if is_queued_for_deletion():
		return
	queue_free()
	option_selected.emit(index)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and Preferences.matches(event, KeyBindings.INTERACT):
		get_viewport().set_input_as_handled()
		if choices.size() == 1:
			choices[0].pressed.emit()
