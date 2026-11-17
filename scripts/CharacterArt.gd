extends RefCounted
class_name CharacterArt

const CAST_PATH := "res://assets/characters/cast.svg"
const NEIGHBOR_PORTRAITS := "res://assets/characters/neighbor-portraits.svg"
const RETAINER_MOTION := "res://assets/characters/retainer-motion.png"
const TOWN_PORTRAITS := "res://assets/characters/town-portraits.svg"
const TOWN_REGIONS := {
	"谷伯": Rect2(0, 0, 48, 48),
	"渔生": Rect2(48, 0, 48, 48),
	"蔡娘": Rect2(0, 48, 48, 48),
	"禾伯": Rect2(48, 48, 48, 48),
}
const CELL_SIZE := 32
const MOTION_COLUMNS := 4
const WORKER_COLUMNS := MOTION_COLUMNS + 2
const MOTION_ROWS := 3
const VISITOR_FIRST_ROW := 6
const WILD_DOG_ROW := 10
const SCOUT_ROW := 11
const WORKER_SLEEVES := [
	Color("#64777a"), Color("#638499"), Color("#617660"), Color("#a06951"), Color("#587963"),
	Color("#795a4d"), Color("#916675"),
	Color("#798173"), Color("#a99b78"), Color("#697572"), Color("#596766"), Color("#647e58"), Color("#98614e"),
	Color("#88908d"), Color("#65716b"), Color("#6f8766"), Color("#a8735a"), Color("#875f50"),
]

static func retainer(school: int, former_visitor := -1) -> AtlasTexture:
	return _worker_art(_worker_index("", school, former_visitor), Vector2(CELL_SIZE, CELL_SIZE))

static func retainer_motion(speaker: String, school: int, former_visitor: int) -> AtlasTexture:
	return _worker_art(_worker_index(speaker, school, former_visitor),
		Vector2(CELL_SIZE * WORKER_COLUMNS, CELL_SIZE * MOTION_ROWS))

static func retainer_sleeve(speaker: String, school: int, former_visitor: int) -> Color:
	return WORKER_SLEEVES[_worker_index(speaker, school, former_visitor)]

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
	return _neighbor_art(speaker, Vector2(CELL_SIZE * WORKER_COLUMNS, CELL_SIZE * MOTION_ROWS))

static func _neighbor_art(speaker: String, size: Vector2) -> AtlasTexture:
	var index := VisitorData.NEIGHBORS.find(speaker)
	if index < 0:
		return null
	return _worker_art(index, size)

static func _worker_art(index: int, size: Vector2) -> AtlasTexture:
	return _region(RETAINER_MOTION, Rect2(Vector2(0, index * CELL_SIZE * MOTION_ROWS), size))

static func _worker_index(speaker: String, school: int, former_visitor: int) -> int:
	var named := VisitorData.NEIGHBORS.find(speaker)
	if named >= 0:
		return named
	var generic := VisitorData.NEIGHBORS.size()
	if former_visitor >= 0:
		return generic + VISITOR_FIRST_ROW + clampi(former_visitor, 0, VisitorData.School.size() - 1)
	return generic + clampi(school, 0, VISITOR_FIRST_ROW - 1)

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
