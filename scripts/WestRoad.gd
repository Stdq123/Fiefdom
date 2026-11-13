extends Node2D

const LAYOUT := preload("res://scripts/WestRoadLayout.gd")
const GROUND := preload("res://scripts/WestRoadGround.gd")
const TRACK_AUDIO := preload("res://scripts/TerrainAudio.gd")
const VISITOR := preload("res://scenes/Visitor.tscn")
const SILK_JOURNEY := preload("res://scripts/SilkJourney.gd")
const TRACK_DIRECTION := preload("res://scripts/RoadNetwork.gd")
const SIGN_MATERIAL := preload("res://resources/world_hint_material.tres")
const GOLD := Color("#f0cc7b")

@onready var player: Player = $Player
@onready var ground: GROUND = $Ground
@onready var settings: Panel = %Settings
@onready var audio: TRACK_AUDIO = AudioManager.terrain_audio

var route_direction := Vector2.ZERO
var scheduled_guest: VisitorData
var silk_guest: Visitor
var network: TRACK_DIRECTION
var route := PackedVector2Array()
var route_origin := Vector2.INF

func _ready() -> void:
	$MarketGate.position = LAYOUT.MARKET_GATE
	$EstateGate.position = LAYOUT.ESTATE_GATE
	$MarketArrival.position = LAYOUT.MARKET_GATE + Vector2(33, 0)
	$EstateArrival.position = LAYOUT.ESTATE_GATE - Vector2(33, 0)
	player.arrive_at($MarketArrival if Global.restored_west_road_from_market else $EstateArrival)
	Global.restored_west_road_from_market = false
	ground.place_scenery($Scenery)
	network = TRACK_DIRECTION.new([LAYOUT.ROAD], self, player)
	scheduled_guest = Global.visitor_for_day(Global.current_day)
	$DialogManager.setup($UI/Control, player)
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
	GameEvents.visitor_interacted.connect(_talk_to_silk_guest)
	GameEvents.retainer_recruited.connect(_refresh_scheduled_guest.unbind(1))
	_refresh_clock()
	_sync_silk_guest()
	_refresh_route()

func _process(delta: float) -> void:
	if not player.conversation_open and not MapTravel.active:
		Global.advance_daylight(delta)
		Global.advance_away_field_work(delta)
	_sync_silk_guest()
	_refresh_route()
	$DayLighting.refresh(delta)
	AudioManager.set_world_ambience(ground.creek_distance(player.position),
		player.position.distance_to(Vector2(169, -46)), player.position.distance_to(Vector2(-125, 71)))

func _unhandled_key_input(event: InputEvent) -> void:
	if not player.conversation_open and event.is_action_pressed("ui_cancel"):
		settings.show()
		get_viewport().set_input_as_handled()

func _update_modal() -> void:
	%SettingsShade.visible = settings.visible
	player.conversation_open = settings.visible

func resume_from_market() -> bool:
	return player.position.distance_squared_to(LAYOUT.MARKET_GATE) < player.position.distance_squared_to(LAYOUT.ESTATE_GATE)

func _refresh_clock() -> void:
	%Date.text = "第 %d 天  ·  %s  ·  %s" % [Global.current_day, Global.get_current_solar_term(), Global.day_watch_label()]

func _refresh_scheduled_guest() -> void:
	scheduled_guest = Global.visitor_for_day(Global.current_day)
	_sync_silk_guest()

func _sync_silk_guest() -> void:
	var trip := scheduled_guest.silk_trip() if scheduled_guest else VisitorData.SilkTrip.NONE
	var offset := SILK_JOURNEY.road_offset(SILK_JOURNEY.Section.BRIDGE, trip)
	if offset < 0.0:
		if silk_guest:
			silk_guest.queue_free()
			silk_guest = null
		return
	if not silk_guest:
		silk_guest = VISITOR.instantiate()
		silk_guest.name = VisitorData.SILK_MERCHANT
		silk_guest.data = scheduled_guest
		silk_guest.position = SILK_JOURNEY.position_on(SILK_JOURNEY.Section.BRIDGE, offset)
		add_child(silk_guest)
	SILK_JOURNEY.walk(silk_guest, VisitorData.VisitActivity.SILK_BRIDGE, SILK_JOURNEY.Section.BRIDGE, offset)

func _talk_to_silk_guest(data: VisitorData) -> void:
	if silk_guest and data == silk_guest.data:
		if Global.market_trip_target == data.name:
			Global.market_trip_target = ""
		$DialogManager.show_visitor_dialog(data, VisitorData.SILK_BRIDGE_PLACE)

func _refresh_route() -> void:
	var target := Global.market_trip_target
	var tracking_guest := target == VisitorData.SILK_MERCHANT
	var silk_trip := scheduled_guest.silk_trip() if tracking_guest and scheduled_guest else VisitorData.SilkTrip.NONE
	if not tracking_guest or not silk_guest:
		route.clear()
		route_origin = Vector2.INF
	if not Global.ravine_trip_target.is_empty():
		%Route.text = "竹涧 · %s →" % Global.ravine_trip_target
		route_direction = Vector2.RIGHT
	elif target == Global.MARKET_RETURN:
		%Route.text = "回封地 →"
		route_direction = Vector2.RIGHT
	elif tracking_guest and silk_guest:
		var foot := silk_guest.position
		route_direction = Vector2(signf(foot.x - player.position.x), 0)
		%Route.text = ("← " if route_direction.x < 0.0 else "") + "陶辛 · 溪桥道" + (" →" if route_direction.x > 0.0 else "")
		if player.position.distance_to(route_origin) >= 3.0 or route.is_empty() or foot.distance_to(route[-1]) >= 2.0:
			route_origin = player.position
			route = network.route_between(route_origin, foot)
	elif silk_trip in [VisitorData.SilkTrip.RETURN_ROAD, VisitorData.SilkTrip.PAVILION]:
		%Route.text = "陶辛 · 南路亭 →"
		route_direction = Vector2.RIGHT
	elif tracking_guest and silk_trip == VisitorData.SilkTrip.NONE:
		%Route.text = "陶辛 · 回封地 →"
		route_direction = Vector2.RIGHT
	elif not target.is_empty():
		%Route.text = "← 西市 · %s" % target
		route_direction = Vector2.LEFT
	else:
		%Route.text = ""
		route_direction = Vector2.ZERO
	%Route.visible = not %Route.text.is_empty()
	$Waypoint.queue_redraw()

func _draw_waypoint() -> void:
	if route.size() >= 2:
		for index in range(1, route.size()):
			$Waypoint.draw_dashed_line(route[index - 1], route[index], GOLD, 1.5, 5.5)
		$Waypoint.draw_arc(route[-1], 10.0, 0.0, TAU, 24, GOLD, 1.5, true)
		return
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
