extends Node
class_name UIDialogManager

const DIALOGUE := preload("res://scenes/DialoguePanel.tscn")
const SPRING_GATHERING := preload("res://scripts/SpringGathering.gd")
const MUSIC_PRACTICE := preload("res://scripts/MusicPractice.gd")
const ROAD_REST := preload("res://scripts/RoadRest.gd")
const ROTATION_BOOK := preload("res://scripts/FieldRotationBook.gd")
const TRAVEL_HEARTH := preload("res://scripts/TravelHearth.gd")

var parent_node: Control
var player: Player

func setup(host: Control, estate_player: Player) -> void:
	parent_node = host
	player = estate_player

func show_freight_arrival(speech: String, portrait: Texture2D, guide_hearth: Callable) -> void:
	var dialog := _open("申禾", "车夫 · 南路亭", speech + "\n亭东生着火。带点食材去，走远路前可以装一份吃的。",
		["指路去灶台", "知道了"], [], portrait)
	dialog.option_selected.connect(func(index: int):
		if index == 0:
			guide_hearth.call()
	)

func show_winter_supper() -> void:
	var portrait := WinterSupper.guest_art(2, true)
	var record := Global.winter_supper_record()
	var need := Global.retainer_food_cost()
	if not record.is_empty():
		var dish: String = WinterSupper.RECIPES[record.recipe].name
		_open(WinterSupper.HOST, WinterSupper.PLACE,
			"这锅%s已经煮好。先给门客留 %d 份，余下的给路过亭子的人。坐近些，风就小了。" % [
				dish, mini(need, int(record.portions))], ["坐一会"], [], portrait)
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
	var dialog := _open(WinterSupper.HOST, context, speech, ["备麦菽粥", "备鱼麦羹", "坐一会"], disabled, portrait)
	dialog.option_selected.connect(func(index: int):
		if index < WinterSupper.MENU.size():
			Global.prepare_winter_supper(WinterSupper.MENU[index], fish)
	)

func show_travel_hearth(guide_market: Callable) -> void:
	var place := "南路灶台"
	var portrait := TRAVEL_HEARTH.PORTRAIT
	if not Global.travel_hearth_open():
		var dialog := _open(place, "南路亭东", "西市交过第一单后，这里就会有人照看灶火。",
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
				"我从南边回来看看这片地。记得先收井田中央那格，那一份要送进国库。")
		return
	var balance := Global.balance
	var options: Array[String] = [
		"已交谈" if data.talked_today() else "交谈",
		"交易（%d 铜钱）" % balance.trade_base_price,
		"招募（%d 声望）" % balance.recruit_reputation_requirement,
	]
	var disabled: Array[int] = []
	if data.talked_today():
		disabled.append(0)
	if Global.money < balance.trade_base_price:
		disabled.append(1)
	if Global.reputation < balance.recruit_reputation_requirement or Global.last_recruit_day == Global.current_day:
		disabled.append(2)
	var favor_index := options.size()
	var favor := _add_favor_option(data.name, options, disabled)
	options.append("离开")
	var speech := data.pavilion_greeting() if at_pavilion else data.greeting()
	var dialog = _open(data.name, data.get_school_name() + " · " + place,
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
			_recruit(data)

func _recruit(data: VisitorData) -> void:
	var cost := Global.balance.recruit_reputation_requirement
	if Global.reputation < cost or Global.last_recruit_day == Global.current_day:
		return
	var school := RetainerData.School.NONE
	match data.school:
		VisitorData.School.CONFUCIAN: school = RetainerData.School.CONFUCIAN
		VisitorData.School.MOHIST: school = RetainerData.School.MOHIST
		VisitorData.School.MILITARY: school = RetainerData.School.MILITARY
	var profession := "士人"
	if data.name in [VisitorData.SILK_MERCHANT, VisitorData.RAVINE_GUIDE]:
		profession = data.get_school_name()
	var retainer := RetainerData.new(data.name, profession, school)
	retainer.visitor_appearance = data.school
	Global.reputation -= cost
	Global.retainers.append(retainer)
	if not Global.visitor_encounters.has(data.name):
		Global.visitor_encounters[data.name] = 0
	Global.last_recruit_day = Global.current_day
	data.is_recruited = true
	GameEvents.retainer_recruited.emit(retainer)
	GameEvents.reputation_changed.emit(Global.reputation)

func show_retainer_dialog(data: RetainerData) -> void:
	if parent_node.has_node("DialoguePanel") or not Global.retainers.has(data):
		return
	if data.name == VisitorData.FIELD_KEEPER:
		_show_field_keeper("门客 · " + data.duty_name(), data.get_appearance_texture(), data.resident_line())
		return
	var options: Array[String] = []
	var disabled: Array[int] = []
	var favor := _add_favor_option(data.name, options, disabled)
	options.append("离开")
	var dialog = _open(data.name, "门客 · " + data.duty_name(), data.resident_line(),
		options, disabled, data.get_appearance_texture())
	if favor.is_valid():
		dialog.option_selected.connect(func(index: int):
			if index == 0 and Global.retainers.has(data):
				favor.call()
		)

func _show_field_keeper(context: String, appearance: Texture2D, usual_line: String) -> void:
	var story := Global.field_rotation
	var text := usual_line
	var options: Array[String] = ["离开"]
	var follow_up: Callable
	if story.signed_day > 0:
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
	var dialog := _open(VisitorData.FIELD_KEEPER, context, text, options, [], appearance)
	if follow_up.is_valid():
		var day := Global.current_day
		dialog.option_selected.connect(func(index: int):
			if index == 0 and Global.current_day == day:
				follow_up.call()
		)

func _field_keeper_season_line() -> String:
	if Global.field_rotation.signed_day == Global.current_day:
		return "我把咱们的两茬收成记在田南。若后来的人想知道地怎样养出来，就叫他翻开轮作簿。"
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

func show_rotation_book(highlight_soil: Callable) -> void:
	if parent_node.has_node("DialoguePanel") or Global.field_rotation.signed_day == 0:
		return
	var story := Global.field_rotation
	var note := "渠伯记 · 井田 %d" % story.field_number
	var count := Global.fertile_cells.size()
	var summary := "第 %d 天，先前种过菽的私田收下%s，多收一份。\n现在有 %d 格地留着豆茬的肥。" % [
		story.harvest_day, Global.rotation_crop_name(), count]
	var action := "标出肥地（%d 格）" % count if count > 0 else "标出肥地"
	var disabled: Array[int] = []
	if count == 0:
		disabled.append(0)
	var dialog := _open("轮作簿", note, summary, [action, "合上"], disabled, ROTATION_BOOK.ART)
	AudioManager.play_sfx(ROTATION_BOOK.TAP)
	dialog.option_selected.connect(func(index: int):
		if index == 0 and not Global.fertile_cells.is_empty():
			highlight_soil.call()
	)

func show_east_watch() -> void:
	if parent_node.has_node("DialoguePanel") or Global.last_defense.is_empty():
		return
	var note := Global.last_defense
	var guard: String = note["guard"]
	var defender := "你放了末一箭" if guard.is_empty() else "%s放了末一箭" % guard
	var date := "第 %d 天 · %s" % [note["day"], Global.get_current_solar_term(note["day"])]
	var record := "击退%s，%s。%s。\n封地至今击退 %d 次敌袭。" % [
		Global.raid_name(note["kind"]), defender, Global.defense_loss_note(), Global.raids_defeated]
	_open("东岗守备牌", date, record, ["合上"], [], preload("res://assets/world/east-watch.svg"))

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
		_open(guest.speaker, "秋社 · 南路亭东", guest.remark(), ["离开"], [], guest.icon)

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
