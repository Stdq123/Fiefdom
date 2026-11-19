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
@onready var footer: HBoxContainer = %ReadFooter
@onready var page_controls: HBoxContainer = %PageControls
@onready var page_back: Button = %PageBack
@onready var page_forward: Button = %PageForward
@onready var page_count: Label = %PageCount
@onready var scrollbar := speech.get_v_scroll_bar()

signal option_selected(index: int)

var choices: Array[Button] = []

func _ready() -> void:
	InterfaceFont.scale_reading_text(text_label, &"normal_font_size")
	for control: Control in [context_label, %PlotCaption, %TributeDue, %TributeEstimate,
			controls_hint, page_back, page_forward, page_count]:
		InterfaceFont.scale_reading_text(control)
	scrollbar.theme_type_variation = &"HudJournalBar"
	scrollbar.focus_mode = Control.FOCUS_NONE
	scrollbar.changed.connect(_refresh_page_controls)
	scrollbar.value_changed.connect(_refresh_page_controls.unbind(1))
	page_back.pressed.connect(page_speech.bind(-1))
	page_forward.pressed.connect(page_speech.bind(1))
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
	if is_queued_for_deletion():
		return
	var reserved := frame.get_theme_stylebox("panel").get_minimum_size().y
	var separation := body.get_theme_constant("separation")
	var hint_height := controls_hint.get_combined_minimum_size().y
	for child: Control in body.get_children():
		if child.visible and child != speech:
			var height := hint_height if child == footer else child.get_combined_minimum_size().y
			reserved += height + separation
	var available := size.y + frame.offset_bottom - TOP_MARGIN - reserved
	var text_height := text_label.get_combined_minimum_size().y
	var needs_pages := text_height > available
	if page_controls.visible != needs_pages:
		var focused := get_viewport().gui_get_focus_owner()
		page_controls.visible = needs_pages
		_refresh_controls_hint()
		if not needs_pages and (focused == page_back or focused == page_forward) and not choices.is_empty():
			choices.back().grab_focus()
		_link_tab_order()
	if needs_pages:
		available -= maxf(0.0, page_controls.get_combined_minimum_size().y - hint_height)
	speech.custom_minimum_size.y = minf(maxf(0.0, available), text_height)
	_refresh_page_controls()

func _line_height() -> float:
	var font_size := text_label.get_theme_font_size(&"normal_font_size")
	return text_label.get_theme_font(&"normal_font").get_height(font_size) + text_label.get_theme_constant(&"line_separation")

func _page_stride() -> int:
	return maxi(1, floori(scrollbar.page - _line_height()))

func _refresh_page_controls() -> void:
	if not page_controls.visible:
		return
	var end := maxf(0.0, scrollbar.max_value - scrollbar.page)
	var at_end := scrollbar.value >= end - 0.5
	var total := 1 + ceili(end / float(_page_stride()))
	var page := total if at_end else 1 + floori(scrollbar.value / _page_stride())
	page_count.text = "%d / %d" % [page, total]
	var at_start := scrollbar.value < 0.5
	if page_back.disabled == at_start and page_forward.disabled == at_end:
		return
	var focused := get_viewport().gui_get_focus_owner()
	page_back.disabled = at_start
	page_forward.disabled = at_end
	page_back.focus_mode = Control.FOCUS_NONE if at_start else Control.FOCUS_ALL
	page_forward.focus_mode = Control.FOCUS_NONE if at_end else Control.FOCUS_ALL
	_link_tab_order()
	if focused == page_back and at_start and not at_end:
		page_forward.grab_focus()
	elif focused == page_forward and at_end and not at_start:
		page_back.grab_focus()

func page_speech(step: int) -> bool:
	if not is_visible_in_tree() or not scrollbar.visible:
		return false
	var before := speech.scroll_vertical
	speech.scroll_vertical += _page_stride() * step
	if speech.scroll_vertical != before:
		AudioManager.play_menu_cue(AudioManager.MenuCue.PAGE)
	return true

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not scrollbar.visible or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] or not frame.get_global_rect().has_point(event.position):
		return
	var direction := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
	var factor: float = event.factor if event.factor > 0.0 else 1.0
	speech.scroll_vertical += direction * maxi(1, roundi(_line_height() * 3.0 * factor))
	get_viewport().set_input_as_handled()

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
		choice.focus_neighbor_right = next
		choice.focus_neighbor_bottom = next
	_link_tab_order()
	if not choices.is_empty():
		choices.back().grab_focus()
		if GamepadInput.active:
			# The container positions the new buttons before the next frame.
			await get_tree().process_frame
			var focus := get_viewport().gui_get_focus_owner() as Button
			if is_visible_in_tree() and choices.has(focus):
				GamepadInput.snap_pointer_to_focus()

func _link_tab_order() -> void:
	var order: Array[Button] = choices.duplicate()
	for button: Button in [page_back, page_forward]:
		if page_controls.visible and not button.disabled:
			order.append(button)
		var other := page_forward if button == page_back else page_back
		var neighbor := button.get_path_to(button if other.disabled else other)
		button.focus_neighbor_left = neighbor
		button.focus_neighbor_right = neighbor
		button.focus_neighbor_bottom = ^"."
		button.focus_neighbor_top = ^"." if choices.is_empty() else button.get_path_to(choices.back())
	for index in order.size():
		var control := order[index]
		control.focus_previous = control.get_path_to(order[posmod(index - 1, order.size())])
		control.focus_next = control.get_path_to(order[(index + 1) % order.size()])

func move_choice(step: int) -> void:
	if choices.is_empty():
		return
	var selected := choices.find(get_viewport().gui_get_focus_owner() as Button)
	var next: Button = choices.back() if selected < 0 else choices[posmod(selected + step, choices.size())]
	next.grab_focus()

func _refresh_controls_hint() -> void:
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if choices.size() == 1 or page_controls.visible else HORIZONTAL_ALIGNMENT_RIGHT
	if choices.size() == 1:
		controls_hint.text = "%s 继续" % GamepadInput.interact_key()
	elif choices.is_empty():
		controls_hint.text = "B 返回" if GamepadInput.active else "Esc 返回"
	else:
		controls_hint.text = "十字键 选择  ·  A 确认  ·  B 返回" if GamepadInput.active \
			else "方向键 选择  ·  回车 确认  ·  Esc 返回"
	var interaction := Preferences.binding(KeyBindings.INTERACT)
	page_back.text = "上一页  LB" if GamepadInput.active else ("上一页" if interaction == KEY_PAGEUP else "上一页  PgUp")
	page_forward.text = "下一页  RB" if GamepadInput.active else ("下一页" if interaction == KEY_PAGEDOWN else "下一页  PgDn")

func _on_option_pressed(index: int) -> void:
	if is_queued_for_deletion():
		return
	dismiss()
	option_selected.emit(index)

func dismiss() -> void:
	if is_queued_for_deletion():
		return
	hide()
	remove_from_group(&"dialogue_panel")
	queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		dismiss()
	elif event is InputEventKey and event.pressed and not Preferences.matches(event, KeyBindings.INTERACT):
		var key: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		if key in [KEY_PAGEUP, KEY_PAGEDOWN] and page_speech(1 if key == KEY_PAGEDOWN else -1):
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_pressed() and not event.is_echo() and Preferences.matches(event, KeyBindings.INTERACT):
		get_viewport().set_input_as_handled()
		if choices.size() == 1:
			choices[0].pressed.emit()
