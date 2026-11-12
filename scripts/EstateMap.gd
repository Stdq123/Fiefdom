extends "res://scripts/SurveyMap.gd"

enum Category { PLACES, FIELDS, PEOPLE, RAVINE }

const LANDSCAPE := preload("res://scripts/Landscape.gd")
const PAPER := Color("#ded2ac")
const INK := Color("#3e3c2a")
const GOLD := Color("#f2ce78")
const WATER := Color("#386f74")
const DRY := Color("#865b42")
const PERSON := Color("#475e73")
const CAPTION_SIZE := 15
const MAP_MARGIN := 19.0

@onready var chart: Control = %Chart
@onready var tabs: HBoxContainer = %Tabs
@onready var field_routes: HBoxContainer = %FieldRoutes
@onready var harvest_route: Button = %HarvestRoute
@onready var water_route: Button = %WaterRoute
@onready var canal_route: Button = %CanalRoute
@onready var ravine_note: Label = %RavineNote
@onready var listing: VBoxContainer = %Listing
@onready var scroll: ScrollContainer = %IndexScroll
@onready var date: Label = %Date
@onready var status: Label = %DirectionStatus
@onready var clear_button: Button = %ClearDirections

var world: Node2D
var landscape: LANDSCAPE
var directions: Control
var controls_blocked: Callable
var tiles: TileMapLayer
var category := Category.PLACES
var places: Array[Dictionary] = []
var fields: Array[Dictionary] = []
var field_tasks: Dictionary[Vector2i, int] = {}
var people: Array[Dictionary] = []
var row_buttons: Dictionary[Button, Dictionary] = {}
var captions: Dictionary[String, Rect2] = {}
var target: Dictionary = {}
var road_path := PackedVector2Array()

func setup(estate_world: Node2D, guide: Control, blocked: Callable) -> void:
	world = estate_world
	landscape = world.get_node("Landscape")
	tiles = world.tile_map
	directions = guide
	controls_blocked = blocked
	if not Global.ravine_trip_target.is_empty():
		category = Category.RAVINE
	for tab: Button in tabs.get_children():
		tab.pressed.connect(_show_category.bind(tab.get_index()))
	harvest_route.pressed.connect(_start_field_route.bind(Global.NightGrowth.READY))
	water_route.pressed.connect(_start_field_route.bind(Global.NightGrowth.DRY))
	canal_route.pressed.connect(_start_field_route.bind(Global.NightGrowth.BLOCKED))
	chart.draw.connect(_draw_chart)
	chart.gui_input.connect(_chart_input)
	chart.resized.connect(_layout_chart)
	clear_button.pressed.connect(_clear_directions)

func open_fields() -> void:
	if modal.visible:
		_show_category(Category.FIELDS)
	else:
		category = Category.FIELDS
		open_map()

func _start_field_route(task: int) -> void:
	if directions.follow_field_route(task):
		close_map()

func _map_available() -> bool:
	return controls_blocked.is_valid() and not controls_blocked.call()

func _refresh_on_open() -> void:
	date.text = "第 %d 天 · %s" % [Global.current_day, Global.get_current_solar_term()]
	_collect_places()
	_collect_fields()
	_collect_people()
	_show_category(category)

func _collect_places() -> void:
	var icons: Dictionary[int, Texture2D] = {}
	for sprite: Sprite2D in landscape.scenery:
		if sprite.visible:
			icons[landscape.scenery[sprite]] = sprite.texture
	places = [
		_entry(Category.PLACES, "东关", "通往竹涧", _node_point(world.get_node("EastGate")), true, icons.get(LANDSCAPE.Prop.GATE)),
		_entry(Category.PLACES, "水源", "封地的引水处", _cell_point(Global.irrigation.source_cell), true),
		_entry(Category.PLACES, "西廊", "西关内的歇脚处，陶辛在这里理绸", EstateLayout.WEST_COURT, true,
			icons.get(LANDSCAPE.SCENE_WEST_COURT)),
		_entry(Category.PLACES, "西市", "沿西路去粮摊、鱼摊和绸摊", _node_point(world.get_node("WestMarketGate")), true),
		_entry(Category.PLACES, "南路亭", "穿过田南竹径，到亭前歇脚", LANDSCAPE.SOUTH_PAVILION, true, icons.get(LANDSCAPE.SCENE_LANDMARK)),
		_entry(Category.PLACES, DrivingPractice.PLACE, "在田边上车 · 穿旗门并停稳", DrivingPractice.START_POINT),
		_entry(Category.PLACES, "南路灶台", "带食材来做路餐" if Global.travel_hearth_open() else "西市交过第一单后开灶",
			_node_point(world.get_node("TravelHearth/Approach")), true),
		_entry(Category.PLACES, "交货簿", "到卸货场查看本季托付", _node_point(world.get_node("SeasonBoard/Approach")), true)
	]
	var hall := world.get_node("HallRest") as Node2D
	if hall.visible:
		places.insert(2, _entry(Category.PLACES, "堂前", "进屋可研读、歇息和更衣", _node_point(hall), true, icons.get(LANDSCAPE.Prop.HALL)))
	var pavilion: PavilionRest = world.pavilion_rest
	if pavilion.visible:
		var approach := world.to_local(pavilion.to_global(PavilionRest.APPROACH))
		places.append(_entry(Category.PLACES, PavilionRest.PLACE, "与门客说话、查看今夜口粮", approach))
	_add_built_place("药圃", "采药处", "HerbGarden")
	_add_built_place("东路岗", "查看守备口信", "Scenery/EastWatch")
	_add_built_place("轮作簿", "查看轮作约定", "FieldRotationBook")
	if Global.road_rest_built():
		_add_built_place("亭西歇脚处", "在长凳旁休息", "RoadRest")
	var record_stand := world.get_node("Scenery/EndingRecord")
	if record_stand.visible:
		places.push_front(_entry(Category.PLACES, record_stand.record_name, "%s · 翻看通关当天的账目" % record_stand.place_name,
			_node_point(record_stand), false, record_stand.texture))
	if Global.is_autumn_exhibit_day():
		places.append(_entry(Category.PLACES, "秋社展台", "摆三种私田收成", _node_point(world.get_node("AutumnExhibit/Approach")), true))
	if Global.is_winter_supper_day():
		var detail := "用私仓麦备当晚的饭" if Global.winter_supper_record().is_empty() else "已备饭，可回亭东围坐"
		places.append(_entry(Category.PLACES, WinterSupper.PLACE, detail, _node_point(world.get_node("WinterSupper/Approach")), true))
	if Global.sheepfold.owned():
		var sheepfold_detail := "可剪毛" if Global.can_use_sheepfold(Sheepfold.Action.SHEAR) else "查看羊毛长势与草料"
		_add_built_place(Sheepfold.PLACE, sheepfold_detail, "SheepfoldPen", true)
	var shed := world.get_node("SilkShed") as Node2D
	if shed.visible:
		places.append(_entry(Category.PLACES, "蚕棚", "从西廊沿土路向南，进屋养蚕、缫丝与织绸",
			_node_point(shed.get_node("Yard")), true, icons.get(LANDSCAPE.Prop.SILK_SHED)))

func _add_built_place(title: String, detail: String, path: NodePath, caption := false) -> void:
	var site := world.get_node(path) as Node2D
	if site.is_visible_in_tree():
		places.append(_entry(Category.PLACES, title, detail, _node_point(site), caption))

func _collect_fields() -> void:
	fields.clear()
	field_tasks.clear()
	for field in Global.well_fields:
		var center: Vector2i = field["center_pos"]
		var id: int = field["field_id"]
		var progress: int = field["reclamation_progress"]
		var working: bool = not field["is_unlocked"]
		var title := "井田 %d" % (id + 1)
		var watered := Global.irrigation.watered_footprint(center)
		var detail := ""
		var needs := PackedStringArray()
		if working:
			title += " 工地"
			detail = "%s · 还需 %d 夜" % [Global.reclamation_stage(progress), Global.RECLAMATION_NIGHTS - progress]
		else:
			var ripe := 0
			var dry := 0
			var blocked := 0
			for y in range(-1, 2):
				for x in range(-1, 2):
					var cell := center + Vector2i(x, y)
					var task := Global.crop_night_status(cell)
					if task in Global.FIELD_ROUTE_STATES:
						field_tasks[cell] = task
					match task:
						Global.NightGrowth.READY: ripe += 1
						Global.NightGrowth.DRY: dry += 1
						Global.NightGrowth.BLOCKED: blocked += 1
			detail = "渠水 %d/9 格 · 可收 %d 格" % [watered.size(), ripe]
			if dry > 0:
				needs.append("待浇 %d" % dry)
			if blocked > 0:
				needs.append("断水 %d" % blocked)
		var entry := _entry(Category.FIELDS, title, detail, _cell_point(center))
		entry.merge({"field_id": id, "worksite": working, "watered": watered, "needs": " · ".join(needs)})
		fields.append(entry)

func _collect_people() -> void:
	people.clear()
	if Global.tax_council_waiting():
		_add_person(Global.TAX_ENVOY, "使者 · 堂前候议", world.tax_envoy, CharacterArt.tax_envoy_icon())
	for visitor: Node2D in world.active_visitors:
		_add_visitor(visitor)
	var silk_stop: Dictionary = world.silk_trip_stop()
	if not silk_stop.is_empty() and not world.neighbor_actor(VisitorData.SILK_MERCHANT):
		var portrait := CharacterArt.dialogue_portrait(VisitorData.SILK_MERCHANT, null, true)
		people.append(_entry(Category.PEOPLE, VisitorData.SILK_MERCHANT, silk_stop.note, silk_stop.point, false, portrait))
	if is_instance_valid(world.field_guest):
		_add_visitor(world.field_guest)
	for guest: Node2D in world.get_node("SpringGathering/Guests").get_children():
		_add_visitor(guest)
	for guest: Node2D in world.get_node("AutumnExhibit/Guests").get_children():
		if guest.is_visible_in_tree():
			_add_person(guest.speaker, "秋社 · 东南空地", guest, guest.icon)
	for resident: RetainerData in Global.retainers:
		var actor := world.retainer_instances.get(resident) as Retainer
		if is_instance_valid(actor):
			var rest := actor.pavilion_note()
			_add_person(resident.name, "门客 · " + resident.duty_name() if rest.is_empty() else rest,
				actor, resident.get_appearance_texture())

func _ravine_places() -> Array[Dictionary]:
	var gate := _node_point(world.get_node("EastGate"))
	var destinations: Array[Dictionary] = []
	var deployed := Global.creek_trap_site()
	var basket: String = CreekTrap.PLACES[deployed] if deployed >= 0 else ""
	for place: String in Global.ravine_trip_places():
		var entry := _entry(Category.RAVINE, place, Global.ravine_place_detail(place), gate)
		if place == basket:
			destinations.push_front(entry)
		else:
			destinations.append(entry)
	return destinations

func _add_visitor(actor: Visitor) -> void:
	var visitor: VisitorData = actor.data
	_add_person(visitor.name, "来客 · " + actor.visit_note(), actor, visitor.get_appearance_texture())

func _add_person(title: String, detail: String, actor: Node2D, fallback: Texture2D) -> void:
	var icon := CharacterArt.dialogue_portrait(title, fallback, VisitorData.favor_completed(title))
	people.append(_entry(Category.PEOPLE, title, detail, _node_point(actor), false, icon))

func _entry(kind: Category, title: String, detail: String, point: Vector2, caption := false, icon: Texture2D = null) -> Dictionary:
	return {"kind": kind, "title": title, "detail": detail, "point": point, "caption": caption, "icon": icon}

func _node_point(node: Node2D) -> Vector2:
	return world.to_local(node.global_position)

func _player_point() -> Vector2:
	return world.estate_player_point()

func _cell_point(cell: Vector2i) -> Vector2:
	return world.to_local(tiles.to_global(tiles.map_to_local(cell)))

func _show_category(next: Category) -> void:
	category = next
	for tab: Button in tabs.get_children():
		tab.set_pressed_no_signal(tab.get_index() == category)
	for child in listing.get_children():
		listing.remove_child(child)
		child.queue_free()
	row_buttons.clear()
	scroll.scroll_vertical = 0
	var entries := places
	match category:
		Category.FIELDS: entries = fields
		Category.PEOPLE: entries = people
		Category.RAVINE: entries = _ravine_places()
	field_routes.visible = category == Category.FIELDS
	if field_routes.visible:
		var report := Global.field_night_forecast()
		_update_field_button(harvest_route, "■ 可收", report.ready)
		_update_field_button(water_route, "◇ 待浇", report.dry)
		_update_field_button(canal_route, "× 断水", report.blocked)
	ravine_note.visible = category == Category.RAVINE
	if ravine_note.visible:
		var quota := "今日已有外出收获" if Global.last_forage_day == Global.current_day else "今日可带回一份外出收获"
		ravine_note.text = quota + "\n东岸一带有野狗和斥候。"
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "封地此刻没有来客或门客。" if category == Category.PEOPLE else "这里还没有井田。"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size.y = 52.0
		listing.add_child(empty)
	for entry in entries:
		_add_row(entry)
	_refresh_destination()

func _update_field_button(button: Button, label_text: String, count: int) -> void:
	button.text = "%s %d" % [label_text, count]
	button.disabled = count == 0

func _add_row(entry: Dictionary) -> void:
	var row := Button.new()
	var needs: String = entry.get("needs", "")
	row.custom_minimum_size.y = 58.0 if needs.is_empty() else 76.0
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.toggle_mode = true
	row.accessibility_name = "%s，%s" % [entry.title, entry.detail]
	if not needs.is_empty():
		row.accessibility_name += "，" + needs
	if entry.kind == Category.RAVINE:
		row.tooltip_text = entry.detail
	row.pressed.connect(_select.bind(entry))
	listing.add_child(row)
	row_buttons[row] = entry

	var text_left := 14.0
	if entry.kind == Category.PEOPLE and entry.icon:
		var portrait := TextureRect.new()
		portrait.texture = entry.icon
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		portrait.offset_left = 10.0
		portrait.offset_right = 52.0
		portrait.offset_top = -21.0
		portrait.offset_bottom = 21.0
		text_left = 62.0

	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)
	copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	copy.offset_left = text_left
	copy.offset_right = -12.0
	_add_row_text(copy, entry.title, 17, Color("#f5e7bd"))
	_add_row_text(copy, entry.detail, 14, Color("#c7cbb2"))
	if not needs.is_empty():
		_add_row_text(copy, needs, 14, Color("#e6cb99"))

func _add_row_text(parent: VBoxContainer, content: String, font_size: int, ink: Color) -> void:
	var label := Label.new()
	label.text = content
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	parent.add_child(label)

func _select(entry: Dictionary) -> void:
	match entry.kind:
		Category.PEOPLE:
			directions.follow_neighbor(entry.title)
		Category.FIELDS:
			if entry.worksite:
				directions.follow_worksite(entry.field_id)
			else:
				directions.follow_place(entry.title, entry.point)
		Category.PLACES:
			directions.follow_place(entry.title, entry.point)
		Category.RAVINE:
			directions.follow_ravine(entry.title)
	if category == entry.kind:
		_refresh_destination()
	else:
		_show_category(entry.kind)

func _clear_directions() -> void:
	directions.clear_tracking()
	_refresh_destination()

func _refresh_destination() -> void:
	target = directions.destination()
	road_path = PackedVector2Array() if directions.tracked_place.is_empty() else \
		directions.road_route_between(_player_point(), directions.tracked_place_point)
	clear_button.disabled = target.is_empty()
	if not target.is_empty():
		status.text = "指路 · " + target.title
	else:
		match category:
			Category.FIELDS: status.text = "选一类田务，做完一格会标出下一格。"
			Category.RAVINE: status.text = "选个去处，沿金色标记走东关。"
			_: status.text = "点选目的地，回到封地后沿金色标记走。"
	for row in row_buttons:
		var entry: Dictionary = row_buttons[row]
		var selected: String = target.get("title", "")
		match entry.kind:
			Category.PEOPLE: selected = directions.tracked_neighbor
			Category.RAVINE: selected = Global.ravine_trip_target
		row.set_pressed_no_signal(entry.title == selected)
	_layout_chart()

func _chart_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		chart.mouse_default_cursor_shape = (Control.CURSOR_ARROW if _entry_at(event.position).is_empty()
			else Control.CURSOR_POINTING_HAND)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var entry := _entry_at(event.position)
		if not entry.is_empty():
			_select(entry)
		chart.accept_event()

func _entry_at(at: Vector2) -> Dictionary:
	var closest: Dictionary = {}
	var distance := 11.0
	var pins := people + places if category == Category.PEOPLE else places
	for entry in pins:
		var away := at.distance_to(_map_point(entry.point))
		if (entry.kind == Category.PLACES and _place_pin(entry).has_point(at)
			or captions.get(entry.title, Rect2()).has_point(at)):
			away = minf(away, 6.0)
		if away < distance:
			distance = away
			closest = entry
	if not closest.is_empty():
		return closest
	for field in fields:
		if _field_rect(field.point).has_point(at):
			return field
	return {}

func _map_scale() -> float:
	var usable := chart.size - Vector2.ONE * (MAP_MARGIN * 2.0)
	return minf(usable.x / LANDSCAPE.ESTATE_BOUNDS.size.x, usable.y / LANDSCAPE.ESTATE_BOUNDS.size.y)

func _map_point(point: Vector2) -> Vector2:
	return chart.size * 0.5 + (point - LANDSCAPE.ESTATE_BOUNDS.get_center()) * _map_scale()

func _field_rect(point: Vector2) -> Rect2:
	var extent := Vector2(tiles.tile_set.tile_size) * (3.0 * _map_scale())
	return Rect2(_map_point(point) - extent * 0.5, extent)

func _place_pin(place: Dictionary) -> Rect2:
	var at := _map_point(place.point)
	if place.icon:
		var extent: Vector2 = place.icon.get_size() * 0.58
		return Rect2(at - Vector2(extent.x * 0.5, extent.y - 3.0), extent)
	return Rect2(at - Vector2(6, 6), Vector2(12, 12))

func _layout_chart() -> void:
	captions.clear()
	var occupied: Array[Rect2] = []
	for place in places:
		occupied.append(_place_pin(place).grow(2.0))
	for field in fields:
		var footprint := _field_rect(field.point).grow(2.0)
		if category == Category.FIELDS:
			footprint = footprint.grow_side(SIDE_TOP, 15.0)
		occupied.append(footprint)
	if category == Category.PEOPLE:
		for person in people:
			occupied.append(Rect2(_map_point(person.point) - Vector2(8, 8), Vector2(16, 16)))
	occupied.append(Rect2(_map_point(_player_point()) - Vector2(9, 9), Vector2(18, 18)))
	var target_bounds := Rect2()
	if not target.is_empty():
		target_bounds = Rect2(_map_point(target.point) - Vector2(15, 15), Vector2(30, 30))
		occupied.append(target_bounds)

	var font := chart.get_theme_default_font()
	var safe := Rect2(Vector2.ZERO, chart.size).grow(-12.0)
	for place in places:
		if not place.caption:
			continue
		var width := font.get_string_size(place.title, HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE).x + 8.0
		var size := Vector2(width, 20.0)
		var pin := _place_pin(place)
		if not target.is_empty() and target.point == place.point:
			pin = pin.merge(target_bounds)
		var center := pin.get_center() - size * 0.5
		var options := [
			Rect2(Vector2(center.x, pin.position.y - size.y - 5.0), size),
			Rect2(Vector2(pin.end.x + 5.0, center.y), size),
			Rect2(Vector2(center.x, pin.end.y + 5.0), size),
			Rect2(Vector2(pin.position.x - size.x - 5.0, center.y), size)
		]
		for label: Rect2 in options:
			if not safe.encloses(label) or occupied.any(func(rect: Rect2) -> bool: return rect.intersects(label)):
				continue
			captions[place.title] = label
			occupied.append(label.grow(2.0))
			break
	chart.queue_redraw()

func _draw_chart() -> void:
	var sheet := Rect2(Vector2.ZERO, chart.size)
	chart.draw_rect(sheet, PAPER)
	chart.draw_rect(sheet.grow(-4.0), Color("#ab9770"), false, 1.0)
	chart.draw_rect(sheet.grow(-8.0), Color("#b7a47d"), false, 1.0)
	for index in 192:
		var point := Vector2(17 + (index * 311) % int(chart.size.x - 34.0),
			17 + (index * 179) % int(chart.size.y - 34.0))
		chart.draw_rect(Rect2(point, Vector2(2, 1)), Color("#9c88563c"))
	_draw_landscape()
	if road_path.size() > 1:
		var route := PackedVector2Array()
		for point in road_path:
			route.append(_map_point(point))
		chart.draw_polyline(route, INK, 4.0, true)
		chart.draw_polyline(route, GOLD, 2.0, true)
	_draw_channels()
	for field in fields:
		_draw_field(field)
	if category == Category.FIELDS:
		for cell in field_tasks:
			_draw_field_task(cell, field_tasks[cell])
	for place in places:
		_draw_place(place)
	if category == Category.PEOPLE:
		for person in people:
			_draw_person(_map_point(person.point))
	if not target.is_empty():
		var point := _map_point(target.point)
		var radius := 7.0 if category == Category.FIELDS and Global.field_route_status >= 0 else 13.0
		chart.draw_arc(point, radius, 0.0, TAU, 32, INK, 3.6, true)
		chart.draw_arc(point, radius, 0.0, TAU, 32, GOLD, 2.0, true)
	var here := _map_point(_player_point())
	chart.draw_circle(here, 7.0, INK, true, -1.0, true)
	chart.draw_circle(here, 4.7, GOLD, true, -1.0, true)
	chart.draw_circle(here, 2.0, Color("#fff3cb"), true, -1.0, true)
	_draw_north_mark()

func _draw_landscape() -> void:
	for sprite: Sprite2D in landscape.scenery:
		var prop: int = landscape.scenery[sprite]
		var foot := _node_point(sprite)
		if (sprite.visible and LANDSCAPE.ESTATE_BOUNDS.has_point(foot)
				and (prop in LANDSCAPE.LEAFY_PROPS or prop in [LANDSCAPE.Prop.PINE, LANDSCAPE.Prop.BAMBOO])):
			var at := _map_point(foot)
			chart.draw_circle(at, 6.8, Color("#a4aa7b"), true, -1.0, true)
			chart.draw_circle(at + Vector2(-1, -2), 4.8, Color("#8f9a6d"), true, -1.0, true)
	var bounds := LANDSCAPE.ESTATE_BOUNDS
	var land := PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y),
		bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	for track in landscape.track_shapes:
		_draw_road_shape(track.shoulder, land, Color("#ad996b"))
	for track in landscape.track_shapes:
		_draw_road_shape(track.surface, land, Color("#c6ac7e"))

func _draw_road_shape(outline: PackedVector2Array, land: PackedVector2Array, ink: Color) -> void:
	for segment in Geometry2D.intersect_polygons(outline, land):
		var points := PackedVector2Array()
		for point in segment:
			points.append(_map_point(point))
		chart.draw_colored_polygon(points, ink)

func _draw_channels() -> void:
	var network := Global.irrigation
	for cell in network.channels:
		var at := _map_point(_cell_point(cell))
		var color := WATER if network.is_channel_wet(cell) else DRY
		chart.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), color)
		for step: Vector2i in Irrigation.NEIGHBORS:
			var neighbor := cell + step
			if neighbor == network.source_cell or network.channels.has(neighbor):
				var end := at.lerp(_map_point(_cell_point(neighbor)), 0.51)
				chart.draw_line(at, end, color, 3.0, true)

func _draw_field(field: Dictionary) -> void:
	var area := _field_rect(field.point)
	var at := area.get_center()
	var cell := area.size / 3.0
	var entrance: Vector2 = landscape.field_entrance(field.field_id)
	if field.worksite:
		chart.draw_rect(area, Color("#c2a574"))
		for index in range(1, 6):
			var ratio := float(index) / 3.0
			var start := area.position + Vector2(maxf(0.0, ratio - 1.0), minf(1.0, ratio)) * area.size
			var end := area.position + Vector2(minf(1.0, ratio), maxf(0.0, ratio - 1.0)) * area.size
			chart.draw_line(start, end, Color("#a38259"), 1.0, true)
		chart.draw_rect(area, DRY, false, 2.0)
	else:
		chart.draw_rect(area, Color("#a2a87a"))
		for watered_cell: Vector2i in field.watered:
			var wet := _map_point(_cell_point(watered_cell))
			chart.draw_rect(Rect2(wet - cell * 0.5, cell), Color("#84a8a1"))
		for offset in [1.0, 2.0]:
			chart.draw_line(area.position + Vector2(cell.x * offset, 0),
				area.position + Vector2(cell.x * offset, area.size.y), Color("#6e7859"))
			chart.draw_line(area.position + Vector2(0, cell.y * offset),
				area.position + Vector2(area.size.x, cell.y * offset), Color("#6e7859"))
		chart.draw_rect(Rect2(at - cell * 0.5, cell), Color("#6e5734"), false, 1.4)
		var boundary := EstateLayout.field_boundary(area, entrance, cell.x)
		chart.draw_polyline(boundary, Color("#576345"), 1.6, true)
	var number_y := area.end.y + 8.0 if entrance == Vector2.UP else area.position.y - 8.0
	var number_at := Vector2(at.x, number_y) if category == Category.FIELDS else at
	_draw_text(str(field.field_id + 1), number_at, 12, INK)

func _draw_field_task(cell: Vector2i, task: int) -> void:
	var at := _map_point(_cell_point(cell))
	match task:
		Global.NightGrowth.READY:
			var square := Rect2(at - Vector2(4, 4), Vector2(8, 8))
			chart.draw_rect(square, INK)
			chart.draw_rect(square.grow(-1.5), GOLD)
		Global.NightGrowth.DRY:
			var diamond := PackedVector2Array([at + Vector2(0, -4), at + Vector2(4, 0),
				at + Vector2(0, 4), at + Vector2(-4, 0), at + Vector2(0, -4)])
			chart.draw_polyline(diamond, INK, 3.5, true)
			chart.draw_polyline(diamond, Color("#b7e1ef"), 1.5, true)
		Global.NightGrowth.BLOCKED:
			for diagonal in [Vector2(3, 3), Vector2(3, -3)]:
				chart.draw_line(at - diagonal, at + diagonal, INK, 3.5, true)
				chart.draw_line(at - diagonal, at + diagonal, Color("#ffb38f"), 1.5, true)

func _draw_place(place: Dictionary) -> void:
	var at := _map_point(place.point)
	var color := WATER if place.title == "水源" else INK
	if captions.has(place.title):
		var label := captions[place.title]
		var connection := at.clamp(label.position, label.end)
		chart.draw_line(at, connection, Color("#8a7554"), 1.0, true)
		chart.draw_rect(label, Color("#eee3bde8"))
		_draw_text(place.title, label.get_center(), CAPTION_SIZE, INK)
	if place.icon:
		chart.draw_texture_rect(place.icon, _place_pin(place), false, Color("#f1e5cb"))
		chart.draw_circle(at, 2.0, color, true, -1.0, true)
	else:
		chart.draw_circle(at, 6.0, PAPER, true, -1.0, true)
		chart.draw_circle(at, 4.6, color, true, -1.0, true)

func _draw_person(at: Vector2) -> void:
	chart.draw_circle(at, 7.0, PAPER, true, -1.0, true)
	chart.draw_circle(at, 5.5, PERSON, true, -1.0, true)
	chart.draw_circle(at + Vector2(0, -1.6), 1.4, Color("#f6e7bf"), true, -1.0, true)
	chart.draw_line(at + Vector2(-2, 2), at + Vector2(2, 2), Color("#f6e7bf"), 1.4, true)

func _draw_text(content: String, center: Vector2, font_size: int, color: Color) -> void:
	var font := chart.get_theme_default_font()
	var width := font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	chart.draw_string(font, center + Vector2(-width * 0.5, baseline), content,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_north_mark() -> void:
	var at := Vector2(chart.size.x - 43.0, 59.0)
	_draw_text("北", at + Vector2(0, -24), 16, INK)
	chart.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -12), at + Vector2(5, 7),
		at + Vector2(0, 4), at + Vector2(-5, 7)]), INK)
	chart.draw_line(at + Vector2(0, 7), at + Vector2(0, 17), INK, 1.0, true)
