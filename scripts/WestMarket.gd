extends Node2D

const TRACK_AUDIO := preload("res://scripts/TerrainAudio.gd")
const VISITOR := preload("res://scenes/Visitor.tscn")
const LAYOUT := preload("res://scripts/WestMarketLayout.gd")
const GROUND := preload("res://scripts/WestMarketGround.gd")
const ORDER_CART := preload("res://scripts/SeasonOrderCart.gd")
const SILK_JOURNEY := preload("res://scripts/SilkJourney.gd")
const DYER := preload("res://scripts/MarketDyer.gd")
const RAIN_VEIL := preload("res://scripts/RainVeil.gd")
const SCENERY_OCCLUSION := preload("res://scripts/SceneryOcclusion.gd")
const DAY_LIGHTING := preload("res://scripts/DayLighting.gd")
const WATER_SURFACE := preload("res://scripts/WaterSurface.gd")
const FIXTURE_ART := preload("res://assets/world/west-market-fixtures.png")
const FISH_BOARD := Rect2(64, 64, 24, 18)

@onready var player: Player = $Player
@onready var ground: GROUND = $Ground
@onready var lighting: DAY_LIGHTING = $DayLighting
@onready var audio: TRACK_AUDIO = AudioManager.terrain_audio
@onready var counter: Control = %Counter
@onready var market_map: Control = $UI/Control/WestMarketMap
@onready var settings: Panel = %Settings
@onready var settings_shade: ColorRect = %SettingsShade
@onready var date: Label = %Date
@onready var stock: Label = %Stock
@onready var produce_sack: Sprite2D = $Stalls/GrainStall/ProduceSack
@onready var produce_tag: Sprite2D = $Stalls/GrainStall/ProduceSack/CropTag
@onready var sample: Sprite2D = $Stalls/SilkStall/MarketSample
@onready var fish_sign: Node2D = $Stalls/FishStall/FishOrderSign
@onready var fish_icon: Sprite2D = $Stalls/FishStall/FishOrderSign/FishIcon
@onready var dyer: DYER = $Dyer
@onready var dye_house: StaticBody2D = $DyeHouse
@onready var drying_rack: StaticBody2D = $DryingRack

var silk_guest: Visitor
var silk_trip := VisitorData.SilkTrip.NONE
var fish_reserved := false

func _ready() -> void:
	var rain: RAIN_VEIL = $Rain
	var occlusion := SCENERY_OCCLUSION.new(player)
	add_child(occlusion)
	ground.place_scenery($Scenery, occlusion)
	dye_house.position = LAYOUT.DYE_HOUSE
	drying_rack.position = LAYOUT.DYE_RACK
	rain.add_roof(dye_house, Rect2(-49, -40, 93, 41), [
		Vector3(-45, -39, 43), Vector3(-27, -39, 44), Vector3(25, -39, 44), Vector3(40, -39, 42),
	])
	$DyeHouse/Building.frame = int(Global.season_index() == Global.Season.WINTER)
	if Global.has_rain():
		dye_house.modulate = Color("#c0ced2")
		drying_rack.modulate = Color("#c4d1d3")
		rain.add_puddles(ground.weather.bounds, ground.weather.patches)
	dyer.approached.connect(_talk_to_dyer)
	occlusion.watch($DyeHouse/Building, dye_house)
	occlusion.watch($DryingRack/ClothLine, drying_rack)
	var destinations: Dictionary[String, Vector2] = {}
	for stall: MarketStall in $Stalls.get_children():
		stall.opened.connect(_open_stall)
		occlusion.watch(stall.counter_back, stall)
		occlusion.watch(stall.counter_front, stall)
		rain.add_roof(stall, Rect2(-46, -41, 91, 44), [Vector3(-44, -40, 46), Vector3(41, -40, 45)])
		var approach := ground.to_local(stall.to_global(MarketStall.APPROACH))
		destinations[MarketStall.TITLES[stall.kind]] = approach
		ground.add_stall_yard(stall.kind, approach, $Scenery)
	destinations[Global.MARKET_ORDERS] = ground.to_local($OrderCart.to_global(ORDER_CART.APPROACH))
	destinations[Global.MARKET_RETURN] = ground.to_local($EstateRoad.global_position)
	$OrderCart.opened.connect(_open_orders)
	for foot: Vector2 in [Vector2(-379, 112), Vector2(-118, -98), Vector2(208, 168),
			Vector2(264, 55), Vector2(-163, 110), Vector2(-53, 81), Vector2(379, 56)]:
		lighting.place_lamp($Scenery, foot, 0.82)
	lighting.place_lamp($Scenery, LAYOUT.DYE_EAVE + Vector2(-18, 4), 0.64, 0.08)
	var basin_lamp := lighting.place_lamp($Scenery, LAYOUT.BASIN.position + Vector2(32, -7), 0.69, 0.12)
	var basin_water: WATER_SURFACE = $Ground/BasinWater
	basin_water.reflect_lantern(basin_lamp.glow, LAYOUT.BASIN.position + Vector2(30, 6))
	lighting.refresh()
	player.arrive_at($EstateRoadArrival)
	player.restore_walking_checkpoint(LAYOUT.BOUNDS, ground.walking_fixture_footprints())
	player.footstep.connect(_step)
	market_map.setup(self, destinations, $MarketWaypoint)
	market_map.open_button.icon = HUDIcons.icon(HUDIcons.Symbol.MAP)
	$CampaignHUD.add_field_return(player, market_map.follow_region_destination)
	$DialogManager.setup($UI/Control, player)
	%SettingsButton.icon = HUDIcons.icon(HUDIcons.Symbol.SETTINGS)
	%CoinIcon.texture = HUDIcons.icon(HUDIcons.Symbol.COIN)
	%SettingsButton.pressed.connect(settings.show)
	counter.visibility_changed.connect(_update_modal)
	settings.visibility_changed.connect(_update_modal)
	GameEvents.daylight_changed.connect(_refresh_date)
	GameEvents.daylight_changed.connect(_refresh_silk_guest)
	GameEvents.daylight_changed.connect(_refresh_held_fish)
	GameEvents.daylight_changed.connect(_refresh_drying_rack)
	GameEvents.visitor_interacted.connect(_talk_to_silk_guest)
	GameEvents.ravine_trip_requested.connect(_follow_trip)
	GameEvents.west_market_directions_requested.connect(_follow_trip)
	GameEvents.water_source_directions_requested.connect(_follow_trip.bind(Global.WATER_SOURCE))
	GameEvents.retainer_recruited.connect(_refresh_silk_guest.unbind(1))
	GameEvents.money_changed.connect(_refresh_stock.unbind(1))
	GameEvents.food_changed.connect(_refresh_stock.unbind(1))
	GameEvents.crop_harvested.connect(_refresh_stock.unbind(1))
	GameEvents.crop_harvested.connect(_refresh_produce_sack.unbind(1))
	GameEvents.inventory_changed.connect(_refresh_produce_sack.unbind(1))
	GameEvents.fish_changed.connect(_refresh_fish_sign)
	GameEvents.fish_changed.connect(_refresh_held_fish)
	fish_sign.draw.connect(_draw_fish_sign)
	_refresh_date()
	_refresh_stock()
	var produce := ItemManager.season_item_picture(Global.market_produce_crop())
	produce_tag.texture = produce.texture
	produce_tag.self_modulate = produce.tint
	_refresh_produce_sack()
	sample.visible = VisitorData.silk_sample_on_display(Global.current_day)
	_refresh_silk_guest()
	_refresh_fish_sign()
	_refresh_held_fish()
	_refresh_drying_rack()

func _open_stall(kind: MarketStall.Kind) -> void:
	market_map.arrive_at(MarketStall.TITLES[kind])
	counter.open_for(kind)

func _open_orders() -> void:
	market_map.arrive_at(Global.MARKET_ORDERS)
	counter.open_orders()

func _follow_trip(place: String) -> void:
	market_map.follow_region_destination(place)
	counter.hide()

func _process(delta: float) -> void:
	if not player.conversation_open and not MapTravel.active:
		Global.advance_daylight(delta)
		Global.advance_away_field_work(delta)
	if silk_trip == VisitorData.SilkTrip.RETURN_ROAD and silk_guest:
		_sync_silk_return()
	lighting.refresh(delta)
	var distance: float = ground.distance_to_trees(player.global_position)
	AudioManager.set_world_ambience(INF, distance, distance)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if $UI/Control.has_node("DialoguePanel"):
		return
	if counter.visible:
		counter.hide()
	elif settings.visible:
		settings.hide()
	else:
		settings.show()
	get_viewport().set_input_as_handled()

func _update_modal() -> void:
	settings_shade.visible = settings.visible
	player.conversation_open = settings.visible or counter.visible

func _refresh_date() -> void:
	date.text = "第 %d 天 · %s · %s%s" % [Global.current_day, Global.day_watch_label(), Global.get_current_solar_term(),
		" · 雨" if Global.has_rain() else ""]

func _refresh_stock() -> void:
	stock.text = "%d 铜钱   ·   %d 粮食" % [Global.money, Global.food_storage]

func _refresh_produce_sack() -> void:
	var available := Global.market_produce_available()
	produce_sack.visible = Global.first_tribute_delivered()
	produce_sack.region_rect.position.x = 0.0 if available else 16.0
	produce_sack.scale.y = 1.3 if available else 0.65
	produce_tag.visible = available

func _refresh_fish_sign() -> void:
	fish_sign.visible = Global.knows_ravine_journal() or not Global.fish_collection.is_empty()
	if fish_sign.visible:
		var offer := Global.fish_market_offer()
		fish_reserved = not offer.receipt.is_empty()
		fish_icon.texture = CreekFish.portrait(offer.receipt.fish if fish_reserved else offer.fish)
		fish_icon.modulate = Color.WHITE if fish_reserved else Color("#a9af9e")
		fish_sign.queue_redraw()

func _refresh_held_fish() -> void:
	var waiting := Global.day_progress < CreekFish.ORDER_PICKUP and Global.fish_order_for_porter()
	ground.show_held_fish(Global.fish_order_receipt.fish if waiting else "")

func _refresh_drying_rack() -> void:
	var covered := Global.has_rain() or Global.day_progress >= DYER.CLOSE_YARD.x
	$DryingRack/ClothLine.frame = int(covered)
	ground.cover_dye_vats(covered)

func _talk_to_dyer() -> void:
	dyer.face_customer(player.global_position)
	$DialogManager.show_market_dyer(dyer.SPEAKER, dyer.remark(), dyer.portrait,
		_follow_trip.bind(MarketStall.TITLES[MarketStall.Kind.SILK]))

func _draw_fish_sign() -> void:
	var tint := Color.WHITE if fish_reserved else Color("#d8cfbc")
	fish_sign.draw_texture_rect_region(FIXTURE_ART, Rect2(Vector2(-12, -9), FISH_BOARD.size), FISH_BOARD, tint)

func _refresh_silk_guest() -> void:
	if not sample.visible:
		return
	var guest := Global.visitor_for_day(Global.current_day)
	silk_trip = guest.silk_trip() if guest else VisitorData.SilkTrip.NONE
	if silk_trip not in [VisitorData.SilkTrip.STALL, VisitorData.SilkTrip.RETURN_ROAD]:
		_remove_silk_guest()
		return
	if silk_trip == VisitorData.SilkTrip.RETURN_ROAD:
		if SILK_JOURNEY.road_offset(SILK_JOURNEY.Section.MARKET, silk_trip) >= 0.0:
			_add_silk_guest(guest, LAYOUT.TAO_STOP)
			_sync_silk_return()
		return
	if silk_guest:
		return
	var path := LAYOUT.silk_guest_path()
	_add_silk_guest(guest, path[0])
	silk_guest.go_to_activity(VisitorData.VisitActivity.SILK_MARKET, path, sample.global_position,
		true, VisitorData.seconds_since(VisitorData.SILK_MARKET_ARRIVE))

func _add_silk_guest(data: VisitorData, foot: Vector2) -> void:
	if silk_guest:
		return
	silk_guest = VISITOR.instantiate()
	silk_guest.name = VisitorData.SILK_MERCHANT
	silk_guest.data = data
	silk_guest.position = foot
	add_child(silk_guest)

func _sync_silk_return() -> void:
	var offset := SILK_JOURNEY.road_offset(SILK_JOURNEY.Section.MARKET, silk_trip)
	if offset < 0.0:
		_remove_silk_guest()
	else:
		SILK_JOURNEY.walk(silk_guest, VisitorData.VisitActivity.SILK_MARKET, SILK_JOURNEY.Section.MARKET, offset)

func _remove_silk_guest() -> void:
	if silk_guest:
		silk_guest.queue_free()
		silk_guest = null

func _talk_to_silk_guest(data: VisitorData) -> void:
	if silk_guest and data == silk_guest.data:
		market_map.arrive_at(data.name)
		$DialogManager.show_visitor_dialog(data, VisitorData.SILK_MARKET_PLACE)

func _step(foot: Vector2) -> void:
	var surface := TRACK_AUDIO.Surface.GRASS
	if ground.is_on_paving(foot):
		surface = TRACK_AUDIO.Surface.STONE
	elif ground.is_on_street(foot):
		surface = TRACK_AUDIO.Surface.TRACK
	ground.weather.play_step(foot, player.get_real_velocity(), surface)
