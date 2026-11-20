extends ColorRect

const LEDGER_DESK := preload("res://scripts/RouteLedgerDesk.gd")

@onready var records: VBoxContainer = %Records
@onready var estates: VBoxContainer = %Estates
@onready var records_heading: Label = %RecordsHeading
@onready var record_scroll: ScrollContainer = %RecordScroll
@onready var status: Label = %Status
@onready var controls_hint: Label = %ControlsHint
@onready var close_button: Button = %Close

var preferred_campaign := ""
var selected_campaign := ""
var previously_paused := false
var previous_focus: Control
var campaigns: Dictionary[String, Array] = {}
var campaign_buttons: Dictionary[String, Button] = {}

func _ready() -> void:
	previously_paused = get_tree().paused
	previous_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	AudioManager.play_menu_cue(AudioManager.MenuCue.OPEN)
	close_button.pressed.connect(_close)
	for control: Control in [%Heading, %EstateHeading, records_heading, status, controls_hint, close_button]:
		InterfaceFont.scale_reading_text(control)
	GamepadInput.changed.connect(_refresh_controls_hint)
	_refresh_controls_hint()
	for entry in Global.saved_games():
		var key: String = entry["campaign_key"]
		if not campaigns.has(key):
			campaigns[key] = []
		campaigns[key].append(entry)
	for key in campaigns:
		_add_campaign(key, campaigns[key][0])
	if campaigns.is_empty():
		_show_unavailable()
		close_button.focus_next = ^"."
		close_button.focus_previous = ^"."
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			close_button.set_focus_neighbor(side, ^".")
		close_button.grab_focus()
	else:
		var preferred := preferred_campaign.md5_text()
		var key: String = preferred if campaigns.has(preferred) else campaigns.keys()[0]
		_show_records(key)
		campaign_buttons[key].grab_focus()
	GamepadInput.snap_pointer_to_focus.call_deferred()

func _add_row(column: VBoxContainer) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 68
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(button)
	InterfaceFont.scale_reading_text(button)
	return button

func _add_campaign(key: String, latest: Dictionary) -> void:
	var button := _add_row(estates)
	button.toggle_mode = true
	var heading: String = latest["campaign_name"]
	var detail := "存档无法读取"
	if latest["error"] == OK:
		var route := Global.saved_game_route(latest, false)
		detail = "第 %d 天 · %s" % [latest["day"], route if not route.is_empty() else Global.rank_names[latest["rank"]]]
	button.text = heading + "\n" + detail
	button.tooltip_text = button.text
	button.focus_entered.connect(_show_records.bind(key))
	button.pressed.connect(_show_records.bind(key))
	campaign_buttons[key] = button

func _show_records(key: String) -> void:
	if key == selected_campaign:
		campaign_buttons[key].set_pressed_no_signal(true)
		return
	if not selected_campaign.is_empty():
		AudioManager.play_menu_cue(AudioManager.MenuCue.PAGE)
	selected_campaign = key
	for estate in campaign_buttons:
		campaign_buttons[estate].theme_type_variation = &"HudPrimary" if estate == key else &"HudButton"
		campaign_buttons[estate].set_pressed_no_signal(estate == key)
	for row in records.get_children():
		records.remove_child(row)
		row.queue_free()
	record_scroll.scroll_vertical = 0
	var entries: Array = campaigns[key]
	records_heading.text = ("%s的存档" % entries[0]["campaign_name"] if entries[0]["error"] == OK
		else "受损记录")
	status.hide()
	var readable := false
	for entry: Dictionary in entries:
		var button := _add_row(records)
		button.disabled = entry["error"] != OK
		if button.disabled:
			button.focus_mode = Control.FOCUS_NONE
			button.text = "%s · 无法读取" % entry["source"]
			if entry.legacy:
				button.text += " · 旧版"
			button.tooltip_text = button.text
		else:
			var route := Global.saved_game_route(entry, false)
			var rank: String = Global.rank_names[entry.rank]
			var detail := rank if route.is_empty() else route
			var caption := Global.saved_game_caption(entry)
			if not route.is_empty():
				caption += " · " + rank
			if entry.legacy:
				caption = "旧版 · " + caption
			button.text = "%s · %s\n%s" % [Global.saved_game_action(entry), detail, caption]
			button.tooltip_text = button.text
			if entry.completed_route in [Global.Outcome.TRADITIONAL, Global.Outcome.REFORMED]:
				button.icon = LEDGER_DESK.volume_texture(entry.completed_route == Global.Outcome.TRADITIONAL)
				button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				button.expand_icon = true
				button.add_theme_constant_override("icon_max_width", 66)
				button.add_theme_constant_override("h_separation", 12)
		if not button.disabled and not Global.saved_game_route(entry, false).is_empty():
			button.tooltip_text += "\n爵位 · " + Global.rank_names[entry.rank]
		button.pressed.connect(_load.bind(entry, button, key))
		readable = readable or not button.disabled
	if not readable:
		_show_unavailable()
	_link_focus(campaign_buttons[key])

func _link_focus(selected: Button) -> void:
	var estate_rows: Array[Button] = []
	estate_rows.assign(campaign_buttons.values())
	var record_rows: Array[Button] = []
	for button: Button in records.get_children():
		if not button.disabled:
			record_rows.append(button)
	var first_record := record_rows[0] if not record_rows.is_empty() else close_button
	_column_focus(estate_rows, SIDE_RIGHT, first_record)
	_column_focus(record_rows, SIDE_LEFT, selected)
	for row in estate_rows:
		row.focus_next = row.get_path_to(first_record)
		row.focus_previous = row.get_path_to(close_button)
	for i in record_rows.size():
		var row := record_rows[i]
		row.focus_next = row.get_path_to(record_rows[i + 1] if i + 1 < record_rows.size() else close_button)
		row.focus_previous = row.get_path_to(record_rows[i - 1] if i > 0 else selected)
	close_button.focus_next = close_button.get_path_to(selected)
	close_button.focus_previous = close_button.get_path_to(record_rows.back() if not record_rows.is_empty() else selected)
	close_button.focus_neighbor_top = close_button.get_path_to(record_rows.back() if not record_rows.is_empty() else selected)
	close_button.focus_neighbor_left = close_button.get_path_to(selected)
	close_button.focus_neighbor_right = ^"."
	close_button.focus_neighbor_bottom = ^"."

func _column_focus(items: Array[Button], toward: Side, across: Button) -> void:
	for i in items.size():
		var row := items[i]
		row.set_focus_neighbor(toward, row.get_path_to(across))
		row.set_focus_neighbor(SIDE_LEFT if toward == SIDE_RIGHT else SIDE_RIGHT, ^".")
		row.focus_neighbor_top = row.get_path_to(items[maxi(0, i - 1)])
		row.focus_neighbor_bottom = row.get_path_to(items[i + 1] if i + 1 < items.size() else close_button)

func _show_unavailable() -> void:
	status.text = "没有可读取的存档。" if selected_campaign.is_empty() else "这处封地没有可读取的存档。"
	status.show()

func _refresh_controls_hint() -> void:
	controls_hint.text = ("十字键选条目 · 摇杆移动光标 · A 确认 · B 返回" if GamepadInput.active
		else "↑ ↓ 选条目 · ← → 换栏 · 回车确认 · Esc 返回")

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	get_tree().paused = previously_paused
	hide()
	AudioManager.play_menu_cue(AudioManager.MenuCue.CLOSE)
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()
		GamepadInput.snap_pointer_to_focus.call_deferred()
	queue_free()

func _load(entry: Dictionary, button: Button, key: String) -> void:
	var prepared := await MapTravel.prepare_session(entry["scene"], "正在读取存档")
	if prepared in [ERR_BUSY, ERR_SKIP]:
		return
	if prepared != OK:
		_show_load_error("无法读取这份存档所需的地图。可重试或选择其他记录。")
		return
	get_tree().paused = false
	var result := Global.load_game(entry["path"])
	if result == OK:
		return
	get_tree().paused = true
	if result in [ERR_FILE_CORRUPT, ERR_FILE_NOT_FOUND]:
		button.disabled = true
		button.focus_mode = Control.FOCUS_NONE
		_link_focus(campaign_buttons[key])
	_show_load_error("这份存档无法读取。请选择其他存档。")

func _show_load_error(message: String) -> void:
	status.text = message
	status.show()
	close_button.grab_focus()
	GamepadInput.snap_pointer_to_focus.call_deferred()
