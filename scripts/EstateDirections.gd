extends Control

enum Mark { PLOT, BUTTON, NEIGHBOR, EDGE, WORKSITE, PLACE }

const CAMPAIGN_GUIDE := preload("res://scripts/CampaignGuide.gd")
const ROAD_NETWORK := preload("res://scripts/RoadNetwork.gd")
const GOLD := Color("#f1d38b")
const SHADOW := Color("#24352b")
const FIELD_ROUTES := {
	Global.NightGrowth.READY: {"task": "收获", "plot": "可收"},
	Global.NightGrowth.DRY: {"task": "浇水", "plot": "待浇"},
	Global.NightGrowth.BLOCKED: {"task": "断水", "plot": "断水"},
	Global.MulberryRoute.PLANT: {"task": "种桑"},
	Global.MulberryRoute.WATER: {"task": "浇桑", "plot": "待浇"},
	Global.MulberryRoute.HARVEST: {"task": "采桑叶", "plot": "可收"},
	Global.TributeRoute.TEND: {"task": "照料公田"},
	Global.OrderFieldRoute.HARVEST: {"task": "收交货作物", "plot": "备货"},
}

var world: Node2D
var hud: Control
var tracked_neighbor := ""
var tracked_plot: Variant = null
var tracked_site := -1
var tracked_place := ""
var tracked_place_point := Vector2.ZERO
var following_raid := false
var caption: Label
var plate := StyleBoxFlat.new()
var mark := Mark.PLOT
var outline := Rect2()
var plaque := Rect2()
var edge_direction := Vector2.ZERO
var road_network: ROAD_NETWORK
var road_guide := Node2D.new()
var road_path := PackedVector2Array()
var road_origin := Vector2.INF
var road_target := Vector2.INF

func setup(estate_world: Node2D, estate_hud: Control) -> void:
	world = estate_world
	hud = estate_hud
	hud.cancel_directions.pressed.connect(clear_tracking)
	_refresh_road_network()
	GameEvents.seed_garden_arrived.connect(_refresh_road_network)
	GameEvents.pond_landing_opened.connect(_refresh_road_network)
	road_guide.z_index = -2
	road_guide.hide()
	world.add_child(road_guide)
	road_guide.draw.connect(_draw_road_guide)

	plate.bg_color = Color("#203126f7")
	plate.border_color = Color("#b8a26d")
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(3)
	caption = Label.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", GOLD)
	add_child(caption)
	hide()

func _refresh_road_network() -> void:
	var tracks := [EstateLayout.ROADS[0], EstateLayout.SOUTH_LANE, EstateLayout.EAST_LANE] \
		+ EstateLayout.WEST_ROADS + EstateLayout.SOUTH_ROADS + EstateLayout.DRIVING_ROADS
	if Global.seed_garden_day() > 0:
		tracks.append(EstateLayout.SEED_GARDEN_TRACK)
	if Global.pond_landing_day() > 0:
		tracks.append(EstateLayout.POND_TRACK)
	road_network = ROAD_NETWORK.new(tracks, world, world.player)
	road_target = Vector2.INF

func follow_neighbor(speaker: String) -> bool:
	if not is_instance_valid(world.neighbor_actor(speaker)) and _neighbor_trip_stop(speaker).is_empty():
		return false
	clear_tracking()
	tracked_neighbor = speaker
	if speaker == VisitorData.SILK_MERCHANT:
		Global.market_trip_target = speaker
	hud.cancel_directions.text = "%s · 取消指路" % speaker
	hud.cancel_directions.show()
	return true

func follow_field_route(status: int, public_only := false) -> bool:
	var cell: Variant = world.find_field_task(status, public_only)
	if cell == null:
		return false
	clear_tracking()
	Global.field_route_status = status
	Global.field_route_public_only = public_only
	_track_field_plot(cell)
	return true

func _track_field_plot(cell: Vector2i) -> void:
	tracked_plot = cell
	var task: String = FIELD_ROUTES[Global.field_route_status].task
	hud.cancel_directions.text = task + ("公田" if Global.field_route_public_only else "") + " · 取消指路"
	hud.cancel_directions.show()

func _refresh_field_route() -> void:
	var status := Global.field_route_status
	if status < 0:
		if tracked_plot != null:
			clear_tracking()
		return
	if tracked_plot != null:
		if world.matches_field_route(tracked_plot, status):
			return
		if status == Global.MulberryRoute.PLANT and Global.active_crops.get(tracked_plot, {}).get("id") == "mulberry":
			clear_tracking()
			return
	var next: Variant = world.find_field_task(status, Global.field_route_public_only)
	if next == null:
		clear_tracking()
	else:
		if tracked_plot != null:
			world.tile_map.get_node("FieldCursor").clear_plot_hover(tracked_plot)
		_track_field_plot(next)

func follow_worksite(field_id: int) -> void:
	clear_tracking()
	tracked_site = field_id
	hud.cancel_directions.text = "井田 %d 工地 · 取消指路" % (field_id + 1)
	hud.cancel_directions.show()

func follow_place(title: String, point: Vector2) -> void:
	clear_tracking()
	tracked_place = title
	tracked_place_point = point
	hud.cancel_directions.text = title + " · 取消指路"
	hud.cancel_directions.show()

func follow_ravine(place: String) -> void:
	follow_place("竹涧 · " + place, ravine_gate_point(place))
	Global.ravine_trip_target = place

func follow_water_source() -> void:
	follow_place(Global.WATER_SOURCE, _cell_position(Global.irrigation.source_cell))
	Global.market_trip_target = Global.WATER_SOURCE

func ravine_gate_point(place: String) -> Vector2:
	var south: bool = (Global.ravine_shortcut_open() and world.estate_player_point().y >= EstateLayout.BAMBOO_BEND.y
		and place in [CreekFish.PLACES[CreekFish.Site.SHOAL], CreekTrap.PLACES[CreekFish.Site.SHOAL]])
	var gate := world.get_node("RavineTrailGate" if south else "EastGate") as Node2D
	return world.to_local(gate.global_position)

func follow_market(place: String) -> void:
	var gate := world.get_node("WestMarketGate") as Node2D
	follow_place(place if place == Sheepfold.MEADOW else "西市 · " + place, world.to_local(gate.global_position))
	Global.market_trip_target = place

func follow_raid() -> void:
	clear_tracking()
	following_raid = true
	hud.cancel_directions.text = "来敌 · 取消指路"
	hud.cancel_directions.show()

func destination() -> Dictionary:
	var raider := _tracked_raider()
	if raider:
		return {"title": Global.raid_name(Global.raid_kind), "point": world.to_local(raider.global_position)}
	var site := Global.get_well_field(tracked_site)
	if not site.is_empty() and not site["is_unlocked"]:
		return {"title": "井田 %d 工地" % (tracked_site + 1), "point": _cell_position(site["center_pos"])}
	if tracked_plot != null and Global.field_route_status >= 0 and world.matches_field_route(tracked_plot, Global.field_route_status):
		return {"title": _field_plot_label(tracked_plot), "point": _cell_position(tracked_plot)}
	if not tracked_neighbor.is_empty():
		var actor: Node2D = world.neighbor_actor(tracked_neighbor)
		if is_instance_valid(actor):
			return {"title": tracked_neighbor, "point": world.to_local(actor.global_position)}
		return _neighbor_trip_stop(tracked_neighbor)
	if not tracked_place.is_empty():
		return {"title": tracked_place, "point": tracked_place_point}
	return {}

func _neighbor_trip_stop(speaker: String) -> Dictionary:
	return world.silk_trip_stop() if speaker == VisitorData.SILK_MERCHANT else {}

func _tracked_raider() -> Node2D:
	if following_raid and Global.raid_day > 0:
		return get_tree().get_first_node_in_group("estate_raiders") as Node2D
	return null

func _cell_position(cell: Vector2i) -> Vector2:
	var tiles: TileMapLayer = world.tile_map
	return world.to_local(tiles.to_global(tiles.map_to_local(cell)))

func _field_plot_label(cell: Vector2i) -> String:
	if Global.field_route_status == Global.TributeRoute.TEND:
		return "公田 · " + world.field_message(cell, world.field_action(cell))
	if Global.field_route_status == Global.MulberryRoute.PLANT:
		if not Global.tilled_cells.has(cell):
			return "私田 · 翻地种桑"
		return "私田 · 播桑" if world.current_seed_id == "mulberry" else "私田 · 换桑种"
	var land := "公田" if Global.is_public_plot(cell) else "私田"
	var crop: CropData = Global.active_crops[cell].data
	return "%s · %s%s" % [crop.crop_name, FIELD_ROUTES[Global.field_route_status].plot, land]

func arrive_at(speaker: String) -> void:
	if tracked_neighbor == speaker:
		clear_tracking()

func clear_tracking() -> void:
	tracked_neighbor = ""
	tracked_plot = null
	Global.field_route_status = -1
	Global.field_route_public_only = false
	tracked_site = -1
	tracked_place = ""
	Global.ravine_trip_target = ""
	Global.market_trip_target = ""
	following_raid = false
	road_guide.hide()
	road_target = Vector2.INF
	hud.cancel_directions.hide()

func update_marker(blocked: bool) -> void:
	if not MapTravel.active and Global.outcome == Global.Outcome.RUNNING:
		_refresh_field_route()
	if blocked or Global.outcome != Global.Outcome.RUNNING:
		road_guide.hide()
		hide()
		return
	caption.hide()
	if following_raid:
		var raider := _tracked_raider()
		if raider:
			var bounds := raider.get_global_transform_with_canvas() * Rect2(-12, -16, 24, 21)
			var shot := "RT 射箭" if GamepadInput.active else "右键射箭"
			_mark_map(bounds, Global.raid_name(Global.raid_kind) + " · " + shot, Mark.NEIGHBOR, false)
			return
		clear_tracking()
	if tracked_site >= 0:
		var field := Global.get_well_field(tracked_site)
		if not field.is_empty() and not field["is_unlocked"]:
			_mark_worksite(field["center_pos"])
			return
		clear_tracking()
	if tracked_plot != null:
		_mark_plot(tracked_plot, _field_plot_label(tracked_plot))
		return
	if not tracked_neighbor.is_empty():
		var actor: Node2D = world.neighbor_actor(tracked_neighbor)
		if is_instance_valid(actor):
			var near: bool = world.player.interaction_target == actor
			if near:
				road_guide.hide()
			else:
				_show_road_route(world.to_local(actor.global_position))
			var portrait := actor.get_global_transform_with_canvas() * Rect2(-10, -23, 20, 25)
			_mark_map(portrait, tracked_neighbor, Mark.NEIGHBOR, near)
			return
		var stop := _neighbor_trip_stop(tracked_neighbor)
		if not stop.is_empty():
			_mark_place(stop.title, stop.point)
			return
		clear_tracking()
	if not tracked_place.is_empty():
		var foot := world.to_local(world.player.global_position)
		if foot.distance_to(tracked_place_point) > 12.0:
			_mark_place(tracked_place, tracked_place_point)
			return
		if not Global.ravine_trip_target.is_empty() or not Global.market_trip_target.is_empty():
			hide()
			return
		clear_tracking()
	var guide := hud.guide as CAMPAIGN_GUIDE
	match guide.opening_cue:
		CAMPAIGN_GUIDE.OpeningCue.PLOT:
			_mark_plot(guide.opening_cell, guide.opening_plot_name)
		CAMPAIGN_GUIDE.OpeningCue.SLEEP:
			_mark_button(hud.sleep_button)
		CAMPAIGN_GUIDE.OpeningCue.SEED:
			_mark_button(hud.seed_buttons[guide.opening_seed_id])
		_:
			hide()

func _mark_place(title: String, point: Vector2) -> void:
	_show_road_route(point)
	var at := world.get_global_transform_with_canvas() * point
	_mark_map(Rect2(at - Vector2(8, 8), Vector2(16, 16)), title, Mark.PLACE, false)

func _show_road_route(point: Vector2) -> void:
	var foot := world.to_local(world.player.global_position)
	if foot.distance_to(road_origin) > 10.0 or point.distance_to(road_target) > 6.0:
		road_path = road_route_between(foot, point)
		road_origin = foot
		road_target = point
		road_guide.queue_redraw()
	road_guide.visible = road_path.size() > 1

func road_route_between(foot: Vector2, point: Vector2) -> PackedVector2Array:
	if (point.y >= EstateLayout.FIELD_LANE_TURN.y or point.x <= EstateLayout.WEST_FORK.x
		or point.x >= EstateLayout.EAST_WATCH.x):
		return road_network.route_between(foot, point)
	return PackedVector2Array()

func _draw_road_guide() -> void:
	for index in range(1, road_path.size()):
		road_guide.draw_dashed_line(road_path[index - 1], road_path[index], SHADOW, 3.2, 6.0)
		road_guide.draw_dashed_line(road_path[index - 1], road_path[index], GOLD, 1.6, 6.0)

func _mark_plot(cell: Vector2i, title: String) -> void:
	var tiles: TileMapLayer = world.tile_map
	var center := tiles.map_to_local(cell)
	var extent := Vector2(tiles.tile_set.tile_size)
	var plot := tiles.get_global_transform_with_canvas() * Rect2(center - extent / 2.0, extent)
	var hover := tiles.get_node("FieldCursor") as Node2D
	_mark_map(plot, title, Mark.PLOT, hover.visible and hover.position == center)

func _mark_worksite(cell: Vector2i) -> void:
	var tiles: TileMapLayer = world.tile_map
	var center := tiles.map_to_local(cell)
	var extent := Vector2(tiles.tile_set.tile_size) * 3.0
	var footprint := tiles.get_global_transform_with_canvas() * Rect2(center - extent / 2.0, extent)
	_mark_map(footprint, "井田 %d 工地" % (tracked_site + 1), Mark.WORKSITE, false)

func _mark_button(button: Button) -> void:
	mark = Mark.BUTTON
	outline = button.get_global_rect().grow(2.0)
	show()
	queue_redraw()

func _mark_map(bounds: Rect2, label_text: String, style: Mark, near: bool) -> void:
	caption.text = label_text
	var text_size := caption.get_combined_minimum_size()
	caption.size = text_size
	if hud.map_space_clear(bounds):
		mark = style
		outline = bounds.grow(1.0) if style in [Mark.PLOT, Mark.WORKSITE] else bounds
		if not near:
			var badge_size := text_size + Vector2(16, 6)
			var clearance := bounds.size.y + 6.0 if style == Mark.PLOT else 7.0
			plaque = Rect2(Vector2(bounds.get_center().x - badge_size.x / 2.0, bounds.end.y + clearance), badge_size)
			if hud.map_space_clear(plaque):
				caption.position = plaque.position + Vector2(8, 3)
				caption.show()
	else:
		mark = Mark.EDGE
		var badge_size := text_size + Vector2(32, 9)
		var safe := get_viewport_rect().grow(-17.0)
		edge_direction = safe.get_center().direction_to(bounds.get_center())
		var half := ((safe.size - badge_size) * 0.5).max(Vector2.ONE)
		var distance := minf(half.x / maxf(0.001, absf(edge_direction.x)),
			half.y / maxf(0.001, absf(edge_direction.y)))
		while true:
			plaque = Rect2((safe.get_center() + edge_direction * distance - badge_size / 2.0).round(), badge_size)
			if hud.map_space_clear(plaque):
				break
			if distance <= 0.0:
				hide()
				return
			distance = maxf(0.0, distance - 8.0)
		caption.position = plaque.position + Vector2(24, 4)
		caption.show()
	show()
	queue_redraw()

func _draw() -> void:
	if caption and caption.visible:
		draw_style_box(plate, plaque)
	match mark:
		Mark.PLOT, Mark.BUTTON, Mark.WORKSITE:
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var point: Vector2 = outline.get_center() + outline.size * 0.5 * corner
				var line := PackedVector2Array([point - Vector2(8 * corner.x, 0), point, point - Vector2(0, 8 * corner.y)])
				draw_polyline(line, SHADOW, 4.0)
				draw_polyline(line, GOLD, 1.8)
		Mark.NEIGHBOR, Mark.PLACE:
			var at := outline.get_center()
			if mark == Mark.NEIGHBOR:
				at.y = outline.end.y + 2
			var stone := PackedVector2Array([at + Vector2(0, -5), at + Vector2(6, 0),
				at + Vector2(0, 5), at + Vector2(-6, 0)])
			if mark == Mark.PLACE:
				draw_circle(at, 8.0, SHADOW)
			draw_colored_polygon(stone, GOLD)
		Mark.EDGE:
			var at := plaque.position + Vector2(12, plaque.size.y / 2.0)
			var axis := edge_direction * 6.0
			var wing := axis.orthogonal() * 0.75
			draw_colored_polygon(PackedVector2Array([at + axis, at - axis + wing, at - axis - wing]), GOLD)
