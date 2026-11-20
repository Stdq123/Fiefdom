extends Control

signal choice_selected(choice: Global.TaxReformChoice)
signal dismissed

const IMPLEMENTS := preload("res://scripts/CouncilImplements.gd")
const PANEL_FOCUS := preload("res://scripts/PanelFocus.gd")
const SHEET_MARGIN := 20.0

@onready var sheet: PanelContainer = %Council
@onready var content: VBoxContainer = %Content
@onready var title_label: Label = %Title
@onready var speaker_label: Label = %Speaker
@onready var text_label: Label = %Greeting
@onready var ledger: Label = %Ledger
@onready var choice_headings: MarginContainer = %ChoiceHeadings
@onready var choice_buttons: HBoxContainer = %ChoiceButtons
@onready var scroll: ScrollContainer = %CompareScroll
@onready var choices_container: HBoxContainer = %Choices
@onready var selection_label: Label = %Selection
@onready var confirm_button: Button = %Confirm
@onready var leave_button: Button = %Leave

var current_event_data: Dictionary = {}
var option_buttons: Dictionary[int, Button] = {}
var cards: Dictionary[int, PanelContainer] = {}
var selected_choice := Global.TaxReformChoice.NONE
var card_style: StyleBoxTexture
var selected_style: StyleBoxTexture

func _ready() -> void:
	add_to_group("gamepad_directional_menu")
	for label: Label in [text_label, ledger, selection_label]:
		InterfaceFont.scale_reading_text(label)
	var bar := scroll.get_v_scroll_bar()
	bar.theme_type_variation = &"HudJournalBar"
	bar.focus_mode = FOCUS_ALL
	bar.custom_step = 48.0
	bar.visibility_changed.connect(_link_focus, CONNECT_DEFERRED)
	choices_container.minimum_size_changed.connect(_fit_comparison, CONNECT_DEFERRED)
	content.minimum_size_changed.connect(_fit_comparison, CONNECT_DEFERRED)
	get_viewport().size_changed.connect(_fit_comparison)
	choices_container.resized.connect(_align_columns)
	card_style = get_theme_stylebox(&"panel", &"PanelContainer").duplicate() as StyleBoxTexture
	card_style.content_margin_left = 13
	card_style.content_margin_right = 13
	card_style.content_margin_top = 10
	card_style.content_margin_bottom = 12
	selected_style = card_style.duplicate() as StyleBoxTexture
	selected_style.modulate_color = Color("#ffe5af")
	confirm_button.pressed.connect(_confirm)
	leave_button.pressed.connect(_leave)
	GamepadInput.changed.connect(_refresh_selection_prompt)

func setup(event_data: Dictionary) -> void:
	current_event_data = event_data
	title_label.text = event_data["title"]
	speaker_label.text = event_data["speaker"]
	text_label.text = event_data["text"]
	ledger.text = event_data["ledger"]
	for row: HBoxContainer in [choice_buttons, choices_container]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	option_buttons.clear()
	cards.clear()
	for choice: Dictionary in event_data["choices"]:
		_add_choice(choice)
	_select(Global.TaxReformChoice.NONE)
	option_buttons.values().front().grab_focus()
	scroll.scroll_vertical = 0
	_fit_comparison.call_deferred()

func _fit_comparison() -> void:
	var chrome := sheet.get_theme_stylebox("panel").get_minimum_size().y
	var separation := content.get_theme_constant("separation")
	for child: Control in content.get_children():
		if child != scroll and child.visible:
			chrome += child.get_combined_minimum_size().y + separation
	var available := maxf(0.0, get_viewport_rect().size.y - SHEET_MARGIN * 2.0 - chrome)
	scroll.custom_minimum_size.y = minf(choices_container.get_combined_minimum_size().y, available)

func _align_columns() -> void:
	var margin := maxi(0, roundi(scroll.size.x - choices_container.size.x))
	choice_headings.add_theme_constant_override("margin_right", margin)

func _add_choice(data: Dictionary) -> void:
	var choice: Global.TaxReformChoice = data["choice_type"]
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", card_style)
	choices_container.add_child(card)
	cards[choice] = card

	var button := Button.new()
	button.text = data["text"]
	button.theme_type_variation = &"HudButton"
	button.icon = IMPLEMENTS.plate(choice)
	button.add_theme_constant_override(&"icon_max_width", int(IMPLEMENTS.PLATE_SIZE.x))
	button.add_theme_constant_override(&"h_separation", 10)
	button.add_theme_font_size_override(&"font_size", 20)
	button.custom_minimum_size.y = 77
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.toggle_mode = true
	button.pressed.connect(_select.bind(choice))
	choice_buttons.add_child(button)
	option_buttons[choice] = button

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	card.add_child(stack)
	_add_section(stack, "田赋", data["levy"], 52.0)
	_add_section(stack, data["heading"], data["detail"])
	_add_section(stack, "这批收成", data["harvest"])
	_add_section(stack, "门客", data["household"], 52.0)

func _add_section(parent: VBoxContainer, heading: String, detail: String, minimum_height := 0.0) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	parent.add_child(section)
	if not heading.is_empty():
		var title := Label.new()
		title.text = heading
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", Color("#66361f"))
		section.add_child(title)
		InterfaceFont.scale_reading_text(title)
	var body := Label.new()
	body.text = detail
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.y = minimum_height
	section.add_child(body)
	InterfaceFont.scale_reading_text(body)

func _select(choice: Global.TaxReformChoice) -> void:
	selected_choice = choice
	for id in option_buttons:
		option_buttons[id].set_pressed_no_signal(id == choice)
		cards[id].add_theme_stylebox_override("panel", selected_style if id == choice else card_style)
	confirm_button.disabled = choice == Global.TaxReformChoice.NONE
	confirm_button.text = "延期研究" if choice == Global.TaxReformChoice.DELAYED else "定案"
	_refresh_selection_prompt()
	_link_focus()

func _refresh_selection_prompt() -> void:
	var back := GamepadInput.back_key()
	if selected_choice == Global.TaxReformChoice.NONE:
		selection_label.text = "选定方案后可定案  ·  %s 稍后再议" % back
	else:
		selection_label.text = "当前选择 · %s  ·  %s 清除选择" % [option_buttons[selected_choice].text, back]

func _link_focus() -> void:
	if option_buttons.is_empty():
		return
	var options: Array[Button] = []
	options.assign(option_buttons.values())
	var bar := scroll.get_v_scroll_bar()
	var lower: Control = bar if bar.visible else confirm_button
	var tabs: Array[Control] = [leave_button]
	tabs.append_array(options)
	if bar.visible:
		tabs.append(bar)
	if not confirm_button.disabled:
		tabs.append(confirm_button)
	for index in tabs.size():
		var control := tabs[index]
		control.focus_previous = control.get_path_to(tabs[posmod(index - 1, tabs.size())])
		control.focus_next = control.get_path_to(tabs[(index + 1) % tabs.size()])
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			control.set_focus_neighbor(side, ^".")
	for index in options.size():
		var option := options[index]
		option.focus_neighbor_left = option.get_path_to(options[maxi(0, index - 1)])
		option.focus_neighbor_right = option.get_path_to(options[mini(index + 1, options.size() - 1)])
		option.focus_neighbor_top = option.get_path_to(leave_button)
		if bar.visible or not confirm_button.disabled:
			option.focus_neighbor_bottom = option.get_path_to(lower)
	var current: Button = option_buttons.get(selected_choice, options[0])
	leave_button.focus_neighbor_bottom = leave_button.get_path_to(current)
	confirm_button.focus_neighbor_top = confirm_button.get_path_to(current)
	if bar.visible:
		bar.focus_neighbor_left = bar.get_path_to(current)
		bar.focus_neighbor_right = bar.get_path_to(current if confirm_button.disabled else confirm_button)
		confirm_button.focus_neighbor_left = confirm_button.get_path_to(bar)

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventAction:
		var focus := PANEL_FOCUS.input_owner(sheet)
		if focus:
			PANEL_FOCUS.keep_navigation_inside(sheet, focus, event)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		var bar := scroll.get_v_scroll_bar()
		if bar.visible:
			scroll.scroll_vertical += roundi(bar.page * (1.0 if event.keycode == KEY_PAGEDOWN else -1.0))
			get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if selected_choice != Global.TaxReformChoice.NONE:
		_select(Global.TaxReformChoice.NONE)
		option_buttons.values().front().grab_focus()
		GamepadInput.snap_pointer_to_focus.call_deferred()
	else:
		_leave()

func _leave() -> void:
	queue_free()
	dismissed.emit()

func _confirm() -> void:
	if confirm_button.disabled or is_queued_for_deletion():
		return
	queue_free()
	choice_selected.emit(selected_choice)
