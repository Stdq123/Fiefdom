extends VBoxContainer

const MARKET_OFFER := preload("res://scenes/FishMarketOffer.tscn")

@export var at_stall := false

var summary: Label
var receipt: Label
var market_offer: PanelContainer
var rows: Dictionary[String, Dictionary] = {}

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "竹涧溪鱼簿"
	title.add_theme_color_override("font_color", Color("#efd291"))
	title.add_theme_font_size_override("font_size", 25)
	title.visible = not at_stall
	add_child(title)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary)
	market_offer = MARKET_OFFER.instantiate()
	market_offer.at_stall = at_stall
	add_child(market_offer)
	for id: String in CreekFish.IDS:
		_add_fish_row(id)
	receipt = Label.new()
	receipt.add_theme_color_override("font_color", Color("#bfd59f"))
	receipt.hide()
	add_child(receipt)
	GameEvents.fish_changed.connect(_refresh)
	GameEvents.creek_trap_changed.connect(_refresh)
	GameEvents.forage_taken.connect(_refresh)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	visibility_changed.connect(_refresh)
	_refresh()

func clear_receipt() -> void:
	receipt.text = ""
	receipt.hide()

func _add_fish_row(id: String) -> void:
	var fish: Dictionary = CreekFish.SPECIES[id]
	var card := PanelContainer.new()
	add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = CreekFish.portrait(id)
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 18)
	text.add_child(label)
	var history := Label.new()
	history.add_theme_font_size_override("font_size", 14)
	history.add_theme_color_override("font_color", Color("#bcc8a5"))
	history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(history)
	var food := Button.new()
	food.text = "留作口粮 +%d" % fish.food
	food.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	food.custom_minimum_size.y = 36
	food.pressed.connect(_exchange.bind(id, true))
	row.add_child(food)
	var sell := Button.new()
	sell.text = "售出 · %d 铜钱" % fish.copper
	sell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sell.custom_minimum_size.y = 36
	sell.pressed.connect(_exchange.bind(id, false))
	row.add_child(sell)
	rows[id] = {"icon": icon, "label": label, "history": history, "food": food, "sell": sell}

func _refresh() -> void:
	market_offer.refresh()
	if not Global.knows_ravine_journal():
		summary.text = "先到南边竹径找蒲宁。他知道竹涧哪里可以抛竿。"
	else:
		var pool := CreekFish.at(CreekFish.Site.POOL, Global.season_index(), Global.has_rain())
		var shoal := CreekFish.at(CreekFish.Site.SHOAL, Global.season_index(), Global.has_rain())
		summary.text = "已记 %d/%d 种   ·   今日鱼情   柳湾：%s   砾滩：%s" % [Global.fish_collection.size(), CreekFish.IDS.size(),
			CreekFish.SPECIES[pool].name, CreekFish.SPECIES[shoal].name]
		var trap_site := Global.creek_trap_site()
		if trap_site >= 0:
			summary.text += "\n%s · %s" % [CreekTrap.PLACES[trap_site], Global.creek_trap_detail(trap_site)]
		elif Global.creek_traps_unlocked():
			summary.text += "\n柳湾、砾滩可用竹笼，带一份黍或菽出门。"
		elif Global.get_current_year() >= 2:
			summary.text += "\n钓到第一尾鱼后，两岸的笼桩就能使用。"
	for id: String in CreekFish.IDS:
		var row: Dictionary = rows[id]
		var fish: Dictionary = CreekFish.SPECIES[id]
		var record: Dictionary = Global.fish_collection.get(id, {})
		var count := Global.fish_count(id)
		row.label.text = "%s   ·   鱼篓 %d 尾" % [fish.name, count]
		row.history.text = fish.habitat if record.is_empty() else "首获 · 第 %d 天 · %s · %s" % [record.first_day,
			Global.get_current_solar_term(record.first_day), CreekFish.PLACES[record.first_site]]
		row.icon.modulate = Color(0.63, 0.68, 0.65) if record.is_empty() else Color.WHITE
		row.food.disabled = count == 0
		row.sell.disabled = count == 0

func _exchange(id: String, for_food: bool) -> void:
	if not Global.exchange_creek_fish(id, for_food):
		return
	var fish: Dictionary = CreekFish.SPECIES[id]
	receipt.text = ("%s留作口粮 · 粮食 +%d" % [fish.name, fish.food] if for_food
		else "已售一尾%s · 铜钱 +%d" % [fish.name, fish.copper])
	receipt.show()
