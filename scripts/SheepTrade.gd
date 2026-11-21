extends VBoxContainer

signal silk_requested

@onready var account: Label = %SheepAccount
@onready var buy_sheep: Button = %BuySheep
@onready var buy_fodder: Button = %BuyFodder
@onready var sell_wool: Button = %SellWool
@onready var weave_coat: Button = %WeaveCoat
var receipt: MarketReceipt

func _ready() -> void:
	for control: Control in [account, buy_sheep, buy_fodder, sell_wool, weave_coat, %BackToSilk]:
		InterfaceFont.scale_reading_text(control)
	buy_sheep.pressed.connect(_trade.bind(Sheepfold.Action.BUY_SHEEP))
	buy_fodder.pressed.connect(_trade.bind(Sheepfold.Action.BUY_FODDER))
	sell_wool.pressed.connect(_trade.bind(Sheepfold.Action.SELL_WOOL))
	weave_coat.pressed.connect(_trade.bind(Sheepfold.Action.WEAVE_COAT))
	%BackToSilk.pressed.connect(silk_requested.emit)
	GameEvents.sheepfold_changed.connect(_refresh)
	GameEvents.money_changed.connect(_refresh.unbind(1))

func show_offer() -> void:
	_refresh()

func _refresh() -> void:
	var flock := Global.sheepfold
	var prices := Global.balance
	if flock.owned():
		account.text = "羊在西坡羊棚 · 草料 %d 份 · 羊毛 %d 份" % [flock.fodder, flock.wool]
		account.text += "\n桥东草甸 · " + Global.meadow_status()
		if Global.money < prices.sheep_fodder_price:
			account.text += "\n买草料还差 %d 铜钱。" % (prices.sheep_fodder_price - Global.money)
		if not flock.coat and flock.wool < prices.sheep_coat_wool:
			account.text += "\n织衣还差 %d 份羊毛。" % (prices.sheep_coat_wool - flock.wool)
	else:
		account.text = "领羊后在封地西坡立栏。\n雨天和冬季要备草料，饱食 %d 夜可剪毛。" % prices.sheep_wool_nights
		if Global.money < prices.sheep_price:
			account.text += "\n还差 %d 铜钱。" % (prices.sheep_price - Global.money)
	buy_sheep.visible = not flock.owned()
	buy_sheep.text = "领羊立栏 · %d 铜钱" % prices.sheep_price
	buy_sheep.disabled = not Global.can_use_sheepfold(Sheepfold.Action.BUY_SHEEP)
	buy_fodder.get_parent().visible = flock.owned()
	buy_fodder.text = "买草料 %d 份 · −%d 铜钱" % [prices.sheep_fodder_bundle, prices.sheep_fodder_price]
	buy_fodder.disabled = not Global.can_use_sheepfold(Sheepfold.Action.BUY_FODDER)
	sell_wool.text = "售羊毛 1 份 · +%d 铜钱" % prices.sheep_wool_price
	sell_wool.disabled = not Global.can_use_sheepfold(Sheepfold.Action.SELL_WOOL)
	weave_coat.visible = flock.owned()
	weave_coat.text = "羊毛衣已送到堂屋" if flock.coat else "请蔡娘织羊毛衣 · %d 份羊毛" % prices.sheep_coat_wool
	weave_coat.disabled = not Global.can_use_sheepfold(Sheepfold.Action.WEAVE_COAT)

func _trade(action: Sheepfold.Action) -> void:
	if not Global.use_sheepfold(action):
		return
	var prices := Global.balance
	match action:
		Sheepfold.Action.BUY_SHEEP:
			receipt.present("西坡羊棚 +1 只羊 · 铜钱 −%d\n回封地可从舆图查看西坡羊棚。" % prices.sheep_price,
				$SheepHeader/Animal.texture)
		Sheepfold.Action.BUY_FODDER:
			receipt.present("羊棚草料 +%d 份 · 铜钱 −%d" % [prices.sheep_fodder_bundle, prices.sheep_fodder_price],
				HUDIcons.icon(HUDIcons.Symbol.GRAIN))
		Sheepfold.Action.SELL_WOOL:
			receipt.present("羊毛 −1 份 · 铜钱 +%d" % prices.sheep_wool_price, ItemManager.goods_icon(ItemManager.Goods.WOOL))
		Sheepfold.Action.WEAVE_COAT:
			receipt.present("羊毛 −%d 份 · 到堂屋衣架旁试穿羊毛衣" % prices.sheep_coat_wool,
				ItemManager.goods_icon(ItemManager.Goods.WOOL))
			AudioManager.play_ui_sfx(1.10)
			return
	AudioManager.play_trade_cue(AudioManager.TradeCue.SALE if action == Sheepfold.Action.SELL_WOOL else AudioManager.TradeCue.PURCHASE)
