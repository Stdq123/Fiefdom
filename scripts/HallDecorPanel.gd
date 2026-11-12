extends "res://scripts/SurveyMap.gd"

@onready var camera: Camera2D = $"../../../World/HallInterior/RoomCamera"
@onready var decor: HallDecorView = $"../../../World/HallInterior/Decor"
@onready var shelf_hint: Label = $"../../../World/HallInterior/DecorShelf/Hint"
@onready var exit_hint: Label = $"../../../World/HallInterior/ExitHint"
@onready var estate_hud: Control = $"../EstateHUD"
@onready var shelf_tab: Button = %ShelfTab
@onready var mat_tab: Button = %MatTab
@onready var shelf_rows: VBoxContainer = %ShelfRows
@onready var mat_rows: VBoxContainer = %MatRows
@onready var preview_label: Label = %PreviewLabel
@onready var apply_button: Button = %ApplyDecor

var rows: Dictionary[String, Button] = {}
var draft_mat := HallDecor.DEFAULT_MAT
var draft_shelf := HallDecor.DEFAULT_SHELF
var camera_offset := Vector2.ZERO
var hint_visible := false

func _ready() -> void:
	super._ready()
	GameEvents.hall_decor_requested.connect(open_map)
	shelf_tab.pressed.connect(_show_slot.bind(HallDecor.Slot.SHELF))
	mat_tab.pressed.connect(_show_slot.bind(HallDecor.Slot.MAT))
	apply_button.pressed.connect(_apply)

	var pressed_style := shelf_rows.get_theme_stylebox("pressed", "Button").duplicate() as StyleBox
	var normal := shelf_rows.get_theme_stylebox("normal", "Button")
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		pressed_style.set_content_margin(side, normal.get_margin(side))
	for id: String in HallDecor.CATALOG:
		var row := Button.new()
		row.name = id
		row.custom_minimum_size.y = 38.0
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.toggle_mode = true
		row.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.icon = decor.texture_for(id, true)
		row.add_theme_constant_override("icon_max_width", 32)
		row.add_theme_constant_override("h_separation", 11)
		row.add_theme_stylebox_override("pressed", pressed_style)
		row.pressed.connect(_select.bind(id))
		var list := mat_rows if HallDecor.CATALOG[id].slot == HallDecor.Slot.MAT else shelf_rows
		list.add_child(row)
		rows[id] = row

func _map_available() -> bool:
	return Global.estate_room == Global.EstateRoom.HALL

func _refresh_on_open() -> void:
	draft_mat = Global.hall_mat_id
	draft_shelf = Global.hall_shelf_id
	camera_offset = camera.offset
	camera.offset.x += 80.0
	camera.force_update_scroll()
	estate_hud.hide()
	exit_hint.hide()
	hint_visible = shelf_hint.visible
	shelf_hint.hide()
	_show_slot(HallDecor.Slot.SHELF)
	_refresh_rows()

func close_map() -> void:
	if owns_pause:
		decor.show_saved()
		camera.offset = camera_offset
		camera.force_update_scroll()
		estate_hud.show()
		exit_hint.show()
		shelf_hint.visible = hint_visible
	super.close_map()

func _show_slot(slot: HallDecor.Slot) -> void:
	var shelf_active := slot == HallDecor.Slot.SHELF
	shelf_tab.set_pressed_no_signal(shelf_active)
	mat_tab.set_pressed_no_signal(not shelf_active)
	shelf_rows.visible = shelf_active
	mat_rows.visible = not shelf_active

func _select(id: String) -> void:
	if HallDecor.CATALOG[id].slot == HallDecor.Slot.MAT:
		draft_mat = id
	else:
		draft_shelf = id
	decor.show_selection(draft_mat, draft_shelf)
	_refresh_rows()

func _refresh_rows() -> void:
	var changed := draft_mat != Global.hall_mat_id or draft_shelf != Global.hall_shelf_id
	for id: String in rows:
		var row := rows[id]
		var choice: Dictionary = HallDecor.CATALOG[id]
		var selected := id == draft_mat or id == draft_shelf
		row.disabled = not Global.hall_decor_unlocked(id)
		row.set_pressed_no_signal(selected)
		row.text = choice.name
		if row.disabled:
			row.text += "  ·  " + choice.requirement
		elif selected:
			row.text += "  ·  已摆放" if id in [Global.hall_mat_id, Global.hall_shelf_id] else "  ·  预览中"
	preview_label.text = "%s · %s" % [HallDecor.CATALOG[draft_mat].name, HallDecor.CATALOG[draft_shelf].name]
	apply_button.disabled = not changed

func _apply() -> void:
	if Global.arrange_hall(draft_mat, draft_shelf):
		close_map()
