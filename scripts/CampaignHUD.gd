extends CanvasLayer

const GAME_THEME := preload("res://resources/game_theme.tres")
const HUD_THEME := preload("res://resources/estate_hud_theme.tres")
const ESTATE_ENDING := preload("res://scenes/EstateEnding.tscn")
const TITLE_CONFIRMATION := preload("res://scripts/ReturnToTitleDialog.gd")
const VITALS := preload("res://scenes/HUDVitals.tscn")
const TRAVEL_HEADING := preload("res://scenes/TravelHeading.tscn")
const TRAVEL_ROUTE_SIGN := preload("res://scenes/TravelRouteSign.tscn")
const BACKPACK := preload("res://scenes/Backpack.tscn")
const NOTICE_TOP := 112.0
const NOTICE_MAX_WIDTH := 536.0

@export var show_field_status := true
@export var backpack_trigger: NodePath

var view: Control
var trail_vitals: PanelContainer
var trail_date: Label
var outing_label: Label
var ravine_label: Label
var trail_route_sign: TravelRouteSign
var notice: Label
var notice_tween: Tween
var management_open := false
var settings_open := false
var modal_open := false
var summary: Control
var status: Label
var backpack: Control
var backpack_button: Button
var field_return_button: Button
var _return_player: Player

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	view = Control.new()
	view.theme = GAME_THEME
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if show_field_status:
		_build_status()
	_setup_backpack_button()
	notice = Label.new()
	notice.name = "WorldNotice"
	notice.hide()
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	notice.theme = HUD_THEME
	notice.theme_type_variation = &"HudBronzeInk"
	notice.add_theme_stylebox_override(&"normal", HUD_THEME.get_stylebox(&"panel", &"HudRail"))
	notice.add_to_group(&"interaction_prompt_obstacle")
	view.add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	InterfaceFont.scale_reading_text(notice)
	Preferences.reading_size_changed.connect(_fit_notice_width)
	view.resized.connect(_fit_notice_width)
	notice.minimum_size_changed.connect(_fit_notice_height, CONNECT_DEFERRED)
	set_notice_clearance(0.0)
	GameEvents.world_notice.connect(show_world_notice)
	GameEvents.management_visibility_changed.connect(func(open: bool):
		management_open = open
		_refresh_notice_visibility()
	)
	GameEvents.settings_visibility_changed.connect(func(open: bool):
		settings_open = open
		_refresh_notice_visibility()
	)
	GameEvents.modal_visibility_changed.connect(func(open: bool):
		modal_open = open
		_refresh_notice_visibility()
	)
	GameEvents.campaign_ended.connect(_show_outcome, CONNECT_DEFERRED)
	GameEvents.ending_record_requested.connect(_open_record)
	if Global.outcome != Global.Outcome.RUNNING:
		_show_outcome.call_deferred(Global.outcome, true)
	elif get_parent().scene_file_path != Global.ESTATE_SCENE and not Global.restore_notice.is_empty():
		show_world_notice(Global.restore_notice, 4.0)
		Global.restore_notice = ""

func set_notice_clearance(minimum_top: float) -> void:
	if is_instance_valid(notice):
		notice.position.y = maxf(NOTICE_TOP, minimum_top)

func add_field_return(walker: Player, choose_trip: Callable) -> void:
	_return_player = walker
	field_return_button = Button.new()
	field_return_button.name = "FieldReturn"
	field_return_button.add_to_group(&"interaction_prompt_obstacle")
	var work := Global.field_return_caption()
	field_return_button.text = "回井田" if work.is_empty() else "接着田务"
	field_return_button.tooltip_text = "沿路指引回第一块井田的田口" if work.is_empty() else "回封地后查看先前的田务 · " + work
	field_return_button.theme = HUD_THEME
	field_return_button.theme_type_variation = &"HudButton"
	field_return_button.focus_mode = Control.FOCUS_NONE
	field_return_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	view.add_child(field_return_button)
	field_return_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	field_return_button.offset_left = -188.0
	field_return_button.offset_right = -92.0
	field_return_button.offset_top = 16.0
	field_return_button.offset_bottom = 56.0
	field_return_button.pressed.connect(func():
		if _can_start_field_return() and not choose_trip.call(Global.FIELD_RETURN):
			show_world_notice("这里接不上山路，靠近一条路后再选。")
	)
	field_return_button.hide()
	set_process(true)

func _process(_delta: float) -> void:
	field_return_button.visible = _can_start_field_return()

func _can_start_field_return() -> bool:
	return Global.outcome == Global.Outcome.RUNNING and not get_tree().paused and not settings_open and not modal_open \
		and not management_open and is_instance_valid(_return_player) and not _return_player.world_controls_blocked() \
		and Global.regional_destination() != Global.FIELD_RETURN

func _setup_backpack_button() -> void:
	if backpack_trigger.is_empty():
		backpack_button = Button.new()
		backpack_button.name = "BackpackButton"
		backpack_button.add_to_group(&"interaction_prompt_obstacle")
		view.add_child(backpack_button)
		backpack_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		backpack_button.offset_left = 92.0
		backpack_button.offset_right = 188.0
		backpack_button.offset_top = 16.0
		backpack_button.offset_bottom = 56.0
	else:
		backpack_button = get_node(backpack_trigger)
	backpack_button.focus_mode = Control.FOCUS_NONE
	backpack_button.theme = HUD_THEME
	backpack_button.theme_type_variation = &"HudButton"
	backpack_button.icon = HUDIcons.icon(HUDIcons.Symbol.BACKPACK)
	backpack_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	backpack_button.pressed.connect(_open_backpack)
	GamepadInput.changed.connect(_refresh_backpack_shortcuts)
	Preferences.bindings_changed.connect(_refresh_backpack_shortcuts)
	_refresh_backpack_shortcuts()

func _refresh_backpack_shortcuts() -> void:
	backpack_button.text = "背包" if GamepadInput.active else "背包  " + Preferences.key_label(KeyBindings.BACKPACK)
	if backpack:
		backpack.close_button.text = "关闭  B" if GamepadInput.active else "关闭  Esc"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and Preferences.matches(event, KeyBindings.BACKPACK):
		if _open_backpack():
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not backpack or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel") or Preferences.matches(event, KeyBindings.BACKPACK):
		get_viewport().set_input_as_handled()
		_close_backpack()

func _open_backpack() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Player
	if get_tree().paused or Global.outcome != Global.Outcome.RUNNING or modal_open or settings_open or management_open \
			or not player or player.world_controls_blocked() or player.training_cart.visible:
		return false
	get_tree().paused = true
	backpack = BACKPACK.instantiate()
	view.add_child(backpack)
	backpack.close_requested.connect(_close_backpack)
	_refresh_backpack_shortcuts()
	GamepadInput.snap_pointer_to_focus()
	AudioManager.play_menu_cue(AudioManager.MenuCue.OPEN)
	GameEvents.modal_visibility_changed.emit(true)
	return true

func _close_backpack() -> void:
	backpack.hide()
	backpack.queue_free()
	backpack = null
	get_tree().paused = Global.outcome != Global.Outcome.RUNNING
	if Global.outcome == Global.Outcome.RUNNING:
		AudioManager.play_menu_cue(AudioManager.MenuCue.CLOSE)
	GameEvents.modal_visibility_changed.emit(false)

func _refresh_notice_visibility() -> void:
	var covered := management_open or settings_open or modal_open or is_instance_valid(summary)
	notice.visible = not covered and not notice.text.is_empty() and notice.modulate.a > 0.0
	if notice_tween and notice_tween.is_valid():
		if notice.visible:
			notice_tween.play()
		else:
			notice_tween.pause()

func _build_status() -> void:
	var trail_note := PanelContainer.new()
	trail_note.add_to_group(&"interaction_prompt_obstacle")
	trail_note.theme = HUD_THEME
	trail_note.theme_type_variation = &"HudCalendar"
	trail_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(trail_note)
	trail_note.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	trail_note.offset_left = -270.0
	trail_note.offset_right = -16.0
	trail_note.offset_top = 16.0
	trail_note.offset_bottom = 16.0
	var trail_text := VBoxContainer.new()
	trail_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail_note.add_child(trail_text)
	var heading := TRAVEL_HEADING.instantiate() as TravelHeading
	heading.place_name = "竹涧"
	trail_text.add_child(heading)
	trail_date = Label.new()
	trail_date.theme_type_variation = &"HudBronzeInk"
	trail_text.add_child(trail_date)
	GameEvents.daylight_changed.connect(_refresh_trail_date)
	_refresh_trail_date()
	outing_label = Label.new()
	outing_label.theme_type_variation = &"HudBronzeInk"
	trail_text.add_child(outing_label)
	GameEvents.forage_taken.connect(_refresh_outing)
	GameEvents.fish_changed.connect(_refresh_outing)
	GameEvents.day_advanced.connect(_refresh_outing.unbind(1))
	ravine_label = Label.new()
	ravine_label.add_theme_color_override("font_color", Color("#f2c596"))
	trail_text.add_child(ravine_label)
	for label: Label in [trail_date, outing_label, ravine_label]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		InterfaceFont.scale_reading_text(label)
	GameEvents.ravine_journal_changed.connect(_refresh_ravine)
	_refresh_ravine()
	trail_route_sign = TRAVEL_ROUTE_SIGN.instantiate()
	trail_text.add_child(trail_route_sign)

	trail_vitals = VITALS.instantiate()
	trail_vitals.add_to_group(&"interaction_prompt_obstacle")
	view.add_child(trail_vitals)
	trail_vitals.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	trail_vitals.offset_left = 16.0
	trail_vitals.offset_top = -16.0
	trail_vitals.offset_right = 202.0
	trail_vitals.offset_bottom = -16.0
	trail_vitals.grow_vertical = Control.GROW_DIRECTION_BEGIN
	GamepadInput.changed.connect(_refresh_camera_hint)
	_refresh_camera_hint()
	GameEvents.stamina_changed.connect(_refresh_outing.unbind(1))
	_refresh_outing()

func _refresh_trail_date() -> void:
	trail_date.text = "第 %d 天 · %s · %s · %s" % [Global.current_day, Global.get_current_solar_term(),
		Global.day_watch_label(), Global.weather_label()]

func _refresh_outing() -> void:
	outing_label.text = Global.ravine_outing_status()

func _refresh_camera_hint() -> void:
	trail_vitals.tooltip_text = ("RT 射箭 · 见地面预警就横移\n按下左/右摇杆缩小/放大" if GamepadInput.active
		else "右键射箭 · 见地面预警就横移\n滚轮缩放视野")

func _refresh_ravine() -> void:
	ravine_label.visible = Global.knows_ravine_journal() and Global.ravine_journal.garden_day == 0
	ravine_label.text = Global.ravine_status() if ravine_label.visible else ""

func show_world_notice(message: String, hold_seconds := -1.0) -> void:
	if notice_tween:
		notice_tween.kill()
		notice_tween = null
	notice.text = message
	notice.modulate.a = 1.0
	_fit_notice_width()
	var hold := hold_seconds if hold_seconds >= 0.0 else (2.8 if show_field_status else 0.0)
	if hold > 0.0 and not message.is_empty():
		notice_tween = create_tween()
		notice_tween.tween_interval(hold)
		notice_tween.tween_property(notice, "modulate:a", 0.0, 0.45)
		notice_tween.tween_callback(notice.hide)
	_refresh_notice_visibility()

func _fit_notice_width() -> void:
	if notice.text.is_empty():
		return
	var font := notice.get_theme_font(&"font")
	var font_size := notice.get_theme_font_size(&"font_size")
	var text_width := font.get_multiline_string_size(notice.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var padding := notice.get_theme_stylebox(&"normal").get_minimum_size().x
	var available := clampf(view.size.x - 16.0, padding, NOTICE_MAX_WIDTH)
	var width := minf(ceilf(text_width + padding), available)
	notice.offset_left = -width * 0.5
	notice.offset_right = width * 0.5
	_fit_notice_height.call_deferred()

func _fit_notice_height() -> void:
	notice.size.y = notice.get_combined_minimum_size().y

func _show_outcome(outcome: Global.Outcome, saved_ending := false) -> void:
	if is_instance_valid(summary):
		return
	if backpack:
		_close_backpack()
	get_tree().paused = true
	if outcome in [Global.Outcome.TRADITIONAL, Global.Outcome.REFORMED]:
		_show_ending(saved_ending)
		return
	_show_defeat(outcome)

func _show_ending(saved_ending: bool) -> void:
	var ending = _add_ending_panel()
	ending.present(get_parent().get_node("World"), saved_ending)
	status = ending.status
	ending.ending_saved = saved_ending
	if saved_ending:
		status.text = "此结局已保存，可从「选择存档」重看。"
	else:
		match Global.save_automatically("ending"):
			OK:
				ending.ending_saved = true
				status.text = "结局已自动保存。"
			ERR_SKIP: status.text = "可点「保存结局」留存本次记录。"
			ERR_FILE_UNRECOGNIZED: status.text = "结局自动保存失败。自动档位含新版存档，可点「保存结局」尝试手动档。"
			_: status.text = "结局自动保存失败。可尝试「保存结局」。"
	ending.continue_button.pressed.connect(_continue_estate)
	ending.save_button.pressed.connect(_save_ending)
	ending.refresh_restore()
	ending.restore_requested.connect(_restore_game)
	var title_confirmation := TITLE_CONFIRMATION.new()
	title_confirmation.name = "TitleConfirmation"
	title_confirmation.save_progress = _save_ending
	title_confirmation.return_requested.connect(_return_to_title, CONNECT_DEFERRED)
	ending.add_child(title_confirmation)
	ending.title_button.pressed.connect(func():
		if ending.ending_saved:
			_return_to_title()
		else:
			title_confirmation.ask("结局尚未保存。保存会更新本局手动档，直接返回会放弃这份结局记录。", "留在结算")
	)

func _add_ending_panel() -> Control:
	summary = ESTATE_ENDING.instantiate()
	_refresh_notice_visibility()
	view.add_child(summary)
	return summary

func _continue_estate() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var result := Global.continue_after_ending(player.global_position, player.facing_direction())
	if result != OK:
		status.text = "继续经营失败（%s）" % error_string(result)

func _open_record() -> void:
	get_tree().paused = true
	var ending = _add_ending_panel()
	ending.open_archive()
	ending.close_requested.connect(_close_record)

func _close_record() -> void:
	summary.queue_free()
	summary = null
	_refresh_notice_visibility()
	get_tree().paused = false

func _show_defeat(outcome: Global.Outcome) -> void:
	var background := ColorRect.new()
	background.color = Color("#211c1bf7")
	summary = background
	_refresh_notice_visibility()
	view.add_child(summary)
	summary.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	summary.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 440
	content.add_theme_constant_override("separation", 14)
	center.add_child(content)

	var heading := Label.new()
	var epilogue: String
	var seal_text: String
	match outcome:
		Global.Outcome.DEFEAT_COMBAT:
			heading.text = "战败"
			seal_text = "危"
			epilogue = "气血耗尽，封地经营暂告一段落。"
		_:
			heading.text = "褫夺封地"
			seal_text = "黜"
			epilogue = "久未纳贡，声望跌过底线，国君已收回封地。"
	var seal := PanelContainer.new()
	seal.custom_minimum_size = Vector2(68, 60)
	seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(seal)
	var inscription := Label.new()
	inscription.text = seal_text
	inscription.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inscription.add_theme_font_size_override("font_size", 34)
	inscription.add_theme_color_override("font_color", Color("#f0927a"))
	seal.add_child(inscription)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 42)
	content.add_child(heading)
	var detail := Label.new()
	detail.text = epilogue
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(detail)
	var load_button := Button.new()
	load_button.name = "RestoreCampaign"
	load_button.text = "读取最近存档"
	var recovery := Global.latest_saved_game(true)
	load_button.disabled = recovery.is_empty()
	load_button.custom_minimum_size.y = 44
	load_button.pressed.connect(_restore_game)
	content.add_child(load_button)
	var title_button := Button.new()
	title_button.name = "ReturnToTitle"
	title_button.text = "返回标题"
	title_button.custom_minimum_size.y = 44
	title_button.pressed.connect(_return_to_title)
	content.add_child(title_button)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.text = ("本局没有可恢复的存档。" if load_button.disabled else
		Global.saved_game_caption(recovery))
	content.add_child(status)
	if load_button.disabled:
		title_button.grab_focus()
	else:
		load_button.grab_focus()

func _save_ending() -> Error:
	var result := Global.save_game()
	match result:
		OK: status.text = "结局已存档。"
		ERR_FILE_UNRECOGNIZED: status.text = TITLE_CONFIRMATION.PROTECTED_MANUAL_SAVE + "可留在结算。"
		_: status.text = "保存失败（%s）" % error_string(result)
	if result == OK:
		summary.ending_saved = true
		summary.refresh_restore()
	return result

func _restore_game() -> void:
	get_tree().paused = false
	var result := Global.load_latest_game(true)
	if result != OK:
		get_tree().paused = true
		status.text = ("请用更新版本的《采邑春秋》读取这份存档。" if result == ERR_FILE_UNRECOGNIZED
			else "读取失败（%s）" % error_string(result))

func _return_to_title() -> void:
	get_tree().paused = false
	var result := get_tree().change_scene_to_file(Global.TITLE_SCENE)
	if result != OK:
		get_tree().paused = true
		status.text = "返回标题失败（%s）" % error_string(result)
