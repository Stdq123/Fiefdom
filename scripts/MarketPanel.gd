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
@onready var reform_sale: HBoxContainer = $ReformSale
@onready var reform_sale_note: Label = $ReformSale/Note
@onready var reform_sale_button: Button = $ReformSale/SellSurplus
@onready var sell_button: Button = $TradeActions/SellButton
@onready var convert_button: Button = $TradeActions/ConvertButton
@onready var buy_button: Button = $TradeActions/BuyFoodButton
@onready var reserve_kind: OptionButton = $ReserveOptions/ReserveKind
@onready var use_reserved: CheckBox = $ReserveOptions/UseReserved
@onready var reserve_label: Label = $ReservePlan
@onready var reserve_button: Button = $ReserveActions/ReserveButton
@onready var survey_button: Button = $ReserveActions/ReturnToSurvey
@onready var receipt: MarketReceipt = $Receipt

var return_to_survey: Callable
var reform_quote: Dictionary = {}
var reserve_quote: Dictionary = {}

func _ready() -> void:
	crop_choice.add_item("全部")
	for id in CropStock.IDS:
		crop_choice.add_item(ItemManager.crop_label(id))
	crop_choice.item_selected.connect(_refresh_trade.unbind(1))
	quantity.value_changed.connect(_refresh_trade.unbind(1))
	$QuantityRow/Five.pressed.connect(func(): quantity.value = 5)
	all_crops.pressed.connect(func(): quantity.value = Global.crop_stock.count(_selected_crop()))
	sell_button.pressed.connect(_sell)
	reform_sale_button.pressed.connect(_sell_reform_surplus)
	convert_button.pressed.connect(_convert)
	buy_button.pressed.connect(_buy)
	reserve_kind.add_item("三夜口粮", ReserveKind.HOUSEHOLD)
	reserve_kind.add_item("开垦备粮", ReserveKind.RECLAMATION)
	reserve_kind.item_selected.connect(_change_reserve_kind.unbind(1))
	use_reserved.toggled.connect(_refresh_reserve.unbind(1))
	reserve_button.pressed.connect(_reserve)
	survey_button.pressed.connect(func(): return_to_survey.call())
	$MarketHeader/NightRations.pressed.connect(GameEvents.night_rations_requested.emit)
	var grain_stall: String = MarketStall.TITLES[MarketStall.Kind.GRAIN]
	$MarketHeader/MarketDirections.pressed.connect(GameEvents.west_market_directions_requested.emit.bind(grain_stall))
	$MarketHeader.visible = not at_stall
	if at_stall:
		_enable_stall_reading()
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
	GameEvents.tax_reform_choice_made.connect(_refresh.unbind(1))
	GameEvents.day_advanced.connect(func(_day: int):
		receipt.clear()
		use_reserved.set_pressed_no_signal(false)
		_refresh()
	)
	_refresh()

func _enable_stall_reading() -> void:
	for control: Control in [grain_stock, crop_stock, copper_stock, food_label, stock_detail, debit_plan,
		$QuantityRow/Label, quantity.get_line_edit(), $QuantityRow/Five, all_crops, crop_choice,
		sell_button, convert_button, buy_button, reform_sale_note, reform_sale_button,
		reserve_kind, use_reserved, reserve_label, reserve_button]:
		InterfaceFont.scale_reading_text(control)
	for picker: OptionButton in [crop_choice, reserve_kind]:
		var menu := picker.get_popup()
		var standard := menu.get_theme_font_size(&"font_size")
		menu.about_to_popup.connect(func(): menu.add_theme_font_size_override(&"font_size", Preferences.reading_font_size(standard)))

func focus_reform_sale() -> void:
	if reform_sale_button.is_visible_in_tree():
		reform_sale_button.grab_focus()
		_snap_market_focus(reform_sale_button)

func _snap_market_focus(control: Control) -> void:
	if not GamepadInput.active:
		return
	# The market tab is resized after its visibility changes.
	await get_tree().process_frame
	if control.has_focus():
		GamepadInput.snap_pointer_to_focus()

func show_reclamation_reserve(return_action: Callable) -> void:
	return_to_survey = return_action
	reserve_kind.select(ReserveKind.RECLAMATION)
	quantity.value = 1
	_change_reserve_kind()
	if reserve_button.disabled:
		reserve_kind.grab_focus()
	else:
		reserve_button.grab_focus()

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		use_reserved.set_pressed_no_signal(false)
		if return_to_survey.is_valid():
			return_to_survey = Callable()
			reserve_kind.select(ReserveKind.HOUSEHOLD)
	_refresh()

func _change_reserve_kind() -> void:
	use_reserved.set_pressed_no_signal(false)
	receipt.clear()
	_refresh_reserve()

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
	_refresh_reform_sale()
	_refresh_trade()
	_refresh_reserve()

func _refresh_reform_sale() -> void:
	reform_quote = Global.reform_sale_quote()
	var had_focus := reform_sale_button.has_focus()
	reform_sale.visible = not reform_quote.is_empty()
	if reform_quote.is_empty():
		if had_focus:
			crop_choice.grab_focus()
			_snap_market_focus(crop_choice)
		return
	var retained := PackedStringArray()
	if reform_quote.rations > 0:
		retained.append("今夜所缺口粮 %d 份" % reform_quote.rations)
	if reform_quote.held > 0:
		retained.append("时令与节庆用料 %d 份" % reform_quote.held)
	reform_sale_note.text = "售 %s · 售后 %d / %d 铜钱" % [
		ItemManager.describe_crops(reform_quote.used), reform_quote.balance, reform_quote.target]
	if not retained.is_empty():
		reform_sale_note.text += "\n保留 " + " · ".join(retained)
	reform_sale_button.text = "出售 %d 份 · +%d 铜钱" % [reform_quote.amount, reform_quote.gain]

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
	convert_button.text = "转粮 · +%d 份" % amount
	sell_button.text = "出售 · +%d 铜钱" % (amount * Global.balance.market_crop_price)
	buy_button.text = "买粮 %d 份 · −%d 铜钱" % [amount, purchase]
	convert_button.disabled = not valid or crop_shortage > 0
	sell_button.disabled = convert_button.disabled
	buy_button.disabled = not valid or copper_shortage > 0
	var quantity_hint := "" if valid else "请输入至少 1 份"
	var crop_hint := "还差 %d 份作物" % crop_shortage if crop_shortage > 0 else quantity_hint
	convert_button.tooltip_text = "%d %s换 %d 份粮" % [amount, label, amount] if not convert_button.disabled else crop_hint
	sell_button.tooltip_text = "出售 %d 份%s" % [amount, label] if not sell_button.disabled else crop_hint
	buy_button.tooltip_text = "买入 %d 份粮" % amount if not buy_button.disabled else (
		"还差 %d 铜钱" % copper_shortage if copper_shortage > 0 else quantity_hint)
	var use := Global.market_crop_plan(amount, crop_id)
	if not use.is_empty():
		debit_plan.text = "会取用   " + ItemManager.describe_crops(use) + _order_stock_note(use)
	else:
		debit_plan.text = "出售或转粮还差 %d 份%s" % [crop_shortage, label] if crop_shortage > 0 else quantity_hint
	if valid and copper_shortage > 0:
		debit_plan.text += "\n买粮还差 %d 铜钱" % copper_shortage

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

func _refresh_reserve() -> void:
	survey_button.visible = return_to_survey.is_valid()
	var construction := reserve_kind.selected == ReserveKind.RECLAMATION
	var plan := (Global.reclamation_food_plan(use_reserved.button_pressed) if construction
		else Global.food_reserve_plan(RESERVE_NIGHTS, use_reserved.button_pressed))
	reserve_quote = plan
	var can_use_reserved: bool = plan.can_use_reserved and plan.get("possible", true)
	var focus_moved: bool = (use_reserved.has_focus() and not can_use_reserved
		or reserve_button.has_focus() and not plan.can_order)
	use_reserved.visible = can_use_reserved
	if not can_use_reserved:
		use_reserved.set_pressed_no_signal(false)
	reserve_kind.focus_neighbor_right = reserve_kind.get_path_to(use_reserved) if can_use_reserved else NodePath()
	reserve_button.text = "备齐开垦粮" if construction else "按计划补粮"
	reserve_button.disabled = not plan.can_order
	if focus_moved and is_visible_in_tree():
		reserve_kind.grab_focus()
		_snap_market_focus(reserve_kind)
	reserve_label.text = _reserve_text(plan, construction)

func _reserve_text(plan: Dictionary, construction: bool) -> String:
	var lines := PackedStringArray()
	if construction:
		if not plan.possible:
			return "封地已达到最高田额。"
		lines.append("立桩用粮 %d · %d 夜口粮 %d · 共 %d 份" % [
			plan.stake_grain, Global.RECLAMATION_NIGHTS, plan.crew_food, plan.target])
	elif plan.target == 0:
		return "招募门客后，可按每夜粮耗备粮。"
	elif plan.food == 0:
		return "粮仓已有三夜口粮。"

	if plan.food > 0:
		var trade := PackedStringArray()
		if not construction:
			trade.append("补到 %d 份粮" % plan.target)
		if plan.crops > 0:
			trade.append("转粮 " + ItemManager.describe_crops(plan.used))
		if plan.food > plan.crops:
			trade.append("购粮 %d 份用 %d 铜钱" % [plan.food - plan.crops, plan.copper])
		lines.append(" · ".join(trade))
		var crops := PackedStringArray()
		if not plan.used_reserved.is_empty():
			crops.append("将动用预留 " + ItemManager.describe_crops(plan.used_reserved))
		if not plan.retained.is_empty():
			crops.append("交货与节庆留用 " + ItemManager.describe_crops(plan.retained))
		if not crops.is_empty():
			lines.append(" · ".join(crops))
	else:
		lines.append("粮已备齐")

	var budget := PackedStringArray()
	if construction:
		budget.append("立桩需 %d 铜钱" % plan.stake_copper)
	if plan.food > 0 and plan.research_reserve > 0:
		budget.append("第 %d 天研究费留 %d 铜钱" % [plan.research_day, plan.research_reserve])
	if plan.copper_short > 0:
		budget.append("还差 %d 铜钱" % plan.copper_short)
	if not budget.is_empty():
		lines.append(" · ".join(budget))
	return "\n".join(lines)

func _sell() -> void:
	var amount := int(quantity.value)
	var id := _selected_crop()
	var lots := Global.market_crop_plan(amount, id)
	if Global.sell_crops(amount, id):
		receipt.present_crops("售出 %s · 铜钱 +%d" % [ItemManager.describe_crops(lots), amount * Global.balance.market_crop_price], lots)
		AudioManager.play_trade_cue(AudioManager.TradeCue.SALE)

func _sell_reform_surplus() -> void:
	var sale := Global.sell_crops_for_reform(reform_quote)
	if sale.is_empty():
		_refresh()
		receipt.present("库存或用粮已有变化，请核对新报价。", HUDIcons.icon(HUDIcons.Symbol.LEDGER), true)
		return
	var message := "售出 %s · 铜钱 +%d · 现有 %d 枚" % [ItemManager.describe_crops(sale.used), sale.gain, sale.balance]
	if sale.balance >= sale.target:
		message += " · 铜钱已达标"
	receipt.present_crops(message, sale.used)
	AudioManager.play_trade_cue(AudioManager.TradeCue.SALE)

func _convert() -> void:
	var amount := int(quantity.value)
	var id := _selected_crop()
	var lots := Global.market_crop_plan(amount, id)
	if Global.convert_inventory_to_food(amount, id):
		receipt.present_crops("转用 %s · 粮仓 +%d 份" % [ItemManager.describe_crops(lots), amount], lots)
		AudioManager.play_trade_cue(AudioManager.TradeCue.STORE_FOOD)

func _buy() -> void:
	var amount := int(quantity.value)
	if Global.buy_market_food(amount):
		receipt.present("购粮入仓 +%d 份 · 铜钱 −%d" % [amount, amount * Global.balance.market_food_price],
			HUDIcons.icon(HUDIcons.Symbol.GRAIN))
		AudioManager.play_trade_cue(AudioManager.TradeCue.PURCHASE)

func _reserve() -> void:
	var quote := reserve_quote
	if not quote.get("can_order", false):
		return
	var construction := reserve_kind.selected == ReserveKind.RECLAMATION
	var committed := (Global.prepare_reclamation_food(use_reserved.button_pressed, quote) if construction
		else Global.prepare_food_reserve(RESERVE_NIGHTS, use_reserved.button_pressed, quote))
	if not committed:
		_refresh()
		receipt.present("库存或用粮已有变化，请核对新计划。", HUDIcons.icon(HUDIcons.Symbol.LEDGER), true)
		return
	var title := "开垦粮已备齐" if construction else "三夜粮已备好"
	var message := "%s · 入仓 %d 份 · 实付 %d 铜钱" % [title, quote.food, quote.copper]
	if not quote.used.is_empty():
		message += "\n转用 " + ItemManager.describe_crops(quote.used)
	receipt.present_crops(message, quote.used)
	AudioManager.play_trade_cue(AudioManager.TradeCue.PURCHASE if quote.copper > 0 else AudioManager.TradeCue.STORE_FOOD)
