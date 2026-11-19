extends VBoxContainer

signal silk_requested

const READY_INK := Color("#b8d29a")
const WAIT_INK := Color("#e3c289")
const CARGO_SLIP := preload("res://scenes/SeasonOrderCargo.tscn")
const CROP_PROGRESS := {
	Global.NightGrowth.READY: "%d 格已熟",
	Global.NightGrowth.RIPEN: "%d 格明日熟",
	Global.NightGrowth.DRY: "%d 格待浇",
	Global.NightGrowth.BLOCKED: "%d 格断水",
	Global.NightGrowth.GROW: "%d 格生长中",
}

@export var at_market := false

@onready var header: PanelContainer = $Header
@onready var order_title: Label = $Header/Row/Heading/Name
@onready var deadline: Label = $Header/Row/Heading/Deadline
@onready var order_route: Button = $Header/Row/OrderRoute
@onready var current_bookmark: Button = $Header/Row/CurrentPage
@onready var next_bookmark: Button = $Header/Row/NextPage
@onready var scroll: ScrollContainer = $Scroll
@onready var pages: VBoxContainer = $Scroll/Pages
@onready var request: Label = $Scroll/Pages/Current/Content/Request
@onready var cargo: HBoxContainer = $Scroll/Pages/Current/Content/Cargo
@onready var status: Label = $Scroll/Pages/Current/Content/State
@onready var copper_button: Button = $Scroll/Pages/Current/Content/Rewards/Copper
@onready var food_button: Button = $Scroll/Pages/Current/Content/Rewards/Food
@onready var pin_button: Button = $Scroll/Pages/Current/Content/Actions/Pin
@onready var field_work_button: Button = $Scroll/Pages/Current/Content/FieldActions/FieldWork
@onready var steward_work: Button = $Scroll/Pages/Current/Content/FieldActions/StewardWork
@onready var fish_route_button: Button = $Scroll/Pages/Current/Content/Actions/FishRoute
@onready var produce_route_button: Button = $Scroll/Pages/Current/Content/Actions/ProduceRoute
@onready var water_route_button: Button = $Scroll/Pages/Current/Content/Actions/WaterRoute
@onready var silk_button: Button = $Scroll/Pages/Current/Content/Actions/Silk
@onready var freight_route: Button = $Scroll/Pages/Current/Content/Actions/FreightRoute
@onready var next_sheet: PanelContainer = $Scroll/Pages/Next
@onready var next_heading: Label = $Scroll/Pages/Next/Content/Heading
@onready var next_cargo: HBoxContainer = $Scroll/Pages/Next/Content/Cargo
@onready var next_plan_button: Button = $Scroll/Pages/Next/Content/Actions/Plan
@onready var next_silk_button: Button = $Scroll/Pages/Next/Content/Actions/Silk
@onready var next_water_button: Button = $Scroll/Pages/Next/Content/Actions/WaterRoute
@onready var next_details: Label = $Scroll/Pages/Next/Content/Details
@onready var next_field_work_button: Button = $Scroll/Pages/Next/Content/FieldActions/FieldWork
@onready var next_steward_work: Button = $Scroll/Pages/Next/Content/FieldActions/StewardWork
@onready var last_receipt: Label = $Scroll/Pages/LastReceipt

var start_day := 0
var fish_route_target := ""
var market_book_height := 0.0

func _ready() -> void:
	for action: Button in [pin_button, field_work_button, steward_work, fish_route_button, produce_route_button,
		water_route_button, silk_button, freight_route, next_plan_button, next_silk_button, next_water_button,
		next_field_work_button, next_steward_work]:
		action.theme_type_variation = &"HudButton"
	for control: Control in [order_title, deadline, request, status, next_heading, next_details, last_receipt,
		copper_button, food_button, order_route, current_bookmark, next_bookmark, pin_button, field_work_button,
		steward_work, fish_route_button, produce_route_button, water_route_button, silk_button, freight_route,
		next_plan_button, next_silk_button, next_water_button, next_field_work_button, next_steward_work]:
		InterfaceFont.scale_reading_text(control)
	var scrollbar := scroll.get_v_scroll_bar()
	scrollbar.theme_type_variation = &"HudJournalBar"
	scrollbar.focus_mode = FOCUS_ALL
	copper_button.icon = HUDIcons.icon(HUDIcons.Symbol.COIN)
	food_button.icon = HUDIcons.icon(HUDIcons.Symbol.RATIONS)
	order_route.icon = HUDIcons.icon(HUDIcons.Symbol.MAP)
	order_route.add_theme_constant_override(&"icon_max_width", 18)
	if at_market:
		pages.minimum_size_changed.connect(_fit_market_book, CONNECT_DEFERRED)
		header.minimum_size_changed.connect(_fit_market_book, CONNECT_DEFERRED)
	order_route.pressed.connect(GameEvents.west_market_directions_requested.emit.bind(Global.MARKET_ORDERS))
	current_bookmark.pressed.connect(scroll.set.bind(&"scroll_vertical", 0))
	next_bookmark.pressed.connect(open_forecast)
	copper_button.pressed.connect(_deliver.bind(false))
	food_button.pressed.connect(_deliver.bind(true))
	pin_button.toggled.connect(Global.pin_season_order)
	field_work_button.pressed.connect(GameEvents.season_order_work_requested.emit.bind(false))
	next_field_work_button.pressed.connect(GameEvents.season_order_work_requested.emit.bind(true))
	steward_work.pressed.connect(_assign_steward_work.bind(false))
	next_steward_work.pressed.connect(_assign_steward_work.bind(true))
	next_plan_button.toggled.connect(Global.pin_season_order.bind(true))
	fish_route_button.pressed.connect(func(): GameEvents.ravine_trip_requested.emit(fish_route_target))
	produce_route_button.pressed.connect(GameEvents.west_market_directions_requested.emit.bind(MarketStall.TITLES[MarketStall.Kind.GRAIN]))
	water_route_button.pressed.connect(_follow_water_source)
	next_water_button.pressed.connect(_follow_water_source.bind(true))
	silk_button.pressed.connect(silk_requested.emit)
	freight_route.pressed.connect(GameEvents.west_market_directions_requested.emit.bind(Global.FREIGHT_YARD))
	next_silk_button.pressed.connect(silk_requested.emit)
	visibility_changed.connect(_open_book)
	GameEvents.season_order_pin_changed.connect(_refresh)
	GameEvents.daylight_changed.connect(_refresh)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.inventory_changed.connect(_refresh.unbind(1))
	GameEvents.money_changed.connect(_refresh.unbind(1))
	GameEvents.crop_harvested.connect(_refresh.unbind(1))
	GameEvents.farm_state_changed.connect(_refresh)
	GameEvents.channels_changed.connect(_refresh)
	GameEvents.tax_reform_choice_made.connect(_refresh.unbind(1))
	GameEvents.fish_changed.connect(_refresh)
	GameEvents.stamina_changed.connect(_refresh.unbind(1))
	GameEvents.silk_changed.connect(_refresh)
	GameEvents.retainer_assigned.connect(_refresh.unbind(2))
	GameEvents.retainer_duty_changed.connect(_refresh.unbind(1))
	GameEvents.retainer_departed.connect(_refresh.unbind(1))
	GameEvents.campaign_ended.connect(_refresh.unbind(1))
	_open_book()

func _open_book() -> void:
	if is_visible_in_tree():
		scroll.scroll_vertical = 0
		_refresh()
		if at_market:
			_fit_market_book()

func open_forecast() -> void:
	await get_tree().process_frame
	if not is_visible_in_tree():
		return
	scroll.scroll_vertical = roundi(next_sheet.position.y)
	if next_plan_button.is_visible_in_tree():
		next_plan_button.grab_focus()
		GamepadInput.snap_pointer_to_focus.call_deferred()

func fit_market_book(available: float) -> void:
	market_book_height = available
	_fit_market_book()

func _fit_market_book() -> void:
	if not is_visible_in_tree():
		return
	var available := maxf(0.0, market_book_height - header.get_combined_minimum_size().y - get_theme_constant(&"separation"))
	scroll.custom_minimum_size.y = minf(available, pages.get_combined_minimum_size().y)

func _refresh() -> void:
	if not is_visible_in_tree():
		return
	var schedule := Global.season_order()
	var order: Dictionary = schedule.order
	var delivered_on := Global.season_order_delivered_at(schedule)
	var ready := Global.can_deliver_season_order(schedule)
	var rewards := Global.season_order_rewards(schedule)
	start_day = schedule.start
	order_title.text = "%s单 · %s" % [Global.SEASON_NAMES[Global.season_index()], order.title]
	var days_left: int = schedule.end - Global.current_day + 1
	deadline.text = ("第 %d 天截止 · 余 %d 天" % [schedule.end, days_left]
		if delivered_on == 0 else "第 %d–%d 天" % [schedule.start, schedule.end])
	if delivered_on == 0 and days_left <= 2:
		deadline.add_theme_color_override("font_color", WAIT_INK)
	else:
		deadline.remove_theme_color_override("font_color")
	request.text = "%s托付    %s" % [order.speaker, order.request] if delivered_on == 0 else order.thanks
	copper_button.text = "交货 · 领 %d 铜钱" % rewards.copper
	food_button.text = "交货 · 领 %d 口粮" % rewards.food
	copper_button.disabled = not ready
	food_button.disabled = not ready
	order_route.visible = ready and not at_market
	copper_button.get_parent().visible = delivered_on == 0
	pin_button.visible = delivered_on == 0 and Global.outcome == Global.Outcome.RUNNING
	var pinned := Global.is_season_order_pinned(schedule)
	pin_button.set_pressed_no_signal(pinned)
	pin_button.text = "取消田边跟踪" if pinned else "在田边跟踪此单"
	_refresh_field_work(field_work_button, schedule)
	_refresh_produce_route(order)
	var rice_water_gap := Global.rice_order_water_gap(schedule) if pin_button.visible else 0
	water_route_button.visible = rice_water_gap > 0
	silk_button.visible = not at_market and delivered_on == 0 and Global.outcome == Global.Outcome.RUNNING \
		and int(order.get("silk", 0)) > Global.silk_workshop.bolts
	var fish: String = order.get("fish", "")
	fish_route_target = Global.fishing_spot_today(fish) if not fish.is_empty() and Global.fish_count(fish) == 0 else ""
	fish_route_button.visible = (pin_button.visible and Global.knows_ravine_journal()
		and not fish_route_target.is_empty())
	if fish_route_button.visible:
		var reason := Global.fishing_block_reason()
		fish_route_button.text = "去%s钓%s" % [fish_route_target, CreekFish.SPECIES[fish].name]
		fish_route_button.disabled = not reason.is_empty()
		fish_route_button.tooltip_text = reason
	_show_cargo(cargo, schedule, delivered_on > 0)

	var receipt: Dictionary = Global.season_order_receipts.get(order.id, {})
	var freight: Dictionary = receipt if delivered_on > 0 and int(receipt.dispatch_day) >= Global.current_day else {}
	if freight.is_empty() and schedule.start == Global.current_day:
		freight = Global.pending_freight_receipt()
	freight_route.visible = Global.outcome == Global.Outcome.RUNNING and not freight.is_empty()
	if freight_route.visible:
		var arrived := SeasonOrders.transit_progress(freight, Global.current_day, Global.day_progress) >= 1.0
		freight_route.text = "货已到 · 去卸货场" if arrived else "指路去卸货场"
		freight_route.tooltip_text = "到卸货场找申禾" if arrived else SeasonOrders.arrival_caption(freight)
		if delivered_on == 0:
			freight_route.text = "上一季货车 · 去卸货场"
	if delivered_on > 0:
		var travel := SeasonOrders.transit_progress(receipt, Global.current_day, Global.day_progress)
		var delivery := SeasonOrders.dispatch_caption(receipt) if travel < 0.0 else (
			"正在运往南路卸货场" if travel < 1.0 else "已送到南路卸货场")
		if order.id == SeasonOrders.WATCH_RELIEF and travel >= 1.0:
			delivery = "巡人 · 正送往东路岗" if Global.watch_relief_progress() < 1.0 else "东路岗 · 巡粮与新旗绳已到"
		elif order.id in SeasonOrders.POND_ORDERS and travel >= 1.0:
			delivery = "已送到南路卸货场 · 南池西岸钓台已开放"
		elif order.id == SeasonOrders.WINTER_WOVEN_GOODS and travel >= 1.0:
			delivery = "阿绥 · 正送往南路亭" if Global.winter_road_rations_progress() < 1.0 else "亭前路粮案 · 麦与帛已到"
		else:
			delivery = "申禾 · " + delivery
		if travel < 1.0:
			delivery += " · " + SeasonOrders.arrival_caption(receipt)
		status.text = "第 %d 天已交 · 已领%s\n%s" % [
			delivered_on, "口粮" if receipt.paid_in_food else "铜钱", delivery]
		if (Global.get_current_year() == Global.TAX_COUNCIL_YEAR - 1
			and Global.tax_reform_choice == Global.TaxReformChoice.NONE and not Global.tax_council_waiting()):
			var required := Global.TAX_COUNCIL_PETITION_ORDERS
			status.text += "\n提前请议 · 本年已交 %d/%d 季 · 详见议税筹备账" % [
				mini(Global.tax_council_petition_order_count(), required), required]
	elif Global.outcome != Global.Outcome.RUNNING:
		status.text = "本局已经结算"
	elif ready:
		status.text = "已备齐 · 任选一种报酬，并记 %d 声望" % Global.balance.interaction_reputation_gain
		var silk: int = order.get("silk", 0)
		var target := Global.balance.ending_silk_target
		if silk > 0 and Global.silk_workshop.bolts - silk < target and Global.tax_reform_choice == Global.TaxReformChoice.NONE:
			status.text += "\n交货后余 %d 匹丝绸。议税两案都要备 %d 匹。" % [Global.silk_workshop.bolts - silk, target]
	else:
		status.text = _preparation_notes(schedule, rice_water_gap)
	if freight_route.visible and delivered_on == 0:
		var transit := SeasonOrders.transit_progress(freight, Global.current_day, Global.day_progress)
		var arrival := SeasonOrders.arrival_caption(freight) if transit < 1.0 else "已到南路卸货场"
		status.text += "\n上一季货车 · %s" % arrival
	if delivered_on == 0 and not fish.is_empty() and Global.fish_count(fish) == 1:
		var offer := Global.fish_market_offer()
		if offer.fish == fish and offer.receipt.is_empty():
			var warning := "交出这尾%s后，鱼摊留鱼单会缺鱼。" % CreekFish.SPECIES[fish].name
			status.text = warning if status.text.is_empty() else status.text + "\n" + warning
	var steward_note := _refresh_steward_work(steward_work, schedule)
	field_work_button.get_parent().visible = field_work_button.visible or steward_work.visible
	if not steward_note.is_empty():
		status.text += "\n" + steward_note
	status.add_theme_color_override("font_color", READY_INK if ready or delivered_on > 0 else WAIT_INK)
	var upcoming := Global.season_order(schedule.end + 1)
	next_heading.text = "下季 · %s · 第 %d–%d 天" % [upcoming.order.title, upcoming.start, upcoming.end]
	next_details.text = "%s托付    %s" % [upcoming.order.speaker, upcoming.order.request]
	_show_cargo(next_cargo, upcoming)
	var needs_next_water := Global.rice_order_water_gap(upcoming) > 0
	if needs_next_water:
		next_details.text += "\n备稻须接通水渠。"
	var planning := Global.is_season_order_pinned(upcoming)
	if planning:
		next_details.text += "\n已跟踪。夜间备粮会为下季留出所需作物。"
	next_plan_button.set_pressed_no_signal(planning)
	next_plan_button.text = "取消下季跟踪" if planning else "跟踪下季备货"
	next_plan_button.visible = Global.outcome == Global.Outcome.RUNNING
	next_water_button.visible = next_plan_button.visible and needs_next_water
	next_silk_button.visible = next_plan_button.visible and not at_market \
		and int(upcoming.order.get("silk", 0)) > Global.season_order_stock_for(upcoming, SeasonOrders.SILK_ITEM)
	_refresh_field_work(next_field_work_button, upcoming)
	var next_steward_note := _refresh_steward_work(next_steward_work, upcoming)
	next_field_work_button.get_parent().visible = next_field_work_button.visible or next_steward_work.visible
	if not next_steward_note.is_empty():
		next_details.text += "\n" + next_steward_note
	last_receipt.visible = delivered_on == 0 and not receipt.is_empty()
	if last_receipt.visible:
		last_receipt.text = "上次这张单在第 %d 天交齐。" % receipt.day

func _refresh_field_work(button: Button, schedule: Dictionary) -> void:
	var plan := Global.season_order_work(schedule) if not at_market else {}
	button.visible = not plan.is_empty()
	if not button.visible:
		return
	var label := ItemManager.crop_label(plan.crop_id)
	match int(plan.action):
		Global.OrderWork.HARVEST: button.text = "标出已熟的%s" % label
		Global.OrderWork.WATER: button.text = "标出待浇的%s" % label
		Global.OrderWork.SOW: button.text = "标出空私田 · 换%s种" % label
		Global.OrderWork.WAIT: button.text = "查看田里的%s" % label
	button.tooltip_text = "在田边跟踪此单，并标出一格私田。"
	if schedule.start > Global.current_day:
		if plan.action != Global.OrderWork.HARVEST:
			next_details.text += "\n%s最早第 %d 天可收。第 %d 天起可交货。" % [label, plan.day, schedule.start]
		button.tooltip_text += "\n第 %d 天起可交货。" % schedule.start

func _refresh_steward_work(button: Button, schedule: Dictionary) -> String:
	button.visible = false
	if at_market:
		return ""
	var offer := Global.steward_order_offer(schedule)
	if offer.queued > 0:
		button.visible = true
		button.text = "撤回未播 · %d 格" % offer.queued
		button.tooltip_text = "撤回本单还未播种的安排。已播的作物照常生长。"
		return ("管事备货待播 %d 格。" % offer.queued if offer.unstaffed == 0 else
			"备货待播 %d 格，其中 %d 格需要交接管事。" % [offer.queued, offer.unstaffed])
	if offer.plans.is_empty():
		return ""
	var crops := {}
	for id: String in offer.plans.values():
		crops[id] = crops.get(id, 0) + 1
	var items := PackedStringArray()
	for id: String in crops:
		items.append("%s %d 格" % [ItemManager.crop_label(id), crops[id]])
	button.visible = true
	button.text = "安排管事备货 · %d 格" % offer.plans.size()
	button.tooltip_text = "用管事白天的工时，只在可用私田种一茬。可在封地概览查看田格。"
	return "管事可备%s。若今天播种，预计第 %d 天可收完。" % ["、".join(items), offer.latest]

func _assign_steward_work(upcoming: bool) -> void:
	if at_market:
		return
	var schedule := Global.season_order()
	if upcoming:
		schedule = Global.season_order(schedule.end + 1)
	if Global.steward_order_offer(schedule).queued > 0:
		Global.cancel_order_sowing(schedule.start)
	else:
		Global.queue_steward_order_sowing(schedule)
	_refresh()
	GamepadInput.snap_pointer_to_focus.call_deferred()

func _refresh_produce_route(order: Dictionary) -> void:
	var crop := Global.market_produce_crop()
	var missing: int = order.need.get(crop, 0) - Global.crop_stock.count(crop)
	produce_route_button.visible = pin_button.visible and missing > 0 and Global.market_produce_available()
	if produce_route_button.visible:
		var price := Global.market_produce_price()
		var shortfall := price - Global.money
		produce_route_button.text = ("粮摊买一份%s · %d 铜钱" % [ItemManager.crop_label(crop), price] if shortfall <= 0
			else "粮摊有%s · 缺 %d 铜钱" % [ItemManager.crop_label(crop), shortfall])
		produce_route_button.disabled = shortfall > 0

func _follow_water_source(upcoming := false) -> void:
	Global.pin_season_order(true, upcoming)
	GameEvents.water_source_directions_requested.emit()

func _preparation_notes(schedule: Dictionary, rice_water_gap: int) -> String:
	var planted: Dictionary[String, Dictionary] = {}
	for cell: Vector2i in Global.active_crops:
		var crop: Dictionary = Global.active_crops[cell]
		if not Global.is_public_plot(cell) and schedule.order.need.has(crop.id):
			var growth := Global.crop_night_status(cell)
			var counts: Dictionary = planted.get_or_add(crop.id, {})
			counts[growth] = int(counts.get(growth, 0)) + 1
	var notes := PackedStringArray()
	for id: String in schedule.order.need:
		var missing := Global.season_order_crop_gap(schedule, id)
		if missing == 0:
			continue
		var crop := ItemManager.get_crop(id)
		var harvest_day := Global.current_day + Global.sowing_nights(crop)
		var line := "%s 缺 %d 份" % [crop.crop_name, missing]
		var fields := PackedStringArray()
		var counts: Dictionary = planted.get(id, {})
		for growth: int in CROP_PROGRESS:
			if counts.has(growth):
				fields.append(CROP_PROGRESS[growth] % counts[growth])
		if not fields.is_empty():
			line += " · 私田 " + "、".join(fields)
		if harvest_day > schedule.end:
			line += " · 今日新播已赶不上本季"
		elif crop.is_water_crop and rice_water_gap > 0:
			line += " · 通渠后播种，最快第 %d 天收" % harvest_day
		else:
			line += " · 今日播种最早第 %d 天收" % harvest_day
		notes.append(line)
	var fish: String = schedule.order.get("fish", "")
	if not fish.is_empty() and Global.fish_count(fish) == 0:
		var species: Dictionary = CreekFish.SPECIES[fish]
		var fishing_hint: String = species.habitat
		if not Global.knows_ravine_journal():
			fishing_hint = "先到南边竹径与蒲宁交谈"
		elif not fish_route_target.is_empty():
			fishing_hint = "今日在" + fish_route_target
			var blocked := Global.fishing_block_reason()
			if not blocked.is_empty():
				fishing_hint += " · " + blocked
		notes.append("%s 缺 1 尾 · %s" % [species.name, fishing_hint])
	var silk_needed: int = schedule.order.get("silk", 0) - Global.silk_workshop.bolts
	if silk_needed > 0:
		var workshop_hint := "在蚕棚养蚕、缫丝，再到织机织绸" if Global.silk_workshop.built else (
			"书达 %d 级后可在「管理 → 蚕桑」建蚕棚" % SilkWorkshop.LITERACY_LEVEL)
		notes.append("丝绸 缺 %d 匹 · %s" % [silk_needed, workshop_hint])
	return "\n".join(notes)

func _show_cargo(row: HBoxContainer, schedule: Dictionary, delivered := false) -> void:
	var needs := SeasonOrders.cargo(schedule.order)
	var ids := needs.keys()
	if row.get_meta(&"cargo_ids", []) != ids:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
		for id: String in ids:
			var slip := CARGO_SLIP.instantiate() as PanelContainer
			row.add_child(slip)
			var picture := ItemManager.season_item_picture(id)
			var icon: TextureRect = slip.get_node("Goods/Icon")
			icon.texture = picture.texture
			icon.self_modulate = picture.tint
			slip.get_node("Goods/Counts/ItemName").text = ItemManager.season_item_label(id)
			for label: Label in slip.get_node("Goods/Counts").get_children():
				InterfaceFont.scale_reading_text(label)
		row.set_meta(&"cargo_ids", ids)

	for index in ids.size():
		var id: String = ids[index]
		var slip := row.get_child(index) as PanelContainer
		var on_hand := Global.season_order_stock(id)
		var stock := Global.season_order_stock_for(schedule, id)
		var needed: int = needs[id]
		var unit := "份"
		if id == SeasonOrders.SILK_ITEM:
			unit = "匹"
		elif CreekFish.SPECIES.has(id):
			unit = "尾"
		var quantity: Label = slip.get_node("Goods/Counts/Quantity")
		if delivered:
			quantity.text = "已交 %d %s" % [needed, unit]
		elif stock >= needed:
			quantity.text = "已备齐 · %d/%d" % [needed, needed]
		else:
			quantity.text = "缺 %d %s · %d/%d" % [needed - stock, unit, stock, needed]
		quantity.add_theme_color_override("font_color", READY_INK if delivered or stock >= needed else WAIT_INK)
		var reservation: Label = slip.get_node("Goods/Counts/Reservation")
		reservation.visible = on_hand > stock
		if reservation.visible:
			reservation.text = "仓内 %d %s · 本季先留 %d %s" % [on_hand, unit, on_hand - stock, unit]
		slip.tooltip_text = "" if delivered else "库存 %d %s · 此单需 %d %s" % [on_hand, unit, needed, unit]
		if reservation.visible:
			slip.tooltip_text += "\n下季可留 %d %s" % [stock, unit]

func _deliver(paid_in_food: bool) -> void:
	if Global.deliver_season_order(start_day, paid_in_food):
		AudioManager.play_sfx(preload("res://assets/audio/freight/receipt.wav"), -10.0)
	else:
		_refresh()
