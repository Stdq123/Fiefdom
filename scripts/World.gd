extends Node2D

signal seed_selected(seed_id: String)
signal channel_mode_changed(enabled: bool)
signal channel_feedback(message: String)
signal visitor_changed(data: VisitorData)

const SEED_ORDER := CropData.IDS
const FIELD_IMPACTS := preload("res://assets/farming/field-impacts.svg")
const HARVEST_TEXT_OFFSET := -4.0
const LANDSCAPE := preload("res://scripts/Landscape.gd")
const DUTY_STATIONS := {
	RetainerData.Duty.FIELD: {"anchor": Vector2(136, 154), "place": "田边"},
	RetainerData.Duty.REEL: {"anchor": EstateLayout.SILK_SHED_YARD + Vector2(-12, 5), "place": "蚕桑棚"},
	RetainerData.Duty.TEACH: {"anchor": Vector2(-20, 49), "place": "堂前"},
	RetainerData.Duty.GUARD: {"anchor": Vector2(184, 161), "place": "东路"},
	RetainerData.Duty.HARVEST: {"anchor": Vector2(147, 113), "place": "田边"},
}
enum FieldAction { NONE, TILL, SOW, WATER, HARVEST, CHANNEL, RAIN, WATERED, DRY_RICE, RICE_SEED }
const FIELD_COSTS := {
	FieldAction.TILL: 2, FieldAction.SOW: 2, FieldAction.WATER: 1, FieldAction.HARVEST: 3,
}

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var crops_layer: TileMapLayer = $TileMapLayer/CropsLayer
@onready var player: Player = $Player
@onready var tax_envoy: Node2D = $TaxEnvoy
@onready var irrigation_overlay = $TileMapLayer/IrrigationOverlay
@onready var pavilion_rest: PavilionRest = $PavilionRest

var channel_mode: bool:
	get: return irrigation_overlay.editing

var active_crops: Dictionary:
	get: return Global.active_crops

var retainer_instances: Dictionary = {} # RetainerData -> Retainer Node

# Preload crop data (for prototype)
# var millet_data = preload("res://scripts/CropData.gd").new() # Use ItemManager instead
var current_seed_id: String:
	get: return Global.selected_seed_id
	set(value): Global.selected_seed_id = value

var floating_text_scene = preload("res://scenes/FloatingText.tscn")
var retainer_scene = preload("res://scenes/Retainer.tscn")
var visitor_scene = preload("res://scenes/Visitor.tscn")
var enemy_scene = preload("res://scenes/Enemy.tscn")
var active_visitors: Array[Visitor] = []
var scheduled_visitor: VisitorData
var field_guest: Node2D
var sweep_action := FieldAction.NONE
var sweep_field := Rect2i()
var sweep_pointer := Vector2.ZERO
var swept_cells: Dictionary[Vector2i, bool] = {}
var sweep_harvests := 0
var sweep_gains := Vector4i.ZERO
var sweep_popup: Label

func _ready() -> void:
	# millet_data.crop_name = "黍" ... # Moved to ItemManager

	GameEvents.day_advanced.connect(_on_day_advanced)
	GameEvents.seed_cycle_requested.connect(_cycle_seed)
	GameEvents.retainer_assigned.connect(_on_retainer_assigned)
	GameEvents.retainer_duty_changed.connect(_on_retainer_duty_changed)
	GameEvents.retainer_recruited.connect(_on_retainer_recruited)
	GameEvents.retainer_departed.connect(_on_retainer_departed)
	GameEvents.road_provisions_delivered.connect(_on_road_provisions_delivered)
	GameEvents.silk_sample_delivered.connect(_on_silk_sample_delivered)
	GameEvents.herb_garden_feedback.connect(_on_herb_garden_feedback)
	GameEvents.east_watch_built.connect(_refresh_defense_notice)
	GameEvents.channel_survey_learned.connect(_on_channel_survey_learned)
	for milestone in [GameEvents.road_rest_changed, GameEvents.channel_survey_learned, GameEvents.silk_sample_delivered,
			GameEvents.ravine_journal_changed, GameEvents.east_watch_built]:
		milestone.connect(_update_visitor_activity)
	GameEvents.daylight_changed.connect(_update_visitor_clock)
	GameEvents.tax_reform_choice_made.connect(_on_tax_reform_choice_made)
	GameEvents.management_visibility_changed.connect(_end_sweep.unbind(1))
	GameEvents.estate_room_changed.connect(_on_estate_room_changed)
	get_window().focus_exited.connect(_end_sweep)
	get_window().mouse_exited.connect(_end_sweep)
	get_viewport().size_changed.connect(_end_sweep)
	# Initialize first well field if none exists
	if Global.well_fields.is_empty():
		Global.add_well_field(Global.FIRST_FIELD_CENTER)
		Global.well_fields[0]["is_unlocked"] = true  # First field is already ready
		Global.well_fields[0]["reclamation_progress"] = Global.RECLAMATION_NIGHTS
		print("Initialized first well field at (5, 5)")
	for field in Global.well_fields:
		if field["is_unlocked"]:
			_draw_well_field(field["center_pos"])
	$TileMapLayer/WellFieldMarker.refresh_markers()

	# Setup Navigation (Runtime generation for prototype)
	setup_navigation()

	# Spawn retainers from Global
	for r_data in Global.retainers:
		spawn_retainer(r_data, true)

	_refresh_visitor()
	_refresh_field_keeper_visit()

	# Restore crop visuals
	restore_crops_visuals()

	if Global.raid_day > 0:
		_spawn_raider()
	_refresh_defense_notice.call_deferred()

func _spawn_raider() -> void:
	var enemy = enemy_scene.instantiate()
	enemy.type = Global.raid_kind
	enemy.raid = true
	enemy.position = Vector2(264, 152)
	add_child(enemy)
	print("Raid on day ", Global.raid_day, " enemy ", enemy.type)

func _refresh_defense_notice() -> void:
	if Global.defense_review_ready() and not Global.is_raid_day(Global.current_day + 1):
		GameEvents.world_notice.emit("东路已守住 · 可找弋戎复盘")
	else:
		GameEvents.world_notice.emit("")

func get_random_crop_pos() -> Vector2i:
	if active_crops.is_empty():
		return Vector2i(-1, -1)
	var keys = active_crops.keys()
	return keys[randi() % keys.size()]

func destroy_crop(grid_pos: Vector2i) -> void:
	if active_crops.has(grid_pos):
		active_crops.erase(grid_pos)
		crops_layer.erase_cell(grid_pos)
		if Global.raid_day > 0:
			Global.raid_crop_losses += 1
		GameEvents.farm_state_changed.emit()
		spawn_floating_text(grid_pos, "来敌毁掉了作物", Color("#f09879"))

func get_crop_world_pos(grid_pos: Vector2i) -> Vector2:
	return to_local(tile_map.to_global(tile_map.map_to_local(grid_pos)))

func worksite_at(cell: Vector2i) -> Dictionary:
	for field in Global.well_fields:
		if not field["is_unlocked"] and Rect2i(field["center_pos"] - Vector2i.ONE, Vector2i(3, 3)).has_point(cell):
			return field
	return {}

func nearest_worksite() -> int:
	var result := -1
	var nearest := INF
	for field in Global.well_fields:
		if field["is_unlocked"]:
			continue
		var center := to_global(get_crop_world_pos(field["center_pos"]))
		var distance := player.global_position.distance_squared_to(center)
		if distance < nearest:
			result = field["field_id"]
			nearest = distance
	return result

func restore_crops_visuals() -> void:
	for grid_pos in active_crops:
		_draw_crop(grid_pos)

func _draw_crop(grid_pos: Vector2i) -> void:
	var crop: Dictionary = active_crops[grid_pos]
	var data: CropData = crop["data"]
	var stage := 0
	if crop["age"] >= crop["growth_nights"]:
		stage = 2
	elif crop["age"] > 0:
		stage = 1
	crops_layer.set_cell(grid_pos, data.atlas_source_id, data.stages_atlas_coords[stage])

func setup_navigation() -> void:
	var nav_region = NavigationRegion2D.new()
	var nav_poly = NavigationPolygon.new()
	nav_poly.vertices = PackedVector2Array([Vector2(-500, -500), Vector2(-500, 500), Vector2(500, 500), Vector2(500, -500)])
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)
	print("Navigation Setup Complete")

func spawn_retainer(data: RetainerData, restoring := false) -> void:
	var retainer := retainer_scene.instantiate() as Retainer
	retainer.data = data
	retainer.position = _duty_station(data)
	add_child(retainer)
	retainer_instances[data] = retainer
	if restoring:
		retainer.restore_evening()

func _duty_station(data: RetainerData) -> Vector2:
	var slot := 0
	for other in Global.retainers:
		if other == data:
			break
		if other.duty == data.duty:
			slot += 1
	return DUTY_STATIONS[data.duty]["anchor"] + Vector2(19 * (slot % 3), 17 * floori(float(slot) / 3))

func duty_place(data: RetainerData) -> String:
	var retainer := retainer_instances.get(data) as Retainer
	if retainer and not retainer.pavilion_note().is_empty():
		return "南路亭"
	return DUTY_STATIONS[data.duty]["place"]

func path_to_pavilion_seat(from: Vector2, seat: Vector2) -> Array[Vector2]:
	var table := pavilion_rest.position
	var path: Array[Vector2] = []
	if from.distance_to(table) > 56.0:
		var start := from
		if start.x < 0.0 and start.y < 146.0:
			start.x = 17.0 # Pass the east side of the silk shed.
			path.append(start)
		elif start.x >= 80.0 and start.y < 205.0:
			path.append_array(Array(_follow_lane(LANDSCAPE.ESTATE_EAST_LANE, start, LANDSCAPE.EAST_LANE_JUNCTION)))
			start = LANDSCAPE.EAST_LANE_JUNCTION
		path.append_array(Array(_follow_lane(LANDSCAPE.ESTATE_SOUTH_LANE, start, EstateLayout.PAVILION_JUNCTION)))
		path.append_array(EstateLayout.PAVILION_COURT.slice(0, -1))
		if seat.y < table.y:
			path.append(table + Vector2(-27, -14))
		elif seat.x > table.x:
			path.append(table + Vector2(25, 15))
	path.append(seat)
	return path

func _refresh_duty_stations() -> void:
	for data in retainer_instances:
		var retainer = retainer_instances[data]
		var station := to_global(_duty_station(data))
		if retainer.home_position != station:
			retainer.home_position = station
			retainer.set_state(Retainer.State.IDLE)

func _on_retainer_assigned(data: RetainerData, grid_pos: Vector2i) -> void:
	if retainer_instances.has(data):
		var retainer = retainer_instances[data]
		data.assigned_area = grid_pos
		if data.duty in [RetainerData.Duty.FIELD, RetainerData.Duty.HARVEST]:
			retainer.set_state(retainer.State.IDLE)
		else:
			Global.assign_duty(data, RetainerData.Duty.FIELD)
		print("World: Assigned ", data.name, " to ", grid_pos)

func _on_retainer_duty_changed(_data: RetainerData) -> void:
	_refresh_duty_stations()

func _on_retainer_recruited(data: RetainerData) -> void:
	spawn_retainer(data)
	if data.name == VisitorData.FIELD_KEEPER:
		_refresh_field_keeper_visit()
	if Global.last_recruit_day == Global.current_day:
		if Global.last_recruit_outside_rotation:
			_refresh_handoff_visitor()
			_report_visitor_activity()
		else:
			_refresh_visitor()
	var returned: bool = Global.neighbor_departures.get(data.name, {}).get("returned_day", 0) == Global.current_day
	var notice := "%s重新留任" if returned else "%s留在了封地"
	spawn_floating_text(Vector2i(5, 5), notice % data.name, Color("#efce80"))

func _on_retainer_departed(data: RetainerData) -> void:
	var retainer = retainer_instances.get(data)
	if is_instance_valid(retainer):
		retainer.queue_free()
	retainer_instances.erase(data)
	_refresh_duty_stations()
	if data.name == VisitorData.FIELD_KEEPER:
		_refresh_field_keeper_visit()
	elif data.name == VisitorData.RAVINE_GUIDE:
		_refresh_handoff_visitor()
		_report_visitor_activity()

func _on_road_provisions_delivered() -> void:
	var cell := tile_map.local_to_map(tile_map.to_local(player.global_position))
	spawn_floating_text(cell, "路粮已备 · 声望 +%d" % Global.balance.interaction_reputation_gain, Color("#efce80"))

func _on_silk_sample_delivered() -> void:
	var cell := tile_map.local_to_map(tile_map.to_local(player.global_position))
	spawn_floating_text(cell, "样绸已交 · 铜钱 +%d\n堂屋添了西廊纹衣" % Global.silk_sample_price(), Color("#efce80"))

func _on_herb_garden_feedback(message: String) -> void:
	var cell := tile_map.local_to_map(tile_map.to_local(player.global_position))
	spawn_floating_text(cell, message, Color("#bad29a"))

func _on_channel_survey_learned() -> void:
	spawn_floating_text(Global.irrigation.source_cell, "立起量水尺 · 可用放样", Color("#ade2cc"))

func _on_tax_reform_choice_made(choice: Global.TaxReformChoice) -> void:
	if choice == Global.TaxReformChoice.REFORMED:
		for field in Global.well_fields:
			if field["is_unlocked"]:
				_draw_well_field(field["center_pos"])
		$TileMapLayer/WellFieldMarker.refresh_markers()

func is_crop_dry(grid_pos: Vector2i) -> bool:
	return Global.field_crop_is_dry(grid_pos)

func find_field_task(status: int, public_only := false) -> Variant:
	if status == Global.MulberryRoute.PLANT:
		return _find_mulberry_planting_site()
	if status == Global.TributeRoute.TEND:
		return Global.tribute_field_plan().get("cell")
	var nearest: Variant = null
	var distance := INF
	var public_selected := false
	var start := estate_player_point()
	for cell: Vector2i in active_crops:
		if not matches_field_route(cell, status):
			continue
		var is_public := Global.is_public_plot(cell)
		if (public_only or public_selected) and not is_public:
			continue
		var distance_to_crop := start.distance_squared_to(get_crop_world_pos(cell))
		if is_public != public_selected or distance_to_crop < distance:
			nearest = cell
			distance = distance_to_crop
			public_selected = is_public
	return nearest

func matches_field_route(cell: Vector2i, status: int) -> bool:
	if status == Global.TributeRoute.TEND:
		return Global.is_public_plot(cell)
	if status == Global.MulberryRoute.PLANT:
		return (tile_map.get_cell_source_id(cell) >= 0 and not Global.is_public_plot(cell)
			and not active_crops.has(cell) and not Global.field_seed_plans.has(cell))
	if status in [Global.MulberryRoute.WATER, Global.MulberryRoute.HARVEST]:
		var crop: Dictionary = active_crops.get(cell, {})
		if crop.get("id") != "mulberry" or Global.is_public_plot(cell):
			return false
		status = Global.NightGrowth.DRY if status == Global.MulberryRoute.WATER else Global.NightGrowth.READY
	return Global.crop_night_status(cell) == status

func _find_mulberry_planting_site() -> Variant:
	var start := estate_player_point()
	var nearest: Variant = null
	var distance := INF
	var priority := -1
	for cell: Vector2i in tile_map.get_used_cells():
		if not matches_field_route(cell, Global.MulberryRoute.PLANT):
			continue
		var site_priority := 2 * int(Global.irrigation.supplies(cell)) + int(Global.tilled_cells.has(cell))
		var walking := start.distance_squared_to(get_crop_world_pos(cell))
		if site_priority > priority or (site_priority == priority and walking < distance):
			nearest = cell
			distance = walking
			priority = site_priority
	return nearest

func mulberry_growth_remaining() -> int:
	var soonest := 0
	for cell: Vector2i in active_crops:
		var crop: Dictionary = active_crops[cell]
		if crop.id != "mulberry" or Global.is_public_plot(cell):
			continue
		var nights: int = crop.growth_nights - crop.age
		if nights > 0 and (soonest == 0 or nights < soonest):
			soonest = nights
	return soonest

func is_crop_ripe(grid_pos: Vector2i) -> bool:
	return Global.field_crop_is_ripe(grid_pos)

func council_harvest_forecast(choice: Global.TaxReformChoice) -> Dictionary:
	var totals := {"plots": 0, "tribute": 0, "stock": 0, "copper": 0, "leaves": 0}
	var rate := clampf(Global.balance.reformed_tax_rate, 0.0, 1.0)
	for cell: Vector2i in active_crops:
		var tile := tile_map.get_cell_tile_data(cell)
		if tile == null or not is_crop_ripe(cell):
			continue
		var crop: Dictionary = active_crops[cell]
		var data: CropData = crop["data"]
		var proceeds := Global.harvest_proceeds(Global.is_public_plot(cell), data.sell_price,
			Global.crop_rotation_bonus(cell, data), choice, rate)
		totals["plots"] += 1
		for resource in ["tribute", "stock", "copper"]:
			totals[resource] += proceeds[resource]
		if crop["id"] == "mulberry":
			totals["leaves"] += proceeds["stock"] * Global.balance.mulberry_leaves_per_harvest
	return totals

func crop_job(worker: Retainer, cell: Vector2i) -> Global.FieldJob:
	var job := Global.field_job(worker.data.duty, cell)
	if job == Global.FieldJob.NONE:
		return job
	for other: Retainer in retainer_instances.values():
		if (other != worker and other.data.duty == worker.data.duty
			and other.target_grid_pos == cell and other.current_state != Retainer.State.IDLE):
			return Global.FieldJob.NONE
	return job

func find_work_crop(worker: Retainer) -> Vector2i:
	var assigned := worker.data.assigned_area
	if assigned != Retainer.NO_CELL and crop_job(worker, assigned) != Global.FieldJob.NONE:
		return assigned
	var nearest := Retainer.NO_CELL
	var distance := INF
	for cell: Vector2i in Global.tilled_cells:
		var distance_to_crop := worker.global_position.distance_squared_to(to_global(get_crop_world_pos(cell)))
		if distance_to_crop < distance and crop_job(worker, cell) != Global.FieldJob.NONE:
			distance = distance_to_crop
			nearest = cell
	return nearest

func water_crop(grid_pos: Vector2i) -> bool:
	if not Global.water_field_crop(grid_pos):
		return false
	_show_field_impact(grid_pos, Player.Action.WATER)
	print("Crop watered at ", grid_pos)
	return true

func _draw_well_field(center: Vector2i) -> void:
	var public_center := Global.is_public_plot(center)
	for x in range(-1, 2):
		for y in range(-1, 2):
			var coords := center + Vector2i(x, y)
			var public_field := coords == center and public_center
			var soil := 1 if Global.tilled_cells.has(coords) else 0
			tile_map.set_cell(coords, 0, Vector2i(1 if public_field else 0, soil))

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_end_sweep()

func _input(event: InputEvent) -> void:
	if channel_mode:
		if event is InputEventMouse:
			irrigation_overlay.track_pointer(event.position, _fill_held(event))
		elif Preferences.matches(event, KeyBindings.FILL):
			irrigation_overlay.track_pointer(irrigation_overlay.pointer, event.is_pressed())
	if sweep_action == FieldAction.NONE:
		return
	if event is InputEventMouseButton:
		if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
			_end_sweep()
	elif event is InputEventMouseMotion:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0 or get_viewport().gui_get_hovered_control() != null:
			_end_sweep()

func _unhandled_input(event: InputEvent) -> void:
	if Global.is_indoors() or player.world_controls_blocked() or player.training_cart.visible:
		return
	if (event is InputEventKey or event is InputEventAction) and event.is_pressed() and not event.is_echo():
		if channel_mode and event.is_action_pressed("ui_cancel"):
			if irrigation_overlay.survey_mode:
				irrigation_overlay.cancel_survey()
				channel_feedback.emit("放样已取消")
			else:
				set_channel_mode(false)
			get_viewport().set_input_as_handled()
			return
		if channel_mode and irrigation_overlay.survey_mode and Preferences.matches(event, KeyBindings.ROTATE):
			irrigation_overlay.flip_survey()
			get_viewport().set_input_as_handled()
			return
		if not channel_mode:
			for index in KeyBindings.SEEDS.size():
				if Preferences.matches(event, KeyBindings.SEEDS[index]):
					select_seed(SEED_ORDER[index])
					get_viewport().set_input_as_handled()
					return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_end_sweep()
		var grid_pos := field_at(event.position)
		if channel_mode:
			_edit_channel(grid_pos, _fill_held(event))
			get_viewport().set_input_as_handled()
		else:
			_begin_sweep(grid_pos, event.position)
			if handle_interaction(grid_pos):
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and sweep_action != FieldAction.NONE:
		if player.conversation_open or channel_mode:
			_end_sweep()
			return
		_sweep_to(event.position)
		get_viewport().set_input_as_handled()

func _fill_held(event: InputEventMouse) -> bool:
	return (GamepadInput.filling or Input.is_action_pressed(KeyBindings.FILL)
		or (Preferences.binding(KeyBindings.FILL) == KEY_SHIFT and event.shift_pressed))

func _begin_sweep(cell: Vector2i, pointer: Vector2) -> void:
	var action := field_action(cell)
	var cost := field_cost(action)
	if cost == 0 or cost > Global.current_stamina:
		return
	for field in Global.well_fields:
		var bounds := Rect2i(field["center_pos"] - Vector2i.ONE, Vector2i(3, 3))
		if field["is_unlocked"] and bounds.has_point(cell):
			sweep_field = bounds
			sweep_pointer = pointer
			sweep_action = action
			swept_cells[cell] = true
			return

func _sweep_to(pointer: Vector2) -> void:
	if pointer == sweep_pointer:
		return
	var tile_size := Vector2(tile_map.tile_set.tile_size)
	var origin := tile_map.map_to_local(Vector2i.ZERO) - tile_size * 0.5
	# Project both ends through the current view to measure pointer travel.
	var to_grid := tile_map.get_global_transform_with_canvas().affine_inverse()
	var precision := Vector2(0.0001, 0.0001)
	var from := ((to_grid * sweep_pointer - origin) / tile_size).snapped(precision)
	var to := ((to_grid * pointer - origin) / tile_size).snapped(precision)
	sweep_pointer = pointer
	var travel := to - from
	if travel == Vector2.ZERO:
		return
	var step := Vector2i(travel.sign())
	var crossed := _stroke_cell(from, step)
	var destination := _stroke_cell(to, -step)
	while true:
		if not sweep_field.has_point(crossed):
			_end_sweep()
			return
		if not swept_cells.has(crossed):
			swept_cells[crossed] = true
			if field_action(crossed) == sweep_action:
				var enough := Global.current_stamina >= field_cost(sweep_action)
				handle_interaction(crossed)
				if not enough:
					_end_sweep()
					return
		if crossed == destination:
			return
		var next_x := (crossed.x + int(step.x > 0) - from.x) / travel.x if crossed.x != destination.x else INF
		var next_y := (crossed.y + int(step.y > 0) - from.y) / travel.y if crossed.y != destination.y else INF
		if is_equal_approx(next_x, next_y):
			crossed += step
		elif next_x < next_y:
			crossed.x += step.x
		else:
			crossed.y += step.y

func _stroke_cell(point: Vector2, inward: Vector2i) -> Vector2i:
	# At a boundary, choose the tile toward the interior of the segment.
	return Vector2i(ceili(point.x) - 1 if inward.x < 0 else floori(point.x),
		ceili(point.y) - 1 if inward.y < 0 else floori(point.y))

func _end_sweep() -> void:
	sweep_action = FieldAction.NONE
	swept_cells.clear()
	sweep_harvests = 0
	sweep_gains = Vector4i.ZERO
	sweep_popup = null

func field_at(viewport_point: Vector2) -> Vector2i:
	return tile_map.local_to_map(tile_map.make_canvas_position_local(viewport_point))

func select_seed(seed_id: String) -> void:
	if current_seed_id != seed_id and SEED_ORDER.has(seed_id):
		_end_sweep()
		current_seed_id = seed_id
		seed_selected.emit(seed_id)

func _cycle_seed(step: int) -> void:
	if not channel_mode and not Global.is_indoors():
		select_seed(SEED_ORDER[posmod(SEED_ORDER.find(current_seed_id) + step, SEED_ORDER.size())])

func set_channel_mode(enabled: bool) -> void:
	var editing: bool = enabled and not Global.is_indoors() and Global.tech_unlocked["irrigation"]
	if channel_mode != editing:
		_end_sweep()
		irrigation_overlay.set_editing(editing)
		channel_mode_changed.emit(editing)

func _on_estate_room_changed(room: Global.EstateRoom) -> void:
	if room != Global.EstateRoom.OUTDOORS:
		set_channel_mode(false)
		_end_sweep()

func estate_player_point() -> Vector2:
	match Global.estate_room:
		Global.EstateRoom.HALL: return to_local($HallRest/Yard.global_position)
		Global.EstateRoom.SILK_SHED: return to_local($SilkShed/Yard.global_position)
	return to_local(player.global_position)

func _edit_channel(cell: Vector2i, fill: bool) -> void:
	if irrigation_overlay.survey_mode:
		channel_feedback.emit(irrigation_overlay.select_survey_cell(cell))
		return
	if fill:
		channel_feedback.emit("水渠已填平" if Global.fill_channel(cell) else "这里没有水渠")
		return
	match Global.build_channel(cell):
		Global.ChannelSite.AVAILABLE:
			channel_feedback.emit("水渠已通水" if Global.irrigation.is_channel_wet(cell) else "已挖渠，等待接通水源")
		Global.ChannelSite.BLOCKED:
			channel_feedback.emit("请选择封地内的空地")
		Global.ChannelSite.FOUNDATION:
			channel_feedback.emit("这里是屋基 · 请从屋外引渠")
		Global.ChannelSite.ALREADY_BUILT:
			channel_feedback.emit("这里已有水渠")
		Global.ChannelSite.NO_FUNDS:
			channel_feedback.emit("铜钱不足")
		Global.ChannelSite.LOCKED:
			channel_feedback.emit("请先在科技面板解锁水利")

func field_action(grid_pos: Vector2i) -> FieldAction:
	if active_crops.has(grid_pos):
		var crop: Dictionary = active_crops[grid_pos]
		if crop["age"] >= crop["growth_nights"]:
			return FieldAction.HARVEST
		match Global.crop_water(grid_pos, crop):
			Global.CropWater.CANAL: return FieldAction.CHANNEL
			Global.CropWater.BLOCKED: return FieldAction.DRY_RICE
			Global.CropWater.RAIN: return FieldAction.RAIN
			Global.CropWater.HAND: return FieldAction.WATERED
			_: return FieldAction.WATER
	match tile_map.get_cell_atlas_coords(grid_pos).y:
		0: return FieldAction.TILL
		1:
			var seed := ItemManager.get_crop(current_seed_id)
			if seed and seed.is_water_crop and not Global.irrigation.supplies(grid_pos):
				return FieldAction.RICE_SEED
			return FieldAction.SOW if seed else FieldAction.NONE
	return FieldAction.NONE

func field_cost(action: FieldAction) -> int:
	return FIELD_COSTS.get(action, 0)

func field_message(grid_pos: Vector2i, action: FieldAction) -> String:
	if field_cost(action) > Global.current_stamina:
		return "体力不足 · 需 %d" % field_cost(action)
	match action:
		FieldAction.TILL: return "翻地"
		FieldAction.SOW:
			var seed := ItemManager.get_crop(current_seed_id)
			return "播种 · %s · %d 夜" % [seed.crop_name, Global.sowing_nights(seed)]
		FieldAction.HARVEST:
			var crop: CropData = active_crops[grid_pos]["data"]
			var rotation := " · 轮作 +1" if Global.fertile_cells.has(grid_pos) and not crop.restores_fertility else ""
			return "收获 · " + crop.crop_name + rotation
		FieldAction.WATER: return "待浇水"
		FieldAction.CHANNEL: return "渠水已到"
		FieldAction.RAIN: return "雨已润土"
		FieldAction.WATERED: return "已浇水"
		FieldAction.DRY_RICE: return "稻田断水"
		FieldAction.RICE_SEED: return "稻种需要通水的水渠"
	return ""

func handle_interaction(grid_pos: Vector2i) -> bool:
	var action := field_action(grid_pos)
	if action == FieldAction.NONE:
		return false
	var cost := field_cost(action)
	if cost > Global.current_stamina:
		spawn_floating_text(grid_pos, field_message(grid_pos, action), Color.SALMON)
		return true
	match action:
		FieldAction.TILL:
			_till_soil(grid_pos)
		FieldAction.SOW:
			_plant_crop(grid_pos)
		FieldAction.WATER:
			Global.current_stamina -= cost
			water_crop(grid_pos)
			player.show_action(Player.Action.WATER, to_global(get_crop_world_pos(grid_pos)))
			GameEvents.stamina_changed.emit(Global.current_stamina)
		FieldAction.HARVEST:
			harvest_crop(grid_pos)
		FieldAction.CHANNEL, FieldAction.RAIN, FieldAction.WATERED:
			spawn_floating_text(grid_pos, field_message(grid_pos, action) + " · 过夜后生长", Color.CYAN)
		FieldAction.DRY_RICE:
			spawn_floating_text(grid_pos, "稻田断水 · 请接通水源", Color.ORANGE)
		FieldAction.RICE_SEED:
			spawn_floating_text(grid_pos, field_message(grid_pos, action), Color.ORANGE)
	return true

func _show_field_impact(cell: Vector2i, action: ToolGesture.Action) -> void:
	var impact := Sprite2D.new()
	impact.texture = FIELD_IMPACTS
	impact.hframes = 4
	impact.vframes = 3
	impact.frame_coords = Vector2i(action, 0)
	impact.position = get_crop_world_pos(cell)
	impact.z_index = 2
	add_child(impact)
	var motion := impact.create_tween()
	motion.tween_interval(0.08)
	motion.tween_callback(impact.set_frame_coords.bind(Vector2i(action, 1)))
	motion.tween_interval(0.10)
	motion.tween_callback(impact.set_frame_coords.bind(Vector2i(action, 2)))
	motion.tween_property(impact, "modulate:a", 0.0, 0.12)
	motion.tween_callback(impact.queue_free)

func _till_soil(grid_pos: Vector2i) -> void:
	Global.current_stamina -= field_cost(FieldAction.TILL)
	GameEvents.stamina_changed.emit(Global.current_stamina)
	var atlas := tile_map.get_cell_atlas_coords(grid_pos)
	tile_map.set_cell(grid_pos, 0, Vector2i(atlas.x, 1))
	Global.tilled_cells[grid_pos] = true
	GameEvents.farm_state_changed.emit()
	_show_field_impact(grid_pos, Player.Action.TILL)
	player.show_action(Player.Action.TILL, to_global(get_crop_world_pos(grid_pos)))
	print("Tilled at ", grid_pos)

func _plant_crop(grid_pos: Vector2i) -> void:
	if not sow_crop(grid_pos, current_seed_id):
		return
	Global.current_stamina -= field_cost(FieldAction.SOW)
	GameEvents.stamina_changed.emit(Global.current_stamina)
	player.show_action(Player.Action.SOW, to_global(get_crop_world_pos(grid_pos)))

func sow_crop(grid_pos: Vector2i, seed_id: String) -> bool:
	if not Global.sow_field_crop(grid_pos, seed_id):
		return false
	_draw_crop(grid_pos)
	_show_field_impact(grid_pos, Player.Action.SOW)
	print("Planted ", ItemManager.crop_label(seed_id), " at ", grid_pos)
	return true

func harvest_crop(grid_pos: Vector2i, worker: Retainer = null) -> bool:
	var tile_data := tile_map.get_cell_tile_data(grid_pos)
	if tile_data == null or Global.outcome != Global.Outcome.RUNNING or not is_crop_ripe(grid_pos):
		return false
	if not worker:
		var cost := field_cost(FieldAction.HARVEST)
		if Global.current_stamina < cost:
			return false
		Global.current_stamina -= cost
		GameEvents.stamina_changed.emit(Global.current_stamina)

	var harvest := Global.harvest_field_crop(grid_pos)
	var message := "国库 +%d" % harvest.tribute if harvest.public else (
		"%s +%d · 铜钱 +%d" % [harvest.crop, harvest.stock, harvest.copper])
	var tone := Color("#efce80") if harvest.public else Color("#d2de9e")
	if harvest.leaves > 0:
		message += " · 桑叶 +%d" % harvest.leaves
	if harvest.rotated:
		message += " · 轮作增收"
	if harvest.fertile:
		message += " · 肥地"

	if active_crops.has(grid_pos):
		_draw_crop(grid_pos)
	else:
		crops_layer.erase_cell(grid_pos)
	if worker:
		spawn_floating_text(grid_pos, worker.data.name + "收割 · " + message, tone, HARVEST_TEXT_OFFSET)
	elif sweep_action == FieldAction.HARVEST:
		sweep_harvests += 1
		sweep_gains += Vector4i(harvest.tribute, harvest.stock, harvest.copper, harvest.leaves)
		if is_instance_valid(sweep_popup):
			sweep_popup.queue_free()
		if sweep_harvests > 1:
			var totals := PackedStringArray(["收获 %d 格" % sweep_harvests])
			var names := ["国库", "作物", "铜钱", "桑叶"]
			for i in names.size():
				if sweep_gains[i] > 0:
					totals.append("%s +%d" % [names[i], sweep_gains[i]])
			message = " · ".join(totals)
		sweep_popup = spawn_floating_text(grid_pos, message, tone, HARVEST_TEXT_OFFSET)
	else:
		spawn_floating_text(grid_pos, message, tone, HARVEST_TEXT_OFFSET)
	_show_field_impact(grid_pos, Player.Action.HARVEST)
	if not worker:
		player.show_action(Player.Action.HARVEST, to_global(get_crop_world_pos(grid_pos)))
	if harvest.first_tribute:
		var receipt := "首份纳贡已入库"
		if Global.rotation_offer_ready() and neighbor_actor(VisitorData.FIELD_KEEPER):
			receipt += " · 可找渠伯谈轮作"
		GameEvents.world_notice.emit(receipt)
	return true

func spawn_floating_text(grid_pos: Vector2i, text: String, color: Color, offset_y := 13.0) -> Label:
	var instance := floating_text_scene.instantiate() as Label
	instance.text = text
	instance.modulate = color
	instance.scale = Vector2.ONE / player.camera.zoom
	var center := get_crop_world_pos(grid_pos)
	var half_width := instance.get_combined_minimum_size().x * instance.scale.x / 2
	instance.position = center + Vector2(-half_width, offset_y)
	add_child(instance)
	return instance

func _on_day_advanced(new_day: int) -> void:
	_end_sweep()
	print("Day Advanced to ", new_day)
	for field in Global.well_fields:
		if not field["is_unlocked"] and Global.advance_reclamation(field["field_id"]) and field["is_unlocked"]:
			_draw_well_field(field["center_pos"])
	
	var overnight := Global.field_night_forecast(new_day - 1)
	for pos in active_crops:
		var crop: Dictionary = active_crops[pos]
		var water := Global.crop_water(pos, crop, new_day - 1)
		var growth := Global.night_growth(crop, water)
		if growth == Global.NightGrowth.GROW or growth == Global.NightGrowth.RIPEN:
			crop["age"] += 1
			if water == Global.CropWater.CANAL and Global.first_channel_growth_day == 0:
				Global.first_channel_growth_day = new_day
			_draw_crop(pos)
		crop["watered"] = false
	Global.last_field_night = overnight
	for retainer: Retainer in retainer_instances.values():
		retainer.resume_duty_at_dawn()
	_refresh_visitor(true)
	_refresh_field_keeper_visit()
	if Global.begin_raid(new_day):
		_spawn_raider()
	_refresh_defense_notice()

func current_visitor() -> VisitorData:
	var actor := current_visitor_actor()
	return actor.data if actor else null

func current_visitor_actor() -> Visitor:
	var regular := _scheduled_visitor_actor()
	return regular if regular else handoff_visitor()

func _scheduled_visitor_actor() -> Visitor:
	for visitor in active_visitors:
		if visitor.data == scheduled_visitor:
			return visitor
	return null

func handoff_visitor() -> Visitor:
	for visitor in active_visitors:
		if visitor.data.handoff_visit:
			return visitor
	return null

func recruitment_candidate() -> Dictionary:
	var visitors := active_visitors.duplicate()
	if is_instance_valid(field_guest):
		visitors.append(field_guest as Visitor)
	var candidates: Array[Dictionary] = []
	for actor: Visitor in visitors:
		var location := actor.visit_note() if actor.walking_to_stop else "在" + actor.visit_location()
		candidates.append({"guest": actor.data, "location": location})
	var trip := silk_trip_stop()
	if not trip.is_empty() and not _scheduled_visitor_actor():
		candidates.append({"guest": scheduled_visitor, "location": trip.note})
	for candidate in candidates:
		if Global.can_recruit_visitor(candidate.guest):
			return candidate
	return candidates.front() if not candidates.is_empty() else {}

func silk_trip_note() -> String:
	return silk_trip_stop().get("note", "")

func silk_trip_stop() -> Dictionary:
	if not scheduled_visitor:
		return {}
	var note := ""
	match scheduled_visitor.silk_trip():
		VisitorData.SilkTrip.WEST_ROAD:
			note = "正沿西路去西市"
		VisitorData.SilkTrip.STALL:
			note = "在西市绸摊，酉时到南路亭"
		VisitorData.SilkTrip.RETURN_ROAD:
			return {"title": "陶辛 · 酉时南路亭", "place": "南路亭", "point": LANDSCAPE.PAVILION_REST_FOOT,
				"note": "正返程，酉时到南路亭"}
		_:
			return {}
	return {"title": "陶辛 · 西市绸摊", "place": "西市", "point": $WestMarketGate.position, "note": note}

func neighbor_actor(speaker: String) -> Node2D:
	if speaker == Global.TAX_ENVOY and Global.tax_council_waiting():
		return tax_envoy
	for resident: RetainerData in retainer_instances:
		if resident.name == speaker:
			return retainer_instances[resident]
	for visitor: Node2D in active_visitors:
		if visitor.data.name == speaker:
			return visitor
	if speaker == VisitorData.FIELD_KEEPER and is_instance_valid(field_guest):
		return field_guest
	var guest := $AutumnExhibit/Guests.get_node_or_null(NodePath(speaker)) as Node2D
	if guest and guest.is_visible_in_tree():
		return guest
	return $SpringGathering/Guests.get_node_or_null(NodePath(speaker)) as Node2D

func _refresh_field_keeper_visit() -> void:
	var visiting := Global.field_keeper_visiting()
	if is_instance_valid(field_guest):
		if not visiting:
			field_guest.queue_free()
			field_guest = null
		return
	if visiting:
		var data := VisitorData.new()
		data.name = VisitorData.FIELD_KEEPER
		data.meeting_place = "井田西南"
		field_guest = visitor_scene.instantiate()
		field_guest.name = "FieldKeeperVisit"
		field_guest.data = data
		field_guest.position = Vector2(-13, 214)
		add_child(field_guest)

func _refresh_visitor(walk_in := false) -> void:
	for visitor in active_visitors:
		visitor.queue_free()
	active_visitors.clear()
	var names: Array[String] = []
	for retainer in Global.retainers:
		names.append(retainer.name)
	scheduled_visitor = Global.visitor_for_day(Global.current_day)
	_place_scheduled_visitor(walk_in)
	_refresh_handoff_visitor(walk_in)
	$SpringGathering.refresh(scheduled_visitor, names)
	_report_visitor_activity()

func _refresh_handoff_visitor(walk_in := false) -> void:
	var guide := handoff_visitor()
	var scheduled_guide := scheduled_visitor != null and scheduled_visitor.name == VisitorData.RAVINE_GUIDE
	if scheduled_guide or not Global.ravine_handoff_visit_today():
		if guide:
			_remove_visitor(guide)
		return
	if not guide:
		var data := VisitorData.from_persona(VisitorData.RAVINE_PERSONA)
		data.handoff_visit = true
		guide = _add_visitor(data, VisitorData.BAMBOO_PATH)
	_apply_visitor_activity(guide, walk_in)

func _add_visitor(data: VisitorData, foot: Vector2) -> Visitor:
	var visitor := visitor_scene.instantiate() as Visitor
	visitor.data = data
	visitor.position = foot
	add_child(visitor)
	active_visitors.append(visitor)
	visitor.activity_reached.connect(_visitor_arrived.bind(visitor))
	return visitor

func _place_scheduled_visitor(walk_in: bool) -> void:
	if not scheduled_visitor:
		return
	var trip := scheduled_visitor.silk_trip()
	if trip in [VisitorData.SilkTrip.STALL, VisitorData.SilkTrip.RETURN_ROAD]:
		return
	var foot: Vector2 = ($WestMarketArrival.position if trip == VisitorData.SilkTrip.PAVILION
		else scheduled_visitor.meeting_point(get_crop_world_pos(Global.irrigation.source_cell)))
	var visitor := _add_visitor(scheduled_visitor, foot)
	if trip == VisitorData.SilkTrip.PAVILION:
		_apply_pavilion_visit(visitor, false)
	else:
		_apply_visitor_activity(visitor, walk_in and trip == VisitorData.SilkTrip.NONE)
		if trip == VisitorData.SilkTrip.WEST_ROAD:
			_send_visitor_to_market(visitor)
		else:
			_apply_pavilion_visit(visitor, walk_in)

func _send_visitor_to_market(visitor: Visitor) -> void:
	var gate: Vector2 = $WestMarketGate.position
	var path := _follow_lane(EstateLayout.WEST_COURT_PATH, visitor.position, EstateLayout.WEST_COURT_TURN)
	path.append_array(_follow_lane(EstateLayout.WEST_LANE, EstateLayout.WEST_COURT_TURN, EstateLayout.WEST_FORK).slice(1))
	path.append_array(_follow_lane(LANDSCAPE.ESTATE_TRACKS[0], EstateLayout.WEST_FORK, gate).slice(1))
	visitor.go_to_activity(VisitorData.VisitActivity.TO_SILK_MARKET, path, gate + Vector2.LEFT,
		true, VisitorData.seconds_since(VisitorData.SILK_MARKET_DEPART))
	if not visitor.walking_to_stop:
		_remove_visitor(visitor)

func _remove_visitor(visitor: Visitor) -> void:
	active_visitors.erase(visitor)
	visitor.queue_free()

func _visitor_arrived(visitor: Visitor) -> void:
	if visitor.activity == VisitorData.VisitActivity.TO_SILK_MARKET:
		_remove_visitor(visitor)
	_report_visitor_activity()

func _report_visitor_activity() -> void:
	visitor_changed.emit(current_visitor())

func _update_visitor_activity() -> void:
	_refresh_handoff_visitor(true)
	for visitor in active_visitors:
		if visitor.activity in [VisitorData.VisitActivity.PAVILION_REST, VisitorData.VisitActivity.TO_SILK_MARKET]:
			continue
		if not _apply_pavilion_visit(visitor, true):
			_apply_visitor_activity(visitor, true)
	_report_visitor_activity()

func _update_visitor_clock() -> void:
	if not scheduled_visitor:
		return
	var visitor := _scheduled_visitor_actor()
	match scheduled_visitor.silk_trip():
		VisitorData.SilkTrip.WEST_ROAD:
			if visitor and visitor.activity != VisitorData.VisitActivity.TO_SILK_MARKET:
				_send_visitor_to_market(visitor)
				_report_visitor_activity()
		VisitorData.SilkTrip.STALL, VisitorData.SilkTrip.RETURN_ROAD:
			if visitor:
				_remove_visitor(visitor)
			_report_visitor_activity()
		VisitorData.SilkTrip.PAVILION:
			if visitor and visitor.activity == VisitorData.VisitActivity.PAVILION_REST:
				return
			if visitor:
				_remove_visitor(visitor)
			_place_scheduled_visitor(false)
			_report_visitor_activity()
		_:
			if visitor and _apply_pavilion_visit(visitor, true):
				_report_visitor_activity()

func _apply_pavilion_visit(visitor: Visitor, walk_in: bool) -> bool:
	var from_market := visitor.data.silk_trip() == VisitorData.SilkTrip.PAVILION
	if (visitor.activity == VisitorData.VisitActivity.PAVILION_REST or (not from_market and not visitor.data.has_pavilion_rest())
		or VisitorData.pavilion_rest_seconds() < 0.0 or Global.outcome != Global.Outcome.RUNNING):
		return false
	var path := _path_to_pavilion(visitor)
	var elapsed := 0.0 if walk_in else VisitorData.pavilion_rest_seconds()
	visitor.go_to_activity(VisitorData.VisitActivity.PAVILION_REST, path, LANDSCAPE.PAVILION_WATER,
		Global.day_progress < 1.0, elapsed)
	return true

func _path_to_pavilion(visitor: Visitor) -> PackedVector2Array:
	var start := visitor.position
	var path := PackedVector2Array()
	if visitor.data.silk_trip() == VisitorData.SilkTrip.PAVILION:
		path = _follow_lane(LANDSCAPE.ESTATE_TRACKS[0], start, LANDSCAPE.ESTATE_SOUTH_LANE[0])
	elif visitor.data.name == VisitorData.EAST_WATCHER:
		path = _follow_lane(LANDSCAPE.ESTATE_EAST_LANE, start, LANDSCAPE.EAST_LANE_JUNCTION)
	elif visitor.activity == VisitorData.VisitActivity.ROAD_REST and start.x < LANDSCAPE.ROAD_REST_TRACK[0].x:
		path = _follow_lane(LANDSCAPE.ROAD_REST_TRACK, start, LANDSCAPE.ROAD_REST_TRACK[0])
	elif visitor.activity == VisitorData.VisitActivity.HERBS and start.x > LANDSCAPE.GARDEN_TRACK[1].x:
		path = _follow_lane(LANDSCAPE.GARDEN_TRACK, start, LANDSCAPE.GARDEN_TRACK[0])
	if not path.is_empty():
		start = path[-1]
	path.append_array(_follow_lane(LANDSCAPE.ESTATE_SOUTH_LANE, start, LANDSCAPE.PAVILION_TURN))
	path.append_array(PackedVector2Array([EstateLayout.SOUTH_PAVILION + Vector2(-14, 3), LANDSCAPE.PAVILION_REST_FOOT]))
	return path

func _follow_lane(lane: Array, from: Vector2, destination: Vector2) -> PackedVector2Array:
	var closest := Vector2.ZERO
	var best := INF
	var segment := 0
	for index in range(lane.size() - 1):
		var point := Geometry2D.get_closest_point_to_segment(from, lane[index], lane[index + 1])
		var distance := from.distance_squared_to(point)
		if distance < best:
			closest = point
			best = distance
			segment = index
	var end := lane.find(destination)
	var path := PackedVector2Array([closest])
	if end <= segment:
		for index in range(segment, end - 1, -1):
			path.append(lane[index])
	else:
		for index in range(segment + 1, end + 1):
			path.append(lane[index])
	return path

func _apply_visitor_activity(visitor: Visitor, walk_in: bool) -> bool:
	var work := VisitorData.activity_on(visitor.data.name, Global.current_day)
	if work == VisitorData.VisitActivity.NONE or work == visitor.activity:
		return false
	var path := PackedVector2Array()
	var focus := Vector2.ZERO
	match work:
		VisitorData.VisitActivity.ROAD_REST:
			focus = $RoadRest.position
			path = _follow_lane(LANDSCAPE.ESTATE_SOUTH_LANE, visitor.position, EstateLayout.PAVILION_JUNCTION)
			path.append_array(PackedVector2Array(LANDSCAPE.ROAD_REST_TRACK.slice(1)))
			path.append(focus + Vector2(20, 11))
		VisitorData.VisitActivity.MEASURE:
			focus = get_crop_world_pos(Global.irrigation.source_cell)
			path.append(focus + Vector2(24, 20))
			path.append(focus + Vector2(18, -17))
		VisitorData.VisitActivity.SILK:
			focus = LANDSCAPE.SILK_SAMPLE_BOUNDS.get_center()
			path.append(focus + Vector2(10, 20))
		VisitorData.VisitActivity.HERBS:
			focus = $HerbGarden.position
			path = _follow_lane(LANDSCAPE.ESTATE_SOUTH_LANE, visitor.position, LANDSCAPE.GARDEN_TRACK[0])
			path.append_array(PackedVector2Array(LANDSCAPE.GARDEN_TRACK.slice(1)))
			path.append(focus + Vector2(-14, 24))
		VisitorData.VisitActivity.WATCH:
			focus = $Scenery/EastWatch.position
			path = PackedVector2Array([EstateLayout.EAST_LANE[-2], focus + Vector2(-18, 13)])
	visitor.go_to_activity(work, path, focus, walk_in)
	return true
