extends "res://scripts/SurveyMap.gd"

const VIEW_DIRECTIONS := [0, 2, 1]

@onready var outfits: VBoxContainer = %Outfits
@onready var views: HBoxContainer = %Views
@onready var outfit_name: Label = %OutfitName
@onready var detail: Label = %OutfitDetail
@onready var apply_button: Button = %WearOutfit

var selected := PlayerAttire.DEFAULT
var rows: Dictionary[String, Button] = {}

func _ready() -> void:
	super._ready()
	GameEvents.wardrobe_requested.connect(open_map)
	var group := ButtonGroup.new()
	var normal := outfits.get_theme_stylebox("normal", "Button")
	var selected_style := outfits.get_theme_stylebox("pressed", "Button").duplicate() as StyleBox
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		selected_style.set_content_margin(side, normal.get_margin(side))
	for id: String in PlayerAttire.CATALOG:
		var row := Button.new()
		row.name = id
		row.custom_minimum_size.y = 43.0
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.toggle_mode = true
		row.button_group = group
		row.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.icon = PlayerAttire.preview(id, 0)
		row.add_theme_constant_override("h_separation", 10)
		row.add_theme_stylebox_override("pressed", selected_style)
		row.pressed.connect(_select.bind(id))
		outfits.add_child(row)
		rows[id] = row
	apply_button.pressed.connect(_wear_selected)

func _map_available() -> bool:
	return Global.estate_room == Global.EstateRoom.HALL

func _refresh_on_open() -> void:
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
	selected = id
	rows[id].set_pressed_no_signal(true)
	var choice: Dictionary = PlayerAttire.CATALOG[id]
	for index in VIEW_DIRECTIONS.size():
		var sprite: TextureRect = views.get_child(index).get_node("Sprite")
		sprite.texture = PlayerAttire.preview(id, VIEW_DIRECTIONS[index])
	outfit_name.text = choice.name
	detail.text = choice.detail
	var available := Global.can_wear_attire(id)
	apply_button.disabled = not available or id == Global.attire_id
	if not available:
		apply_button.text = _requirement(id) + "后可穿"
	else:
		apply_button.text = "已穿着" if id == Global.attire_id else "穿上"

func _wear_selected() -> void:
	if Global.change_attire(selected):
		close_map()
