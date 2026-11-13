extends VBoxContainer

signal silk_requested

@onready var account: Label = %SheepAccount
@onready var buy_sheep: Button = %BuySheep
@onready var buy_fodder: Button = %BuyFodder
@onready var sell_wool: Button = %SellWool
@onready var weave_coat: Button = %WeaveCoat
@onready var receipt: Label = %SheepReceipt

func _ready() -> void:
	buy_sheep.pressed.connect(_trade.bind(Sheepfold.Action.BUY_SHEEP))
	buy_fodder.pressed.connect(_trade.bind(Sheepfold.Action.BUY_FODDER))
	sell_wool.pressed.connect(_trade.bind(Sheepfold.Action.SELL_WOOL))
	weave_coat.pressed.connect(_trade.bind(Sheepfold.Action.WEAVE_COAT))
	%BackToSilk.pressed.connect(silk_requested.emit)
	GameEvents.sheepfold_changed.connect(_refresh)

func show_offer() -> void:
	receipt.text = ""
	_refresh()

func _refresh() -> void:
	var flock := Global.sheepfold
	var prices := Global.balance
	if flock.owned():
		account.text = "羊在西坡羊棚 · 草料 %d 份 · 羊毛 %d 份" % [flock.fodder, flock.wool]
		account.text += "\n桥东草甸 · " + Global.meadow_status()
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
	match action:
		Sheepfold.Action.BUY_SHEEP:
			receipt.text = "蔡娘已安置好羊。回封地后可在舆图上找到西坡羊棚。"
		Sheepfold.Action.BUY_FODDER:
			receipt.text = "草料已送进羊棚。雨天和冬天会取用。"
		Sheepfold.Action.SELL_WOOL:
			receipt.text = "蔡娘收下了一份羊毛。"
		Sheepfold.Action.WEAVE_COAT:
			receipt.text = "到堂屋衣架旁试穿。"
	AudioManager.play_ui_sfx(1.10)
