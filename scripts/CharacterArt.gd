extends RefCounted
class_name CharacterArt

const NEIGHBOR_PORTRAITS := "res://assets/characters/neighbor-portraits.png"
const RETAINER_MOTION := "res://assets/characters/retainer-motion.png"
const TOWN_PORTRAITS := "res://assets/characters/town-portraits.png"
const FESTIVAL_MOTION := "res://assets/characters/autumn-guests.png"
const PORTRAIT_SIZE := 48
const TOWN_REGIONS := {
	"谷伯": Rect2(0, 0, 48, 48),
	"渔生": Rect2(48, 0, 48, 48),
	"蔡娘": Rect2(0, 48, 48, 48),
	"禾伯": Rect2(48, 48, 48, 48),
	"阿苓": Rect2(96, 0, 48, 48),
	"召简": Rect2(144, 0, 48, 48),
	"阿绥": Rect2(96, 48, 48, 48),
	"林蓼": Rect2(144, 48, 48, 48),
}
const CELL_SIZE := 32
const MOTION_COLUMNS := 4
const STREET_COLUMNS := MOTION_COLUMNS + 2
const WORK_COLUMN := MOTION_COLUMNS
const PASS_COLUMN := WORK_COLUMN + 2
const ERRAND_COLUMN := PASS_COLUMN + 2
const WORKER_COLUMNS := ERRAND_COLUMN + 2
const MOTION_ROWS := 3
const RETAINER_SCHOOLS := 6
const WORKER_SLEEVES := [
	Color("#82766d"), Color("#526b83"), Color("#809262"), Color("#ab714e"), Color("#677850"),
	Color("#976146"), Color("#a46877"),
	Color("#968877"), Color("#c8a263"), Color("#82766d"), Color("#6c6362"), Color("#677850"), Color("#976146"),
	Color("#968877"), Color("#82766d"), Color("#809262"), Color("#ab714e"), Color("#97654e"),
]

static func retainer(school: int, former_visitor := -1) -> AtlasTexture:
	return _worker_art(_worker_index("", school, former_visitor), Vector2(CELL_SIZE, CELL_SIZE))

static func retainer_motion(speaker: String, school: int, former_visitor: int) -> AtlasTexture:
	return _worker_art(_worker_index(speaker, school, former_visitor),
		Vector2(CELL_SIZE * WORKER_COLUMNS, CELL_SIZE * MOTION_ROWS))

static func retainer_sleeve(speaker: String, school: int, former_visitor: int) -> Color:
	return WORKER_SLEEVES[_worker_index(speaker, school, former_visitor)]

static func visitor(school: int, speaker := "") -> AtlasTexture:
	var guest := AutumnExhibit.GUESTS.find(speaker)
	if guest >= 0:
		return _region(FESTIVAL_MOTION, Rect2(0, guest * CELL_SIZE * MOTION_ROWS, CELL_SIZE, CELL_SIZE))
	return retainer(0, maxi(school, 0))

static func visitor_motion(school: int) -> AtlasTexture:
	return retainer_motion("", 0, maxi(school, 0))

static func festival_guest_motion(guest: int) -> AtlasTexture:
	return _region(FESTIVAL_MOTION, Rect2(0, guest * CELL_SIZE * MOTION_ROWS,
		CELL_SIZE * MOTION_COLUMNS, CELL_SIZE * MOTION_ROWS))

static func tax_envoy_icon() -> AtlasTexture:
	return _region("res://assets/characters/envoy-motion.png", Rect2(0, 0, CELL_SIZE, CELL_SIZE))

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
		return generic + RETAINER_SCHOOLS + clampi(former_visitor, 0, VisitorData.School.size() - 1)
	return generic + clampi(school, 0, RETAINER_SCHOOLS - 1)

static func visitor_portrait(school: int) -> AtlasTexture:
	var index := clampi(school, 0, VisitorData.School.size() - 1)
	return _region(TOWN_PORTRAITS, Rect2(index * PORTRAIT_SIZE, 2 * PORTRAIT_SIZE,
		PORTRAIT_SIZE, PORTRAIT_SIZE))

static func retainer_portrait(school: int, former_visitor: int) -> AtlasTexture:
	if former_visitor >= 0:
		return visitor_portrait(former_visitor)
	var index := clampi(school, 0, RETAINER_SCHOOLS - 1)
	return _region(TOWN_PORTRAITS, Rect2(index * PORTRAIT_SIZE, 3 * PORTRAIT_SIZE,
		PORTRAIT_SIZE, PORTRAIT_SIZE))

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
		"商音": frame = 13 if favor_done else 11
		_: return fallback
	return _region(NEIGHBOR_PORTRAITS, Rect2(frame * PORTRAIT_SIZE, 0, PORTRAIT_SIZE, PORTRAIT_SIZE))

static func _region(path: String, bounds: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(path)
	texture.region = bounds
	texture.filter_clip = true
	return texture
