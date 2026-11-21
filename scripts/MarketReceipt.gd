extends PanelContainer
class_name MarketReceipt

signal presented

const INK := Color("#e9ddb7")
const WARNING_INK := Color("#ffc399")

@onready var art: TextureRect = $Row/Art
@onready var label: Label = $Row/Text

var text: String:
	get: return label.text

func _ready() -> void:
	InterfaceFont.scale_reading_text(label)

func present(message: String, picture: Texture2D, warning := false) -> void:
	label.text = message
	label.add_theme_color_override(&"font_color", WARNING_INK if warning else INK)
	art.texture = picture
	show()
	presented.emit()

func present_crops(message: String, lots: Dictionary) -> void:
	var id: String = lots.keys().front() if lots.size() == 1 else CropStock.MIXED
	present(message, ItemManager.harvest_icon(id))

func clear() -> void:
	hide()
	label.text = ""
	art.texture = null
