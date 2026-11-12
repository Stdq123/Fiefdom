extends VBoxContainer

enum ReserveKind { HOUSEHOLD, RECLAMATION }

const RESERVE_NIGHTS := 3
const SHORTAGE_COLOR := Color("#e5b981")

@export var at_stall := false

@onready var quantity: SpinBox = $QuantityRow/Quantity
@onready var all_crops: Button = $QuantityRow/AllCrops
@onready var crop_choice: OptionButton = $QuantityRow/CropChoice
@onready var stock_detail: Label = $StockDetail
@onready var fish_book_button: Button = $MarketHeader/FishBook
@onready var debit_plan: Label = $DebitPlan
@onready var grain_stock: Label = $Stock/Grain/Label
@onready var crop_stock: Label = $Stock/Crops/Label
@onready var copper_stock: Label = $Stock/Copper/Label
@onready var food_label: Label = $FoodLabel
@onready var sell_button: Button = $SellButton
@onready var convert_button: Button = $ConvertButton
@onready var buy_button: Button = $BuyFoodButton
@onready var reserve_kind: OptionButton = $ReserveKind
@onready var reserve_label: Label = $ReservePlan
@onready var reserve_button: Button = $ReserveActions/ReserveButton
@onready var survey_button: Button = $ReserveActions/ReturnToSurvey
@onready var receipt: Label = $Receipt

var return_to_survey: Callable

func _ready() -> void:
	crop_choice.add_item("全部")
	for id in CropStock.IDS:
		crop_choice.add_item(ItemManager.crop_label(id))
	crop_choice.item_selected.connect(_refresh_trade.unbind(1))
	quantity.value_changed.connect(_refresh_trade.unbind(1))
	$QuantityRow/Five.pressed.connect(func(): quantity.value = 5)
	all_crops.pressed.connect(func(): quantity.value = Global.crop_stock.count(_selected_crop()))
	sell_button.pressed.connect(_sell)
	convert_button.pressed.connect(_convert)
	buy_button.pressed.connect(_buy)
	reserve_kind.add_item("三夜口粮", ReserveKind.HOUSEHOLD)
	reserve_kind.add_item("开垦备粮", ReserveKind.RECLAMATION)
	reserve_kind.item_selected.connect(_refresh.unbind(1))
	reserve_button.pressed.connect(_reserve)
	survey_button.pressed.connect(func(): return_to_survey.call())
	$MarketHeader/NightRations.pressed.connect(GameEvents.night_rations_requested.emit)
	var grain_stall: String = MarketStall.TITLES[MarketStall.Kind.GRAIN]
	$MarketHeader/MarketDirections.pressed.connect(GameEvents.west_market_directions_requested.emit.bind(grain_stall))
	$MarketHeader.visible = not at_stall
	visibility_changed.connect(_on_visibility_changed)
	GameEvents.crop_harvested.connect(_refresh.unbind(1))
	GameEvents.inventory_changed.connect(_refresh.unbind(1))
	GameEvents.money_changed.connect(_refresh.unbind(1))
	GameEvents.food_changed.connect(_refresh.unbind(1))
	GameEvents.night_rations_changed.connect(_refresh)
	GameEvents.season_order_pin_changed.connect(_refresh)
	GameEvents.retainer_duty_changed.connect(_refresh.unbind(1))
	GameEvents.retainer_recruited.connect(_refresh.unbind(1))
	GameEvents.retainer_departed.connect(_refresh.unbind(1))
	GameEvents.rank_changed.connect(_refresh.unbind(1))
	GameEvents.day_advanced.connect(func(_day: int):
		receipt.text = ""
		_refresh()
	)
	_refresh()

func focus_crop_conversion() -> void:
	crop_choice.select(0)
	quantity.value = 1
	_refresh_trade()
	convert_button.grab_focus()

func show_reclamation_reserve(return_action: Callable) -> void:
	return_to_survey = return_action
	reserve_kind.select(ReserveKind.RECLAMATION)
	quantity.value = 1
	receipt.text = ""
	_refresh()
	if reserve_button.disabled:
		reserve_kind.grab_focus()
	else:
		reserve_button.grab_focus()

func _on_visibility_changed() -> void:
	if not is_visible_in_tree() and return_to_survey.is_valid():
		return_to_survey = Callable()
		reserve_kind.select(ReserveKind.HOUSEHOLD)
	_refresh()

func _refresh() -> void:
	fish_book_button.visible = Global.knows_ravine_journal() or not Global.fish_collection.is_empty()
	grain_stock.text = "粮仓\n%d 份" % Global.food_storage
	crop_stock.text = "私田作物\n%d 份" % Global.player_inventory
	copper_stock.text = "铜钱\n%d 枚" % Global.money
	var lots := ItemManager.describe_crops(Global.crop_stock.lots)
	stock_detail.text = "分仓   " + lots if not lots.is_empty() else "私田收成会按品种分仓。"
	crop_choice.set_item_text(0, "全部 · %d" % Global.player_inventory)
	for index in CropStock.IDS.size():
		var id: String = CropStock.IDS[index]
		crop_choice.set_item_text(index + 1, "%s · %d" % [ItemManager.crop_label(id), Global.crop_stock.count(id)])
	var tonight := Global.night_rations_plan()
	var nightly: int = tonight.need
	var supplement: int = tonight.converted + tonight.bought
	if nightly == 0:
		food_label.text = "暂无门客，今夜无需备粮。"
	elif supplement > 0:
		food_label.text = "每夜耗粮 %d · 今夜会自动补 %d 份" % [nightly, supplement]
		if tonight.served < nightly:
			food_label.text += " · 仍缺 %d 份" % (nightly - int(tonight.served))
	elif tonight.missing > 0:
		food_label.text = "每夜耗粮 %d · 今夜还差 %d 份" % [nightly, tonight.missing]
	else:
		food_label.text = "每夜耗粮 %d · 现有口粮可用 %d 夜" % [nightly, floori(float(Global.food_storage) / nightly)]
	if tonight.uncovered > 0:
		food_label.add_theme_color_override("font_color", SHORTAGE_COLOR)
	else:
		food_label.remove_theme_color_override("font_color")
	_refresh_trade()
	_refresh_reserve(nightly)

func _refresh_trade() -> void:
	var amount := int(quantity.value)
	var valid := amount > 0
	var crop_id := _selected_crop()
	var available := Global.crop_stock.count(crop_id)
	var label := "作物" if crop_id.is_empty() else ItemManager.crop_label(crop_id)
	var purchase := amount * Global.balance.market_food_price
	var copper_shortage := purchase - Global.money
	var crop_shortage := amount - available
	all_crops.disabled = available == 0
	convert_button.text = "作物转粮 · %d %s → %d 粮食" % [amount, label, amount]
	sell_button.text = "出售作物 · %d %s → %d 铜钱" % [amount, label, amount * Global.balance.market_crop_price]
	buy_button.text = "购买粮食 · %d 铜钱 → %d 粮食" % [purchase, amount]
	convert_button.disabled = not valid or crop_shortage > 0
	sell_button.disabled = convert_button.disabled
	buy_button.disabled = not valid or copper_shortage > 0
	var quantity_hint := "" if valid else "请输入至少 1 份"
	convert_button.tooltip_text = "还差 %d 份作物" % crop_shortage if crop_shortage > 0 else quantity_hint
	sell_button.tooltip_text = convert_button.tooltip_text
	buy_button.tooltip_text = "还差 %d 铜钱" % copper_shortage if copper_shortage > 0 else quantity_hint
	var use := Global.market_crop_plan(amount, crop_id)
	if not use.is_empty():
		debit_plan.text = "会取用   " + ItemManager.describe_crops(use) + _order_stock_note(use)
	else:
		debit_plan.text = "该品种还差 %d 份" % crop_shortage if crop_shortage > 0 else "选品种和数量，查看将用哪些作物。"

func _selected_crop() -> String:
	return CropStock.IDS[crop_choice.selected - 1] if crop_choice.selected > 0 else ""

func _order_stock_note(use: Dictionary) -> String:
	var schedule := Global.season_order()
	var current: Dictionary = schedule.order.need if Global.season_order_delivered_at(schedule) == 0 else {}
	var planned := Global.season_order_crops_to_keep()
	var uses_current := false
	var uses_upcoming := false
	for id in use:
		var stock := Global.crop_stock.count(id)
		var remainder: int = stock - use[id]
		var kept_now := mini(stock, int(current.get(id, 0)))
		var kept_total := mini(stock, int(planned.get(id, 0)))
		uses_current = uses_current or remainder < kept_now
		uses_upcoming = uses_upcoming or (kept_total > kept_now and remainder < kept_total)
	if uses_current and uses_upcoming:
		return " · 含本季和下季留货"
	if uses_upcoming:
		return " · 含下季留货"
	if uses_current:
		return " · 含本季交货作物"
	return ""

func _refresh_reserve(nightly: int) -> void:
	survey_button.visible = return_to_survey.is_valid()
	if reserve_kind.selected == ReserveKind.RECLAMATION:
		_refresh_reclamation_reserve()
		return
	var plan := Global.food_reserve_plan(RESERVE_NIGHTS)
	reserve_button.text = "按计划补粮"
	reserve_button.disabled = plan.food == 0 or plan.copper > Global.money
	if nightly == 0:
		reserve_label.text = "招募门客后，可按每夜粮耗备粮。"
	elif plan.food == 0:
		reserve_label.text = "粮仓已有三夜口粮。"
	else:
		reserve_label.text = "补到 %d 份粮 · 用 %d 作物和 %d 铜钱" % [plan.target, plan.crops, plan.copper]
		if plan.crops > 0:
			reserve_label.text += "\n取用 %s%s" % [ItemManager.describe_crops(plan.used), _order_stock_note(plan.used)]
		if reserve_button.disabled:
			reserve_label.text += " · 还差 %d 铜钱" % (plan.copper - Global.money)

func _refresh_reclamation_reserve() -> void:
	var plan := Global.reclamation_food_plan()
	reserve_button.text = "备齐开垦粮"
	reserve_button.disabled = not plan.can_order
	if not plan.possible:
		reserve_label.text = "封地已达到最高田额。"
		return
	var lines := PackedStringArray(["立桩用粮 %d · %d 夜口粮 %d · 共 %d 份" % [
		plan.stake_grain, Global.RECLAMATION_NIGHTS, plan.crew_food, plan.target]])
	if plan.food > 0:
		var trade := PackedStringArray()
		if plan.crops > 0:
			trade.append("转粮 " + ItemManager.describe_crops(plan.used) + _order_stock_note(plan.used))
		if plan.copper > 0:
			trade.append("购粮 %d 份用 %d 铜钱" % [plan.food - plan.crops, plan.copper])
		lines.append(" · ".join(trade))
	else:
		lines.append("粮已备齐")
	var budget := "立桩需 %d 铜钱" % plan.stake_copper
	if plan.copper_short > 0:
		budget += " · 合计还差 %d 铜钱" % plan.copper_short
	else:
		budget = "留出 %d 铜钱立桩" % plan.stake_copper
	lines.append(budget)
	reserve_label.text = "\n".join(lines)

func _sell() -> void:
	var amount := int(quantity.value)
	var id := _selected_crop()
	var lots := ItemManager.describe_crops(Global.market_crop_plan(amount, id))
	if Global.sell_crops(amount, id):
		receipt.text = "售出 %s · 铜钱 +%d" % [lots, amount * Global.balance.market_crop_price]

func _convert() -> void:
	var amount := int(quantity.value)
	if Global.convert_inventory_to_food(amount, _selected_crop()):
		receipt.text = "转粮完成 · 粮食 +%d" % amount

func _buy() -> void:
	var amount := int(quantity.value)
	if Global.buy_market_food(amount):
		receipt.text = "购粮完成 · 粮食 +%d · 铜钱 −%d" % [amount, amount * Global.balance.market_food_price]

func _reserve() -> void:
	if reserve_kind.selected == ReserveKind.RECLAMATION:
		var order := Global.reclamation_food_plan()
		if Global.prepare_reclamation_food():
			receipt.text = "开垦粮已备齐 · 入仓 %d 份 · 实付 %d 铜钱" % [order.food, order.copper]
		return
	var plan := Global.food_reserve_plan(RESERVE_NIGHTS)
	if Global.prepare_food_reserve(RESERVE_NIGHTS):
		receipt.text = "三夜粮已备好 · 粮食 +%d" % plan.food
