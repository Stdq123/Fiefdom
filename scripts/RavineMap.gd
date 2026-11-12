extends "res://scripts/SurveyMap.gd"

const LANDSCAPE := preload("res://scripts/Landscape.gd")
const INK := Color("#403b29")
const PATH_INK := Color("#934b2e")
const MAP_MARGIN := Vector2(20, 20)
const JOURNAL_SUFFIX := "水迹"
const ESTATE_EXIT := "西门回封地"

@onready var chart: Control = %Chart
@onready var paper: Control = %MapInk
@onready var open_button: Button = %OpenMap
@onready var journal_button: Button = %JournalSite
@onready var trap_button: Button = %TrapSite
@onready var cancel_button: Button = %CancelDirections
@onready var clear_button: Button = %ClearRoute
@onready var route_status: Label = %RouteStatus
@onready var fish_delivery: Button = %FishDelivery
@onready var season_delivery: Button = %SeasonDelivery

var guide: Node2D
var player: Player
var landscape: LANDSCAPE
var places: Dictionary[String, Vector2] = {}
var markers: Dictionary[String, Button] = {}

func _refresh_shortcuts() -> void:
	super._refresh_shortcuts()
	open_button.text = "竹涧舆图  %s" % ("Y" if GamepadInput.active else Preferences.key_label(KeyBindings.MAP))

func setup(trail_guide: Node2D, walker: Player, terrain: LANDSCAPE, destinations: Dictionary[String, Vector2]) -> void:
	guide = trail_guide
	player = walker
	landscape = terrain
	places = destinations
	var trap_icon := CreekTrap.icon()
	for place in places:
		var button := Button.new()
		if place in CreekTrap.PLACES:
			button.icon = trap_icon
			button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			button.accessibility_name = place
		else:
			button.text = place
		if place == RavineLayout.SOUTH_TRAIL_NAME:
			button.disabled = not Global.ravine_shortcut_open()
			button.tooltip_text = "交完三处水迹后通封地南路" if button.disabled else "回封地南路灶台附近"
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.toggle_mode = true
		button.pressed.connect(_select_place.bind(place, places[place]))
		chart.add_child(button)
		markers[place] = button
	open_button.pressed.connect(open_map)
	journal_button.pressed.connect(_select_journal_site)
	trap_button.pressed.connect(_select_deployed_trap)
	cancel_button.pressed.connect(guide.clear)
	clear_button.pressed.connect(guide.clear)
	fish_delivery.pressed.connect(_select_market.bind(MarketStall.TITLES[MarketStall.Kind.FISH]))
	season_delivery.pressed.connect(_select_market.bind(Global.MARKET_ORDERS))
	chart.resized.connect(_layout_markers)
	paper.draw.connect(_draw_chart)
	guide.changed.connect(_refresh_route)
	GameEvents.ravine_journal_changed.connect(_refresh_journal)
	GameEvents.creek_trap_changed.connect(_refresh_traps)
	GameEvents.fish_changed.connect(_refresh_traps)
	_refresh_journal()
	_refresh_traps()
	_refresh_route()

func _map_available() -> bool:
	return is_instance_valid(player) and not player.conversation_open and not MapTravel.active

func _refresh_on_open() -> void:
	for place: String in Global.ravine_trip_places():
		var detail := Global.ravine_place_detail(place)
		markers[place].tooltip_text = place + "\n" + detail if place in CreekTrap.PLACES else detail
	var deliveries := Global.fish_delivery_places()
	fish_delivery.visible = MarketStall.TITLES[MarketStall.Kind.FISH] in deliveries
	season_delivery.visible = Global.MARKET_ORDERS in deliveries
	fish_delivery.get_parent().visible = not deliveries.is_empty()
	_refresh_route()
	_layout_markers()

func _on_campaign_ended(outcome: Global.Outcome) -> void:
	super._on_campaign_ended(outcome)
	guide.clear()

func _select_place(place: String, point: Vector2) -> void:
	if place == RavineLayout.SOUTH_TRAIL_NAME and not Global.ravine_shortcut_open():
		return
	if not guide.follow(place, point):
		_refresh_route()
		route_status.text = "这里接不上山路，靠近一条路后再选。"

func follow_place(place: String) -> void:
	_select_place(place, places[place])

func restore_waypoint(place: String) -> void:
	if places.has(place):
		follow_place(place)
	elif place.ends_with(JOURNAL_SUFFIX):
		var site := Global.ravine_site_today()
		if site >= 0 and place == RavineJournal.SITES[site].name + JOURNAL_SUFFIX:
			_select_journal_site()

func follow_market(place: String) -> bool:
	return guide.follow(ESTATE_EXIT, places[ESTATE_EXIT], place)

func _select_market(place: String) -> void:
	if follow_market(place):
		close_map()
	else:
		route_status.text = "这里接不上山路，靠近一条路后再选。"

func _select_deployed_trap() -> void:
	follow_place(CreekTrap.PLACES[Global.creek_trap_site()])

func _refresh_traps() -> void:
	for place: String in CreekTrap.PLACES:
		markers[place].visible = Global.creek_traps_unlocked()
	var site := Global.creek_trap_site()
	trap_button.visible = site >= 0
	if trap_button.visible:
		var forecast := Global.creek_trap_catch()
		var when := "可收" if Global.current_day >= forecast.day else "第 %d 天可收" % forecast.day
		trap_button.text = CreekTrap.PLACES[site] + " · " + when
	paper.queue_redraw()

func _select_journal_site() -> void:
	var site := Global.ravine_site_today()
	if site >= 0:
		var location: Dictionary = RavineJournal.SITES[site]
		_select_place(location.name + JOURNAL_SUFFIX, location.position)

func _refresh_journal() -> void:
	var site := Global.ravine_site_today()
	journal_button.visible = site >= 0
	if site >= 0:
		journal_button.text = "今日水迹 · " + RavineJournal.SITES[site].name
	elif guide.destination_name.ends_with(JOURNAL_SUFFIX):
		guide.clear()
	paper.queue_redraw()

func _refresh_route() -> void:
	var name: String = guide.destination_name
	var going_to_market := name == ESTATE_EXIT and not Global.market_trip_target.is_empty()
	var destination := "西市 · " + Global.market_trip_target if going_to_market else name
	cancel_button.visible = not name.is_empty()
	cancel_button.text = destination + " · 清除指路"
	clear_button.disabled = name.is_empty()
	for place in markers:
		markers[place].set_pressed_no_signal(place == name)
	if name.is_empty():
		route_status.text = "选一处地点，回到山路后沿标记走。"
	else:
		route_status.text = "前往" + destination
		if going_to_market:
			route_status.text += " · 经西门回封地"
		elif name == RavineLayout.SOUTH_TRAIL_NAME:
			route_status.text += " · 回封地南路"
		if guide.route.has(LANDSCAPE.BRIDGE):
			route_status.text += " · 经木桥"
		elif guide.route.has(LANDSCAPE.FORD):
			route_status.text += " · 经浅滩"
		if name in Global.ravine_trip_places():
			route_status.text += "\n" + Global.ravine_place_detail(name)
	paper.queue_redraw()

func _map_scale() -> float:
	var usable := chart.size - MAP_MARGIN * 2.0
	return minf(usable.x / LANDSCAPE.WILD_BOUNDS.size.x, usable.y / LANDSCAPE.WILD_BOUNDS.size.y)

func _map_point(point: Vector2) -> Vector2:
	return chart.size * 0.5 + (point - LANDSCAPE.WILD_BOUNDS.get_center()) * _map_scale()

func _map_line(points: PackedVector2Array) -> PackedVector2Array:
	var ink := PackedVector2Array()
	for point: Vector2 in points:
		ink.append(_map_point(point))
	return ink

func _layout_markers() -> void:
	for place in markers:
		var button := markers[place]
		button.size = button.get_combined_minimum_size()
		var offset := Vector2(-button.size.x / 2.0, 8)
		match place:
			"野果坳", "望溪台":
				offset.y = -button.size.y - 9
			"浅滩", SummerRaft.PLACE:
				offset = Vector2(-button.size.x - 13, -button.size.y / 2.0)
			RavineLayout.SOUTH_TRAIL_NAME:
				offset = Vector2(-button.size.x - 12, -button.size.y / 2.0)
			CreekFish.PLACES[CreekFish.Site.POOL], CreekFish.PLACES[CreekFish.Site.SHOAL]:
				offset = Vector2(14, -button.size.y / 2.0)
			CreekTrap.PLACES[CreekFish.Site.POOL]:
				offset = Vector2(14, -button.size.y - 5)
			CreekTrap.PLACES[CreekFish.Site.SHOAL]:
				offset = Vector2(14, 3)
		button.position = (_map_point(places[place]) + offset).round()
	paper.queue_redraw()

func _draw_chart() -> void:
	var sheet := Rect2(Vector2.ZERO, chart.size)
	paper.draw_rect(sheet, Color("#dbd0ae"))
	for prop: Vector3i in LANDSCAPE.WILD_PROPS:
		var foot := Vector2(prop.x, prop.y)
		if LANDSCAPE.WILD_BOUNDS.has_point(foot) and (prop.z in LANDSCAPE.LEAFY_PROPS or prop.z == LANDSCAPE.Prop.PINE):
			var at := _map_point(foot)
			paper.draw_circle(at, 6.0, Color("#a5ad85"))
			paper.draw_circle(at + Vector2(0, -3), 4.5, Color("#89976f"))
	paper.draw_colored_polygon(_map_line(PackedVector2Array(LANDSCAPE.GRAVEL_BAR)), Color("#b1ae92"))
	paper.draw_colored_polygon(_map_line(PackedVector2Array(RavineLayout.WILLOW_BANK)), Color("#b1ae92"))
	var creek := _map_line(PackedVector2Array(LANDSCAPE.CREEK))
	paper.draw_polyline(creek, Color("#a7b19c"), 51.0 * _map_scale(), true)
	paper.draw_polyline(creek, Color("#557e88"), 35.0 * _map_scale(), true)
	paper.draw_polyline(creek, Color("#90adb0"), 3.0, true)
	for track in landscape.track_shapes:
		paper.draw_colored_polygon(_map_line(track.shoulder), Color("#9b865f"))
	for track in landscape.track_shapes:
		paper.draw_colored_polygon(_map_line(track.surface), Color("#c7b388"))
	var marked := _map_line(guide.route)
	if marked.size() >= 2:
		paper.draw_polyline(marked, Color("#f7df9f"), 7.0, true)
		paper.draw_polyline(marked, PATH_INK, 4.0, true)
	for place in places:
		if markers[place].visible:
			var pin := _map_point(places[place])
			var button := markers[place]
			var edge := pin.clamp(button.position, button.position + button.size)
			paper.draw_line(pin, edge, INK, 1.0, true)
			paper.draw_circle(pin, 4.0, INK)
	var site := Global.ravine_site_today()
	if site >= 0:
		paper.draw_arc(_map_point(RavineJournal.SITES[site].position), 6.0, 0.0, TAU, 18, PATH_INK, 2.0, true)
	var here := _map_point(guide.to_local(player.global_position))
	paper.draw_circle(here, 8.0, INK)
	paper.draw_circle(here, 5.0, Color("#ffe19d"))
	paper.draw_arc(here, 11.0, 0.0, TAU, 22, Color("#826839"), 1.5, true)
	paper.draw_rect(sheet.grow(-1.0), Color("#8c7c5f"), false, 2.0)
