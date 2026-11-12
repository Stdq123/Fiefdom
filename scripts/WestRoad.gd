extends Node2D

const LAYOUT := preload("res://scripts/WestRoadLayout.gd")
const GROUND := preload("res://scripts/WestRoadGround.gd")
const TRACK_AUDIO := preload("res://scripts/TerrainAudio.gd")
const SIGN_MATERIAL := preload("res://resources/world_hint_material.tres")
const GOLD := Color("#f0cc7b")

@onready var player: Player = $Player
@onready var ground: GROUND = $Ground
@onready var settings: Panel = %Settings
@onready var audio: TRACK_AUDIO = AudioManager.terrain_audio

var route_direction := Vector2.ZERO

func _ready() -> void:
	$MarketGate.position = LAYOUT.MARKET_GATE
	$EstateGate.position = LAYOUT.ESTATE_GATE
	$MarketArrival.position = LAYOUT.MARKET_GATE + Vector2(33, 0)
	$EstateArrival.position = LAYOUT.ESTATE_GATE - Vector2(33, 0)
	player.arrive_at($MarketArrival if Global.restored_west_road_from_market else $EstateArrival)
	Global.restored_west_road_from_market = false
	ground.place_scenery($Scenery)
	for foot: Vector2 in [Vector2(-243, 59), Vector2(245, 60), Vector2(-58, 58), Vector2(54, 59)]:
		$DayLighting.place_lamp($Scenery, foot, 0.82)
	_place_sign(LAYOUT.MARKET_GATE + Vector2(15, -48), "← 西市")
	_place_sign(LAYOUT.ESTATE_GATE + Vector2(-16, -48), "封地 →")
	$Waypoint.draw.connect(_draw_waypoint)
	player.footstep.connect(_step)
	settings.save_resume_hint = "续档时从溪桥道较近的一侧路口继续。"
	%SettingsButton.pressed.connect(settings.show)
	settings.visibility_changed.connect(_update_modal)
	GameEvents.daylight_changed.connect(_refresh_clock)
	_refresh_clock()

func _process(delta: float) -> void:
	if not player.conversation_open and not MapTravel.active:
		Global.advance_daylight(delta)
		Global.advance_away_field_work(delta)
	$DayLighting.refresh(delta)
	AudioManager.set_world_ambience(ground.creek_distance(player.position),
		player.position.distance_to(Vector2(169, -46)), player.position.distance_to(Vector2(-125, 71)))

func _unhandled_key_input(event: InputEvent) -> void:
	if not settings.visible and event.is_action_pressed("ui_cancel"):
		settings.show()
		get_viewport().set_input_as_handled()

func _update_modal() -> void:
	%SettingsShade.visible = settings.visible
	player.conversation_open = settings.visible

func resume_from_market() -> bool:
	return player.position.distance_squared_to(LAYOUT.MARKET_GATE) < player.position.distance_squared_to(LAYOUT.ESTATE_GATE)

func _refresh_clock() -> void:
	%Date.text = "第 %d 天  ·  %s  ·  %s" % [Global.current_day, Global.get_current_solar_term(), Global.day_watch_label()]
	var target := Global.market_trip_target
	var guest := Global.visitor_for_day(Global.current_day) if target == VisitorData.SILK_MERCHANT else null
	var silk_trip := guest.silk_trip() if guest else VisitorData.SilkTrip.NONE
	if not Global.ravine_trip_target.is_empty():
		%Route.text = "竹涧 · %s →" % Global.ravine_trip_target
		route_direction = Vector2.RIGHT
	elif target == Global.MARKET_RETURN:
		%Route.text = "回封地 →"
		route_direction = Vector2.RIGHT
	elif silk_trip in [VisitorData.SilkTrip.RETURN_ROAD, VisitorData.SilkTrip.PAVILION]:
		%Route.text = "封地 · 陶辛 →"
		route_direction = Vector2.RIGHT
	elif not target.is_empty():
		%Route.text = "← 西市 · %s" % target
		route_direction = Vector2.LEFT
	else:
		%Route.text = ""
		route_direction = Vector2.ZERO
	%Route.visible = route_direction != Vector2.ZERO
	$Waypoint.queue_redraw()

func _draw_waypoint() -> void:
	if route_direction == Vector2.ZERO:
		return
	for point: Vector2 in LAYOUT.ROAD.slice(1, -1):
		var head := point + route_direction * 3.0
		var tail := point - route_direction * 3.0
		$Waypoint.draw_polyline(PackedVector2Array([tail - Vector2(0, 4), head, tail + Vector2(0, 4)]), GOLD, 1.5)

func _place_sign(point: Vector2, caption: String) -> void:
	var sign := Label.new()
	sign.text = caption
	sign.position = point - Vector2(44, 16)
	sign.size.x = 88.0
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.material = SIGN_MATERIAL
	sign.z_index = 4
	sign.add_theme_font_size_override("font_size", 10)
	sign.add_theme_color_override("font_color", Color("#e5d9b0"))
	sign.add_theme_color_override("font_outline_color", Color("#263827"))
	sign.add_theme_constant_override("outline_size", 3)
	add_child(sign)

func _step(foot: Vector2) -> void:
	var surface := TRACK_AUDIO.Surface.GRASS
	if LAYOUT.BRIDGE.has_point(foot):
		surface = TRACK_AUDIO.Surface.PLANK
	elif Geometry2D.is_point_in_polygon(foot, ground.pavement):
		surface = TRACK_AUDIO.Surface.STONE
	elif Geometry2D.is_point_in_polygon(foot, ground.track):
		surface = TRACK_AUDIO.Surface.TRACK
	audio.play_step(surface)
