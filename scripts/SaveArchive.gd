extends ColorRect

@onready var records: VBoxContainer = %Records
@onready var estates: VBoxContainer = %Estates
@onready var records_heading: Label = %RecordsHeading
@onready var record_scroll: ScrollContainer = %RecordScroll
@onready var status: Label = %Status
@onready var close_button: Button = %Close

var preferred_campaign := ""
var previously_paused := false
var previous_focus: Control
var campaigns: Dictionary[String, Array] = {}
var campaign_buttons: Dictionary[String, Button] = {}

func _ready() -> void:
	previously_paused = get_tree().paused
	previous_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	close_button.pressed.connect(_close)
	for entry in Global.saved_games():
		var key: String = entry["campaign_key"]
		if not campaigns.has(key):
			campaigns[key] = []
		campaigns[key].append(entry)
	var normal := get_theme_stylebox("normal", "Button")
	var selected := get_theme_stylebox("pressed", "Button").duplicate() as StyleBox
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		selected.set_content_margin(side, normal.get_margin(side))
	for key in campaigns:
		_add_campaign(key, campaigns[key][0], selected)
	if campaigns.is_empty():
		_show_unavailable()
		close_button.grab_focus()
		return
	var preferred := preferred_campaign.md5_text()
	var key: String = preferred if campaigns.has(preferred) else campaigns.keys()[0]
	_show_records(key)
	campaign_buttons[key].grab_focus()

func _add_campaign(key: String, latest: Dictionary, selected: StyleBox) -> void:
	var button := Button.new()
	button.custom_minimum_size.y = 60
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.toggle_mode = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_stylebox_override("pressed", selected)
	var heading: String = latest["campaign_name"]
	var detail := "存档无法读取"
	if latest["error"] == OK:
		var route := Global.saved_game_route(latest)
		detail = "第 %d 天 · %s" % [latest["day"], route if not route.is_empty() else Global.rank_names[latest["rank"]]]
	button.text = heading + "\n" + detail
	button.tooltip_text = button.text
	button.pressed.connect(_show_records.bind(key))
	estates.add_child(button)
	campaign_buttons[key] = button

func _show_records(key: String) -> void:
	for estate in campaign_buttons:
		campaign_buttons[estate].set_pressed_no_signal(estate == key)
	for row in records.get_children():
		records.remove_child(row)
		row.queue_free()
	record_scroll.scroll_vertical = 0
	var entries: Array = campaigns[key]
	records_heading.text = "%s的存档" % entries[0]["campaign_name"]
	status.hide()
	var readable := false
	for entry: Dictionary in entries:
		var button := Button.new()
		button.custom_minimum_size.y = 46
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.disabled = entry["error"] != OK
		button.text = ("%s · 无法读取" % entry["source"]) if button.disabled else (
			Global.saved_game_caption(entry) + " · " + Global.rank_names[entry["rank"]])
		if entry["legacy"]:
			button.text += " · 旧版"
		button.tooltip_text = button.text
		button.pressed.connect(_load.bind(entry["path"], button))
		records.add_child(button)
		readable = readable or not button.disabled
	if not readable:
		_show_unavailable()

func _show_unavailable() -> void:
	status.text = "没有可读取的存档。"
	status.show()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	get_tree().paused = previously_paused
	hide()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()
	queue_free()

func _load(path: String, button: Button) -> void:
	get_tree().paused = false
	var result := Global.load_game(path)
	if result == OK:
		return
	get_tree().paused = true
	status.text = "这份存档无法读取。请选择其他存档。"
	status.show()
	if result in [ERR_FILE_CORRUPT, ERR_FILE_NOT_FOUND]:
		button.disabled = true
	close_button.grab_focus()
