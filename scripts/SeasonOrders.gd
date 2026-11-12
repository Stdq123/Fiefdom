extends RefCounted
class_name SeasonOrders

const TERMS_PER_SEASON := 6
const EVENING_DISPATCH := 11.0 / 16.0
const MORNING_DISPATCH := 1.0 / 16.0
const TRAVEL_FRACTION := 0.12
const SILK_ITEM := "silk_bolt"
const ORDERS := [
	{
		"id": "spring", "title": "亭前备种", "speaker": "季青",
		"request": "南路有人刚分到地。匀两份菽、一份黍，我把能留种的挑出来送去。",
		"need": {"beans": 2, "millet": 1},
		"thanks": "季青托人把菽和黍分进两个布袋，路上可以分给新领田的人。",
		"arrival": "季青托的菽和黍都到了。南路上新分到地的几户人家，来亭里就能领种。"
	},
	{
		"id": "summer", "title": "新稻到亭", "speaker": "石墨",
		"request": "下游有几家也在量水口。若井田引得来水，留两份新稻给他们看看。",
		"need": {"rice": 2},
		"thanks": "石墨在稻袋上绑了截量渠的绳，留给下游照着比量。",
		"arrival": "石墨的两袋新稻在卸货场码好了。下游的人来取稻时，袋口那截量水的绳也一并带走。"
	},
	{
		"id": "autumn", "title": "东岗秋粮", "speaker": "弋戎",
		"request": "巡到天凉，得带点能下锅的。两份稷加一份菽，够东岗添一锅饭。",
		"need": {"sorghum": 2, "beans": 1},
		"thanks": "稷和菽已分袋。弋戎托人来亭里接走，给换岗的人添一锅饭。",
		"arrival": "东岗的稷和菽已送到。等弋戎的人来换岗，我叫他们把两袋都捎上。"
	},
	{
		"id": "winter", "title": "冬路粮与麻", "speaker": "陶辛",
		"request": "我要赶在岁末前走一趟南路。留两份麦作路粮，再带一束麻回西廊捻线。",
		"need": {"wheat": 2, "hemp": 1},
		"thanks": "陶辛托人把麦和麻扎好，麦留作路粮，麻带去西廊。",
		"arrival": "陶辛的麦和麻都到了。麦留在亭前给赶路的人，麻等他来带回西廊捻线。"
	}
]

const FOLLOW_UP_ORDERS := [
	{
		"id": "spring_seed_share", "title": "南路续种", "speaker": "季青",
		"request": "南路又开了几畦地。留两份菽和两份黍作种，再捎一份冬麦给来取种的人。",
		"need": {"beans": 2, "millet": 2, "wheat": 1},
		"thanks": "留种的菽和黍已分好。冬麦另装一袋，到了亭前可先做顿饭。",
		"arrival": "菽和黍已经送到。季青正教新领田的人挑种，亭下那袋麦留着做饭。"
	},
	{
		"id": "summer_willow_catch", "title": "柳湾夏鲜", "speaker": "石墨",
		"request": "下游这几日都在修渠。备两份新稻，再到柳湾钓一尾白鲦，我给渠边的人送饭。",
		"need": {"rice": 2}, "fish": "minnow",
		"thanks": "稻已入袋，白鲦装进带水的鱼篓。申禾会把两样都送到南路卸货场。",
		"arrival": "石墨刚派人取走了稻和白鲦。听说下游的水口已经通了，今晚能在渠边吃顿热饭。"
	},
	{
		"id": "autumn_watch_relief", "title": "东岗换防", "speaker": "弋戎",
		"request": "换岗的人这回要走远些。两份稷和一份菽作路粮，再带一束麻来修旗绳。",
		"need": {"sorghum": 2, "beans": 1, "hemp": 1},
		"thanks": "巡粮和麻已捆好。新换岗的人会从南路亭领走。",
		"arrival": "弋戎的人已经来领路粮。麻绳要换到东岗的旗上，起风时就看得见。"
	},
	{
		"id": "winter_woven_goods", "title": "岁末麦帛", "speaker": "陶辛",
		"request": "赶冬路的几户想换些布缝行囊。请捎两份麦作路粮，再从蚕棚带一匹丝绸来。",
		"need": {"wheat": 2}, "silk": 1,
		"thanks": "麦袋和丝绸分开扎好了。路上遇雪，申禾会先把布包进车篷。",
		"arrival": "麦和丝绸都到了。陶辛正在亭前量布，那几户人家赶在年前也能带着新行囊上路。"
	},
]

static func window(day: int, days_per_term: int) -> Dictionary:
	var length := TERMS_PER_SEASON * maxi(1, days_per_term)
	var period := floori(float(maxi(day, 1) - 1) / length)
	var start := period * length + 1
	var season := period % ORDERS.size()
	var original: Dictionary = ORDERS[season]
	var order: Dictionary = original if period < ORDERS.size() else FOLLOW_UP_ORDERS[season]
	return {"start": start, "end": start + length - 1, "order": order, "original_order": original}

static func cargo(order: Dictionary) -> Dictionary:
	var goods: Dictionary = order.need.duplicate()
	if order.has("fish"):
		goods[order.fish] = 1
	if order.has("silk"):
		goods[SILK_ITEM] = order.silk
	return goods

static func dispatch_day(day: int, clock: float) -> int:
	return day + int(clock >= EVENING_DISPATCH)

static func transit_progress(receipt: Dictionary, day: int, clock: float) -> float:
	var scheduled_day: int = receipt.dispatch_day
	var start := MORNING_DISPATCH if scheduled_day > receipt.day else EVENING_DISPATCH
	return (float(day - scheduled_day) + clock - start) / TRAVEL_FRACTION

static func dispatch_caption(receipt: Dictionary) -> String:
	var watch := "辰时" if receipt.dispatch_day > receipt.day else "酉时"
	return "第 %d 天%s发车" % [receipt.dispatch_day, watch]
