extends VBoxContainer

const ROSTER_ENTRY := preload("res://scenes/NeighborRosterEntry.tscn")
const ROLES := {
	VisitorData.FIELD_KEEPER: "井田管事",
	VisitorData.ROAD_KEEPER: "南路行客",
	VisitorData.WATER_GUIDE: "水利墨者",
	VisitorData.SILK_MERCHANT: "南路绸商",
	VisitorData.RAVINE_GUIDE: "竹涧行者",
	VisitorData.EAST_WATCHER: "东路弓士",
	VisitorData.MUSIC_HOST: "亭集乐师",
}

@onready var roster: VBoxContainer = %Roster
@onready var roster_scroll: ScrollContainer = $Pages/RosterCard/Stack/Scroll
@onready var known_count: Label = %KnownCount
@onready var page: VBoxContainer = %Page
@onready var page_scroll: ScrollContainer = $Pages/PageCard/Scroll
@onready var profile: PanelContainer = %Profile
@onready var portrait: TextureRect = %Portrait
@onready var person_name: Label = %PersonName
@onready var first_meeting: Label = %FirstMeeting
@onready var where: Label = %Where
@onready var locate_button: Button = %LocateNeighbor
@onready var memory: Label = %Memory
@onready var next_step: Label = %Next
@onready var pavilion_card: PanelContainer = %PavilionCard
@onready var appointment_title: Label = %AppointmentTitle
@onready var appointment_note: Label = %AppointmentNote
@onready var pavilion_route: Button = %PavilionRoute
@onready var world: Node2D = get_tree().current_scene.get_node("World")

var selected := ""

func _ready() -> void:
	for control: Control in [$Title, known_count, person_name, first_meeting, where, locate_button, memory,
		next_step, %NextHeading, %MemoryHeading, appointment_title, appointment_note, pavilion_route, %Empty]:
		InterfaceFont.scale_reading_text(control)
	for scroll: ScrollContainer in [roster_scroll, page_scroll]:
		var scrollbar := scroll.get_v_scroll_bar()
		scrollbar.focus_mode = Control.FOCUS_ALL
		scrollbar.theme_type_variation = &"HudJournalBar"
	locate_button.icon = HUDIcons.icon(HUDIcons.Symbol.MAP)
	var group := ButtonGroup.new()
	for speaker: String in VisitorData.NEIGHBORS:
		_add_roster_entry(speaker, group)
	visibility_changed.connect(refresh)
	GamepadInput.changed.connect(refresh)
	Preferences.bindings_changed.connect(refresh)
	GameEvents.day_advanced.connect(refresh.unbind(1))
	GameEvents.daylight_changed.connect(refresh)
	world.visitor_changed.connect(refresh.unbind(1))
	world.pavilion_rest.story_changed.connect(refresh.unbind(3))
	GameEvents.retainer_assigned.connect(refresh.unbind(2))
	GameEvents.retainer_duty_changed.connect(refresh.unbind(1))
	GameEvents.retainer_location_changed.connect(refresh)
	GameEvents.retainer_recruited.connect(refresh.unbind(1))
	GameEvents.retainer_departed.connect(refresh.unbind(1))
	GameEvents.food_changed.connect(refresh.unbind(1))
	GameEvents.road_rest_changed.connect(refresh)
	GameEvents.pavilion_story_heard.connect(refresh)
	GameEvents.seed_garden_arrived.connect(refresh)
	GameEvents.field_rotation_changed.connect(refresh)
	locate_button.pressed.connect(func(): GameEvents.neighbor_directions_requested.emit(selected))
	pavilion_route.pressed.connect(GameEvents.pavilion_story_directions_requested.emit)
	refresh()

func _add_roster_entry(speaker: String, group: ButtonGroup) -> void:
	var button := ROSTER_ENTRY.instantiate() as Button
	button.name = speaker
	button.button_group = group
	button.pressed.connect(_show_neighbor.bind(speaker))
	roster.add_child(button)
	button.get_node("Inset/Row/Caption/Name").text = speaker
	InterfaceFont.scale_reading_text(button.get_node("Inset/Row/Caption/Name"))
	InterfaceFont.scale_reading_text(button.get_node("Inset/Row/Caption/Status"))
	var inset := button.get_node("Inset") as MarginContainer
	var standard_height := button.custom_minimum_size.y
	var fit := func(): button.custom_minimum_size.y = maxf(standard_height, inset.get_combined_minimum_size().y)
	inset.minimum_size_changed.connect(fit)
	fit.call()

func refresh() -> void:
	if not is_visible_in_tree():
		return
	var known := {}
	var previous: Button
	for button: Button in roster.get_children():
		var speaker := String(button.name)
		button.visible = Global.knows_neighbor(speaker)
		if button.visible:
			var visit := _visit(speaker)
			known[speaker] = visit
			button.get_node("Inset/Row/Portrait").texture = CharacterArt.dialogue_portrait(speaker, null, VisitorData.favor_completed(speaker))
			button.get_node("Inset/Row/Caption/Status").text = visit.summary
			button.accessibility_name = "%s，%s" % [speaker, visit.summary]
			button.focus_neighbor_top = button.get_path_to(previous) if previous else NodePath()
			button.focus_neighbor_bottom = NodePath(".")
			if previous:
				previous.focus_neighbor_bottom = previous.get_path_to(button)
			previous = button
	known_count.text = "已相识  %d / %d" % [known.size(), VisitorData.NEIGHBORS.size()]
	%PageCard.visible = not known.is_empty()
	%EmptyCard.visible = known.is_empty()
	%Empty.text = "在田边或南路亭遇见人时，靠近按 %s 打招呼。" % GamepadInput.interact_key()
	if not known.is_empty():
		var speaker: String = selected if known.has(selected) else known.keys()[0]
		_show_neighbor(speaker, known[speaker])

func _show_neighbor(speaker: String, visit := {}) -> void:
	if selected != speaker:
		page_scroll.scroll_vertical = 0
	selected = speaker
	var button := roster.get_node(speaker) as Button
	button.button_pressed = true
	portrait.texture = CharacterArt.dialogue_portrait(speaker, null, VisitorData.favor_completed(speaker))
	person_name.text = speaker
	var day: int = Global.neighbor_met_days.get(speaker, 0)
	var date := "第 %d 天相识 · %s" % [day, Global.get_current_solar_term(day)] if day > 0 else "旧日相识"
	first_meeting.text = "%s  ·  %s" % [ROLES[speaker], date]
	if visit.is_empty():
		visit = _visit(speaker)
	where.text = visit.location
	locate_button.visible = not visit.route.is_empty()
	locate_button.text = visit.route
	_refresh_appointment(speaker)
	var story := _story(speaker)
	memory.text = story[0]
	var garden_day := Global.seed_garden_day()
	if speaker == VisitorData.ROAD_KEEPER and garden_day > 0:
		memory.text += "\n第 %d 天 · 林蓼把春单的菽和黍种在亭西种圃。" % garden_day
	for note: String in PavilionStories.heard_notes(speaker):
		memory.text += "\n" + note
	next_step.text = story[1]
	var departure: Dictionary = Global.neighbor_departures.get(speaker, {})
	if not departure.is_empty():
		if departure.day > 0:
			var note := "第 %d 天夜 · 缺餐后离任。" if departure.reason == Global.DepartureReason.HUNGER else "第 %d 天 · 议税后离任。"
			memory.text += "\n" + (note % departure.day)
		if departure.returned_day > 0:
			memory.text += "\n第 %d 天 · 应邀回来照料田地。" % departure.returned_day
	var portions := Global.recruitment_food_requirement(speaker)
	if portions > 0 and not Global.retainers.any(func(resident: RetainerData) -> bool: return resident.name == speaker):
		var gap := portions - Global.food_storage
		var purpose := "留任口粮" if Global.pending_neighbor_return(speaker).is_empty() else "返岗口粮"
		where.text += "\n%s · 粮仓 %d / %d 份 · %s" % [
			purpose, Global.food_storage, portions, "还差 %d 份" % gap if gap > 0 else "口粮已备齐"]
	%NextCard.visible = not next_step.text.is_empty()

func _refresh_appointment(speaker: String) -> void:
	var table := world.pavilion_rest as PavilionRest
	var ready := not table.story_id.is_empty()
	var id := table.story_id if ready else table.appointment_id
	pavilion_card.visible = not id.is_empty() and speaker in PavilionStories.speakers(id)
	if not pavilion_card.visible:
		return
	var story: Dictionary = PavilionStories.STORIES[id]
	appointment_title.text = "%s · %s" % [PavilionRest.STORY_LABEL if ready else "今晚小谈", story.title]
	var people := "、".join(story.speakers)
	appointment_note.text = ("%s已入席 · %s" % [people, table.gathering_name()] if ready
		else "%s起 · %s · %s" % [PavilionRest.rest_watch(), people, table.gathering_name()])
	pavilion_route.text = "指路去席案" if ready else "指路去候席"

func _visit(speaker: String) -> Dictionary:
	var person: Node2D = world.neighbor_actor(speaker)
	var route := "在地图上找" if is_instance_valid(person) else ""
	for resident in Global.retainers:
		if resident.name == speaker:
			var actor := person as Retainer
			var rest := actor.pavilion_note() if actor else ""
			if not rest.is_empty():
				return _visit_note("留任 · 亭边歇脚", rest + " · 留任门客", route)
			return _visit_note("留任门客", "%s · 留任门客 · %s" % [world.duty_place(resident), resident.duty_name()], route)
	var actor := person as Visitor
	if actor and actor in world.active_visitors:
		var guest := actor.data
		var purpose := "等交手记" if speaker == VisitorData.RAVINE_GUIDE and Global.ravine_handoff_ready() else "今日来访"
		var note := "%s · %s" % [actor.visit_note(), purpose]
		if speaker == VisitorData.SILK_MERCHANT and VisitorData.silk_market_day(Global.current_day) \
				and guest.silk_trip() == VisitorData.SilkTrip.NONE:
			note += "\n" + VisitorData.SILK_MARKET_PLAN
		elif guest.has_pavilion_rest() and VisitorData.pavilion_rest_seconds() < 0.0:
			note += "\n" + VisitorData.pavilion_rest_plan()
		return _visit_note(purpose, note, route)
	if speaker == VisitorData.SILK_MERCHANT:
		var trip: Dictionary = world.silk_trip_stop()
		if not trip.is_empty():
			var label := "西市行程" if trip.place == "西市" else "正返封地"
			return _visit_note(label, trip.note, "指路去" + trip.place)
	if speaker == VisitorData.FIELD_KEEPER:
		if Global.field_keeper_visiting():
			return _visit_note("今日回访", "井田西南 · 今日回来看看", route)
		var day := Global.next_field_keeper_visit()
		return _visit_note("第 %d 天回访" % day, "住在封地外 · 第 %d 天回井田西南" % day)
	if world.get_node("SpringGathering/Guests").has_node(speaker):
		return _visit_note("谷雨亭集", "南路亭东 · 谷雨亭集", route)
	if speaker == VisitorData.MUSIC_HOST:
		return _visit_note("谷雨来访", "随节气来访 · 谷雨可在南路亭东遇见", route)
	for persona in VisitorData.PERSONAS:
		if persona.name == speaker:
			var day := Global.next_visitor_day(speaker)
			if day > 0:
				var note := "下一次轮访 · 第 %d 天 · %s" % [day, VisitorData.scheduled_stop(speaker, persona.place, day)]
				if speaker == VisitorData.SILK_MERCHANT and VisitorData.silk_market_day(day):
					note += "\n" + VisitorData.SILK_MARKET_PLAN
				return _visit_note("第 %d 天轮访" % day, note, route)
			return _visit_note("今日在外", "今日在外 · 来访时常到%s" % persona.place, route)
	return _visit_note("今日在外", "今日在外", route)

func _visit_note(summary: String, location: String, route := "") -> Dictionary:
	return {"summary": summary, "location": location, "route": route}

func _story(speaker: String) -> Array[String]:
	match speaker:
		VisitorData.FIELD_KEEPER:
			return _field_keeper_story()
		VisitorData.ROAD_KEEPER:
			return _road_story()
		VisitorData.WATER_GUIDE:
			if Global.channel_survey_day > 0:
				return ["第 %d 天同石墨勘渠，量水尺立在了水源旁。" % Global.channel_survey_day, "挖渠时可用放样预看通水范围和费用。"]
			if Global.water_review_ready():
				return ["第 %d 天，田苗第一次靠渠水长过一夜。" % Global.first_channel_growth_day, "找石墨一同勘渠。"]
			return ["石墨在水源旁讲过田渠的高低。", "解锁水利，把水渠接到正在生长的田苗旁，再过一夜。"]
		VisitorData.SILK_MERCHANT:
			if Global.silk_sample_day > 0:
				var lead := "沿西路去绸摊，可以看到蔡娘挂出的样绸。" if VisitorData.silk_sample_on_display(Global.current_day) \
					else "明日可去西市绸摊看样绸。"
				return ["第 %d 天交了样绸。陶辛留一角在西廊，把其余的交给蔡娘。" % Global.silk_sample_day, lead]
			return ["陶辛沿南路收绸，想让来往的人看看这片封地织的样子。", "织好一匹绸，再找陶辛谈样绸。"]
		VisitorData.RAVINE_GUIDE:
			if Global.ravine_journal.garden_day > 0:
				return ["第 %d 天交还溪行手记。蒲宁在竹径东侧留下一畦药苗。" % Global.ravine_journal.garden_day, "受伤时可去药圃取用。"]
			var lead := Global.ravine_status() if Global.knows_ravine_journal() else "同蒲宁交谈，听他托付三处水迹。"
			return ["蒲宁熟悉木桥、浅滩和望溪台。", lead]
		VisitorData.EAST_WATCHER:
			if Global.east_watch_day > 0:
				return ["第 %d 天同弋戎复盘守田，把战果刻在东岗守备牌上。" % Global.east_watch_day, "东路岗的守备牌可以翻看最新战果。"]
			var lead := "最近一场敌袭已经击退，可以找弋戎复盘。" if Global.defense_review_ready() else "击退一次敌袭，再找弋戎说说东路的守备。"
			return ["弋戎常绕着东边的田埂看脚印。", lead]
		VisitorData.MUSIC_HOST:
			if not Global.gathering_recitals.is_empty():
				var day: int = Global.gathering_recitals.keys().max()
				return ["第 %d 天同商音合奏迎客曲，敲中 %d 拍。" % [day, Global.gathering_recitals[day]], "南路亭边的曲簿留着历次成绩。"]
			return ["商音在谷雨亭集挂起了四口钟。", "谷雨去南路亭东，跟商音试奏迎客曲。"]
	return ["", ""]

func _field_keeper_story() -> Array[String]:
	var story := Global.field_rotation
	if not Global.first_tribute_delivered():
		return ["开垦头一块井田时，渠伯就在田边收紧木桶的箍。", "从井田中央收一份作物，送入国库。"]
	if story.promise_day == 0:
		return ["渠伯陪你等到了头一份公田收成。", "再找渠伯谈谈，他想在一格私田试两茬庄稼。"]
	var note := "第 %d 天 · 与渠伯约好在私田试轮作。" % story.promise_day
	if story.beans_day > 0:
		note += "\n第 %d 天 · 收了菽，田里留下豆茬的肥。" % story.beans_day
	if story.harvest_day > 0:
		note += "\n第 %d 天 · 井田 %d 的%s轮作多收一份。" % [
			story.harvest_day, story.field_number, Global.rotation_crop_name()]
	if story.signed_day > 0:
		note += "\n第 %d 天 · 把这次收成记进轮作簿。" % story.signed_day
		return [note, "沿井田西南的岔路翻看轮作簿，可以标出肥地、安排轮作和管事。"]
	if story.ready_to_sign():
		return [note, "再找渠伯，把这一格田的两茬收成记下来。"]
	if story.beans_day > 0:
		return [note, "在有金角标的私田种别的作物，并把它收下。"]
	return [note, "先在一格私田收菽，再在原地种下一茬。已有豆茬的私田也可以用。"]

func _road_story() -> Array[String]:
	if not Global.road_provisions_delivered:
		var lead := "备一份私田收成，再找季青交路粮。" if Global.road_provisions_requested() else "和季青交谈，等头一份公田收成送入国库。"
		return ["季青借南路亭歇脚，常替错过饭点的旅人惦记一口粮。", lead]
	var date := "第 %d 天 · " % Global.road_provisions_day if Global.road_provisions_day > 0 else ""
	var note := date + "你留了一份收成，季青把路粮收进亭边的木匣。"
	if Global.road_rest_built():
		note += "\n第 %d 天 · 亭西摆好了长凳和水瓮。" % (Global.road_rest_paid_day + 1)
		var lead := ("今天已在亭西歇脚。" if Global.road_rest_used_day == Global.current_day
			else "体力不足时，可到长凳旁按 %s 歇一歇。每日一次。" % GamepadInput.interact_key())
		return [note, lead]
	if Global.road_rest_paid_day > 0:
		return [note + "\n第 %d 天 · 备下木料。" % Global.road_rest_paid_day, "过一夜，亭西的歇脚处便能用。"]
	if Global.road_rest_requested():
		return [note, "再见季青时，可以出 %d 铜钱一起修歇脚处。" % Global.balance.road_rest_cost]
	return [note, "改日再见季青，问问路粮匣旁还缺什么。"]
