extends Node2D

signal preview_changed(message: String)
signal survey_changed(active: bool)

const BANK_SHADOW := Color("#394636")
const BANK := Color("#9c8259")
const BED := Color("#584e39")
const WATER := Color("#568e87")
const WATER_LIGHT := Color("#a5d4bc")
const DRY := Color("#8b6949")
const CULVERT_STONE := Color("#898475")
const RIPPLE_SPACING := 23.0
const RIPPLE_SPEED := 11.0
const FERTILITY_HIGHLIGHT_SECONDS := 12.0

@onready var tile_map: TileMapLayer = get_parent()
@onready var tile_size := Vector2(tile_map.tile_set.tile_size)

var editing := false
var cursor := Vector2i.ZERO
var pointer := Vector2.ZERO
var preview_fill := false
var survey_mode := false
var survey_start: Variant
var horizontal_first := true
var preview_route: Array[Vector2i] = []
var repair_cells: Array[Vector2i] = []
var affected_fields: Dictionary[Vector2i, bool] = {}
var affected_channels: Dictionary[Vector2i, bool] = {}
var planned_additions: Array[Vector2i] = []
var future_water: Dictionary[Vector2i, int] = {}
var preview_site: int = Global.ChannelSite.BLOCKED
var blocked_cell := Vector2i.ZERO
var source_label: Label
@onready var flow_ink := Node2D.new()
@onready var crop_icons := Node2D.new()
@onready var plan_ink := Node2D.new()
var fertility_highlight: Tween
var footbridges: Array[Rect2] = []
var culverts: Dictionary[Vector2i, bool] = {}
var water_time := 0.0
var water_frame := 0

func _ready() -> void:
	source_label = Label.new()
	source_label.material = preload("res://resources/world_hint_material.tres")
	source_label.text = "水源"
	source_label.add_theme_font_size_override("font_size", 10)
	source_label.add_theme_color_override("font_color", Color("#c4e2ce"))
	source_label.add_theme_color_override("font_outline_color", Color("#21392d"))
	source_label.add_theme_constant_override("outline_size", 3)
	source_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(source_label)
	flow_ink.draw.connect(_draw_flow)
	add_child(flow_ink)
	crop_icons.z_index = 2
	crop_icons.draw.connect(_draw_crop_icons)
	add_child(crop_icons)
	plan_ink.z_index = 3
	plan_ink.draw.connect(_draw_plan)
	add_child(plan_ink)
	_refresh_network()
	GameEvents.channels_changed.connect(_refresh_network)
	GameEvents.well_field_reclaimed.connect(_refresh_network.unbind(2))
	GameEvents.well_field_added.connect(_refresh_network.unbind(1))
	GameEvents.channel_survey_learned.connect(_refresh_network)
	GameEvents.ravine_journal_changed.connect(_refresh_network)
	GameEvents.field_rotation_changed.connect(_refresh_network)
	GameEvents.money_changed.connect(_refresh_plan.unbind(1))
	GameEvents.crop_harvested.connect(_refresh_tiles.unbind(1))
	GameEvents.farm_state_changed.connect(_refresh_tiles)
	GameEvents.day_advanced.connect(_refresh_tiles.unbind(1))
	GameEvents.day_advanced.connect(_clear_fertility_highlight.unbind(1))

func set_editing(enabled: bool) -> void:
	editing = enabled
	if editing:
		_clear_fertility_highlight()
	pointer = get_viewport().get_mouse_position()
	preview_fill = Input.is_action_pressed(KeyBindings.FILL) or GamepadInput.filling
	cursor = _pointer_cell()
	if not editing and survey_mode:
		cancel_survey()
	_refresh_tiles()
	_refresh_plan()

func track_pointer(at: Vector2, fill: bool) -> void:
	pointer = at
	var cell := _pointer_cell()
	if cell != cursor or fill != preview_fill:
		cursor = cell
		preview_fill = fill
		_refresh_plan()

func _process(delta: float) -> void:
	if editing:
		track_pointer(pointer, preview_fill)
	if Global.is_indoors():
		return
	water_time = fposmod(water_time + delta * RIPPLE_SPEED, RIPPLE_SPACING)
	var next_frame := floori(water_time)
	if next_frame != water_frame:
		water_frame = next_frame
		flow_ink.queue_redraw()

func _pointer_cell() -> Vector2i:
	return tile_map.local_to_map(tile_map.make_canvas_position_local(pointer))

func toggle_survey() -> void:
	if survey_mode:
		cancel_survey()
	elif editing and Global.channel_survey_day > 0:
		survey_mode = true
		horizontal_first = true
		survey_changed.emit(true)
		_refresh_plan()

func cancel_survey() -> void:
	survey_mode = false
	survey_start = null
	survey_changed.emit(false)
	_refresh_plan()

func flip_survey() -> void:
	horizontal_first = not horizontal_first
	_refresh_plan()

func select_survey_cell(cell: Vector2i) -> String:
	if cell != Global.irrigation.source_cell and not Global.RECLAMATION_BOUNDS.has_point(cell):
		return "请在封地内放样"
	if survey_start == null:
		match Global.channel_build_plan([cell], true)["site"]:
			Global.ChannelSite.BLOCKED: return "起点需避开井田"
			Global.ChannelSite.FOUNDATION: return "起点需避开屋基"
		survey_start = cell
		_refresh_plan()
		return "起点已定 · 选渠尾"
	var route := _survey_route(cell)
	var plan := Global.channel_build_plan(route, true)
	match Global.build_channel_path(route, true):
		Global.ChannelSite.AVAILABLE:
			cancel_survey()
			return "已挖 %d 格 · 支出 %d 铜钱" % [plan["additions"].size(), plan["cost"]]
		Global.ChannelSite.NO_FUNDS: return "铜钱不足 · 放样保留"
		Global.ChannelSite.BLOCKED, Global.ChannelSite.FOUNDATION:
			var key := "Menu" if GamepadInput.active else Preferences.key_label(KeyBindings.ROTATE)
			var obstacle := "屋基" if plan["site"] == Global.ChannelSite.FOUNDATION else "井田"
			return "渠线压到%s · 可用 %s 换弯" % [obstacle, key]
		_: return "这条渠线上已有水源或水渠"

func _survey_route(end: Vector2i) -> Array[Vector2i]:
	if survey_start == null:
		return [end]
	var point: Vector2i = survey_start
	var route: Array[Vector2i] = [point]
	var axes := [Vector2i.RIGHT, Vector2i.DOWN] if horizontal_first else [Vector2i.DOWN, Vector2i.RIGHT]
	for axis: Vector2i in axes:
		var distance := end.x - point.x if axis == Vector2i.RIGHT else end.y - point.y
		for step in absi(distance):
			point += axis * signi(distance)
			route.append(point)
	return route

func _refresh_plan() -> void:
	preview_route.clear()
	repair_cells.clear()
	planned_additions.clear()
	affected_fields.clear()
	affected_channels.clear()
	plan_ink.queue_redraw()
	if not editing:
		return
	if cursor != Global.irrigation.source_cell and not Global.RECLAMATION_BOUNDS.has_point(cursor):
		preview_changed.emit("移到封地内的地格，查看渠水变化。")
		return
	if preview_fill and not survey_mode:
		_preview_fill()
	else:
		_preview_dig()

func _preview_fill() -> void:
	preview_route = [cursor]
	var exists := Global.irrigation.channels.has(cursor)
	preview_site = Global.ChannelSite.AVAILABLE if exists else Global.ChannelSite.BLOCKED
	blocked_cell = cursor
	if not exists:
		preview_changed.emit("填渠 · 这里是空地")
		return
	_compare_flow(Global.irrigation.projected_flow([], cursor))
	var stalled := 0
	for cell in affected_fields:
		var crop: Dictionary = Global.active_crops.get(cell, {})
		if crop.get("requires_channel", false) and crop["age"] < crop["growth_nights"]:
			stalled += 1
	var action := "填暗渠" if culverts.has(cursor) else "填渠"
	preview_changed.emit("%s · 失水 %d 格%s" % [
		action, affected_fields.size(), " · %d 格稻暂停" % stalled if stalled > 0 else ""])

func _preview_dig() -> void:
	if not survey_mode and cursor == Global.irrigation.source_cell:
		preview_changed.emit("水源 · 从相邻的空地引水")
		return
	if not survey_mode and Global.irrigation.channels.has(cursor):
		for gap in Global.irrigation.repair_gaps(cursor):
			if Global.check_channel_site(gap) in [Global.ChannelSite.AVAILABLE, Global.ChannelSite.NO_FUNDS]:
				repair_cells.append(gap)
		if Global.irrigation.is_channel_wet(cursor):
			var kind := "通水暗渠" if culverts.has(cursor) else "通水渠"
			var key := "LT" if GamepadInput.active else Preferences.key_label(KeyBindings.FILL)
			preview_changed.emit("%s · 按 %s 查看填渠影响" % [kind, key])
		else:
			var kind := "暗渠断水" if culverts.has(cursor) else "断渠"
			preview_changed.emit(kind + " · " + ("金框处可补接" if not repair_cells.is_empty() else "与水源之间还有缺口"))
		return
	preview_route = _survey_route(cursor)
	var plan := Global.channel_build_plan(preview_route, survey_mode)
	preview_site = plan["site"]
	blocked_cell = plan["blocked_cell"]
	planned_additions.assign(plan["additions"])
	if preview_site == Global.ChannelSite.FOUNDATION:
		preview_changed.emit("红框处是屋基，请从屋外引渠")
	elif preview_site == Global.ChannelSite.BLOCKED:
		preview_changed.emit("红框处是井田，请绕开")
	elif planned_additions.is_empty():
		preview_changed.emit("可从水源或已有水渠起步" if survey_start == null else "这段已有水渠")
	else:
		_compare_flow(Global.irrigation.projected_flow(planned_additions))
		var price := "%d 铜钱" % plan["cost"]
		if preview_site == Global.ChannelSite.NO_FUNDS:
			price += " · 差 %d" % (plan["cost"] - Global.money)
		var supplied := planned_additions.any(func(cell: Vector2i) -> bool: return future_water.has(cell))
		var coverage := "供水 +%d 格" % affected_fields.size() if supplied else "仍需接通"
		preview_changed.emit("挖 %d 格 · %s · %s" % [planned_additions.size(), price, coverage])

func _compare_flow(next: Dictionary[Vector2i, int]) -> void:
	future_water = next
	for cell in Global.irrigation.channels:
		if Global.irrigation.is_channel_wet(cell) != next.has(cell):
			affected_channels[cell] = next.has(cell)
	for cell in tile_map.get_used_cells():
		var supplied := Irrigation.supplied_by(cell, next)
		if Global.irrigation.supplies(cell) != supplied:
			affected_fields[cell] = supplied

func _refresh_network() -> void:
	source_label.text = "水源 · 量水尺" if Global.channel_survey_day > 0 else "水源"
	source_label.position = tile_map.map_to_local(Global.irrigation.source_cell) + Vector2(-source_label.get_minimum_size().x / 2.0, -22)
	culverts.clear()
	for cell in Global.irrigation.channels:
		if EstateLayout.is_foundation(cell):
			culverts[cell] = true
	_refresh_footbridges()
	flow_ink.queue_redraw()
	_refresh_tiles()
	_refresh_plan()

func _refresh_footbridges() -> void:
	footbridges.clear()
	var landscape: Node2D = tile_map.get_parent().get_node("Landscape")
	var network := Global.irrigation
	for cell in network.channels:
		if culverts.has(cell):
			continue
		var center := tile_map.map_to_local(cell)
		for direction: Vector2i in Irrigation.NEIGHBORS:
			var neighbor := cell + direction
			if culverts.has(neighbor):
				continue
			if neighbor != network.source_cell and (not network.channels.has(neighbor) or direction in [Vector2i.LEFT, Vector2i.UP]):
				continue
			var other := tile_map.map_to_local(neighbor)
			var hit: Variant = landscape.track_crossing(landscape.to_local(to_global(center)), landscape.to_local(to_global(other)))
			if hit == null:
				continue
			var midpoint := to_local(landscape.to_global(hit)).round()
			var size := Vector2(16, 14) if direction.x != 0 else Vector2(14, 16)
			var deck := Rect2(midpoint - size * 0.5, size)
			if not deck.intersects(_cell_rect(network.source_cell).grow(-2)) and not footbridges.any(
				func(existing: Rect2) -> bool: return existing.intersects(deck)):
				footbridges.append(deck)

func footbridge_at(world_point: Vector2) -> bool:
	var local := to_local(world_point)
	return footbridges.any(func(deck: Rect2) -> bool: return deck.has_point(local))

func _refresh_tiles() -> void:
	queue_redraw()
	crop_icons.queue_redraw()

func _draw_plan() -> void:
	if not editing:
		return
	var gain := Color("#a0e4d3")
	var loss := Color("#edaa83")
	for cell in culverts:
		var cover := _cell_rect(cell).grow(-2)
		plan_ink.draw_rect(cover, Color("#ad9b7650"))
		plan_ink.draw_rect(cover, Color("#c9b78c"), false, 1.0)
	for cell in affected_fields:
		var ink := gain if affected_fields[cell] else loss
		plan_ink.draw_rect(_cell_rect(cell).grow(-1), Color(ink, 0.24))
		plan_ink.draw_rect(_cell_rect(cell).grow(-1), ink, false, 1.0)
	for cell in affected_channels:
		var ink := gain if affected_channels[cell] else loss
		plan_ink.draw_rect(_cell_rect(cell).grow(-3), Color(ink, 0.42))
	for cell in repair_cells:
		plan_ink.draw_rect(_cell_rect(cell).grow(-2), Color("#f2cc78"), false, 1.5)
	for cell in planned_additions:
		var ink := gain if future_water.has(cell) else Color("#edc48b")
		plan_ink.draw_rect(_cell_rect(cell).grow(-2), Color(ink, 0.42))
		plan_ink.draw_rect(_cell_rect(cell).grow(-2), ink, false, 1.0)
	if not preview_route.is_empty():
		var outline := gain if preview_site == Global.ChannelSite.AVAILABLE else loss
		plan_ink.draw_rect(_cell_rect(cursor).grow(-1), outline, false, 1.3)
		if preview_site in [Global.ChannelSite.BLOCKED, Global.ChannelSite.FOUNDATION]:
			plan_ink.draw_rect(_cell_rect(blocked_cell).grow(-1), Color("#ee9073"), false, 1.5)
	if survey_mode and survey_start != null:
		plan_ink.draw_rect(_cell_rect(survey_start).grow(-1), Color("#f2cc78"), false, 1.5)

func highlight_fertile_cells() -> void:
	if editing or Global.fertile_cells.is_empty():
		return
	_clear_fertility_highlight()
	fertility_highlight = create_tween()
	fertility_highlight.tween_interval(FERTILITY_HIGHLIGHT_SECONDS)
	fertility_highlight.tween_callback(func():
		fertility_highlight = null
		crop_icons.queue_redraw()
	)
	crop_icons.queue_redraw()
	GameEvents.world_notice.emit("田间金框标出豆茬留肥 · %d 秒" % int(FERTILITY_HIGHLIGHT_SECONDS))

func _clear_fertility_highlight() -> void:
	if fertility_highlight:
		fertility_highlight.kill()
		fertility_highlight = null
		crop_icons.queue_redraw()

func _draw_crop_icons() -> void:
	if editing:
		return
	if fertility_highlight:
		for cell in Global.fertile_cells:
			var area := _cell_rect(cell).grow(-1)
			crop_icons.draw_rect(area, Color("#ddbb6f34"))
			crop_icons.draw_rect(area, Color("#4b4432"), false, 2.4)
			crop_icons.draw_rect(area, Color("#f4d99c"), false, 1.0)
	for cell in Global.active_crops:
		var crop: Dictionary = Global.active_crops[cell]
		var at := tile_map.map_to_local(cell) + Vector2(5, 5)
		if crop["age"] >= crop["growth_nights"]:
			crop_icons.draw_circle(at, 3.8, Color("#332f24e8"))
			crop_icons.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -3), at + Vector2(2.5, 0),
				at + Vector2(0, 2.5), at + Vector2(-2.5, 0)]), Color("#f4ce76"))
			continue
		match Global.crop_water(cell, crop):
			Global.CropWater.DRY:
				crop_icons.draw_circle(at, 3.8, Color("#283730e8"))
				crop_icons.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -3), at + Vector2(2, 0),
					at + Vector2(2, 1), at + Vector2(0, 2.5), at + Vector2(-2, 1), at + Vector2(-2, 0)]), Color("#a4d4d0"))
			Global.CropWater.BLOCKED:
				crop_icons.draw_circle(at, 3.8, Color("#3c3027e8"))
				crop_icons.draw_line(at - Vector2(2, 2), at + Vector2(2, 2), Color("#efa07b"), 1.4)
				crop_icons.draw_line(at + Vector2(-2, 2), at + Vector2(2, -2), Color("#efa07b"), 1.4)

func _draw() -> void:
	var network := Global.irrigation
	var rain := Global.has_rain()
	for cell in network.channels:
		_channel_shape(cell, 11.0, BANK_SHADOW, Vector2.DOWN)
	for cell in network.channels:
		_channel_shape(cell, 10.0, BANK)
	for cell in network.channels:
		_channel_shape(cell, 7.0, BED)
	for cell in network.channels:
		var center := tile_map.map_to_local(cell)
		if culverts.has(cell):
			_channel_shape(cell, 9.0, CULVERT_STONE)
			draw_rect(Rect2(center + Vector2(-3, -1), Vector2(6, 1)), CULVERT_STONE.lightened(0.2))
			continue
		var wet := network.is_channel_wet(cell)
		_channel_shape(cell, 5.0, WATER if wet else DRY)
		if not wet:
			draw_rect(Rect2(center + Vector2(-2, -1), Vector2(3, 1)), BED)

	for cell in tile_map.get_used_cells():
		var supplied := network.supplies(cell)
		var crop: Dictionary = Global.active_crops.get(cell, {})
		var hand_watered: bool = crop.get("watered", false) and not crop.get("requires_channel", false)
		var rained_on: bool = rain and (crop.is_empty() or not crop["data"].is_water_crop)
		if supplied or hand_watered or rained_on:
			var soil := _cell_rect(cell).grow(-1)
			draw_rect(soil, Color("#23372c7a"))
			if supplied:
				_draw_inlets(cell)
		if Global.fertile_cells.has(cell):
			var corner := _cell_rect(cell).position + Vector2(2, 12)
			draw_rect(Rect2(corner, Vector2(4, 2)), Color("#dbb773"))

	_draw_source(_cell_rect(network.source_cell).position)
	_draw_footbridges()

func _channel_shape(cell: Vector2i, width: float, ink: Color, offset := Vector2.ZERO) -> void:
	var network := Global.irrigation
	var center := tile_map.map_to_local(cell) + offset
	draw_rect(Rect2(center - Vector2.ONE * width / 2.0, Vector2.ONE * width), ink)
	for direction: Vector2i in Irrigation.NEIGHBORS:
		var next_cell := cell + direction
		if next_cell == network.source_cell or network.channels.has(next_cell):
			draw_line(center, center + Vector2(direction) * tile_size / 2.0, ink, width)

func _draw_inlets(cell: Vector2i) -> void:
	var network := Global.irrigation
	var center := tile_map.map_to_local(cell)
	for direction: Vector2i in Irrigation.NEIGHBORS:
		if not network.is_channel_wet(cell + direction):
			continue
		var bank := center + Vector2(direction) * tile_size * 0.5
		var ditch := tile_map.map_to_local(cell + direction) - Vector2(direction) * 1.0
		var soil := bank - Vector2(direction) * 2.0
		draw_line(ditch, soil, BED, 4.0)
		draw_line(ditch, soil, WATER, 2.0)

func _draw_flow() -> void:
	var network := Global.irrigation
	var source := tile_map.map_to_local(network.source_cell)
	flow_ink.draw_rect(Rect2(source + Vector2(posmod(water_frame, 5) - 3, -2), Vector2(3, 1)), WATER_LIGHT)
	for cell in network.channels:
		var distance := network.flow_distance(cell)
		if distance <= 0 or culverts.has(cell):
			continue
		var center := tile_map.map_to_local(cell)
		for direction: Vector2i in Irrigation.NEIGHBORS:
			var upstream := cell + direction
			if network.flow_distance(upstream) != distance - 1 or culverts.has(upstream):
				continue
			var length := tile_size.x if direction.x != 0 else tile_size.y
			var traveled := fposmod(water_frame - float(distance - 1) * length, RIPPLE_SPACING)
			if traveled >= length or (upstream == network.source_cell and traveled < 5.0):
				continue
			var point := (center + Vector2(direction) * (length - traveled)).round()
			if footbridges.any(func(deck: Rect2) -> bool: return deck.has_point(point)):
				continue
			var streak := Vector2(3, 1) if direction.x != 0 else Vector2(1, 3)
			flow_ink.draw_rect(Rect2(point - (streak * 0.5).floor(), streak), WATER_LIGHT)

func _draw_footbridges() -> void:
	for deck in footbridges:
		draw_rect(deck.grow(1), Color("#52412e"))
		draw_rect(deck, Color("#b59460"))
		var across_x := deck.size.x < deck.size.y
		for gap in [4, 8, 12]:
			var offset := Vector2(0, gap) if across_x else Vector2(gap, 0)
			var seam := Vector2(deck.size.x, 1) if across_x else Vector2(1, deck.size.y)
			draw_rect(Rect2(deck.position + offset, seam), Color("#7f603e"))
		draw_rect(Rect2(deck.position + Vector2(1, 1), Vector2(deck.size.x - 2, 1)), Color("#d6b783"))

func _draw_source(origin: Vector2) -> void:
	draw_rect(Rect2(origin + Vector2(1, 2), Vector2(14, 13)), BANK_SHADOW)
	draw_rect(Rect2(origin + Vector2(1, 4), Vector2(14, 8)), Color("#969477"))
	draw_rect(Rect2(origin + Vector2(3, 2), Vector2(10, 12)), Color("#969477"))
	draw_rect(Rect2(origin + Vector2(3, 3), Vector2(10, 1)), Color("#c1bb96"))
	draw_rect(Rect2(origin + Vector2(3, 12), Vector2(10, 2)), Color("#686d58"))
	draw_rect(Rect2(origin + Vector2(3, 4), Vector2(10, 8)), Color("#355a54"))
	draw_rect(Rect2(origin + Vector2(4, 5), Vector2(8, 6)), WATER)
	draw_rect(Rect2(origin + Vector2(7, 9), Vector2(4, 1)), Color("#81b7a7"))
	var center := origin + tile_size * 0.5
	for direction: Vector2i in Irrigation.NEIGHBORS:
		if Global.irrigation.channels.has(Global.irrigation.source_cell + direction):
			var inlet := center + Vector2(direction) * 3.0
			var edge := center + Vector2(direction) * (tile_size * 0.5 + Vector2.ONE)
			draw_line(inlet, edge, Color("#405c51"), 7.0)
			draw_line(inlet, edge, WATER, 5.0)
	if Global.channel_survey_day > 0:
		draw_rect(Rect2(origin + Vector2(11, 0), Vector2(4, 13)), Color("#44392e"))
		draw_rect(Rect2(origin + Vector2(12, 0), Vector2(2, 12)), Color("#d8b276"))
		for mark in [3, 6, 9]:
			draw_rect(Rect2(origin + Vector2(12, mark), Vector2(2, 1)), Color("#73583b"))

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(tile_map.map_to_local(cell) - tile_size / 2.0, tile_size)
