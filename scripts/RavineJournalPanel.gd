extends VBoxContainer

const OUTINGS := ["野果坳", "望溪台"]

@export var trace_frame: StyleBoxFlat
@export var trace_art: Array[Texture2D]
@export var garden_art: Array[Texture2D]

@onready var progress: Label = %Progress
@onready var pages: VBoxContainer = %Pages
@onready var scroll: ScrollContainer = %Reading
@onready var today: Label = %Today
@onready var next_step: Label = %NextStep
@onready var next_route: Button = %NextRoute
@onready var introduction: PanelContainer = %Introduction
@onready var visitor_where: Label = %VisitorWhere
@onready var outing_status: Label = %OutingStatus
@onready var forage_notes: Array[Label] = [%FruitQuote, %HerbQuote]
@onready var forage_routes: Array[Button] = [%FruitRoute, %HerbRoute]
@onready var garden_card: PanelContainer = %GardenCard
@onready var garden: Label = %Garden
@onready var world: Node2D = get_tree().current_scene.get_node("World")

var headings: Array[Label] = []
var notes: Array[Label] = []
var active_trace_frame: StyleBoxFlat

func _ready() -> void:
	_build_pages()
	%GuidePortrait.texture = CharacterArt.dialogue_portrait(VisitorData.RAVINE_GUIDE, null, false)
	for control: Control in [%Title, today, progress, next_step, next_route, %GuideName, visitor_where,
		outing_status, %FruitName, %HerbName, %GardenTitle, garden] + forage_notes + forage_routes:
		InterfaceFont.scale_reading_text(control)
	var scrollbar := scroll.get_v_scroll_bar()
	scrollbar.theme_type_variation = &"HudJournalBar"
	scrollbar.focus_mode = Control.FOCUS_ALL
	next_route.pressed.connect(_guide_next_step)
	for index in OUTINGS.size():
		forage_routes[index].pressed.connect(GameEvents.ravine_trip_requested.emit.bind(OUTINGS[index]))
	visibility_changed.connect(_refresh)
	world.visitor_changed.connect(_refresh.unbind(1))
	GameEvents.ravine_journal_changed.connect(_refresh)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.health_changed.connect(_refresh.unbind(1))
	GameEvents.forage_taken.connect(_refresh)
	GameEvents.wild_herbs_changed.connect(_refresh)
	GameEvents.retainer_departed.connect(_refresh.unbind(1))
	GameEvents.retainer_recruited.connect(_refresh.unbind(1))
	_refresh()

func _build_pages() -> void:
	active_trace_frame = trace_frame.duplicate()
	active_trace_frame.border_color = Color("#c9a967")
	active_trace_frame.bg_color = Color("#304032")
	for index in RavineJournal.SITES.size():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override(&"panel", trace_frame)
		pages.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 14)
		card.add_child(row)
		var picture_well := PanelContainer.new()
		picture_well.theme_type_variation = &"HudWell"
		picture_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(picture_well)
		var picture := TextureRect.new()
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.custom_minimum_size = Vector2(96, 72)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.texture = trace_art[index]
		picture_well.add_child(picture)
		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override(&"separation", 5)
		row.add_child(content)
		var heading := Label.new()
		heading.add_theme_font_size_override(&"font_size", 19)
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(heading)
		InterfaceFont.scale_reading_text(heading)
		headings.append(heading)
		var note := Label.new()
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override(&"font_size", 17)
		note.add_theme_color_override(&"font_color", Color("#d6dfce"))
		content.add_child(note)
		InterfaceFont.scale_reading_text(note)
		notes.append(note)

func _refresh() -> void:
	if not is_visible_in_tree():
		return
	var known := Global.knows_ravine_journal()
	var active := Global.ravine_site_today()
	var visitor := world.neighbor_actor(VisitorData.RAVINE_GUIDE) as Node2D
	var has_guide := is_instance_valid(visitor)
	today.text = "第 %d 天 · %s · %s" % [Global.current_day, Global.get_current_solar_term(), Global.weather_label(0, true)]
	pages.visible = known
	introduction.visible = not known
	garden_card.visible = known and Global.ravine_shortcut_open()
	if not known:
		progress.text = "溪行手记尚未领到"
		next_step.text = "与蒲宁交谈，领取记录三处水迹的委托。"
		if visitor is Visitor:
			visitor_where.text = visitor.visit_note()
		else:
			var visit_day := Global.next_visitor_day(VisitorData.RAVINE_GUIDE)
			visitor_where.text = ("第 %d 天来访 · 南边竹径" % visit_day if visit_day > 0 else "轮访 · 南边竹径")
		_set_next_route("找蒲宁", has_guide)
	else:
		progress.text = Global.ravine_status()
		_refresh_pages(active)
		if garden_card.visible:
			next_step.text = "药圃在竹径东侧。南路小径已通往竹涧浅滩。"
			_set_next_route("指路去药圃")
			_refresh_garden()
		elif Global.ravine_handoff_ready():
			next_step.text = ("到南边竹径把三页交给蒲宁，可打开药圃和南路小径。" if Global.ravine_handoff_visit_today()
				else "到蒲宁的岗位交还三页，可打开药圃和南路小径。")
			_set_next_route("找蒲宁", has_guide)
		elif active >= 0:
			next_step.text = "从东关进竹涧，在竹涧舆图点「今日水迹」找立牌。"
			_set_next_route("指路去东关")
		else:
			next_step.text = "立牌明日会指向下一处。可在下方重读已记的水迹。"
			next_route.hide()
	_refresh_outing()

func _refresh_pages(active: int) -> void:
	for index in RavineJournal.SITES.size():
		var site: Dictionary = RavineJournal.SITES[index]
		var date: int = Global.ravine_journal.recorded_days[index]
		var card := pages.get_child(index) as PanelContainer
		card.add_theme_stylebox_override(&"panel", active_trace_frame if index == active else trace_frame)
		headings[index].add_theme_color_override(&"font_color",
			Color("#ffe3a8") if index == active else Color("#cad9b8"))
		if date > 0:
			var raining := Global.has_rain(date)
			headings[index].text = "%s · 第 %d 天 · %s · %s" % [
				site.name, date, Global.get_current_solar_term(date), Global.weather_label(date, true)]
			notes[index].text = site.rain if raining else site.dry
		else:
			headings[index].text = "%s · %s" % [site.name, "今日可记" if index == active else "待记"]
			notes[index].text = site.path

func _refresh_outing() -> void:
	var spent := Global.last_forage_day == Global.current_day
	outing_status.text = "今日采集已用。水迹另记。" if spent else "每日可采一处。水迹另记。"
	for index in OUTINGS.size():
		forage_notes[index].visible = not spent
		if not spent:
			forage_notes[index].text = Global.ravine_place_detail(OUTINGS[index])
		forage_routes[index].disabled = spent

func _refresh_garden() -> void:
	var wait := Global.herb_garden_wait()
	%GardenArt.texture = garden_art[0 if wait > 0 else 1]
	if wait > 0:
		garden.text = "新叶还需 %d 夜" % wait
		return
	var healing := mini(Global.balance.wild_herb_healing, Global.balance.player_max_health - Global.health)
	garden.text = "草药已长成 · 取用后气血 +%d" % healing if healing > 0 else "草药已长成 · 可留到受伤时"

func _set_next_route(label: String, available := true) -> void:
	next_route.text = label
	next_route.visible = available

func _guide_next_step() -> void:
	if Global.ravine_shortcut_open():
		GameEvents.ravine_journal_directions_requested.emit("药圃")
	elif not Global.knows_ravine_journal() or Global.ravine_handoff_ready():
		GameEvents.neighbor_directions_requested.emit(VisitorData.RAVINE_GUIDE)
	elif Global.ravine_site_today() >= 0:
		GameEvents.ravine_journal_directions_requested.emit("东关")
