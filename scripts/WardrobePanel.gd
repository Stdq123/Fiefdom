extends "res://scripts/SurveyMap.gd"

const POSES := {WardrobeFigure.STAND: "站姿", WardrobeFigure.WALK: "走路",
	ToolGesture.Action.TILL: "挥锄", ToolGesture.Action.SOW: "播种",
	ToolGesture.Action.WATER: "浇水", ToolGesture.Action.HARVEST: "收割"}

@onready var outfits: VBoxContainer = %Outfits
@onready var views: HBoxContainer = %Views
@onready var figures: Array[WardrobeFigure] = [views.get_node("Front/Sprite"), views.get_node("Side/Sprite"), views.get_node("Back/Sprite")]
@onready var outfit_name: Label = %OutfitName
@onready var detail: Label = %OutfitDetail
@onready var apply_button: Button = %WearOutfit

var selected := PlayerAttire.DEFAULT
var rows: Dictionary[String, Button] = {}
var pose_buttons: Dictionary[int, Button] = {}
var motion := WardrobeFigure.STAND
var motion_time := 0.0

func _ready() -> void:
	super._ready()
	GameEvents.wardrobe_requested.connect(open_map)
	modal.visibility_changed.connect(_refresh_animation)
	var poses := ButtonGroup.new()
	for id: int in POSES:
		var button := Button.new()
		button.text = POSES[id]
		button.toggle_mode = true
		button.button_group = poses
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size.y = 34.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme_type_variation = &"HudButton"
		button.pressed.connect(_select_pose.bind(id))
		%Poses.add_child(button)
		pose_buttons[id] = button
	var group := ButtonGroup.new()
	for id: String in PlayerAttire.CATALOG:
		var row := Button.new()
		row.name = id
		row.custom_minimum_size.y = 43.0
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.toggle_mode = true
		row.button_group = group
		row.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.theme_type_variation = &"HudButton"
		row.icon = PlayerAttire.preview(id, 0)
		row.add_theme_constant_override("h_separation", 10)
		row.add_theme_constant_override("icon_max_width", 32)
		# Retain the actual cloth colours on the light selection tab.
		for tint in [&"icon_normal_color", &"icon_pressed_color", &"icon_focus_color", &"icon_hover_color", &"icon_hover_pressed_color"]:
			row.add_theme_color_override(tint, Color.WHITE)
		row.pressed.connect(_select.bind(id))
		outfits.add_child(row)
		rows[id] = row
	apply_button.pressed.connect(_wear_selected)
	_refresh_animation()

func _map_available() -> bool:
	return Global.estate_room == Global.EstateRoom.HALL

func _refresh_on_open() -> void:
	_select_pose(WardrobeFigure.STAND)
	for id: String in rows:
		rows[id].visible = id != PlayerAttire.WOOL or Global.sheepfold.owned()
		var name_text: String = PlayerAttire.CATALOG[id].name
		if id == Global.attire_id:
			name_text += "   ·   已穿着"
		elif not Global.can_wear_attire(id):
			name_text += "   ·   " + _requirement(id)
		rows[id].text = name_text
	_select(Global.attire_id)

func _requirement(id: String) -> String:
	if id == PlayerAttire.SAMPLE:
		return "交付样绸"
	if id == PlayerAttire.WOOL:
		return "请蔡娘织衣"
	return "晋升%s" % Global.rank_names[PlayerAttire.CATALOG[id].rank]

func _select(id: String) -> void:
	rows[selected].set_pressed_no_signal(false)
	rows[selected].theme_type_variation = &"HudButton"
	selected = id
	rows[id].set_pressed_no_signal(true)
	rows[id].theme_type_variation = &"HudPrimary"
	var choice: Dictionary = PlayerAttire.CATALOG[id]
	for figure in figures:
		figure.dress(id)
		figure.show_pose(motion, motion_time)
	outfit_name.text = choice.name
	detail.text = choice.detail
	var available := Global.can_wear_attire(id)
	apply_button.disabled = not available or id == Global.attire_id
	if not available:
		apply_button.text = _requirement(id) + "后可穿"
	else:
		apply_button.text = "已穿着" if id == Global.attire_id else "穿上"
	_link_focus()

func _link_focus() -> void:
	var order: Array[Control] = [close_button]
	for row: Button in rows.values():
		if row.visible:
			order.append(row)
	order.append_array(pose_buttons.values())
	if not apply_button.disabled:
		order.append(apply_button)
	for index in order.size():
		var button := order[index]
		button.focus_next = button.get_path_to(order[(index + 1) % order.size()])
		button.focus_previous = button.get_path_to(order[index - 1])

func _select_pose(id: int) -> void:
	pose_buttons[motion].set_pressed_no_signal(false)
	pose_buttons[motion].theme_type_variation = &"HudButton"
	motion = id
	pose_buttons[id].set_pressed_no_signal(true)
	pose_buttons[id].theme_type_variation = &"HudPrimary"
	motion_time = 0.0
	for figure in figures:
		figure.show_pose(motion, motion_time)
	_refresh_animation()

func _refresh_animation() -> void:
	set_process(modal.is_visible_in_tree() and motion != WardrobeFigure.STAND)

func _process(delta: float) -> void:
	motion_time = fmod(motion_time + delta, 1.2)
	for figure in figures:
		figure.show_pose(motion, motion_time)

func _wear_selected() -> void:
	if Global.change_attire(selected):
		close_map()
