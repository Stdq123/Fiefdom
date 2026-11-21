extends Node2D

const LAYOUT := preload("res://scripts/WestRoadLayout.gd")
const GROUND := preload("res://scripts/WestRoadGround.gd")
const WOODEN_BRIDGE := preload("res://scripts/WoodenBridge.gd")
const TRACK_AUDIO := preload("res://scripts/TerrainAudio.gd")
const RAIN_VEIL := preload("res://scripts/RainVeil.gd")
const SCENERY_OCCLUSION := preload("res://scripts/SceneryOcclusion.gd")
const DAY_LIGHTING := preload("res://scripts/DayLighting.gd")
const WATER_SURFACE := preload("res://scripts/WaterSurface.gd")
const VISITOR := preload("res://scenes/Visitor.tscn")
const SILK_JOURNEY := preload("res://scripts/SilkJourney.gd")
const TRACK_DIRECTION := preload("res://scripts/RoadNetwork.gd")
const SURVEY := preload("res://scripts/SurveyMap.gd")
const GOLD := Color("#f0cc7b")

@onready var player: Player = $Player
@onready var ground: GROUND = $Ground
@onready var lighting: DAY_LIGHTING = $DayLighting
@onready var settings: Panel = %Settings
@onready var region_map: Control = $UI/Control/RegionMap
@onready var route_sign: TravelRouteSign = %RouteSign
@onready var audio: TRACK_AUDIO = AudioManager.terrain_audio

var route_direction := Vector2.ZERO
var scheduled_guest: VisitorData
var silk_guest: Visitor
var network: TRACK_DIRECTION
var route := PackedVector2Array()
var route_origin := Vector2.INF

func _ready() -> void:
	var rain: RAIN_VEIL = $Rain
	$MarketGate.position = LAYOUT.MARKET_GATE
	$EstateGate.position = LAYOUT.ESTATE_GATE
	$MarketArrival.position = LAYOUT.MARKET_GATE + Vector2(33, 0)
	$EstateArrival.position = LAYOUT.ESTATE_GATE - Vector2(33, 0)
	$FodderMeadow.position = LAYOUT.MEADOW
	player.arrive_at($MarketArrival if Global.restored_west_road_from_market else $EstateArrival)
	Global.restored_west_road_from_market = false
	var occlusion := SCENERY_OCCLUSION.new(player)
	add_child(occlusion)
	ground.place_scenery($Scenery, occlusion)
	add_child(WOODEN_BRIDGE.new(LAYOUT.BRIDGE))
	rain.add_surface(LAYOUT.BRIDGE.grow(-3.0), 8)
	if Global.has_rain():
		rain.add_puddles(ground.weather.bounds, ground.weather.patches)
	player.restore_walking_checkpoint(LAYOUT.BOUNDS)
	network = TRACK_DIRECTION.new([LAYOUT.ROAD, LAYOUT.MEADOW_TRACK], self, player)
	scheduled_guest = Global.visitor_for_day(Global.current_day)
	$DialogManager.setup($UI/Control, player)
	for foot: Vector2 in [Vector2(-243, 59), Vector2(245, 60)]:
		lighting.place_lamp($Scenery, foot, 0.82)
	var west_lamp := lighting.place_lamp($Scenery, Vector2(-58, 58), 0.82)
	var east_lamp := lighting.place_lamp($Scenery, Vector2(54, 59), 0.82)
	var creek: WATER_SURFACE = $Ground/WaterSurface
	creek.reflect_lantern(west_lamp.glow, Vector2(-23, 64))
	creek.reflect_lantern(east_lamp.glow, Vector2(4, 63))
	lighting.add_cloud_shadows(GROUND.BACKDROP)
	$Waypoint.draw.connect(_draw_waypoint)
	player.footstep.connect(_step)
	InterfaceFont.scale_reading_text(%Date)
	%SettingsButton.icon = HUDIcons.icon(HUDIcons.Symbol.SETTINGS)
	%SettingsButton.pressed.connect(settings.show)
	settings.visibility_changed.connect(_update_modal)
	region_map.setup(SURVEY.Region.ROAD, func(): return player.conversation_open, Global.regional_destination,
		_follow_region_destination, _clear_regional_trip, null, Callable(), _map_road_progress)
	$CampaignHUD.add_field_return(player, _follow_region_destination)
	region_map.road_button.icon = HUDIcons.icon(HUDIcons.Symbol.MAP)
	route_sign.setup(player, $CampaignHUD, _clear_regional_trip, region_map.road_button)
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
	lighting.refresh(delta)
	_refresh_ambience()

func _refresh_ambience() -> void:
	AudioManager.set_world_ambience(ground.creek_distance(player.position),
		player.position.distance_to(Vector2(169, -46)), player.position.distance_to(Vector2(-125, 71)), false, 1.15)

func _unhandled_key_input(event: InputEvent) -> void:
	if not player.conversation_open and event.is_action_pressed("ui_cancel"):
		settings.show()
		get_viewport().set_input_as_handled()

func _update_modal() -> void:
	%SettingsShade.visible = settings.visible
	player.conversation_open = settings.visible

func _follow_region_destination(place: String) -> bool:
	if place in Global.ravine_trip_places():
		Global.market_trip_target = ""
		Global.ravine_trip_target = place
	else:
		Global.ravine_trip_target = ""
		Global.market_trip_target = place
	Global.field_route_status = -1
	_refresh_route()
	return true

func _clear_regional_trip() -> void:
	Global.market_trip_target = ""
	Global.ravine_trip_target = ""
	_refresh_route()

func _map_road_progress() -> Vector2:
	var foot := player.position
	var across := clampf(inverse_lerp(LAYOUT.MARKET_GATE.x, LAYOUT.ESTATE_GATE.x, foot.x), 0.0, 1.0)
	var down := 0.0
	if foot.y > LAYOUT.MEADOW_JUNCTION.y + 12.0 and (Geometry2D.is_point_in_polygon(foot, ground.meadow_track)
			or Geometry2D.is_point_in_polygon(foot, PackedVector2Array(LAYOUT.MEADOW_EDGE))):
		down = clampf(inverse_lerp(LAYOUT.MEADOW_JUNCTION.y, LAYOUT.MEADOW.y, foot.y), 0.0, 1.0)
	return Vector2(across, down)

func resume_from_market() -> bool:
	return player.position.distance_squared_to(LAYOUT.MARKET_GATE) < player.position.distance_squared_to(LAYOUT.ESTATE_GATE)

func _refresh_clock() -> void:
	%Date.text = TravelHeading.date_caption()

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
		silk_guest.sprite.foot_planted.connect(_show_resident_step)
	SILK_JOURNEY.walk(silk_guest, VisitorData.VisitActivity.SILK_BRIDGE, SILK_JOURNEY.Section.BRIDGE, offset)

func _talk_to_silk_guest(data: VisitorData) -> void:
	if silk_guest and data == silk_guest.data:
		if Global.market_trip_target == data.name:
			Global.market_trip_target = ""
		$DialogManager.show_visitor_dialog(data, VisitorData.SILK_BRIDGE_PLACE)

func _refresh_route() -> void:
	var target := Global.market_trip_target
	var tracking_meadow := target == Sheepfold.MEADOW
	var tracking_field := target == Global.FIELD_RETURN
	var tracking_guest := target == VisitorData.SILK_MERCHANT
	var silk_trip := scheduled_guest.silk_trip() if tracking_guest and scheduled_guest else VisitorData.SilkTrip.NONE
	if not tracking_meadow and not tracking_field and (not tracking_guest or not silk_guest):
		route.clear()
		route_origin = Vector2.INF
	var destination := ""
	var next_step := ""
	if not Global.ravine_trip_target.is_empty():
		destination = "竹涧 · " + Global.ravine_trip_target
		next_step = "向东进封地，再走东关入竹涧。"
		route_direction = Vector2.RIGHT
	elif tracking_meadow:
		destination = Sheepfold.MEADOW
		next_step = "桥东岔口向南。"
		route_direction = Vector2.ZERO
		_route_to(LAYOUT.MEADOW, 5.0)
	elif target == Global.MARKET_RETURN:
		destination = "回封地"
		next_step = "沿桥道向东，到封地西关。"
		route_direction = Vector2.RIGHT
	elif tracking_field:
		destination = "封地 · " + Global.field_return_place_name()
		next_step = "沿金线向东，到封地西关。"
		route_direction = Vector2.RIGHT
		_route_to(LAYOUT.ESTATE_GATE, 8.0)
	elif target in Global.ESTATE_REGIONAL_STOPS:
		destination = "封地 · " + target
		next_step = "沿桥道向东，到封地西关。"
		route_direction = Vector2.RIGHT
	elif tracking_guest and silk_guest:
		var foot := silk_guest.position
		route_direction = Vector2(signf(foot.x - player.position.x), 0)
		destination = "陶辛 · 溪桥道"
		next_step = "沿金线去找路上的陶辛。"
		_route_to(foot, 3.0)
	elif silk_trip in [VisitorData.SilkTrip.RETURN_ROAD, VisitorData.SilkTrip.PAVILION]:
		destination = "陶辛 · 南路亭"
		next_step = "从封地西关回去，再到南路亭。"
		route_direction = Vector2.RIGHT
	elif tracking_guest and silk_trip == VisitorData.SilkTrip.NONE:
		destination = "回封地找陶辛"
		next_step = "沿桥道向东，到封地西关。"
		route_direction = Vector2.RIGHT
	elif not target.is_empty():
		destination = "西市 · " + target
		next_step = "沿桥道向西，到西市东口。"
		route_direction = Vector2.LEFT
	else:
		route_direction = Vector2.ZERO
	var direction := route_direction if route.is_empty() else TRACK_DIRECTION.next_direction(route, player.position)
	if tracking_meadow and not route.is_empty() and direction.is_zero_approx():
		next_step = ""
	route_sign.set_route(destination, next_step, direction)
	$Waypoint.queue_redraw()

func _route_to(foot: Vector2, refresh_distance: float) -> void:
	if player.position.distance_to(route_origin) >= refresh_distance or route.is_empty() or foot.distance_to(route[-1]) >= 2.0:
		route_origin = player.position
		route = network.route_between(route_origin, foot)

func _draw_waypoint() -> void:
	if route.size() >= 2:
		for index in range(1, route.size()):
			$Waypoint.draw_dashed_line(route[index - 1], route[index], GOLD, 1.5, 5.5)
		$Waypoint.draw_arc(route[-1], 10.0, 0.0, TAU, 24, GOLD, 1.5, true)
		return
	if route_direction == Vector2.ZERO:
		return
	for point: Vector2 in LAYOUT.ROAD.slice(1, -1) + [LAYOUT.BRIDGE.get_center()]:
		var head := point + route_direction * 3.0
		var tail := point - route_direction * 3.0
		$Waypoint.draw_polyline(PackedVector2Array([tail - Vector2(0, 4), head, tail + Vector2(0, 4)]), GOLD, 1.5)

func finish_meadow_route() -> void:
	if Global.market_trip_target == Sheepfold.MEADOW:
		_clear_regional_trip()

func _step(at: Vector2) -> void:
	var foot := player.footstep_contact(at)
	ground.weather.play_step(foot, player.get_real_velocity(), _surface_at(foot))

func _show_resident_step(foot: Vector2, movement: Vector2) -> void:
	ground.weather.show_resident_step(foot, movement, _surface_at(foot))

func _surface_at(foot: Vector2) -> TRACK_AUDIO.Surface:
	if LAYOUT.BRIDGE.has_point(foot):
		return TRACK_AUDIO.Surface.PLANK
	if ground.bridge_apron_at(foot) or Geometry2D.is_point_in_polygon(foot, ground.pavement):
		return TRACK_AUDIO.Surface.STONE
	if Geometry2D.is_point_in_polygon(foot, ground.track) or Geometry2D.is_point_in_polygon(foot, ground.meadow_track):
		return TRACK_AUDIO.Surface.TRACK
	return TRACK_AUDIO.Surface.GRASS
