extends RefCounted
class_name HUDIcons

enum Symbol {
	BACKPACK, MAP, SETTINGS, COIN, CALENDAR, SUN, RAIN, MOON, HEALTH, STAMINA, GRAIN, TREASURY,
	HOE, WATER, LEDGER, RATIONS, MILLET, SORGHUM, RICE, WHEAT, BEANS, MULBERRY, HEMP, SNOW,
}

const SHEET_PATH := "res://assets/ui/hud-symbols.png"
const SNOW_PATH := "res://assets/ui/hud-snow.png"
const SKY: Array[Symbol] = [Symbol.SUN, Symbol.RAIN, Symbol.MOON, Symbol.SNOW]
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
	var texture := AtlasTexture.new()
	if symbol == Symbol.SNOW:
		texture.atlas = load(SNOW_PATH)
		texture.region = Rect2(0, 0, 16, 16)
	else:
		if not _sheet:
			_sheet = load(SHEET_PATH)
		texture.atlas = _sheet
		texture.region = Rect2(16 * symbol, 0, 16, 16)
	texture.filter_clip = true
	_icons[symbol] = texture
	return texture

static func sky_index(day := 0) -> int:
	match Global.weather_on(day):
		Global.Weather.RAIN: return 1
		Global.Weather.LIGHT_SNOW, Global.Weather.HEAVY_SNOW: return 3
	return 2 if day <= 0 and Global.day_progress >= 0.72 else 0
