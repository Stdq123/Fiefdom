extends RefCounted
class_name PavilionStories

const IDS := ["road_grain", "water_marks", "market_cloth", "watch_lantern"]
const STORIES := {
	"road_grain": {
		"speakers": [VisitorData.ROAD_KEEPER, VisitorData.FIELD_KEEPER],
		"title": "路粮匣",
		"memory": "季青和渠伯聊起你放进路粮匣的那捧谷。",
		"lines": [
			"方才有人赶路错过了饭点。我给他抓了一把匣里的谷，他在亭里嚼了好一会，才肯起身。",
			"我年轻时也这么赶过路。那时人家给我一捧菽，我留了一粒，回家才种下去。",
			"那就把匣底再擦一擦。下一捧留给谁，等他来了才知道。",
		],
	},
	"water_marks": {
		"speakers": [VisitorData.WATER_GUIDE, VisitorData.FIELD_KEEPER],
		"title": "一线渠水",
		"memory": "石墨和渠伯说起田苗第一次喝到渠水的那夜。",
		"lines": [
			"头一夜通水，我在水尺上挑了一道浅痕。今早又看了一眼，泥还在那儿。",
			"那晚我提着桶走到田边，站了片刻才想起来，今天不用再往井里去一趟。",
			"等秋水退了，咱们照着这道痕再看一遍。哪格要多留些水，田苗会告诉咱们。",
		],
	},
	"market_cloth": {
		"speakers": [VisitorData.SILK_MERCHANT, VisitorData.ROAD_KEEPER],
		"title": "绸边的结",
		"memory": "陶辛同季青说了蔡娘怎样在西市收好那匹样绸。",
		"lines": [
			"蔡娘没急着量尺寸。她先把咱们那匹布摊在阴里，说经线齐不齐，等天暗些反倒看得清。",
			"我给出门的人包粮，也要多等一息。手松开了，绳结还能稳住，才敢交给他。",
			"她也这么说。今早我过溪桥，特意停下来看看那个结。走了一路，一点没松。",
		],
	},
	"watch_lantern": {
		"speakers": [VisitorData.EAST_WATCHER, VisitorData.RAVINE_GUIDE],
		"title": "东路的一盏灯",
		"memory": "蒲宁听弋戎讲起守田后，东路上最后亮着的那盏灯。",
		"lines": [
			"上回守完田，我在东岗又站了一会。风从田埂过去，灯倒没灭。",
			"从竹径看来，那点灯像是落在草里的星。我知道有人还守着，就沿着亮处往回走。",
			"原来亭里也看得到。今后往东去得晚，就把灯再往路边挪半步。",
		],
	},
}

static func speakers(id: String) -> Array:
	return STORIES[id].speakers

static func available(id: String) -> bool:
	match id:
		"road_grain": return Global.road_provisions_delivered
		"water_marks": return Global.channel_survey_day > 0
		"market_cloth": return Global.silk_sample_day > 0
		"watch_lantern": return Global.east_watch_day > 0
	return false

static func heard_notes(speaker: String) -> Array[String]:
	var heard: Array[String] = []
	for id: String in IDS:
		if Global.pavilion_stories_heard.has(id) and speaker in speakers(id):
			heard.append(id)
	heard.sort_custom(func(a: String, b: String) -> bool:
		return Global.pavilion_stories_heard[a] < Global.pavilion_stories_heard[b])
	var notes: Array[String] = []
	for id: String in heard:
		notes.append("第 %d 天 · %s" % [Global.pavilion_stories_heard[id], STORIES[id].memory])
	return notes
