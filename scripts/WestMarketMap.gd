extends "res://scripts/SurveyMap.gd"

const MARKET_BOUNDS := Rect2(-236, -132, 490, 272)
const INK := Color("#483e2c")
const GOLD := Color("#f0cc7b")
const MERCHANT := VisitorData.SILK_MERCHANT
const WAYPOINT_ARROWS := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
const STALL_COLORS := [Color("#b98b53"), Color("#678287"), Color("#a46048")]
const STALL_SERVICES := ["作物换粮、买粮", "交留鱼单、卖鱼", "卖绸、交易羊毛"]

@onready var chart: Control = %Chart
@onready var paper: Control = %MapInk
@onready var open_button: Button = %OpenMap
@onready var cancel_button: Button = %CancelDirections
@onready var clear_button: Button = %ClearRoute
@onready var route_status: Label = %RouteStatus
@onready var merchant_button: Button = %FindMerchant

var market: Node2D
var player: Player
var ground: Node2D
var pin: Node2D
var places: Dictionary[String, Vector2] = {}
var markers: Dictionary[String, Button] = {}

func setup(street: Node2D, destinations: Dictionary[String, Vector2], waypoint: Node2D) -> void:
	market = street
	player = market.player
	ground = market.ground
	places = destinations
	pin = waypoint
	pin.draw.connect(_draw_waypoint)
	for place in places:
		var button := Button.new()
		button.text = place
		button.tooltip_text = _service(place)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.toggle_mode = true
		button.pressed.connect(_select_place.bind(place))
		chart.add_child(button)
		markers[place] = button
	open_button.pressed.connect(open_map)
	cancel_button.pressed.connect(_clear)
	clear_button.pressed.connect(_clear)
	merchant_button.icon = CharacterArt.dialogue_portrait(MERCHANT, null, true)
	merchant_button.pressed.connect(_select_place.bind(MERCHANT))
	chart.resized.connect(_layout_markers)
	paper.draw.connect(_draw_chart)
	_refresh_destination()

func _refresh_shortcuts() -> void:
	super._refresh_shortcuts()
	open_button.text = "西市舆图  %s" % ("Y" if GamepadInput.active else Preferences.key_label(KeyBindings.MAP))

func _map_available() -> bool:
	return not player.conversation_open and not MapTravel.active and Global.outcome == Global.Outcome.RUNNING

func _refresh_on_open() -> void:
	merchant_button.visible = market.silk_guest != null or market.silk_trip == VisitorData.SilkTrip.WEST_ROAD
	merchant_button.tooltip_text = _merchant_note()
	_layout_markers()
	_refresh_destination()

func _process(_delta: float) -> void:
	var available := _map_available()
	open_button.disabled = not available
	var place := Global.market_trip_target
	cancel_button.visible = available and not modal.visible and not place.is_empty()
	pin.visible = cancel_button.visible
	if not pin.visible:
		return
	var label := place
	var point: Vector2
	if place == MERCHANT and market.silk_guest:
		point = ground.to_local(market.silk_guest.global_position)
	elif place == MERCHANT:
		var next := _merchant_waiting_stop()
		point = places[next]
		label = "陶辛 · 午时到绸摊" if next != Global.MARKET_RETURN else "回封地找陶辛"
	else:
		point = places[place]
	pin.global_position = ground.to_global(point)
	var delta := pin.global_position - player.global_position
	var bearing: String = WAYPOINT_ARROWS[posmod(roundi(delta.angle() / (PI / 4.0)), WAYPOINT_ARROWS.size())]
	cancel_button.text = "%s  %s · 取消指路" % ["◆" if delta.length() < 12.0 else bearing, label]

func _merchant_waiting_stop() -> String:
	return MarketStall.TITLES[MarketStall.Kind.SILK] if market.silk_trip == VisitorData.SilkTrip.WEST_ROAD else Global.MARKET_RETURN

func _merchant_note() -> String:
	match market.silk_trip:
		VisitorData.SilkTrip.WEST_ROAD:
			return "午时到绸摊"
		VisitorData.SilkTrip.STALL:
			return "正走向绸摊" if market.silk_guest and market.silk_guest.walking_to_stop else "在绸摊理货"
		VisitorData.SilkTrip.RETURN_ROAD:
			return "向东返程，酉时到南路亭"
		VisitorData.SilkTrip.PAVILION:
			return "已回封地，去南路亭"
	return "回封地后按邻里手记找他"

func _select_place(place: String) -> void:
	Global.market_trip_target = place
	Global.ravine_trip_target = ""
	Global.field_route_status = -1
	_refresh_destination()

func arrive_at(place: String) -> void:
	if Global.market_trip_target == place:
		_clear()

func _clear() -> void:
	Global.market_trip_target = ""
	_refresh_destination()

func _refresh_destination() -> void:
	var place := Global.market_trip_target
	clear_button.disabled = place.is_empty()
	for name in markers:
		markers[name].set_pressed_no_signal(name == place)
	merchant_button.set_pressed_no_signal(place == MERCHANT)
	route_status.text = "点选去处，回到街上后看金色标记。" if place.is_empty() else "%s · %s" % [place, _service(place)]
	paper.queue_redraw()

func _service(place: String) -> String:
	match place:
		MERCHANT:
			return _merchant_note()
		Global.MARKET_RETURN:
			return "沿石板街向东出关"
		Global.MARKET_ORDERS:
			return "查看时令单、交货"
	return STALL_SERVICES[MarketStall.TITLES.find(place)]

func _scale() -> float:
	var usable := chart.size - Vector2(52.0, 36.0)
	return minf(usable.x / MARKET_BOUNDS.size.x, usable.y / MARKET_BOUNDS.size.y)

func _map_point(foot: Vector2) -> Vector2:
	return chart.size * 0.5 + (foot - MARKET_BOUNDS.get_center()) * _scale()

func _map_outline(points: PackedVector2Array) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for point in points:
		outline.append(_map_point(point))
	return outline

func _layout_markers() -> void:
	for place in markers:
		var button := markers[place]
		button.size = button.get_combined_minimum_size().max(Vector2(92, 33))
		var vertical := -83.0 if place in MarketStall.TITLES else 21.0
		button.position = (_map_point(places[place]) + Vector2(-button.size.x * 0.5, vertical)).round()
	paper.queue_redraw()

func _draw_chart() -> void:
	var sheet := Rect2(Vector2.ZERO, chart.size)
	paper.draw_rect(sheet, Color("#dbd0ae"))
	for foot: Vector2 in ground.TREE_FEET:
		var at := _map_point(foot)
		paper.draw_circle(at, 11.0, Color("#b8b995"), true, -1.0, true)
		paper.draw_circle(at + Vector2(-2, -4), 7.0, Color("#9ba77c"), true, -1.0, true)
	paper.draw_colored_polygon(_map_outline(ground.street), Color("#b99c6c"))
	paper.draw_colored_polygon(_map_outline(ground.paving), Color("#beb8a0"))
	for index in MarketStall.TITLES.size():
		var foot := places[MarketStall.TITLES[index]] - MarketStall.APPROACH
		var canopy := Rect2(_map_point(foot + Vector2(-34, -31)), Vector2(68, 28) * _scale())
		paper.draw_rect(canopy.grow(2.0), INK)
		paper.draw_rect(canopy, STALL_COLORS[index])
		for stripe in [1, 3, 5]:
			var width := canopy.size.x / 7.0
			var segment := Rect2(canopy.position + Vector2(width * stripe, 0), Vector2(width, canopy.size.y))
			paper.draw_rect(segment, STALL_COLORS[index].lightened(0.24))
	var destination := Global.market_trip_target
	if destination == MERCHANT and not market.silk_guest:
		destination = _merchant_waiting_stop()
	for place in places:
		var at := _map_point(places[place])
		if place not in MarketStall.TITLES:
			var button := markers[place]
			var label_edge := button.position + Vector2(button.size.x * 0.5, 0.0)
			paper.draw_line(at, label_edge, INK, 1.0, true)
		var selected := place == destination
		paper.draw_circle(at, 6.0 if selected else 4.0, INK)
		if selected:
			paper.draw_circle(at, 3.5, GOLD)
	if market.silk_guest:
		_draw_merchant()
	var here := _map_point(ground.to_local(player.global_position))
	paper.draw_circle(here, 8.0, Color("#2e4a42"))
	paper.draw_circle(here, 5.0, Color("#e7f0ce"))
	paper.draw_arc(here, 11.0, 0.0, TAU, 24, Color("#426c5d"), 1.5, true)
	paper.draw_rect(sheet.grow(-1.0), Color("#8c7c5f"), false, 2.0)

func _draw_merchant() -> void:
	var foot := _map_point(ground.to_local(market.silk_guest.global_position))
	var portrait := Rect2(foot + Vector2(-14, -46), Vector2(28, 28))
	var ink := GOLD if Global.market_trip_target == MERCHANT else Color("#516779")
	paper.draw_rect(portrait.grow(2.0), ink)
	paper.draw_texture_rect(merchant_button.icon, portrait, false)
	paper.draw_line(foot, foot + Vector2(0, -18), ink, 1.5, true)
	paper.draw_circle(foot, 5.0, INK)
	paper.draw_circle(foot, 3.0, ink)

func _draw_waypoint() -> void:
	pin.draw_circle(Vector2.ZERO, 7.5, Color("#263527"), false, 3.4, true)
	pin.draw_circle(Vector2.ZERO, 7.5, GOLD, false, 1.8, true)
	pin.draw_colored_polygon(PackedVector2Array([Vector2(0, -15), Vector2(4, -11),
		Vector2(0, -7), Vector2(-4, -11)]), GOLD)
