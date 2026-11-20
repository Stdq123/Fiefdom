extends VBoxContainer

const MARKET_OFFER := preload("res://scenes/FishMarketOffer.tscn")
const FISH_ENTRY := preload("res://scenes/FishLedgerEntry.tscn")
const SITE_CARD := preload("res://scenes/FishingSiteCard.tscn")

@export var at_stall := false

@onready var summary: Label = %Summary
@onready var readiness: Label = %Readiness
@onready var teacher_route: Button = %FindTeacher
@onready var receipt: Label = %Receipt
@onready var reading: ScrollContainer = %Reading

var world: Node2D
var market_offer: PanelContainer
var rows: Dictionary[String, Dictionary] = {}
var sites: Array[Dictionary] = []
var trap_card: Dictionary = {}

func _ready() -> void:
	%Title.visible = not at_stall
	$Forecast.visible = not at_stall
	for control: Control in [%Title, summary, %Waters, readiness, teacher_route, receipt]:
		InterfaceFont.scale_reading_text(control)
	var body := VBoxContainer.new()
	body.name = "Contents"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 9)
	if at_stall:
		reading.hide()
		add_child(body)
		move_child(receipt, -1)
	else:
		reading.add_child(body)
		var scrollbar := reading.get_v_scroll_bar()
		scrollbar.theme_type_variation = &"HudJournalBar"
		scrollbar.focus_mode = Control.FOCUS_ALL
		world = get_tree().current_scene.get_node("World")
		world.visitor_changed.connect(_refresh.unbind(1))
		teacher_route.pressed.connect(GameEvents.neighbor_directions_requested.emit.bind(VisitorData.RAVINE_GUIDE))
		for site in CreekFish.PLACES.size():
			var card := _add_site_card(%Sites)
			card.title.text = CreekFish.PLACES[site]
			card.route.accessibility_name = "指路去" + CreekFish.PLACES[site]
			card.route.pressed.connect(_follow_site.bind(site))
			sites.append(card)

	market_offer = MARKET_OFFER.instantiate()
	market_offer.at_stall = at_stall
	body.add_child(market_offer)
	var collection := GridContainer.new()
	collection.columns = 1 if at_stall else 2
	collection.add_theme_constant_override(&"h_separation", 9)
	collection.add_theme_constant_override(&"v_separation", 9)
	body.add_child(collection)
	for id: String in CreekFish.IDS:
		_add_fish_entry(collection, id)
	if not at_stall:
		trap_card = _add_site_card(body)
		trap_card.icon.texture = CreekTrap.icon()
		trap_card.route.pressed.connect(_follow_trap)

	GameEvents.fish_changed.connect(_refresh)
	GameEvents.creek_trap_changed.connect(_refresh)
	GameEvents.pond_landing_opened.connect(_refresh)
	GameEvents.ravine_journal_changed.connect(_refresh)
	GameEvents.stamina_changed.connect(_refresh.unbind(1))
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.campaign_ended.connect(_refresh.unbind(1))
	visibility_changed.connect(_refresh)
	_refresh()

func clear_receipt() -> void:
	receipt.text = ""
	receipt.hide()

func _add_fish_entry(collection: GridContainer, id: String) -> void:
	var fish: Dictionary = CreekFish.SPECIES[id]
	var card := FISH_ENTRY.instantiate() as PanelContainer
	collection.add_child(card)
	var icon := card.get_node("%Icon") as TextureRect
	icon.texture = CreekFish.portrait(id)
	var name_and_stock := card.get_node("%NameAndStock") as Label
	var history := card.get_node("%History") as Label
	var commitment := card.get_node("%Commitment") as Label
	var food := card.get_node("%Food") as Button
	var sell := card.get_node("%Sell") as Button
	food.text = "留 1 尾 · 口粮 +%d" % fish.food
	sell.text = "售 1 尾 · +%d 铜钱" % fish.copper
	food.accessibility_name = "%s · %s" % [fish.name, food.text]
	sell.accessibility_name = "%s · %s" % [fish.name, sell.text]
	food.pressed.connect(_exchange.bind(id, true))
	sell.pressed.connect(_exchange.bind(id, false))
	for control: Control in [name_and_stock, history, commitment, food, sell]:
		InterfaceFont.scale_reading_text(control)
	rows[id] = {"card": card, "icon": icon, "label": name_and_stock, "history": history,
		"commitment": commitment, "food": food, "sell": sell}

func _add_site_card(parent: Container) -> Dictionary:
	var card := SITE_CARD.instantiate() as PanelContainer
	parent.add_child(card)
	var title := card.get_node("%Place") as Label
	var note := card.get_node("%Note") as Label
	var route := card.get_node("%Route") as Button
	for control: Control in [title, note, route]:
		InterfaceFont.scale_reading_text(control)
	return {"card": card, "title": title, "note": note, "icon": card.get_node("%Icon"), "route": route}

func _refresh() -> void:
	if not is_visible_in_tree():
		return
	var total := 0
	var offer := Global.fish_market_offer()
	var schedule := Global.season_order()
	var open_order := Global.season_order_delivered_at(schedule) == 0
	for id: String in CreekFish.IDS:
		var row: Dictionary = rows[id]
		var fish: Dictionary = CreekFish.SPECIES[id]
		var record: Dictionary = Global.fish_collection.get(id, {})
		var count := Global.fish_count(id)
		total += count
		row.label.text = "%s · 鱼篓 %d 尾" % [fish.name, count]
		row.history.text = "未记 · " + fish.habitat if record.is_empty() else "首获 · 第 %d 天 · %s · %s" % [
			record.first_day, Global.get_current_solar_term(record.first_day), CreekFish.PLACES[record.first_site]]
		row.icon.modulate = Color(0.63, 0.68, 0.65) if record.is_empty() else Color.WHITE
		row.food.disabled = count == 0 or Global.outcome != Global.Outcome.RUNNING
		row.sell.disabled = row.food.disabled
		var claims := PackedStringArray()
		if count > 0 and Global.outcome == Global.Outcome.RUNNING:
			if offer.receipt.is_empty() and offer.fish == id:
				claims.append("「渔生留鱼」")
			if open_order and schedule.order.get("fish", "") == id:
				claims.append("「%s」" % schedule.order.title)
		row.commitment.visible = count > 0 and count <= claims.size()
		if row.commitment.visible:
			var orders := "和".join(claims)
			row.commitment.text = ("最后一尾 · %s会用到这尾鱼" % orders if count == 1
				else "%s各需一尾。留粮或出售后余 1 尾。" % orders)

	summary.text = "已记 %d/%d 种 · 鱼篓共 %d 尾" % [Global.fish_collection.size(), CreekFish.IDS.size(), total]
	market_offer.refresh()
	var known := Global.knows_ravine_journal()
	var pond := Global.pond_landing_day() > 0
	if at_stall:
		_refresh_counter_forecast(known, pond)
	else:
		_refresh_forecast(known, pond)
		_refresh_trap(known)

func _refresh_counter_forecast(known: bool, pond: bool) -> void:
	var water := PackedStringArray()
	for site in CreekFish.PLACES.size():
		var accessible := pond if site == CreekFish.Site.POND else known
		if accessible:
			water.append("%s %s" % [CreekFish.PLACES[site], CreekFish.SPECIES[Global.fish_at_today(site)].name])
	if not water.is_empty():
		summary.text += "\n今日鱼情 · " + " · ".join(water)
	if not known:
		summary.text += "\n到南边竹径找蒲宁学钓。"
	var trap_site := Global.creek_trap_site()
	if trap_site >= 0:
		summary.text += "\n%s · %s" % [CreekTrap.PLACES[trap_site], Global.creek_trap_detail(trap_site)]

func _refresh_forecast(known: bool, pond: bool) -> void:
	var detail := "抛竿耗 %d 体力" % Global.balance.fishing_stamina_cost
	if Global.outcome != Global.Outcome.RUNNING:
		detail = "本局已结算"
	elif known or pond:
		var reason := Global.fishing_block_reason(false, CreekFish.Site.POOL if known else CreekFish.Site.POND)
		if not reason.is_empty():
			detail = reason
		else:
			detail = "今日可垂钓 · " + detail
	else:
		detail = "到南边竹径找蒲宁学钓"
	if pond and not known and Global.outcome == Global.Outcome.RUNNING:
		detail += " · 竹涧须先找蒲宁"
	readiness.text = "第 %d 天 · %s · %s · %s" % [Global.current_day, Global.get_current_solar_term(),
		Global.weather_label(0, true), detail]
	teacher_route.visible = not known and Global.outcome == Global.Outcome.RUNNING \
		and is_instance_valid(world.neighbor_actor(VisitorData.RAVINE_GUIDE))
	for site in sites.size():
		var card := sites[site]
		var open := pond if site == CreekFish.Site.POND else known
		var reason := Global.fishing_block_reason(false, site)
		var fish := Global.fish_at_today(site)
		card.note.text = CreekFish.SPECIES[fish].name if open else Global.fishing_block_reason(true, site)
		card.icon.texture = rows[fish].icon.texture if open else HUDIcons.icon(HUDIcons.Symbol.MAP)
		card.route.visible = open and Global.outcome == Global.Outcome.RUNNING
		card.route.disabled = not reason.is_empty()
		card.route.tooltip_text = reason

func _refresh_trap(known: bool) -> void:
	var deployed := Global.creek_trap_site()
	trap_card.card.visible = known and (deployed >= 0 or Global.get_current_year() >= 2)
	if not trap_card.card.visible:
		return
	trap_card.route.visible = deployed >= 0 and Global.outcome == Global.Outcome.RUNNING
	trap_card.route.text = "指路去竹笼"
	if deployed >= 0:
		trap_card.title.text = CreekTrap.PLACES[deployed]
		trap_card.note.text = Global.creek_trap_detail(deployed)
	else:
		trap_card.title.text = "两岸竹笼"
		trap_card.note.text = ("柳湾和砾滩可用竹笼，带一份黍或菽作饵。" if Global.creek_traps_unlocked()
			else "钓到第一尾鱼后，可使用两岸的笼桩。")

func _follow_site(site: int) -> void:
	if Global.outcome != Global.Outcome.RUNNING or not Global.fishing_block_reason(false, site).is_empty():
		return
	if site == CreekFish.Site.POND:
		GameEvents.pond_landing_directions_requested.emit()
	else:
		GameEvents.ravine_trip_requested.emit(CreekFish.PLACES[site])

func _follow_trap() -> void:
	var deployed := Global.creek_trap_site()
	if deployed >= 0 and Global.outcome == Global.Outcome.RUNNING:
		GameEvents.ravine_trip_requested.emit(CreekTrap.PLACES[deployed])

func _exchange(id: String, for_food: bool) -> void:
	if not Global.exchange_creek_fish(id, for_food):
		return
	var fish: Dictionary = CreekFish.SPECIES[id]
	receipt.text = ("%s留作口粮 · 粮食 +%d" % [fish.name, fish.food] if for_food
		else "已售一尾%s · 铜钱 +%d" % [fish.name, fish.copper])
	receipt.show()
	AudioManager.play_trade_cue(AudioManager.TradeCue.STORE_FOOD if for_food else AudioManager.TradeCue.SALE)
