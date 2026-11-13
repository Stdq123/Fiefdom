extends Node
class_name UIDialogManager

const DIALOGUE := preload("res://scenes/DialoguePanel.tscn")
const SPRING_GATHERING := preload("res://scripts/SpringGathering.gd")
const MUSIC_PRACTICE := preload("res://scripts/MusicPractice.gd")
const ROAD_REST := preload("res://scripts/RoadRest.gd")
const ROTATION_BOOK := preload("res://scripts/FieldRotationBook.gd")
const TRAVEL_HEARTH := preload("res://scripts/TravelHearth.gd")
const WATER_SOURCE := preload("res://scripts/WaterSource.gd")
const SEED_GARDEN := preload("res://scripts/SeedGarden.gd")
const HUNGER_RETURN_LINES := {
	VisitorData.FIELD_KEEPER: "那夜没分到饭，我只好去南边借住。今早路过，还是想看看咱们那块田。",
	VisitorData.ROAD_KEEPER: "那晚我拎着空碗出了门，是过路人分了我一把炒菽。我记得这份情，也惦记亭西的人。",
	VisitorData.WATER_GUIDE: "那夜吃不上饭，我就去上游的磨坊借宿了。今天刚过路口，先想来看看水源。",
	VisitorData.SILK_MERCHANT: "我去西市帮蔡娘理货，换了几顿饭。回来走这一路，还是一眼就认出了西廊的石阶。",
	VisitorData.RAVINE_GUIDE: "那天我空着肚子走到木桥，幸好还有人在涧边生火。今天回来了，想先沿竹径走一走。",
	VisitorData.EAST_WATCHER: "那夜我把弓靠在门边，空手去了东头讨一碗饭。今天走旧路，还是先往田埂上看了一眼。",
}

const COUNCIL_REACTIONS := {
	VisitorData.ROAD_KEEPER: [
		"我去堂前看了一眼，贡簿还摊在原处。等公仓这茬入账，我替你把记数的木筹收好。",
		"我在亭下听见有人问新税怎么算。收谷归谁、扣了几文，最好让拿镰的人也能看见。",
	],
	VisitorData.SILK_MERCHANT: [
		"若有绸要送往王庭，我能找块干布来裹。西市的好价，等交完谷帛再慢慢谈。",
		"蔡娘问起新册。我说田里的铜钱照新法算，摊上的绸仍要看布边和经线。",
	],
}

var parent_node: Control
var player: Player

func setup(host: Control, estate_player: Player) -> void:
	parent_node = host
	player = estate_player

func show_freight_arrival(speech: String, portrait: Texture2D, guide_hearth: Callable,
		destination: String, guide_destination: Callable) -> void:
	var choices: Array[String] = ["指路去灶台", "知道了"]
	var actions: Array[Callable] = [guide_hearth]
	if not destination.is_empty():
		choices.push_front("指路去" + destination)
		actions.push_front(guide_destination)
	var dialog := _open("申禾", "车夫 · 南路卸货场", speech + "\n沿南路往东有灶台。带点食材去，走远路前可以装一份吃的。",
		choices, [], portrait)
	dialog.option_selected.connect(func(index: int):
		if index < actions.size():
			actions[index].call()
	)

func show_seed_garden(host_present: bool) -> void:
	var garden_day := Global.seed_garden_day()
	var remaining := garden_day + SeasonOrders.SEED_GROW_NIGHTS - Global.current_day
	var context := "南路亭 · 第 %d 天下种" % garden_day
	var gift := Global.seed_garden_gift
	var speaker := "林蓼" if host_present else SEED_GARDEN.PLACE
	var portrait := SEED_GARDEN.portrait() if host_present else null
	if remaining > 0:
		var text := ("你留的菽和黍，我各挑了一把种在这儿。以后谁来领种，先来认一认苗。" if host_present
			else "林蓼在木签上记着，菽和黍是西市送来的种。两畦再过 %d 夜就能收。" % remaining)
		_open(speaker, context, text, ["离开"], [], portrait)
	elif not gift.is_empty():
		_open(speaker, context, "林蓼留了木签。给你的%s已经取走，其余留给新领田的人。" % ItemManager.crop_label(gift),
			["离开"], [], portrait)
	else:
		var dialog := _open(speaker, context, "林蓼把头茬菽和黍各分了一袋，余下留给来领种的人。她在木签上写着，送种的人可以选一份带走。",
			["取一份菽", "取一份黍", "留在圃里"], [], portrait)
		dialog.option_selected.connect(func(index: int):
			if index < SeasonOrders.SEED_CROPS.size() and Global.take_seed_garden_gift(SeasonOrders.SEED_CROPS[index]):
				GameEvents.world_notice.emit("亭西种圃 · %s入私仓" % ItemManager.crop_label(Global.seed_garden_gift)))

func show_winter_supper() -> void:
	var record := Global.winter_supper_record()
	var need := Global.retainer_food_cost()
	if not record.is_empty():
		var dish: String = WinterSupper.RECIPES[record.recipe].name
		_open(WinterSupper.HOST, WinterSupper.PLACE,
			"这锅%s已经煮好。先给门客留 %d 份，余下的留给来围炉的人。坐近些，风就小了。" % [
				dish, mini(need, int(record.portions))], ["坐一会"], [], null)
		return
	var fish := Global.fish_for_travel_meal()
	var fish_name: String = "溪鱼" if fish.is_empty() else CreekFish.SPECIES[fish].name
	var last_year := Global.current_day - Global.SOLAR_TERMS.size() * maxi(1, Global.balance.days_per_solar_term)
	var previous := Global.winter_supper_record(last_year) if last_year > 0 else {}
	var welcome := ("天色晚了，今夜你家需 %d 份。" if Global.day_progress >= WinterSupper.EVENING else "灯亮就开席，今夜你家需 %d 份。") % need
	if not previous.is_empty():
		welcome = "还记得去年的%s。今夜需 %d 份。" % [WinterSupper.RECIPES[previous.recipe].name, need]
	var speech := "%s\n麦菽粥 · 麦 1、菽 1 · 供 %d 份\n鱼麦羹 · 麦 1、%s 1 · 供 %d 份" % [
		welcome, WinterSupper.portions(WinterSupper.BEAN, Global.balance), fish_name, WinterSupper.portions(WinterSupper.FISH, Global.balance)]
	var stock := Global.crop_stock
	var context := "%s · 私仓麦 %d、菽 %d" % [WinterSupper.PLACE, stock.count("wheat"), stock.count("beans")]
	var order := Global.season_order()
	if Global.season_order_delivered_at(order) == 0 and stock.count("wheat") <= int(order.order.need.get("wheat", 0)):
		context += " · 冬单也需麦"
	var disabled: Array[int] = []
	for index in WinterSupper.MENU.size():
		if not Global.can_prepare_winter_supper(WinterSupper.MENU[index], fish):
			disabled.append(index)
	var dialog := _open(WinterSupper.HOST, context, speech, ["备麦菽粥", "备鱼麦羹", "坐一会"], disabled, null)
	dialog.option_selected.connect(func(index: int):
		if index < WinterSupper.MENU.size():
			Global.prepare_winter_supper(WinterSupper.MENU[index], fish)
	)

func show_travel_hearth(guide_market: Callable) -> void:
	var place := "南路灶台"
	var portrait := TRAVEL_HEARTH.PORTRAIT
	if not Global.travel_hearth_open():
		var dialog := _open(place, "南路东段", "西市交过第一单后，这里就会有人照看灶火。",
			["指路去西市", "离开"], [], portrait)
		dialog.option_selected.connect(func(index: int):
			if index == 0:
				guide_market.call()
		)
		return
	var packed := Global.travel_meal
	if not packed.is_empty():
		_open(place, "每次可带一份", "包里有%s。饿了可%s食用，吃完再来装。" % [TravelMeal.RECIPES[packed].name, GamepadInput.meal_hint()],
			["离开"], [], TravelMeal.icon(packed))
		return
	var meals: Array[String] = [TravelMeal.BEAN_MILLET, TravelMeal.RICE_FISH]
	var fish := Global.fish_for_travel_meal()
	var fish_name: String = "溪鱼" if fish.is_empty() else CreekFish.SPECIES[fish].name
	var disabled: Array[int] = []
	for index in meals.size():
		if not Global.can_pack_travel_meal(meals[index], fish):
			disabled.append(index)
	var stock := Global.crop_stock
	var rice := "稻 %d/1、%s %d/1" % [stock.count("rice"), fish_name, Global.fish_count(fish)]
	var grain := "菽 %d/1、黍 %d/1" % [stock.count("beans"), stock.count("millet")]
	var speech := "菽黍饭　%s　·　%s\n稻鱼羹　%s　·　%s" % [
		grain, TravelMeal.describe_recovery(TravelMeal.benefits(meals[0], Global.balance)),
		rice, TravelMeal.describe_recovery(TravelMeal.benefits(meals[1], Global.balance))]
	var dialog := _open(place, "可带一份 · %s食用" % GamepadInput.meal_hint(), speech, ["装菽黍饭", "装稻鱼羹", "离开"], disabled, portrait)
	dialog.option_selected.connect(func(index: int):
		if index < meals.size():
			Global.pack_travel_meal(meals[index], fish)
	)

func show_visitor_dialog(data: VisitorData, place: String, at_pavilion := false) -> void:
	if data.is_recruited or parent_node.has_node("DialoguePanel"):
		return
	if data.name == VisitorData.FIELD_KEEPER:
		if Global.field_keeper_visiting():
			_show_field_keeper("回访 · " + data.meeting_place, data.get_appearance_texture(),
				"我从南边回来看看这片地。记得先收井田中央那格，那一份要送进国库。", "", data)
		return
	var balance := Global.balance
	var returning := not Global.pending_neighbor_return(data.name).is_empty()
	var block := Global.recruitment_block(data)
	var options: Array[String] = [
		"已交谈" if data.talked_today() else "交谈",
		"交易（%d 铜钱）" % balance.trade_base_price,
		_recruit_option(data, block, returning),
	]
	var disabled: Array[int] = []
	if data.talked_today():
		disabled.append(0)
	if Global.money < balance.trade_base_price:
		disabled.append(1)
	if block != Global.RecruitmentBlock.NONE:
		disabled.append(2)
	var favor_index := options.size()
	var favor := _add_favor_option(data.name, options, disabled)
	options.append("离开")
	var speech := data.pavilion_greeting() if at_pavilion else data.greeting()
	if place == VisitorData.SILK_MARKET_PLACE:
		speech = VisitorData.silk_market_line()
	elif place == VisitorData.SILK_BRIDGE_PLACE:
		speech = data.silk_bridge_line()
	if returning:
		speech = _return_speech(data.name, speech if favor.is_valid() else "")
	elif not favor.is_valid() and place not in [VisitorData.SILK_MARKET_PLACE, VisitorData.SILK_BRIDGE_PLACE]:
		speech = _council_reaction(data.name, speech)
	var context := _recruitment_context(data.get_school_name() + " · " + place, block)
	var dialog = _open(data.name, context,
		speech, options, disabled, data.get_appearance_texture())
	dialog.option_selected.connect(_on_visitor_choice.bind(data, favor_index, favor))

func _on_visitor_choice(index: int, data: VisitorData, favor_index: int, favor: Callable) -> void:
	if data.is_recruited:
		return
	if index == favor_index and favor.is_valid():
		favor.call()
		return
	match index:
		0:
			Global.talk_to_visitor(data.name)
		1:
			var price := Global.balance.trade_base_price
			if Global.money >= price:
				Global.money -= price
				Global.player_inventory += 1
				GameEvents.money_changed.emit(Global.money)
				GameEvents.inventory_changed.emit(Global.player_inventory)
		2:
			Global.recruit_visitor(data)

func _recruit_option(guest: VisitorData, block: Global.RecruitmentBlock, returning: bool) -> String:
	var action := "请回来" if returning else "招募"
	var detail := "%d 声望" % Global.balance.recruit_reputation_requirement if block == Global.RecruitmentBlock.NONE \
		else Global.recruitment_block_note(guest, block)
	return "%s（%s）" % [action, detail]

func _recruitment_context(context: String, block: Global.RecruitmentBlock) -> String:
	if block == Global.RecruitmentBlock.NONE and Global.current_rank == Global.Rank.XIA_SHI and Global.eligible_for_promotion():
		var remaining := Global.reputation - Global.balance.recruit_reputation_requirement
		if remaining < Global.promotion_reputation():
			return context + "\n留任后声望 %d/%d。补足后过夜可晋升中士。" % [remaining, Global.promotion_reputation()]
	return context

func _return_speech(speaker: String, following: String) -> String:
	var departure := Global.pending_neighbor_return(speaker)
	var speech := "我从南边回来看看这片地。若还缺个管田的人，咱们坐下说说。"
	match departure.get("reason"):
		Global.DepartureReason.HUNGER:
			speech = HUNGER_RETURN_LINES[speaker]
		Global.DepartureReason.REFORM:
			speech = "议税那天我收了行李。今天路过，想看看新法落在田里，种田的人过得怎样。"
	var portions := Global.recruitment_food_requirement(speaker)
	if portions > 0:
		speech += "\n若再留下，先在粮仓备齐大伙一夜的口粮。现有 %d / %d 份。" % [Global.food_storage, portions]
	if not following.is_empty():
		speech += "\n" + following
	return speech

func show_retainer_dialog(data: RetainerData, at_pavilion := false) -> void:
	if parent_node.has_node("DialoguePanel") or not Global.retainers.has(data):
		return
	var context := "门客 · 南路亭" if at_pavilion else "门客 · " + data.duty_name()
	var evening := data.evening_line() if at_pavilion else ""
	if data.name == VisitorData.FIELD_KEEPER:
		_show_field_keeper(context, data.get_appearance_texture(), data.resident_line(), evening)
		return
	var options: Array[String] = []
	var disabled: Array[int] = []
	var favor := _add_favor_option(data.name, options, disabled)
	options.append("离开")
	var speech := data.resident_line()
	if at_pavilion:
		speech = evening + "\n" + speech if favor.is_valid() else evening
	if not favor.is_valid():
		speech = _council_reaction(data.name, speech)
	var dialog = _open(data.name, context, speech,
		options, disabled, data.get_appearance_texture())
	if favor.is_valid():
		dialog.option_selected.connect(func(index: int):
			if index == 0 and Global.retainers.has(data):
				favor.call()
		)

func _show_field_keeper(context: String, appearance: Texture2D, usual_line: String, evening := "", guest: VisitorData = null) -> void:
	var story := Global.field_rotation
	var text := usual_line if evening.is_empty() else evening
	var options: Array[String] = ["离开"]
	var follow_up: Callable
	if story.signed_day > 0:
		if evening.is_empty() or story.signed_day == Global.current_day:
			text = _field_keeper_season_line()
	elif story.ready_to_sign():
		text = "那年教我种菽的人没留下名字，只在田埂上插了根木签。\n今儿收的%s，咱们也记下来。日后换人管田，还有个凭据。" % Global.rotation_crop_name()
		options.push_front("一起记进轮作簿")
		follow_up = Global.sign_rotation_book
	elif story.waiting_for_harvest():
		text = "一格私田，先收菽。等豆茬留住肥，再在原地种下一茬。\n你想种哪样都成。收时若多出一份，就回来告诉我。"
		if story.beans_day > 0:
			text = "豆茬的肥还在地里。找有金角标的私田，种点别的。\n若赶上谷雨，旱苗还能省一回浇水。等收了咱们再记。"
	elif Global.rotation_offer_ready():
		text = "荒年我只敢种黍。邻人分我一把菽种，说这地也该喘口气。\n你肯留一格私田，先收菽，再在原地收一茬吗？"
		options.push_front("约定试一回轮作")
		follow_up = Global.agree_to_rotation
	if not evening.is_empty() and text != evening:
		text = evening + "\n" + text
	var return_index := -1
	var disabled: Array[int] = []
	if guest:
		return_index = options.size() - 1
		var block := Global.recruitment_block(guest)
		options.insert(return_index, _recruit_option(guest, block, true))
		if block != Global.RecruitmentBlock.NONE:
			disabled.append(return_index)
		context = _recruitment_context(context, block)
		text = _return_speech(guest.name, text if text != usual_line else "")
	var dialog := _open(VisitorData.FIELD_KEEPER, context, text, options, disabled, appearance)
	if follow_up.is_valid() or guest:
		var day := Global.current_day
		dialog.option_selected.connect(func(index: int):
			if Global.current_day != day:
				return
			if index == 0 and follow_up.is_valid():
				follow_up.call()
			elif index == return_index:
				Global.recruit_visitor(guest)
		)

func _council_reaction(speaker: String, usual_line: String) -> String:
	var days := Global.current_day - Global.tax_reform_day
	if not COUNCIL_REACTIONS.has(speaker) or days >= SeasonOrders.TERMS_PER_SEASON * maxi(1, Global.balance.days_per_solar_term):
		return usual_line
	match Global.tax_reform_choice:
		Global.TaxReformChoice.TRADITIONAL:
			return COUNCIL_REACTIONS[speaker][0]
		Global.TaxReformChoice.REFORMED:
			return COUNCIL_REACTIONS[speaker][1]
	return usual_line

func _field_keeper_season_line() -> String:
	if Global.field_rotation.signed_day == Global.current_day:
		return "我把咱们的两茬收成记在田南。往后哪一畦想这么种，翻开簿子指给我看，我照着接茬。"
	if Global.has_rain():
		return "今早雨落下来，我就把轮作簿往架里推了推。等雨小了，咱们再看豆茬里长了什么。"
	match Global.season_index():
		Global.Season.SUMMER:
			return "日头烈，豆茬的土翻开还带潮气。挑种的时候看看簿上哪格留着肥。"
		Global.Season.AUTUMN:
			return "稷穗垂下来了。割完记得给田留一茬菽，明年路过田南的人，还能照簿接着种。"
		Global.Season.WINTER:
			return "霜沾在木架上，我今早用袖子抹了抹。冬麦还会长，留肥的格子都能从簿里查到。"
	return "春土一松，我又想起那把菽种。去田南翻翻吧，地里哪一格有肥，簿上现在看得见。"

func show_rotation_book(highlight_soil: Callable, open_plans: Callable) -> void:
	if parent_node.has_node("DialoguePanel") or Global.field_rotation.signed_day == 0:
		return
	var story := Global.field_rotation
	var note := "渠伯记 · 井田 %d" % story.field_number
	var count := Global.fertile_cells.size()
	var summary := "第 %d 天，先前种过菽的私田收下%s，多收一份。\n现在有 %d 格地留着豆茬的肥。可让照料门客交替播种菽和所选作物。" % [
		story.harvest_day, Global.rotation_crop_name(), count]
	var action := "标出肥地（%d 格）" % count if count > 0 else "标出肥地"
	var disabled: Array[int] = []
	if count == 0:
		disabled.append(0)
	var dialog := _open("轮作簿", note, summary, [action, "安排轮作", "合上"], disabled, ROTATION_BOOK.ART)
	AudioManager.play_sfx(ROTATION_BOOK.TAP)
	dialog.option_selected.connect(func(index: int):
		if index == 0 and not Global.fertile_cells.is_empty():
			highlight_soil.call()
		elif index == 1:
			open_plans.call()
	)

func show_water_source(starter_tiles: int, open_study: Callable, open_technology: Callable, begin_digging: Callable) -> void:
	var context := "田边 · 水利"
	var text := "通水渠能给相邻田格供水。稻要靠渠水才能播种。"
	var choice := "去研读"
	var action := open_study
	if Global.tech_unlocked["irrigation"]:
		var watered := 0
		for field: Dictionary in Global.well_fields:
			if field["is_unlocked"]:
				watered += Global.irrigation.watered_footprint(field["center_pos"]).size()
		context = "已有 %d 块井田接水" % Global.irrigated_well_fields()
		text = "渠水供到 %d 格田。接水的作物过夜能长，断水的稻会停长。" % watered
		if Global.channel_survey_day > 0:
			text += "\n在挖渠时可从通水的一侧装田口闸，把水引过三格田。"
		choice = "进入挖渠"
		action = begin_digging
		if starter_tiles > 0:
			var cost := starter_tiles * Global.channel_cost()
			text += "\n沿泉口开 %d 格到田边，共需 %d 铜钱。" % [starter_tiles, cost]
			if Global.money < cost:
				text += "还差 %d 铜钱。" % (cost - Global.money)
			choice = "标出引水位置"
	else:
		var level := Global.player_stats.get_level(PlayerStats.Art.LITERACY)
		var needed := Irrigation.UNLOCK_LITERACY_LEVEL
		if level >= needed:
			text += "\n书艺已达 %d 级。现在可解锁水利。" % level
			choice = "打开科技"
			action = open_technology
		else:
			text += "\n书艺 %d/%d 级。每天可研读一次。" % [level, needed]
	var dialog := _open("水源", context, text, [choice, "离开"], [], WATER_SOURCE.ART)
	dialog.option_selected.connect(func(index: int):
		if index == 0:
			action.call()
	)

func show_east_watch() -> void:
	if parent_node.has_node("DialoguePanel"):
		return
	var title := "东岗巡粮簿"
	var context := "南路来货"
	var lines := PackedStringArray()
	if Global.east_watch_day > 0:
		var note := Global.last_defense
		var guard: String = note["guard"]
		var defender := "你放了末一箭" if guard.is_empty() else "%s放了末一箭" % guard
		title = "东岗守备牌"
		context = "第 %d 天 · %s" % [note["day"], Global.get_current_solar_term(note["day"])]
		lines.append("击退%s，%s。%s。\n封地至今击退 %d 次敌袭。" % [
			Global.raid_name(note["kind"]), defender, Global.defense_loss_note(), Global.raids_defeated])
	var relief := Global.watch_relief_day()
	if relief > 0:
		lines.append("第 %d 天，南路送到两份稷、一份菽和一束麻。巡粮已分袋，新麻绳系上了岗旗。" % relief)
	if not lines.is_empty():
		_open(title, context, "\n\n".join(lines), ["合上"], [], preload("res://assets/world/east-watch.svg"))

func show_gathering_guest(data: VisitorData) -> void:
	if parent_node.has_node("DialoguePanel") or not Global.is_gathering_day():
		return
	var speaker := data.name
	var options: Array[String] = ["离开"]
	var speech: String
	match speaker:
		SPRING_GATHERING.HOST:
			if Global.gathering_score() > 0:
				speech = "今年的迎客曲已经写进曲簿。等明年谷雨，咱们还在亭东见。"
			else:
				speech = "今年的头一场春雨到了。来敲四拍迎客曲吧。等光条进了绿段再敲，响够三拍，我就把这支曲子记到簿上。"
				options.push_front("合奏迎客曲")
		VisitorData.ROAD_KEEPER:
			speech = ("亭下的路粮匣开着呢。远道来听钟的人，歇脚时也能吃上一口。" if Global.road_provisions_delivered
				else "沿南路走来，听见有人试钟，就循着声音找过来了。今天过路的人都愿意多坐一会。")
		VisitorData.SILK_MERCHANT:
			speech = ("西廊那角绸样有人认出来了。我说，是这片封地养的蚕，织绸的人今天也来听钟。" if Global.silk_sample_day > 0
				else "我本来只打算借亭躲一场雨。听说有人要奏迎客曲，干脆坐下来，把路让给后来的人。")
		"林蓼":
			speech = "我把蓑衣搁在亭下了。春雨落在竹叶上，远一点听，和敲钟像是一问一答。"
		_:
			speech = "我沿竹径过来的。打这儿经过的人说，亭边那本曲簿可以翻到往年的迎客曲。"
	var context := "乐师 · 谷雨亭集" if speaker == SPRING_GATHERING.HOST else "亭东来客 · 谷雨亭集"
	var dialog := _open(speaker, context, speech, options, [], data.get_appearance_texture())
	if options.size() > 1:
		dialog.option_selected.connect(_on_gathering_choice.bind(Global.current_day))

func _on_gathering_choice(index: int, day: int) -> void:
	if (index != 0 or day != Global.current_day or not Global.is_gathering_day()
		or Global.outcome != Global.Outcome.RUNNING or Global.gathering_score() > 0 or parent_node.has_node("MusicPractice")):
		return
	var practice := MUSIC_PRACTICE.new()
	practice.name = "MusicPractice"
	practice.recital_day = day
	parent_node.add_child(practice)

func show_autumn_guest(guest: Node2D) -> void:
	if not parent_node.has_node("DialoguePanel"):
		_open(guest.speaker, "秋社 · " + EstateLayout.FESTIVAL_SITE_NAME, guest.remark(), ["离开"], [], guest.icon)

func show_gathering_book() -> void:
	if parent_node.has_node("DialoguePanel"):
		return
	var dates := Global.gathering_recitals.keys()
	dates.sort()
	var lines := PackedStringArray()
	for day: int in dates.slice(-4):
		var year := ceili(float(day) / maxi(1, Global.balance.days_per_year))
		lines.append("第 %d 年 · 谷雨 · 迎客曲 %d/%d" % [year, Global.gathering_recitals[day], Global.GATHERING_BEATS])
	var text := "簿上还空着。去亭东找商音合奏迎客曲吧。" if lines.is_empty() else "\n".join(lines)
	_open("谷雨曲簿", "南路亭 · 迎客曲", text, ["合上"], [], SPRING_GATHERING.BOOK)

func show_road_rest() -> void:
	if parent_node.has_node("DialoguePanel") or not Global.road_rest_built():
		return
	var recovered := Global.road_rest_recovery()
	var choice := "歇一歇（体力 +%d）" % recovered if recovered > 0 else "歇一歇"
	var text := "凳边那瓮水还是凉的。放下农具坐一会，再回田里忙也来得及。"
	if Global.road_rest_used_day == Global.current_day:
		text = "今天已经在长凳上歇过了。季青把水瓮重新盖好，留给下一个赶路的人。"
	elif recovered == 0:
		text = "现在体力充足。忙完一阵再来坐坐，亭檐下有一瓮水。"
	var disabled: Array[int] = []
	if recovered <= 0:
		disabled.append(0)
	var dialog := _open("亭西歇脚处", "南路亭 · 季青与你合修", text, [choice, "离开"], disabled, ROAD_REST.portrait())
	var day := Global.current_day
	dialog.option_selected.connect(func(index: int):
		if index == 0 and day == Global.current_day:
			Global.use_road_rest()
	)

func _add_favor_option(speaker: String, options: Array[String], disabled: Array[int]) -> Callable:
	var index := options.size()
	if speaker == VisitorData.ROAD_KEEPER and Global.road_provisions_requested():
		options.append("送路粮（1 作物）")
		if Global.player_inventory == 0:
			disabled.append(index)
		return Global.deliver_road_provisions
	if speaker == VisitorData.ROAD_KEEPER and Global.road_rest_requested():
		options.append("修歇脚处（%d 铜钱）" % Global.balance.road_rest_cost)
		if Global.money < Global.balance.road_rest_cost:
			disabled.append(index)
		return Global.fund_road_rest
	if speaker == VisitorData.SILK_MERCHANT and Global.silk_sample_requested():
		options.append("交样绸（%d 铜钱）" % Global.silk_sample_price())
		if not Global.can_use_workshop(SilkWorkshop.Action.SELL):
			disabled.append(index)
		return Global.deliver_silk_sample
	if speaker == VisitorData.RAVINE_GUIDE and Global.ravine_handoff_ready():
		options.append("交溪行手记")
		return Global.deliver_ravine_journal
	if speaker == VisitorData.EAST_WATCHER and Global.defense_review_ready():
		options.append("复盘守备")
		return Global.review_defense
	if speaker == VisitorData.WATER_GUIDE and Global.water_review_ready():
		options.append("随石墨勘渠")
		return Global.learn_channel_survey
	return Callable()

func _open(speaker: String, context: String, speech: String, options: Array[String], disabled: Array[int], portrait: Texture2D) -> Control:
	Global.meet_neighbor(speaker)
	var dialog := DIALOGUE.instantiate()
	parent_node.add_child(dialog)
	dialog.setup(speaker, context, speech, options, disabled,
		CharacterArt.dialogue_portrait(speaker, portrait, VisitorData.favor_completed(speaker)))
	player.conversation_open = true
	dialog.tree_exited.connect(func():
		if is_instance_valid(player):
			player.conversation_open = false
	)
	return dialog
