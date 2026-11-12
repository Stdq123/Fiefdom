extends RefCounted
class_name CreekTrap

const PLACES := ["柳湾竹笼", "砾滩竹笼"]
const ART := "res://assets/world/creek-trap.svg"
const BAITS := {
	"millet": {"name": "黍饵", "nights": 1, "amount": 1},
	"beans": {"name": "菽饵", "nights": 2, "amount": 2},
}

static func icon() -> AtlasTexture:
	var basket := AtlasTexture.new()
	basket.atlas = load(ART)
	basket.region = Rect2(20, 0, 28, 20)
	basket.filter_clip = true
	return basket
