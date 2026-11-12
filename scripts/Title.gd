extends Control

const SettingsPanelScript := preload("res://scripts/SettingsPanel.gd")
const SAVE_ARCHIVE := preload("res://scenes/SaveArchive.tscn")

@export var primary_action_style: StyleBox

@onready var menu: VBoxContainer = $Center/Menu
@onready var new_button: Button = $Center/Menu/NewGame
@onready var continue_button: Button = $Center/Menu/Continue
@onready var archive_button: Button = $Center/Menu/SaveArchive
@onready var status: Label = $Center/Menu/Status
@onready var new_confirmation: ConfirmationDialog = $NewConfirmation
@onready var new_name: LineEdit = $NewConfirmation/Form/EstateName

var settings_panel: Panel

func _ready() -> void:
	$Version.text = "Windows · %s" % ProjectSettings.get_setting("application/config/version")
	new_button.pressed.connect(_on_new_requested)
	continue_button.pressed.connect(_continue_game)
	archive_button.pressed.connect(func(): add_child(SAVE_ARCHIVE.instantiate()))
	$Center/Menu/Settings.pressed.connect(_open_settings)
	$Center/Menu/Exit.pressed.connect(func(): get_tree().quit())
	new_confirmation.confirmed.connect(_start_game)
	new_confirmation.register_text_enter(new_name)
	new_confirmation.get_cancel_button().text = "取消"
	_refresh_menu()
	print("Fiefdom title ready")

func _refresh_menu() -> void:
	var latest := Global.latest_saved_game()
	var can_resume := not latest.is_empty()
	continue_button.visible = can_resume
	continue_button.disabled = not can_resume
	archive_button.visible = Global.has_saved_game()
	status.text = latest["campaign_name"] + "\n" + Global.saved_game_caption(latest) if can_resume else "还没有存档"
	if archive_button.visible and not can_resume:
		status.text = "存档格式有误，可从「选择存档」查看。"
	new_button.remove_theme_stylebox_override("normal")
	continue_button.remove_theme_stylebox_override("normal")
	var primary := continue_button if can_resume else new_button
	primary.add_theme_stylebox_override("normal", primary_action_style)
	primary.grab_focus()

func _on_new_requested() -> void:
	if Global.has_saved_game():
		new_name.text = Global.next_campaign_name()
		new_confirmation.popup_centered()
		new_name.grab_focus()
		new_name.select_all()
	else:
		_start_game()

func _start_game() -> void:
	var result := Global.start_new_game(new_name.text)
	if result != OK:
		status.text = "打开封地失败（%s）" % error_string(result)

func _continue_game() -> void:
	var result := Global.load_latest_game()
	if result == OK:
		return
	_refresh_menu()
	if result not in [ERR_FILE_NOT_FOUND, ERR_FILE_CORRUPT]:
		status.text = "继续失败（%s）" % error_string(result)

func _open_settings() -> void:
	if not is_instance_valid(settings_panel):
		settings_panel = SettingsPanelScript.new()
		settings_panel.session_controls = false
		settings_panel.hide()
		add_child(settings_panel)
		settings_panel.visibility_changed.connect(_update_settings_visibility)
	settings_panel.show()

func _update_settings_visibility() -> void:
	menu.visible = not settings_panel.visible
	if menu.visible:
		$Center/Menu/Settings.grab_focus()
