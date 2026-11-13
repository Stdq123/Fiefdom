extends Node2D

signal preview_changed(message: String)
signal survey_changed(active: bool)
signal gate_mode_changed(active: bool)

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
const RICE_MARK := Color("#abdcc8")

@onready var tile_map: TileMapLayer = get_parent()
@onready var tile_size := Vector2(tile_map.tile_set.tile_size)
@onready var water_source = $WaterSource

var editing := false
var cursor := Vector2i.ZERO
var pointer := Vector2.ZERO
var preview_fill := false
var survey_mode := false
var gate_mode := false
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
var starter_canal: Array[Vector2i] = []
var rice_plot_highlight: Array[Vector2i] = []
var gate_candidates: Dictionary[Vector2i, bool] = {}
var gate_row: Array[Vector2i] = []
@onready var flow_ink := Node2D.new()
@onready var crop_icons := Node2D.new()
@onready var plan_ink := Node2D.new()
var fertility_highlight: Tween
var footbridges: Array[Rect2] = []
var culverts: Dictionary[Vector2i, bool] = {}
var water_time := 0.0
var water_frame := 0

func _ready() -> void:
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
	GameEvents.day_advanced.connect(_clear_rice_plot_highlight.unbind(1))

func set_editing(enabled: bool) -> void:
	editing = enabled
	if editing:
		_clear_fertility_highlight()
		_clear_rice_plot_highlight()
	pointer = get_viewport().get_mouse_position()
	preview_fill = Input.is_action_pressed(KeyBindings.FILL) or GamepadInput.filling
	cursor = _pointer_cell()
	if not editing:
		starter_canal.clear()
		if survey_mode:
			cancel_survey()
		if gate_mode:
			set_gate_mode(false)
	_refresh_tiles()
	_refresh_plan()

func starter_canal_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var network := Global.irrigation
	var center: Vector2i = Global.well_fields[0].center_pos
	var offset := center - network.source_cell
	var rice_gap := Global.pinned_rice_water_gap()
	if (offset.x != 0 and offset.y != 0) or (rice_gap == 0 and not network.watered_footprint(center).is_empty()):
		return cells
	var axis := offset.sign()
	# The field edge is one tile from its center. The canal ends just outside it.
	for step in range(1, maxi(absi(offset.x), absi(offset.y)) - 1):
		var cell := network.source_cell + axis * step
		if not network.channels.has(cell):
			cells.append(cell)
	if rice_gap > 0:
		var bank := center - axis * 2
		var along := Vector2i(-axis.y, axis.x)
		var plots := Global.private_rice_plots()
		var rice := ItemManager.get_crop("rice")
		# Continue along the outside edge so the same ditch can supply another plot.
		for side: Vector2i in [along, -along]:
			var yield_count := 0
			for plot in starter_rice_plots(cells):
				yield_count += 1 + Global.crop_rotation_bonus(plot, rice)
			if yield_count >= rice_gap:
				break
			var cell := bank + side
			var plot := cell + axis
			if plot in plots and not network.supplies(plot) and Global.crop_night_status(plot) != Global.NightGrowth.READY \
					and Global.check_channel_site(cell) in [Global.ChannelSite.AVAILABLE, Global.ChannelSite.NO_FUNDS]:
				cells.append(cell)
		if starter_rice_plots(cells).is_empty():
			cells.clear()
	var plan := Global.channel_build_plan(cells)
	if plan.site not in [Global.ChannelSite.AVAILABLE, Global.ChannelSite.NO_FUNDS]:
		cells.clear()
	return cells

func starter_rice_plots(cells: Array[Vector2i]) -> Array[Vector2i]:
	var plots: Array[Vector2i] = []
	if cells.is_empty() or Global.pinned_rice_water_gap() == 0:
		return plots
	var network := Global.irrigation
	var projected := network.projected_flow(cells)
	for cell in Global.private_rice_plots():
		if (not network.supplies(cell) and Global.crop_night_status(cell) != Global.NightGrowth.READY
				and Irrigation.supplied_by(cell, projected)):
			plots.append(cell)
	return plots

func show_starter_canal(cells: Array[Vector2i]) -> void:
	starter_canal = cells
	rice_plot_highlight = starter_rice_plots(cells)
	flow_ink.queue_redraw()
	var work := "引水需挖" if rice_plot_highlight.is_empty() else "备稻渠需挖"
	preview_changed.emit("%s %d 格 · 共 %d 铜钱" % [work, cells.size(), cells.size() * Global.channel_cost()])

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
		if gate_mode:
			set_gate_mode(false)
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

func set_gate_mode(active: bool) -> void:
	if active and survey_mode:
		cancel_survey()
	gate_mode = active
	gate_mode_changed.emit(active)
	_refresh_plan()

func place_field_gate(edge: Vector2i) -> String:
	var plan := Global.build_field_gate(edge)
	if plan.site == Global.FieldGateSite.AVAILABLE:
		set_gate_mode(false)
		AudioManager.play_ui_sfx(1.08)
		return "田口闸已装好 · 渠水沿田沟流过三格"
	return _gate_feedback(plan)

func _gate_feedback(plan: Dictionary) -> String:
	match plan.site:
		Global.FieldGateSite.LOCKED: return "随石墨勘渠后可装田口闸"
		Global.FieldGateSite.NOT_EDGE: return "选择井田边线的中间一格"
		Global.FieldGateSite.NO_WATER: return "这一侧还没通水 · 先接上外渠"
		Global.FieldGateSite.ALREADY_BUILT: return "这一侧已有闸口"
		Global.FieldGateSite.NO_FUNDS: return "田口闸还差 %d 铜钱" % (plan.price - Global.money)
		_: return ""

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
	gate_candidates.clear()
	gate_row.clear()
	affected_fields.clear()
	affected_channels.clear()
	plan_ink.queue_redraw()
	flow_ink.queue_redraw()
	if not editing:
		return
	if gate_mode:
		_preview_gate()
		return
	if cursor != Global.irrigation.source_cell and not Global.RECLAMATION_BOUNDS.has_point(cursor):
		preview_changed.emit("移到封地内的地格，查看渠水变化。")
		return
	if preview_fill and not survey_mode:
		_preview_fill()
	else:
		_preview_dig()

func _preview_gate() -> void:
	var network := Global.irrigation
	for field: Dictionary in Global.well_fields:
		if not field.is_unlocked:
			continue
		var center: Vector2i = field.center_pos
		for direction: Vector2i in Irrigation.NEIGHBORS:
			var inlet := center + direction * 2
			if network.gate_is_wet(inlet) and network.field_gates.get(center) != inlet:
				gate_candidates[center + direction] = true
	var plan := Global.field_gate_plan(cursor)
	if plan.has("center"):
		gate_row = Irrigation.gate_row(plan.center, plan.inlet)
	if plan.site not in [Global.FieldGateSite.AVAILABLE, Global.FieldGateSite.NO_FUNDS]:
		preview_changed.emit(_gate_feedback(plan))
		return
	var gates := network.field_gates.duplicate()
	gates[plan.center] = plan.inlet
	_compare_flow(network.projected_flow([]), gates)
	var added := 0
	var lost := 0
	for supplied in affected_fields.values():
		if supplied:
			added += 1
		else:
			lost += 1
	var text := "移闸" if network.field_gates.has(plan.center) else "装闸"
	text += " · %d 铜钱 · 接水 +%d 格" % [plan.price, added]
	if lost > 0:
		text += " · 失水 %d 格" % lost
		text += _stalled_rice_note()
	if plan.site == Global.FieldGateSite.NO_FUNDS:
		text += " · 差 %d 铜钱" % (plan.price - Global.money)
	preview_changed.emit(text)

func _preview_fill() -> void:
	preview_route = [cursor]
	var network := Global.irrigation
	var gate_center: Variant = network.field_gate_center_at(cursor)
	if gate_center != null:
		var gates := network.field_gates.duplicate()
		gates.erase(gate_center)
		preview_site = Global.ChannelSite.AVAILABLE
		_compare_flow(network.projected_flow([]), gates)
		preview_changed.emit("拆闸 · 失水 %d 格%s" % [affected_fields.size(), _stalled_rice_note()])
		return
	var exists := network.channels.has(cursor)
	preview_site = Global.ChannelSite.AVAILABLE if exists else Global.ChannelSite.BLOCKED
	blocked_cell = cursor
	if not exists:
		preview_changed.emit("填渠 · 这里是空地")
		return
	_compare_flow(network.projected_flow([], cursor), network.field_gates)
	var action := "填暗渠" if culverts.has(cursor) else "填渠"
	preview_changed.emit("%s · 失水 %d 格%s" % [action, affected_fields.size(), _stalled_rice_note()])

func _stalled_rice_note() -> String:
	var stalled := 0
	for cell in affected_fields:
		var crop: Dictionary = Global.active_crops.get(cell, {})
		if not affected_fields[cell] and crop.get("requires_channel", false) and crop.age < crop.growth_nights:
			stalled += 1
	return " · %d 格稻暂停" % stalled if stalled > 0 else ""

func _preview_dig() -> void:
	if not survey_mode and cursor == Global.irrigation.source_cell:
		preview_changed.emit("水源 · 从相邻的空地引水")
		return
	if not survey_mode and Global.irrigation.field_gate_center_at(cursor) != null:
		var key := "LT" if GamepadInput.active else Preferences.key_label(KeyBindings.FILL)
		preview_changed.emit("田口闸 · 按 %s 查看拆闸影响" % key)
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
		_compare_flow(Global.irrigation.projected_flow(planned_additions), Global.irrigation.field_gates)
		var price := "%d 铜钱" % plan["cost"]
		if preview_site == Global.ChannelSite.NO_FUNDS:
			price += " · 差 %d" % (plan["cost"] - Global.money)
		var supplied := planned_additions.any(func(cell: Vector2i) -> bool: return future_water.has(cell))
		var coverage := "供水 +%d 格" % affected_fields.size() if supplied else "仍需接通"
		preview_changed.emit("挖 %d 格 · %s · %s" % [planned_additions.size(), price, coverage])

func _compare_flow(next: Dictionary[Vector2i, int], gates: Dictionary[Vector2i, Vector2i]) -> void:
	future_water = next
	var gate_water := Global.irrigation.gate_water(next, gates)
	for cell in Global.irrigation.channels:
		if Global.irrigation.is_channel_wet(cell) != next.has(cell):
			affected_channels[cell] = next.has(cell)
	for cell in tile_map.get_used_cells():
		var supplied := gate_water.has(cell) or Irrigation.supplied_by(cell, next)
		if Global.irrigation.supplies(cell) != supplied:
			affected_fields[cell] = supplied

func _refresh_network() -> void:
	water_source.refresh(tile_map.map_to_local(Global.irrigation.source_cell))
	if not starter_canal.is_empty():
		starter_canal = starter_canal_cells()
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
	for cell in gate_candidates:
		plan_ink.draw_rect(_cell_rect(cell).grow(-2), Color("#d5bb6f"), false, 1.4)
	if not gate_row.is_empty():
		var first := tile_map.map_to_local(gate_row.front())
		var last := tile_map.map_to_local(gate_row.back())
		var ink := gain if gate_candidates.has(cursor) else Color("#b0976a")
		plan_ink.draw_line(first, last, ink, 1.3)
		for cell in gate_row:
			plan_ink.draw_circle(tile_map.map_to_local(cell), 2.0, ink)
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

func _clear_rice_plot_highlight() -> void:
	rice_plot_highlight.clear()
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
	for cell in rice_plot_highlight:
		if not Global.active_crops.has(cell) and Global.irrigation.supplies(cell):
			crop_icons.draw_rect(_cell_rect(cell).grow(-1.5), RICE_MARK, false, 1.25)
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

	for center in network.field_gates:
		_draw_field_gate(center, network.field_gates[center], network)
	_draw_footbridges()

func _draw_field_gate(center: Vector2i, inlet: Vector2i, network: Irrigation) -> void:
	var side := (inlet - center).sign()
	var axis := Vector2(side)
	var across := Vector2(-axis.y, axis.x)
	var middle := tile_map.map_to_local(center)
	var half_span := tile_size.dot(axis.abs()) * 1.5
	var mouth := (middle + axis * half_span).round()
	var end := middle - axis * (half_span - 3.0)
	var wet := network.gate_is_wet(inlet)
	var from_outside := 0.0
	if wet:
		from_outside = 1.0 if inlet == network.source_cell else tile_size.dot(axis.abs()) * 0.5
	var start := mouth + axis * from_outside
	draw_line(start, end, BED, 4.0)
	draw_line(start, end, WATER if wet else DRY, 2.0)
	draw_line(mouth - across * 5.0, mouth + across * 5.0, Color("#44372a"), 5.0)
	draw_line(mouth - across * 5.0, mouth + across * 5.0, Color("#a9814e"), 3.0)
	for direction: float in [-1.0, 1.0]:
		var post := mouth + across * 4.5 * direction
		draw_rect(Rect2(post - Vector2(1, 3), Vector2(3, 6)), Color("#665038"))
		draw_rect(Rect2(post - Vector2(0, 3), Vector2(2, 3)), Color("#d1ac73"))
	draw_rect(Rect2(mouth - Vector2(1, 2), Vector2(3, 2)), WATER_LIGHT if wet else Color("#b68c57"))

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
	for center in network.field_gates:
		var inlet := network.field_gates[center]
		if network.gate_is_wet(inlet):
			var axis := Vector2((inlet - center).sign())
			var run := tile_size.dot(axis.abs()) * 3.0
			var mouth := tile_map.map_to_local(center) + axis * run * 0.5
			var traveled := fposmod(water_frame - network.flow_distance(inlet) * 2.0, RIPPLE_SPACING)
			while traveled < run - 4.0:
				if traveled > 4.0:
					var point := (mouth - axis * traveled).round()
					var streak := Vector2.ONE + axis.abs() * 2.0
					flow_ink.draw_rect(Rect2(point - (streak * 0.5).floor(), streak), WATER_LIGHT)
				traveled += RIPPLE_SPACING
	if editing and not preview_fill and not survey_mode:
		for cell in starter_canal:
			var bed := _cell_rect(cell).grow(-2)
			flow_ink.draw_rect(bed, Color("#b590544d"))
			flow_ink.draw_rect(bed, Color("#f3cd7a"), false, 1.3)
		for cell in rice_plot_highlight:
			flow_ink.draw_rect(_cell_rect(cell).grow(-1.5), RICE_MARK, false, 1.25)

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

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(tile_map.map_to_local(cell) - tile_size / 2.0, tile_size)
