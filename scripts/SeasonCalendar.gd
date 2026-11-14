extends "res://scripts/SurveyMap.gd"

signal directions_requested(place: String)

const TERMS := SeasonOrders.TERMS_PER_SEASON
const EVENT_TERMS := [Global.GATHERING_TERM, SummerRaft.TERM, AutumnExhibit.TERM, WinterSupper.TERM]

@onready var seasons: HBoxContainer = %Seasons
@onready var dates: VBoxContainer = %Dates
@onready var year_label: Label = %Year
@onready var title: Label = %DateTitle
@onready var forecast: Label = %Forecast
@onready var planting: Label = %Planting
@onready var order_note: Label = %Order
@onready var event_note: Label = %Event
@onready var guide: Button = %Guide
@onready var fish_guide: Button = %FishGuide

var controls_blocked: Callable
var year_start := 1
var term_days := 1
var season := 0
var focus := 0
var residents: Array[String] = []
var event_to_open := 0

func _ready() -> void:
	super._ready()
	for button: Button in seasons.get_children():
		button.pressed.connect(_show_season.bind(button.get_index()))
	var normal := dates.get_theme_stylebox("normal", "Button")
	var selected := dates.get_theme_stylebox("pressed", "Button").duplicate() as StyleBox
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		selected.set_content_margin(side, normal.get_margin(side))
	for index in TERMS:
		var row := Button.new()
		row.custom_minimum_size.y = 49.0
		row.toggle_mode = true
		row.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_stylebox_override("pressed", selected)
		row.pressed.connect(_show_date.bind(index))
		dates.add_child(row)
	guide.pressed.connect(_request_directions)
	fish_guide.pressed.connect(_follow_place.bind(CreekFish.PLACES[CreekFish.Site.POOL]))

func _map_available() -> bool:
	return not controls_blocked.call()

func open_noticed_event() -> void:
	event_to_open = _noticed_day()
	if event_to_open > 0:
		open_map()
	event_to_open = 0

func _open_from_shortcut() -> void:
	if _noticed_day() > 0:
		open_noticed_event()
	else:
		open_map()

func event_notice() -> String:
	var day := _noticed_day()
	if day == 0:
		return ""
	var remaining := day - Global.current_day
	var when := "今日" if remaining <= 0 else ("明日" if remaining == 1 else "%d 天后 " % remaining)
	var status := ""
	if Global.is_gathering_day(day):
		status = "南路亭东" if Global.gathering_recitals.get(day, 0) == 0 else "已入簿"
	elif Global.is_summer_raft_day(day):
		status = "竹涧西岸" if not Global.summer_raft_results.has(day) else "已入簿"
	elif Global.is_autumn_exhibit_day(day):
		status = ("谷样 %d/%d" % [mini(_autumn_stock().size(), AutumnExhibit.SAMPLE_COUNT), AutumnExhibit.SAMPLE_COUNT]
			if Global.autumn_exhibit_record(day).is_empty() else "已入簿")
	elif Global.is_winter_supper_day(day):
		status = _winter_notice(day) if Global.winter_supper_record(day).is_empty() else "已备饭"
	return "%s%s · %s  ›" % [when, _event_name(day), status]

func _noticed_day() -> int:
	var term_length := maxi(1, Global.balance.days_per_solar_term)
	var today := Global.current_day
	var first := _year_start(today, term_length)
	for term: String in EVENT_TERMS:
		var day := first + Global.SOLAR_TERMS.find(term) * term_length
		if today >= day + _event_length(day, term_length):
			continue
		if today >= day - _notice_lead(term):
			return day
	return 0

func _notice_lead(term: String) -> int:
	if term == WinterSupper.TERM:
		return maxi(ItemManager.get_crop("wheat").days_to_grow, ItemManager.get_crop("beans").days_to_grow)
	var lead := 1
	if term == AutumnExhibit.TERM:
		for id: String in AutumnExhibit.CROPS:
			var crop := ItemManager.get_crop(id)
			if not crop.is_water_crop:
				lead = maxi(lead, crop.days_to_grow)
	return lead

func _year_start(day: int, term_length: int) -> int:
	return day - posmod(day - 1, term_length * Global.SOLAR_TERMS.size())

func _event_length(day: int, term_length: int) -> int:
	return term_length if Global.is_gathering_day(day) or Global.is_autumn_exhibit_day(day) else 1

func _refresh_on_open() -> void:
	term_days = maxi(1, Global.balance.days_per_solar_term)
	var day := event_to_open if event_to_open > 0 else Global.current_day
	year_start = _year_start(day, term_days)
	year_label.text = "第 %d 年    ·    今天第 %d 天" % [Global.get_current_year(), Global.current_day]
	residents.clear()
	for member: RetainerData in Global.retainers:
		residents.append(member.name)
	_show_season(Global.season_index(day), Global.solar_term_index(day) % TERMS)

func _show_season(next: int, first_date := -1) -> void:
	season = next
	for button: Button in seasons.get_children():
		button.set_pressed_no_signal(button.get_index() == season)
	for index in TERMS:
		var day := _day(index)
		var row := dates.get_child(index) as Button
		var special := _event_name(day)
		var today := "  ·  今日" if Global.current_day >= day and Global.current_day < day + term_days else ""
		row.text = "%s     %s%s%s" % [_day_label(day), Global.get_current_solar_term(day),
			"  ·  " + special if not special.is_empty() else "", today]
	if first_date < 0:
		first_date = Global.solar_term_index() % TERMS if season == Global.season_index() else 0
	_show_date(first_date)

func _day(index: int) -> int:
	return year_start + (season * TERMS + index) * term_days

func _day_label(day: int) -> String:
	return "第 %d 天" % day if term_days == 1 else "第 %d–%d 天" % [day, day + term_days - 1]

func _event_name(day: int) -> String:
	if Global.is_gathering_day(day):
		return "谷雨亭集"
	if Global.is_summer_raft_day(day):
		return SummerRaft.TITLE
	if Global.is_winter_supper_day(day):
		return WinterSupper.PLACE
	return AutumnExhibit.NAME if Global.is_autumn_exhibit_day(day) else ""

func _show_date(index: int) -> void:
	focus = index
	for row: Button in dates.get_children():
		row.set_pressed_no_signal(row.get_index() == focus)
	var day := _day(focus)
	var past := day + term_days <= Global.current_day
	var upcoming := day > Global.current_day
	title.text = "%s   ·   %s" % [Global.get_current_solar_term(day), _day_label(day)]
	var weather := "雨 · 旱作可得水" if Global.has_rain(day) else "晴"
	if past:
		forecast.text = weather + "    ·    节气已过"
	else:
		var guest := VisitorData.for_day(day, residents) if upcoming else Global.visitor_for_day(Global.current_day)
		var visit := "首日轮访" if upcoming and term_days > 1 else ("轮访" if upcoming else "今日轮访")
		forecast.text = "%s    ·    %s" % [weather, "%s %s" % [visit, guest.name] if guest else "轮访歇日"]
		if not upcoming and Global.ravine_handoff_visit_today():
			forecast.text += ("\n蒲宁在南边竹径等手记。" if Global.ravine_handoff_ready() else "\n蒲宁今天在竹径药圃。")
		if day == Global.current_day + 1 and Global.is_raid_day(day):
			forecast.text += "\n明日东关有敌情，留意守备。"
	for crop_id: String in CropData.IDS:
		var crop := ItemManager.get_crop(crop_id)
		if crop.favored_season == season:
			planting.text = "当季宜播 %s · %d 夜成熟%s" % [crop.crop_name, Global.sowing_nights(crop, day),
				" · 需渠水" if crop.is_water_crop else " · 须逐夜供水"]
			break
	var schedule := Global.season_order(day)
	var delivered := Global.season_order_delivered_at(schedule)
	var due := "第 %d 天已交齐" % delivered if delivered > 0 else "第 %d 天截止" % schedule.end
	order_note.text = "本季托付  %s\n%s · %s" % [schedule.order.title, ItemManager.describe_season_order(schedule.order), due]
	if schedule.start > Global.current_day and Global.is_season_order_pinned(schedule):
		order_note.text += " · 已跟踪备货"
	_show_event(day)

func _show_event(day: int) -> void:
	var special := _event_name(day)
	var last_day := day + _event_length(day, term_days) - 1
	var past := last_day < Global.current_day
	var place := _event_place(day)
	event_note.visible = not special.is_empty()
	guide.visible = not special.is_empty() and not past
	guide.text = ("先认路 · " if day > Global.current_day else "指路去") + place
	fish_guide.hide()
	if Global.is_autumn_exhibit_day(day):
		var entry := Global.autumn_exhibit_record(day)
		if not entry.is_empty():
			event_note.text = "秋社已入簿 · %s\n谷样%s。" % [AutumnExhibit.names(entry.crops), "已分给乡邻" if entry.shared else "已带回"]
		else:
			event_note.text = "秋社 · 今年展台已收。" if past else _autumn_plan(day, last_day)
	elif Global.is_gathering_day(day):
		var score: int = Global.gathering_recitals.get(day, 0)
		event_note.text = "谷雨亭集 · 南路亭东\n" + ("迎客曲 %d/%d · 已入曲簿" % [score, Global.GATHERING_BEATS]
			if score > 0 else ("今年亭集已散。" if past else "找商音合奏迎客曲。击准 %d 声可得乐经验。" % Global.GATHERING_MIN_HITS))
	elif Global.is_summer_raft_day(day):
		var best: Dictionary = Global.summer_raft_results.get(day, {})
		event_note.text = "夏至试筏 · 竹涧西岸\n" + ("本年最好成绩 · " + SummerRaft.score_text(best.gates, best.time_ms)
			if not best.is_empty() else ("今年试筏已结束。" if past else "沿溪过四道竹标。过三道可得御经验。"))
		if not past and term_days > 1:
			event_note.text += "\n第 %d 天试筏。" % day
	elif Global.is_winter_supper_day(day):
		var record := Global.winter_supper_record(day)
		if not record.is_empty():
			event_note.text = "冬至已入簿 · %s\n围炉备了 %d 份，先供当晚门客。" % [WinterSupper.RECIPES[record.recipe].name, record.portions]
		else:
			event_note.text = "冬至围炉 · 今年这席已散。" if past else _winter_plan(day)
	guide.get_parent().visible = guide.visible or fish_guide.visible

func _autumn_stock() -> Array[String]:
	var stock: Array[String] = []
	for id: String in AutumnExhibit.CROPS:
		if Global.crop_stock.count(id) > 0:
			stock.append(id)
	return stock

func _ripe_private_crops() -> Dictionary:
	var ripe := {}
	for cell: Vector2i in Global.active_crops:
		if not Global.is_public_plot(cell) and Global.field_crop_is_ripe(cell):
			ripe[Global.active_crops[cell].id] = true
	return ripe

func _autumn_plan(day: int, last_day: int) -> String:
	var stock := _autumn_stock()
	var needed := maxi(0, AutumnExhibit.SAMPLE_COUNT - stock.size())
	var preparation := "谷样已齐" if needed == 0 else "还差 %d 种" % needed
	var on_hand := "仓中暂无谷样" if stock.is_empty() else "仓中有 " + AutumnExhibit.names(stock)
	var line := "秋社 · %s\n备三种不同的私田作物，各一份。\n留样给乡邻，冬至禾伯会出菽。\n%s · %s" % [
		EstateLayout.FESTIVAL_SITE_NAME, on_hand, preparation]
	if needed == 0 or day - Global.current_day > _notice_lead(AutumnExhibit.TERM):
		return line
	var ripe := _ripe_private_crops()
	var harvest: Array[String] = []
	var sow: Array[String] = []
	for id: String in AutumnExhibit.CROPS:
		if id in stock:
			continue
		if ripe.has(id):
			harvest.append(id)
			continue
		var crop := ItemManager.get_crop(id)
		if not crop.is_water_crop and Global.sowing_nights(crop) <= last_day - Global.current_day:
			sow.append(id)
	if not harvest.is_empty():
		line += "\n可收私田 %s。" % AutumnExhibit.names(harvest)
	if harvest.size() < needed and not sow.is_empty():
		line += "\n今日播 %s，逐夜供水可赶上。" % AutumnExhibit.names(sow)
	return line

func _winter_notice(day: int) -> String:
	var wheat := Global.crop_stock.count("wheat") > 0
	var beans := Global.crop_stock.count("beans") > 0 or Global.winter_supper_bean_gift(day)
	var fish := not Global.fish_for_travel_meal().is_empty()
	if not wheat:
		return "缺麦" if beans or fish else "缺食材"
	if beans:
		return "两道齐料" if fish else "可备麦菽粥"
	return "可备鱼麦羹" if fish else "缺菽或鱼"

func _winter_plan(day: int) -> String:
	var wheat := Global.crop_stock.count("wheat")
	var beans := Global.crop_stock.count("beans")
	var gift := Global.winter_supper_bean_gift(day)
	var fish := Global.fish_for_travel_meal()
	var fish_name: String = "无溪鱼" if fish.is_empty() else CreekFish.SPECIES[fish].name
	var date := "第 %d 天 · " % day if term_days > 1 else ""
	var line := "冬至围炉 · %s\n%s酉时点灯。围炉饭先供当晚门客。\n仓中 麦 %d · 菽 %d · %s" % [
		EstateLayout.FESTIVAL_SITE_NAME, date, wheat, beans, fish_name]
	line += "\n麦菽粥 %d 份 · %s" % [WinterSupper.portions(WinterSupper.BEAN, Global.balance),
		"禾伯出菽，带一份麦即可。" if gift else "麦、菽各一份。"]
	line += "\n鱼麦羹 %d 份 · 一份麦、一尾溪鱼。" % WinterSupper.portions(WinterSupper.FISH, Global.balance)
	var remaining := day - Global.current_day
	if remaining <= _notice_lead(WinterSupper.TERM):
		var prep := PackedStringArray()
		var ripe := _ripe_private_crops()
		if wheat == 0:
			var nights := Global.sowing_nights(ItemManager.get_crop("wheat"))
			if ripe.has("wheat"):
				prep.append("可收私田熟麦")
			elif nights <= remaining:
				prep.append("今日播私田麦，%d 夜可收" % nights)
		if not gift and beans == 0:
			var nights := Global.sowing_nights(ItemManager.get_crop("beans"))
			if ripe.has("beans"):
				prep.append("可收私田熟菽")
			elif nights <= remaining:
				prep.append("今日播私田菽，%d 夜可收" % nights)
		if not prep.is_empty():
			line += "\n" + "。".join(prep) + "。新播作物须逐夜供水。"
		if fish.is_empty():
			fish_guide.visible = Global.knows_ravine_journal() and Global.last_fishing_day != Global.current_day
			if not gift and beans == 0 and not Global.knows_ravine_journal():
				line += "\n可到南边竹径向蒲宁学垂钓。"
	return line

func _event_place(day: int) -> String:
	if Global.is_summer_raft_day(day):
		return SummerRaft.PLACE
	if Global.is_winter_supper_day(day):
		return WinterSupper.PLACE
	if Global.is_autumn_exhibit_day(day):
		return "秋社展台"
	return "南路亭东"

func _request_directions() -> void:
	_follow_place(_event_place(_day(focus)))

func _follow_place(place: String) -> void:
	directions_requested.emit(place)
	close_map()
