extends Control

const HEADINGS := ["粮摊 · 谷伯", "鱼摊 · 渔生", "绸摊 · 蔡娘"]

@onready var title: Label = %CounterTitle
@onready var close_button: Button = %CloseCounter
@onready var grain: VBoxContainer = %Grain
@onready var fish: VBoxContainer = %Fish
@onready var silk: VBoxContainer = %Silk
@onready var sheep: VBoxContainer = %Sheep
@onready var orders: VBoxContainer = %Orders
@onready var silk_stock: Label = %SilkStock
@onready var silk_sample: Label = %Sample
@onready var sell_silk: Button = %SellSilk
@onready var silk_receipt: Label = %SilkReceipt

func _ready() -> void:
	close_button.pressed.connect(hide)
	sell_silk.pressed.connect(_sell_silk)
	%SheepTrade.pressed.connect(_open_sheep)
	sheep.silk_requested.connect(open_for.bind(MarketStall.Kind.SILK))
	GameEvents.silk_changed.connect(_refresh_silk)

func open_for(kind: MarketStall.Kind) -> void:
	grain.receipt.text = ""
	fish.receipt.text = ""
	silk_receipt.text = ""
	if kind == MarketStall.Kind.SILK:
		_refresh_silk()
	_open_view(HEADINGS[kind], [grain, fish, silk][kind])

func open_orders() -> void:
	_open_view("西市交货簿", orders)

func _open_sheep() -> void:
	sheep.show_offer()
	_open_view("绸摊 · 羊与羊毛", sheep)

func _open_view(heading: String, active_view: Control) -> void:
	title.text = heading
	for view: Control in [grain, fish, silk, orders, sheep]:
		view.visible = view == active_view
	show()
	close_button.grab_focus()
	AudioManager.play_ui_sfx()

func _refresh_silk() -> void:
	silk_stock.text = "丝绸库存   %d 匹" % Global.silk_workshop.bolts
	sell_silk.text = "售出一匹丝绸   +%d 铜钱" % Global.balance.silk_sell_price
	sell_silk.disabled = not Global.can_use_workshop(SilkWorkshop.Action.SELL)
	silk_sample.visible = Global.silk_sample_requested()
	%SheepTrade.visible = Global.first_tribute_delivered()

func _sell_silk() -> void:
	if Global.use_workshop(SilkWorkshop.Action.SELL):
		silk_receipt.text = "已售一匹丝绸 · 铜钱 +%d" % Global.balance.silk_sell_price
		AudioManager.play_ui_sfx(1.12)
