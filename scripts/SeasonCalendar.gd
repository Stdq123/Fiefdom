extends "res://scripts/SurveyMap.gd"

signal directions_requested(place: String)
signal order_requested(upcoming: bool)

const TERMS := SeasonOrders.TERMS_PER_SEASON
const EVENT_TERMS := [Global.GATHERING_TERM, SummerRaft.TERM, AutumnExhibit.TERM, WinterSupper.TERM]

@onready var seasons: HBoxContainer = %Seasons
@onready var dates: VBoxContainer = %Dates
@onready var year_label: Label = %Year
@onready var previous_year: Button = %PreviousYear
@onready var next_year: Button = %NextYear
@onready var today_button: Button = %Today
@onready var title: Label = %DateTitle
@onready var date_context: Label = %DateContext
@onready var read_scroll: ScrollContainer = %ReadScroll
@onready var weather_icon: TextureRect = %WeatherIcon
@onready var forecast: Label = %Forecast
@onready var planting: Label = %Planting
@onready var order_note: Label = %Order
@onready var order_button: Button = %OrderBook
@onready var event_note: Label = %Event
@onready var guide: Button = %Guide
@onready var fish_guide: Button = %FishGuide
@onready var pantry_note: Label = %PantryNote
@onready var keep_samples: Button = %KeepSamples
@onready var keep_porridge: Button = %KeepPorridge
@onready var keep_soup: Button = %KeepSoup
@onready var routes: HBoxContainer = %Routes
@onready var pantry_actions: HBoxContainer = %Pantry
@onready var actions: VBoxContainer = %Actions

var controls_blocked: Callable
var year_start := 1
var term_days := 1
var season := 0
var focus := 0
var residents: Array[String] = []
var day_to_open := 0

func _ready() -> void:
	super._ready()
	for label: Label in [forecast, planting, order_note, event_note, pantry_note]:
		InterfaceFont.scale_reading_text(label)
	var bar := read_scroll.get_v_scroll_bar()
	bar.focus_mode = FOCUS_ALL
	bar.visibility_changed.connect(_refresh_focus, CONNECT_DEFERRED)
	previous_year.pressed.connect(_change_year.bind(-1))
	next_year.pressed.connect(_change_year.bind(1))
	today_button.pressed.connect(func(): _show_day(Global.current_day))
	for button: Button in seasons.get_children():
		button.pressed.connect(_show_season.bind(button.get_index()))
	var normal := dates.get_theme_stylebox("normal", "Button")
	var selected := dates.get_theme_stylebox("pressed", "Button").duplicate() as StyleBox
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		selected.set_content_margin(side, normal.get_margin(side))
	for button: Button in [keep_samples, keep_porridge, keep_soup]:
		button.add_theme_stylebox_override("pressed", selected)
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
	fish_guide.pressed.connect(_request_fishing_directions)
	order_button.pressed.connect(_request_order)
	keep_samples.toggled.connect(_set_pantry)
	keep_porridge.toggled.connect(_set_pantry.bind(WinterSupper.BEAN))
	keep_soup.toggled.connect(_set_pantry.bind(WinterSupper.FISH))

func _map_available() -> bool:
	return not controls_blocked.call()

func open_noticed_event() -> void:
	var event_day := _noticed_day()
	if event_day > 0:
		open_day(maxi(event_day, Global.current_day))

func open_day(day: int) -> void:
	day_to_open = day
	open_map()
	day_to_open = 0

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
		var have := AutumnExhibit.stocked_crops(Global.crop_stock).size()
		status = ("谷样 %d/%d" % [mini(have, AutumnExhibit.SAMPLE_COUNT), AutumnExhibit.SAMPLE_COUNT]
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
		if today >= day - Global.festival_notice_lead(term):
			return day
	return 0

func _year_start(day: int, term_length: int) -> int:
	return day - posmod(day - 1, term_length * Global.SOLAR_TERMS.size())

func _event_length(day: int, term_length: int) -> int:
	return term_length if Global.is_gathering_day(day) or Global.is_autumn_exhibit_day(day) else 1

func _refresh_on_open() -> void:
	term_days = maxi(1, Global.balance.days_per_solar_term)
	residents.clear()
	for member: RetainerData in Global.retainers:
		residents.append(member.name)
	_show_day(day_to_open if day_to_open > 0 else Global.current_day)

func _show_day(day: int) -> void:
	year_start = _year_start(day, term_days)
	var year_days := term_days * Global.SOLAR_TERMS.size()
	var year := floori(float(year_start - 1) / year_days) + 1
	var current_start := _year_start(Global.current_day, term_days)
	year_label.text = "第 %d 年    ·    今天第 %d 天" % [year, Global.current_day]
	previous_year.disabled = year_start == 1
	next_year.disabled = year_start >= current_start + year_days
	_show_season(Global.season_index(day), Global.solar_term_index(day) % TERMS, day)

func _change_year(step: int) -> void:
	var button := previous_year if step < 0 else next_year
	if button.disabled:
		return
	var had_focus := button.has_focus()
	_show_day(_day(focus) + step * term_days * Global.SOLAR_TERMS.size())
	if had_focus and button.disabled:
		today_button.grab_focus()
		GamepadInput.snap_pointer_to_focus()

func _show_season(next: int, first_date := -1, detail_day := 0) -> void:
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
		var this_season := year_start == _year_start(Global.current_day, term_days) and season == Global.season_index()
		first_date = Global.solar_term_index() % TERMS if this_season else 0
	_show_date(first_date, detail_day)

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

func _show_date(index: int, detail_day := 0) -> void:
	focus = index
	read_scroll.scroll_vertical = 0
	for row: Button in dates.get_children():
		row.set_pressed_no_signal(row.get_index() == focus)
	var term_day := _day(focus)
	var day := detail_day if detail_day > 0 else term_day
	if detail_day == 0 and Global.current_day >= term_day and Global.current_day < term_day + term_days:
		day = Global.current_day
	var upcoming := day > Global.current_day
	var date := _day_label(term_day) if detail_day == 0 else "第 %d 天" % day
	var caption := "%s   ·   %s" % [Global.get_current_solar_term(day), date]
	if modal.is_visible_in_tree() and title.text != caption:
		AudioManager.play_menu_cue(AudioManager.MenuCue.PAGE)
	title.text = caption
	var remaining := day - Global.current_day
	if remaining < 0:
		date_context.text = "已过"
	elif remaining == 0:
		date_context.text = "今日"
	elif remaining == 1:
		date_context.text = "明日"
	else:
		date_context.text = "%d 天后" % remaining
	weather_icon.texture = HUDIcons.icon(HUDIcons.SKY[HUDIcons.sky_index(day)])
	var weather := "雨 · 旱作可得水" if Global.has_rain(day) else Global.weather_label(day)
	if day < Global.current_day:
		forecast.text = weather + "    ·    此日已过"
	else:
		var guest := VisitorData.for_day(day, residents) if upcoming else Global.visitor_for_day(day)
		var visit := "预计轮访" if upcoming else "今日轮访"
		var visit_note := "%s %s" % [visit, guest.name] if guest else ("预计轮访歇日" if upcoming else "轮访歇日")
		forecast.text = "%s    ·    %s" % [weather, visit_note]
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
	_show_order(day)
	_show_event(term_day)
	_refresh_focus()

func _refresh_focus() -> void:
	if not modal.visible:
		return
	var headers := _visible_controls([previous_year, next_year, today_button, close_button])
	var season_tabs: Array[Control] = []
	season_tabs.assign(seasons.get_children())
	var date_rows: Array[Control] = []
	date_rows.assign(dates.get_children())
	var active_season := season_tabs[season]
	var active_date := date_rows[focus]
	var detail_rows: Array[Array] = [
		_visible_controls([order_button, read_scroll.get_v_scroll_bar()]),
		_visible_controls([guide, fish_guide]),
		_visible_controls([keep_samples, keep_porridge, keep_soup]),
	]
	detail_rows = detail_rows.filter(func(row: Array) -> bool: return not row.is_empty())
	var first_detail: Control = close_button if detail_rows.is_empty() else detail_rows[0][0]
	_focus_row(headers, null, active_season)
	_focus_row(season_tabs, today_button, active_date)
	for index in date_rows.size():
		var row := date_rows[index]
		row.focus_neighbor_left = ^"."
		row.focus_neighbor_right = row.get_path_to(first_detail)
		row.focus_neighbor_top = row.get_path_to(date_rows[index - 1] if index > 0 else active_season)
		row.focus_neighbor_bottom = row.get_path_to(date_rows[mini(index + 1, date_rows.size() - 1)])

	var tab_order := headers + season_tabs + date_rows
	var above := active_season
	for index in detail_rows.size():
		var row: Array[Control] = detail_rows[index]
		var below: Control = detail_rows[index + 1][0] if index + 1 < detail_rows.size() else null
		_focus_row(row, above, below, active_date)
		tab_order.append_array(row)
		above = row[0]
	for index in tab_order.size():
		var control := tab_order[index]
		control.focus_next = control.get_path_to(tab_order[(index + 1) % tab_order.size()])
		control.focus_previous = control.get_path_to(tab_order[posmod(index - 1, tab_order.size())])

func _visible_controls(items: Array[Control]) -> Array[Control]:
	var visible_items: Array[Control] = []
	for item in items:
		if item.is_visible_in_tree() and (not item is Button or not item.disabled):
			visible_items.append(item)
	return visible_items

func _focus_row(items: Array[Control], above: Control, below: Control, left: Control = null) -> void:
	for index in items.size():
		var item := items[index]
		var previous := items[index - 1] if index > 0 else left
		item.focus_neighbor_left = item.get_path_to(previous) if previous else ^"."
		item.focus_neighbor_right = item.get_path_to(items[mini(index + 1, items.size() - 1)])
		item.focus_neighbor_top = item.get_path_to(above) if above else ^"."
		item.focus_neighbor_bottom = item.get_path_to(below) if below else ^"."

func _show_order(day: int) -> void:
	var schedule := Global.season_order(day)
	var delivered := Global.season_order_delivered_at(schedule)
	var due := "第 %d 天已交齐" % delivered if delivered > 0 else "第 %d 天截止" % schedule.end
	order_note.text = "%s季托付  %s\n%s · %s" % [Global.SEASON_NAMES[season], schedule.order.title,
		ItemManager.describe_season_order(schedule.order), due]
	if schedule.start > Global.current_day and Global.is_season_order_pinned(schedule):
		order_note.text += " · 已跟踪备货"
	var current := Global.season_order()
	order_button.visible = schedule.start == current.start or schedule.start == current.end + 1
	order_button.text = "下季备货" if schedule.start > current.start else "查看交货簿"

func _request_order() -> void:
	var upcoming: bool = _day(focus) > Global.season_order().end
	close_map()
	order_requested.emit(upcoming)

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
			event_note.text = "秋社 · 展台已收。" if past else _autumn_plan(day, last_day)
	elif Global.is_gathering_day(day):
		var score: int = Global.gathering_recitals.get(day, 0)
		event_note.text = "谷雨亭集 · 南路亭东\n" + ("迎客曲 %d/%d · 已入曲簿" % [score, Global.GATHERING_BEATS]
			if score > 0 else ("亭集已散。" if past else "找商音合奏迎客曲。击准 %d 声可得乐经验。" % Global.GATHERING_MIN_HITS))
	elif Global.is_summer_raft_day(day):
		var best: Dictionary = Global.summer_raft_results.get(day, {})
		event_note.text = "夏至试筏 · 竹涧西岸\n" + ("本年最好成绩 · " + SummerRaft.score_text(best.gates, best.time_ms)
			if not best.is_empty() else ("试筏已结束。" if past else "沿溪过四道竹标。过三道可得御经验。"))
		if not past and term_days > 1:
			event_note.text += "\n第 %d 天试筏。" % day
	elif Global.is_winter_supper_day(day):
		var record := Global.winter_supper_record(day)
		if not record.is_empty():
			event_note.text = "冬至已入簿 · %s\n围炉备了 %d 份，先供当晚门客。" % [WinterSupper.RECIPES[record.recipe].name, record.portions]
		else:
			event_note.text = "冬至围炉 · 这席已散。" if past else _winter_plan(day)
	_refresh_festival_pantry(day)

func _refresh_festival_pantry(day: int) -> void:
	var can_set := Global.can_set_festival_pantry(day)
	var active := can_set and Global.night_rations.festival_day == day
	keep_samples.visible = can_set and Global.is_autumn_exhibit_day(day)
	keep_samples.set_pressed_no_signal(active and keep_samples.visible)
	keep_samples.text = "取消留谷样" if keep_samples.button_pressed else "夜里留谷样"
	var winter := can_set and Global.is_winter_supper_day(day)
	keep_porridge.visible = winter
	keep_soup.visible = winter
	var recipe := Global.night_rations.festival_recipe if active else ""
	keep_porridge.set_pressed_no_signal(recipe == WinterSupper.BEAN)
	keep_soup.set_pressed_no_signal(recipe == WinterSupper.FISH)
	pantry_note.visible = active
	if active:
		pantry_note.text = NightRations.describe_festival_pantry(Global.night_rations_plan().festival_pantry)
	routes.visible = guide.visible or fish_guide.visible
	pantry_actions.visible = keep_samples.visible or winter
	actions.visible = routes.visible or pantry_actions.visible

func _set_pantry(enabled: bool, recipe := "") -> void:
	var day := _day(focus)
	Global.set_festival_pantry(day if enabled else 0, recipe)
	_refresh_festival_pantry(day)

func _ripe_private_crops() -> Dictionary:
	var ripe := {}
	for cell: Vector2i in Global.active_crops:
		if not Global.is_public_plot(cell) and Global.field_crop_is_ripe(cell):
			ripe[Global.active_crops[cell].id] = true
	return ripe

func _autumn_plan(day: int, last_day: int) -> String:
	var stock := AutumnExhibit.stocked_crops(Global.crop_stock)
	var needed := maxi(0, AutumnExhibit.SAMPLE_COUNT - stock.size())
	var preparation := "谷样已齐" if needed == 0 else "还差 %d 种" % needed
	var on_hand := "仓中暂无谷样" if stock.is_empty() else "仓中有 " + AutumnExhibit.names(stock)
	var line := "秋社 · %s\n备三种不同的私田作物，各一份。\n留样给乡邻，冬至禾伯会出菽。\n%s · %s" % [
		EstateLayout.FESTIVAL_SITE_NAME, on_hand, preparation]
	if needed == 0 or day - Global.current_day > Global.festival_notice_lead(AutumnExhibit.TERM):
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
	if remaining <= Global.festival_notice_lead(WinterSupper.TERM):
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
			var site := Global.winter_supper_fishing_site()
			if Global.last_fishing_day == Global.current_day:
				line += "\n垂钓 · 今日垂钓机会已用"
			elif site >= 0:
				var reason := Global.fishing_block_reason(false, site)
				fish_guide.visible = reason.is_empty()
				fish_guide.text = "指路去" + Global.POND_LANDING if site == CreekFish.Site.POND else "指路去柳湾钓鱼"
				if not reason.is_empty():
					line += "\n垂钓 · " + reason
			elif not gift and beans == 0:
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

func _request_fishing_directions() -> void:
	var site := Global.winter_supper_fishing_site()
	if (site >= 0 and Global.fishing_block_reason(false, site).is_empty()
			and Global.fish_for_travel_meal().is_empty()):
		_follow_place(CreekFish.PLACES[site])

func _follow_place(place: String) -> void:
	directions_requested.emit(place)
	close_map()
