extends RefCounted
class_name HUDIcons

enum Symbol { BACKPACK, MAP, SETTINGS, COIN, CALENDAR, SUN, RAIN, MOON, HEALTH, STAMINA, GRAIN, TREASURY }

const SHEET := preload("res://assets/ui/hud-symbols.svg")
const SKY: Array[Symbol] = [Symbol.SUN, Symbol.RAIN, Symbol.MOON]

static func icon(symbol: Symbol) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = SHEET
	texture.region = Rect2(16 * symbol, 0, 16, 16)
	texture.filter_clip = true
	return texture

static func sky_index() -> int:
	return 1 if Global.has_rain() else (2 if Global.day_progress >= 0.72 else 0)
