extends Node2D

const TRACK_AUDIO := preload("res://scripts/TerrainAudio.gd")
const VISITOR := preload("res://scenes/Visitor.tscn")
const SILK_STALL_PATH := [Vector2(231, 31), Vector2(190, 28), Vector2(166, 34), Vector2(153, 43)]

@onready var player: Player = $Player
@onready var ground: Node2D = $Ground
@onready var lighting: CanvasModulate = $DayLighting
@onready var audio: TRACK_AUDIO = AudioManager.terrain_audio
@onready var counter: Control = %Counter
@onready var market_map: Control = $UI/Control/WestMarketMap
@onready var settings: Panel = %Settings
@onready var settings_shade: ColorRect = %SettingsShade
@onready var date: Label = %Date
@onready var stock: Label = %Stock
@onready var sample: Sprite2D = $Stalls/SilkStall/MarketSample
@onready var fish_sign: Node2D = $Stalls/FishStall/FishOrderSign
@onready var fish_icon: Sprite2D = $Stalls/FishStall/FishOrderSign/FishIcon

var silk_guest: Visitor
var guest_returning := false
var fish_reserved := false

func _ready() -> void:
	ground.place_scenery($Scenery)
	var destinations: Dictionary[String, Vector2] = {}
	for stall: MarketStall in $Stalls.get_children():
		stall.opened.connect(_open_stall)
		destinations[MarketStall.TITLES[stall.kind]] = ground.to_local(stall.to_global(MarketStall.APPROACH))
	destinations[Global.MARKET_ORDERS] = ground.to_local($OrderCart.to_global(Vector2(0, -16)))
	destinations[Global.MARKET_RETURN] = ground.to_local($EstateRoad.global_position)
	$OrderCart.opened.connect(_open_orders)
	for foot: Vector2 in [Vector2(-62, 6), Vector2(54, 4), Vector2(154, 13), Vector2(181, 55), Vector2(-148, 75)]:
		lighting.place_lamp($Scenery, foot, 0.82)
	player.arrive_at($EstateRoadArrival)
	player.footstep.connect(_step)
	market_map.setup(player, ground, destinations, $MarketWaypoint)
	$DialogManager.setup($UI/Control, player)
	%SettingsButton.pressed.connect(settings.show)
	counter.visibility_changed.connect(_update_modal)
	settings.visibility_changed.connect(_update_modal)
	GameEvents.daylight_changed.connect(_refresh_date)
	GameEvents.daylight_changed.connect(_refresh_silk_guest)
	GameEvents.visitor_interacted.connect(_talk_to_silk_guest)
	GameEvents.retainer_recruited.connect(_refresh_silk_guest.unbind(1))
	GameEvents.money_changed.connect(_refresh_stock.unbind(1))
	GameEvents.food_changed.connect(_refresh_stock.unbind(1))
	GameEvents.crop_harvested.connect(_refresh_stock.unbind(1))
	GameEvents.fish_changed.connect(_refresh_fish_sign)
	fish_sign.draw.connect(_draw_fish_sign)
	_refresh_date()
	_refresh_stock()
	sample.visible = VisitorData.silk_sample_on_display(Global.current_day)
	_refresh_silk_guest()
	_refresh_fish_sign()

func _open_stall(kind: MarketStall.Kind) -> void:
	market_map.arrive_at(MarketStall.TITLES[kind])
	counter.open_for(kind)

func _open_orders() -> void:
	market_map.arrive_at(Global.MARKET_ORDERS)
	counter.open_orders()

func _process(delta: float) -> void:
	if not player.conversation_open and not MapTravel.active:
		Global.advance_daylight(delta)
		Global.advance_away_field_work(delta)
	lighting.refresh(delta)
	var tree_line := Vector2(-183, -35)
	var distance := player.position.distance_to(tree_line)
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
	date.text = "第 %d 天  ·  %s  ·  %s" % [Global.current_day, Global.get_current_solar_term(), Global.day_watch_label()]

func _refresh_stock() -> void:
	stock.text = "%d 铜钱   ·   %d 粮食" % [Global.money, Global.food_storage]

func _refresh_fish_sign() -> void:
	fish_sign.visible = Global.knows_ravine_journal() or not Global.fish_collection.is_empty()
	if fish_sign.visible:
		var offer := Global.fish_market_offer()
		fish_reserved = not offer.receipt.is_empty()
		fish_icon.texture = CreekFish.portrait(offer.receipt.fish if fish_reserved else offer.fish)
		fish_icon.modulate = Color.WHITE if fish_reserved else Color("#a9af9e")
		fish_sign.queue_redraw()

func _draw_fish_sign() -> void:
	fish_sign.draw_rect(Rect2(-11, -7, 22, 15), Color("#49382c"))
	var board := Color("#d1a668") if fish_reserved else Color("#a88d65")
	fish_sign.draw_rect(Rect2(-10, -6, 20, 12), board)
	fish_sign.draw_rect(Rect2(-9, -5, 1, 2), Color("#5c523f"))
	fish_sign.draw_rect(Rect2(8, -5, 1, 2), Color("#5c523f"))

func _refresh_silk_guest() -> void:
	if not sample.visible:
		return
	var guest := Global.visitor_for_day(Global.current_day)
	var trip := guest.silk_trip() if guest else VisitorData.SilkTrip.NONE
	if trip not in [VisitorData.SilkTrip.STALL, VisitorData.SilkTrip.RETURN_ROAD]:
		_remove_silk_guest()
		return
	var returning := trip == VisitorData.SilkTrip.RETURN_ROAD
	if silk_guest and returning == guest_returning:
		return
	var path := PackedVector2Array(SILK_STALL_PATH)
	if returning:
		path.reverse()
	if not silk_guest:
		silk_guest = VISITOR.instantiate()
		silk_guest.name = VisitorData.SILK_MERCHANT
		silk_guest.data = guest
		silk_guest.position = path[0]
		add_child(silk_guest)
		silk_guest.activity_reached.connect(_on_silk_guest_arrived)
	guest_returning = returning
	var start := VisitorData.SILK_MARKET_LEAVE if returning else VisitorData.SILK_MARKET_ARRIVE
	var focus := path[-1] + Vector2.RIGHT if returning else sample.global_position
	silk_guest.go_to_activity(VisitorData.VisitActivity.SILK_MARKET, path, focus,
		true, VisitorData.seconds_since(start))
	if returning and not silk_guest.walking_to_stop:
		_remove_silk_guest()

func _on_silk_guest_arrived() -> void:
	if guest_returning:
		_remove_silk_guest()

func _remove_silk_guest() -> void:
	if silk_guest:
		silk_guest.queue_free()
		silk_guest = null

func _talk_to_silk_guest(data: VisitorData) -> void:
	if silk_guest and data == silk_guest.data:
		$DialogManager.show_visitor_dialog(data, VisitorData.SILK_MARKET_PLACE)

func _step(foot: Vector2) -> void:
	var surface := TRACK_AUDIO.Surface.GRASS
	if ground.is_on_paving(foot):
		surface = TRACK_AUDIO.Surface.STONE
	elif ground.is_on_street(foot):
		surface = TRACK_AUDIO.Surface.TRACK
	audio.play_step(surface)
