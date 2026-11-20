extends "res://scripts/SurveyMap.gd"

const REGIONS := ["西市", "溪桥道", "封地", "竹涧"]
const PAPER := Color("#e2d6b2")
const INK := Color("#443c2a")
const GOLD := Color("#f2ca73")
const ROAD_INK := Color("#9b8660")
const PREVIEW_INK := Color("#315d54")
const WATER := Color("#6b9992")
const POINTS := [Vector2(97, 184), Vector2(266, 184), Vector2(449, 184), Vector2(636, 184)]
const ROAD_WEST := Vector2(188, 184)
const ROAD_EAST := Vector2(344, 184)
const MEADOW_TURN := Vector2(305, 184)
const MEADOW_BEND := Vector2(303, 221)
const MEADOW_ICON := Vector2(320, 254)
const MEADOW_TRAIL := [MEADOW_TURN, MEADOW_BEND, MEADOW_ICON]
const MAIN_TRAIL := [POINTS[0], Vector2(147, 186), ROAD_WEST, POINTS[1],
	MEADOW_TURN, ROAD_EAST, Vector2(388, 188), POINTS[2]]
const EAST_TRAIL := [POINTS[2], Vector2(509, 177), Vector2(569, 170), POINTS[3]]
const SHORTCUT := [POINTS[2], Vector2(465, 232), Vector2(513, 265),
	Vector2(567, 265), Vector2(619, 240), POINTS[3]]
const STREAM := [Vector2(242, -12), Vector2(235, 65), Vector2(247, 119), Vector2(257, 146),
	Vector2(267, 188), Vector2(254, 240), Vector2(235, 294), Vector2(239, 381)]
const RAVINE_STREAM := [Vector2(655, -12), Vector2(642, 56), Vector2(652, 105), Vector2(662, 150),
	Vector2(685, 207), Vector2(674, 265), Vector2(686, 318), Vector2(705, 381)]
const BUILDINGS := preload("res://assets/world/estate-buildings.svg")
const LOOKOUT := preload("res://assets/world/stone-lookout.svg")
const TREES := preload("res://assets/world/seasonal-trees.svg")
const MARKET_CHOICES := MarketStall.TITLES + [Global.MARKET_ORDERS]
const ESTATE_CHOICES := [Global.MARKET_RETURN] + Global.ESTATE_REGIONAL_STOPS
const SEAL_RADIUS := 11.0
const HERE_RADIUS := 23.0

@onready var paper: Control = %Paper
@onready var destinations: HFlowContainer = %Destinations
@onready var place_title: Label = %PlaceTitle
@onready var local_button: Button = %LocalMap
@onready var road_button: Button = %RoadMap
@onready var current_location: Label = %CurrentLocation
@onready var active_route: Label = %ActiveRoute
@onready var active_swatch: Control = %ActiveSwatch
@onready var route_label: Label = %Route
@onready var place_detail: Label = %PlaceDetail
@onready var preview_badge: Label = %PreviewBadge
@onready var preview_swatch: Control = %PreviewSwatch
@onready var route_button: Button = %Follow
@onready var clear_button: Button = %ClearDirections
@onready var region_buttons: HBoxContainer = %Regions
@onready var stall_art: Texture2D = load(MarketStall.ART_PATH)

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
	for label: Label in [current_location, active_route, route_label, place_detail, preview_badge]:
		InterfaceFont.scale_reading_text(label)
	paper.draw.connect(_draw_chart)
	paper.resized.connect(paper.queue_redraw)
	Preferences.reading_size_changed.connect(paper.queue_redraw)
	paper.gui_input.connect(_select_region_on_map)
	for swatch in [active_swatch, preview_swatch]:
		swatch.draw.connect(_draw_swatch.bind(swatch))
		swatch.resized.connect(swatch.queue_redraw)
	for button: Button in region_buttons.get_children():
		button.pressed.connect(_browse.bind(button.get_index()))
	route_button.pressed.connect(_follow)
	clear_button.pressed.connect(_cancel_route)
	local_button.pressed.connect(func(): switch_to(local_map, local_map.get_node("%RegionMap")))
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
	current_location.text = "当前位置 · " + REGIONS[region]
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
	if place in ESTATE_CHOICES:
		return Region.ESTATE
	if place == Sheepfold.MEADOW:
		return Region.ROAD
	return Region.RAVINE if place in Global.ravine_trip_places() else Region.MARKET

func _active_destination() -> String:
	var place: String = active_trip.call()
	var listed := (place in ESTATE_CHOICES or place == Sheepfold.MEADOW
		or place in MARKET_CHOICES or place in Global.ravine_trip_places())
	return place if listed else ""

func _browse(index: int) -> void:
	if selected != index and modal.is_visible_in_tree():
		AudioManager.play_menu_cue(AudioManager.MenuCue.PAGE)
	selected = index as Region
	var active := _active_destination()
	selected_place = active if not active.is_empty() and _region_for(active) == selected else ""
	_refresh_selection()

func _select_region_on_map(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if Rect2(MEADOW_ICON - Vector2(47, 18), Vector2(100, 56)).has_point(event.position):
			_browse(Region.ROAD)
			_preview_destination(Sheepfold.MEADOW)
			return
		for index in POINTS.size():
			var point: Vector2 = POINTS[index]
			if Rect2(point - Vector2(56, 88), Vector2(112, 135)).has_point(event.position):
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
			var work := Global.field_return_caption()
			if work.is_empty():
				_add_destination(Global.FIELD_RETURN, Global.FIELD_RETURN, "沿路走到第一块井田的田口")
			else:
				_add_destination(Global.FIELD_RETURN, "接着田务", work)
			_add_destination(Global.WATER_SOURCE, "水源", "到泉边查看引水与水利研习")
			if not Global.pending_freight_receipt().is_empty() or Global.market_trip_target == Global.FREIGHT_YARD:
				_add_destination(Global.FREIGHT_YARD, Global.FREIGHT_YARD, "货到后可和申禾交谈")
			if Global.pond_landing_day() > 0:
				_add_destination(Global.POND_LANDING, Global.POND_LANDING, "从南池西岸走上木台")
			if Global.winter_supper_route_open():
				_add_destination(WinterSupper.PLACE, WinterSupper.PLACE, "沿南池西岸去围炉石坪")
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
	var active_place := Global.field_return_place_name() if active == Global.FIELD_RETURN else active
	active_route.text = "当前未指路" if active_place.is_empty() else "当前指路 · " + active_place
	active_swatch.visible = not _active_destination().is_empty()
	preview_badge.visible = not selected_place.is_empty() and selected_place != active
	preview_swatch.visible = preview_badge.visible
	var destination: Button = destination_buttons.get(selected_place)
	place_detail.text = destination.tooltip_text if destination else ""
	if selected_place == Sheepfold.MEADOW:
		place_detail.text = Global.meadow_status()
	clear_button.disabled = active.is_empty()
	route_button.disabled = selected_place.is_empty() or selected_place == active
	route_button.text = "开始指路" if selected_place.is_empty() else "指路去" + selected_place
	if selected_place == Global.MARKET_RETURN:
		route_button.text = "指路回封地"
	elif selected_place == Global.FIELD_RETURN:
		var work := Global.field_return_caption()
		route_button.text = "指路回井田" if work.is_empty() else "接着田务"
		if not work.is_empty():
			place_detail.text = work
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
		var south := _uses_shortcut(selected_place)
		if _region_for(selected_place) == Region.RAVINE and region != Region.RAVINE:
			route_label.text += " · 经" + (EstateLayout.RAVINE_TRAIL_NAME if south else "东关")
		elif region == Region.RAVINE and _region_for(selected_place) != Region.RAVINE:
			route_label.text += " · 经南路小径" if south else " · 经西门"
		var place := Global.field_return_place_name() if selected_place == Global.FIELD_RETURN else selected_place
		if names.size() == 1:
			route_label.text = "在%s内前往%s" % [names[0], place]
		elif selected_place == Sheepfold.MEADOW:
			route_label.text += " → " + Sheepfold.MEADOW
		elif selected_place in Global.ESTATE_REGIONAL_STOPS:
			route_label.text += " → " + place
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

func _uses_shortcut(place: String) -> bool:
	return uses_south_trail.is_valid() and Global.ravine_shortcut_open() and not place.is_empty() \
		and (region == Region.RAVINE or _region_for(place) == Region.RAVINE) and uses_south_trail.call(place)

func _route_points(place: String, progress: Vector2) -> PackedVector2Array:
	if place.is_empty():
		return PackedVector2Array()
	var foot := _current_point(progress)
	var meadow := place == Sheepfold.MEADOW
	var on_meadow_trail := region == Region.ROAD and progress.y > 0.0
	var points := PackedVector2Array([foot])
	if on_meadow_trail:
		if meadow:
			if progress.y < 0.5:
				points.append(MEADOW_BEND)
			if foot != MEADOW_ICON:
				points.append(MEADOW_ICON)
			return points
		if progress.y > 0.5:
			points.append(MEADOW_BEND)
		points.append(MEADOW_TURN)
	var start := points[-1]
	var finish: Vector2 = MEADOW_TURN if meadow else POINTS[_region_for(place)]
	var eastern_leg := SHORTCUT if _uses_shortcut(place) else EAST_TRAIL
	# These roads are ordered west to east. Start and end may be inside a road segment.
	var trail: Array = MAIN_TRAIL + eastern_leg.slice(1)
	if finish.x < start.x:
		trail.reverse()
	var west := minf(start.x, finish.x)
	var east := maxf(start.x, finish.x)
	for vertex: Vector2 in trail:
		if vertex.x > west and vertex.x < east:
			points.append(vertex)
	if start != finish:
		points.append(finish)
	if meadow:
		points.append(MEADOW_BEND)
		points.append(MEADOW_ICON)
	return points

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
	for path: Array in [MAIN_TRAIL, EAST_TRAIL, MEADOW_TRAIL]:
		paper.draw_polyline(PackedVector2Array(path), ROAD_INK, 5.0, true)
	if Global.ravine_shortcut_open():
		paper.draw_polyline(PackedVector2Array(SHORTCUT), ROAD_INK, 5.0, true)
		_draw_text("南路小径", Vector2(542, 288), 14, INK)
	_draw_bridge()
	_draw_landmarks()
	_draw_seal(MEADOW_ICON, 7.5)
	for at: Vector2 in POINTS:
		_draw_seal(at, SEAL_RADIUS)
	var progress: Vector2 = road_progress.call() if region == Region.ROAD else Vector2.ZERO
	var active := _active_destination()
	var confirmed := _route_points(active, progress)
	var preview := _route_points(selected_place, progress) if selected_place != active else PackedVector2Array()
	if confirmed.size() > 1:
		_draw_active_route(paper, confirmed)
	if preview.size() > 1:
		_draw_preview_route(paper, preview)
	_draw_text(Sheepfold.MEADOW, MEADOW_ICON + Vector2(6, 21), 14, INK)
	_draw_text("北", Vector2(680, 42), 15, INK)
	paper.draw_colored_polygon(PackedVector2Array([Vector2(680, 52), Vector2(674, 67), Vector2(680, 63), Vector2(686, 67)]), INK)
	for index in REGIONS.size():
		var at: Vector2 = POINTS[index]
		_draw_text(REGIONS[index], at + Vector2(-9 if index == Region.ROAD else 0, 29), 20, INK)
	if not confirmed.is_empty():
		paper.draw_circle(confirmed[-1], 8.5, INK, true, -1.0, true)
		paper.draw_circle(confirmed[-1], 5.5, GOLD, true, -1.0, true)
	if not preview.is_empty():
		_draw_preview_marker(preview[-1])
	_draw_current_position(_current_point(progress))

func _current_point(progress: Vector2) -> Vector2:
	return _road_point(progress) if region == Region.ROAD else POINTS[region]

func _road_point(progress: Vector2) -> Vector2:
	if progress.y == 0.0:
		return ROAD_WEST.lerp(ROAD_EAST, progress.x)
	if progress.y < 0.5:
		return MEADOW_TURN.lerp(MEADOW_BEND, progress.y * 2.0)
	return MEADOW_BEND.lerp(MEADOW_ICON, progress.y * 2.0 - 1.0)

func _draw_current_position(foot: Vector2) -> void:
	var pin := foot - Vector2(0, HERE_RADIUS)
	paper.draw_colored_polygon(PackedVector2Array([pin + Vector2(-6, 3), pin + Vector2(6, 3), foot]), INK)
	paper.draw_circle(pin, 8.0, INK, true, -1.0, true)
	paper.draw_circle(pin, 5.0, Color("#fff3d7"), true, -1.0, true)
	paper.draw_circle(pin, 2.0, PREVIEW_INK, true, -1.0, true)

func _draw_seal(at: Vector2, radius: float) -> void:
	paper.draw_circle(at, radius, INK, true, -1.0, true)
	paper.draw_circle(at, radius - 2.5, PAPER, true, -1.0, true)

func _draw_preview_marker(at: Vector2) -> void:
	var shape := PackedVector2Array([
		at + Vector2(0, -12), at + Vector2(12, 0),
		at + Vector2(0, 12), at + Vector2(-12, 0), at + Vector2(0, -12),
	])
	paper.draw_polyline(shape, PAPER, 5.0, true)
	paper.draw_polyline(shape, PREVIEW_INK, 2.8, true)

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

func _draw_active_route(canvas: CanvasItem, line: PackedVector2Array) -> void:
	canvas.draw_polyline(line, INK, 10.0, true)
	canvas.draw_polyline(line, GOLD, 7.0, true)

func _draw_preview_route(canvas: CanvasItem, line: PackedVector2Array, ink := PREVIEW_INK) -> void:
	for index in range(1, line.size()):
		canvas.draw_dashed_line(line[index - 1], line[index], ink, 3.6, 7.0, true, true)

func _draw_swatch(swatch: Control) -> void:
	var mid := swatch.size.y * 0.5
	var line := PackedVector2Array([Vector2(2.0, mid), Vector2(swatch.size.x - 2.0, mid)])
	if swatch == active_swatch:
		_draw_active_route(swatch, line)
	else:
		_draw_preview_route(swatch, line, PREVIEW_INK.lightened(0.46))

func _draw_bridge() -> void:
	var deck := Rect2(247, 175, 38, 18)
	paper.draw_rect(deck.grow(1), Color("#67533b"))
	paper.draw_rect(deck, Color("#c69d63"))
	for index in 7:
		paper.draw_line(deck.position + Vector2(3 + index * 5, 2),
			deck.position + Vector2(3 + index * 5, deck.size.y - 2), Color("#987346"), 1.0)

func _draw_landmarks() -> void:
	var stall := Rect2(59, 102, 76, 54)
	paper.draw_texture_rect_region(stall_art, stall, Rect2(Vector2.ZERO, MarketStall.FRAME))
	paper.draw_texture_rect_region(stall_art, stall, Rect2(Vector2(0, MarketStall.FRAME.y), MarketStall.FRAME))
	paper.draw_texture_rect_region(BUILDINGS, Rect2(406, 91, 86, 59), Rect2(0, 0, 128, 88))
	paper.draw_texture_rect(LOOKOUT, Rect2(602, 97, 47, 42), false)
	for at: Vector2 in [Vector2(170, 119), Vector2(204, 110), Vector2(309, 153), Vector2(346, 147),
			Vector2(357, 231), Vector2(494, 228), Vector2(575, 132), Vector2(595, 245), Vector2(687, 141)]:
		paper.draw_texture_rect_region(TREES, Rect2(at - Vector2(16, 30), Vector2(32, 32)), Rect2(96, 0, 48, 48))

func _draw_text(value: String, at: Vector2, font_size: int, color: Color) -> void:
	var font := paper.get_theme_default_font()
	font_size = Preferences.reading_font_size(font_size)
	var span := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	paper.draw_string(font, at + Vector2(-span.x * 0.5, font.get_ascent(font_size) * 0.5),
		value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
