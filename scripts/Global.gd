extends Node

const SAVE_PATH := "user://savegame.json"
const AUTO_SAVE_PATHS := ["user://autosave-1.json", "user://autosave-2.json", "user://autosave-3.json"]
const CAMPAIGN_SAVE_ROOT := "user://campaigns"
const SAVE_VERSION := 2
const SAVE_TIME_SCALE := 1000000
const TITLE_SCENE := "res://scenes/Title.tscn"
const ESTATE_SCENE := "res://scenes/Main.tscn"
const WILDERNESS_SCENE := "res://scenes/Wilderness.tscn"
const WEST_ROAD_SCENE := "res://scenes/WestRoad.tscn"
const WEST_MARKET_SCENE := "res://scenes/WestMarket.tscn"
const SAVE_SCENES := {"estate": ESTATE_SCENE, "ravine": WILDERNESS_SCENE,
	"west_market": WEST_MARKET_SCENE, "west_road": WEST_ROAD_SCENE}
const SAVE_LOCATION_NAMES := {"ravine": "竹涧", "west_market": "西市", "west_road": "溪桥道"}
const RAVINE_TRIP_PLACES := ["野果坳", "望溪台", "柳湾", "砾滩", SummerRaft.PLACE]
const MARKET_ORDERS := "收货牌"
const MARKET_RETURN := "回封地"
const TAX_ENVOY := "召简"
const TAX_COUNCIL_YEAR := 3
const RECLAMATION_BOUNDS := Rect2i(-16, -10, 36, 23)
const FIRST_FIELD_CENTER := Vector2i(5, 5)
const RECLAMATION_NIGHTS := 4
const RECLAMATION_RETAINERS := 3
const RECLAMATION_STAGES := ["立桩", "清草", "整地", "划畦"]
const GATHERING_TERM := "谷雨"
const GATHERING_BEATS := 4
const GATHERING_MIN_HITS := 3
const GATHERING_MUSIC_XP := 30
const FIELD_NIGHT_COUNTS := ["ready", "growing", "public_ripe", "private_ripe", "dry", "blocked"]
const AWAY_FIELD_JOBS := ["watered", "harvested", "sown"]
const AWAY_FIELD_YIELDS := ["tribute", "stock", "copper", "leaves"]
const AWAY_FIELD_TOTALS := {
	"watered": "浇水 %d 格", "harvested": "收割 %d 格", "sown": "补播 %d 格", "tribute": "国库 +%d",
	"stock": "私仓 +%d", "copper": "铜钱 +%d", "leaves": "桑叶 +%d",
}
const DAY_START_HOUR := 6.0
const DAY_END_HOUR := 22.0
const DAY_WATCHES := ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]

# Game balance configuration
var balance: BalanceData = preload("res://resources/BalanceData.tres")

enum EstateRoom { OUTDOORS, HALL, SILK_SHED }

# Global state manager
var current_day: int
var day_progress := 0.0
var estate_room := EstateRoom.OUTDOORS
var selected_seed_id: String = CropData.IDS[0]
var crop_stock := CropStock.new()
var night_rations := NightRations.new()
var last_field_night: Dictionary = {}
var last_dawn: Dictionary = {}
var away_field_report: Dictionary = {}
var _away_work_elapsed: Dictionary[RetainerData, float] = {}
var player_inventory: int:
	get: return crop_stock.count()
	set(value):
		var change := maxi(0, value) - crop_stock.count()
		if change > 0:
			crop_stock.add(CropStock.MIXED, change)
		elif change < 0:
			crop_stock.spend(crop_stock.plan(-change))
var season_order_receipts: Dictionary[String, Dictionary] = {}
var legacy_order_start := 0
var pinned_season_start := 0
var travel_meal := ""
var king_storage: int
var private_harvest_total: int
var money: int
var reputation: int
var max_stamina: int
var current_stamina: int
var health: int
var raid_day := 0
var raid_kind := 0
var raid_health := -1
var raids_defeated := 0
var raid_crop_losses := 0
var last_defense: Dictionary = {}
var east_watch_day := 0
var last_forage_day := 0
var last_fishing_day := 0
var ravine_trip_target := ""
var market_trip_target := ""
var restored_ravine_waypoint := ""
var restored_ravine_south := false
var restored_west_road_from_market := false
var fish_collection: Dictionary[String, Dictionary] = {}
var fish_order_receipt: Dictionary = {}
var creek_trap: Dictionary = {}
var ravine_journal: RavineJournal

enum Outcome { RUNNING, DEFEAT_COMBAT, DEFEAT_ESTATE, TRADITIONAL, REFORMED }
var outcome: Outcome = Outcome.RUNNING
var campaign_id := ""
var campaign_name := "封地 1"
var checkpoint_sequence := 0
var restore_notice := ""

# Phase 2: Economy & Retainers
var food_storage: int
var retainers: Array[RetainerData] = []
var days_without_contribution: int
var visitor_encounters: Dictionary[String, int] = {}
var neighbor_met_days: Dictionary[String, int] = {}
enum DepartureReason { UNRECORDED, HUNGER, REFORM }
enum RecruitmentBlock { NONE, UNAVAILABLE, DAILY_LIMIT, JUST_LEFT, REPUTATION, FOOD }
var neighbor_departures: Dictionary[String, Dictionary] = {}
var last_recruit_day := 0
var last_recruit_outside_rotation := false
var road_provisions_delivered := false
var road_provisions_day := 0
var road_rest_paid_day := 0
var road_rest_used_day := 0
var field_rotation := FieldRotation.new()
var silk_sample_day := 0

# Phase 3: RPG Stats
var player_stats: PlayerStats
var practice_days: Dictionary[String, int] = {}
var best_driving_ms := 0
var gathering_recitals: Dictionary[int, int] = {}
var summer_raft_results: Dictionary[int, Dictionary] = {}
var autumn_exhibits: Dictionary[int, Dictionary] = {}
var winter_suppers: Dictionary[int, Dictionary] = {}

var active_crops: Dictionary = {}
var tilled_cells: Dictionary = {}
var field_route_status := -1
var field_route_public_only := false
var field_seed_plans: Dictionary[Vector2i, String] = {}
var fertile_cells: Dictionary[Vector2i, bool] = {}
var irrigation: Irrigation
var first_channel_growth_day := 0
var channel_survey_day := 0
var silk_workshop: SilkWorkshop
var silk_bolts_sold := 0
var silk_bolts_offered := 0
var sheepfold := Sheepfold.new()

enum ChannelSite { AVAILABLE, LOCKED, BLOCKED, ALREADY_BUILT, NO_FUNDS, FOUNDATION }
enum ReclamationSite { OPEN, EDGE, NEAR_FIELD, SOURCE, CANAL, ROAD, LANDMARK }
enum CropWater { DRY, BLOCKED, HAND, CANAL, RAIN }
enum NightGrowth { READY, DRY, BLOCKED, GROW, RIPEN }
enum MulberryRoute { PLANT = 5, WATER, HARVEST }
enum TributeRoute { TEND = 8 }
const FIELD_ROUTE_STATES := [NightGrowth.READY, NightGrowth.DRY, NightGrowth.BLOCKED,
	MulberryRoute.PLANT, MulberryRoute.WATER, MulberryRoute.HARVEST, TributeRoute.TEND]
enum Season { SPRING, SUMMER, AUTUMN, WINTER }
const SEASON_NAMES := ["春", "夏", "秋", "冬"]

# Phase 3: Rank & Tech
enum Rank {
	XIA_SHI,        # 下士（初始爵位）
	ZHONG_SHI,      # 中士
	SHANG_SHI,      # 上士
	DA_FU,          # 大夫
	QING            # 卿
}
const WELL_FIELD_LIMITS: Array[int] = [1, 2, 4, 9, 16]
var current_rank: Rank = Rank.XIA_SHI
var attire_id := PlayerAttire.DEFAULT
var hall_mat_id := HallDecor.DEFAULT_MAT
var hall_shelf_id := HallDecor.DEFAULT_SHELF
var rank_names: Dictionary = {
	Rank.XIA_SHI: "下士",
	Rank.ZHONG_SHI: "中士",
	Rank.SHANG_SHI: "上士",
	Rank.DA_FU: "大夫",
	Rank.QING: "卿"
}

var tech_unlocked: Dictionary

# Well-Field System (井田制扩展)
var well_fields: Array[Dictionary] = []  # 存储所有井田数据
var max_well_fields: int = WELL_FIELD_LIMITS[Rank.XIA_SHI]  # 当前爵位允许的最大井田数量

# Tax Reform System (初税亩改革)
enum TaxReformChoice {
	NONE,           # 未选择（游戏初期）
	DELAYED,        # 拖延观望
	REFORMED,       # 支持改革（法家路线）
	TRADITIONAL     # 坚守传统（儒家路线）
}
enum RouteGoal { TRIBUTE, TAXED_HARVEST, OFFER_SILK, SELL_SILK, COPPER, RAIDS }

var tax_reform_choice: TaxReformChoice = TaxReformChoice.NONE
var tax_reform_year: int = 0  # 改革发生的年份
var tax_reform_day: int = 0
var tax_council_invited := false
var research_choice_pending := false
var route_baseline: Dictionary[String, int] = {}
var ending_record: Dictionary = {}
var tax_rate: float = 0.0  # 改革后的税率（0.0-1.0，默认0表示未改革）
var zhou_li_score: String = "中"  # 周礼评分（上上/上中/中上/中/中下/下中/下下）

const SOLAR_TERMS = [
	"立春", "雨水", "惊蛰", "春分", "清明", "谷雨",
	"立夏", "小满", "芒种", "夏至", "小暑", "大暑",
	"立秋", "处暑", "白露", "秋分", "寒露", "霜降",
	"立冬", "小雪", "大雪", "冬至", "小寒", "大寒"
]

# Quest System
const TRIBUTE_QUEST_REPUTATION := 50
var quest_target: int = 10
var quest_progress: int = 0
var quest_completed: bool = false

func _ready() -> void:
	_reset_campaign()

func start_new_game(estate_name := "") -> Error:
	var chosen_name := estate_name.strip_edges()
	if chosen_name.is_empty():
		chosen_name = next_campaign_name()
	var result := get_tree().change_scene_to_file(ESTATE_SCENE)
	if result == OK:
		_reset_campaign()
		campaign_name = chosen_name.left(16)
		get_tree().scene_changed.connect(_announce_arrival, CONNECT_ONE_SHOT)
	return result

func _announce_arrival() -> void:
	GameEvents.estate_arrived.emit()

func _reset_campaign() -> void:
	campaign_id = "%d-%d-%d" % [int(Time.get_unix_time_from_system()), OS.get_process_id(), Time.get_ticks_usec()]
	checkpoint_sequence = 0
	restore_notice = ""
	current_day = 1
	day_progress = 0.0
	estate_room = EstateRoom.OUTDOORS
	selected_seed_id = CropData.IDS[0]
	crop_stock = CropStock.new()
	night_rations = NightRations.new()
	last_field_night.clear()
	last_dawn.clear()
	away_field_report.clear()
	_away_work_elapsed.clear()
	season_order_receipts.clear()
	legacy_order_start = 0
	pinned_season_start = 0
	travel_meal = ""
	king_storage = 0
	private_harvest_total = 0
	money = 0
	reputation = 0
	max_stamina = 100
	current_stamina = max_stamina
	health = balance.player_max_health
	outcome = Outcome.RUNNING
	raid_day = 0
	raid_kind = 0
	raid_health = -1
	raids_defeated = 0
	raid_crop_losses = 0
	last_defense.clear()
	east_watch_day = 0
	last_forage_day = 0
	last_fishing_day = 0
	ravine_trip_target = ""
	market_trip_target = ""
	restored_ravine_waypoint = ""
	restored_ravine_south = false
	restored_west_road_from_market = false
	creek_trap.clear()
	fish_collection.clear()
	fish_order_receipt.clear()
	ravine_journal = RavineJournal.new()
	food_storage = 10
	days_without_contribution = 0
	retainers = [_starter_retainer()]
	visitor_encounters.clear()
	neighbor_met_days.clear()
	neighbor_met_days[VisitorData.FIELD_KEEPER] = current_day
	neighbor_departures.clear()
	last_recruit_day = 0
	last_recruit_outside_rotation = false
	road_provisions_delivered = false
	road_provisions_day = 0
	road_rest_paid_day = 0
	road_rest_used_day = 0
	field_rotation = FieldRotation.new()
	silk_sample_day = 0
	player_stats = PlayerStats.new()
	practice_days.clear()
	best_driving_ms = 0
	gathering_recitals.clear()
	summer_raft_results.clear()
	autumn_exhibits.clear()
	winter_suppers.clear()
	active_crops.clear()
	tilled_cells.clear()
	field_route_status = -1
	field_route_public_only = false
	field_seed_plans.clear()
	fertile_cells.clear()
	irrigation = Irrigation.new()
	first_channel_growth_day = 0
	channel_survey_day = 0
	silk_workshop = SilkWorkshop.new()
	silk_bolts_sold = 0
	silk_bolts_offered = 0
	sheepfold = Sheepfold.new()
	tech_unlocked = {"irrigation": false, "composite_bow": false}
	current_rank = Rank.XIA_SHI
	attire_id = PlayerAttire.DEFAULT
	hall_mat_id = HallDecor.DEFAULT_MAT
	hall_shelf_id = HallDecor.DEFAULT_SHELF
	well_fields.clear()
	_update_max_well_fields()
	tax_reform_choice = TaxReformChoice.NONE
	tax_reform_year = 0
	tax_reform_day = 0
	tax_council_invited = false
	research_choice_pending = false
	route_baseline.clear()
	ending_record.clear()
	tax_rate = 0.0
	zhou_li_score = "中"
	quest_progress = 0
	quest_completed = false

func _starter_retainer() -> RetainerData:
	return RetainerData.new(VisitorData.FIELD_KEEPER, "农夫", RetainerData.School.MOHIST)

func knows_neighbor(speaker: String) -> bool:
	if (neighbor_met_days.has(speaker) or visitor_encounters.has(speaker) or neighbor_departures.has(speaker)
		or VisitorData.favor_completed(speaker)):
		return true
	for resident in retainers:
		if resident.name == speaker:
			return true
	return false

func meet_neighbor(speaker: String) -> void:
	if speaker in VisitorData.NEIGHBORS and not knows_neighbor(speaker):
		neighbor_met_days[speaker] = current_day

func talk_to_visitor(visitor_name: String) -> void:
	if visitor_encounters.get(visitor_name, 0) == current_day:
		return
	meet_neighbor(visitor_name)
	visitor_encounters[visitor_name] = current_day
	player_stats.add_xp(PlayerStats.Art.LITERACY, balance.interaction_xp_gain)
	reputation += balance.interaction_reputation_gain
	GameEvents.reputation_changed.emit(reputation)

func visitor_for_day(day: int) -> VisitorData:
	var resident_names: Array[String] = []
	for resident in retainers:
		resident_names.append(resident.name)
	if last_recruit_day == day and not last_recruit_outside_rotation:
		return null
	if ((defense_review_ready() or east_watch_day == day) and last_defense.get("day", 0) + 1 == day
		and visitor_encounters.has(VisitorData.EAST_WATCHER) and VisitorData.EAST_WATCHER not in resident_names):
		return VisitorData.from_persona(VisitorData.EAST_PERSONA)
	if ((water_review_ready() or channel_survey_day == day) and first_channel_growth_day == day
		and visitor_encounters.has(VisitorData.WATER_GUIDE) and VisitorData.WATER_GUIDE not in resident_names):
		return VisitorData.from_persona(VisitorData.WATER_PERSONA)
	return VisitorData.for_day(day, resident_names)

func next_visitor_day(speaker: String) -> int:
	# 五人轮访与七日歇日经过这个周期后会重合。
	var cycle_days := VisitorData.PERSONAS.size() * 7
	for day in range(current_day + 1, current_day + cycle_days + 1):
		var visitor := visitor_for_day(day)
		if visitor and visitor.name == speaker:
			return day
	return 0

func first_tribute_delivered() -> bool:
	return quest_progress > 0 or king_storage > 0

func tribute_deadline() -> int:
	if tax_reform_choice == TaxReformChoice.REFORMED:
		return 0
	return current_day + maxi(0, balance.no_contribution_threshold - days_without_contribution - 1)

func tribute_penalty_tonight() -> int:
	return balance.no_contribution_penalty if tribute_deadline() == current_day else 0

func tribute_overdue() -> bool:
	return days_without_contribution >= balance.no_contribution_threshold

func next_field_keeper_visit() -> int:
	return current_day + posmod(-current_day, FieldRotation.VISIT_INTERVAL)

func field_keeper_visiting() -> bool:
	return (outcome == Outcome.RUNNING and current_day == next_field_keeper_visit()
		and not retainers.any(func(resident: RetainerData) -> bool: return resident.name == VisitorData.FIELD_KEEPER))

func rotation_offer_ready() -> bool:
	return outcome == Outcome.RUNNING and first_tribute_delivered() and field_rotation.promise_day == 0

func agree_to_rotation() -> bool:
	if not rotation_offer_ready():
		return false
	field_rotation.promise_day = current_day
	GameEvents.field_rotation_changed.emit()
	GameEvents.world_notice.emit("与渠伯约好轮作 · 先在私田收一茬菽")
	return true

func note_rotation_harvest(cell: Vector2i, crop: CropData, crop_id: String, rotated: bool) -> void:
	if outcome != Outcome.RUNNING or not field_rotation.waiting_for_harvest():
		return
	if crop.restores_fertility and field_rotation.beans_day == 0:
		field_rotation.beans_day = current_day
		GameEvents.field_rotation_changed.emit()
		GameEvents.world_notice.emit("菽已收 · 在留肥的私田再收一茬")
	elif rotated:
		for field in well_fields:
			var center: Vector2i = field["center_pos"]
			if Rect2i(center - Vector2i.ONE, Vector2i(3, 3)).has_point(cell):
				field_rotation.harvest_day = current_day
				field_rotation.field_number = field["field_id"] + 1
				field_rotation.crop_id = crop_id
				GameEvents.field_rotation_changed.emit()
				GameEvents.world_notice.emit("%s轮作多收一份 · 回田边找渠伯" % crop.crop_name)
				break

func sign_rotation_book() -> bool:
	if outcome != Outcome.RUNNING or not field_rotation.ready_to_sign():
		return false
	field_rotation.signed_day = current_day
	GameEvents.field_rotation_changed.emit()
	GameEvents.world_notice.emit("渠伯摆好了轮作簿 · 去井田西南翻看")
	return true

func rotation_crop_name() -> String:
	var crop := ItemManager.get_crop(field_rotation.crop_id)
	return crop.crop_name if crop else "下一茬作物"

func road_provisions_requested() -> bool:
	return first_tribute_delivered() and visitor_encounters.has(VisitorData.ROAD_KEEPER) and not road_provisions_delivered

func deliver_road_provisions() -> bool:
	if not road_provisions_requested() or player_inventory < 1:
		return false
	if not crop_stock.spend(market_crop_plan(1)):
		return false
	reputation += balance.interaction_reputation_gain
	road_provisions_delivered = true
	road_provisions_day = current_day
	GameEvents.inventory_changed.emit(player_inventory)
	GameEvents.reputation_changed.emit(reputation)
	GameEvents.road_provisions_delivered.emit()
	return true

func road_rest_requested() -> bool:
	return road_provisions_delivered and road_rest_paid_day == 0 and current_day > road_provisions_day

func road_rest_built() -> bool:
	return road_rest_paid_day > 0 and current_day > road_rest_paid_day

func fund_road_rest() -> bool:
	if outcome != Outcome.RUNNING or not road_rest_requested() or money < balance.road_rest_cost:
		return false
	money -= balance.road_rest_cost
	road_rest_paid_day = current_day
	GameEvents.money_changed.emit(money)
	GameEvents.road_rest_changed.emit()
	GameEvents.world_notice.emit("季青备下木料 · 明日可到亭西歇脚")
	return true

func road_rest_recovery() -> int:
	if outcome != Outcome.RUNNING or not road_rest_built() or road_rest_used_day == current_day:
		return 0
	return mini(balance.road_rest_stamina, max_stamina - current_stamina)

func use_road_rest() -> bool:
	var recovered := road_rest_recovery()
	if recovered <= 0:
		return false
	current_stamina += recovered
	road_rest_used_day = current_day
	GameEvents.stamina_changed.emit(current_stamina)
	GameEvents.road_rest_changed.emit()
	GameEvents.world_notice.emit("亭西歇了一会 · 体力 +%d" % recovered)
	return true

func silk_sample_requested() -> bool:
	return silk_sample_day == 0 and visitor_encounters.has(VisitorData.SILK_MERCHANT)

func silk_sample_price() -> int:
	return balance.silk_sell_price + balance.silk_sample_bonus

func deliver_silk_sample() -> bool:
	if outcome != Outcome.RUNNING or not silk_sample_requested() or not can_use_workshop(SilkWorkshop.Action.SELL):
		return false
	silk_sample_day = current_day
	money += balance.silk_sample_bonus
	use_workshop(SilkWorkshop.Action.SELL)
	GameEvents.silk_sample_delivered.emit()
	return true

func can_wear_attire(id: String) -> bool:
	return PlayerAttire.can_wear(id, current_rank, silk_sample_day > 0, sheepfold.coat)

func change_attire(id: String) -> bool:
	if outcome != Outcome.RUNNING or not can_wear_attire(id):
		return false
	attire_id = id
	GameEvents.attire_changed.emit()
	return true

func hall_decor_unlocked(id: String) -> bool:
	match id:
		HallDecor.DEFAULT_MAT, HallDecor.DEFAULT_SHELF, "bare_floor":
			return true
		"blue_mat":
			return road_rest_built()
		"silk_mat":
			return silk_sample_day > 0
		"wool_mat":
			return sheepfold.coat
		"tribute_sheaf":
			return first_tribute_delivered()
		"stream_jar":
			return not fish_collection.is_empty()
		"water_slips":
			return channel_survey_day > 0
		"gathering_bell":
			return not gathering_recitals.is_empty()
		"raft_flag":
			return summer_raft_results.values().any(func(run: Dictionary) -> bool: return run.gates >= SummerRaft.MIN_GATES)
		"supper_bowl":
			return not winter_suppers.is_empty()
	return false

func _valid_hall_decor(id: String, slot: HallDecor.Slot) -> bool:
	return HallDecor.CATALOG.has(id) and HallDecor.CATALOG[id].slot == slot and hall_decor_unlocked(id)

func arrange_hall(mat: String, shelf: String) -> bool:
	if (outcome != Outcome.RUNNING or not _valid_hall_decor(mat, HallDecor.Slot.MAT)
		or not _valid_hall_decor(shelf, HallDecor.Slot.SHELF)):
		return false
	hall_mat_id = mat
	hall_shelf_id = shelf
	return true

func advance_daylight(seconds: float) -> void:
	if outcome != Outcome.RUNNING or day_progress >= 1.0 or seconds <= 0.0:
		return
	var watch := _day_watch_index(day_progress)
	day_progress = minf(1.0, day_progress + seconds / maxf(1.0, balance.daylight_seconds))
	if _day_watch_index(day_progress) != watch:
		GameEvents.daylight_changed.emit()

func _day_watch_index(progress: float) -> int:
	var hour := lerpf(DAY_START_HOUR, DAY_END_HOUR, progress)
	return floori((hour + 1.0) / 2.0)

func day_watch_label() -> String:
	return DAY_WATCHES[_day_watch_index(day_progress)] + "时"

func dusk_amount() -> float:
	return smoothstep(0.68, 0.86, day_progress)

func is_indoors() -> bool:
	return estate_room != EstateRoom.OUTDOORS

func begin_next_day() -> void:
	current_day += 1
	day_progress = 0.0
	last_dawn.clear()
	field_route_status = -1
	field_route_public_only = false
	away_field_report.clear()
	_away_work_elapsed.clear()
	if sheepfold.owned():
		sheepfold.settle_night(sheep_feed(sheepfold.fodder, current_day - 1), balance.sheep_wool_nights)
		GameEvents.sheepfold_changed.emit()
	GameEvents.daylight_changed.emit()

func record_dawn(previous_rank: Rank, completed_fields: Array[int], research_fee: int, tribute_penalty: int) -> void:
	last_dawn = {
		"day": current_day - 1,
		"rank_change": int(current_rank) - int(previous_rank),
		"completed_fields": completed_fields,
		"research_paid": research_fee if not research_choice_pending else 0,
		"research_gap": maxi(0, research_fee - money) if research_choice_pending else 0,
		"tribute_penalty": tribute_penalty,
	}

func has_morning_record() -> bool:
	return not last_dawn.is_empty() or not last_field_night.is_empty() or not night_rations.last.is_empty()

func dawn_milestones() -> PackedStringArray:
	var lines := PackedStringArray()
	var rank_change: int = last_dawn.get("rank_change", 0)
	if rank_change > 0:
		lines.append("晋升%s · 井田上限 %d 块 · 堂屋添了新衣" % [rank_names[current_rank], max_well_fields])
	elif rank_change < 0:
		lines.append("削爵至%s · 井田上限 %d 块" % [rank_names[current_rank], max_well_fields])
	var completed: Array = last_dawn.get("completed_fields", [])
	if not completed.is_empty():
		var numbers := PackedStringArray()
		for number: int in completed:
			numbers.append(str(number))
		lines.append("井田 %s 已完工 · 可耕种" % "、".join(numbers))
	var research_paid: int = last_dawn.get("research_paid", 0)
	var research_gap: int = last_dawn.get("research_gap", 0)
	if research_paid > 0:
		lines.append("研究经费已缴 %d 铜钱" % research_paid)
	elif research_gap > 0:
		lines.append("研究经费未缴 · 缺 %d 铜钱 · 召简回堂前催议" % research_gap)
	var tribute_penalty: int = last_dawn.get("tribute_penalty", 0)
	if tribute_penalty > 0:
		lines.append("欠贡 · 声望 −%d" % tribute_penalty)
	return lines

func solar_term_index(day := 0) -> int:
	var date := day if day > 0 else current_day
	return floori(float(date - 1) / maxi(1, balance.days_per_solar_term)) % SOLAR_TERMS.size()

func get_current_solar_term(day := 0) -> String:
	return SOLAR_TERMS[solar_term_index(day)]

func season_index(day := 0) -> int:
	return floori(float(solar_term_index(day)) / SeasonOrders.TERMS_PER_SEASON)

func sowing_nights(crop: CropData, day := 0) -> int:
	return crop.sowing_nights(season_index(day), balance.seasonal_growth_reduction)

func has_rain(day := 0) -> bool:
	return get_current_solar_term(day) == balance.rain_solar_term

func sheep_can_graze(day := 0) -> bool:
	return season_index(day) != Season.WINTER and not has_rain(day)

func sheep_feed(fodder: int, day := 0) -> Sheepfold.Feed:
	if sheep_can_graze(day):
		return Sheepfold.Feed.PASTURE
	return Sheepfold.Feed.FODDER if fodder > 0 else Sheepfold.Feed.SHORTAGE

func meadow_has_grass() -> bool:
	return season_index() in [Season.SUMMER, Season.AUTUMN] and sheepfold.last_meadow_cut < _season_start()

func meadow_status() -> String:
	if season_index() not in [Season.SUMMER, Season.AUTUMN]:
		return "夏秋可割草"
	if not meadow_has_grass():
		return "本季已收"
	if not sheepfold.owned():
		return "领羊立栏后可割草"
	if has_rain():
		return "等晴天再割草"
	return "可割草料 %d 份" % balance.sheep_meadow_yield

func can_cut_meadow_grass() -> bool:
	return outcome == Outcome.RUNNING and sheepfold.owned() and meadow_has_grass() and not has_rain()

func cut_meadow_grass() -> bool:
	if not can_cut_meadow_grass():
		return false
	sheepfold.last_meadow_cut = current_day
	sheepfold.fodder += balance.sheep_meadow_yield
	GameEvents.sheepfold_changed.emit()
	GameEvents.world_notice.emit("草料 +%d · 已送回羊棚" % balance.sheep_meadow_yield)
	return true

func _season_start() -> int:
	var term_days := maxi(1, balance.days_per_solar_term)
	return _solar_term_start(current_day) - posmod(solar_term_index(), SeasonOrders.TERMS_PER_SEASON) * term_days

func can_use_sheepfold(action: Sheepfold.Action) -> bool:
	if outcome != Outcome.RUNNING:
		return false
	if action == Sheepfold.Action.BUY_SHEEP:
		return first_tribute_delivered() and not sheepfold.owned() and money >= balance.sheep_price
	if not sheepfold.owned():
		return false
	match action:
		Sheepfold.Action.BUY_FODDER:
			return money >= balance.sheep_fodder_price
		Sheepfold.Action.MIX_FODDER:
			return crop_stock.count("wheat") > 0
		Sheepfold.Action.SHEAR:
			return sheepfold.wool_nights >= balance.sheep_wool_nights
		Sheepfold.Action.SELL_WOOL:
			return sheepfold.wool > 0
		Sheepfold.Action.WEAVE_COAT:
			return not sheepfold.coat and sheepfold.wool >= balance.sheep_coat_wool
	return false

func use_sheepfold(action: Sheepfold.Action) -> bool:
	if not can_use_sheepfold(action):
		return false
	var before := money
	match action:
		Sheepfold.Action.BUY_SHEEP:
			money -= balance.sheep_price
			sheepfold.bought_day = current_day
		Sheepfold.Action.BUY_FODDER:
			money -= balance.sheep_fodder_price
			sheepfold.fodder += balance.sheep_fodder_bundle
		Sheepfold.Action.MIX_FODDER:
			crop_stock.spend({"wheat": 1})
			sheepfold.fodder += balance.sheep_fodder_bundle
			GameEvents.inventory_changed.emit(player_inventory)
		Sheepfold.Action.SHEAR:
			sheepfold.wool_nights = 0
			sheepfold.wool += 1
			GameEvents.sheep_sheared.emit()
		Sheepfold.Action.SELL_WOOL:
			sheepfold.wool -= 1
			money += balance.sheep_wool_price
		Sheepfold.Action.WEAVE_COAT:
			sheepfold.wool -= balance.sheep_coat_wool
			sheepfold.coat = true
	if money != before:
		GameEvents.money_changed.emit(money)
	GameEvents.sheepfold_changed.emit()
	return true

func is_gathering_day(day := 0) -> bool:
	return get_current_solar_term(day) == GATHERING_TERM

func gathering_score() -> int:
	return gathering_recitals.get(_solar_term_start(current_day), 0)

func record_gathering_recital(day: int, hits: int) -> bool:
	if outcome != Outcome.RUNNING or day != current_day or not is_gathering_day() or gathering_score() > 0:
		return false
	if hits < GATHERING_MIN_HITS or hits > GATHERING_BEATS:
		return false
	gathering_recitals[_solar_term_start(day)] = hits
	player_stats.add_xp(PlayerStats.Art.MUSIC, GATHERING_MUSIC_XP)
	GameEvents.gathering_recital_recorded.emit()
	return true

func _solar_term_start(day: int) -> int:
	return day - posmod(day - 1, maxi(1, balance.days_per_solar_term))

func is_summer_raft_day(day := 0) -> bool:
	var date := day if day > 0 else current_day
	return get_current_solar_term(date) == SummerRaft.TERM and _solar_term_start(date) == date

func record_summer_raft(day: int, gates: int, time_ms: int) -> Dictionary:
	if outcome != Outcome.RUNNING or day != current_day or not is_summer_raft_day():
		return {}
	var previous: Dictionary = summer_raft_results.get(day, {})
	var previous_gates: int = previous.get("gates", -1)
	var previous_time: int = previous.get("time_ms", 0)
	var improved := gates > previous_gates or (gates == previous_gates and time_ms < previous_time)
	var experience := balance.summer_raft_driving if gates >= SummerRaft.MIN_GATES and previous_gates < SummerRaft.MIN_GATES else 0
	if improved:
		summer_raft_results[day] = {"gates": gates, "time_ms": time_ms}
	if experience > 0:
		player_stats.add_xp(PlayerStats.Art.DRIVING, experience)
	return {"improved": improved, "experience": experience}

func is_autumn_exhibit_day(day := 0) -> bool:
	return get_current_solar_term(day) == AutumnExhibit.TERM

func autumn_exhibit_record(day: int) -> Dictionary:
	return autumn_exhibits.get(_solar_term_start(day), {})

func is_winter_supper_day(day := 0) -> bool:
	var date := day if day > 0 else current_day
	return get_current_solar_term(date) == WinterSupper.TERM and _solar_term_start(date) == date

func winter_supper_record(day := 0) -> Dictionary:
	return winter_suppers.get(day if day > 0 else current_day, {})

func can_prepare_winter_supper(recipe: String, fish: String) -> bool:
	return (outcome == Outcome.RUNNING and is_winter_supper_day() and not winter_suppers.has(current_day)
		and crop_stock.can_spend(WinterSupper.RECIPES[recipe].crops)
		and (recipe != WinterSupper.FISH or fish_count(fish) > 0))

func prepare_winter_supper(recipe: String, fish: String) -> bool:
	if not can_prepare_winter_supper(recipe, fish):
		return false
	var dish: Dictionary = WinterSupper.RECIPES[recipe]
	crop_stock.spend(dish.crops)
	if recipe == WinterSupper.FISH:
		fish_collection[fish].stock -= 1
	winter_suppers[current_day] = {"recipe": recipe, "portions": WinterSupper.portions(recipe, balance)}
	player_stats.add_xp(PlayerStats.Art.RITES, balance.winter_supper_rites)
	GameEvents.inventory_changed.emit(player_inventory)
	if recipe == WinterSupper.FISH:
		GameEvents.fish_changed.emit()
	GameEvents.winter_supper_prepared.emit()
	GameEvents.night_rations_changed.emit()
	GameEvents.world_notice.emit("%s已上桌 · 可在今夜安排查看" % dish.name)
	return true

func place_autumn_exhibit(crops: Array[String], share: bool) -> bool:
	if outcome != Outcome.RUNNING or not is_autumn_exhibit_day() or not autumn_exhibit_record(current_day).is_empty():
		return false
	var samples := AutumnExhibit.portions(crops)
	if samples.is_empty() or not crop_stock.can_spend(samples):
		return false
	autumn_exhibits[_solar_term_start(current_day)] = {"crops": crops.duplicate(), "shared": share}
	if share:
		crop_stock.spend(samples)
		reputation += balance.autumn_share_reputation
		GameEvents.inventory_changed.emit(player_inventory)
		GameEvents.reputation_changed.emit(reputation)
	player_stats.add_xp(PlayerStats.Art.RITES, balance.autumn_exhibit_rites)
	GameEvents.autumn_exhibit_completed.emit()
	return true

func crop_water(cell: Vector2i, crop: Dictionary, day := 0) -> CropWater:
	if irrigation.supplies(cell):
		return CropWater.CANAL
	if crop.get("requires_channel", false):
		return CropWater.BLOCKED
	if not crop["data"].is_water_crop and has_rain(day):
		return CropWater.RAIN
	return CropWater.HAND if crop["watered"] else CropWater.DRY

func field_crop_is_dry(cell: Vector2i) -> bool:
	var crop: Dictionary = active_crops.get(cell, {})
	return not crop.is_empty() and crop.age < crop.growth_nights and crop_water(cell, crop) == CropWater.DRY

func field_crop_is_ripe(cell: Vector2i) -> bool:
	var crop: Dictionary = active_crops.get(cell, {})
	return not crop.is_empty() and crop.age >= crop.growth_nights

func water_field_crop(cell: Vector2i) -> bool:
	if not field_crop_is_dry(cell):
		return false
	active_crops[cell].watered = true
	GameEvents.farm_state_changed.emit()
	return true

func can_plan_field_seed(cell: Vector2i) -> bool:
	if not tilled_cells.has(cell):
		return false
	var crop: Dictionary = active_crops.get(cell, {})
	return crop.is_empty() or not crop.data.is_perennial

func set_field_seed_plan(cell: Vector2i, plan: String) -> void:
	if not can_plan_field_seed(cell):
		return
	if plan.is_empty():
		field_seed_plans.erase(cell)
	elif FieldSeedPlan.is_valid(plan) and (not FieldSeedPlan.is_rotation(plan) or field_rotation.signed_day > 0):
		field_seed_plans[cell] = plan

func next_seed_for_plan(cell: Vector2i, plan: String) -> String:
	if not FieldSeedPlan.is_rotation(plan):
		return plan
	var crop: Dictionary = active_crops.get(cell, {})
	# Preview the soil after harvest when a crop is still in the plot.
	var prepared: bool = fertile_cells.has(cell) if crop.is_empty() else crop.data.restores_fertility
	return FieldSeedPlan.crop_id(plan) if prepared else FieldSeedPlan.BEANS

func planned_field_seed(cell: Vector2i) -> String:
	if active_crops.has(cell):
		return ""
	var seed_id := next_seed_for_plan(cell, field_seed_plans.get(cell, ""))
	if seed_id.is_empty():
		return ""
	var seed := ItemManager.get_crop(seed_id)
	return seed_id if not seed.is_water_crop or irrigation.supplies(cell) else ""

func sow_field_crop(cell: Vector2i, seed_id: String) -> bool:
	if seed_id.is_empty() or not tilled_cells.has(cell) or active_crops.has(cell):
		return false
	var seed := ItemManager.get_crop(seed_id)
	if seed == null or (seed.is_water_crop and not irrigation.supplies(cell)):
		return false
	active_crops[cell] = {"id": seed_id, "data": seed, "age": 0,
		"growth_nights": sowing_nights(seed), "watered": false, "requires_channel": seed.is_water_crop}
	if seed.is_perennial:
		field_seed_plans.erase(cell)
	GameEvents.farm_state_changed.emit()
	return true

enum FieldJob { NONE, WATER, SOW, HARVEST }

func field_job(duty: RetainerData.Duty, cell: Vector2i) -> FieldJob:
	match duty:
		RetainerData.Duty.FIELD:
			if field_crop_is_dry(cell):
				return FieldJob.WATER
			if not planned_field_seed(cell).is_empty():
				return FieldJob.SOW
		RetainerData.Duty.HARVEST:
			if field_crop_is_ripe(cell):
				return FieldJob.HARVEST
	return FieldJob.NONE

func crop_rotation_bonus(cell: Vector2i, crop: CropData) -> int:
	return int(not crop.restores_fertility and fertile_cells.has(cell))

func harvest_field_crop(cell: Vector2i) -> Dictionary:
	if outcome != Outcome.RUNNING or not field_crop_is_ripe(cell):
		return {}
	var crop: Dictionary = active_crops[cell]
	var data: CropData = crop.data
	var crop_id: String = crop.id
	var public_plot := is_public_plot(cell)
	var first_tribute := public_plot and not first_tribute_delivered()
	var rotation := crop_rotation_bonus(cell, data)
	if rotation > 0:
		fertile_cells.erase(cell)
	if data.restores_fertility:
		fertile_cells[cell] = true
	if data.is_perennial:
		crop.age = mini(1, data.days_to_grow - 1)
		crop.growth_nights = data.days_to_grow
		crop.watered = false
	else:
		active_crops.erase(cell)
	var proceeds := harvest_proceeds(public_plot, data.sell_price, rotation, tax_reform_choice, tax_rate)
	_record_harvest(proceeds, crop_id)
	player_stats.add_xp(PlayerStats.Art.MATH, 5)
	var leaves := collect_mulberry_leaves(proceeds.stock) if not public_plot and crop_id == "mulberry" else 0
	if not public_plot and (rotation > 0 or data.restores_fertility):
		note_rotation_harvest(cell, data, crop_id, rotation > 0)
	GameEvents.crop_harvested.emit(public_plot)
	proceeds.merge({"crop": data.crop_name, "public": public_plot, "first_tribute": first_tribute,
		"leaves": leaves, "rotated": rotation > 0, "fertile": data.restores_fertility})
	return proceeds

func advance_away_field_work(seconds: float) -> void:
	if outcome != Outcome.RUNNING or tilled_cells.is_empty():
		return
	for worker in retainers:
		if worker.duty not in [RetainerData.Duty.FIELD, RetainerData.Duty.HARVEST]:
			continue
		var period := balance.away_field_work_seconds / maxf(0.1, worker.get_work_efficiency())
		var elapsed: float = _away_work_elapsed.get(worker, 0.0) + seconds
		while elapsed >= period and outcome == Outcome.RUNNING:
			var cell := _away_work_plot(worker)
			if cell == RetainerData.NO_ASSIGNMENT:
				elapsed = 0.0
				break
			elapsed -= period
			_finish_away_field_work(field_job(worker.duty, cell), cell)
		_away_work_elapsed[worker] = elapsed

func _away_work_plot(worker: RetainerData) -> Vector2i:
	var anchor := worker.assigned_area if worker.assigned_area != RetainerData.NO_ASSIGNMENT else FIRST_FIELD_CENTER
	var nearest := RetainerData.NO_ASSIGNMENT
	var distance := INF
	for cell: Vector2i in tilled_cells:
		var distance_to_anchor := cell.distance_squared_to(anchor)
		if distance_to_anchor < distance and field_job(worker.duty, cell) != FieldJob.NONE:
			nearest = cell
			distance = distance_to_anchor
	return nearest

func _finish_away_field_work(job: FieldJob, cell: Vector2i) -> void:
	if away_field_report.is_empty():
		away_field_report = {"day": current_day, "first_tribute": false}
		for key in AWAY_FIELD_TOTALS:
			away_field_report[key] = 0
	match job:
		FieldJob.WATER:
			water_field_crop(cell)
			away_field_report.watered += 1
		FieldJob.SOW:
			sow_field_crop(cell, planned_field_seed(cell))
			away_field_report.sown += 1
		FieldJob.HARVEST:
			var harvest := harvest_field_crop(cell)
			away_field_report.harvested += 1
			away_field_report.first_tribute = away_field_report.first_tribute or harvest.first_tribute
			for key in AWAY_FIELD_YIELDS:
				away_field_report[key] += harvest[key]
	away_field_report.pending = true

func away_field_summary(keys: Array = []) -> String:
	var included_keys := AWAY_FIELD_TOTALS.keys() if keys.is_empty() else keys
	var results := PackedStringArray()
	for key in included_keys:
		var count: int = away_field_report.get(key, 0)
		if count > 0:
			results.append(AWAY_FIELD_TOTALS[key] % count)
	return " · ".join(results)

func acknowledge_away_field_work() -> bool:
	_away_work_elapsed.clear()
	if not away_field_report.get("pending", false):
		return false
	away_field_report.pending = false
	return true

func is_public_plot(cell: Vector2i) -> bool:
	if tax_reform_choice == TaxReformChoice.REFORMED:
		return false
	for field in well_fields:
		if field["is_unlocked"] and field["center_pos"] == cell:
			return true
	return false

func night_growth(crop: Dictionary, water: CropWater) -> NightGrowth:
	var nights_left: int = crop["growth_nights"] - crop["age"]
	if nights_left <= 0:
		return NightGrowth.READY
	match water:
		CropWater.DRY: return NightGrowth.DRY
		CropWater.BLOCKED: return NightGrowth.BLOCKED
	return NightGrowth.RIPEN if nights_left == 1 else NightGrowth.GROW

func crop_night_status(cell: Vector2i, day := 0) -> int:
	var crop: Dictionary = active_crops.get(cell, {})
	return -1 if crop.is_empty() else night_growth(crop, crop_water(cell, crop, day))

func field_night_forecast(day := 0) -> Dictionary:
	var report := {"day": current_day if day <= 0 else day}
	for key in FIELD_NIGHT_COUNTS:
		report[key] = 0
	for cell: Vector2i in active_crops:
		match crop_night_status(cell, report.day):
			NightGrowth.READY: report.ready += 1
			NightGrowth.DRY: report.dry += 1
			NightGrowth.BLOCKED: report.blocked += 1
			NightGrowth.GROW: report.growing += 1
			NightGrowth.RIPEN:
				var key := "public_ripe" if is_public_plot(cell) else "private_ripe"
				report[key] += 1
	return report

func tribute_field_plan() -> Dictionary:
	if tribute_deadline() == 0:
		return {}
	var plan := {}
	var sowing_seed := ""
	var earliest := INF
	for field in well_fields:
		if not field["is_unlocked"]:
			continue
		var cell: Vector2i = field["center_pos"]
		var crop: Dictionary = active_crops.get(cell, {})
		var status := crop_night_status(cell)
		var seed := ""
		var nights: int
		var crop_data: CropData
		if crop.is_empty():
			if sowing_seed.is_empty():
				sowing_seed = _tribute_seed()
			seed = sowing_seed
			crop_data = ItemManager.get_crop(seed)
			nights = sowing_nights(crop_data)
		else:
			crop_data = crop.data
			nights = maxi(0, int(crop.growth_nights) - int(crop.age))
		if nights < earliest or (nights == earliest and plan.status == NightGrowth.BLOCKED and status != NightGrowth.BLOCKED):
			earliest = nights
			plan = {"cell": cell, "field": int(field["field_id"]) + 1, "status": status,
				"seed_id": seed, "crop": crop_data.crop_name, "ready_day": current_day + nights}
	return plan

func _tribute_seed() -> String:
	var best := "millet"
	var fewest := sowing_nights(ItemManager.get_crop(best))
	for seed: String in CropData.IDS:
		var crop := ItemManager.get_crop(seed)
		if crop.is_water_crop or crop.is_perennial:
			continue
		var nights := sowing_nights(crop)
		if nights < fewest or (nights == fewest and seed == selected_seed_id):
			fewest = nights
			best = seed
	return best

func knows_ravine_journal() -> bool:
	return visitor_encounters.has(VisitorData.RAVINE_GUIDE)

func ravine_site_today() -> int:
	return ravine_journal.next_site(current_day, has_rain()) if knows_ravine_journal() else -1

func ravine_handoff_ready() -> bool:
	return ravine_journal.complete() and ravine_journal.garden_day == 0

func ravine_shortcut_open() -> bool:
	return ravine_journal.garden_day > 0

func ravine_handoff_visit_today() -> bool:
	return ((ravine_handoff_ready() or ravine_journal.garden_day == current_day)
		and not retainers.any(func(resident: RetainerData) -> bool: return resident.name == VisitorData.RAVINE_GUIDE))

func ravine_status() -> String:
	if ravine_journal.garden_day > 0:
		return "手记已交 · 竹径药圃已备好"
	if ravine_handoff_ready():
		return "手记 3/3 · 回竹径找蒲宁" if ravine_handoff_visit_today() else "手记 3/3 · 到蒲宁的岗位交接"
	var site := ravine_site_today()
	var step := "今日记%s" % RavineJournal.SITES[site].name if site >= 0 else "今日已记，明日再来"
	return "手记 %d/%d · %s" % [ravine_journal.count(), RavineJournal.SITES.size(), step]

func record_ravine_site(site: int) -> bool:
	if outcome != Outcome.RUNNING or site < 0 or site != ravine_site_today():
		return false
	ravine_journal.recorded_days[site] = current_day
	GameEvents.ravine_journal_changed.emit()
	GameEvents.world_notice.emit("记下%s · 手记 %d/%d" % [
		RavineJournal.SITES[site].name, ravine_journal.count(), RavineJournal.SITES.size()])
	return true

func deliver_ravine_journal() -> bool:
	if outcome != Outcome.RUNNING or not ravine_handoff_ready():
		return false
	ravine_journal.garden_day = current_day
	GameEvents.ravine_journal_changed.emit()
	GameEvents.herb_garden_feedback.emit("竹径药圃已备好 · 南路小径已开")
	return true

func herb_garden_wait() -> int:
	return ravine_journal.garden_wait(current_day, balance.herb_garden_regrowth_days)

func harvest_herb_garden() -> bool:
	if outcome != Outcome.RUNNING or ravine_journal.garden_day == 0 or herb_garden_wait() > 0:
		return false
	if health >= balance.player_max_health:
		GameEvents.herb_garden_feedback.emit("气血充足 · 留着草药")
		return false
	ravine_journal.garden_harvest_day = current_day
	var recovered := _heal_with_herbs()
	GameEvents.ravine_journal_changed.emit()
	GameEvents.herb_garden_feedback.emit("药圃草药 · 气血 +%d" % recovered)
	return true

func can_practice_today(art: PlayerStats.Art) -> bool:
	return practice_days.get(PlayerStats.Art.keys()[art], 0) != current_day

func award_practice(art: PlayerStats.Art, xp: int) -> bool:
	if not can_practice_today(art):
		return false
	practice_days[PlayerStats.Art.keys()[art]] = current_day
	player_stats.add_xp(art, xp)
	return true

func study_bamboo_slips() -> bool:
	var xp := balance.literacy_study_xp
	if not award_practice(PlayerStats.Art.LITERACY, xp):
		return false
	GameEvents.practice_feedback.emit("研读简册 · 书经验 +%d" % xp)
	print("STUDY day=", current_day, " xp=", xp)
	return true

func get_current_year() -> int:
	return ceili(float(current_day) / maxi(1, balance.days_per_year))

func public_contribution_ratio(added_public := 0, added_private := 0) -> float:
	var tribute := king_storage + added_public
	return float(tribute) / maxi(1, tribute + private_harvest_total + added_private)

func tax_council_start_day() -> int:
	return (TAX_COUNCIL_YEAR - 1) * maxi(1, balance.days_per_year) + 1

func tax_council_public_gap(added_public := 0, added_private := 0) -> int:
	var tribute := king_storage + added_public
	var private_yield := private_harvest_total + added_private
	var threshold := balance.public_field_ratio_threshold
	if threshold > 1.0 or (threshold == 1.0 and private_yield > 0):
		return -1
	if private_yield == 0 or threshold <= 0.0:
		return maxi(0, 1 - tribute)
	# Test the nearest whole amount with the same ratio used at the invitation.
	var estimate := maxi(1, floori(private_yield * threshold / (1.0 - threshold)))
	var minimum := estimate + int(float(estimate) / (estimate + private_yield) < threshold)
	return maxi(0, minimum - tribute)

func tax_council_waiting() -> bool:
	if outcome != Outcome.RUNNING:
		return false
	if tax_reform_choice == TaxReformChoice.NONE:
		return tax_council_invited
	return tax_reform_choice == TaxReformChoice.DELAYED and (research_choice_pending or research_days_remaining() == 0)

func research_days_remaining() -> int:
	return maxi(0, tax_reform_day + maxi(1, balance.days_per_year) - current_day)

func research_payment_interval() -> int:
	return maxi(1, ceili(balance.days_per_year / 12.0))

func research_days_until_payment() -> int:
	var elapsed := maxi(0, current_day - tax_reform_day)
	return research_payment_interval() - elapsed % research_payment_interval()

func research_fee_due(day: int) -> int:
	if tax_reform_choice != TaxReformChoice.DELAYED or research_choice_pending:
		return 0
	var elapsed := day - tax_reform_day
	if elapsed <= 0 or elapsed > maxi(1, balance.days_per_year) or elapsed % research_payment_interval() != 0:
		return 0
	return maxi(0, balance.research_monthly_cost)

func set_route_baseline(saved: Dictionary = {}) -> void:
	route_baseline = {
		"tribute": clampi(_read_save_int(saved.get("tribute"), king_storage), 0, king_storage),
		"private": clampi(_read_save_int(saved.get("private"), private_harvest_total), 0, private_harvest_total),
		"offered": clampi(_read_save_int(saved.get("offered"), silk_bolts_offered), 0, silk_bolts_offered),
		"sold": clampi(_read_save_int(saved.get("sold"), silk_bolts_sold), 0, silk_bolts_sold)
	}

func route_objectives(choice := TaxReformChoice.NONE) -> Array[Dictionary]:
	var baseline: Dictionary = route_baseline if choice == TaxReformChoice.NONE else {}
	if choice == TaxReformChoice.NONE:
		choice = tax_reform_choice
	var goals: Array[Dictionary] = []
	match choice:
		TaxReformChoice.TRADITIONAL:
			goals = [
				{"kind": RouteGoal.TRIBUTE, "label": "新增公田纳贡",
					"value": king_storage - baseline.get("tribute", king_storage), "target": balance.ending_traditional_tribute},
				{"kind": RouteGoal.OFFER_SILK, "label": "进献丝绸",
					"value": silk_bolts_offered - baseline.get("offered", silk_bolts_offered), "target": balance.ending_silk_target}
			]
		TaxReformChoice.REFORMED:
			goals = [
				{"kind": RouteGoal.TAXED_HARVEST, "label": "新增计税收成",
					"value": private_harvest_total - baseline.get("private", private_harvest_total), "target": balance.ending_reformed_private},
				{"kind": RouteGoal.SELL_SILK, "label": "售出丝绸",
					"value": silk_bolts_sold - baseline.get("sold", silk_bolts_sold), "target": balance.ending_silk_target},
				{"kind": RouteGoal.COPPER, "label": "现有铜钱", "value": money, "target": balance.ending_reformed_wealth}
			]
		_:
			return goals
	goals.append({"kind": RouteGoal.RAIDS, "label": "击退敌袭", "value": raids_defeated, "target": balance.ending_raids_min})
	return goals

func restore_stamina() -> int:
	current_stamina = max_stamina
	health = mini(balance.player_max_health, health + balance.health_recovery_at_night)
	GameEvents.health_changed.emit(health)
	print("Stamina Restored")

	# Daily consumption
	var fed := _serve_night_rations(maxi(1, current_day - 1))
	_advance_lessons(fed)
	var fed_reelers := _count_duty(fed, RetainerData.Duty.REEL)
	if silk_workshop.advance_day(balance, fed_reelers):
		GameEvents.silk_changed.emit()

	# Apply CONFUCIAN loyalty aura (儒家忠诚光环)
	_apply_confucian_loyalty_aura()

	# Check contribution
	if tax_reform_choice == TaxReformChoice.REFORMED:
		return 0
	var due := tribute_deadline() == current_day
	days_without_contribution += 1
	if due:
		reputation -= balance.no_contribution_penalty
		print("Warning: Reputation decreased due to lack of contribution! Current: ", reputation)
		GameEvents.reputation_changed.emit(reputation)
		if reputation <= balance.rank_strip_threshold:
			_strip_rank()
		return balance.no_contribution_penalty
	return 0

func _strip_rank() -> void:
	if current_rank == Rank.XIA_SHI:
		finish_campaign(Outcome.DEFEAT_ESTATE)
		return
	current_rank = (current_rank - 1) as Rank
	if not can_wear_attire(attire_id):
		change_attire(PlayerAttire.DEFAULT)
	days_without_contribution = 0
	_update_max_well_fields()
	GameEvents.rank_changed.emit(current_rank)

func hurt_player(damage: int) -> void:
	if outcome != Outcome.RUNNING or damage <= 0:
		return
	health = maxi(0, health - damage)
	GameEvents.health_changed.emit(health)
	if health == 0:
		finish_campaign(Outcome.DEFEAT_COMBAT)

func finish_campaign(result: Outcome) -> void:
	if outcome != Outcome.RUNNING or result == Outcome.RUNNING:
		return
	if result in [Outcome.TRADITIONAL, Outcome.REFORMED]:
		if not ending_record.is_empty():
			return
		ending_record = _capture_ending(result)
	outcome = result
	GameEvents.campaign_ended.emit(outcome)

func _capture_ending(result: Outcome) -> Dictionary:
	var accounts := route_objectives()
	if accounts.is_empty() or accounts.any(func(goal: Dictionary) -> bool: return goal["value"] < goal["target"]):
		accounts = [
			{"label": "国库", "value": king_storage},
			{"label": "私田收成", "value": private_harvest_total},
			{"label": "铜钱", "value": money},
			{"label": "击退敌袭", "value": raids_defeated}
		]
	for account in accounts:
		account.erase("kind")
	return {
		"outcome": result,
		"date": "第 %d 年 · %s   第 %d 天 · %s" % [
			get_current_year(), get_current_solar_term(), current_day, rank_names[current_rank]],
		"accounts": accounts,
		"memories": _ending_memories()
	}

func _ending_memories() -> Array[String]:
	var moments: Array[String] = []
	if field_rotation.signed_day > 0:
		moments.append("渠伯把%s的收成记进轮作簿。" % rotation_crop_name())
	if ravine_journal.garden_day > 0:
		moments.append("蒲宁收下溪行手记，在竹径留了药圃。")
	if road_rest_built():
		moments.append("季青和你在南路亭西修了歇脚处。")
	if east_watch_day > 0:
		moments.append("弋戎把守田的战果留在东岗。")
	if not gathering_recitals.is_empty():
		moments.append("南路亭的曲簿记下了你与商音的合奏。")
	if not winter_suppers.is_empty():
		moments.append("冬至时，你在南池畔备下的那锅热饭还有人记得。")
	if silk_sample_day > 0:
		moments.append("陶辛把你织的样绸挂在西廊。")
	var fields := well_fields.filter(func(field: Dictionary) -> bool: return field["is_unlocked"])
	moments.append("%d 块井田已经耕成，%d 位门客留任。" % [fields.size(), retainers.size()])
	var irrigated := irrigated_well_fields()
	if irrigated > 0:
		moments.append("渠水已送到 %d 块井田。" % irrigated)
	if silk_workshop.built:
		moments.append("蚕室已能养蚕、缫丝和织绸。")
	return moments.slice(0, 3)

func continue_after_ending(position: Vector2, direction: Vector2) -> Error:
	var tree := get_tree()
	var result := tree.change_scene_to_file(ESTATE_SCENE)
	if result == OK:
		outcome = Outcome.RUNNING
		tree.paused = false
		tree.scene_changed.connect(_arrive_after_ending.bind(position, direction), CONNECT_ONE_SHOT)
	return result

func _arrive_after_ending(position: Vector2, direction: Vector2) -> void:
	get_tree().get_first_node_in_group("player").arrive_at_position(position, direction)
	save_automatically("ending_continue")

func is_raid_day(day: int) -> bool:
	return day >= balance.raid_first_day and (day - balance.raid_first_day) % maxi(1, balance.raid_interval_days) == 0

func raid_kind_on(day: int) -> int:
	return floori(float(day - balance.raid_first_day) / maxi(1, balance.raid_interval_days)) % 2

func raid_name(kind: int) -> String:
	return "野狗" if kind == 0 else "斥候"

func begin_raid(day: int) -> bool:
	if raid_day > 0 or not is_raid_day(day):
		return false
	raid_day = day
	raid_kind = raid_kind_on(day)
	raid_health = -1
	raid_crop_losses = 0
	GameEvents.raid_started.emit()
	return true

func defeat_raid(guard_name := "") -> void:
	if raid_day == 0:
		return
	last_defense = {"day": current_day, "kind": raid_kind, "losses": raid_crop_losses, "guard": guard_name}
	raid_day = 0
	raid_health = -1
	raid_crop_losses = 0
	raids_defeated += 1
	GameEvents.raid_defeated.emit()
	var follow_up := " · 可找弋戎复盘" if defense_review_ready() else ""
	GameEvents.world_notice.emit("击退%s · %s%s" % [raid_name(raid_kind), defense_loss_note(), follow_up])

func defense_review_ready() -> bool:
	return raid_day == 0 and east_watch_day == 0 and not last_defense.is_empty()

func review_defense() -> bool:
	if outcome != Outcome.RUNNING or not defense_review_ready():
		return false
	east_watch_day = current_day
	GameEvents.east_watch_built.emit()
	if not is_raid_day(current_day + 1):
		GameEvents.world_notice.emit("东路岗立了守备牌 · 靠近按 %s 查看" % GamepadInput.interact_key())
	return true

func defense_loss_note() -> String:
	var losses: int = last_defense.get("losses", 0)
	return "作物全保住了" if losses == 0 else "损失 %d 格作物" % losses

func forage_food() -> void:
	if not _take_forage_slot():
		return
	food_storage += balance.wild_food_yield
	GameEvents.food_changed.emit(food_storage)
	GameEvents.world_notice.emit("采得野果 · 粮食 +%d" % balance.wild_food_yield)

func ravine_outing_status() -> String:
	var forage := "采集已用" if last_forage_day == current_day else "可采一处"
	var blocked := fishing_block_reason(true)
	return "%s · %s" % [forage, "可钓一尾" if blocked.is_empty() else blocked]

func ravine_place_detail(place: String) -> String:
	if place == SummerRaft.PLACE:
		return "今日开筏 · 顺流穿过竹标" if is_summer_raft_day() else "夏至首日开放 · 可看往年成绩"
	var trap_site := CreekTrap.PLACES.find(place)
	if trap_site >= 0:
		return creek_trap_detail(trap_site)
	if place in ["野果坳", "望溪台"] and last_forage_day == current_day:
		return "今日采集已用"
	match place:
		"野果坳":
			return "野果 · 粮食 +%d" % balance.wild_food_yield
		"望溪台":
			var recovered := wild_herb_recovery()
			return "野药 · 气血 +%d" % recovered if recovered > 0 else "野药 · 气血充足"
	var site := CreekFish.PLACES.find(place)
	if site < 0:
		return ""
	var blocked := fishing_block_reason()
	if not blocked.is_empty():
		return blocked
	var fish: Dictionary = CreekFish.SPECIES[fish_at_today(site)]
	return "%s · 耗 %d 体力 · 可换 %d 粮" % [fish.name, balance.fishing_stamina_cost, fish.food]

func fish_at_today(site: int) -> String:
	return fish_at_day(site, current_day)

func fish_at_day(site: int, day: int) -> String:
	return CreekFish.at(site, season_index(day), has_rain(day))

func creek_traps_unlocked() -> bool:
	return get_current_year() >= 2 and not fish_collection.is_empty()

func ravine_trip_places() -> Array:
	return RAVINE_TRIP_PLACES + CreekTrap.PLACES if creek_traps_unlocked() else RAVINE_TRIP_PLACES

func regional_destination() -> String:
	return market_trip_target if ravine_trip_target.is_empty() else ravine_trip_target

func creek_trap_site() -> int:
	return creek_trap.get("site", -1)

func creek_trap_forecast(site: int, bait: String, set_day: int) -> Dictionary:
	var recipe: Dictionary = CreekTrap.BAITS[bait]
	var due: int = set_day + recipe.nights
	return {"day": due, "fish": fish_at_day(site, due), "amount": recipe.amount}

func creek_trap_catch() -> Dictionary:
	if creek_trap.is_empty():
		return {}
	return creek_trap_forecast(creek_trap.site, creek_trap.bait, creek_trap.set_day)

func creek_trap_detail(site: int) -> String:
	var deployed := creek_trap_site()
	if deployed < 0:
		return "可用一份黍或菽下笼"
	if deployed != site:
		return "竹笼在%s" % CreekFish.PLACES[deployed]
	var forecast := creek_trap_catch()
	var fish: String = CreekFish.SPECIES[forecast.fish].name
	return ("可收 · %s %d 尾" % [fish, forecast.amount] if current_day >= forecast.day else
		"第 %d 天可收 · %s %d 尾" % [forecast.day, fish, forecast.amount])

func set_creek_trap(site: int, bait: String) -> bool:
	if (outcome != Outcome.RUNNING or not creek_traps_unlocked() or not creek_trap.is_empty()
		or site < 0 or site >= CreekTrap.PLACES.size() or not CreekTrap.BAITS.has(bait)):
		return false
	if not crop_stock.spend({bait: 1}):
		return false
	creek_trap = {"site": site, "bait": bait, "set_day": current_day}
	GameEvents.inventory_changed.emit(player_inventory)
	GameEvents.creek_trap_changed.emit()
	return true

func take_creek_trap(site: int) -> Dictionary:
	if outcome != Outcome.RUNNING or creek_trap.is_empty() or creek_trap.site != site:
		return {}
	var caught := creek_trap_catch()
	if current_day < caught.day:
		return {}
	creek_trap.clear()
	_store_creek_fish(caught.fish, site, caught.amount)
	GameEvents.fish_changed.emit()
	GameEvents.creek_trap_changed.emit()
	return caught

func fishing_spot_today(id: String) -> String:
	for site in CreekFish.PLACES.size():
		if fish_at_today(site) == id:
			return CreekFish.PLACES[site]
	return ""

func fishing_block_reason(compact := false) -> String:
	if not knows_ravine_journal():
		return "垂钓待学" if compact else "先到南边竹径与蒲宁交谈"
	if last_fishing_day == current_day:
		return "垂钓已用" if compact else "今日垂钓机会已用"
	if current_stamina < balance.fishing_stamina_cost:
		return "抛竿缺体力" if compact else "体力不足 · 抛竿需要 %d" % balance.fishing_stamina_cost
	return ""

func cast_fishing_line() -> bool:
	if outcome != Outcome.RUNNING:
		return false
	var reason := fishing_block_reason()
	if not reason.is_empty():
		GameEvents.world_notice.emit(reason)
		return false
	current_stamina -= balance.fishing_stamina_cost
	GameEvents.stamina_changed.emit(current_stamina)
	return true

func land_creek_fish(site: int, cast_day: int) -> String:
	if outcome != Outcome.RUNNING or cast_day != current_day or last_fishing_day == current_day or not knows_ravine_journal():
		return ""
	var id := fish_at_today(site)
	if id.is_empty():
		return ""
	var first_catch := fish_collection.is_empty()
	_store_creek_fish(id, site, 1)
	last_fishing_day = current_day
	GameEvents.fish_changed.emit()
	if first_catch and creek_traps_unlocked():
		GameEvents.world_notice.emit("两岸可下竹笼 · 用黍或菽作饵")
	return id

func _store_creek_fish(id: String, site: int, amount: int) -> void:
	var record: Dictionary = fish_collection.get(id, {"first_day": current_day, "first_site": site, "stock": 0})
	record.stock += amount
	fish_collection[id] = record

func fish_count(id: String) -> int:
	return fish_collection.get(id, {}).get("stock", 0)

func fish_market_offer() -> Dictionary:
	var window := SeasonOrders.window(current_day, balance.days_per_solar_term)
	var request: Dictionary = CreekFish.MARKET_ORDERS[season_index()]
	var fish: Dictionary = CreekFish.SPECIES[request.fish]
	return {"start": window.start, "end": window.end, "fish": request.fish, "request": request.request,
		"thanks": request.thanks, "receipt": fish_order_receipt if fish_order_receipt.get("day", 0) >= window.start else {},
		"food": fish.food + balance.fish_order_food_bonus, "copper": fish.copper + balance.fish_order_copper_bonus}

func fish_delivery_places(caught := "") -> Array[String]:
	var places: Array[String] = []
	var offer := fish_market_offer()
	if (offer.receipt.is_empty() and fish_count(offer.fish) > 0
		and (caught.is_empty() or caught == offer.fish)):
		places.append(MarketStall.TITLES[MarketStall.Kind.FISH])
	var schedule := season_order()
	var order_fish: String = schedule.order.get("fish", "")
	if not order_fish.is_empty() and (caught.is_empty() or caught == order_fish) and can_deliver_season_order(schedule):
		places.append(MARKET_ORDERS)
	return places

func deliver_fish_order(start_day: int, for_food: bool) -> bool:
	var offer := fish_market_offer()
	if outcome != Outcome.RUNNING or offer.start != start_day or not offer.receipt.is_empty() or fish_count(offer.fish) < 1:
		return false
	var amount: int = offer.food if for_food else offer.copper
	fish_order_receipt = {"day": current_day, "fish": offer.fish, "for_food": for_food, "amount": amount}
	_settle_fish_exchange(offer.fish, for_food, amount)
	return true

func exchange_creek_fish(id: String, for_food: bool) -> bool:
	if outcome != Outcome.RUNNING or not CreekFish.SPECIES.has(id) or fish_count(id) < 1:
		return false
	var fish: Dictionary = CreekFish.SPECIES[id]
	_settle_fish_exchange(id, for_food, fish.food if for_food else fish.copper)
	return true

func _settle_fish_exchange(id: String, for_food: bool, amount: int) -> void:
	fish_collection[id].stock -= 1
	if for_food:
		food_storage += amount
		GameEvents.food_changed.emit(food_storage)
	else:
		money += amount
		GameEvents.money_changed.emit(money)
	GameEvents.fish_changed.emit()

func forage_herbs() -> void:
	if last_forage_day != current_day and health >= balance.player_max_health:
		GameEvents.world_notice.emit("气血充足，先把药草留在这里。")
		return
	if not _take_forage_slot():
		return
	var recovered := _heal_with_herbs()
	GameEvents.world_notice.emit("敷了野药 · 气血 +%d" % recovered)

func wild_herb_recovery() -> int:
	return mini(balance.wild_herb_healing, balance.player_max_health - health)

func _heal_with_herbs() -> int:
	var recovered := wild_herb_recovery()
	health += recovered
	GameEvents.health_changed.emit(health)
	return recovered

func _take_forage_slot() -> bool:
	if last_forage_day == current_day:
		GameEvents.world_notice.emit("今天已采集过，明日再来。")
		return false
	last_forage_day = current_day
	GameEvents.forage_taken.emit()
	return true

# Apply儒家忠诚光环（每天提升其他门客忠诚度）
func _apply_confucian_loyalty_aura() -> void:
	var confucian_count := 0
	for retainer in retainers:
		if retainer.school == RetainerData.School.CONFUCIAN:
			confucian_count += 1

	if confucian_count > 0:
		var loyalty_boost: float = confucian_count * balance.confucian_loyalty_aura * 10.0
		for retainer in retainers:
			if retainer.school != RetainerData.School.CONFUCIAN:
				retainer.loyalty = minf(100.0, retainer.loyalty + loyalty_boost)

func retainer_food_cost() -> int:
	var cost := 0
	for retainer in retainers:
		cost += retainer_night_ration(retainer)
	return cost

func retainer_night_ration(retainer: RetainerData) -> int:
	return 1 + (0 if retainer.duty == RetainerData.Duty.FIELD else balance.specialist_food_per_night)

func _night_meal(available: int) -> Dictionary:
	var order := retainers.duplicate()
	if night_rations.priority:
		order.erase(night_rations.priority)
		order.push_front(night_rations.priority)
	var fed: Array[RetainerData] = []
	var missed: Array[RetainerData] = []
	var served := 0
	for retainer in order:
		var portions := retainer_night_ration(retainer)
		if portions <= available - served:
			served += portions
			fed.append(retainer)
		else:
			missed.append(retainer)
	return {"served": served, "fed": fed, "missed": missed}

func _serve_night_rations(finished_day: int) -> Array[RetainerData]:
	var plan := _night_rations_supply_plan(finished_day)
	var used: Dictionary = {}
	var bought := 0
	var copper := 0
	var supplement: int = plan.converted + plan.bought
	if supplement > 0 and _market_exchange(plan.used, plan.copper, supplement):
		used = plan.used
		bought = plan.bought
		copper = plan.copper
	var meal := _night_meal(food_storage + int(plan.supper))
	var served: int = meal.served
	var supper := mini(served, int(plan.supper))
	var grain := served - supper
	if grain > 0:
		food_storage -= grain
		GameEvents.food_changed.emit(food_storage)
	var missed := PackedStringArray()
	var departed := PackedStringArray()
	for retainer: RetainerData in meal.missed:
		missed.append(retainer.name)
		retainer.loyalty = maxf(0.0, retainer.loyalty - NightRations.MISSED_MEAL_LOYALTY)
		if retainer.loyalty == 0.0:
			departed.append(retainer.name)
			dismiss_retainer(retainer, DepartureReason.HUNGER, finished_day)
	night_rations.last = {
		"day": finished_day, "need": plan.need, "served": served,
		"used": used, "bought": bought, "copper": copper,
	}
	if not missed.is_empty():
		night_rations.last["missed"] = missed
		print("Rations short: ", served, "/", plan.need, ". Missed: ", "、".join(missed))
	else:
		print("Food consumed: ", grain, ". Remaining: ", food_storage)
	if not departed.is_empty():
		night_rations.last["departed"] = departed
	if supper > 0:
		night_rations.last["supper"] = supper
	GameEvents.night_rations_changed.emit()
	return meal.fed

func _advance_lessons(fed: Array[RetainerData]) -> void:
	var teachers := _count_duty(fed, RetainerData.Duty.TEACH)
	if teachers > 0:
		player_stats.add_xp(PlayerStats.Art.RITES, teachers * balance.confucian_teaching_rites_xp)
		reputation += teachers * balance.confucian_teaching_reputation
		GameEvents.reputation_changed.emit(reputation)

func can_assign_duty(retainer: RetainerData, duty: RetainerData.Duty) -> bool:
	return (retainers.has(retainer) and retainer.can_take_duty(duty)
		and (duty != RetainerData.Duty.REEL or silk_workshop.built))

func assign_duty(retainer: RetainerData, duty: RetainerData.Duty) -> bool:
	if not can_assign_duty(retainer, duty):
		return false
	if retainer.duty != duty:
		retainer.duty = duty
		GameEvents.retainer_duty_changed.emit(retainer)
	return true

func dismiss_retainer(retainer: RetainerData, reason := DepartureReason.UNRECORDED, day := 0) -> void:
	if retainers.has(retainer):
		retainers.erase(retainer)
		if night_rations.priority == retainer:
			night_rations.priority = null
		if (reason != DepartureReason.UNRECORDED and retainer.name in VisitorData.NEIGHBORS
			and not retainers.any(func(resident: RetainerData) -> bool: return resident.name == retainer.name)):
			neighbor_departures[retainer.name] = {
				"day": day if day > 0 else current_day, "reason": reason, "returned_day": 0,
			}
		GameEvents.retainer_departed.emit(retainer)

func pending_neighbor_return(speaker: String) -> Dictionary:
	var departure: Dictionary = neighbor_departures.get(speaker, {})
	return departure if departure.get("returned_day", 0) == 0 else {}

func recruitment_food_requirement(speaker: String) -> int:
	if (speaker == VisitorData.FIELD_KEEPER
		or pending_neighbor_return(speaker).get("reason") == DepartureReason.HUNGER):
		return retainer_food_cost() + 1
	return 0

func recruitment_block(guest: VisitorData) -> RecruitmentBlock:
	if outcome != Outcome.RUNNING or guest.is_recruited \
			or retainers.any(func(resident: RetainerData) -> bool: return resident.name == guest.name):
		return RecruitmentBlock.UNAVAILABLE
	if last_recruit_day == current_day:
		return RecruitmentBlock.DAILY_LIMIT
	if pending_neighbor_return(guest.name).get("day", 0) >= current_day:
		return RecruitmentBlock.JUST_LEFT
	if reputation < balance.recruit_reputation_requirement:
		return RecruitmentBlock.REPUTATION
	if food_storage < recruitment_food_requirement(guest.name):
		return RecruitmentBlock.FOOD
	return RecruitmentBlock.NONE

func recruitment_block_note(guest: VisitorData, block: RecruitmentBlock) -> String:
	match block:
		RecruitmentBlock.UNAVAILABLE: return "暂不能留任"
		RecruitmentBlock.DAILY_LIMIT: return "今日已留一人"
		RecruitmentBlock.JUST_LEFT: return "今日刚离任"
		RecruitmentBlock.REPUTATION: return "还差 %d 声望" % (balance.recruit_reputation_requirement - reputation)
		RecruitmentBlock.FOOD: return "还差 %d 份口粮" % (recruitment_food_requirement(guest.name) - food_storage)
	return ""

func can_recruit_visitor(guest: VisitorData) -> bool:
	return recruitment_block(guest) == RecruitmentBlock.NONE

func recruit_visitor(guest: VisitorData) -> void:
	if not can_recruit_visitor(guest):
		return
	var school := RetainerData.School.NONE
	match guest.school:
		VisitorData.School.CONFUCIAN: school = RetainerData.School.CONFUCIAN
		VisitorData.School.MOHIST: school = RetainerData.School.MOHIST
		VisitorData.School.MILITARY: school = RetainerData.School.MILITARY
	var profession := guest.get_school_name() if guest.name in [VisitorData.SILK_MERCHANT, VisitorData.RAVINE_GUIDE] else "士人"
	var keeper := guest.name == VisitorData.FIELD_KEEPER
	var retainer := _starter_retainer() if keeper else RetainerData.new(guest.name, profession, school)
	if not keeper:
		retainer.visitor_appearance = guest.school
	var departure := pending_neighbor_return(guest.name)
	if not departure.is_empty():
		departure.returned_day = current_day
	elif keeper:
		neighbor_departures[guest.name] = {"day": 0, "reason": DepartureReason.UNRECORDED, "returned_day": current_day}
	reputation -= balance.recruit_reputation_requirement
	retainers.append(retainer)
	if not visitor_encounters.has(guest.name):
		visitor_encounters[guest.name] = 0
	last_recruit_day = current_day
	last_recruit_outside_rotation = guest.handoff_visit or keeper
	guest.is_recruited = true
	GameEvents.retainer_recruited.emit(retainer)
	GameEvents.reputation_changed.emit(reputation)

func harvest_proceeds(is_public: bool, unit_price: int, extra_yield: int,
		choice: TaxReformChoice, rate: float) -> Dictionary:
	var amount := 1 + maxi(0, extra_yield)
	if choice == TaxReformChoice.REFORMED:
		var net_unit := int(unit_price * (1.0 - rate))
		return {"tribute": 0, "stock": amount, "copper": net_unit * amount, "levy": (unit_price - net_unit) * amount}
	if is_public:
		return {"tribute": amount, "stock": 0, "copper": 0, "levy": 0}
	var yield_bonus := 0.0
	for retainer in retainers:
		if retainer.school == RetainerData.School.AGRARIAN:
			yield_bonus += 0.5
	amount += ceili(yield_bonus)
	return {"tribute": 0, "stock": amount, "copper": unit_price * amount, "levy": 0}

func _record_harvest(proceeds: Dictionary, crop_id: String) -> void:
	if proceeds.stock > 0:
		crop_stock.add(crop_id, proceeds.stock)
		private_harvest_total += proceeds.stock
		money += proceeds.copper
		print("Added to Player Inventory. Amount: %d, Money: %d" % [proceeds.stock, money])
		return

	var tax_multiplier := 1.0
	if tax_reform_choice == TaxReformChoice.TRADITIONAL:
		for retainer in retainers:
			if retainer.school == RetainerData.School.LEGALIST:
				tax_multiplier += 0.2
	var amount: int = proceeds["tribute"]
	king_storage += amount
	reputation += ceili(10 * tax_multiplier) * amount
	days_without_contribution = 0
	if field_route_status == TributeRoute.TEND:
		field_route_status = -1
	print("Added to King's Treasury. Amount: ", amount, " Reputation: ", reputation)
	if not quest_completed:
		quest_progress = mini(quest_target, quest_progress + amount)
		if quest_progress >= quest_target:
			quest_completed = true
			reputation += TRIBUTE_QUEST_REPUTATION
			print("Quest Completed!")
			GameEvents.reputation_changed.emit(reputation)

func collect_mulberry_leaves(harvest_units: int) -> int:
	var amount := harvest_units * balance.mulberry_leaves_per_harvest
	silk_workshop.leaves += amount
	GameEvents.silk_changed.emit()
	return amount

func can_use_workshop(action: SilkWorkshop.Action) -> bool:
	return silk_workshop.can_act(action, balance, player_stats.get_level(PlayerStats.Art.LITERACY), money)

func silk_reelers() -> int:
	return _count_duty(retainers, RetainerData.Duty.REEL)

func _count_duty(workers: Array[RetainerData], duty: RetainerData.Duty) -> int:
	var count := 0
	for retainer in workers:
		if retainer.duty == duty:
			count += 1
	return count

func silk_thread_yield() -> int:
	return SilkWorkshop.thread_yield(balance, silk_reelers())

func silk_night_summary(fed: Array[RetainerData]) -> String:
	return silk_workshop.describe_tonight(balance, _count_duty(fed, RetainerData.Duty.REEL))

func set_repeat_silk_batches(enabled: bool) -> void:
	if silk_workshop.built and silk_workshop.repeat_batches != enabled:
		silk_workshop.repeat_batches = enabled
		GameEvents.silk_changed.emit()

func set_night_reeling(enabled: bool) -> void:
	if silk_workshop.built and silk_workshop.night_reeling != enabled:
		silk_workshop.night_reeling = enabled
		GameEvents.silk_changed.emit()

func use_workshop(action: SilkWorkshop.Action, amount := 1) -> bool:
	if not can_use_workshop(action) or amount < 1 or amount > silk_workshop.capacity(action, balance):
		return false
	silk_workshop.apply(action, balance, silk_thread_yield(), amount)
	match action:
		SilkWorkshop.Action.BUILD:
			money -= balance.silk_workshop_cost
			GameEvents.money_changed.emit(money)
		SilkWorkshop.Action.SELL:
			silk_bolts_sold += 1
			money += balance.silk_sell_price
			GameEvents.money_changed.emit(money)
		SilkWorkshop.Action.OFFER:
			silk_bolts_offered += 1
			reputation += balance.silk_offer_reputation
			GameEvents.reputation_changed.emit(reputation)
	GameEvents.silk_changed.emit()
	return true
		
func season_order(day := 0) -> Dictionary:
	var schedule := SeasonOrders.window(day if day > 0 else current_day, balance.days_per_solar_term)
	var original: Dictionary = schedule.original_order
	var receipt: Dictionary = season_order_receipts.get(original.id, {})
	var delivered: int = receipt.get("day", 0)
	if legacy_order_start == schedule.start or (delivered >= schedule.start and delivered <= schedule.end):
		schedule.order = original
	return schedule

func season_order_delivered_at(schedule: Dictionary) -> int:
	var receipt: Dictionary = season_order_receipts.get(schedule.order.id, {})
	var day: int = receipt.get("day", 0)
	return day if day >= schedule.start and day <= schedule.end else 0

func is_season_order_pinned(schedule: Dictionary) -> bool:
	return outcome == Outcome.RUNNING and pinned_season_start == schedule.start and season_order_delivered_at(schedule) == 0

func pin_season_order(pinned: bool, upcoming := false) -> void:
	var schedule := season_order()
	var start: int = schedule.end + 1 if upcoming else schedule.start
	pinned_season_start = start if pinned else 0
	GameEvents.season_order_pin_changed.emit()

func pinned_season_order() -> Dictionary:
	var schedule := season_order()
	return schedule if is_season_order_pinned(schedule) else _pinned_order_after(schedule)

func _pinned_order_after(schedule: Dictionary) -> Dictionary:
	if pinned_season_start != schedule.end + 1:
		return {}
	var upcoming := season_order(pinned_season_start)
	return upcoming if is_season_order_pinned(upcoming) else {}

func season_order_rewards(schedule: Dictionary) -> Dictionary:
	var units := 0
	for amount in schedule.order.need.values():
		units += int(amount)
	var fish: Dictionary = CreekFish.SPECIES.get(schedule.order.get("fish", ""), {})
	var silk_value := int(schedule.order.get("silk", 0)) * balance.silk_sell_price
	return {
		"copper": units * balance.market_crop_price + int(fish.get("copper", 0)) + silk_value + balance.season_order_copper_bonus,
		"food": units + int(fish.get("food", 0)) + floori(float(silk_value) / balance.market_food_price) + balance.season_order_food_bonus,
	}

func season_order_stock(id: String) -> int:
	if id == SeasonOrders.SILK_ITEM:
		return silk_workshop.bolts
	if CreekFish.SPECIES.has(id):
		return fish_count(id)
	return crop_stock.count(id)

func season_order_stock_for(schedule: Dictionary, id: String) -> int:
	var stock := season_order_stock(id)
	if schedule.start <= current_day:
		return stock
	var current := season_order()
	if season_order_delivered_at(current) == 0:
		stock -= int(SeasonOrders.cargo(current.order).get(id, 0))
	return maxi(0, stock)

func can_deliver_season_order(schedule: Dictionary) -> bool:
	if (outcome != Outcome.RUNNING or current_day < schedule.start or current_day > schedule.end
			or season_order_delivered_at(schedule) > 0):
		return false
	var goods := SeasonOrders.cargo(schedule.order)
	for id: String in goods:
		if season_order_stock(id) < int(goods[id]):
			return false
	return true

func deliver_season_order(start_day: int, paid_in_food: bool) -> bool:
	var schedule := season_order()
	if start_day != schedule.start or not can_deliver_season_order(schedule) or not crop_stock.spend(schedule.order.need):
		return false
	var fish: String = schedule.order.get("fish", "")
	var silk: int = schedule.order.get("silk", 0)
	if not fish.is_empty():
		fish_collection[fish].stock -= 1
	silk_workshop.bolts -= silk
	var rewards := season_order_rewards(schedule)
	var previous_post := watch_relief_day() if schedule.order.id == SeasonOrders.WATCH_RELIEF else 0
	season_order_receipts[schedule.order.id] = {
		"day": current_day, "paid_in_food": paid_in_food,
		"dispatch_day": SeasonOrders.dispatch_day(current_day, day_progress),
	}
	if previous_post > 0:
		season_order_receipts[schedule.order.id]["previous_post_day"] = previous_post
	reputation += balance.interaction_reputation_gain
	if paid_in_food:
		food_storage += rewards.food
	else:
		money += rewards.copper
	GameEvents.inventory_changed.emit(player_inventory)
	if not fish.is_empty():
		GameEvents.fish_changed.emit()
	if silk > 0:
		GameEvents.silk_changed.emit()
	GameEvents.reputation_changed.emit(reputation)
	if paid_in_food:
		GameEvents.food_changed.emit(food_storage)
	else:
		GameEvents.money_changed.emit(money)
	return true

func watch_relief_progress() -> float:
	var receipt: Dictionary = season_order_receipts.get(SeasonOrders.WATCH_RELIEF, {})
	if receipt.is_empty():
		return -1.0
	var transit := SeasonOrders.transit_progress(receipt, current_day, day_progress)
	return (transit - 1.0) * SeasonOrders.TRAVEL_FRACTION / SeasonOrders.WATCH_RELAY_FRACTION

func watch_relief_day() -> int:
	var receipt: Dictionary = season_order_receipts.get(SeasonOrders.WATCH_RELIEF, {})
	if receipt.is_empty():
		return 0
	return int(receipt.dispatch_day) if watch_relief_progress() >= 1.0 else int(receipt.get("previous_post_day", 0))

func market_crop_plan(amount: int, crop_id := "") -> Dictionary[String, int]:
	return crop_stock.plan(amount, crop_id, season_order_crops_to_keep())

func season_order_crops_to_keep() -> Dictionary:
	var schedule := season_order()
	return _order_stock_to_keep(schedule, _pinned_order_after(schedule))

func travel_hearth_open() -> bool:
	return not season_order_receipts.is_empty()

func fish_for_travel_meal() -> String:
	for id: String in CreekFish.IDS:
		if fish_count(id) > 0:
			return id
	return ""

func can_pack_travel_meal(meal: String, fish_id: String) -> bool:
	return (outcome == Outcome.RUNNING and travel_hearth_open() and travel_meal.is_empty()
		and (meal != TravelMeal.RICE_FISH or fish_count(fish_id) > 0)
		and crop_stock.can_spend(TravelMeal.RECIPES[meal].crops))

func pack_travel_meal(meal: String, fish_id: String) -> bool:
	if not can_pack_travel_meal(meal, fish_id):
		return false
	crop_stock.spend(TravelMeal.RECIPES[meal].crops)
	travel_meal = meal
	if meal == TravelMeal.RICE_FISH:
		fish_collection[fish_id].stock -= 1
		GameEvents.fish_changed.emit()
	GameEvents.inventory_changed.emit(player_inventory)
	GameEvents.travel_meal_changed.emit()
	GameEvents.world_notice.emit("装好%s · %s食用" % [TravelMeal.RECIPES[meal].name, GamepadInput.meal_hint()])
	return true

func eat_travel_meal() -> bool:
	if travel_meal.is_empty() or outcome != Outcome.RUNNING:
		return false
	var benefits := TravelMeal.benefits(travel_meal, balance)
	var gain := benefits.min(Vector2i(max_stamina - current_stamina, balance.player_max_health - health))
	if gain == Vector2i.ZERO:
		GameEvents.world_notice.emit("眼下用不着这份路餐，先带着。")
		return false
	var dish: String = TravelMeal.RECIPES[travel_meal].name
	travel_meal = ""
	current_stamina += gain.x
	health += gain.y
	GameEvents.stamina_changed.emit(current_stamina)
	GameEvents.health_changed.emit(health)
	GameEvents.travel_meal_changed.emit()
	GameEvents.world_notice.emit("吃了%s · %s" % [dish, TravelMeal.describe_recovery(gain)])
	return true

func _order_stock_to_keep(schedule: Dictionary, upcoming: Dictionary) -> Dictionary:
	var keep: Dictionary = schedule.order.need.duplicate() if season_order_delivered_at(schedule) == 0 else {}
	if not upcoming.is_empty():
		for id: String in upcoming.order.need:
			keep[id] = int(keep.get(id, 0)) + int(upcoming.order.need[id])
	return keep

func set_night_rations(enabled: bool, copper_limit: int, partial_meals := false) -> void:
	var limit := clampi(copper_limit, 0, NightRations.MAX_COPPER_LIMIT)
	if outcome != Outcome.RUNNING or (night_rations.enabled == enabled and night_rations.copper_limit == limit
			and night_rations.partial_meals == partial_meals):
		return
	night_rations.enabled = enabled
	night_rations.copper_limit = limit
	night_rations.partial_meals = partial_meals
	GameEvents.night_rations_changed.emit()

func set_ration_priority(retainer: RetainerData) -> void:
	if outcome != Outcome.RUNNING or (retainer and not retainers.has(retainer)) or night_rations.priority == retainer:
		return
	night_rations.priority = retainer
	GameEvents.night_rations_changed.emit()

func night_rations_plan(finished_day := 0) -> Dictionary:
	var plan := _night_rations_supply_plan(finished_day if finished_day > 0 else current_day)
	plan.merge(_night_meal(food_storage + int(plan.supper) + int(plan.converted) + int(plan.bought)))
	return plan

func _night_rations_supply_plan(evening: int) -> Dictionary:
	var schedule := season_order(evening + 1)
	var upcoming := _pinned_order_after(schedule)
	var need := retainer_food_cost()
	var supper := mini(need, int(winter_supper_record(evening).get("portions", 0)))
	var fee := research_fee_due(evening + 1)
	var reserved := fee if money >= fee else 0
	var plan := night_rations.plan(need, food_storage + supper, money - reserved, crop_stock,
		_order_stock_to_keep(schedule, upcoming), balance.market_food_price, _night_meal)
	plan.supper = supper
	plan.research_fee = fee
	plan.research_reserve = reserved
	var current_open := season_order_delivered_at(schedule) == 0
	plan.order_name = schedule.order.title
	plan.upcoming_order_name = upcoming.order.title if not upcoming.is_empty() else ""
	plan.new_order = schedule.start == evening + 1
	plan.current_reserved = {}
	plan.upcoming_reserved = {}
	for id: String in plan.reserved:
		var total: int = plan.reserved[id]
		var current := mini(total, int(schedule.order.need.get(id, 0))) if current_open else 0
		if current > 0:
			plan.current_reserved[id] = current
		if total > current:
			plan.upcoming_reserved[id] = total - current
	return plan

func sell_crops(amount: int, crop_id := "") -> bool:
	var use := market_crop_plan(amount, crop_id)
	return not use.is_empty() and _market_exchange(use, -amount * balance.market_crop_price, 0)

func affordable_market_food() -> int:
	return floori(float(money) / balance.market_food_price)

func buy_market_food(amount: int) -> bool:
	return amount > 0 and amount <= affordable_market_food() and _market_exchange({}, amount * balance.market_food_price, amount)

func convert_inventory_to_food(amount: int, crop_id := "") -> bool:
	var use := market_crop_plan(amount, crop_id)
	return not use.is_empty() and _market_exchange(use, 0, amount)

func food_reserve_plan(nights: int) -> Dictionary:
	return _food_reserve_for(maxi(0, nights) * retainer_food_cost())

func _food_reserve_for(target: int) -> Dictionary:
	var needed := maxi(0, target - food_storage)
	var crops := mini(player_inventory, needed)
	return {"target": target, "crops": crops, "food": needed, "copper": (needed - crops) * balance.market_food_price,
		"used": market_crop_plan(crops)}

func prepare_food_reserve(nights: int) -> bool:
	var plan := food_reserve_plan(nights)
	return plan.food > 0 and _market_exchange(plan.used, plan.copper, plan.food)

func reclamation_food_plan() -> Dictionary:
	var site := reclamation_plan()
	var plan := _food_reserve_for(int(site.grain) + int(site.crew_food))
	plan.possible = site.possible
	plan.stake_grain = site.grain
	plan.stake_copper = site.copper
	plan.crew_food = site.crew_food
	plan.copper_short = maxi(0, int(site.copper) + int(plan.copper) - money)
	plan.can_order = (outcome == Outcome.RUNNING and plan.possible and plan.food > 0
		and (plan.copper == 0 or plan.copper_short == 0))
	return plan

func prepare_reclamation_food() -> bool:
	var plan := reclamation_food_plan()
	return plan.can_order and _market_exchange(plan.used, plan.copper, plan.food)

func _market_exchange(use: Dictionary, copper_spent: int, food_gained: int) -> bool:
	if copper_spent > money or not crop_stock.spend(use):
		return false

	money -= copper_spent
	food_storage += food_gained
	if not use.is_empty():
		GameEvents.inventory_changed.emit(player_inventory)
	if copper_spent != 0:
		GameEvents.money_changed.emit(money)
	if food_gained > 0:
		GameEvents.food_changed.emit(food_storage)
	return true

func eligible_for_promotion() -> bool:
	if current_rank == Rank.QING or reputation < promotion_reputation():
		return false
	match current_rank:
		Rank.XIA_SHI:
			return zhou_li_score in ["上上", "上中", "中上", "中"]
		Rank.ZHONG_SHI:
			return highest_six_art_level() >= balance.upper_rank_art_level
		Rank.DA_FU:
			return _all_six_arts_level(balance.minister_rank_art_level)
	return true

func check_rank_up() -> bool:
	if not eligible_for_promotion():
		return false
	current_rank = (current_rank + 1) as Rank
	_update_max_well_fields()
	print("Promoted to ", rank_names[current_rank], "!")
	GameEvents.rank_changed.emit(current_rank)
	return true

func promotion_reputation() -> int:
	match current_rank:
		Rank.XIA_SHI: return balance.middle_rank_reputation
		Rank.ZHONG_SHI: return balance.upper_rank_reputation
		Rank.SHANG_SHI: return balance.grandee_rank_reputation
		Rank.DA_FU: return balance.minister_rank_reputation
	return 0

func promotion_summary() -> String:
	if current_rank == Rank.QING:
		return "当前爵位 · 卿"
	var detail := ""
	match current_rank:
		Rank.XIA_SHI: detail = " · 周礼中或以上"
		Rank.ZHONG_SHI: detail = " · 任一六艺 %d 级" % balance.upper_rank_art_level
		Rank.DA_FU: detail = " · 六艺全部 %d 级" % balance.minister_rank_art_level
	return "%s → %s · 声望 %d/%d%s" % [
		rank_names[current_rank], rank_names[current_rank + 1], reputation, promotion_reputation(), detail]

func highest_six_art_level() -> int:
	var highest := 0
	for art in PlayerStats.Art.values():
		highest = maxi(highest, player_stats.get_level(art))
	return highest

# Helper: Check if all six arts reach level
func _all_six_arts_level(required_level: int) -> bool:
	for art in PlayerStats.Art.values():
		if player_stats.get_level(art) < required_level:
			return false
	return true

# Update max well fields based on rank
func _update_max_well_fields() -> void:
	max_well_fields = WELL_FIELD_LIMITS[current_rank]

# Well-Field Management Functions
func reclamation_plan() -> Dictionary:
	var has_space := well_fields.size() < max_well_fields
	var cost_rank: int = current_rank
	if not has_space:
		while cost_rank < Rank.QING and well_fields.size() >= WELL_FIELD_LIMITS[cost_rank]:
			cost_rank += 1
	var copper := balance.reclamation_cost_copper * (cost_rank + 1)
	var grain := balance.reclamation_cost_food * (cost_rank + 1)
	var workers_needed := maxi(0, RECLAMATION_RETAINERS - retainers.size())
	return {
		"copper": copper, "grain": grain, "has_space": has_space, "workers_needed": workers_needed,
		"crew_food": RECLAMATION_NIGHTS * retainer_food_cost(),
		"cost_rank": cost_rank, "possible": has_space or well_fields.size() < WELL_FIELD_LIMITS[cost_rank],
		"ready": outcome == Outcome.RUNNING and has_space and workers_needed == 0 and money >= copper and food_storage >= grain
	}

func reclaim_well_field(center: Vector2i) -> Dictionary:
	var plan := reclamation_plan()
	if not plan.ready or not add_well_field(center):
		return {}
	var field_id := well_fields.size() - 1
	money -= plan.copper
	food_storage -= plan.grain
	GameEvents.money_changed.emit(money)
	GameEvents.food_changed.emit(food_storage)
	GameEvents.well_field_added.emit(field_id)
	return {"field_id": field_id, "copper": plan.copper, "grain": plan.grain}

func can_add_well_field(center_pos: Vector2i) -> bool:
	return well_fields.size() < max_well_fields and reclamation_site(center_pos) == ReclamationSite.OPEN

func reclamation_site(center_pos: Vector2i) -> ReclamationSite:
	if not RECLAMATION_BOUNDS.grow(-1).has_point(center_pos):
		return ReclamationSite.EDGE
	for field in well_fields:
		var existing_center: Vector2i = field["center_pos"]
		var distance := (existing_center - center_pos).abs()
		if (distance.x < 3 and distance.y < 3) or existing_center.distance_to(center_pos) < balance.well_field_min_distance:
			return ReclamationSite.NEAR_FIELD
	if Rect2i(center_pos - Vector2i.ONE, Vector2i(3, 3)).has_point(irrigation.source_cell):
		return ReclamationSite.SOURCE
	for y in range(-1, 2):
		for x in range(-1, 2):
			if irrigation.channels.has(center_pos + Vector2i(x, y)):
				return ReclamationSite.CANAL
	var area := EstateLayout.field_bounds(center_pos)
	for landmark: Rect2 in EstateLayout.LANDMARKS:
		if area.intersects(landmark):
			return ReclamationSite.LANDMARK
	if EstateLayout.overlaps_road(area):
		return ReclamationSite.ROAD
	return ReclamationSite.OPEN

func add_well_field(center_pos: Vector2i) -> bool:
	if not can_add_well_field(center_pos):
		return false
	var new_field = {
		"field_id": well_fields.size(),
		"center_pos": center_pos,
		"is_unlocked": false,
		"reclamation_progress": 0,
		"assigned_retainers": []
	}
	well_fields.append(new_field)
	return true

func advance_reclamation(field_id: int) -> bool:
	if field_id < 0 or field_id >= well_fields.size():
		return false

	var field = well_fields[field_id]
	if field["reclamation_progress"] < RECLAMATION_NIGHTS:
		field["reclamation_progress"] += 1
		if field["reclamation_progress"] >= RECLAMATION_NIGHTS:
			field["is_unlocked"] = true
			print("Well field ", field_id, " is now ready for planting!")
		GameEvents.well_field_reclaimed.emit(field_id, field["reclamation_progress"])
		return true
	return false

func get_well_field(field_id: int) -> Dictionary:
	if field_id >= 0 and field_id < well_fields.size():
		return well_fields[field_id]
	return {}

func reclamation_stage(progress: int) -> String:
	return RECLAMATION_STAGES[clampi(progress, 0, RECLAMATION_NIGHTS - 1)]

func channel_cost() -> int:
	return maxi(0, balance.irrigation_channel_cost)

func check_channel_site(cell: Vector2i) -> ChannelSite:
	if not tech_unlocked["irrigation"]:
		return ChannelSite.LOCKED
	if cell == irrigation.source_cell or not RECLAMATION_BOUNDS.has_point(cell) or _is_well_field_cell(cell, well_fields):
		return ChannelSite.BLOCKED
	if irrigation.channels.has(cell):
		return ChannelSite.ALREADY_BUILT
	if EstateLayout.is_foundation(cell):
		return ChannelSite.FOUNDATION
	if money < channel_cost():
		return ChannelSite.NO_FUNDS
	return ChannelSite.AVAILABLE

func build_channel(cell: Vector2i) -> ChannelSite:
	return build_channel_path([cell])

func channel_build_plan(route: Array[Vector2i], survey := false) -> Dictionary:
	var additions: Array[Vector2i] = []
	var result := {"site": ChannelSite.AVAILABLE, "additions": additions, "cost": 0, "blocked_cell": Vector2i.ZERO}
	if not tech_unlocked["irrigation"] or (survey and channel_survey_day == 0):
		result["site"] = ChannelSite.LOCKED
		return result
	for cell in route:
		if survey and (cell == irrigation.source_cell or irrigation.channels.has(cell)):
			continue
		var site := check_channel_site(cell)
		if site in [ChannelSite.BLOCKED, ChannelSite.ALREADY_BUILT, ChannelSite.FOUNDATION]:
			result["site"] = site
			result["blocked_cell"] = cell
			additions.clear()
			return result
		if cell not in additions:
			additions.append(cell)
	result["cost"] = additions.size() * channel_cost()
	if additions.is_empty():
		result["site"] = ChannelSite.ALREADY_BUILT
	elif money < result["cost"]:
		result["site"] = ChannelSite.NO_FUNDS
	return result

func build_channel_path(route: Array[Vector2i], survey := false) -> ChannelSite:
	var plan := channel_build_plan(route, survey)
	var site: ChannelSite = plan["site"]
	if site == ChannelSite.AVAILABLE:
		irrigation.add_channels(plan["additions"])
		money -= plan["cost"]
		GameEvents.money_changed.emit(money)
		GameEvents.channels_changed.emit()
	return site

func fill_channel(cell: Vector2i) -> bool:
	if not tech_unlocked["irrigation"] or not irrigation.remove_channel(cell):
		return false
	GameEvents.channels_changed.emit()
	return true

func water_review_ready() -> bool:
	return first_channel_growth_day > 0 and channel_survey_day == 0

func learn_channel_survey() -> bool:
	if outcome != Outcome.RUNNING or not water_review_ready():
		return false
	channel_survey_day = current_day
	GameEvents.channel_survey_learned.emit()
	return true

func irrigated_well_fields() -> int:
	var supplied := 0
	for field in well_fields:
		if field["is_unlocked"] and not irrigation.watered_footprint(field["center_pos"]).is_empty():
			supplied += 1
	return supplied

func _is_well_field_cell(cell: Vector2i, fields: Array[Dictionary]) -> bool:
	for field in fields:
		var center: Vector2i = field["center_pos"]
		if Rect2i(center - Vector2i.ONE, Vector2i(3, 3)).has_point(cell):
			return true
	return false

func _water_source_for(fields: Array[Dictionary]) -> Vector2i:
	for cell: Vector2i in Irrigation.SOURCE_CANDIDATES:
		if not _is_well_field_cell(cell, fields):
			return cell
	return Vector2i(RECLAMATION_BOUNDS.position.x - 1, 5)

func save_game() -> Error:
	var result := _save_snapshot("")
	GameEvents.save_finished.emit(result, false)
	return result

func save_automatically(origin: String) -> void:
	if Preferences.autosave and outcome == Outcome.RUNNING:
		GameEvents.save_finished.emit(_save_snapshot(origin), true)

func _save_snapshot(origin: String) -> Error:
	var folder := _campaign_directory()
	var created := DirAccess.make_dir_recursive_absolute(folder)
	if created != OK:
		return created
	var catalog := saved_games()
	var previous: int = 0 if catalog.is_empty() else catalog[0]["sequence"]
	var sequence := maxi(previous + 1, int(Time.get_unix_time_from_system() * SAVE_TIME_SCALE))
	var path := manual_save_path() if origin.is_empty() else _next_auto_slot(folder, catalog)
	var saved_crops := {}
	for cell in active_crops:
		var crop = active_crops[cell]
		saved_crops[_cell_key(cell)] = {
			"id": crop["id"],
			"age": crop["age"],
			"growth_nights": crop["growth_nights"],
			"watered": crop["watered"],
			"requires_channel": crop.get("requires_channel", false)
		}

	var saved_fields := []
	for field in well_fields:
		var entry := field.duplicate()
		entry["center_pos"] = _cell_key(field["center_pos"])
		saved_fields.append(entry)

	var saved_soil := []
	for cell in tilled_cells:
		saved_soil.append(_cell_key(cell))

	var saved_seed_plans := {}
	for cell in field_seed_plans:
		saved_seed_plans[_cell_key(cell)] = field_seed_plans[cell]

	var saved_fertility := []
	for cell in fertile_cells:
		saved_fertility.append(_cell_key(cell))

	var saved_channels := []
	for cell in irrigation.channels:
		saved_channels.append(_cell_key(cell))

	var saved_retainers := []
	for retainer in retainers:
		saved_retainers.append({
			"name": retainer.name,
			"profession": retainer.profession,
			"school": retainer.school,
			"duty": retainer.duty,
			"visitor_appearance": retainer.visitor_appearance,
			"hunger": retainer.hunger,
			"loyalty": retainer.loyalty,
			"efficiency": retainer.efficiency,
			"assigned_area": _cell_key(retainer.assigned_area)
		})

	var scene := get_tree().current_scene
	var location: Variant = SAVE_SCENES.find_key(scene.scene_file_path) if scene != null else null
	var data := {
		"save_version": SAVE_VERSION,
		"save_sequence": sequence,
		"save_origin": origin,
		"campaign_id": campaign_id,
		"campaign_name": campaign_name,
		"current_day": current_day,
		"day_progress": day_progress,
		"estate_room": estate_room,
		"location": "estate" if location == null else location,
		"ravine_waypoint": scene.active_waypoint() if location == "ravine" else "",
		"ravine_south_arrival": scene.resume_from_south_trail() if location == "ravine" else false,
		"west_road_from_market": scene.resume_from_market() if location == "west_road" else false,
		"selected_seed": selected_seed_id,
		"field_route_status": field_route_status,
		"field_route_public_only": field_route_public_only,
		"current_stamina": current_stamina,
		"health": health,
		"outcome": outcome,
		"ending_record": ending_record,
		"raid_day": raid_day,
		"raid_kind": raid_kind,
		"raid_health": raid_health,
		"raids_defeated": raids_defeated,
		"raid_crop_losses": raid_crop_losses,
		"last_defense": last_defense,
		"east_watch_day": east_watch_day,
		"last_forage_day": last_forage_day,
		"last_fishing_day": last_fishing_day,
		"ravine_trip_target": ravine_trip_target,
		"market_trip_target": market_trip_target,
		"fish_collection": fish_collection,
		"fish_order_receipt": fish_order_receipt,
		"creek_trap": creek_trap,
		"ravine_journal": {
			"recorded_days": ravine_journal.recorded_days,
			"garden_day": ravine_journal.garden_day,
			"garden_harvest_day": ravine_journal.garden_harvest_day
		},
		"money": money,
		"player_inventory": player_inventory,
		"crop_stock": crop_stock.lots,
		"season_order_receipts": season_order_receipts,
		"legacy_order_start": legacy_order_start,
		"pinned_season_start": pinned_season_start,
		"travel_meal": travel_meal,
		"king_storage": king_storage,
		"private_harvest_total": private_harvest_total,
		"silk_bolts_sold": silk_bolts_sold,
		"silk_bolts_offered": silk_bolts_offered,
		"silk_sample_day": silk_sample_day,
		"food_storage": food_storage,
		"night_rations": {
			"enabled": night_rations.enabled,
			"partial_meals": night_rations.partial_meals,
			"copper_limit": night_rations.copper_limit,
			"priority": retainers.find(night_rations.priority),
			"last": night_rations.last,
		},
		"last_field_night": last_field_night,
		"last_dawn": last_dawn,
		"away_field_report": away_field_report,
		"reputation": reputation,
		"days_without_contribution": days_without_contribution,
		"active_crops": saved_crops,
		"tilled_cells": saved_soil,
		"field_seed_plans": saved_seed_plans,
		"fertile_cells": saved_fertility,
		"irrigation_channels": saved_channels,
		"first_channel_growth_day": first_channel_growth_day,
		"channel_survey_day": channel_survey_day,
		"silk_workshop": {
			"built": silk_workshop.built,
			"leaves": silk_workshop.leaves,
			"cocoons": silk_workshop.cocoons,
			"raw_silk": silk_workshop.raw_silk,
			"bolts": silk_workshop.bolts,
			"nights_left": silk_workshop.nights_left,
			"repeat_batches": silk_workshop.repeat_batches,
			"night_reeling": silk_workshop.night_reeling,
			"last_leaves_used": silk_workshop.last_leaves_used,
			"last_hatched": silk_workshop.last_hatched,
			"last_reeled": silk_workshop.last_reeled,
			"last_reel_thread": silk_workshop.last_reel_thread
		},
		"retainers": saved_retainers,
		"visitor_encounters": visitor_encounters.keys(),
		"visitor_talk_days": visitor_encounters,
		"neighbor_met_days": neighbor_met_days,
		"neighbor_departures": neighbor_departures,
		"field_rotation": {
			"promise_day": field_rotation.promise_day,
			"beans_day": field_rotation.beans_day,
			"harvest_day": field_rotation.harvest_day,
			"field_number": field_rotation.field_number,
			"crop_id": field_rotation.crop_id,
			"signed_day": field_rotation.signed_day,
		},
		"last_recruit_day": last_recruit_day,
		"last_recruit_outside_rotation": last_recruit_outside_rotation,
		"road_provisions_delivered": road_provisions_delivered,
		"road_provisions_day": road_provisions_day,
		"road_rest_paid_day": road_rest_paid_day,
		"road_rest_used_day": road_rest_used_day,
		"player_stats": player_stats.stats,
		"practice_days": practice_days,
		"best_driving_ms": best_driving_ms,
		"gathering_recitals": gathering_recitals,
		"summer_raft_results": summer_raft_results,
		"autumn_exhibits": autumn_exhibits,
		"winter_suppers": winter_suppers,
		"sheepfold": sheepfold.save_record(),
		"tech_unlocked": tech_unlocked,
		"current_rank": current_rank,
		"attire": attire_id,
		"hall_mat": hall_mat_id,
		"hall_shelf": hall_shelf_id,
		"well_fields": saved_fields,
		"tax_reform_choice": tax_reform_choice,
		"tax_reform_year": tax_reform_year,
		"tax_reform_day": tax_reform_day,
		"tax_council_invited": tax_council_invited,
		"research_choice_pending": research_choice_pending,
		"route_baseline": route_baseline,
		"tax_rate": tax_rate,
		"zhou_li_score": zhou_li_score,
		"quest_progress": quest_progress,
		"quest_completed": quest_completed
	}

	var pending_path := "%s.%d.tmp" % [path, OS.get_process_id()]
	var file := FileAccess.open(pending_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written := file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if not written or write_error != OK:
		DirAccess.remove_absolute(pending_path)
		return write_error if write_error != OK else ERR_FILE_CANT_WRITE

	var replace_error := DirAccess.rename_absolute(pending_path, path)
	if replace_error != OK:
		DirAccess.remove_absolute(pending_path)
	else:
		checkpoint_sequence = sequence
	return replace_error

func _campaign_directory() -> String:
	return CAMPAIGN_SAVE_ROOT.path_join(campaign_id.md5_text())

func manual_save_path() -> String:
	return _campaign_directory().path_join(SAVE_PATH.get_file())

func _campaign_auto_slots(folder: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for slot: String in AUTO_SAVE_PATHS:
		paths.append(folder.path_join(slot.get_file()))
	return paths

func _next_auto_slot(folder: String, catalog: Array[Dictionary]) -> String:
	var slots := _campaign_auto_slots(folder)
	for path in slots:
		if not FileAccess.file_exists(path):
			return path
	for index in range(catalog.size() - 1, -1, -1):
		var path: String = catalog[index]["path"]
		if path in slots:
			return path
	return slots[0]

func _save_paths() -> PackedStringArray:
	var paths := PackedStringArray([SAVE_PATH] + AUTO_SAVE_PATHS)
	if DirAccess.dir_exists_absolute(CAMPAIGN_SAVE_ROOT):
		for name: String in DirAccess.get_directories_at(CAMPAIGN_SAVE_ROOT):
			var folder := CAMPAIGN_SAVE_ROOT.path_join(name)
			paths.append(folder.path_join(SAVE_PATH.get_file()))
			paths.append_array(_campaign_auto_slots(folder))
	return paths

func has_saved_game() -> bool:
	for path in _save_paths():
		if FileAccess.file_exists(path):
			return true
	return false

func next_campaign_name() -> String:
	var campaigns := {}
	for entry in saved_games():
		campaigns[entry["campaign_key"]] = true
	return "封地 %d" % (campaigns.size() + 1)

func saved_games() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	for path in _save_paths():
		if not FileAccess.file_exists(path):
			continue
		var snapshot := _read_snapshot(path)
		var data: Dictionary = snapshot["data"]
		var readable: bool = snapshot["error"] == OK
		var sequence := _snapshot_sequence(data, path) if readable else -1
		var campaign := _snapshot_campaign(data)
		var legacy := not path.begins_with(CAMPAIGN_SAVE_ROOT + "/")
		var campaign_key := campaign.md5_text() if readable or legacy else path.get_base_dir().get_file()
		var source := "手动存档"
		if path.get_file() != SAVE_PATH.get_file():
			match data.get("save_origin"):
				"council": source = "初税亩自动存档"
				"ending_continue": source = "续营自动存档"
				_: source = "晨间自动存档"
		var saved_outcome := _read_save_int(data.get("outcome"), Outcome.RUNNING)
		var saved_record := _saved_ending_record(data)
		catalog.append({
			"path": path,
			"source": source,
			"sequence": sequence,
			"day": _read_save_int(data.get("current_day"), 0),
			"watch": DAY_WATCHES[_day_watch_index(_saved_day_progress(data))] + "时",
			"location": SAVE_LOCATION_NAMES.get(data.get("location"), ""),
			"rank": clampi(_read_save_int(data.get("current_rank"), Rank.XIA_SHI), Rank.XIA_SHI, Rank.QING),
			"campaign": campaign,
			"campaign_key": campaign_key,
			"campaign_name": _snapshot_campaign_name(data) if readable else "受损存档",
			"legacy": legacy,
			"tax_choice": _read_save_int(data.get("tax_reform_choice"), TaxReformChoice.NONE),
			"outcome": saved_outcome,
			"completed_route": _read_save_int(saved_record.get("outcome"), saved_outcome),
			"running": saved_outcome == Outcome.RUNNING and _read_save_int(data.get("health"), balance.player_max_health) > 0,
			"error": snapshot["error"],
		})
	catalog.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["sequence"] > b["sequence"])
	return catalog

func saved_game_caption(entry: Dictionary) -> String:
	var caption := "%s · 第 %d 天 · %s · %s" % [entry["source"], entry["day"], get_current_solar_term(entry["day"]), entry["watch"]]
	var location: String = entry.get("location", "")
	return caption if location.is_empty() else caption + " · " + location

func saved_game_route(entry: Dictionary) -> String:
	match entry["completed_route"]:
		Outcome.TRADITIONAL: return "守礼安邦 · 已通关"
		Outcome.REFORMED: return "税亩富民 · 已通关"
	match entry["tax_choice"]:
		TaxReformChoice.TRADITIONAL: return "坚守传统"
		TaxReformChoice.REFORMED: return "支持改革"
		TaxReformChoice.DELAYED: return "研究初税亩"
	return ""

func _saved_day_progress(data: Dictionary) -> float:
	return clampf(_read_save_number(data.get("day_progress"), 0.0), 0.0, 1.0)

func latest_saved_game(current_campaign_only := false) -> Dictionary:
	for entry in saved_games():
		if entry["error"] == OK and _can_resume(entry, current_campaign_only):
			return entry
	return {}

func load_latest_game(current_campaign_only := false) -> Error:
	var catalog := saved_games()
	var key := campaign_id.md5_text()
	var unavailable := catalog.any(func(entry: Dictionary) -> bool:
		return entry["error"] != OK and (not current_campaign_only or entry["campaign_key"] == key))
	var failure := ERR_FILE_CORRUPT if unavailable and not current_campaign_only else ERR_FILE_NOT_FOUND
	for entry in catalog:
		if entry["error"] != OK or not _can_resume(entry, current_campaign_only):
			continue
		var result := load_game(entry["path"])
		if result == OK:
			if unavailable:
				restore_notice = "部分存档无法读取 · 已载入第 %d 天" % current_day
			return OK
		failure = result
		unavailable = true
	return failure

func _can_resume(entry: Dictionary, current_campaign_only: bool) -> bool:
	return not current_campaign_only or (entry["campaign"] == campaign_id and entry["running"]
		and entry["sequence"] <= checkpoint_sequence and entry["day"] <= current_day)

func _snapshot_sequence(data: Dictionary, path: String) -> int:
	return _read_save_int(data.get("save_sequence"), FileAccess.get_modified_time(path) * SAVE_TIME_SCALE)

func _snapshot_campaign(data: Dictionary) -> String:
	var key = data.get("campaign_id")
	return key if key is String and not key.is_empty() else "legacy"

func _snapshot_campaign_name(data: Dictionary) -> String:
	var estate_name = data.get("campaign_name")
	return estate_name.left(16) if estate_name is String and not estate_name.is_empty() else "旧封地"

func _read_snapshot(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": FileAccess.get_open_error(), "data": {}}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not json.data is Dictionary:
		return {"error": ERR_FILE_CORRUPT, "data": {}}

	var data: Dictionary = json.data
	var version := _read_save_int(data.get("save_version", 0), -1)
	var saved_day := _read_save_int(data.get("current_day"), 0)
	if version < 0 or version > SAVE_VERSION or saved_day < 1:
		return {"error": ERR_FILE_CORRUPT, "data": {}}
	return {"error": OK, "data": data}

func load_game(path := "") -> Error:
	if path.is_empty():
		path = manual_save_path()
		if not FileAccess.file_exists(path):
			path = SAVE_PATH
	var snapshot := _read_snapshot(path)
	if snapshot["error"] != OK:
		return snapshot["error"]
	var data: Dictionary = snapshot["data"]
	var version := _read_save_int(data.get("save_version", 0), 0)
	var saved_day := _read_save_int(data["current_day"], 1)
	var crop_records = data.get("active_crops", {})
	var soil_records = data.get("tilled_cells", [])
	var fertility_records = data.get("fertile_cells", [])
	var field_records = data.get("well_fields", [])
	var channel_records = data.get("irrigation_channels", [])
	var workshop_record = data.get("silk_workshop", {})
	var retainer_records = data.get("retainers", [])
	var encounter_records = data.get("visitor_encounters", [])
	var talk_records = data.get("visitor_talk_days", {})
	var stats_records = data.get("player_stats", {})
	var practice_records = data.get("practice_days", {})
	var recital_records = data.get("gathering_recitals", {})
	var technology = data.get("tech_unlocked", {})
	if not (crop_records is Dictionary and soil_records is Array and field_records is Array
			and retainer_records is Array and stats_records is Dictionary and technology is Dictionary
			and channel_records is Array and fertility_records is Array and workshop_record is Dictionary
			and encounter_records is Array and talk_records is Dictionary and practice_records is Dictionary
			and recital_records is Dictionary):
		return ERR_FILE_CORRUPT
	var restored_recitals: Dictionary[int, int] = {}
	for key in recital_records:
		var date: String = key
		var day := date.to_int() if date.is_valid_int() else 0
		var hits := _read_save_int(recital_records[key], 0)
		if day > 0 and day <= saved_day and hits >= GATHERING_MIN_HITS and hits <= GATHERING_BEATS:
			restored_recitals[day] = hits

	var restored_soil := {}
	for key in soil_records:
		var cell = _read_save_cell(key)
		if cell == null:
			return ERR_FILE_CORRUPT
		restored_soil[cell] = true

	var restored_crops := {}
	for key in crop_records:
		var cell = _read_save_cell(key)
		var entry = crop_records[key]
		if cell == null or not entry is Dictionary:
			return ERR_FILE_CORRUPT
		var id = entry.get("id", "millet")
		var crop := ItemManager.get_crop(id) if id is String else null
		if crop == null:
			return ERR_FILE_CORRUPT
		restored_crops[cell] = {
			"id": id,
			"data": crop,
			"age": maxi(0, _read_save_int(entry.get("age"), 0)),
			"growth_nights": maxi(1, _read_save_int(entry.get("growth_nights"), crop.days_to_grow)),
			"watered": entry.get("watered", false) == true,
			"requires_channel": crop.is_water_crop and entry.get("requires_channel", false) == true
		}
		restored_soil[cell] = true

	var restored_fields: Array[Dictionary] = []
	for entry in field_records:
		if not entry is Dictionary:
			return ERR_FILE_CORRUPT
		var center = _read_save_cell(entry.get("center_pos"))
		if center == null:
			return ERR_FILE_CORRUPT
		restored_fields.append({
			"field_id": restored_fields.size(),
			"center_pos": center,
			"is_unlocked": entry.get("is_unlocked", false) == true,
			"reclamation_progress": clampi(_read_save_int(entry.get("reclamation_progress"), 0), 0, RECLAMATION_NIGHTS),
			"assigned_retainers": []
		})

	var water_source := _water_source_for(restored_fields)
	var restored_channels: Dictionary[Vector2i, bool] = {}
	if not channel_records.is_empty() and restored_fields.is_empty():
		return ERR_FILE_CORRUPT
	for key in channel_records:
		var cell = _read_save_cell(key)
		if cell == null or cell == water_source or not RECLAMATION_BOUNDS.has_point(cell) or _is_well_field_cell(cell, restored_fields):
			return ERR_FILE_CORRUPT
		restored_channels[cell] = true

	var restored_fertility: Dictionary[Vector2i, bool] = {}
	for key in fertility_records:
		var cell = _read_save_cell(key)
		if cell == null or not _is_well_field_cell(cell, restored_fields):
			return ERR_FILE_CORRUPT
		restored_fertility[cell] = true

	var restored_workshop := SilkWorkshop.new()
	restored_workshop.built = workshop_record.get("built", false) == true
	restored_workshop.leaves = maxi(0, _read_save_int(workshop_record.get("leaves"), 0))
	restored_workshop.cocoons = maxi(0, _read_save_int(workshop_record.get("cocoons"), 0))
	restored_workshop.raw_silk = maxi(0, _read_save_int(workshop_record.get("raw_silk"), 0))
	restored_workshop.bolts = maxi(0, _read_save_int(workshop_record.get("bolts"), 0))
	if restored_workshop.built:
		restored_workshop.nights_left = maxi(0, _read_save_int(workshop_record.get("nights_left"), 0))
		restored_workshop.repeat_batches = workshop_record.get("repeat_batches", false) == true
		restored_workshop.night_reeling = workshop_record.get("night_reeling", false) == true
		restored_workshop.last_leaves_used = maxi(0, _read_save_int(workshop_record.get("last_leaves_used"), 0))
		restored_workshop.last_hatched = maxi(0, _read_save_int(workshop_record.get("last_hatched"), 0))
		restored_workshop.last_reeled = maxi(0, _read_save_int(workshop_record.get("last_reeled"), 0))
		restored_workshop.last_reel_thread = maxi(0, _read_save_int(workshop_record.get("last_reel_thread"), 0))

	var restored_retainers: Array[RetainerData] = []
	var last_duty := RetainerData.Duty.size() - 1 if version >= 2 else RetainerData.Duty.GUARD
	for entry in retainer_records:
		if not entry is Dictionary:
			return ERR_FILE_CORRUPT
		var school := clampi(_read_save_int(entry.get("school"), 0), 0, RetainerData.School.size() - 1)
		var retainer := RetainerData.new(str(entry.get("name", "无名氏")), str(entry.get("profession", "农夫")), school)
		var duty := clampi(_read_save_int(entry.get("duty"), 0), 0, last_duty) as RetainerData.Duty
		if retainer.can_take_duty(duty) and (duty != RetainerData.Duty.REEL or restored_workshop.built):
			retainer.duty = duty
		retainer.visitor_appearance = clampi(_read_save_int(entry.get("visitor_appearance"), -1), -1, VisitorData.School.size() - 1)
		retainer.hunger = clampf(_read_save_number(entry.get("hunger"), 0.0), 0.0, 100.0)
		retainer.loyalty = clampf(_read_save_number(entry.get("loyalty"), 100.0), 0.0, 100.0)
		retainer.efficiency = clampf(_read_save_number(entry.get("efficiency"), 1.0), 0.1, 5.0)
		var assignment = _read_save_cell(entry.get("assigned_area"))
		# Older saves used a valid map coordinate to mean no assignment.
		if assignment != null and (version >= 2 or assignment != Vector2i(-1, -1)):
			retainer.assigned_area = assignment
		restored_retainers.append(retainer)
	if not data.has("retainers"):
		restored_retainers.append(_starter_retainer())

	var restored_encounters: Dictionary[String, int] = {}
	for visitor_name in encounter_records:
		if not visitor_name is String or visitor_name.is_empty():
			return ERR_FILE_CORRUPT
		restored_encounters[visitor_name] = 0
	for visitor_name in talk_records:
		if not visitor_name is String or visitor_name.is_empty():
			return ERR_FILE_CORRUPT
		restored_encounters[visitor_name] = clampi(_read_save_int(talk_records[visitor_name], 0), 0, saved_day)

	var restored_stats := PlayerStats.new()
	var restored_practice: Dictionary[String, int] = {}
	for art in restored_stats.stats:
		var entry = stats_records.get(art, {})
		if not entry is Dictionary:
			return ERR_FILE_CORRUPT
		var max_xp := maxi(1, _read_save_int(entry.get("max_xp"), 100))
		restored_stats.stats[art] = {
			"level": maxi(1, _read_save_int(entry.get("level"), 1)),
			"xp": clampi(_read_save_int(entry.get("xp"), 0), 0, max_xp - 1),
			"max_xp": max_xp
		}
		var last_practice := clampi(_read_save_int(practice_records.get(art), 0), 0, saved_day)
		if last_practice > 0:
			restored_practice[art] = last_practice

	var saved_health := clampi(_read_save_int(data.get("health"), balance.player_max_health), 0, balance.player_max_health)
	var saved_outcome := clampi(_read_save_int(data.get("outcome"), Outcome.RUNNING), Outcome.RUNNING, Outcome.REFORMED) as Outcome
	if saved_health == 0 and saved_outcome == Outcome.RUNNING:
		saved_outcome = Outcome.DEFEAT_COMBAT
	var resume_scene: String = ESTATE_SCENE
	if saved_outcome == Outcome.RUNNING:
		resume_scene = SAVE_SCENES.get(data.get("location"), ESTATE_SCENE)
	# The replacement scene enters the tree at the end of the frame.
	var reload_error := get_tree().change_scene_to_file(resume_scene)
	if reload_error != OK:
		return reload_error

	campaign_id = _snapshot_campaign(data)
	campaign_name = _snapshot_campaign_name(data)
	checkpoint_sequence = _snapshot_sequence(data, path)
	restore_notice = ""
	current_day = saved_day
	day_progress = _saved_day_progress(data)
	var saved_seed: Variant = data.get("selected_seed")
	selected_seed_id = saved_seed if saved_seed is String and CropData.IDS.has(saved_seed) else CropData.IDS[0]
	current_stamina = clampi(_read_save_int(data.get("current_stamina"), max_stamina), 0, max_stamina)
	health = saved_health
	outcome = saved_outcome
	var legacy_room := EstateRoom.HALL if data.get("inside_hall", false) == true else EstateRoom.OUTDOORS
	var saved_room := _read_save_int(data.get("estate_room"), legacy_room)
	estate_room = (saved_room as EstateRoom if outcome == Outcome.RUNNING and resume_scene == ESTATE_SCENE
		and saved_room in EstateRoom.values() else EstateRoom.OUTDOORS)
	raid_day = clampi(_read_save_int(data.get("raid_day"), 0), 0, saved_day)
	raid_kind = clampi(_read_save_int(data.get("raid_kind"), 0), 0, 1)
	raid_health = maxi(-1, _read_save_int(data.get("raid_health"), -1))
	raids_defeated = maxi(0, _read_save_int(data.get("raids_defeated"), 0))
	raid_crop_losses = maxi(0, _read_save_int(data.get("raid_crop_losses"), 0)) if raid_day > 0 else 0
	last_defense = _restore_defense(data.get("last_defense"), saved_day)
	east_watch_day = clampi(_read_save_int(data.get("east_watch_day"), 0), 0, saved_day) if not last_defense.is_empty() else 0
	last_forage_day = clampi(_read_save_int(data.get("last_forage_day"), 0), 0, saved_day)
	# Old saves used one daily record for both activities.
	last_fishing_day = clampi(_read_save_int(data.get("last_fishing_day"), last_forage_day), 0, saved_day)
	_restore_fish_collection(data.get("fish_collection"), saved_day)
	fish_order_receipt = _restore_fish_order_receipt(data.get("fish_order_receipt"), saved_day)
	creek_trap = _restore_creek_trap(data.get("creek_trap"), saved_day)
	var saved_trip: Variant = data.get("ravine_trip_target")
	ravine_trip_target = saved_trip if saved_trip is String and saved_trip in ravine_trip_places() else ""
	var saved_waypoint: Variant = data.get("ravine_waypoint")
	restored_ravine_waypoint = saved_waypoint if resume_scene == WILDERNESS_SCENE and saved_waypoint is String else ""
	var saved_market_trip: Variant = data.get("market_trip_target")
	var market_places := MarketStall.TITLES + [MARKET_ORDERS, MARKET_RETURN, VisitorData.SILK_MERCHANT, Sheepfold.MEADOW]
	market_trip_target = saved_market_trip if saved_market_trip is String and saved_market_trip in market_places else ""
	var saved_route := _read_save_int(data.get("field_route_status"), -1)
	field_route_status = saved_route if saved_route in FIELD_ROUTE_STATES else -1
	field_route_public_only = field_route_status == NightGrowth.READY and data.get("field_route_public_only", false) == true
	ravine_journal = _restore_ravine_journal(data.get("ravine_journal"), saved_day)
	restored_ravine_south = (resume_scene == WILDERNESS_SCENE and ravine_shortcut_open()
		and data.get("ravine_south_arrival", false) == true)
	restored_west_road_from_market = resume_scene == WEST_ROAD_SCENE and data.get("west_road_from_market", false) == true
	money = maxi(0, _read_save_int(data.get("money"), 0))
	_restore_crop_stock(data.get("crop_stock"), maxi(0, _read_save_int(data.get("player_inventory"), 0)))
	_restore_season_order_receipts(data.get("season_order_receipts"), saved_day)
	var order_window := SeasonOrders.window(saved_day, balance.days_per_solar_term)
	# Finish the active order from an older save before changing to the new schedule.
	var old_start: int = order_window.start if order_window.order.id != order_window.original_order.id else 0
	legacy_order_start = _read_save_int(data.get("legacy_order_start"), old_start)
	pinned_season_start = _read_save_int(data.get("pinned_season_start"), 0)
	var packed_meal: Variant = data.get("travel_meal")
	travel_meal = packed_meal if packed_meal is String and TravelMeal.RECIPES.has(packed_meal) else ""
	king_storage = maxi(0, _read_save_int(data.get("king_storage"), 0))
	private_harvest_total = maxi(0, _read_save_int(data.get("private_harvest_total"), player_inventory))
	silk_bolts_sold = maxi(0, _read_save_int(data.get("silk_bolts_sold"), 0))
	silk_bolts_offered = maxi(0, _read_save_int(data.get("silk_bolts_offered"), 0))
	silk_sample_day = clampi(_read_save_int(data.get("silk_sample_day"), 0), 0, saved_day)
	food_storage = maxi(0, _read_save_int(data.get("food_storage"), 10))
	night_rations = _restore_night_rations(data.get("night_rations"), saved_day, restored_retainers)
	last_field_night = _restore_field_night(data.get("last_field_night"), saved_day)
	away_field_report = _restore_away_field_report(data.get("away_field_report"), saved_day)
	_away_work_elapsed.clear()
	reputation = _read_save_int(data.get("reputation"), 0)
	days_without_contribution = maxi(0, _read_save_int(data.get("days_without_contribution"), 0))
	active_crops = restored_crops
	tilled_cells = restored_soil
	fertile_cells = restored_fertility
	well_fields = restored_fields
	last_dawn = _restore_dawn(data.get("last_dawn"), saved_day)
	irrigation.restore(water_source, restored_channels)
	first_channel_growth_day = clampi(_read_save_int(data.get("first_channel_growth_day"), 0), 0, saved_day)
	var saved_survey := _read_save_int(data.get("channel_survey_day"), 0)
	channel_survey_day = mini(saved_survey, saved_day) if first_channel_growth_day > 0 and saved_survey >= first_channel_growth_day else 0
	silk_workshop = restored_workshop
	retainers = restored_retainers
	visitor_encounters = restored_encounters
	neighbor_met_days.clear()
	var known_days: Variant = data.get("neighbor_met_days")
	if known_days is Dictionary:
		for speaker: String in VisitorData.NEIGHBORS:
			var first_day := _read_save_int(known_days.get(speaker), 0)
			if first_day > 0 and first_day <= saved_day:
				neighbor_met_days[speaker] = first_day
	_restore_neighbor_departures(data.get("neighbor_departures"), saved_day)
	last_recruit_day = clampi(_read_save_int(data.get("last_recruit_day"), 0), 0, saved_day)
	last_recruit_outside_rotation = data.get("last_recruit_outside_rotation", data.get("last_recruit_from_handoff", false)) == true
	road_provisions_delivered = data.get("road_provisions_delivered", false) == true
	road_provisions_day = clampi(_read_save_int(data.get("road_provisions_day"), 0), 0, saved_day) if road_provisions_delivered else 0
	var paid_day := _read_save_int(data.get("road_rest_paid_day"), 0)
	road_rest_paid_day = paid_day if road_provisions_delivered and paid_day > road_provisions_day and paid_day <= saved_day else 0
	var used_day := _read_save_int(data.get("road_rest_used_day"), 0)
	road_rest_used_day = used_day if road_rest_paid_day > 0 and used_day > road_rest_paid_day and used_day <= saved_day else 0
	player_stats = restored_stats
	practice_days = restored_practice
	best_driving_ms = maxi(0, _read_save_int(data.get("best_driving_ms"), 0))
	gathering_recitals = restored_recitals
	_restore_summer_raft_results(data.get("summer_raft_results"), saved_day)
	_restore_autumn_exhibits(data.get("autumn_exhibits"), saved_day)
	_restore_winter_suppers(data.get("winter_suppers"), saved_day)
	_restore_sheepfold(data.get("sheepfold"), saved_day)
	tech_unlocked = {
		"irrigation": technology.get("irrigation", false) == true,
		"composite_bow": technology.get("composite_bow", false) == true
	}
	current_rank = clampi(_read_save_int(data.get("current_rank"), Rank.XIA_SHI), Rank.XIA_SHI, Rank.QING) as Rank
	var saved_attire: String = str(data.get("attire", PlayerAttire.DEFAULT))
	attire_id = saved_attire if can_wear_attire(saved_attire) else PlayerAttire.DEFAULT
	tax_reform_choice = clampi(_read_save_int(data.get("tax_reform_choice"), TaxReformChoice.NONE),
		TaxReformChoice.NONE, TaxReformChoice.TRADITIONAL) as TaxReformChoice
	tax_reform_year = maxi(0, _read_save_int(data.get("tax_reform_year"), 0))
	tax_reform_day = clampi(_read_save_int(data.get("tax_reform_day"), current_day if tax_reform_year > 0 else 0), 0, current_day)
	tax_council_invited = tax_reform_choice == TaxReformChoice.NONE and data.get("tax_council_invited", false) == true
	research_choice_pending = tax_reform_choice == TaxReformChoice.DELAYED and data.get("research_choice_pending", false) == true
	tax_rate = clampf(_read_save_number(data.get("tax_rate"), 0.0), 0.0, 1.0)
	route_baseline.clear()
	if tax_reform_choice in [TaxReformChoice.TRADITIONAL, TaxReformChoice.REFORMED]:
		var saved_baseline = data.get("route_baseline", {})
		set_route_baseline(saved_baseline if saved_baseline is Dictionary else {})
	zhou_li_score = str(data.get("zhou_li_score", "中"))
	quest_progress = clampi(_read_save_int(data.get("quest_progress"), king_storage), 0, quest_target)
	quest_completed = data.get("quest_completed", quest_progress == quest_target) == true
	var saved_mat := str(data.get("hall_mat", HallDecor.DEFAULT_MAT))
	var saved_shelf := str(data.get("hall_shelf", HallDecor.DEFAULT_SHELF))
	hall_mat_id = saved_mat if _valid_hall_decor(saved_mat, HallDecor.Slot.MAT) else HallDecor.DEFAULT_MAT
	hall_shelf_id = saved_shelf if _valid_hall_decor(saved_shelf, HallDecor.Slot.SHELF) else HallDecor.DEFAULT_SHELF
	field_rotation = _restore_field_rotation(data.get("field_rotation"), saved_day)
	field_seed_plans.clear()
	var seed_plans: Variant = data.get("field_seed_plans")
	if seed_plans is Dictionary:
		for key in seed_plans:
			var cell = _read_save_cell(key)
			var plan: Variant = seed_plans[key]
			if cell is Vector2i and plan is String:
				set_field_seed_plan(cell, plan)
	ending_record = _saved_ending_record(data)
	if ending_record.is_empty() and outcome in [Outcome.TRADITIONAL, Outcome.REFORMED]:
		ending_record = _capture_ending(outcome)
	_update_max_well_fields()
	return OK

func _saved_ending_record(data: Dictionary) -> Dictionary:
	var record = data.get("ending_record")
	if record is Dictionary and _read_save_int(record.get("outcome"), Outcome.RUNNING) in [Outcome.TRADITIONAL, Outcome.REFORMED]:
		if record.get("date") is String and record.get("memories") is Array \
			and record.get("accounts") is Array and not record["accounts"].is_empty():
			return record
	return {}

func _restore_field_rotation(record: Variant, saved_day: int) -> FieldRotation:
	var restored := FieldRotation.new()
	if not record is Dictionary or not first_tribute_delivered():
		return restored
	var promised := _read_save_int(record.get("promise_day"), 0)
	if promised < 1 or promised > saved_day:
		return restored
	restored.promise_day = promised
	var bean_harvest := _read_save_int(record.get("beans_day"), 0)
	if bean_harvest >= promised and bean_harvest <= saved_day:
		restored.beans_day = bean_harvest
	var rotated := _read_save_int(record.get("harvest_day"), 0)
	var field_number := _read_save_int(record.get("field_number"), 0)
	var crop_id: Variant = record.get("crop_id", "")
	if (rotated >= maxi(promised, restored.beans_day) and rotated <= saved_day and field_number >= 1
		and field_number <= well_fields.size() and crop_id is String and crop_id in CropData.IDS and crop_id != "beans"):
		restored.harvest_day = rotated
		restored.field_number = field_number
		restored.crop_id = crop_id
		var signed := _read_save_int(record.get("signed_day"), 0)
		if signed >= rotated and signed <= saved_day:
			restored.signed_day = signed
	return restored

func _restore_field_night(record: Variant, saved_day: int) -> Dictionary:
	if not record is Dictionary or saved_day <= 1 or _read_save_int(record.get("day"), 0) != saved_day - 1:
		return {}
	var report := {"day": saved_day - 1}
	for key in FIELD_NIGHT_COUNTS:
		report[key] = maxi(0, _read_save_int(record.get(key), 0))
	return report

func _restore_dawn(record: Variant, saved_day: int) -> Dictionary:
	if not record is Dictionary or saved_day <= 1 or _read_save_int(record.get("day"), 0) != saved_day - 1:
		return {}
	var completed: Array[int] = []
	var numbers: Variant = record.get("completed_fields")
	if numbers is Array:
		for value in numbers:
			var number := _read_save_int(value, 0)
			if number > 1 and number <= well_fields.size() and well_fields[number - 1]["is_unlocked"]:
				completed.append(number)
	return {
		"day": saved_day - 1,
		"rank_change": clampi(_read_save_int(record.get("rank_change"), 0), -1, 1),
		"completed_fields": completed,
		"research_paid": maxi(0, _read_save_int(record.get("research_paid"), 0)),
		"research_gap": maxi(0, _read_save_int(record.get("research_gap"), 0)),
		"tribute_penalty": maxi(0, _read_save_int(record.get("tribute_penalty"), 0)),
	}

func _restore_away_field_report(record: Variant, saved_day: int) -> Dictionary:
	if not record is Dictionary or _read_save_int(record.get("day"), 0) != saved_day:
		return {}
	var report := {"day": saved_day, "pending": record.get("pending") == true,
		"first_tribute": record.get("first_tribute") == true}
	for key in AWAY_FIELD_TOTALS:
		report[key] = maxi(0, _read_save_int(record.get(key), 0))
	return report

func _restore_neighbor_departures(saved: Variant, saved_day: int) -> void:
	neighbor_departures.clear()
	if not saved is Dictionary:
		return
	for speaker: String in VisitorData.NEIGHBORS:
		var departure: Variant = saved.get(speaker)
		if not departure is Dictionary:
			continue
		var day := _read_save_int(departure.get("day"), 0)
		var reason := _read_save_int(departure.get("reason"), DepartureReason.UNRECORDED)
		var returned := _read_save_int(departure.get("returned_day"), 0)
		if day == 0 and reason == DepartureReason.UNRECORDED and returned > 0 and returned <= saved_day:
			neighbor_departures[speaker] = {"day": 0, "reason": reason, "returned_day": returned}
			continue
		if day <= 0 or day > saved_day or reason not in [DepartureReason.HUNGER, DepartureReason.REFORM]:
			continue
		neighbor_departures[speaker] = {
			"day": day, "reason": reason, "returned_day": returned if returned > day and returned <= saved_day else 0,
		}

func _restore_night_rations(record: Variant, saved_day: int, roster: Array[RetainerData]) -> NightRations:
	var restored := NightRations.new()
	if not record is Dictionary:
		return restored
	restored.enabled = record.get("enabled", false) == true
	restored.partial_meals = record.get("partial_meals", false) == true
	restored.copper_limit = clampi(_read_save_int(record.get("copper_limit"), 0), 0, NightRations.MAX_COPPER_LIMIT)
	var priority := _read_save_int(record.get("priority"), -1)
	if priority >= 0 and priority < roster.size():
		restored.priority = roster[priority]
	var meal: Variant = record.get("last")
	if not meal is Dictionary:
		return restored
	var day := _read_save_int(meal.get("day"), 0)
	if day <= 0 or day >= saved_day:
		return restored
	var need := maxi(0, _read_save_int(meal.get("need"), 0))
	var served := clampi(_read_save_int(meal.get("served"), 0), 0, need)
	var supper := clampi(_read_save_int(meal.get("supper"), 0), 0, served)
	var bought := clampi(_read_save_int(meal.get("bought"), 0), 0, served - supper)
	var copper := maxi(0, _read_save_int(meal.get("copper"), 0)) if bought > 0 else 0
	var used: Dictionary[String, int] = {}
	var left := served - supper - bought
	var lots: Variant = meal.get("used")
	if lots is Dictionary:
		for id: String in CropStock.IDS:
			var quantity := clampi(_read_save_int(lots.get(id), 0), 0, left)
			if quantity > 0:
				used[id] = quantity
				left -= quantity
	restored.last = {"day": day, "need": need, "served": served, "used": used, "bought": bought, "copper": copper}
	if supper > 0:
		restored.last["supper"] = supper
	for key in ["missed", "departed"]:
		var names: Variant = meal.get(key)
		if names is Array:
			restored.last[key] = PackedStringArray(names.filter(func(value: Variant) -> bool: return value is String))
	return restored

func _restore_fish_collection(record: Variant, saved_day: int) -> void:
	fish_collection.clear()
	if not record is Dictionary:
		return
	for id: String in CreekFish.IDS:
		var entry: Variant = record.get(id)
		if not entry is Dictionary:
			continue
		var first_day := _read_save_int(entry.get("first_day"), 0)
		var site := _read_save_int(entry.get("first_site"), -1)
		if first_day > 0 and first_day <= saved_day and site >= 0 and site < CreekFish.PLACES.size():
			fish_collection[id] = {"first_day": first_day, "first_site": site, "stock": maxi(0, _read_save_int(entry.get("stock"), 0))}

func _restore_fish_order_receipt(record: Variant, saved_day: int) -> Dictionary:
	if not record is Dictionary:
		return {}
	var day := _read_save_int(record.get("day"), 0)
	var amount := _read_save_int(record.get("amount"), 0)
	var fish: Variant = record.get("fish")
	if day > 0 and day <= saved_day and amount > 0 and CreekFish.SPECIES.has(fish):
		return {"day": day, "fish": fish, "for_food": record.get("for_food") == true, "amount": amount}
	return {}

func _restore_creek_trap(record: Variant, saved_day: int) -> Dictionary:
	if not record is Dictionary or not creek_traps_unlocked():
		return {}
	var site := _read_save_int(record.get("site"), -1)
	var set_day := _read_save_int(record.get("set_day"), 0)
	var bait: Variant = record.get("bait")
	if site >= 0 and site < CreekTrap.PLACES.size() and set_day > 0 and set_day <= saved_day and CreekTrap.BAITS.has(bait):
		return {"site": site, "bait": bait, "set_day": set_day}
	return {}

func _restore_defense(record: Variant, saved_day: int) -> Dictionary:
	if not record is Dictionary:
		return {}
	var day := clampi(_read_save_int(record.get("day"), 0), 0, saved_day)
	if day == 0:
		return {}
	var guard = record.get("guard", "")
	return {
		"day": day,
		"kind": clampi(_read_save_int(record.get("kind"), 0), 0, 1),
		"losses": maxi(0, _read_save_int(record.get("losses"), 0)),
		"guard": guard.left(32) if guard is String else "",
	}

func _restore_ravine_journal(record: Variant, saved_day: int) -> RavineJournal:
	var journal := RavineJournal.new()
	if not record is Dictionary:
		return journal
	var days: Variant = record.get("recorded_days", [])
	if days is Array:
		for index in mini(days.size(), journal.recorded_days.size()):
			var day := clampi(_read_save_int(days[index], 0), 0, saved_day)
			if day > 0 and not journal.recorded_days.has(day):
				journal.recorded_days[index] = day
	if journal.complete():
		var garden_day := clampi(_read_save_int(record.get("garden_day"), 0), 0, saved_day)
		if garden_day >= int(journal.recorded_days.max()):
			journal.garden_day = garden_day
			var harvest_day := clampi(_read_save_int(record.get("garden_harvest_day"), 0), 0, saved_day)
			if harvest_day >= garden_day:
				journal.garden_harvest_day = harvest_day
	return journal

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _read_save_cell(value: Variant) -> Variant:
	if value is String:
		var parts: PackedStringArray = value.trim_prefix("(").trim_suffix(")").split(",")
		if parts.size() == 2 and parts[0].strip_edges().is_valid_int() and parts[1].strip_edges().is_valid_int():
			return Vector2i(int(parts[0]), int(parts[1]))
	elif value is Dictionary:
		var x := _read_save_int(value.get("x"), -2147483649)
		var y := _read_save_int(value.get("y"), -2147483649)
		if x >= -2147483648 and x <= 2147483647 and y >= -2147483648 and y <= 2147483647:
			return Vector2i(x, y)
	return null

func _read_save_number(value: Variant, fallback: float) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return float(value)
	return fallback

func _restore_crop_stock(record: Variant, total: int) -> void:
	crop_stock = CropStock.new()
	var remaining := total
	if record is Dictionary:
		for id in CropData.IDS:
			var quantity := clampi(_read_save_int(record.get(id), 0), 0, remaining)
			crop_stock.add(id, quantity)
			remaining -= quantity
	crop_stock.add(CropStock.MIXED, remaining)

func _restore_season_order_receipts(record: Variant, saved_day: int) -> void:
	season_order_receipts.clear()
	if not record is Dictionary:
		return
	for order in SeasonOrders.ORDERS + SeasonOrders.FOLLOW_UP_ORDERS:
		var receipt: Variant = record.get(order.id)
		if receipt is Dictionary:
			var day := _read_save_int(receipt.get("day"), 0)
			if day > 0 and day <= saved_day:
				season_order_receipts[order.id] = {
					"day": day, "paid_in_food": receipt.get("paid_in_food") == true,
					"dispatch_day": clampi(_read_save_int(receipt.get("dispatch_day"), day), day, day + 1),
				}
				if order.id == SeasonOrders.WATCH_RELIEF:
					var previous_post := clampi(_read_save_int(receipt.get("previous_post_day"), 0), 0, day - 1)
					if previous_post > 0:
						season_order_receipts[order.id]["previous_post_day"] = previous_post

func _restore_sheepfold(record: Variant, saved_day: int) -> void:
	sheepfold = Sheepfold.new()
	if not record is Dictionary:
		return
	sheepfold.bought_day = clampi(_read_save_int(record.get("bought_day"), 0), 0, saved_day)
	if not sheepfold.owned():
		return
	sheepfold.fodder = maxi(0, _read_save_int(record.get("fodder"), 0))
	sheepfold.wool_nights = clampi(_read_save_int(record.get("wool_nights"), 0), 0, balance.sheep_wool_nights)
	sheepfold.wool = maxi(0, _read_save_int(record.get("wool"), 0))
	sheepfold.coat = record.get("coat", false) == true
	sheepfold.last_feed = clampi(_read_save_int(record.get("last_feed"), 0), 0, Sheepfold.Feed.SHORTAGE) as Sheepfold.Feed
	sheepfold.last_meadow_cut = clampi(_read_save_int(record.get("last_meadow_cut"), 0), 0, saved_day)

func _restore_summer_raft_results(record: Variant, saved_day: int) -> void:
	summer_raft_results.clear()
	if not record is Dictionary:
		return
	for key in record:
		var day := str(key).to_int()
		var entry: Variant = record[key]
		if day <= 0 or day > saved_day or not entry is Dictionary:
			continue
		var gates := _read_save_int(entry.get("gates"), -1)
		var time_ms := _read_save_int(entry.get("time_ms"), 0)
		if gates >= 0 and gates <= SummerRaft.GATES.size() and time_ms > 0:
			summer_raft_results[day] = {"gates": gates, "time_ms": time_ms}

func _restore_autumn_exhibits(record: Variant, saved_day: int) -> void:
	autumn_exhibits.clear()
	if not record is Dictionary:
		return
	for key in record:
		var date := str(key).to_int()
		var entry: Variant = record[key]
		if date <= 0 or date > saved_day or not entry is Dictionary:
			continue
		var crops: Variant = entry.get("crops")
		if crops is Array and not AutumnExhibit.portions(crops).is_empty():
			autumn_exhibits[date] = {"crops": crops, "shared": entry.get("shared") == true}

func _restore_winter_suppers(record: Variant, saved_day: int) -> void:
	winter_suppers.clear()
	if not record is Dictionary:
		return
	for key in record:
		var day := str(key).to_int()
		var entry: Variant = record[key]
		if day <= 0 or day > saved_day or not entry is Dictionary:
			continue
		var recipe: Variant = entry.get("recipe")
		var portions := _read_save_int(entry.get("portions"), 0)
		if recipe is String and WinterSupper.RECIPES.has(recipe) and portions > 0:
			winter_suppers[day] = {"recipe": recipe, "portions": portions}

func _read_save_int(value: Variant, fallback: int) -> int:
	var number := _read_save_number(value, float(fallback))
	if number < -9007199254740991.0 or number > 9007199254740991.0:
		return fallback
	return int(number)
