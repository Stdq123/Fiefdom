extends Control

const COUNTER_MARGIN := 20.0
const JOURNAL_THEME := preload("res://resources/estate_hud_theme.tres")

@onready var title: Label = %CounterTitle
@onready var counter_balance: Label = %CounterBalance
@onready var close_button: Button = %CloseCounter
@onready var trade_receipt: MarketReceipt = %TradeReceipt
@onready var scroll: ScrollContainer = %CounterScroll
@onready var counter_layout: HBoxContainer = %CounterLayout
@onready var keeper_card: PanelContainer = %KeeperCard
@onready var keeper_portrait: TextureRect = %KeeperPortrait
@onready var keeper_note: Label = %KeeperNote
@onready var market_produce: Button = %MarketProduce
@onready var order_route: Button = %OrderRoute
@onready var grain: VBoxContainer = %Grain
@onready var fish: VBoxContainer = %Fish
@onready var silk: VBoxContainer = %Silk
@onready var sheep: VBoxContainer = %Sheep
@onready var orders: VBoxContainer = %Orders
@onready var silk_stock: Label = %SilkStock
@onready var silk_sample: Label = %Sample
@onready var silk_quote: Label = %SilkQuote
@onready var sell_silk: Button = %SellSilk
@onready var card: PanelContainer = $Center/Card
@onready var inset: MarginContainer = $Center/Card/Inset
@onready var body: VBoxContainer = $Center/Card/Inset/Body
@onready var heading_row: HBoxContainer = $Center/Card/Inset/Body/Heading
@onready var rule: HSeparator = $Center/Card/Inset/Body/Rule
@onready var usual_width := card.custom_minimum_size.x

func _ready() -> void:
	var scroll_bar := scroll.get_v_scroll_bar()
	scroll_bar.theme = JOURNAL_THEME
	scroll_bar.theme_type_variation = &"HudJournalBar"
	scroll_bar.focus_mode = FOCUS_ALL
	for control: Control in [title, counter_balance, close_button, keeper_note, market_produce, order_route,
		silk_stock, silk_sample, silk_quote, sell_silk, %SheepTrade]:
		InterfaceFont.scale_reading_text(control)
	grain.receipt = trade_receipt
	fish.receipt = trade_receipt
	fish.market_offer.trade_receipt = trade_receipt
	sheep.receipt = trade_receipt
	trade_receipt.minimum_size_changed.connect(_fit_body, CONNECT_DEFERRED)
	trade_receipt.visibility_changed.connect(_fit_body, CONNECT_DEFERRED)
	trade_receipt.presented.connect(_keep_trade_focus)
	counter_layout.minimum_size_changed.connect(_fit_body, CONNECT_DEFERRED)
	heading_row.minimum_size_changed.connect(_fit_body, CONNECT_DEFERRED)
	get_viewport().size_changed.connect(_fit_body)
	close_button.pressed.connect(close_counter)
	GamepadInput.changed.connect(_refresh_close_hint)
	_refresh_close_hint()
	sell_silk.pressed.connect(_sell_silk)
	market_produce.pressed.connect(_buy_market_produce)
	order_route.pressed.connect(GameEvents.west_market_directions_requested.emit.bind(Global.MARKET_ORDERS))
	%SheepTrade.pressed.connect(_open_sheep)
	sheep.silk_requested.connect(open_for.bind(MarketStall.Kind.SILK))
	GameEvents.silk_changed.connect(_refresh_silk)
	GameEvents.money_changed.connect(_refresh_prices.unbind(1))
	GameEvents.food_changed.connect(_refresh_balance.unbind(1))
	GameEvents.inventory_changed.connect(_refresh_order_route.unbind(1))
	GameEvents.silk_changed.connect(_refresh_order_route)
	GameEvents.fish_changed.connect(_refresh_order_route)
	GameEvents.fish_changed.connect(func():
		if fish.is_visible_in_tree():
			keeper_note.text = _fish_keeper_note()
	)

func _refresh_close_hint() -> void:
	close_button.text = "离开  B" if GamepadInput.active else "离开  Esc"

func _fit_body() -> void:
	if not is_visible_in_tree():
		return
	var chrome := card.get_theme_stylebox(&"panel").get_minimum_size().y + heading_row.get_combined_minimum_size().y \
		+ rule.get_combined_minimum_size().y + inset.get_theme_constant(&"margin_top") \
		+ inset.get_theme_constant(&"margin_bottom") + 2.0 * body.get_theme_constant(&"separation")
	if trade_receipt.visible:
		chrome += trade_receipt.get_combined_minimum_size().y + body.get_theme_constant(&"separation")
	var available := maxf(0.0, get_viewport_rect().size.y - 2.0 * COUNTER_MARGIN - chrome)
	if orders.visible:
		orders.fit_market_book(available)
	else:
		scroll.custom_minimum_size.y = minf(available, counter_layout.get_combined_minimum_size().y)

func _keep_trade_focus() -> void:
	await get_tree().process_frame
	if not is_visible_in_tree() or not trade_receipt.visible:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if not focus or (focus is BaseButton and focus.disabled):
		close_button.grab_focus()
	elif scroll.is_ancestor_of(focus):
		scroll.ensure_control_visible(focus)
	GamepadInput.snap_pointer_to_focus()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey:
		return
	var backward := event.is_action_pressed(&"ui_focus_prev")
	if not backward and not event.is_action_pressed(&"ui_focus_next"):
		return
	var viewport := get_viewport()
	if viewport.get_embedded_subwindows().any(func(window: Window) -> bool: return not window.unfocusable):
		return
	var current := viewport.gui_get_focus_owner()
	if current and is_ancestor_of(current):
		var next := current.find_prev_valid_focus() if backward else current.find_next_valid_focus()
		if next and is_ancestor_of(next):
			return
	var controls := find_children("*", "Control", true, false)
	if backward:
		controls.reverse()
	for control: Control in controls:
		if control.is_visible_in_tree() and control.focus_mode == FOCUS_ALL and (not control is Button or not control.disabled):
			control.grab_focus()
			viewport.set_input_as_handled()
			return

func open_for(kind: MarketStall.Kind) -> void:
	if kind == MarketStall.Kind.SILK:
		_refresh_silk()
	var speaker: String = MarketStall.KEEPERS[kind]
	var heading := "%s · %s" % [MarketStall.TITLES[kind], speaker]
	_open_view(heading, [grain, fish, silk][kind], speaker)

func open_orders() -> void:
	_open_view("西市交货簿", orders)

func _open_sheep() -> void:
	sheep.show_offer()
	var speaker: String = MarketStall.KEEPERS[MarketStall.Kind.SILK]
	_open_view("%s · 羊与羊毛" % speaker, sheep, speaker)

func _open_view(heading: String, active_view: Control, speaker := "") -> void:
	var opening := not is_visible_in_tree()
	var changing_page := not active_view.visible
	trade_receipt.clear()
	title.text = heading
	counter_balance.visible = active_view != orders
	_refresh_balance()
	card.custom_minimum_size.x = 744.0 if active_view in [fish, orders] else usual_width
	keeper_card.visible = not speaker.is_empty()
	keeper_portrait.texture = CharacterArt.dialogue_portrait(speaker, null, false)
	if keeper_card.visible:
		keeper_note.text = _keeper_line(active_view)
		card.custom_minimum_size.x += keeper_card.custom_minimum_size.x + counter_layout.get_theme_constant("separation")
	for view: Control in [grain, fish, silk, orders, sheep]:
		view.visible = view == active_view
	scroll.visible = active_view != orders
	_refresh_market_produce()
	_refresh_order_route()
	show()
	scroll.set_deferred(&"scroll_vertical", 0)
	_fit_body.call_deferred()
	close_button.grab_focus()
	if opening or changing_page:
		AudioManager.play_menu_cue(AudioManager.MenuCue.OPEN if opening else AudioManager.MenuCue.PAGE)

func close_counter() -> void:
	hide()
	trade_receipt.clear()
	AudioManager.play_menu_cue(AudioManager.MenuCue.CLOSE)

func _keeper_line(active_view: Control) -> String:
	if active_view == grain:
		return "要留着交货的粮，先从袋里挑出来。余下的我再给你过秤。"
	if active_view == fish:
		return _fish_keeper_note()
	if active_view == sheep:
		return "西坡春夏秋能放牧。攒够羊毛带过来，我给你织件厚衣。"
	if VisitorData.silk_sample_on_display(Global.current_day):
		return "我把你家的样绸挂在朝街一面，过路人一眼就看得见。"
	return "把布边铺平给我看看。成匹的绸我收，零头你留着补衣。"

func _refresh_market_produce() -> void:
	market_produce.visible = grain.visible and Global.first_tribute_delivered()
	if not market_produce.visible:
		return
	var crop := ItemManager.crop_label(Global.market_produce_crop())
	var price := Global.market_produce_price()
	var available := Global.market_produce_available()
	var shortage := maxi(0, price - Global.money)
	market_produce.text = "买%s · %d 铜钱" % [crop, price] if available else "%s已售罄" % crop
	market_produce.disabled = not available or shortage > 0 or Global.outcome != Global.Outcome.RUNNING
	market_produce.tooltip_text = "还差 %d 铜钱" % shortage if available and shortage > 0 else ""
	keeper_note.text = ("乡亲托我带来一袋%s。今季只有这一份，买了可进私仓交单。" % crop if available else
		"这季的%s给你了。换季再来，我会带一份新货。" % crop)
	if available and shortage > 0:
		keeper_note.text += "\n买这袋%s还差 %d 铜钱。" % [crop, shortage]

func _refresh_prices() -> void:
	_refresh_balance()
	_refresh_market_produce()
	_refresh_silk()

func _refresh_balance() -> void:
	counter_balance.text = "铜钱 %d 枚 · 粮仓 %d 份" % [Global.money, Global.food_storage]

func _buy_market_produce() -> void:
	if Global.buy_market_produce():
		var id := Global.market_produce_crop()
		trade_receipt.present("私仓 %s +1 份 · 铜钱 −%d" % [ItemManager.crop_label(id), Global.market_produce_price()],
			ItemManager.harvest_icon(id))
		close_button.grab_focus()
		AudioManager.play_trade_cue(AudioManager.TradeCue.PURCHASE)

func _refresh_order_route() -> void:
	order_route.visible = grain.visible and Global.can_deliver_season_order(Global.season_order())

func _fish_keeper_note() -> String:
	if not Global.knows_ravine_journal():
		return "想下竿，去南边竹径找蒲宁。他知道竹涧两岸的水深。"
	var receipt: Dictionary = Global.fish_market_offer().receipt
	if not receipt.is_empty():
		if receipt.day == Global.current_day:
			if not Global.fish_order_for_porter():
				return "鱼收好了。伙计收工了，我打烊后给人送去。"
			if Global.day_progress < CreekFish.ORDER_PICKUP:
				return "鱼收好了，先养在摊边的槽里。酉时伙计会来取。"
		return "鱼收好了，已经送给客人。多的鱼可以留作口粮，或卖给我。"
	return "留鱼单只要一尾。交单时可以领铜钱，也可以换今夜的粮。"

func _refresh_silk() -> void:
	var workshop := Global.silk_workshop
	var price := Global.balance.silk_sell_price
	silk_stock.text = "丝绸库存   %d 匹" % workshop.bolts
	sell_silk.text = "售出 1 匹"
	sell_silk.disabled = not Global.can_use_workshop(SilkWorkshop.Action.SELL)
	if not workshop.built:
		silk_quote.text = "在封地的蚕桑页建蚕室，再备一匹丝绸。"
	elif workshop.bolts == 0:
		silk_quote.text = "还缺 1 匹丝绸 · 每匹售价 %d 铜钱" % price
	else:
		silk_quote.text = "交 1 匹丝绸 · 收 %d 铜钱\n售后余 %d 匹，钱袋 %d 枚" % [
			price, workshop.bolts - 1, Global.money + price]
	silk_sample.visible = Global.silk_sample_requested() or Global.silk_sample_day > 0
	if VisitorData.silk_sample_on_display(Global.current_day):
		silk_sample.text = "蔡娘在摊前挂出了「%s」织成的样绸。" % Global.campaign_name
	elif Global.silk_sample_day > 0:
		silk_sample.text = "陶辛已收样绸，蔡娘明日挂到摊前。"
	else:
		silk_sample.text = "陶辛在西廊等一匹样绸。"
	%SheepTrade.visible = Global.first_tribute_delivered()

func _sell_silk() -> void:
	if Global.use_workshop(SilkWorkshop.Action.SELL):
		trade_receipt.present("丝绸 −1 匹 · 铜钱 +%d" % Global.balance.silk_sell_price,
			ItemManager.goods_icon(ItemManager.Goods.SILK_BOLT))
		AudioManager.play_trade_cue(AudioManager.TradeCue.SALE)
