extends "res://scripts/SurveyMap.gd"

const REGIONS := ["西市", "溪桥道", "封地", "竹涧"]
const PAPER := Color("#e2d6b2")
const INK := Color("#443c2a")
const GOLD := Color("#f2ca73")
const ROAD_INK := Color("#9b8660")
const WATER := Color("#6b9992")
const POINTS := [Vector2(97, 184), Vector2(266, 184), Vector2(449, 184), Vector2(636, 184)]
const TRAILS := [
	[Vector2(97, 184), Vector2(147, 186), Vector2(197, 175), Vector2(266, 184)],
	[Vector2(266, 184), Vector2(334, 191), Vector2(388, 188), Vector2(449, 184)],
	[Vector2(449, 184), Vector2(509, 177), Vector2(569, 170), Vector2(636, 184)],
]
const SHORTCUT := [Vector2(449, 184), Vector2(465, 232), Vector2(513, 265),
	Vector2(567, 265), Vector2(619, 240), Vector2(636, 184)]
const STREAM := [Vector2(242, -12), Vector2(235, 65), Vector2(247, 119), Vector2(257, 146),
	Vector2(267, 188), Vector2(254, 240), Vector2(235, 294), Vector2(239, 381)]
const RAVINE_STREAM := [Vector2(655, -12), Vector2(642, 56), Vector2(652, 105), Vector2(662, 150),
	Vector2(685, 207), Vector2(674, 265), Vector2(686, 318), Vector2(705, 381)]
const BUILDINGS := preload("res://assets/world/estate-buildings.svg")
const LOOKOUT := preload("res://assets/world/stone-lookout.svg")
const TREES := preload("res://assets/world/seasonal-trees.svg")
const MARKET_CHOICES := MarketStall.TITLES + [Global.MARKET_ORDERS]
const SEAL_RADIUS := 11.0
const HERE_RADIUS := 23.0
const MEADOW_ICON := Vector2(315, 245)

@onready var paper: Control = %Paper
@onready var destinations: HFlowContainer = %Destinations
@onready var place_title: Label = %PlaceTitle
@onready var local_button: Button = %LocalMap
@onready var road_button: Button = %RoadMap
@onready var route_label: Label = %Route
@onready var place_detail: Label = %PlaceDetail
@onready var route_button: Button = %Follow
@onready var clear_button: Button = %ClearDirections
@onready var region_buttons: HBoxContainer = %Regions

var region := Region.ESTATE
var selected := Region.ESTATE
var selected_place := ""
var local_map: Control
var controls_blocked: Callable
var active_trip: Callable
var choose_trip: Callable
var clear_trip: Callable
var uses_south_trail: Callable
var road_progress: Callable
var destination_buttons: Dictionary[String, Button] = {}

func _ready() -> void:
	super._ready()
	paper.draw.connect(_draw_chart)
	paper.resized.connect(paper.queue_redraw)
	paper.gui_input.connect(_select_region_on_map)
	for button: Button in region_buttons.get_children():
		button.pressed.connect(_browse.bind(button.get_index()))
	route_button.pressed.connect(_follow)
	clear_button.pressed.connect(_cancel_route)
	local_button.pressed.connect(func(): switch_to(local_map))
	road_button.pressed.connect(open_map)

func setup(current: Region, blocked: Callable, active: Callable, choose: Callable, clear: Callable,
		local: Control = null, south: Callable = Callable(), progress: Callable = Callable()) -> void:
	region = current
	local_map = local
	controls_blocked = blocked
	active_trip = active
	choose_trip = choose
	clear_trip = clear
	uses_south_trail = south
	road_progress = progress
	local_button.visible = local_map != null
	road_button.visible = region == Region.ROAD

func _map_available() -> bool:
	return not controls_blocked.call() and not MapTravel.active

func _open_from_shortcut() -> void:
	if local_map and local_map.modal.visible:
		local_map.close_map()
	elif not get_tree().paused and local_map:
		local_map.open_map()
	elif not get_tree().paused:
		open_map()

func _process(_delta: float) -> void:
	if region == Region.ROAD:
		road_button.visible = not modal.visible and not get_tree().paused and _map_available()

func _refresh_shortcuts() -> void:
	super._refresh_shortcuts()
	road_button.text = "区域舆图  %s" % ("Y" if GamepadInput.active else Preferences.key_label(KeyBindings.MAP))

func _refresh_on_open() -> void:
	var target := _active_destination()
	selected_place = target
	selected = region if target.is_empty() else _region_for(target)
	_refresh_selection()

func _region_for(place: String) -> Region:
	if place == Global.MARKET_RETURN:
		return Region.ESTATE
	if place == Sheepfold.MEADOW:
		return Region.ROAD
	return Region.RAVINE if place in Global.ravine_trip_places() else Region.MARKET

func _active_destination() -> String:
	var place: String = active_trip.call()
	var listed := (place in [Global.MARKET_RETURN, Sheepfold.MEADOW]
		or place in MARKET_CHOICES or place in Global.ravine_trip_places())
	return place if listed else ""

func _browse(index: int) -> void:
	selected = index as Region
	var active := _active_destination()
	selected_place = active if not active.is_empty() and _region_for(active) == selected else ""
	_refresh_selection()

func _select_region_on_map(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if Rect2(MEADOW_ICON - Vector2(45, 20), Vector2(90, 44)).has_point(event.position):
			_browse(Region.ROAD)
			_preview_destination(Sheepfold.MEADOW)
			return
		for index in POINTS.size():
			var point: Vector2 = POINTS[index]
			if Rect2(point - Vector2(45, 88), Vector2(90, 135)).has_point(event.position):
				_browse(index)
				return

func _refresh_selection() -> void:
	place_title.text = REGIONS[selected]
	for button: Button in region_buttons.get_children():
		button.set_pressed_no_signal(button.get_index() == selected)
		button.tooltip_text = "当前位置" if button.get_index() == region else ""
	for child in destinations.get_children():
		destinations.remove_child(child)
		child.queue_free()
	destination_buttons.clear()
	match selected:
		Region.ROAD:
			_add_destination(Sheepfold.MEADOW, Sheepfold.MEADOW, Global.meadow_status())
		Region.MARKET:
			for place: String in MARKET_CHOICES:
				_add_destination(place, place)
		Region.ESTATE:
			if region != Region.ESTATE:
				_add_destination(Global.MARKET_RETURN, "回封地")
		Region.RAVINE:
			for place: String in Global.ravine_trip_places():
				_add_destination(place, place, Global.ravine_place_detail(place))
	_refresh_route()

func _add_destination(place: String, caption: String, detail := "") -> void:
	var button := Button.new()
	button.text = caption
	button.tooltip_text = detail
	button.toggle_mode = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(0, 34)
	button.pressed.connect(_preview_destination.bind(place))
	destinations.add_child(button)
	destination_buttons[place] = button

func _preview_destination(place: String) -> void:
	selected_place = place
	_refresh_route()

func _refresh_route() -> void:
	for place in destination_buttons:
		destination_buttons[place].set_pressed_no_signal(place == selected_place)
	var active: String = active_trip.call()
	place_detail.text = Global.meadow_status() if selected_place == Sheepfold.MEADOW else ""
	clear_button.disabled = active.is_empty()
	route_button.disabled = selected_place.is_empty() or selected_place == active
	route_button.text = "开始指路" if selected_place.is_empty() else "指路去" + selected_place
	if selected_place == Global.MARKET_RETURN:
		route_button.text = "指路回封地"
	if not selected_place.is_empty() and selected_place == active:
		route_button.text = "正在指路"
	if selected_place.is_empty():
		match selected:
			Region.ROAD: route_label.text = "西侧通西市，向东过桥回封地。"
			Region.ESTATE when region == Region.ESTATE: route_label.text = "井田、邻居和堂前可在本地舆图查看。"
			_: route_label.text = "选一个去处，查看沿途经过的区域。"
	else:
		var names := PackedStringArray()
		for stop in _route_regions(_region_for(selected_place)):
			names.append(REGIONS[stop])
		route_label.text = " → ".join(names)
		var south := _uses_shortcut()
		if _region_for(selected_place) == Region.RAVINE and region != Region.RAVINE:
			route_label.text += " · 经" + (EstateLayout.RAVINE_TRAIL_NAME if south else "东关")
		elif region == Region.RAVINE and _region_for(selected_place) != Region.RAVINE:
			route_label.text += " · 经西门"
		if names.size() == 1:
			route_label.text = "在%s内前往%s" % [names[0], selected_place]
		if selected_place == active:
			route_label.text += " · 正在指路"
	paper.queue_redraw()

func _follow() -> void:
	if choose_trip.call(selected_place):
		close_map()
	else:
		route_label.text = "这里接不上山路，靠近一条路后再选。"

func _cancel_route() -> void:
	clear_trip.call()
	_refresh_route()

func _route_regions(destination: Region) -> Array[int]:
	var stops: Array[int] = [region]
	var direction := signi(destination - region)
	for offset in range(1, absi(destination - region) + 1):
		stops.append(region + direction * offset)
	return stops

func _uses_shortcut() -> bool:
	return uses_south_trail.is_valid() and selected == Region.RAVINE and not selected_place.is_empty() 		and uses_south_trail.call(selected_place)

func _draw_chart() -> void:
	var sheet := Rect2(Vector2.ZERO, paper.size)
	paper.draw_rect(sheet, PAPER)
	paper.draw_rect(sheet.grow(-7), Color("#b8a177"), false, 1.0)
	paper.draw_rect(sheet.grow(-11), Color("#c7b48a"), false, 1.0)
	for index in 116:
		var at := Vector2(19 + posmod(index * 193, int(paper.size.x) - 38),
			19 + posmod(index * 67, int(paper.size.y) - 38))
		paper.draw_rect(Rect2(at, Vector2(2, 1)), Color("#a9926240"))
	_draw_land()
	var highlighted: Array[int] = []
	if not selected_place.is_empty():
		highlighted = _route_regions(_region_for(selected_place))
	var south := _uses_shortcut()
	for index in TRAILS.size():
		var active := index in highlighted and index + 1 in highlighted and (index != Region.ESTATE or not south)
		_draw_road(TRAILS[index], active)
	if Global.ravine_shortcut_open():
		_draw_road(SHORTCUT, south)
		_draw_text("南路小径", Vector2(542, 286), 14, INK)
	_draw_meadow()
	_draw_bridge()
	_draw_landmarks()
	_draw_text("北", Vector2(680, 42), 15, INK)
	paper.draw_colored_polygon(PackedVector2Array([Vector2(680, 52), Vector2(674, 67), Vector2(680, 63), Vector2(686, 67)]), INK)
	for index in REGIONS.size():
		var at: Vector2 = POINTS[index]
		var current := index == region
		var target := index == selected
		paper.draw_circle(at, SEAL_RADIUS, INK, true, -1.0, true)
		paper.draw_circle(at, SEAL_RADIUS - 3.0, GOLD if target or index in highlighted else PAPER, true, -1.0, true)
		if current:
			if region == Region.ROAD:
				_draw_road_position(at, road_progress.call())
			else:
				paper.draw_arc(at, SEAL_RADIUS + 3.0, 0.0, TAU, 24, INK, 2.0, true)
				paper.draw_circle(at, 3.0, INK, true, -1.0, true)
		_draw_text(REGIONS[index], at + Vector2(0, 29), 20, INK)
		if current:
			_draw_text("当前位置", at + Vector2(0, 50), 14, Color("#586b4d"))

func _draw_road_position(bridge: Vector2, progress: float) -> void:
	var foot := bridge + Vector2(lerpf(-78.0, 78.0, progress), -HERE_RADIUS)
	paper.draw_line(foot + Vector2(0, 7), Vector2(foot.x, bridge.y), INK, 1.6, true)
	paper.draw_circle(foot, 8.0, INK, true, -1.0, true)
	paper.draw_circle(foot, 5.0, GOLD, true, -1.0, true)
	paper.draw_circle(foot, 2.0, INK, true, -1.0, true)

func _draw_meadow() -> void:
	var selected_meadow := selected_place == Sheepfold.MEADOW
	_draw_road([Vector2(306, 188), Vector2(314, 210), Vector2(309, 225), MEADOW_ICON], selected_meadow)
	paper.draw_circle(MEADOW_ICON, 7.5, INK, true, -1.0, true)
	paper.draw_circle(MEADOW_ICON, 4.0, GOLD if selected_meadow else PAPER, true, -1.0, true)
	_draw_text(Sheepfold.MEADOW, MEADOW_ICON + Vector2(5, 18), 14, INK)

func _draw_land() -> void:
	paper.draw_colored_polygon(PackedVector2Array([Vector2(23, 97), Vector2(54, 65), Vector2(128, 52),
		Vector2(200, 64), Vector2(234, 109), Vector2(210, 151), Vector2(80, 153), Vector2(27, 136)]), Color("#b8b18a"))
	paper.draw_colored_polygon(PackedVector2Array([Vector2(341, 133), Vector2(365, 75), Vector2(473, 64),
		Vector2(538, 97), Vector2(550, 151), Vector2(512, 224), Vector2(424, 250), Vector2(376, 213)]), Color("#c6c193"))
	paper.draw_colored_polygon(PackedVector2Array([Vector2(560, 91), Vector2(605, 70), Vector2(667, 79),
		Vector2(708, 131), Vector2(709, 268), Vector2(665, 299), Vector2(604, 264), Vector2(575, 213)]), Color("#a6ae84"))
	paper.draw_polyline(PackedVector2Array(STREAM), WATER.lightened(0.30), 20.0, true)
	paper.draw_polyline(PackedVector2Array(STREAM), WATER, 13.0, true)
	paper.draw_polyline(PackedVector2Array(RAVINE_STREAM), WATER.lightened(0.30), 20.0, true)
	paper.draw_polyline(PackedVector2Array(RAVINE_STREAM), WATER.darkened(0.09), 13.0, true)

func _draw_road(path: Array, highlighted: bool) -> void:
	var line := PackedVector2Array(path)
	paper.draw_polyline(line, INK if highlighted else ROAD_INK, 8.0 if highlighted else 5.0, true)
	if highlighted:
		paper.draw_polyline(line, GOLD, 4.0, true)

func _draw_bridge() -> void:
	var deck := Rect2(247, 175, 38, 18)
	paper.draw_rect(deck.grow(1), Color("#67533b"))
	paper.draw_rect(deck, Color("#c69d63"))
	for index in 7:
		paper.draw_line(deck.position + Vector2(3 + index * 5, 2),
			deck.position + Vector2(3 + index * 5, deck.size.y - 2), Color("#987346"), 1.0)

func _draw_landmarks() -> void:
	var stall := Rect2(59, 102, 76, 54)
	paper.draw_texture_rect_region(MarketStall.ART, stall, Rect2(Vector2.ZERO, MarketStall.FRAME))
	paper.draw_texture_rect_region(MarketStall.ART, stall, Rect2(Vector2(0, MarketStall.FRAME.y), MarketStall.FRAME))
	paper.draw_texture_rect_region(BUILDINGS, Rect2(406, 91, 86, 59), Rect2(0, 0, 128, 88))
	paper.draw_texture_rect(LOOKOUT, Rect2(602, 97, 47, 42), false)
	for at: Vector2 in [Vector2(170, 119), Vector2(204, 110), Vector2(309, 153), Vector2(346, 147),
			Vector2(357, 231), Vector2(494, 228), Vector2(575, 132), Vector2(595, 245), Vector2(687, 141)]:
		paper.draw_texture_rect_region(TREES, Rect2(at - Vector2(16, 30), Vector2(32, 32)), Rect2(96, 0, 48, 48))

func _draw_text(value: String, at: Vector2, font_size: int, color: Color) -> void:
	var font := paper.get_theme_default_font()
	var span := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	paper.draw_string(font, at + Vector2(-span.x * 0.5, font.get_ascent(font_size) * 0.5),
		value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
