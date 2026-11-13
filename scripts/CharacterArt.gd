extends RefCounted
class_name CharacterArt

const CAST_PATH := "res://assets/characters/cast.svg"
const NEIGHBOR_PORTRAITS := "res://assets/characters/neighbor-portraits.svg"
const NEIGHBOR_MOTION := "res://assets/characters/neighbor-motion.svg"
const TOWN_PORTRAITS := "res://assets/characters/town-portraits.png"
const TOWN_REGIONS := {
	"谷伯": Rect2(0, 0, 48, 48),
	"渔生": Rect2(48, 0, 48, 48),
	"蔡娘": Rect2(0, 48, 48, 48),
	"禾伯": Rect2(48, 48, 48, 48),
}
const CELL_SIZE := 32
const MOTION_COLUMNS := 4
const MOTION_ROWS := 3
const VISITOR_FIRST_ROW := 6
const WILD_DOG_ROW := 10
const SCOUT_ROW := 11
const NEIGHBOR_SLEEVES := [Color("#67777b"), Color("#688ba2"), Color("#617760"), Color("#ad6650"),
	Color("#577a61"), Color("#765142"), Color("#91636f")]

static func retainer(school: int) -> AtlasTexture:
	return _frame(clampi(school, 0, VISITOR_FIRST_ROW - 1))

static func visitor(school: int) -> AtlasTexture:
	if school == 4:
		return _frame(5) # The visiting soldier uses the military outfit.
	return _frame(VISITOR_FIRST_ROW + clampi(school, 0, WILD_DOG_ROW - VISITOR_FIRST_ROW - 1))

static func wild_dog() -> AtlasTexture:
	return _frame(WILD_DOG_ROW)

static func scout() -> AtlasTexture:
	return _frame(SCOUT_ROW)

static func tax_envoy_icon() -> AtlasTexture:
	return _region("res://assets/characters/envoy-motion.svg", Rect2(0, 0, CELL_SIZE, CELL_SIZE))

static func neighbor_icon(speaker: String) -> AtlasTexture:
	return _neighbor_art(speaker, Vector2(CELL_SIZE, CELL_SIZE))

static func neighbor_motion(speaker: String) -> AtlasTexture:
	return _neighbor_art(speaker, Vector2(CELL_SIZE * MOTION_COLUMNS, CELL_SIZE * MOTION_ROWS))

static func neighbor_sleeve(speaker: String) -> Color:
	var index := VisitorData.NEIGHBORS.find(speaker)
	return NEIGHBOR_SLEEVES[index] if index >= 0 else Color("#677479")

static func _neighbor_art(speaker: String, size: Vector2) -> AtlasTexture:
	var index := VisitorData.NEIGHBORS.find(speaker)
	if index < 0:
		return null
	return _region(NEIGHBOR_MOTION, Rect2(Vector2(0, index * CELL_SIZE * MOTION_ROWS), size))

static func dialogue_portrait(speaker: String, fallback: Texture2D, favor_done: bool) -> Texture2D:
	if TOWN_REGIONS.has(speaker):
		return _region(TOWN_PORTRAITS, TOWN_REGIONS[speaker])
	var frame: int
	match speaker:
		VisitorData.FIELD_KEEPER: frame = 12 if favor_done else 0
		"季青": frame = 2 if favor_done else 1
		"陶辛": frame = 4 if favor_done else 3
		"蒲宁": frame = 6 if favor_done else 5
		"弋戎": frame = 8 if favor_done else 7
		"石墨": frame = 10 if favor_done else 9
		"商音": frame = 11
		_: return fallback
	return _region(NEIGHBOR_PORTRAITS, Rect2(frame * 48, 0, 48, 48))

static func _frame(row: int) -> AtlasTexture:
	return _region(CAST_PATH, Rect2(0, row * CELL_SIZE, CELL_SIZE, CELL_SIZE))

static func _region(path: String, bounds: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(path)
	texture.region = bounds
	texture.filter_clip = true
	return texture
