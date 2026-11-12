extends Resource
class_name VisitorData

enum School { CONFUCIAN, MOHIST, TAOIST, MERCHANT, MILITARY }
enum VisitActivity { NONE, ROAD_REST, MEASURE, SILK, HERBS, WATCH, PAVILION_REST, TO_SILK_MARKET, SILK_MARKET }
enum SilkTrip { NONE, WEST_ROAD, STALL, RETURN_ROAD, PAVILION }

const FIELD_KEEPER := "渠伯"
const ROAD_KEEPER := "季青"
const SILK_MERCHANT := "陶辛"
const RAVINE_GUIDE := "蒲宁"
const EAST_WATCHER := "弋戎"
const WATER_GUIDE := "石墨"
const MUSIC_HOST := "商音"
const SILK_MARKET_PLACE := "西市绸摊"
const SILK_MARKET_PLAN := "晴天午、未时在西市绸摊，酉时到南路亭"
const SILK_MARKET_DEPART := (9.0 - Global.DAY_START_HOUR) / (Global.DAY_END_HOUR - Global.DAY_START_HOUR)
const SILK_MARKET_ARRIVE := (11.0 - Global.DAY_START_HOUR) / (Global.DAY_END_HOUR - Global.DAY_START_HOUR)
const SILK_MARKET_LEAVE := (15.0 - Global.DAY_START_HOUR) / (Global.DAY_END_HOUR - Global.DAY_START_HOUR)
const SILK_MARKET_RETURN := (17.0 - Global.DAY_START_HOUR) / (Global.DAY_END_HOUR - Global.DAY_START_HOUR)
const NEIGHBORS := [FIELD_KEEPER, ROAD_KEEPER, WATER_GUIDE, SILK_MERCHANT, RAVINE_GUIDE, EAST_WATCHER, MUSIC_HOST]
const SOUTH_POST := EstateLayout.PAVILION_TURN + Vector2(6, -27)
const BAMBOO_PATH := EstateLayout.BAMBOO_BEND + Vector2(-17, -8)
const EAST_POST := EstateLayout.EAST_WATCH + Vector2(-56, -10)
const RAVINE_PERSONA := {"name": RAVINE_GUIDE, "school": School.TAOIST, "place": "南边竹径"}
const EAST_PERSONA := {"name": EAST_WATCHER, "school": School.MILITARY, "place": "东路岗"}
const WATER_PERSONA := {"name": WATER_GUIDE, "school": School.MOHIST, "place": "水源旁"}
const PERSONAS := [
	{"name": ROAD_KEEPER, "school": School.CONFUCIAN, "place": "南路亭"},
	WATER_PERSONA,
	{"name": SILK_MERCHANT, "school": School.MERCHANT, "place": "西廊"},
	RAVINE_PERSONA,
	EAST_PERSONA
]
const ACTIVITY_STOPS := {
	VisitActivity.ROAD_REST: {"place": "亭西歇脚处", "task": "照看水瓮"},
	VisitActivity.MEASURE: {"place": "水源旁", "task": "看量水尺"},
	VisitActivity.SILK: {"place": "西廊绸架", "task": "整理样绸"},
	VisitActivity.TO_SILK_MARKET: {"place": SILK_MARKET_PLACE, "task": "沿西路赶集"},
	VisitActivity.SILK_MARKET: {"place": SILK_MARKET_PLACE, "task": "同蔡娘理绸"},
	VisitActivity.HERBS: {"place": "竹径药圃", "task": "查看药苗"},
	VisitActivity.WATCH: {"place": "东岗守备牌", "task": "查看守备"},
	VisitActivity.PAVILION_REST: {"place": "南路亭", "task": "灯下歇脚"},
}
const PAVILION_LINES := {
	ROAD_KEEPER: "灯一亮，远处的人就知道这里有个落脚处。你若手上的活做完了，来亭前坐坐。",
	WATER_GUIDE: "白日沿渠看水，到了亭下才发现鞋底还有半寸泥。歇一会儿，明早再去看看水口。",
	SILK_MERCHANT: "暮色落下来，白日的绸色都收进了包袱。赶路时最念着这一盏灯，和肯停下来谈两句的人。",
	RAVINE_GUIDE: "白日听的是桥下的水，这会儿听的是竹叶。坐一会儿，没准能分清哪一阵风从涧里来。",
	EAST_WATCHER: "天一暗，路边的脚步声倒听得更清。今晚我坐在亭前，也能望见东边的路口。",
}
const PAVILION_RAIN_LINES := {
	ROAD_KEEPER: "雨把路上的脚印都洗淡了。我把湿草鞋搁在檐边，等雨小些再穿。",
	WATER_GUIDE: "水从檐角滴下来，一滴接着一滴。明早去水口时，我想看看这一场雨涨了几分。",
	SILK_MERCHANT: "我把绸裹进干布里了。你也来檐下站站，衣裳贴着湿木柱会凉。",
	RAVINE_GUIDE: "檐下听雨正好。雨停后再去竹涧，浅滩的石头会比平日滑，记得走慢些。",
	EAST_WATCHER: "我把弓弦松了些，留在檐下避一避雨。远处若有动静，咱们还看得见东路。",
}
const RETURN_LINES := {
	ROAD_KEEPER: [
		["路旁的草又长起来了。等脚上的泥干些，我想坐在亭西，把那双旧草鞋再编紧一点。",
			"竹叶一响，我就想起刚借亭歇脚的时候。如今亭西有了长凳，路过的人肯多坐一会。"],
		["水瓮搁在亭西背阴处。你忙完田里的活，来坐一阵，听风穿过竹叶。",
			"长凳在亭荫里，坐着比赶路凉快。盛夏走得急，歇脚时也别急着把水喝尽。"],
		["亭西落了几片叶子，扫开就能坐。我想等新谷的香气飘过来，再续那双草鞋的底。",
			"秋风一吹，南路就显得远。亭西这张长凳留得住片刻，人再上路，脚步也轻些。"],
		["我在亭西坐了片刻，鞋上的霜才化。下回带一把干草来，垫在长凳上，坐着暖些。",
			"冬日赶路，最盼望有个背风处。你同我修的长凳就在亭西，忙完也来坐一坐。"],
	],
	WATER_GUIDE: [
		["春土一松，水声就比冬天清。我还记得头一棵靠渠水长起来的苗，水尺就是为它立的。",
			"水尺上沾了新泥，我留着没抹。过些日子再看，便知道这年春水来过多高。"],
		["日头照着田渠，水尺的一面暖，一面凉。我站在凉的这一面，听水慢慢过田埂。",
			"天热时看着渠水往前走，心也不急了。那天咱们蹲在水口看苗，我一直记得。"],
		["秋水清，尺上的刻痕看得分明。哪天田里收完了，咱们再沿渠走一回。",
			"枯叶会在渠口打转。我捞起一片夹进简册，留着比一比明年的水色。"],
		["水尺边结了点霜，刻痕还露着。入冬水声小了，我仍能听出它往哪块田去。",
			"冷天摸水尺，木头都凉透了。想起初次引水那夜的田苗，手里倒暖和些。"],
	],
	SILK_MERCHANT: [
		["春日的光软，最适合看布边。你那匹绸收得平，我总想让后来织的人也摸一摸。",
			"我把绸边举到春光下看，细线一根也分得清。织绸的人有耐性，布也记得。"],
		["暑气上来，绸样得收在阴处。你看这布边，换了几次天色，摸着还是平的。",
			"热天总有人问绸透不透风。我让他先摸摸你留下的样布，再慢慢挑。"],
		["秋风吹过布角，垂下来仍是整的。若要再织，记得也给自己留一匹好布。",
			"秋光照在绸上，颜色就沉一些。我收绸这些年，还是喜欢看人把第一匹织成。"],
		["冬日的手粗，摸绸前我先捂一捂。省得一道裂口，刮坏了细线。",
			"路冷，人便想把衣襟拢紧些。我把你那角绸收好，等春暖再给赶路的人看。"],
	],
	RAVINE_GUIDE: [
		["春水过桥时，我总想起你记的那几道水痕。有些地方同一个人再去看，便像换了样子。",
			"我把溪行手记翻到桥柱那页。新草遮住了岸边，你留下的字还认得出旧路。"],
		["竹阴正浓，桥下的水声隔着叶子传来。等你忙完，咱们也去听一会。",
			"你记过望溪台背阴的土。我照着那一页看药苗，日头最烈时，叶子也还能舒展。"],
		["浅滩边多了枯叶，踏石倒更白了。翻到你记的那页，我仿佛又走了一回。",
			"秋天看水，隔岸的石头都清楚。我想把溪行手记再读一遍，看看自己漏过了什么。"],
		["冬水细，桥柱的旧痕露出来更多。你那几页手记要收好，等春水来时还认得。",
			"竹叶上有霜，我听了好一会儿才听见溪声。冷天走累了，就沿旧路回来。"],
	],
	EAST_WATCHER: [
		["春草盖得住旧脚印，盖不住田埂。我沿东岗走过，想起咱们头回守这条路的样子。",
			"东岗的风从田里吹来，弓弦听着也轻些。田埂上能有一阵闲步，是好事。"],
		["天热，握弓的手容易出汗。我在东岗站一会，再换只手擦一擦，不急着放箭。",
			"东岗背阴处凉快。你若来坐，我就把弓靠在身边，讲讲以前赶夜路的事。"],
		["秋日望得远，田埂上谁走过都看得清。东岗那块牌子，我每次经过都要摸一摸。",
			"谷穗一低，脚下的路反倒显出来了。守过田以后，再看秋收，心里会踏实些。"],
		["东岗起风，我把袖口束紧了。弓弦收在干处，天冷时也得照看好。",
			"霜地上的脚印清楚，我走过之后又回头看了一眼。盼着今年冬天，田埂上只留熟人的脚印。"],
	],
}
const RAIN_LINES := {
	ROAD_KEEPER: "雨打在亭檐上，西边长凳还干着。赶路的人把蓑衣挂上，坐着等雨小些。你也去歇歇吧。",
	WATER_GUIDE: "细雨落在量水尺旁，水面像铺了线。我想起咱们头回蹲在水口看苗，袖子也湿成这样。",
	SILK_MERCHANT: "雨细，布边却不能受潮。我把样绸往西廊里收一点，等天晴了再给人看。",
	RAVINE_GUIDE: "雨落在竹叶上，听久了就分得出轻重。我把溪行手记收在衣里，等雨小些再翻。",
	EAST_WATCHER: "雨声把远处的脚步盖住了。我就在东岗近处走走，弓弦收好，等天放晴。",
}

@export var name := "旅人"
@export var school := School.CONFUCIAN
var meeting_place := "南路亭"
var is_recruited := false
var handoff_visit := false

static func for_day(day: int, retainer_names: Array[String]) -> VisitorData:
	# The first six mornings introduce the cast and give the first visitor a return visit.
	if day < 2 or (day > 7 and posmod(day, 7) in [0, 3]):
		return null
	for offset in PERSONAS.size():
		var persona: Dictionary = PERSONAS[posmod(day - 2 + offset, PERSONAS.size())]
		if persona["name"] not in retainer_names:
			return from_persona(persona)
	var data := VisitorData.new()
	data.name = "行旅 %d" % day
	data.school = posmod(day, School.size()) as School
	return data

static func from_persona(persona: Dictionary) -> VisitorData:
	var data := VisitorData.new()
	data.name = persona.name
	data.school = persona.school as School
	data.meeting_place = persona.place
	return data

func meeting_point(water_source: Vector2) -> Vector2:
	match meeting_place:
		"水源旁": return water_source + Vector2(-5, 21)
		"西廊": return EstateLayout.WEST_COURT
		"南边竹径": return BAMBOO_PATH
		"东路岗": return EAST_POST
	return SOUTH_POST

static func activity_on(speaker: String, day: int) -> VisitActivity:
	match speaker:
		ROAD_KEEPER:
			if Global.road_rest_paid_day > 0 and day > Global.road_rest_paid_day:
				return VisitActivity.ROAD_REST
		WATER_GUIDE:
			if Global.channel_survey_day > 0 and day >= Global.channel_survey_day:
				return VisitActivity.MEASURE
		SILK_MERCHANT:
			if Global.silk_sample_day > 0 and day >= Global.silk_sample_day:
				return VisitActivity.SILK
		RAVINE_GUIDE:
			var planted := Global.ravine_journal.garden_day
			if planted > 0 and day >= planted:
				return VisitActivity.HERBS
		EAST_WATCHER:
			if Global.east_watch_day > 0 and day >= Global.east_watch_day:
				return VisitActivity.WATCH
	return VisitActivity.NONE

static func scheduled_stop(speaker: String, meeting: String, day: int) -> String:
	var activity := activity_on(speaker, day)
	return meeting if activity == VisitActivity.NONE else ACTIVITY_STOPS[activity].place

static func silk_sample_on_display(day: int) -> bool:
	return Global.silk_sample_day > 0 and day > Global.silk_sample_day

static func silk_market_day(day: int) -> bool:
	return silk_sample_on_display(day) and not Global.has_rain(day)

func silk_trip() -> SilkTrip:
	if name != SILK_MERCHANT or is_recruited or not silk_market_day(Global.current_day):
		return SilkTrip.NONE
	if Global.day_progress < SILK_MARKET_DEPART:
		return SilkTrip.NONE
	if Global.day_progress < SILK_MARKET_ARRIVE:
		return SilkTrip.WEST_ROAD
	if Global.day_progress < SILK_MARKET_LEAVE:
		return SilkTrip.STALL
	if Global.day_progress < SILK_MARKET_RETURN:
		return SilkTrip.RETURN_ROAD
	return SilkTrip.PAVILION

static func seconds_since(progress: float) -> float:
	return maxf(0.0, (Global.day_progress - progress) * maxf(1.0, Global.balance.daylight_seconds))

func has_pavilion_rest() -> bool:
	if (not PAVILION_LINES.has(name) or Global.raid_day > 0
		or Global.last_defense.get("day", 0) == Global.current_day):
		return false
	match name:
		WATER_GUIDE:
			return not Global.water_review_ready() and Global.channel_survey_day != Global.current_day
		RAVINE_GUIDE:
			return not Global.ravine_handoff_ready() and Global.ravine_journal.garden_day != Global.current_day
		EAST_WATCHER:
			return not Global.defense_review_ready() and Global.east_watch_day != Global.current_day
	return true

static func pavilion_rest_seconds() -> float:
	var hour := 15.0 if Global.has_rain() else 17.0
	var start := inverse_lerp(Global.DAY_START_HOUR, Global.DAY_END_HOUR, hour)
	return (Global.day_progress - start) * maxf(Global.balance.daylight_seconds, 1.0)

static func pavilion_rest_plan() -> String:
	return "申时到南路亭避雨" if Global.has_rain() else "酉时到南路亭歇脚"

func pavilion_greeting() -> String:
	var lines := PAVILION_RAIN_LINES if Global.has_rain() else PAVILION_LINES
	return lines.get(name, greeting())

func talked_today() -> bool:
	return Global.visitor_encounters.get(name, 0) == Global.current_day

static func favor_completed(speaker: String) -> bool:
	match speaker:
		FIELD_KEEPER: return Global.field_rotation.signed_day > 0
		ROAD_KEEPER: return Global.road_provisions_delivered
		WATER_GUIDE: return Global.channel_survey_day > 0
		SILK_MERCHANT: return Global.silk_sample_day > 0
		RAVINE_GUIDE: return Global.ravine_journal.garden_day > 0
		EAST_WATCHER: return Global.east_watch_day > 0
		MUSIC_HOST: return not Global.gathering_recitals.is_empty()
	return false

func greeting() -> String:
	match name:
		ROAD_KEEPER:
			return road_keeper_line()
		WATER_GUIDE:
			return water_guide_line()
		SILK_MERCHANT:
			return silk_merchant_line()
		RAVINE_GUIDE:
			return ravine_guide_line()
		EAST_WATCHER:
			return east_watch_line()
	return "沿南路走了一日，见这里有片井田，借亭下歇一歇。"

static func water_guide_line() -> String:
	if Global.water_review_ready():
		return "第 %d 天，田苗靠渠水长了一夜。咱们在水口立把尺，我教你用绳放样，先看新渠要花多少钱、能润几格田。" % Global.first_channel_growth_day
	if Global.channel_survey_day > 0:
		var fields := Global.irrigated_well_fields()
		if fields == 0:
			return "水尺旁还有水声，田里却干着。挖渠时把鼠标移到褐色渠段，找找哪一格能把两头补接起来。"
		return "量水尺立在源头，渠水送到 %d 块井田。%s" % [fields, _return_line(WATER_GUIDE)]
	if Global.tech_unlocked["irrigation"]:
		return "蓝色渠段通了水，褐色渠段等着补接。把渠水送到一棵正在长的苗旁，过一夜，再来找我看水。"
	if Global.visitor_encounters.has(WATER_GUIDE):
		return "上回我记下了水口的高低。等你在堂里把书读到三阶，我们再动手挖渠。"
	return "我是石墨，路过听见水声，就绕进来看看。读书到三阶可学水利，沿水源开一段渠，近旁就能种稻。"

static func road_keeper_line(resident := false) -> String:
	if Global.road_rest_built():
		if Global.road_rest_used_day == Global.current_day:
			return "刚才你在亭西坐过，长凳上的凉意也散了。我把水瓮盖好，等下一个赶路的人。"
		return _return_line(ROAD_KEEPER)
	if Global.road_rest_paid_day > 0:
		return "木料已经搬到亭西。今夜把凳脚钉牢，再摆一瓮水，明早赶路的人就有地方坐了。"
	if Global.road_rest_requested():
		return "昨天又有人来取路粮，喝水时还站在风里。我想在亭西添张长凳和一瓮水。备齐木料得 %d 铜钱，你愿意一起办吗？" % Global.balance.road_rest_cost
	if Global.road_provisions_delivered:
		return "你留下的路粮，我放在亭边的木匣里了。谁赶路时饿了，尽管取一捧。我下次来，也会往里添一些。"
	if Global.road_provisions_requested():
		return "听说头一把谷已经入了国库。南路还有人赶着走，常错过一顿。若你手头有余，可匀一份私田收成作路粮。"
	if not Global.visitor_encounters.has(ROAD_KEEPER):
		return "在下季青，借南路亭歇脚。井田中央收的谷要入国库，四周的才归各家。我下回还想来看看这块地。"
	if resident:
		return "自打在这儿住下，我还惦记着南路亭。等公田第一次收成，我想同你商量一件事。"
	return "又见面了。我还记得你那块公田。等头一把谷入了国库，我想同你商量一件事。"

static func silk_merchant_line(resident := false) -> String:
	if Global.silk_sample_day > 0:
		if Global.silk_sample_day == Global.current_day:
			return "这匹绸的边织得平。留一角在西廊，余下的明早托蔡娘挂在西市。那件纹衣是给你的，就在堂屋衣架上。"
		var note := "西廊的绸样还在。" if resident else "又到西廊了，你织的样绸我还收着。"
		return note + _return_line(SILK_MERCHANT)
	if Global.silk_sample_requested():
		if Global.silk_workshop.bolts > 0:
			return "这一匹我想带去南路给人瞧瞧。你若肯匀给我，我按约好的价收，再留一角在西廊。"
		return "我想让南路的人看看这里织的绸。等你织好一匹，留给我作样。我下回到西廊，按样绸的价收。"
	return "我是陶辛，沿南路收绸。你在私田收下的桑叶能养蚕。等你有空，来西廊谈谈织绸的事。"

static func silk_market_line() -> String:
	if Global.attire_id == PlayerAttire.SAMPLE:
		return "蔡娘刚问谁织的这匹绸。你往这儿一站，衣上的纹和摊前的一照面，她就认出来了。"
	return "蔡娘特意把你的绸挂在朝街的一面。今早有人捻着布边问是谁家织的，我指了指东边的路。"

static func ravine_guide_line() -> String:
	if Global.ravine_journal.garden_day > 0:
		var wait := Global.herb_garden_wait()
		if wait > 0:
			return "药圃还要 %d 夜长回新叶。缺药时，可以先去望溪台看看。" % wait
		return "药圃已经长出新叶。" + _return_line(RAVINE_GUIDE)
	if Global.ravine_handoff_ready():
		return "桥柱、踏石和背阴的石台，你都记下了。照着台边的土性，我在竹径东侧育了一畦药苗，正好交给你照料。"
	if not Global.knows_ravine_journal():
		return "我叫蒲宁。想托你记下竹涧三处水迹，每天记一处。柳湾和砾滩也能垂钓，浮标沉了再提竿。记齐水迹就来竹径找我。"
	var site := Global.ravine_site_today()
	if site < 0:
		return "今天的竹简已经记好了。过一夜再出门，明日换一处看水。"
	return "今日先记%s。%s到立牌旁按 %s，把水迹记进手记。" % [
		RavineJournal.SITES[site].name, RavineJournal.SITES[site].path, GamepadInput.interact_key()]

static func east_watch_line(on_guard := false) -> String:
	if Global.raid_day > 0:
		return "东路还有%s。见脚下的红边就横着走，别让来敌一直贴着田。" % Global.raid_name(Global.raid_kind)
	if Global.defense_review_ready():
		var guard: String = Global.last_defense["guard"]
		var shot := "末一箭是你放的。" if guard.is_empty() else "%s放了末一箭。" % guard
		return "%s%s。把这一回刻在东岗牌上吧。下次发现踪迹，我会在预告里写明来敌。" % [
			shot, Global.defense_loss_note()]
	if Global.east_watch_day == Global.current_day:
		return "守备牌立好了。去东路岗翻开竹简，就知道上回是谁放了末一箭，田里又剩下多少。"
	if Global.east_watch_day > 0:
		return "东岗还记着第 %d 天的守备。%s" % [Global.last_defense["day"], _return_line(EAST_WATCHER)]
	if on_guard:
		return "我在东路看着。来敌时我会放箭，你先绕开它画在地上的那道红边。"
	if Global.visitor_encounters.has(EAST_WATCHER):
		return "我又去看了东路。望见烟尘就准备弓箭，别等人踏进田里。"
	return "我叫弋戎，顺路来看看东边的脚印。若肯让我留下，可在「管理」中派我守卫，来敌时我会放箭。"

static func _return_line(speaker: String) -> String:
	if Global.has_rain():
		return RAIN_LINES[speaker]
	var lines: Array = RETURN_LINES[speaker][Global.season_index()]
	return lines[posmod(Global.current_day + Global.get_current_year(), lines.size())]

func get_appearance_texture() -> Texture2D:
	var named := CharacterArt.neighbor_icon(name)
	return named if named else CharacterArt.visitor(school)

func get_school_name() -> String:
	match school:
		School.CONFUCIAN: return "儒者"
		School.MOHIST: return "墨者"
		School.TAOIST: return "行者"
		School.MERCHANT: return "行商"
		School.MILITARY: return "弓士"
	return "旅人"
