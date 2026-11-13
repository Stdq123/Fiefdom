extends VBoxContainer

var progress: Label
var pages: VBoxContainer
var headings: Array[Label] = []
var notes: Array[Label] = []
var garden: Label

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "竹涧溪行手记"
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)
	progress = Label.new()
	progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(progress)

	pages = VBoxContainer.new()
	pages.add_theme_constant_override("separation", 8)
	add_child(pages)
	for site in RavineJournal.SITES:
		var card := PanelContainer.new()
		pages.add_child(card)
		var content := VBoxContainer.new()
		card.add_child(content)
		var heading := Label.new()
		heading.text = site.name
		content.add_child(heading)
		headings.append(heading)
		var note := Label.new()
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 15)
		content.add_child(note)
		notes.append(note)
	garden = Label.new()
	garden.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	garden.add_theme_color_override("font_color", Color("#b8d196"))
	add_child(garden)

	visibility_changed.connect(_refresh)
	GameEvents.ravine_journal_changed.connect(_refresh)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	_refresh()

func _refresh() -> void:
	var known := Global.knows_ravine_journal()
	pages.visible = known
	garden.visible = Global.ravine_journal.garden_day > 0
	if not known:
		progress.text = "沿南边竹径遇见蒲宁时，与他交谈。他会托你记下竹涧的三处水迹。"
		return

	progress.text = Global.ravine_status()
	var active := Global.ravine_site_today()
	for index in RavineJournal.SITES.size():
		var site: Dictionary = RavineJournal.SITES[index]
		var date: int = Global.ravine_journal.recorded_days[index]
		if date > 0:
			headings[index].text = "%s · 第 %d 天 · %s" % [site.name, date, Global.get_current_solar_term(date)]
			notes[index].text = site.rain if Global.has_rain(date) else site.dry
		else:
			headings[index].text = "%s · %s" % [site.name, "今日可记" if index == active else "待记"]
			notes[index].text = site.path

	if garden.visible:
		var wait := Global.herb_garden_wait()
		garden.text = ("竹径东侧的药圃 · 新叶还需 %d 夜" % wait if wait > 0 else
			"竹径东侧的药圃 · 草药已长成，受伤时可取用。")
