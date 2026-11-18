extends RefCounted
class_name HUDIcons

enum Symbol {
	BACKPACK, MAP, SETTINGS, COIN, CALENDAR, SUN, RAIN, MOON, HEALTH, STAMINA, GRAIN, TREASURY,
	HOE, WATER, LEDGER, RATIONS, MILLET, SORGHUM, RICE, WHEAT, BEANS, MULBERRY, HEMP,
}

const SHEET_PATH := "res://assets/ui/hud-symbols.png"
const SKY: Array[Symbol] = [Symbol.SUN, Symbol.RAIN, Symbol.MOON]
const CROPS := {
	"millet": Symbol.MILLET,
	"sorghum": Symbol.SORGHUM,
	"rice": Symbol.RICE,
	"wheat": Symbol.WHEAT,
	"beans": Symbol.BEANS,
	"mulberry": Symbol.MULBERRY,
	"hemp": Symbol.HEMP,
}

static var _sheet: Texture2D
static var _icons: Dictionary[int, AtlasTexture] = {}

static func icon(symbol: Symbol) -> AtlasTexture:
	if _icons.has(symbol):
		return _icons[symbol]
	if not _sheet:
		_sheet = load(SHEET_PATH)
	var texture := AtlasTexture.new()
	texture.atlas = _sheet
	texture.region = Rect2(16 * symbol, 0, 16, 16)
	texture.filter_clip = true
	_icons[symbol] = texture
	return texture

static func sky_index() -> int:
	return 1 if Global.has_rain() else (2 if Global.day_progress >= 0.72 else 0)
