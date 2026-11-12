extends RefCounted
class_name RavineJournal

enum Site { BRIDGE, FORD, LOOKOUT }

const SITES := [
	{"name": "木桥西端", "position": RavineLayout.BRIDGE_JOURNAL, "path": "沿西岸主路向东，到木桥前。",
		"dry": "桥柱留着深浅两道水痕，平水刚过下面一道。",
		"rain": "雨水沿桥柱淌下，溪面已漫过平日那道水痕。"},
	{"name": "浅滩东岸", "position": RavineLayout.FORD_JOURNAL, "path": "从西岸林径的岔口向南，在浅滩东岸记下踏石。",
		"dry": "踏石朝上游的一侧被冲得发白，水退后便露出来。",
		"rain": "浅滩的踏石还露着白边，石间的水比平日急。"},
	{"name": "望溪台", "position": RavineLayout.LOOKOUT_JOURNAL, "path": "过木桥继续向东，沿山径拐向望溪台的背风处。",
		"dry": "石台背阴的一侧还润着，药苗都长在这边。",
		"rain": "台上竹叶挡住急雨，石沿慢慢滴水，根下的土还是松的。"},
]

var recorded_days: Array[int] = [0, 0, 0]
var garden_day := 0
var garden_harvest_day := 0

func count() -> int:
	return recorded_days.size() - recorded_days.count(0)

func complete() -> bool:
	return not recorded_days.has(0)

func next_site(day: int, raining: bool) -> int:
	if recorded_days.has(day):
		return -1
	# Rain favors the bridge. On dry days the starting point follows the date.
	var start := Site.BRIDGE if raining else posmod(day - 1, SITES.size())
	for offset in SITES.size():
		var site := (start + offset) % SITES.size()
		if recorded_days[site] == 0:
			return site
	return -1

func garden_wait(day: int, regrowth_days: int) -> int:
	return maxi(0, garden_harvest_day + regrowth_days - day) if garden_harvest_day > 0 else 0
