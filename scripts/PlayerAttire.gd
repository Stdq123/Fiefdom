extends RefCounted
class_name PlayerAttire

const ORIGINAL_PATH := "res://assets/characters/player.png"
const VARIANTS_PATH := "res://assets/characters/player-attire.png"
const DEFAULT := "cloth"
const SAMPLE := "dyed"
const WOOL := "wool"
const SHEET_SIZE := 96
const FRAME_SIZE := 32
const WORK_COLUMN := 3
const PASS_COLUMN := WORK_COLUMN + 2
const SHEET_WIDTH := FRAME_SIZE * (PASS_COLUMN + 2)
# Sole centers relative to the sprite origin for columns 1 and 2 of each facing.
const PLANTED_SOLES := [
	[Vector2(-4.0, 15.0), Vector2(4.0, 15.0)],
	[Vector2(3.5, 15.0), Vector2(-4.0, 15.0)],
	[Vector2(4.5, 12.5), Vector2(3.0, 13.0)],
]

const CATALOG := {
	"cloth": {"name": "黛布短衣", "detail": "深色布衣 · 木簪", "sheet": -1, "rank": 0, "sleeve": Color("#82766d")},
	"rust": {"name": "赭布短衣", "detail": "赭染布衣 · 窄袖", "sheet": 0, "rank": 0, "sleeve": Color("#976146")},
	"hemp": {"name": "本色麻衣", "detail": "素麻短衣 · 骨簪", "sheet": 1, "rank": 1, "sleeve": Color("#afa07a")},
	"silk": {"name": "湖青绸衣", "detail": "青绸斜领 · 玉簪", "sheet": 2, "rank": 2, "sleeve": Color("#62877a")},
	"dyed": {"name": "西廊纹衣", "detail": "陶辛赠的绛衣 · 米色菱纹", "sheet": 3, "rank": 0, "sleeve": Color("#a05c4c")},
	"brocade": {"name": "紫纹锦衣", "detail": "紫锦 · 金边袖口", "sheet": 4, "rank": 3, "sleeve": Color("#835668")},
	"fur": {"name": "裘衣礼冠", "detail": "裘衣披肩 · 礼冠", "sheet": 5, "rank": 4, "sleeve": Color("#c8a263")},
	"wool": {"name": "羊毛短衣", "detail": "蔡娘织的青灰毛衣 · 浅色领边", "sheet": 6, "rank": 0, "sleeve": Color("#a8a391")},
}

static func can_wear(id: String, rank: int, sample_delivered: bool, wool_coat: bool) -> bool:
	return (CATALOG.has(id) and rank >= CATALOG[id].rank
		and (id != SAMPLE or sample_delivered) and (id != WOOL or wool_coat))

static func texture(id: String) -> Texture2D:
	if id == DEFAULT:
		return load(ORIGINAL_PATH)
	return _region(id, Rect2(0, 0, SHEET_WIDTH, SHEET_SIZE))

static func preview(id: String, direction: int) -> AtlasTexture:
	return _region(id, Rect2(0, direction * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE))

static func planted_sole(frame: Vector2i, mirrored: bool) -> Vector2:
	var sole: Vector2 = PLANTED_SOLES[frame.y][frame.x - 1]
	return Vector2(-sole.x, sole.y) if mirrored else sole

static func _region(id: String, bounds: Rect2) -> AtlasTexture:
	var sheet: int = CATALOG[id].sheet
	var artwork := AtlasTexture.new()
	artwork.atlas = load(ORIGINAL_PATH if sheet < 0 else VARIANTS_PATH)
	bounds.position.y += maxi(0, sheet) * SHEET_SIZE
	artwork.region = bounds
	artwork.filter_clip = true
	return artwork
