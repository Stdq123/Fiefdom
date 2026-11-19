extends Control

const SettingsPanelScript := preload("res://scripts/SettingsPanel.gd")
const SAVE_ARCHIVE := preload("res://scenes/SaveArchive.tscn")
const HUD_THEME := preload("res://resources/estate_hud_theme.tres")

@onready var menu: VBoxContainer = $Center/Menu
@onready var new_button: Button = $Center/Menu/NewGame
@onready var continue_button: Button = $Center/Menu/Continue
@onready var archive_button: Button = $Center/Menu/SaveArchive
@onready var status: Label = $Center/Menu/Status
@onready var new_confirmation: ConfirmationDialog = $NewConfirmation
@onready var new_name: LineEdit = $NewConfirmation/Form/EstateName

var settings_panel: Panel
var _resume_scene := ""

func _ready() -> void:
	$Version.text = "Windows · %s" % ProjectSettings.get_setting("application/config/version")
	new_button.pressed.connect(_on_new_requested)
	continue_button.pressed.connect(_continue_game)
	archive_button.pressed.connect(_open_archive)
	$Center/Menu/Settings.pressed.connect(_open_settings)
	$Center/Menu/Exit.pressed.connect(func(): get_tree().quit())
	new_confirmation.confirmed.connect(_start_game)
	new_confirmation.canceled.connect(AudioManager.play_menu_cue.bind(AudioManager.MenuCue.CLOSE))
	new_confirmation.register_text_enter(new_name)
	new_confirmation.get_cancel_button().text = "取消"
	for button in [new_confirmation.get_ok_button(), new_confirmation.get_cancel_button()]:
		button.theme = HUD_THEME
		button.theme_type_variation = &"HudPrimary" if button == new_confirmation.get_ok_button() else &"HudButton"
		button.custom_minimum_size = Vector2(124, 40)
	new_confirmation.visibility_changed.connect(_update_new_visibility)
	_refresh_menu()
	print("Fiefdom title ready")

func _refresh_menu() -> void:
	var latest := Global.latest_saved_game()
	var can_resume := not latest.is_empty()
	_resume_scene = latest.get("scene", "")
	continue_button.visible = can_resume
	continue_button.disabled = not can_resume
	archive_button.visible = Global.has_saved_game()
	if can_resume:
		continue_button.text = Global.saved_game_action(latest)
		var route := Global.saved_game_route(latest)
		status.text = latest.campaign_name + "\n" + Global.saved_game_caption(latest)
		if not route.is_empty():
			status.text += "\n" + route
	elif archive_button.visible:
		status.text = "存档格式有误，可从「选择存档」查看。"
	else:
		status.text = "还没有存档"
	new_button.theme_type_variation = &"HudButton" if can_resume else &"HudPrimary"
	continue_button.theme_type_variation = &"HudPrimary" if can_resume else &"HudButton"
	var primary := continue_button if can_resume else new_button
	primary.grab_focus()

func _on_new_requested() -> void:
	if Global.has_saved_game():
		new_name.text = Global.next_campaign_name()
		new_confirmation.popup_centered()
		AudioManager.play_menu_cue(AudioManager.MenuCue.OPEN)
		new_name.grab_focus()
		new_name.select_all()
	else:
		_start_game()

func _start_game() -> void:
	if not await MapTravel.prepare_session(Global.ESTATE_SCENE, "正在打开封地"):
		return
	var result := Global.start_new_game(new_name.text)
	if result != OK:
		status.text = "打开封地失败（%s）" % error_string(result)

func _continue_game() -> void:
	if not _resume_scene.is_empty() and not await MapTravel.prepare_session(_resume_scene, "正在读取存档"):
		return
	var result := Global.load_latest_game()
	if result == OK:
		return
	_refresh_menu()
	if result not in [ERR_FILE_NOT_FOUND, ERR_FILE_CORRUPT]:
		status.text = "继续失败（%s）" % error_string(result)

func _update_new_visibility() -> void:
	$ModalShade.visible = new_confirmation.visible
	menu.visible = not new_confirmation.visible
	if menu.visible:
		new_button.grab_focus()

func _open_archive() -> void:
	var archive := SAVE_ARCHIVE.instantiate()
	add_child(archive)
	menu.hide()
	archive.tree_exiting.connect(func():
		if is_inside_tree() and get_tree().current_scene == self:
			menu.show()
			archive_button.grab_focus()
	)

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
	$ModalShade.visible = settings_panel.visible
	if menu.visible:
		$Center/Menu/Settings.grab_focus()
