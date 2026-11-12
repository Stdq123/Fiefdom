extends "res://scripts/SurveyMap.gd"

signal directions_requested(place: String)

const TERMS := SeasonOrders.TERMS_PER_SEASON

@onready var seasons: HBoxContainer = %Seasons
@onready var dates: VBoxContainer = %Dates
@onready var year_label: Label = %Year
@onready var title: Label = %DateTitle
@onready var forecast: Label = %Forecast
@onready var planting: Label = %Planting
@onready var order_note: Label = %Order
@onready var event_note: Label = %Event
@onready var guide: Button = %Guide

var controls_blocked: Callable
var year_start := 1
var term_days := 1
var season := 0
var focus := 0
var residents: Array[String] = []

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

func _map_available() -> bool:
	return not controls_blocked.call()

func _refresh_on_open() -> void:
	term_days = maxi(1, Global.balance.days_per_solar_term)
	var length := term_days * Global.SOLAR_TERMS.size()
	year_start = Global.current_day - posmod(Global.current_day - 1, length)
	year_label.text = "第 %d 年    ·    今天第 %d 天" % [Global.get_current_year(), Global.current_day]
	residents.clear()
	for member: RetainerData in Global.retainers:
		residents.append(member.name)
	_show_season(Global.season_index())

func _show_season(next: int) -> void:
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
	_show_date(Global.solar_term_index() % TERMS if season == Global.season_index() else 0)

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
	var special := _event_name(day)
	event_note.visible = not special.is_empty()
	guide.visible = not special.is_empty() and not past
	guide.text = "指路去" + _event_place(day)
	if Global.is_autumn_exhibit_day(day):
		var entry := Global.autumn_exhibit_record(day)
		event_note.text = "秋社 · 东南空地\n备三种不同的私田作物，各一份。可摆样带回，也可留给乡邻。"
		if not entry.is_empty():
			event_note.text = "秋社已入簿 · %s\n谷样%s。" % [AutumnExhibit.names(entry.crops), "已分给乡邻" if entry.shared else "已带回"]
	elif Global.is_gathering_day(day):
		var score: int = Global.gathering_recitals.get(day, 0)
		event_note.text = "谷雨亭集 · 南路亭东\n" + ("迎客曲 %d/%d · 已入曲簿" % [score, Global.GATHERING_BEATS]
			if score > 0 else "在亭东找商音合奏迎客曲。")
	elif Global.is_summer_raft_day(day):
		var best: Dictionary = Global.summer_raft_results.get(day, {})
		guide.visible = day >= Global.current_day
		event_note.text = "夏至试筏 · 竹涧西岸\n" + ("本年最好成绩 · " + SummerRaft.score_text(best.gates, best.time_ms)
			if not best.is_empty() else "沿溪过四道竹标。过三道可得御经验。")
	elif Global.is_winter_supper_day(day):
		var record := Global.winter_supper_record(day)
		guide.visible = day >= Global.current_day
		if not record.is_empty():
			event_note.text = "冬至已入簿 · %s\n围炉备了 %d 份，先供当晚门客。" % [WinterSupper.RECIPES[record.recipe].name, record.portions]
		elif day < Global.current_day:
			event_note.text = "冬至围炉 · 今年这席已散。"
		else:
			event_note.text = "冬至围炉 · 东南空地 · 酉时点灯\n备一份麦，再带一份菽或一尾溪鱼。围炉饭供当晚门客。"

func _event_place(day: int) -> String:
	if Global.is_summer_raft_day(day):
		return SummerRaft.PLACE
	if Global.is_winter_supper_day(day):
		return WinterSupper.PLACE
	if Global.is_autumn_exhibit_day(day):
		return "秋社展台"
	return "南路亭东"

func _request_directions() -> void:
	directions_requested.emit(_event_place(_day(focus)))
	close_map()
