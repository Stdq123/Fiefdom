extends CanvasLayer

const GAME_THEME := preload("res://resources/game_theme.tres")
const ESTATE_ENDING := preload("res://scenes/EstateEnding.tscn")
const BACKPACK := preload("res://scenes/Backpack.tscn")

@export var show_field_status := true
@export var backpack_trigger: NodePath

var view: Control
var health_label: Label
var health_bar: ProgressBar
var trail_stamina: Label
var trail_date: Label
var outing_label: Label
var ravine_label: Label
var camera_hint: Label
var notice: Label
var notice_tween: Tween
var management_open := false
var settings_open := false
var modal_open := false
var summary: Control
var status: Label
var backpack: Control
var backpack_button: Button
var trail_weather: TextureRect
var sky_icons := HUDIcons.SKY.map(HUDIcons.icon)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	view = Control.new()
	view.theme = GAME_THEME
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if show_field_status:
		_build_status()
	_setup_backpack_button()
	notice = Label.new()
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_color_override("font_color", Color("#edca83"))
	notice.add_theme_color_override("font_outline_color", Color("#25342a"))
	notice.add_theme_constant_override("outline_size", 3)
	view.add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left = -265.0
	notice.offset_right = 265.0
	notice.offset_top = 112.0
	notice.offset_bottom = 140.0
	GameEvents.world_notice.connect(_show_world_notice)
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

func _setup_backpack_button() -> void:
	if backpack_trigger.is_empty():
		backpack_button = Button.new()
		backpack_button.name = "BackpackButton"
		view.add_child(backpack_button)
		backpack_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		backpack_button.offset_left = 92.0
		backpack_button.offset_right = 188.0
		backpack_button.offset_top = 16.0
		backpack_button.offset_bottom = 56.0
	else:
		backpack_button = get_node(backpack_trigger)
	backpack_button.focus_mode = Control.FOCUS_NONE
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
	GameEvents.modal_visibility_changed.emit(true)
	return true

func _close_backpack() -> void:
	backpack.hide()
	backpack.queue_free()
	backpack = null
	get_tree().paused = Global.outcome != Global.Outcome.RUNNING
	GameEvents.modal_visibility_changed.emit(false)

func _refresh_notice_visibility() -> void:
	notice.visible = not (management_open or settings_open or modal_open)

func _build_status() -> void:
	var trail_note := PanelContainer.new()
	trail_note.position = Vector2(16, 16)
	trail_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(trail_note)
	var trail_text := VBoxContainer.new()
	trail_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail_note.add_child(trail_text)
	var trail_title := Label.new()
	trail_title.text = "竹涧"
	trail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trail_title.add_theme_font_size_override("font_size", 22)
	trail_title.add_theme_color_override("font_color", Color("#efd291"))
	var title_row := HBoxContainer.new()
	trail_text.add_child(title_row)
	title_row.add_child(trail_title)
	trail_weather = TextureRect.new()
	trail_weather.custom_minimum_size = Vector2(20, 20)
	trail_weather.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trail_weather.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trail_weather.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_row.add_child(trail_weather)
	trail_date = Label.new()
	trail_date.add_theme_font_size_override("font_size", 14)
	trail_text.add_child(trail_date)
	GameEvents.daylight_changed.connect(_refresh_trail_date)
	_refresh_trail_date()
	outing_label = Label.new()
	outing_label.add_theme_font_size_override("font_size", 14)
	trail_text.add_child(outing_label)
	GameEvents.forage_taken.connect(_refresh_outing)
	GameEvents.fish_changed.connect(_refresh_outing)
	GameEvents.day_advanced.connect(_refresh_outing.unbind(1))
	ravine_label = Label.new()
	ravine_label.add_theme_font_size_override("font_size", 14)
	ravine_label.add_theme_color_override("font_color", Color("#ebcf8d"))
	trail_text.add_child(ravine_label)
	GameEvents.ravine_journal_changed.connect(_refresh_ravine)
	_refresh_ravine()

	camera_hint = Label.new()
	camera_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	camera_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_hint.add_theme_font_size_override("font_size", 14)
	camera_hint.add_theme_color_override("font_outline_color", Color("#21392d"))
	camera_hint.add_theme_constant_override("outline_size", 3)
	view.add_child(camera_hint)
	camera_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	camera_hint.offset_left = -260.0
	camera_hint.offset_right = -20.0
	camera_hint.offset_top = 66.0
	camera_hint.offset_bottom = 106.0
	GamepadInput.changed.connect(_refresh_camera_hint)
	_refresh_camera_hint()

	var vitals := PanelContainer.new()
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(vitals)
	vitals.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.offset_left = 16.0
	vitals.offset_top = -96.0
	vitals.offset_right = 202.0
	vitals.offset_bottom = -16.0
	var health_stack := VBoxContainer.new()
	health_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(health_stack)
	health_label = Label.new()
	health_label.add_theme_font_size_override("font_size", 14)
	health_stack.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size.y = 5.0
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#bc765f")
	fill.set_corner_radius_all(2)
	health_bar.add_theme_stylebox_override("fill", fill)
	health_stack.add_child(health_bar)
	health_bar.max_value = Global.balance.player_max_health
	trail_stamina = Label.new()
	trail_stamina.add_theme_font_size_override("font_size", 14)
	health_stack.add_child(trail_stamina)
	GameEvents.stamina_changed.connect(_update_trail_stamina)
	GameEvents.health_changed.connect(_update_health)
	_update_health(Global.health)
	_update_trail_stamina(Global.current_stamina)

func _refresh_trail_date() -> void:
	trail_weather.texture = sky_icons[HUDIcons.sky_index()]
	trail_date.text = "第 %d 天 · %s · %s · %s" % [Global.current_day, Global.get_current_solar_term(),
		Global.day_watch_label(), "雨" if Global.has_rain() else "晴"]

func _update_trail_stamina(amount: int) -> void:
	trail_stamina.text = "体力 %d/%d" % [amount, Global.max_stamina]
	_refresh_outing()

func _update_health(health: int) -> void:
	health_label.text = "气血 %d/%d" % [health, Global.balance.player_max_health]
	health_label.modulate = Color("#f19279") if health * 3 < Global.balance.player_max_health else Color.WHITE
	health_bar.value = health

func _refresh_outing() -> void:
	outing_label.text = Global.ravine_outing_status()

func _refresh_camera_hint() -> void:
	camera_hint.text = ("RT 射箭 · 见地面预警就横移\n按下左/右摇杆缩小/放大" if GamepadInput.active
		else "右键射箭 · 见地面预警就横移\n滚轮缩放视野")

func _refresh_ravine() -> void:
	ravine_label.visible = Global.knows_ravine_journal() and Global.ravine_journal.garden_day == 0
	ravine_label.text = Global.ravine_status() if ravine_label.visible else ""

func _show_world_notice(message: String) -> void:
	if notice_tween:
		notice_tween.kill()
	notice.text = message
	notice.modulate.a = 1.0
	if show_field_status and not message.is_empty():
		notice_tween = create_tween()
		notice_tween.tween_interval(2.8)
		notice_tween.tween_property(notice, "modulate:a", 0.0, 0.45)

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
	ending.continue_button.pressed.connect(_continue_estate)
	ending.save_button.pressed.connect(_save_ending)
	ending.restore_button.disabled = Global.latest_saved_game(true).is_empty()
	ending.restore_button.pressed.connect(_restore_game)
	ending.title_button.pressed.connect(_return_to_title)

func _add_ending_panel() -> Control:
	summary = ESTATE_ENDING.instantiate()
	notice.hide()
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

func _save_ending() -> void:
	var result := Global.save_game()
	status.text = "结局已存档。" if result == OK else "保存失败（%s）" % error_string(result)
	if result == OK:
		summary.find_child("RestoreCampaign", true, false).disabled = Global.latest_saved_game(true).is_empty()

func _restore_game() -> void:
	get_tree().paused = false
	var result := Global.load_latest_game(true)
	if result != OK:
		get_tree().paused = true
		status.text = "读取失败（%s）" % error_string(result)

func _return_to_title() -> void:
	get_tree().paused = false
	var result := get_tree().change_scene_to_file(Global.TITLE_SCENE)
	if result != OK:
		get_tree().paused = true
		status.text = "返回标题失败（%s）" % error_string(result)
