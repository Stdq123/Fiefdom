extends ColorRect

signal restore_requested(checkpoint: Dictionary)
signal title_requested

const PANEL_FOCUS := preload("res://scripts/PanelFocus.gd")

@onready var estate_name: Label = %EstateName
@onready var date: Label = %DefeatDate
@onready var seal: Label = %DefeatSeal
@onready var heading: Label = %DefeatHeading
@onready var cause: Label = %DefeatCause
@onready var checkpoint: Label = %Checkpoint
@onready var status: Label = %ReadStatus
@onready var restore_button: Button = %RestoreCampaign
@onready var title_button: Button = %ReturnToTitle

var _restore_checkpoint := {}

func _ready() -> void:
	add_to_group("gamepad_directional_menu")
	for control: Control in [estate_name, date, cause, %CheckpointHeading, checkpoint, status, restore_button, title_button]:
		InterfaceFont.scale_reading_text(control)
	restore_button.pressed.connect(func(): restore_requested.emit(_restore_checkpoint))
	title_button.pressed.connect(title_requested.emit)
	GamepadInput.changed.connect(_refresh_back_hint)
	_refresh_back_hint()

func present(outcome: Global.Outcome) -> void:
	var combat := outcome == Global.Outcome.DEFEAT_COMBAT
	estate_name.text = Global.campaign_name
	date.text = "第 %d 天 · %s · %s" % [Global.current_day, Global.get_current_solar_term(), Global.day_watch_label()]
	seal.text = "危" if combat else "黜"
	heading.text = "战败" if combat else "褫夺封地"
	cause.text = ("气血耗尽，封地经营暂告一段落。" if combat else
		"久未纳贡，声望跌过底线，国君已收回封地。")
	refresh_restore()

func refresh_restore() -> void:
	_restore_checkpoint = Global.latest_saved_game(true)
	restore_button.disabled = _restore_checkpoint.is_empty()
	title_button.theme_type_variation = &"HudPrimary" if restore_button.disabled else &"HudButton"
	checkpoint.text = ("本局没有可恢复的存档。" if restore_button.disabled else
		Global.saved_game_caption(_restore_checkpoint))
	var focus := title_button if restore_button.disabled else restore_button
	_focus_action(focus)

func _focus_action(button: Button) -> void:
	button.grab_focus()
	if GamepadInput.active:
		var tree := get_tree()
		await tree.process_frame
		await tree.process_frame
		if is_inside_tree() and PANEL_FOCUS.input_owner(self) == button:
			GamepadInput.snap_pointer_to_focus()

func _refresh_back_hint() -> void:
	title_button.text = "返回标题  %s" % GamepadInput.back_key()

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventAction:
		var focus := PANEL_FOCUS.input_owner(self)
		if focus:
			PANEL_FOCUS.keep_navigation_inside(self, focus, event)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and PANEL_FOCUS.input_owner(self):
		get_viewport().set_input_as_handled()
		title_requested.emit()
