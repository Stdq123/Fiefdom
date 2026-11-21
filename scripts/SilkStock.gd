extends HFlowContainer
class_name SilkStock

const ART := preload("res://assets/inventory/estate-goods.png")
const NAMES := ["桑叶", "蚕茧", "生丝", "丝绸"]
const UNITS := ["片", "只", "份", "匹"]
const ICON_SIZE := 32

@export var card_style: StyleBox

var counts: Array[Label] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"h_separation", 6)
	add_theme_constant_override(&"v_separation", 5)
	for index in NAMES.size():
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if card_style:
			card.add_theme_stylebox_override(&"panel", card_style)
		add_child(card)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", 8)
		card.add_child(row)
		var region := AtlasTexture.new()
		region.atlas = ART
		region.region = Rect2(ICON_SIZE * (index + 1), 0, ICON_SIZE, ICON_SIZE)
		region.filter_clip = true
		var icon := TextureRect.new()
		icon.texture = region
		icon.texture_filter = TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_constant_override(&"separation", 0)
		row.add_child(text)
		_add_label(text, NAMES[index], 14, Color("#d7e0cb"))
		counts.append(_add_label(text, "", 17, Color("#f1d39a")))

func _add_label(parent: Control, copy: String, point_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_font_size_override(&"font_size", point_size)
	label.add_theme_color_override(&"font_color", ink)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	InterfaceFont.scale_reading_text(label)
	return label

func refresh(workshop: SilkWorkshop) -> void:
	var amounts := [workshop.leaves, workshop.cocoons, workshop.raw_silk, workshop.bolts]
	for index in counts.size():
		counts[index].text = "%d %s" % [amounts[index], UNITS[index]]
