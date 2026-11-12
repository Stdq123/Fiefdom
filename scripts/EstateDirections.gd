extends Control

enum Mark { PLOT, BUTTON, NEIGHBOR, EDGE, WORKSITE, PLACE }

const CAMPAIGN_GUIDE := preload("res://scripts/CampaignGuide.gd")
const GOLD := Color("#f1d38b")
const SHADOW := Color("#24352b")

var world: Node2D
var hud: Control
var tracked_neighbor := ""
var tracked_plot: Variant = null
var tracked_site := -1
var tracked_place := ""
var tracked_place_point := Vector2.ZERO
var following_raid := false
var awaiting_tribute := false
var covers: Array[Control] = []
var caption: Label
var plate := StyleBoxFlat.new()
var mark := Mark.PLOT
var outline := Rect2()
var plaque := Rect2()
var edge_direction := Vector2.ZERO

func setup(estate_world: Node2D, estate_hud: Control) -> void:
	world = estate_world
	hud = estate_hud
	for panel_name in ["Journal", "Calendar", "SeedBelt", "Vitals", "Tools", "Actions", "RationsButton"]:
		covers.append(hud.get_node(panel_name) as Control)
	awaiting_tribute = not Global.first_tribute_delivered()
	GameEvents.crop_harvested.connect(_on_harvested)
	hud.cancel_directions.pressed.connect(clear_tracking)

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

func follow_neighbor(speaker: String) -> bool:
	if not is_instance_valid(world.neighbor_actor(speaker)):
		return false
	clear_tracking()
	tracked_neighbor = speaker
	hud.cancel_directions.text = "%s · 取消指路" % speaker
	hud.cancel_directions.show()
	return true

func follow_dry_plot(cell: Vector2i) -> void:
	clear_tracking()
	tracked_plot = cell
	hud.cancel_directions.text = _dry_plot_label(cell) + " · 取消指路"
	hud.cancel_directions.show()

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
	var gate := world.get_node("EastGate") as Node2D
	follow_place("竹涧 · " + place, world.to_local(gate.global_position))
	Global.ravine_trip_target = place

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
	if tracked_plot != null and world.is_crop_dry(tracked_plot):
		return {"title": _dry_plot_label(tracked_plot), "point": _cell_position(tracked_plot)}
	if not tracked_neighbor.is_empty():
		var actor: Node2D = world.neighbor_actor(tracked_neighbor)
		if is_instance_valid(actor):
			return {"title": tracked_neighbor, "point": world.to_local(actor.global_position)}
	if not tracked_place.is_empty():
		return {"title": tracked_place, "point": tracked_place_point}
	return {}

func _tracked_raider() -> Node2D:
	if following_raid and Global.raid_day > 0:
		return get_tree().get_first_node_in_group("estate_raiders") as Node2D
	return null

func _cell_position(cell: Vector2i) -> Vector2:
	var tiles: TileMapLayer = world.tile_map
	return world.to_local(tiles.to_global(tiles.map_to_local(cell)))

func _dry_plot_label(cell: Vector2i) -> String:
	return "待浇公田" if Global.is_public_plot(cell) else "待浇私田"

func arrive_at(speaker: String) -> void:
	if tracked_neighbor == speaker:
		clear_tracking()

func clear_tracking() -> void:
	tracked_neighbor = ""
	tracked_plot = null
	tracked_site = -1
	tracked_place = ""
	Global.ravine_trip_target = ""
	following_raid = false
	hud.cancel_directions.hide()

func _on_harvested(is_public: bool) -> void:
	if awaiting_tribute and is_public and Global.first_tribute_delivered():
		awaiting_tribute = false
		if (tracked_neighbor.is_empty() and tracked_plot == null and tracked_site < 0
			and tracked_place.is_empty() and not following_raid and Global.rotation_offer_ready()):
			follow_neighbor(VisitorData.FIELD_KEEPER)

func update_marker(blocked: bool) -> void:
	if blocked or Global.outcome != Global.Outcome.RUNNING:
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
		if world.is_crop_dry(tracked_plot):
			_mark_plot(tracked_plot, _dry_plot_label(tracked_plot))
			return
		clear_tracking()
	if not tracked_neighbor.is_empty():
		var actor: Node2D = world.neighbor_actor(tracked_neighbor)
		if is_instance_valid(actor):
			var portrait := actor.get_global_transform_with_canvas() * Rect2(-10, -23, 20, 25)
			_mark_map(portrait, tracked_neighbor, Mark.NEIGHBOR, world.player.interaction_target == actor)
			return
		clear_tracking()
	if not tracked_place.is_empty():
		var foot := world.to_local(world.player.global_position)
		if foot.distance_to(tracked_place_point) > 12.0:
			var at := world.get_global_transform_with_canvas() * tracked_place_point
			_mark_map(Rect2(at - Vector2(8, 8), Vector2(16, 16)), tracked_place, Mark.PLACE, false)
			return
		if not Global.ravine_trip_target.is_empty():
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
	if _clear_map_space(bounds):
		mark = style
		outline = bounds.grow(1.0) if style in [Mark.PLOT, Mark.WORKSITE] else bounds
		if not near:
			var badge_size := text_size + Vector2(16, 6)
			var clearance := bounds.size.y + 6.0 if style == Mark.PLOT else 7.0
			plaque = Rect2(Vector2(bounds.get_center().x - badge_size.x / 2.0, bounds.end.y + clearance), badge_size)
			if _clear_map_space(plaque):
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
			if _clear_map_space(plaque):
				break
			if distance <= 0.0:
				hide()
				return
			distance = maxf(0.0, distance - 8.0)
		caption.position = plaque.position + Vector2(24, 4)
		caption.show()
	show()
	queue_redraw()

func _clear_map_space(box: Rect2) -> bool:
	if not get_viewport_rect().grow(-8).encloses(box):
		return false
	for cover in covers:
		if cover.is_visible_in_tree() and cover.get_global_rect().grow(4).intersects(box):
			return false
	return true

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
