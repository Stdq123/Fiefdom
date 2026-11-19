extends Button

const TOOLTIP := preload("res://scenes/CropTooltip.tscn")
const CARDS := {
	"millet": {
		"glyph": preload("res://assets/farming/ancient-characters/millet.png"),
		"period": "西周金文", "note": "生長較快，適合種在公田納貢。",
	},
	"sorghum": {
		"glyph": preload("res://assets/farming/ancient-characters/sorghum.png"),
		"period": "戰國晚期金文", "note": "可留作秋季交貨，送往東崗備糧。",
	},
	"rice": {
		"glyph": preload("res://assets/farming/ancient-characters/rice.png"),
		"period": "春秋早期金文", "note": "有渠水的田格才能播種。\n斷水時停長。",
	},
	"wheat": {
		"glyph": preload("res://assets/farming/ancient-characters/wheat.png"),
		"period": "西周金文", "note": "可煮粥或配草料。\n冬季交貨也用得到。",
	},
	"beans": {
		"glyph": preload("res://assets/farming/ancient-characters/beans.png"),
		"period": "", "note": "豆類。收菽後留下地力，\n下一茬非菽作物多收一份。",
	},
	"mulberry": {
		"glyph": preload("res://assets/farming/ancient-characters/mulberry.png"),
		"period": "戰國楚簡", "note": "私田可採桑葉餵蠶。\n採葉後桑樹仍會生長。",
	},
	"hemp": {
		"glyph": preload("res://assets/farming/ancient-characters/hemp.png"),
		"period": "春秋金文", "note": "可留作時令交貨，\n也可種在私田換取銅錢。",
	},
}

var crop_id: String
var crop_picture: Dictionary
var sowing_hint: String

func _draw() -> void:
	if button_pressed:
		var lip := Vector2(floorf(size.x / 2.0), size.y - 3.0)
		draw_colored_polygon(PackedVector2Array([lip + Vector2(-5, 0), lip + Vector2(0, -4),
			lip + Vector2(5, 0)]), Color("#f7d694"))

static func display_name(id: String, crop_name: String) -> String:
	return "麥" if id == "wheat" else crop_name

func setup(id: String, crop_name: String, picture: Dictionary) -> void:
	crop_id = id
	crop_picture = picture
	accessibility_name = display_name(id, crop_name)

func refresh_tooltip(crop: CropData, nights: int) -> void:
	sowing_hint = "%s供水 %d 夜後成熟" % ["初栽 · " if crop.is_perennial else "", nights]
	if not GamepadInput.active:
		sowing_hint += " · %s 換種" % Preferences.seed_label(crop_id)
	if crop.favored_season >= 0:
		var in_season := crop.sowing_nights(crop.favored_season, Global.balance.seasonal_growth_reduction)
		var saving := crop.days_to_grow - in_season
		if saving > 0:
			sowing_hint += "\n%s播少等 %d 夜" % [Global.SEASON_NAMES[crop.favored_season], saving]
	accessibility_description = "%s\n%s" % [CARDS[crop_id].note, sowing_hint]
	tooltip_text = "%s\n%s" % [accessibility_name, accessibility_description]

func _make_custom_tooltip(for_text: String) -> Control:
	if for_text.is_empty():
		return null
	var entry: Dictionary = CARDS[crop_id]
	var card := TOOLTIP.instantiate() as PanelContainer
	card.get_node("%AncientGlyph").texture = entry.glyph
	var sprite := card.get_node("%CropSprite") as TextureRect
	sprite.texture = crop_picture.texture
	sprite.self_modulate = crop_picture.tint
	card.get_node("%CropName").text = accessibility_name
	var period := card.get_node("%Period") as Label
	period.text = entry.period
	period.visible = not period.text.is_empty()
	var notes := card.get_node("%Notes") as Label
	var timing := card.get_node("%SowingHint") as Label
	var reading_width: float = notes.get_parent_control().custom_minimum_size.x
	# Establish the wrap width before the popup asks for its minimum height.
	notes.size.x = reading_width
	timing.size.x = reading_width
	notes.text = entry.note
	timing.text = sowing_hint
	for label: Label in [card.get_node("%CropName"), period, notes, timing]:
		InterfaceFont.scale_reading_text(label)
	card.reset_size()
	return card
