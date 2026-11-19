extends Node2D

const HUD_THEME := preload("res://resources/estate_hud_theme.tres")
const CURSOR_EDGE := Color("#382519")
const PUBLIC_MARK := Color("#ffdd91")

@onready var tile_map: TileMapLayer = get_parent()
@onready var world = tile_map.get_parent()

@onready var caption := PanelContainer.new()
@onready var label := Label.new()
@onready var batch_icon := TextureRect.new()
var pointer := Vector2.ZERO
var pointer_seen := false
var ink := Color("#edce88")
var preview_plots: Array[Vector2i] = []
var preview_seeds: Dictionary[Vector2i, String] = {}
var hud: Control

func _ready() -> void:
	z_index = 52
	material = preload("res://resources/world_hint_material.tres")
	hide()
	caption.use_parent_material = true
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := HUD_THEME.get_stylebox(&"panel", &"HudRail").duplicate() as StyleBox
	plate.set_content_margin(SIDE_LEFT, 9)
	plate.set_content_margin(SIDE_RIGHT, 9)
	plate.set_content_margin(SIDE_TOP, 5)
	plate.set_content_margin(SIDE_BOTTOM, 6)
	caption.add_theme_stylebox_override("panel", plate)
	add_child(caption)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.use_parent_material = true
	row.add_theme_constant_override("separation", 7)
	caption.add_child(row)
	batch_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	batch_icon.use_parent_material = true
	batch_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	batch_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	batch_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	batch_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	batch_icon.custom_minimum_size = Vector2(18, 22)
	batch_icon.hide()
	row.add_child(batch_icon)
	label.add_theme_font_size_override("font_size", 15)
	label.use_parent_material = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	get_window().mouse_exited.connect(_clear_pointer)
	get_viewport().size_changed.connect(_clear_pointer)
	GameEvents.council_tribute_rows_changed.connect(queue_redraw)
	GameEvents.tax_reform_choice_made.connect(queue_redraw.unbind(1))

func _clear_pointer() -> void:
	pointer_seen = false
	hide()

func clear_plot_hover(cell: Vector2i) -> void:
	if pointer_seen and world.field_at(pointer) == cell:
		_clear_pointer()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		pointer_seen = true
		pointer = event.position

func _process(_delta: float) -> void:
	var viewport := get_viewport()
	var bounds := viewport.get_visible_rect()
	if (not pointer_seen or not bounds.has_point(pointer) or viewport.gui_get_hovered_control() != null
		or world.channel_mode or Global.is_indoors() or world.player.world_controls_blocked() or world.player.training_cart.visible):
		hide()
		return
	var cell: Vector2i = world.field_at(pointer)
	var tile := tile_map.get_cell_tile_data(cell)
	if tile == null:
		var site: Dictionary = world.worksite_at(cell)
		if site.is_empty() or world.sweep_action != world.FieldAction.NONE:
			hide()
			return
		var progress: int = site["reclamation_progress"]
		_place_caption(cell, "井田 %d · %s\n再过 %d 夜可耕种" % [
			site["field_id"] + 1, Global.reclamation_stage(progress), Global.RECLAMATION_NIGHTS - progress],
			Color("#e8c48b"))
		return
	var action: int = world.field_action(cell)
	if world.sweep_action != world.FieldAction.NONE and world.sweep_action != action:
		hide()
		return
	var message: String = world.field_message(cell, action)
	if message.is_empty():
		hide()
		return
	var bulk_input := GamepadInput.filling or Input.is_action_pressed(KeyBindings.FILL)
	var modifier := "LT" if GamepadInput.active else Preferences.key_label(KeyBindings.FILL)
	if bulk_input and world.sweep_action == world.FieldAction.NONE:
		if world.uses_preparation(action):
			var preparation: Dictionary = world.field_preparation(cell)
			if preparation.is_empty():
				_place_caption(cell, "需指向可播的空田\n松开 %s 可单格操作" % modifier, Color("#efaa84"))
			else:
				_show_preparation_preview(cell, preparation)
			return
		var plots: Array[Vector2i] = world.field_batch_targets(cell, action)
		if not plots.is_empty():
			_show_field_preview(cell, action, plots)
			return
		if action == world.FieldAction.HARVEST:
			var scope: Global.FieldScope = world.harvest_batch_scope()
			if not Global.field_scope_matches(cell, scope):
				_place_caption(cell, "批量只收%s\n松开 %s 可单格收割" % [Global.FIELD_SCOPE_NAMES[scope], modifier], Color("#efaa84"))
				return

	var is_public: bool = tile.get_custom_data("is_public_field")
	var cost: int = world.field_cost(action)
	var actionable := cost > 0 and Global.current_stamina >= cost
	var tone := Color("#ecce87") if is_public else Color("#c2d998")
	if not actionable:
		tone = Color("#a7c8bd") if action in [world.FieldAction.CHANNEL, world.FieldAction.RAIN, world.FieldAction.WATERED] else Color("#efaa84")
	var text := ("%s · %s" % ["公田" if is_public else "私田", message])
	if actionable:
		text += "  −%d 体力" % cost
	if world.active_crops.has(cell) and action != world.FieldAction.HARVEST:
		var crop: Dictionary = world.active_crops[cell]
		text += "\n%s · 生长 %d/%d" % [crop["data"].crop_name, crop["age"], crop["growth_nights"]]
	if actionable and world.sweep_action == world.FieldAction.NONE:
		if world.uses_preparation(action):
			if not Global.planned_field_seed(cell, true).is_empty():
				text += "\n按住 %s 预览整备" % modifier
		else:
			var plots: Array[Vector2i] = world.field_batch_targets(cell, action)
			if action == world.FieldAction.HARVEST and not world.harvest_replanting(plots).is_empty():
				text += "\n按住 %s 预览收后续播" % modifier
			elif plots.size() > 1:
				text += "\n按住 %s 预览整田%s" % [modifier, world.FIELD_WORK_LABELS[action]]
	_place_caption(cell, text, tone)

func _show_field_preview(cell: Vector2i, action: int, plots: Array[Vector2i]) -> void:
	var cost: int = plots.size() * world.field_cost(action)
	var title: String = "整田" + world.FIELD_WORK_LABELS[action]
	var seeds: Dictionary[Vector2i, String] = {}
	var details := PackedStringArray()
	var symbol := HUDIcons.Symbol.HOE
	if action == world.FieldAction.SOW:
		symbol = HUDIcons.Symbol.GRAIN if world.sow_from_plan else HUDIcons.CROPS[world.current_seed_id]
		if world.sow_from_plan:
			title = "按安排播种"
			for plot in plots:
				seeds[plot] = world.planting_seed(plot)
			details.append(_seed_varieties(seeds))
		else:
			title += ItemManager.crop_label(world.current_seed_id)
	elif action == world.FieldAction.HARVEST:
		symbol = HUDIcons.Symbol.GRAIN
		var scope: Global.FieldScope = world.harvest_batch_scope()
		if scope != Global.FieldScope.ALL:
			title = "批收" + Global.FIELD_SCOPE_NAMES[scope]
		var totals: Dictionary = world.batch_harvest_totals(plots)
		var harvest_note := Global.field_work_summary(totals, ["tribute", "stock", "copper", "leaves"])
		if totals.levy > 0:
			harvest_note += " · 扣税 %d" % totals.levy
		if not harvest_note.is_empty():
			details.append(harvest_note)
		var replanting: Dictionary = world.harvest_replanting(plots)
		if not replanting.is_empty():
			title = "收后续播"
			seeds = replanting.seeds
			cost = replanting.cost
			details.append("下茬 %s" % _seed_varieties(seeds))
			details.append("续播 %d 格 · 浇水 %d 格" % [seeds.size(), replanting.water])
	elif action == world.FieldAction.WATER:
		symbol = HUDIcons.Symbol.WATER
	_show_batch_caption(cell, title, details, cost, plots, seeds, symbol)

func _show_preparation_preview(cell: Vector2i, preparation: Dictionary) -> void:
	var seeds: Dictionary[Vector2i, String] = preparation.seeds
	var plots: Array[Vector2i] = []
	plots.assign(seeds.keys())
	var details := PackedStringArray([
		_seed_varieties(seeds), "翻地 %d · 播种 %d · 浇水 %d" % [preparation.till, plots.size(), preparation.water],
	])
	_show_batch_caption(cell, "整备空田", details, preparation.cost, plots, seeds)

func _seed_varieties(seeds: Dictionary[Vector2i, String]) -> String:
	var varieties := {}
	for seed: String in seeds.values():
		varieties[seed] = int(varieties.get(seed, 0)) + 1
	return ItemManager.describe_crops(varieties)

func _show_batch_caption(cell: Vector2i, title: String, details: PackedStringArray, cost: int,
		plots: Array[Vector2i], seeds: Dictionary[Vector2i, String], symbol := HUDIcons.Symbol.HOE) -> void:
	var public_plots := 0
	for plot in plots:
		public_plots += int(Global.is_public_plot(plot))
	details.insert(0, "%s · 公田 %d · 私田 %d" % [title, public_plots, plots.size() - public_plots])
	var can_afford := cost <= Global.current_stamina
	var accept := "A 确认" if GamepadInput.active else "左键确认"
	details.append("%d 体力 · %s" % [cost, accept] if can_afford
		else "需 %d 体力 · 还差 %d" % [cost, cost - Global.current_stamina])
	_place_caption(cell, "\n".join(details), Color("#eacb80") if can_afford else Color("#efaa84"), plots, seeds, symbol)

func _place_caption(cell: Vector2i, text: String, tone: Color, plots: Array[Vector2i] = [],
		seeds: Dictionary[Vector2i, String] = {}, symbol := HUDIcons.Symbol.HOE) -> void:
	var at_cell := tile_map.map_to_local(cell)
	if tone != ink or preview_plots != plots or preview_seeds != seeds or (not plots.is_empty() and position != at_cell):
		ink = tone
		preview_plots = plots
		preview_seeds = seeds
		queue_redraw()
	var is_batch := not plots.is_empty()
	if is_batch:
		batch_icon.texture = HUDIcons.icon(symbol)
	if text != label.text or batch_icon.visible != is_batch:
		batch_icon.visible = is_batch
		label.text = text
		caption.size = caption.get_combined_minimum_size()
	label.modulate = ink
	position = at_cell
	var bounds := get_viewport().get_visible_rect().grow(-8.0)
	var transform := tile_map.get_global_transform_with_canvas()
	var scale_in_view := transform.get_scale()
	var margin := Vector2(tile_map.tile_set.tile_size) * scale_in_view * 0.5 + Vector2(4, 4)
	var at := transform * position
	var area := Rect2(at, Vector2.ZERO)
	for plot in plots:
		area = area.expand(transform * tile_map.map_to_local(plot))
	area = Rect2(area.position - margin, area.size + margin * 2.0)
	var occupied: Array[Rect2] = hud.map_obstacles()
	occupied.append(area)
	var player_body: Sprite2D = world.player.sprite
	if player_body.is_visible_in_tree():
		occupied.append((player_body.get_global_transform_with_canvas() * player_body.get_rect()).grow(2.0))
	var has_worker := false
	for worker: Retainer in world.retainer_instances.values():
		if worker.current_state == Retainer.State.WORK and worker.target_grid_pos == cell and worker.sprite.is_visible_in_tree():
			has_worker = true
			var body := worker.sprite
			occupied.append((body.get_global_transform_with_canvas() * body.get_rect()).grow(2.0))
	var screen_position := _fit_caption(at, area, bounds, occupied, has_worker)
	caption.scale = Vector2.ONE / scale_in_view
	show()
	caption.visible = screen_position != Vector2.INF
	if caption.visible:
		caption.position = transform.affine_inverse() * screen_position - position

func _fit_caption(at: Vector2, field: Rect2, bounds: Rect2, occupied: Array[Rect2], below_first: bool) -> Vector2:
	var minimum := bounds.position.ceil()
	var maximum := (bounds.end - caption.size).floor()
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Vector2.INF
	var center := (at - caption.size * 0.5).round().clamp(minimum, maximum)
	var above := Vector2(center.x, floorf(field.position.y - caption.size.y))
	var below := Vector2(center.x, ceilf(field.end.y))
	var right := Vector2(ceilf(field.end.x), center.y)
	var left := Vector2(floorf(field.position.x - caption.size.x), center.y)
	for anchor: Vector2 in [below if below_first else above, above if below_first else below, right, left]:
		if bounds.encloses(Rect2(anchor, caption.size)) and _caption_clear(anchor, occupied):
			return anchor

	# A free rectangle starts at its preferred alignment, the window edge, or a blocker edge.
	var columns := PackedFloat32Array([center.x, minimum.x, maximum.x])
	var rows := PackedFloat32Array([center.y, minimum.y, maximum.y])
	for blocker in occupied:
		columns.append(clampf(floorf(blocker.position.x - caption.size.x), minimum.x, maximum.x))
		columns.append(clampf(ceilf(blocker.end.x), minimum.x, maximum.x))
		rows.append(clampf(floorf(blocker.position.y - caption.size.y), minimum.y, maximum.y))
		rows.append(clampf(ceilf(blocker.end.y), minimum.y, maximum.y))
	var best := Vector2.INF
	var distance := INF
	for y in rows:
		for x in columns:
			var candidate := Vector2(x, y)
			var gap := at.distance_squared_to(candidate + caption.size * 0.5)
			if gap < distance and _caption_clear(candidate, occupied):
				best = candidate
				distance = gap
	return best

func _caption_clear(at: Vector2, occupied: Array[Rect2]) -> bool:
	var rect := Rect2(at, caption.size)
	for blocker in occupied:
		if blocker.intersects(rect):
			return false
	return true

func _draw() -> void:
	var half_cell := Vector2(tile_map.tile_set.tile_size) / 2 - Vector2.ONE
	var focus_ink := ink
	if not preview_plots.is_empty():
		focus_ink = ink.lightened(0.48)
		for plot in preview_plots:
			var local_center := tile_map.map_to_local(plot) - position
			var box := Rect2(local_center - half_cell, half_cell * 2)
			draw_rect(box, Color(ink, 0.11))
			draw_rect(box, CURSOR_EDGE, false, 2.2)
			draw_rect(box, Color(ink, 0.85), false, 0.95)
			if preview_seeds.has(plot):
				var picture := ItemManager.crop_picture(ItemManager.get_crop(preview_seeds[plot]))
				draw_texture_rect(picture.texture, Rect2(local_center - half_cell + Vector2.ONE, (half_cell - Vector2.ONE) * 2), false)
			if Global.is_public_plot(plot):
				var corner := Vector2(box.position.x + 2.5, box.end.y - 2.5)
				var stamp := PackedVector2Array([corner - Vector2(0, 2.5), corner, corner + Vector2(2.5, 0)])
				draw_polyline(stamp, CURSOR_EDGE, 1.8)
				draw_polyline(stamp, PUBLIC_MARK, 1.15)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var tip: Vector2 = half_cell * corner
		var stroke := PackedVector2Array([tip - Vector2(4 * corner.x, 0), tip, tip - Vector2(0, 4 * corner.y)])
		draw_polyline(stroke, CURSOR_EDGE, 2.6)
		draw_polyline(stroke, focus_ink, 1.1)
