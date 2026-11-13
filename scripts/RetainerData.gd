extends Resource
class_name RetainerData

const NO_ASSIGNMENT := Vector2i.MIN
const EVENING_LINES := {
	VisitorData.FIELD_KEEPER: [
		"坐近些。木桶搁在田边一整日，连提梁都晒热了。等明早井水上来，才摸着凉。",
		"我小时候跟着家里人管田。黄昏没人催着下地，就在灯下把一日的事慢慢说完。",
		"锄头用久了，木柄会顺着手掌磨出一道亮痕。我那把舍不得换，明早你瞧瞧。",
		"田里的事我白天说得够多了。你要是不赶着回屋，讲讲今天在封地外见了谁吧。",
	],
	VisitorData.ROAD_KEEPER: [
		"往常走到这个时辰，我还在找人家借宿。如今从堂前走到亭下，几步就有人给我留席。",
		"水是傍晚新汲的。你忙到这会儿，先喝一口，粮簿可以坐下来慢慢翻。",
		"我学礼时，先生最先教的是让座。往里挪一点，人家才知道这儿还有他的地方。",
		"远行人到了晚上，总会先看哪家还点着灯。以前是我在路上张望，今晚轮到我等人。",
	],
	VisitorData.WATER_GUIDE: [
		"我方才从水口绕过来。白日总盯着水往哪儿走，到了这儿，才留心听见水声。",
		"量水的绳收在袖里了。今晚先不量高低，借亭下的灯把这几个旧绳结解开。",
		"水瓮有一道旧裂，我在底下垫了片瓦。你要挪它，记得把那片瓦也带上。",
		"我师父让我们先学磨木片，再学做器具。磨久了，闭上眼也知道哪一头高了半分。",
	],
	VisitorData.SILK_MERCHANT: [
		"赶市的人这时候都在收摊。以前我总数到最后一匹绸才肯坐下，今儿想早些来占个席。",
		"看了整日的布，眼里还晃着细纹。我坐到灯背后去，看一会儿路上的天色。",
		"在外头住店，我总把绸包当枕头，夜里有人碰一下就醒。如今卷好搁着，也能睡踏实。",
		"蔡娘称料时总多等一息，说秤杆摆稳了才好算账。我也得学她，收了工就坐得住。",
	],
	VisitorData.RAVINE_GUIDE: [
		"我回来时看见涧口起了薄雾。隔着那么远，亭前的灯倒比水边的路先认出来。",
		"夜里有人沿竹径走，脚步一停，虫声便又续上来。坐久了，连谁先到亭前也猜得出。",
		"我小时候去过一条很浅的溪，溪底的石头也有好多颜色。可惜那时没带简册，画不下来。",
		"翻过山的人常说，夜里才听得出村子有多远。我听见瓮边的碗响，就知道已经到了。",
	],
	VisitorData.EAST_WATCHER: [
		"从东边回来的路上听见有人说笑，才觉得这趟真的走到了家门口。",
		"我坐这边，正好看得见东路。今夜风轻，听见的都是熟人的脚步。",
		"以前跟人赶夜路，谁都不肯走最后。我倒喜欢走在后头，能看清哪一盏灯是自己人提的。",
		"跟我学箭的人常问弦要绷多紧。坐下之前我先把弦松了。弓跟人一样，整日绷着就使不上劲。",
	],
}

const RAIN_EVENING_LINES := {
	VisitorData.FIELD_KEEPER: [
		"蓑衣挂到柱外去吧。席是季青刚铺的，别让咱们带回来的水先坐下了。",
		"落到田里的雨是好事，落到饭碗里就嫌多。我把两只碗往里挪了挪。",
		"往年碰上下雨，我就在田埂上插把锄头记水线。今夜有人替我留了席，明早再去看也不迟。",
	],
	VisitorData.ROAD_KEEPER: [
		"我把靠外的席卷起来了。待会儿若有赶路的人，让他先坐靠灯的这一张。",
		"刚才雨里有人问哪儿有水喝。我把瓮沿擦干，挪到了柱后。你也喝一碗。",
		"屋檐下说话得靠近些。小时候家里下雨，也是几个人挤在一盏灯旁等饭熟。",
	],
	VisitorData.WATER_GUIDE: [
		"檐滴把石头冲出一道浅沟。你看，连半块瓦都晓得怎么引水。",
		"我在檐外放了个破陶碗。等雨歇了去瞧瞧，和田口的水痕能不能对上。",
		"绳子沾雨就缩，方才拿它量柱子，短了一指。明天去水口前得先晾干。",
	],
	VisitorData.SILK_MERCHANT: [
		"蔡娘教我把绸裹两层，外头一层沾雨，里头一层只贴着绸。今晚试过，果然管用。",
		"听檐下的雨，像织机上有人换梭。倒让我想起年轻时守着铺子等母亲收工。",
		"西市一落雨，卖布的人便都往同一处檐下挤。平日不肯透露的花样，这时候反倒肯讲两句。",
	],
	VisitorData.RAVINE_GUIDE: [
		"雨从竹叶上落下来，一阵密一阵疏。从瓦上落下来倒齐整，我坐着听了一会儿。",
		"你看那道水，过了亭柱就往竹径去了。我在涧里认路，也常先看雨水往哪边流。",
		"我带回几片干竹叶，夹在手记里。你要把湿鞋搁到檐边，垫上一片就不沾泥了。",
	],
	VisitorData.EAST_WATCHER: [
		"弓放在里侧，别让滴水碰到弦。东岗有人值守，我才得空坐这一会儿。",
		"泥地上先听见水，再听见脚步。你从路口过来时，我已经把干席给你往里推了。",
		"从前夜里遇上大雨，我们轮流抱着弓借火。今夜亭里灯是干的，够大家坐一阵。",
	],
}

@export var name: String = "无名氏"
@export var profession: String = "农夫" # Peasant, Scholar, etc.
@export var portrait: Texture2D

# 门客学派
enum School {
	NONE,       # 无学派（普通流民）
	CONFUCIAN,  # 儒家
	MOHIST,     # 墨家
	LEGALIST,   # 法家
	AGRARIAN,   # 农家
	MILITARY    # 兵家
}
@export var school: School = School.NONE
var visitor_appearance: int = -1

enum Duty { FIELD, REEL, TEACH, GUARD, HARVEST, STEWARD }
var duty: Duty = Duty.FIELD

# Attributes
@export_range(0, 100) var hunger: float = 0.0
@export_range(0, 100) var loyalty: float = 100.0
@export_range(0.1, 5.0) var efficiency: float = 1.0
var assigned_area := NO_ASSIGNMENT

func _init(p_name = "无名氏", p_prof = "农夫", p_school = School.NONE):
	name = p_name
	profession = p_prof
	school = p_school

func get_appearance_texture() -> Texture2D:
	var named := CharacterArt.neighbor_icon(name)
	if named:
		return named
	if visitor_appearance >= 0:
		return CharacterArt.visitor(visitor_appearance)
	return CharacterArt.retainer(school)

func duty_name() -> String:
	match duty:
		Duty.REEL: return "蚕桑缫丝"
		Duty.TEACH: return "礼仪教习"
		Duty.GUARD: return "封地守卫"
		Duty.HARVEST: return "田间收割"
		Duty.STEWARD: return "井田管事"
	return "田间照料"

func works_fields() -> bool:
	return duty in [Duty.FIELD, Duty.HARVEST, Duty.STEWARD]

func evening_line(in_rain := false) -> String:
	var greetings := RAIN_EVENING_LINES if in_rain else EVENING_LINES
	var lines: Array = greetings[name]
	return lines[posmod(Global.current_day + Global.season_index(), lines.size())]

func resident_line() -> String:
	if name == VisitorData.ROAD_KEEPER:
		if (duty == Duty.TEACH and Global.road_provisions_delivered and not Global.road_rest_requested()
			and Global.road_rest_paid_day == 0):
			return "今日教礼，我请大家先把一碗饭端给来客。亭里那一匣粮，就是你教我的那一课。"
		return VisitorData.road_keeper_line(true)
	if name == VisitorData.SILK_MERCHANT:
		return VisitorData.silk_merchant_line(true)
	if name == VisitorData.RAVINE_GUIDE:
		return VisitorData.ravine_guide_line()
	if name == VisitorData.EAST_WATCHER:
		return VisitorData.east_watch_line(duty == Duty.GUARD)
	if name == VisitorData.WATER_GUIDE:
		return VisitorData.water_guide_line()
	if name == VisitorData.FIELD_KEEPER and duty == Duty.FIELD:
		match Global.tax_reform_choice:
			Global.TaxReformChoice.TRADITIONAL:
				return "收谷的时候，公仓的筐我还会单放在门边。来收谷的人一到，就照咱们说定的数给。"
			Global.TaxReformChoice.REFORMED:
				return "从前井田中央那一捧谷得另装。如今筐都送去私仓，铜钱按新册结。"
		if Global.first_tribute_delivered():
			return "收进国库的头一捧谷，我看见了。我在田边歇脚，哪一格土色发白，就提桶过去。"
		if Global.current_day == 1:
			return "堂屋给你扫出来了，井里也汲得到水。打今儿起，这片采邑由你照管。\n中间一畦的谷要纳贡，四周的收成归你，可以换粮，也能留给西市的时令单。"
		return "木桶的箍我收紧了。井田中央那格要纳贡。下种后若还没浇水，我会去水口提一桶。"
	match duty:
		Duty.REEL:
			if Global.silk_workshop.night_reeling:
				if not Global.night_rations_plan().fed.has(self):
					return "蚕吃过桑叶了，咱们的晚饭还没着落。劳你先去看看粮仓，饭后我再把茧放进盆里。"
				return "水和篾片都备好了。饭后我会挑一只茧引线，明早来桑棚看看有多少丝。"
			return "你来缫丝时，我帮你守着水温。若想让我晚上接着做，在蚕桑页交代一声就行。"
		Duty.TEACH: return "堂前空着，我摆了席。晚饭后我在这儿讲礼，先学怎样迎送远道而来的人。"
		Duty.GUARD: return "我在东路看着。听见弓弦响，就先离开田埂，给我留一条射线。"
		Duty.HARVEST: return "镰刀已经磨好了。穗子一熟，我就去收。要是有一格得先收，把我拖到封地概览的那格田上。"
		Duty.STEWARD:
			return "井田 %d 交给我。庄稼熟了我来收，空畦照你交代的种子续上。出门前，记得看看粮仓。" % (
				Global.stewarded_field(self).field_id + 1)
	return "有没浇过的苗，我会提桶过去。你在封地概览里定好下茬的种子，我也能替你播种。"

func can_take_duty(next_duty: Duty) -> bool:
	match next_duty:
		Duty.FIELD, Duty.HARVEST, Duty.STEWARD: return true
		Duty.REEL: return school == School.MOHIST
		Duty.TEACH: return school == School.CONFUCIAN
		Duty.GUARD: return school == School.MILITARY
	return false

# 获取学派名称
func get_school_name() -> String:
	match school:
		School.NONE: return "流民"
		School.CONFUCIAN: return "儒家"
		School.MOHIST: return "墨家"
		School.LEGALIST: return "法家"
		School.AGRARIAN: return "农家"
		School.MILITARY: return "兵家"
		_: return "未知"

# 获取学派特质描述
func get_school_ability() -> String:
	match school:
		School.CONFUCIAN: return "安抚门客。安排教习可在过夜时提升礼与声望。"
		School.MOHIST: return "田间浇水更快。缫丝时能多取生丝，也可在蚕桑页委派夜间缫丝。"
		School.LEGALIST: return "法家之治：税收效率+20%"
		School.AGRARIAN: return "耕作专家：作物产量+50%"
		School.MILITARY: return "可分配守卫，在封地用弓射击来犯敌人。"
		_: return "无特殊能力"

# 应用学派特质（返回效率加成）
func apply_school_ability() -> Dictionary:
	var b = Global.balance
	var bonus = {
		"efficiency": 1.0,
		"special": null
	}

	match school:
		School.CONFUCIAN:
			bonus["efficiency"] = b.confucian_efficiency_bonus
			bonus["special"] = "loyalty_aura"
		School.MOHIST:
			bonus["efficiency"] = b.mohist_efficiency_bonus
			bonus["special"] = "auto_repair"
		School.LEGALIST:
			bonus["efficiency"] = b.legalist_efficiency_bonus
			bonus["special"] = "tax_bonus"
		School.AGRARIAN:
			bonus["efficiency"] = b.agrarian_efficiency_bonus
			bonus["special"] = "crop_bonus"
		School.MILITARY:
			bonus["efficiency"] = b.military_efficiency_bonus
			bonus["special"] = "auto_defend"
		_:
			bonus["efficiency"] = 1.0

	return bonus

func get_work_efficiency() -> float:
	return efficiency * float(apply_school_ability()["efficiency"])

# 随机生成门客
static func generate_random() -> RetainerData:
	var names = ["子路", "颜回", "子贡", "冉有", "子夏", "子游", "曾子", "子张"]
	var professions = ["士人", "农夫", "工匠", "商人"]
	var schools = [School.CONFUCIAN, School.MOHIST, School.LEGALIST, School.AGRARIAN, School.MILITARY]

	var retainer = RetainerData.new()
	retainer.name = names.pick_random()
	retainer.profession = professions.pick_random()
	retainer.school = schools.pick_random()
	retainer.loyalty = randi_range(Global.balance.retainer_loyalty_min, Global.balance.retainer_loyalty_max)
	retainer.efficiency = randf_range(Global.balance.retainer_efficiency_min, Global.balance.retainer_efficiency_max)

	return retainer
