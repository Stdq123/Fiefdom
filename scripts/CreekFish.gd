extends RefCounted
class_name CreekFish

enum Site { POOL, SHOAL, POND }

const ORDER_PICKUP := 11.0 / 16.0
const ATLAS := preload("res://assets/world/creek-fish.svg")
const PLACES := ["柳湾", "砾滩", "南池钓台"]
const IDS := ["crucian", "minnow", "carp", "perch"]
const SPECIES := {
	"crucian": {"name": "鲫鱼", "food": 4, "copper": 8, "bite": 1.18, "reel": 1.1, "pull": 0.57,
		"habitat": "春秋冬的柳湾，冬日的砾滩。南池钓台开放后也能钓到。"},
	"minnow": {"name": "白鲦", "food": 3, "copper": 9, "bite": 1.05, "reel": 1.2, "pull": 0.61,
		"habitat": "夏日在柳湾缓水中靠岸。"},
	"carp": {"name": "鲤鱼", "food": 6, "copper": 12, "bite": 0.98, "reel": 1.45, "pull": 0.67,
		"habitat": "春夏在砾滩，谷雨的柳湾也会见到。"},
	"perch": {"name": "鳜鱼", "food": 5, "copper": 16, "bite": 0.88, "reel": 1.65, "pull": 0.72,
		"habitat": "秋日去浅滩东岸的砾滩找它。"},
}
const SEASON_CATCH := [
	["crucian", "minnow", "crucian", "crucian"],
	["carp", "carp", "perch", "crucian"],
	["crucian", "crucian", "crucian", "crucian"],
]
const MARKET_ORDERS := [
	{"fish": "carp", "request": "西路上有人刚修完渠，托我留一尾鲤鱼，下工时好煮汤。",
		"thanks": "修渠的人下工就能喝上鲤鱼汤了。"},
	{"fish": "minnow", "request": "夏天的白鲦要趁鲜。亭前有人买了新稻，想搭一尾下锅。",
		"thanks": "这尾白鲦正好配亭前人家的新稻。"},
	{"fish": "perch", "request": "东路几户来换新谷，临走想带一尾砾滩的鳜鱼回家。",
		"thanks": "东路的人换过新谷，回去正好带上这尾鳜鱼。"},
	{"fish": "crucian", "request": "北街的小灶要留一尾鲫鱼。天一冷，有碗汤才好下饭。",
		"thanks": "这尾鲫鱼给北街的小灶熬汤，暖暖手。"},
]

static func at(site: int, season: int, raining: bool) -> String:
	if site < 0 or site >= PLACES.size() or season < 0 or season >= SEASON_CATCH[0].size():
		return ""
	if site == Site.POOL and raining:
		return "carp"
	return SEASON_CATCH[site][season]

static func portrait(id: String) -> AtlasTexture:
	var icon := AtlasTexture.new()
	icon.atlas = ATLAS
	icon.region = Rect2(IDS.find(id) * 16, 0, 16, 16)
	icon.filter_clip = true
	return icon
