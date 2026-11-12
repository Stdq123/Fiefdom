extends RefCounted
class_name PlayerAttire

const ORIGINAL_PATH := "res://assets/characters/player.svg"
const VARIANTS_PATH := "res://assets/characters/player-attire.svg"
const DEFAULT := "cloth"
const SAMPLE := "dyed"
const WOOL := "wool"
const SHEET_SIZE := 96
const FRAME_SIZE := 32

const CATALOG := {
	"cloth": {"name": "黛布短衣", "detail": "深色布衣 · 木簪", "sheet": -1, "rank": 0, "sleeve": Color("#7d8e83")},
	"rust": {"name": "赭布短衣", "detail": "赭染布衣 · 窄袖", "sheet": 0, "rank": 0, "sleeve": Color("#b36c4b")},
	"hemp": {"name": "本色麻衣", "detail": "素麻短衣 · 骨簪", "sheet": 1, "rank": 1, "sleeve": Color("#a89a62")},
	"silk": {"name": "湖青绸衣", "detail": "青绸斜领 · 玉簪", "sheet": 2, "rank": 2, "sleeve": Color("#539997")},
	"dyed": {"name": "西廊纹衣", "detail": "陶辛赠的绛衣 · 米色菱纹", "sheet": 3, "rank": 0, "sleeve": Color("#ab596e")},
	"brocade": {"name": "紫纹锦衣", "detail": "紫锦 · 金边袖口", "sheet": 4, "rank": 3, "sleeve": Color("#795f9e")},
	"fur": {"name": "裘衣礼冠", "detail": "裘衣披肩 · 礼冠", "sheet": 5, "rank": 4, "sleeve": Color("#dbba8a")},
	"wool": {"name": "羊毛短衣", "detail": "蔡娘织的青灰毛衣 · 浅色领边", "sheet": 6, "rank": 0, "sleeve": Color("#e1d3ba")},
}

static func can_wear(id: String, rank: int, sample_delivered: bool, wool_coat: bool) -> bool:
	return (CATALOG.has(id) and rank >= CATALOG[id].rank
		and (id != SAMPLE or sample_delivered) and (id != WOOL or wool_coat))

static func texture(id: String) -> Texture2D:
	if id == DEFAULT:
		return load(ORIGINAL_PATH)
	return _region(id, 0, SHEET_SIZE)

static func preview(id: String, direction: int) -> AtlasTexture:
	return _region(id, direction * FRAME_SIZE, FRAME_SIZE)

static func _region(id: String, top: int, size: int) -> AtlasTexture:
	var sheet: int = CATALOG[id].sheet
	var artwork := AtlasTexture.new()
	artwork.atlas = load(ORIGINAL_PATH if sheet < 0 else VARIANTS_PATH)
	artwork.region = Rect2(0, maxi(0, sheet) * SHEET_SIZE + top, size, size)
	artwork.filter_clip = true
	return artwork
