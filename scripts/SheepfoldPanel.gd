extends "res://scripts/SurveyMap.gd"

@onready var growth: Label = %WoolGrowth
@onready var stock: Label = %Stock
@onready var forecast: Label = %Forecast
@onready var mix_fodder: Button = %MixFodder
@onready var shear: Button = %Shear
@onready var receipt: Label = %Receipt

func _ready() -> void:
	super._ready()
	mix_fodder.pressed.connect(_mix_fodder)
	shear.pressed.connect(_shear)

func _refresh_on_open() -> void:
	receipt.text = ""
	_refresh()

func _refresh() -> void:
	var flock := Global.sheepfold
	var ready := Global.can_use_sheepfold(Sheepfold.Action.SHEAR)
	growth.text = "羊毛已长足，可以剪毛。" if ready else "羊毛长势  %d / %d 夜" % [flock.wool_nights, Global.balance.sheep_wool_nights]
	stock.text = "草料 %d 份    羊毛 %d 份    私仓麦 %d 份" % [flock.fodder, flock.wool, Global.crop_stock.count("wheat")]
	var projected := flock.fodder
	var watches := PackedStringArray()
	for offset in 3:
		var feed := Global.sheep_feed(projected, Global.current_day + offset)
		watches.append("%s  %s" % [["今晚", "明晚", "后晚"][offset], Sheepfold.FEED_LABELS[feed]])
		if feed == Sheepfold.Feed.FODDER:
			projected -= 1
	forecast.text = "\n".join(watches)
	if flock.last_feed != Sheepfold.Feed.NONE:
		forecast.text += "\n昨夜  " + Sheepfold.FEED_LABELS[flock.last_feed]
	mix_fodder.text = "用 1 份麦备 %d 份草料" % Global.balance.sheep_fodder_bundle
	mix_fodder.disabled = not Global.can_use_sheepfold(Sheepfold.Action.MIX_FODDER)
	shear.disabled = not ready

func _mix_fodder() -> void:
	if Global.use_sheepfold(Sheepfold.Action.MIX_FODDER):
		receipt.text = "草料已备好。"
		_refresh()
		AudioManager.play_ui_sfx()

func _shear() -> void:
	if Global.use_sheepfold(Sheepfold.Action.SHEAR):
		receipt.text = "收好一份羊毛。西市绸摊收羊毛，也可以请蔡娘织衣。"
		_refresh()
