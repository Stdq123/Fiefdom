extends Control

const TRIBUTE_INK := Color("#33432d")
const TRIBUTE_ALERT := Color("#7b3522")
const TOP_MARGIN := 23.0

@onready var frame: PanelContainer = $Panel
@onready var body: VBoxContainer = $Panel/Content/Body
@onready var name_label: Label = %NameLabel
@onready var context_label: Label = %ContextLabel
@onready var speech: ScrollContainer = %Speech
@onready var text_label: RichTextLabel = %TextLabel
@onready var options_container: HFlowContainer = %OptionsContainer
@onready var portrait: TextureRect = %Portrait
@onready var controls_hint: Label = %ControlsHint

signal option_selected(index: int)

var choices: Array[Button] = []

func _ready() -> void:
	InterfaceFont.scale_reading_text(text_label, &"normal_font_size")
	for label: Label in [context_label, %PlotCaption, %TributeDue, %TributeEstimate]:
		InterfaceFont.scale_reading_text(label)
	var scrollbar := speech.get_v_scroll_bar()
	scrollbar.theme_type_variation = &"HudJournalBar"
	scrollbar.visibility_changed.connect(_refresh_controls_hint)
	body.minimum_size_changed.connect(_fit_speech, CONNECT_DEFERRED)
	text_label.minimum_size_changed.connect(_fit_speech, CONNECT_DEFERRED)
	resized.connect(_fit_speech, CONNECT_DEFERRED)

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
		InterfaceFont.scale_reading_text(btn)
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
	_fit_speech.call_deferred()

func _fit_speech() -> void:
	var reserved := frame.get_theme_stylebox("panel").get_minimum_size().y
	var separation := body.get_theme_constant("separation")
	for child: Control in body.get_children():
		if child.visible and child != speech:
			reserved += child.get_combined_minimum_size().y + separation
	var available := maxf(0.0, size.y + frame.offset_bottom - TOP_MARGIN - reserved)
	speech.custom_minimum_size.y = minf(available, text_label.get_combined_minimum_size().y)

func page_speech(step: int) -> bool:
	var bar := speech.get_v_scroll_bar()
	if not bar.visible:
		return false
	var page := maxf(1.0, bar.page - text_label.get_theme_font_size(&"normal_font_size"))
	speech.scroll_vertical += roundi(page * step)
	return true

func show_tribute_plot(field: Dictionary) -> void:
	var plot := TributePlotPicture.new()
	portrait.add_child(plot)
	plot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plot.show_plot(field)
	%PortraitFrame.show()
	%PlotCaption.text = "井田 %d · %s" % [field.field, "待播" if field.status < 0 else field.crop]
	%PlotCaption.show()
	_show_tribute_timing(field)

func _show_tribute_timing(field: Dictionary) -> void:
	var due := Global.tribute_deadline()
	%TributeTiming.visible = due > 0
	if due <= 0:
		return
	var overdue := Global.tribute_overdue()
	var tonight := due == Global.current_day
	var deadline: Label = %TributeDue
	deadline.text = "首贡期限 · 今夜到期" if tonight else "首贡期限 · 第 %d 天过夜前" % due
	if overdue:
		deadline.text = "首贡已逾期"
	deadline.add_theme_color_override("font_color", TRIBUTE_ALERT if tonight or overdue else TRIBUTE_INK)

	var estimate: Label = %TributeEstimate
	estimate.visible = field.status not in [Global.NightGrowth.READY, Global.NightGrowth.BLOCKED]
	if estimate.visible:
		var start := "今日播种并逐夜供水" if field.status < 0 else "逐夜供水"
		var late: bool = not overdue and field.ready_day > due
		estimate.text = "%s · 最早第 %d 天可收" % [start, field.ready_day]
		if late:
			estimate.text += " · 赶不上期限"
		estimate.add_theme_color_override("font_color", TRIBUTE_ALERT if late else TRIBUTE_INK)

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
		if GamepadInput.active:
			# The container positions the new buttons before the next frame.
			await get_tree().process_frame
			if choices.has(get_viewport().gui_get_focus_owner()):
				GamepadInput.snap_pointer_to_focus()

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
	if speech.get_v_scroll_bar().visible:
		controls_hint.text += "  ·  LB/RB 翻页" if GamepadInput.active else "  ·  滚轮 / PgUp PgDn 翻页"

func _on_option_pressed(index: int) -> void:
	if is_queued_for_deletion():
		return
	queue_free()
	option_selected.emit(index)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN] \
			and not Preferences.matches(event, KeyBindings.INTERACT):
		if page_speech(1 if event.keycode == KEY_PAGEDOWN else -1):
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and Preferences.matches(event, KeyBindings.INTERACT):
		get_viewport().set_input_as_handled()
		if choices.size() == 1:
			choices[0].pressed.emit()
