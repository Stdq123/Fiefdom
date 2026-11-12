extends PanelContainer

@onready var icon: TextureRect = %FishIcon
@onready var title: Label = %OfferTitle
@onready var note: Label = %OfferNote
@onready var status: Label = %OfferStatus
@onready var tradeoff: Label = %Tradeoff
@onready var copper_button: Button = %TradeCopper
@onready var food_button: Button = %TradeFood
@onready var directions: Button = %OfferDirections

var at_stall := false
var start_day := 0
var shore := ""

func _ready() -> void:
	copper_button.pressed.connect(_deliver.bind(false))
	food_button.pressed.connect(_deliver.bind(true))
	directions.pressed.connect(_follow_offer)

func refresh() -> void:
	visible = Global.knows_ravine_journal() or not Global.fish_collection.is_empty()
	if not visible:
		return
	var offer := Global.fish_market_offer()
	var receipt: Dictionary = offer.receipt
	var pending := receipt.is_empty()
	var fish: String = offer.fish if pending else receipt.fish
	var species: Dictionary = CreekFish.SPECIES[fish]
	var count := Global.fish_count(fish)
	start_day = offer.start
	icon.texture = CreekFish.portrait(fish)
	title.text = "渔生留鱼 · 一尾%s" % species.name if pending else "渔生留鱼 · 已交"
	note.text = offer.request if pending else offer.thanks
	copper_button.visible = at_stall and pending
	food_button.visible = copper_button.visible
	directions.visible = not at_stall and pending and Global.outcome == Global.Outcome.RUNNING
	tradeoff.hide()
	if not pending:
		status.text = "第 %d 天 · %s一尾 · %s +%d" % [receipt.day, species.name,
			"粮食" if receipt.for_food else "铜钱", receipt.amount]
		return

	copper_button.text = "交鱼 · %d 铜钱" % offer.copper
	food_button.text = "交鱼 · %d 份粮" % offer.food
	copper_button.disabled = count < 1 or Global.outcome != Global.Outcome.RUNNING
	food_button.disabled = copper_button.disabled
	status.text = "第 %d 天截止 · 鱼篓 %d 尾" % [offer.end, count]
	if not at_stall:
		status.text += " · 可换 %d 铜钱或 %d 份粮" % [offer.copper, offer.food]
	shore = Global.fishing_spot_today(fish) if count == 0 else ""
	var delivery := Global.season_order()
	if count == 1 and delivery.order.get("fish", "") == fish and Global.season_order_delivered_at(delivery) == 0:
		tradeoff.text = "交出这尾后，「%s」也会缺鱼。" % delivery.order.title
		tradeoff.show()
	if directions.visible:
		directions.text = "去西市交鱼" if count > 0 else "去%s钓鱼" % shore
		directions.visible = count > 0 or not shore.is_empty()
		var blocked := Global.fishing_block_reason() if count == 0 else ""
		directions.disabled = not blocked.is_empty()
		directions.tooltip_text = blocked
		if directions.visible and directions.disabled:
			status.text += "\n" + blocked

func _follow_offer() -> void:
	if shore.is_empty():
		GameEvents.west_market_directions_requested.emit(MarketStall.TITLES[MarketStall.Kind.FISH])
	else:
		GameEvents.ravine_trip_requested.emit(shore)

func _deliver(for_food: bool) -> void:
	if Global.deliver_fish_order(start_day, for_food):
		AudioManager.play_ui_sfx(1.12)
