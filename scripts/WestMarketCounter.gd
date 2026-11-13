extends Control

@onready var title: Label = %CounterTitle
@onready var close_button: Button = %CloseCounter
@onready var counter_layout: HBoxContainer = %CounterLayout
@onready var keeper_card: PanelContainer = %KeeperCard
@onready var keeper_portrait: TextureRect = %KeeperPortrait
@onready var keeper_note: Label = %KeeperNote
@onready var market_produce: Button = %MarketProduce
@onready var grain: VBoxContainer = %Grain
@onready var fish: VBoxContainer = %Fish
@onready var silk: VBoxContainer = %Silk
@onready var sheep: VBoxContainer = %Sheep
@onready var orders: VBoxContainer = %Orders
@onready var silk_stock: Label = %SilkStock
@onready var silk_sample: Label = %Sample
@onready var sell_silk: Button = %SellSilk
@onready var silk_receipt: Label = %SilkReceipt
@onready var card: PanelContainer = $Center/Card
@onready var usual_width := card.custom_minimum_size.x

func _ready() -> void:
	close_button.pressed.connect(hide)
	GamepadInput.changed.connect(_refresh_close_hint)
	_refresh_close_hint()
	sell_silk.pressed.connect(_sell_silk)
	market_produce.pressed.connect(_buy_market_produce)
	%SheepTrade.pressed.connect(_open_sheep)
	sheep.silk_requested.connect(open_for.bind(MarketStall.Kind.SILK))
	GameEvents.silk_changed.connect(_refresh_silk)
	GameEvents.money_changed.connect(_refresh_market_produce.unbind(1))
	GameEvents.fish_changed.connect(func():
		if fish.is_visible_in_tree():
			keeper_note.text = _fish_keeper_note()
	)

func _refresh_close_hint() -> void:
	close_button.text = "离开  B" if GamepadInput.active else "离开  Esc"

func open_for(kind: MarketStall.Kind) -> void:
	grain.receipt.text = ""
	fish.clear_receipt()
	silk_receipt.text = ""
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
	title.text = heading
	card.custom_minimum_size.x = 744.0 if active_view == fish else usual_width
	keeper_card.visible = not speaker.is_empty()
	keeper_portrait.texture = CharacterArt.dialogue_portrait(speaker, null, false)
	if keeper_card.visible:
		keeper_note.text = _keeper_line(active_view)
		card.custom_minimum_size.x += keeper_card.custom_minimum_size.x + counter_layout.get_theme_constant("separation")
	for view: Control in [grain, fish, silk, orders, sheep]:
		view.visible = view == active_view
	_refresh_market_produce()
	show()
	close_button.grab_focus()
	AudioManager.play_ui_sfx()

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
	market_produce.text = "买%s · %d 铜钱" % [crop, price] if available else "%s已售罄" % crop
	market_produce.disabled = not available or Global.money < price or Global.outcome != Global.Outcome.RUNNING
	market_produce.tooltip_text = "还差 %d 铜钱" % (price - Global.money) if available and Global.money < price else ""
	keeper_note.text = ("乡亲托我带来一袋%s。今季只有这一份，买了可进私仓交单。" % crop if available else
		"这季的%s给你了。换季再来，我会带一份新货。" % crop)

func _buy_market_produce() -> void:
	if Global.buy_market_produce():
		grain.receipt.text = "%s已入私仓 · 铜钱 −%d" % [
			ItemManager.crop_label(Global.market_produce_crop()), Global.market_produce_price()]
		close_button.grab_focus()
		AudioManager.play_ui_sfx(1.12)

func _fish_keeper_note() -> String:
	if not Global.knows_ravine_journal():
		return "想下竿，去南边竹径找蒲宁。他知道竹涧两岸的水深。"
	if not Global.fish_market_offer().receipt.is_empty():
		return "今季留的那尾鱼收好了。多的鱼可以留作口粮，也可以卖给我。"
	return "留鱼单只要一尾。交单时可以领铜钱，也可以换今夜的粮。"

func _refresh_silk() -> void:
	silk_stock.text = "丝绸库存   %d 匹" % Global.silk_workshop.bolts
	sell_silk.text = "售出一匹丝绸   +%d 铜钱" % Global.balance.silk_sell_price
	sell_silk.disabled = not Global.can_use_workshop(SilkWorkshop.Action.SELL)
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
		silk_receipt.text = "已售一匹丝绸 · 铜钱 +%d" % Global.balance.silk_sell_price
		AudioManager.play_ui_sfx(1.12)
