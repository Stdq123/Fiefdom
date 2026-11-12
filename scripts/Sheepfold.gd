extends RefCounted
class_name Sheepfold

enum Action { BUY_SHEEP, BUY_FODDER, MIX_FODDER, SHEAR, SELL_WOOL, WEAVE_COAT }
enum Feed { NONE, PASTURE, FODDER, SHORTAGE }

const PLACE := "西坡羊棚"
const FEED_LABELS := ["", "用当日牧草", "用草料 1 份", "缺草 · 羊毛停长"]

var bought_day := 0
var fodder := 0
var wool_nights := 0
var wool := 0
var coat := false
var last_feed := Feed.NONE

func owned() -> bool:
	return bought_day > 0

func settle_night(feed: Feed, growth_target: int) -> void:
	last_feed = feed
	if feed == Feed.FODDER:
		fodder -= 1
	if feed != Feed.SHORTAGE:
		wool_nights = mini(wool_nights + 1, growth_target)

func save_record() -> Dictionary:
	return {"bought_day": bought_day, "fodder": fodder, "wool_nights": wool_nights,
		"wool": wool, "coat": coat, "last_feed": last_feed}
