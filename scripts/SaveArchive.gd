extends ColorRect

const LEDGER_DESK := preload("res://scripts/RouteLedgerDesk.gd")
const LOCATION_ART := preload("res://assets/ui/save-locations.png")
const LOCATION_TILE := Vector2i(192, 112)
const TRAVEL_LOCATION_TILES := {
	Global.WEST_ROAD_SCENE: Vector2i(0, 1),
	Global.WEST_MARKET_SCENE: Vector2i(1, 1),
	Global.WILDERNESS_SCENE: Vector2i(2, 1),
}

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
	_refresh_catalog(preferred_campaign.md5_text())

func _refresh_catalog(preferred_key: String, previous_path := "") -> void:
	campaigns.clear()
	campaign_buttons.clear()
	selected_campaign = ""
	_clear_rows(estates)
	status.hide()
	for entry in Global.saved_games():
		var key: String = entry["campaign_key"]
		if not campaigns.has(key):
			campaigns[key] = []
		campaigns[key].append(entry)
	for key in campaigns:
		var summary: Dictionary = campaigns[key][0]
		if summary.error != OK:
			for entry: Dictionary in campaigns[key]:
				if entry.error == ERR_FILE_UNRECOGNIZED:
					summary = entry
					break
		_add_campaign(key, summary)
	if campaigns.is_empty():
		_clear_rows(records)
		records_heading.text = "存档记录"
		_show_unavailable()
		close_button.focus_next = ^"."
		close_button.focus_previous = ^"."
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			close_button.set_focus_neighbor(side, ^".")
		close_button.grab_focus()
	else:
		var key: String = preferred_key if campaigns.has(preferred_key) else campaigns.keys()[0]
		_show_records(key)
		var focus: Button = campaign_buttons[key]
		if not previous_path.is_empty() and key == preferred_key:
			focus = _record_focus(key, previous_path)
		focus.grab_focus()
	GamepadInput.snap_pointer_to_focus.call_deferred()

func _record_focus(key: String, path: String) -> Button:
	var first_readable: Button
	for i in campaigns[key].size():
		var row := records.get_child(i) as Button
		if not row.disabled:
			if campaigns[key][i].path == path:
				return row
			if not first_readable:
				first_readable = row
	if first_readable:
		return first_readable
	return close_button if campaigns.size() == 1 else campaign_buttons[key]

func _clear_rows(column: VBoxContainer) -> void:
	for row in column.get_children():
		column.remove_child(row)
		row.queue_free()

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
	if latest["error"] == ERR_FILE_UNRECOGNIZED:
		detail = "需更新游戏"
	elif latest["error"] == OK:
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
	_clear_rows(records)
	record_scroll.scroll_vertical = 0
	var entries: Array = campaigns[key]
	records_heading.text = "%s的存档" % entries[0]["campaign_name"] if entries[0]["error"] == OK else "存档记录"
	status.hide()
	var readable := false
	var update_note := ""
	for entry: Dictionary in entries:
		var button := _add_row(records)
		if entry.error != OK:
			_mark_unavailable(button, entry)
			if entry.error == ERR_FILE_UNRECOGNIZED:
				update_note = Global.saved_game_version_notice(entry)
		else:
			var route := Global.saved_game_route(entry, false)
			var rank: String = Global.rank_names[entry.rank]
			var detail := rank if route.is_empty() else route
			var caption := Global.saved_game_caption(entry)
			if not route.is_empty():
				caption += " · " + rank
			if entry.legacy:
				caption = ("旧目录 · " if entry.required_version > 0 else "旧版 · ") + caption
			button.text = "%s · %s\n%s" % [Global.saved_game_action(entry), detail, caption]
			var version_note := Global.saved_game_version_notice(entry)
			if not version_note.is_empty():
				button.text += "\n" + version_note
			button.tooltip_text = button.text
			_set_record_picture(button, entry)
		if not button.disabled and not Global.saved_game_route(entry, false).is_empty():
			button.tooltip_text += "\n爵位 · " + Global.rank_names[entry.rank]
		button.pressed.connect(_load.bind(entry, key))
		readable = readable or not button.disabled
	if not readable:
		_show_unavailable()
		if not update_note.is_empty():
			status.text = update_note
	_link_focus(campaign_buttons[key])

func _set_record_picture(button: Button, entry: Dictionary) -> void:
	var width := 66
	if entry.running:
		var tile: Vector2i = TRAVEL_LOCATION_TILES.get(entry.scene, Vector2i(entry.estate_room, 0))
		var place := AtlasTexture.new()
		place.atlas = LOCATION_ART
		place.region = Rect2(Vector2(tile * LOCATION_TILE), Vector2(LOCATION_TILE))
		place.filter_clip = true
		button.icon = place
		button.custom_minimum_size.y = 90
		width = 128
	elif entry.completed_route in [Global.Outcome.TRADITIONAL, Global.Outcome.REFORMED]:
		button.icon = LEDGER_DESK.volume_texture(entry.completed_route == Global.Outcome.TRADITIONAL)
	else:
		return
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", width)
	button.add_theme_constant_override("h_separation", 12)

func _mark_unavailable(button: Button, entry: Dictionary) -> void:
	var reason := "需更新游戏" if entry.error == ERR_FILE_UNRECOGNIZED else "无法读取"
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	button.text = "%s · %s" % [entry.source, reason]
	if entry.legacy:
		button.text += " · 旧目录"
	var filename := str(entry.path).get_file()
	button.text += "\n" + filename + (Global.SAVE_BACKUP_SUFFIX if entry.from_backup else "")
	button.tooltip_text = button.text

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

func _load(entry: Dictionary, key: String) -> void:
	var prepared := await MapTravel.prepare_session(entry["scene"], "正在读取存档")
	if prepared in [ERR_BUSY, ERR_SKIP]:
		return
	if prepared != OK:
		_show_load_error("无法读取这份存档所需的地图。可重试或选择其他记录。")
		return
	get_tree().paused = false
	var result := Global.load_saved_entry(entry)
	if result == OK:
		return
	get_tree().paused = true
	if result in [ERR_ALREADY_IN_USE, ERR_FILE_CORRUPT, ERR_FILE_NOT_FOUND, ERR_FILE_UNRECOGNIZED]:
		_refresh_catalog(key, entry.path)
		if campaigns.is_empty():
			return
		var notice := "原记录已变更，请核对列表后重新选择。"
		if result == ERR_FILE_UNRECOGNIZED:
			notice = "原记录需要更新版本的《采邑春秋》。"
		if status.visible:
			if result != ERR_FILE_UNRECOGNIZED:
				status.text += "\n" + notice
		else:
			status.text = notice
			status.show()
		return
	_show_load_error("这份存档无法读取。请选择其他存档。")

func _show_load_error(message: String) -> void:
	status.text = message
	status.show()
	close_button.grab_focus()
	GamepadInput.snap_pointer_to_focus.call_deferred()
