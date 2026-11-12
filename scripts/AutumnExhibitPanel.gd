extends "res://scripts/SurveyMap.gd"

@onready var introduction: Label = %Introduction
@onready var crops: HBoxContainer = %Crops
@onready var selection: Label = %Selection
@onready var take: Button = %Take
@onready var share: Button = %Share

var selected: Array[String] = []
var crop_buttons: Dictionary[String, Button] = {}

func _ready() -> void:
	super._ready()
	for id: String in AutumnExhibit.CROPS:
		var picture := ItemManager.crop_picture(ItemManager.get_crop(id))
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 59.0
		button.toggle_mode = true
		button.icon = picture.texture
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 26)
		button.add_theme_color_override("icon_normal_color", picture.tint)
		button.add_theme_color_override("icon_pressed_color", picture.tint)
		button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		button.toggled.connect(_toggle_crop.bind(id))
		crop_buttons[id] = button
		crops.add_child(button)
	take.pressed.connect(_commit.bind(false))
	share.pressed.connect(_commit.bind(true))

func _refresh_on_open() -> void:
	selected.clear()
	var record := Global.autumn_exhibit_record(Global.current_day)
	var preparing := record.is_empty()
	crops.visible = preparing
	take.get_parent().visible = preparing
	if not preparing:
		introduction.text = "展完后，各家都把自家的样品带回了。"
		if record.shared:
			var recipients := PackedStringArray()
			for index in AutumnExhibit.SAMPLE_COUNT:
				recipients.append("%s一份%s" % [AutumnExhibit.GUESTS[index], ItemManager.crop_label(record.crops[index])])
			introduction.text = "商音把今年的展品记下了。\n%s。" % "，".join(recipients)
		selection.text = "今年摆过    %s" % AutumnExhibit.names(record.crops)
		return
	introduction.text = "商音在等各家的收成。挑三种私田作物，各用一份摆在台上。"
	var last_year := Global.current_day - maxi(1, Global.balance.days_per_solar_term) * Global.SOLAR_TERMS.size()
	if last_year > 0:
		var last := Global.autumn_exhibit_record(last_year)
		if not last.is_empty():
			introduction.text = "商音还记得你去年摆的%s。今年也挑三样吧。" % AutumnExhibit.names(last.crops)
	take.text = "摆样后带回  ·  礼 +%d" % Global.balance.autumn_exhibit_rites
	share.text = "三份都留给乡邻  ·  礼 +%d、声望 +%d" % [Global.balance.autumn_exhibit_rites, Global.balance.autumn_share_reputation]
	_show_selection()

func _toggle_crop(pressed: bool, id: String) -> void:
	if pressed:
		selected.append(id)
	else:
		selected.erase(id)
	_show_selection()

func _show_selection() -> void:
	var full := selected.size() == AutumnExhibit.SAMPLE_COUNT
	for id: String in crop_buttons:
		var button := crop_buttons[id]
		var stock := Global.crop_stock.count(id)
		button.text = "%s\n仓中 %d" % [ItemManager.crop_label(id), stock]
		button.set_pressed_no_signal(id in selected)
		button.disabled = stock == 0 or (full and id not in selected)
	selection.text = "已选 %d/%d" % [selected.size(), AutumnExhibit.SAMPLE_COUNT]
	if not selected.is_empty():
		selection.text += "    " + AutumnExhibit.names(selected)
	take.disabled = not full
	share.disabled = not full

func _commit(sharing: bool) -> void:
	if Global.place_autumn_exhibit(selected, sharing):
		close_map()
		var note := "三样收成已上展台 · 礼 +%d" % Global.balance.autumn_exhibit_rites
		if sharing:
			note += " · 声望 +%d" % Global.balance.autumn_share_reputation
		GameEvents.world_notice.emit(note)
