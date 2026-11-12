extends Node2D

const TRACK_AUDIO := preload("res://scripts/TerrainAudio.gd")

@onready var player: Player = $Player
@onready var ground: Node2D = $Ground
@onready var lighting: CanvasModulate = $DayLighting
@onready var audio: Node = $TerrainAudio
@onready var counter: Control = %Counter
@onready var settings: Panel = %Settings
@onready var settings_shade: ColorRect = %SettingsShade
@onready var date: Label = %Date
@onready var stock: Label = %Stock

func _ready() -> void:
	ground.place_scenery($Scenery)
	for stall: MarketStall in $Stalls.get_children():
		stall.opened.connect(counter.open_for)
	$OrderCart.opened.connect(counter.open_orders)
	for foot: Vector2 in [Vector2(-62, 6), Vector2(54, 4), Vector2(154, 13), Vector2(181, 55), Vector2(-148, 75)]:
		lighting.place_lamp($Scenery, foot, 0.82)
	player.arrive_at($EstateRoadArrival)
	player.footstep.connect(_step)
	%SettingsButton.pressed.connect(settings.show)
	counter.visibility_changed.connect(_update_modal)
	settings.visibility_changed.connect(_update_modal)
	GameEvents.daylight_changed.connect(_refresh_date)
	GameEvents.money_changed.connect(_refresh_stock.unbind(1))
	GameEvents.food_changed.connect(_refresh_stock.unbind(1))
	GameEvents.crop_harvested.connect(_refresh_stock.unbind(1))
	_refresh_date()
	_refresh_stock()

func _process(delta: float) -> void:
	if not player.conversation_open and not MapTravel.active:
		Global.advance_daylight(delta)
		Global.advance_away_field_work(delta)
	lighting.refresh(delta)
	var tree_line := Vector2(-183, -35)
	var distance := player.position.distance_to(tree_line)
	audio.update_ambience(delta, INF, Global.has_rain(), distance, distance, Global.dusk_amount(), false)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
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

func _step(foot: Vector2) -> void:
	var surface := TRACK_AUDIO.Surface.GRASS
	if ground.is_on_paving(foot):
		surface = TRACK_AUDIO.Surface.STONE
	elif ground.is_on_street(foot):
		surface = TRACK_AUDIO.Surface.TRACK
	audio.play_step(surface)
