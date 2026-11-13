extends VBoxContainer

signal silk_requested

const READY_INK := Color("#b8d29a")
const WAIT_INK := Color("#e3c289")

@export var at_market := false

@onready var order_title: Label = $Current/Content/Heading/Name
@onready var deadline: Label = $Current/Content/Heading/Deadline
@onready var request: Label = $Current/Content/Request
@onready var cargo: HBoxContainer = $Current/Content/Cargo
@onready var status: Label = $Current/Content/State
@onready var copper_button: Button = $Current/Content/Rewards/Copper
@onready var food_button: Button = $Current/Content/Rewards/Food
@onready var pin_button: Button = $Current/Content/Actions/Pin
@onready var fish_route_button: Button = $Current/Content/Actions/FishRoute
@onready var produce_route_button: Button = $Current/Content/Actions/ProduceRoute
@onready var silk_button: Button = $Current/Content/Actions/Silk
@onready var next_heading: Label = $Next/Content/HeadingRow/Heading
@onready var next_plan_button: Button = $Next/Content/HeadingRow/Plan
@onready var next_silk_button: Button = $Next/Content/HeadingRow/Silk
@onready var next_details: Label = $Next/Content/Details
@onready var last_receipt: Label = $LastReceipt

var start_day := 0
var fish_route_target := ""

func _ready() -> void:
	$Title.visible = not at_market
	copper_button.pressed.connect(_deliver.bind(false))
	food_button.pressed.connect(_deliver.bind(true))
	pin_button.toggled.connect(Global.pin_season_order)
	next_plan_button.toggled.connect(Global.pin_season_order.bind(true))
	fish_route_button.pressed.connect(func(): GameEvents.ravine_trip_requested.emit(fish_route_target))
	produce_route_button.pressed.connect(GameEvents.west_market_directions_requested.emit.bind(MarketStall.TITLES[MarketStall.Kind.GRAIN]))
	silk_button.pressed.connect(silk_requested.emit)
	next_silk_button.pressed.connect(silk_requested.emit)
	visibility_changed.connect(_refresh)
	GameEvents.season_order_pin_changed.connect(_refresh)
	GameEvents.daylight_changed.connect(_refresh)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.inventory_changed.connect(_refresh.unbind(1))
	GameEvents.money_changed.connect(_refresh.unbind(1))
	GameEvents.crop_harvested.connect(_refresh.unbind(1))
	GameEvents.fish_changed.connect(_refresh)
	GameEvents.stamina_changed.connect(_refresh.unbind(1))
	GameEvents.silk_changed.connect(_refresh)
	GameEvents.campaign_ended.connect(_refresh.unbind(1))
	_refresh()

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
	deadline.text = ("第 %d 天截止 · 余 %d 天" % [schedule.end, schedule.end - Global.current_day + 1]
		if delivered_on == 0 else "第 %d–%d 天" % [schedule.start, schedule.end])
	request.text = "%s托付    %s" % [order.speaker, order.request] if delivered_on == 0 else order.thanks
	copper_button.text = "交货 · 领 %d 铜钱" % rewards.copper
	food_button.text = "交货 · 领 %d 口粮" % rewards.food
	copper_button.disabled = not ready
	food_button.disabled = not ready
	copper_button.get_parent().visible = delivered_on == 0
	pin_button.visible = delivered_on == 0 and Global.outcome == Global.Outcome.RUNNING
	var pinned := Global.is_season_order_pinned(schedule)
	pin_button.set_pressed_no_signal(pinned)
	pin_button.text = "取消田边跟踪" if pinned else "在田边跟踪此单"
	_refresh_produce_route(order)
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
	_show_cargo(SeasonOrders.cargo(order), delivered_on > 0)

	var receipt: Dictionary = Global.season_order_receipts.get(order.id, {})
	if delivered_on > 0:
		var travel := SeasonOrders.transit_progress(receipt, Global.current_day, Global.day_progress)
		var delivery := SeasonOrders.dispatch_caption(receipt) if travel < 0.0 else (
			"正在运往南路卸货场" if travel < 1.0 else "已送到南路卸货场")
		if order.id == SeasonOrders.WATCH_RELIEF and travel >= 1.0:
			delivery = "巡人 · 正送往东路岗" if Global.watch_relief_progress() < 1.0 else "东路岗 · 巡粮与新旗绳已到"
		else:
			delivery = "申禾 · " + delivery
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
		status.text = _preparation_notes(schedule)
	if delivered_on == 0 and not fish.is_empty() and Global.fish_count(fish) == 1:
		var offer := Global.fish_market_offer()
		if offer.fish == fish and offer.receipt.is_empty():
			var warning := "交出这尾%s后，鱼摊留鱼单会缺鱼。" % CreekFish.SPECIES[fish].name
			status.text = warning if status.text.is_empty() else status.text + "\n" + warning
	status.add_theme_color_override("font_color", READY_INK if ready or delivered_on > 0 else WAIT_INK)
	var upcoming := Global.season_order(schedule.end + 1)
	next_heading.text = "下季预告 · 第 %d–%d 天" % [upcoming.start, upcoming.end]
	next_details.text = "%s · %s   可留 %s" % [
		upcoming.order.speaker, upcoming.order.title, ItemManager.describe_season_order_progress(upcoming)]
	if upcoming.order.need.has("rice"):
		next_details.text += " · 稻须接通水渠"
	var planning := Global.is_season_order_pinned(upcoming)
	next_plan_button.set_pressed_no_signal(planning)
	next_plan_button.text = "取消下季备货" if planning else "跟踪下季备货"
	next_plan_button.visible = Global.outcome == Global.Outcome.RUNNING
	next_silk_button.visible = next_plan_button.visible and not at_market \
		and int(upcoming.order.get("silk", 0)) > Global.season_order_stock_for(upcoming, SeasonOrders.SILK_ITEM)
	last_receipt.visible = delivered_on == 0 and not receipt.is_empty()
	if last_receipt.visible:
		last_receipt.text = "上次这张单在第 %d 天交齐。" % receipt.day

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

func _preparation_notes(schedule: Dictionary) -> String:
	var planted: Dictionary[String, Vector2i] = {}
	for cell: Vector2i in Global.active_crops:
		var crop: Dictionary = Global.active_crops[cell]
		if not Global.is_public_plot(cell) and schedule.order.need.has(crop.id):
			var growth := Vector2i(1, 0) if crop.age >= crop.growth_nights else Vector2i(0, 1)
			planted[crop.id] = planted.get(crop.id, Vector2i.ZERO) + growth
	var notes := PackedStringArray()
	for id: String in schedule.order.need:
		var missing: int = schedule.order.need[id] - Global.crop_stock.count(id)
		if missing <= 0:
			continue
		var crop := ItemManager.get_crop(id)
		var harvest_day := Global.current_day + Global.sowing_nights(crop)
		var line := "%s 缺 %d 份" % [crop.crop_name, missing]
		var plots: Vector2i = planted.get(id, Vector2i.ZERO)
		if plots.x > 0:
			line += " · 私田有 %d 格已熟" % plots.x
		if plots.y > 0:
			line += " · 私田 %d 格未熟" % plots.y
		line += (" · 今日播种最早第 %d 天收" % harvest_day
			if harvest_day <= schedule.end else " · 今日新播已赶不上本季")
		if crop.is_water_crop:
			line += " · 需渠水"
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

func _show_cargo(needs: Dictionary, delivered: bool) -> void:
	for child in cargo.get_children():
		cargo.remove_child(child)
		child.queue_free()
	for id in needs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		cargo.add_child(row)
		var picture := ItemManager.season_item_picture(id)
		var icon := TextureRect.new()
		icon.texture = picture.texture
		icon.self_modulate = picture.tint
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(32, 32)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var stock := Global.season_order_stock(id)
		var name := ItemManager.season_item_label(id)
		var label := Label.new()
		label.text = "%s 已交 %d" % [name, needs[id]] if delivered else "%s  %d/%d" % [name, stock, needs[id]]
		label.add_theme_color_override("font_color", READY_INK if delivered or stock >= needs[id] else WAIT_INK)
		row.add_child(label)

func _deliver(paid_in_food: bool) -> void:
	if Global.deliver_season_order(start_day, paid_in_food):
		AudioManager.play_ui_sfx(1.12)
	else:
		_refresh()
