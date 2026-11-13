extends Control

signal choice_selected(choice: Global.TaxReformChoice)
signal dismissed

@onready var sheet: PanelContainer = %Council
@onready var title_label: Label = %Title
@onready var speaker_label: Label = %Speaker
@onready var text_label: Label = %Greeting
@onready var ledger: Label = %Ledger
@onready var choices_container: HBoxContainer = %Choices
@onready var selection_label: Label = %Selection
@onready var confirm_button: Button = %Confirm
@onready var leave_button: Button = %Leave

var current_event_data: Dictionary = {}
var option_buttons: Dictionary[int, Button] = {}
var cards: Dictionary[int, PanelContainer] = {}
var selected_choice := Global.TaxReformChoice.NONE
var card_style := StyleBoxFlat.new()
var selected_style: StyleBoxFlat

func _ready() -> void:
	confirm_button.pressed.connect(_confirm)
	leave_button.pressed.connect(_leave)

func setup(event_data: Dictionary) -> void:
	current_event_data = event_data
	title_label.text = event_data["title"]
	speaker_label.text = event_data["speaker"]
	text_label.text = event_data["text"]
	ledger.text = event_data["ledger"]
	card_style.bg_color = Color("#27372c")
	card_style.border_color = Color("#5d694f")
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(4)
	card_style.content_margin_left = 13
	card_style.content_margin_right = 13
	card_style.content_margin_top = 12
	card_style.content_margin_bottom = 12
	selected_style = card_style.duplicate() as StyleBoxFlat
	selected_style.bg_color = Color("#344437")
	selected_style.border_color = Color("#d3ba79")
	selected_style.set_border_width_all(2)

	for child in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()
	option_buttons.clear()
	cards.clear()
	for choice: Dictionary in event_data["choices"]:
		_add_choice(choice)
	_select(Global.TaxReformChoice.NONE)
	option_buttons.values().front().grab_focus()

func _add_choice(data: Dictionary) -> void:
	var choice: Global.TaxReformChoice = data["choice_type"]
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", card_style)
	choices_container.add_child(card)
	cards[choice] = card

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	card.add_child(stack)
	var button := Button.new()
	button.text = data["text"]
	button.custom_minimum_size.y = 38
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.toggle_mode = true
	button.pressed.connect(_select.bind(choice))
	stack.add_child(button)
	option_buttons[choice] = button
	_add_section(stack, "", data["levy"], 52.0)
	_add_section(stack, "这批收成", data["harvest"])
	_add_section(stack, "", data["household"], 52.0)
	_add_section(stack, data["heading"], data["detail"])

func _add_section(parent: VBoxContainer, heading: String, detail: String, minimum_height := 0.0) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	parent.add_child(section)
	if not heading.is_empty():
		var title := Label.new()
		title.text = heading
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", Color("#d8c48e"))
		section.add_child(title)
	var body := Label.new()
	body.text = detail
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.y = minimum_height
	section.add_child(body)

func _select(choice: Global.TaxReformChoice) -> void:
	selected_choice = choice
	for id in option_buttons:
		option_buttons[id].set_pressed_no_signal(id == choice)
		cards[id].add_theme_stylebox_override("panel", selected_style if id == choice else card_style)
	confirm_button.disabled = choice == Global.TaxReformChoice.NONE
	selection_label.text = ("选定方案后可定案。" if confirm_button.disabled else
		"当前选择 · " + option_buttons[choice].text)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if selected_choice != Global.TaxReformChoice.NONE:
		_select(Global.TaxReformChoice.NONE)
		option_buttons.values().front().grab_focus()
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
