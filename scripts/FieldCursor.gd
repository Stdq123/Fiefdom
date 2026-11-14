extends Node2D

const HUD_THEME := preload("res://resources/estate_hud_theme.tres")

@onready var tile_map: TileMapLayer = get_parent()
@onready var world = tile_map.get_parent()

@onready var caption := PanelContainer.new()
@onready var label := Label.new()
var pointer := Vector2.ZERO
var pointer_seen := false
var ink := Color("#edce88")
var preview_plots: Array[Vector2i] = []
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
	label.add_theme_font_size_override("font_size", 15)
	label.use_parent_material = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_child(label)
	get_window().mouse_exited.connect(_clear_pointer)
	get_viewport().size_changed.connect(_clear_pointer)

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
	if bulk_input and world.sweep_action == world.FieldAction.NONE:
		var plots: Array[Vector2i] = world.field_batch_targets(cell, action)
		if not plots.is_empty():
			_show_field_preview(cell, action, plots)
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
	if actionable and world.sweep_action == world.FieldAction.NONE and world.field_batch_targets(cell, action).size() > 1:
		var modifier := "LT" if GamepadInput.active else Preferences.key_label(KeyBindings.FILL)
		text += "\n按住 %s 预览整田%s" % [modifier, world.FIELD_WORK_LABELS[action]]
	_place_caption(cell, text, tone)

func _show_field_preview(cell: Vector2i, action: int, plots: Array[Vector2i]) -> void:
	var public_plots := 0
	for plot in plots:
		public_plots += int(Global.is_public_plot(plot))
	var cost: int = plots.size() * world.field_cost(action)
	var can_afford := cost <= Global.current_stamina
	var title: String = world.FIELD_WORK_LABELS[action]
	if action == world.FieldAction.SOW:
		title += ItemManager.crop_label(world.current_seed_id)
	var work := "整田%s · 公田 %d · 私田 %d" % [title, public_plots, plots.size() - public_plots]
	var accept := "A 确认" if GamepadInput.active else "左键确认"
	var cost_line := ("%d 体力 · %s" % [cost, accept] if can_afford
		else "需 %d 体力 · 还差 %d" % [cost, cost - Global.current_stamina])
	_place_caption(cell, work + "\n" + cost_line, Color("#eacb80") if can_afford else Color("#efaa84"), plots)

func _place_caption(cell: Vector2i, text: String, tone: Color, plots: Array[Vector2i] = []) -> void:
	var at_cell := tile_map.map_to_local(cell)
	if tone != ink or preview_plots != plots or (not plots.is_empty() and position != at_cell):
		ink = tone
		preview_plots = plots
		queue_redraw()
	if text != label.text:
		label.text = text
		caption.size = caption.get_combined_minimum_size()
	label.modulate = ink
	position = at_cell
	var bounds := get_viewport().get_visible_rect().grow(-8.0)
	var transform := tile_map.get_global_transform_with_canvas()
	var scale_in_view := transform.get_scale()
	var margin := Vector2(tile_map.tile_set.tile_size) * scale_in_view * 0.5 + Vector2(4, 4)
	var at := transform * position
	var centered := (at - caption.size * 0.5).clamp(bounds.position, bounds.end - caption.size)
	var area := Rect2(at, Vector2.ZERO)
	for plot in plots:
		area = area.expand(transform * tile_map.map_to_local(plot))
	var above := Vector2(centered.x, area.position.y - margin.y - caption.size.y)
	var below := Vector2(centered.x, area.end.y + margin.y)
	var has_worker: bool = world.retainer_instances.values().any(func(worker: Retainer) -> bool:
		return worker.current_state == Retainer.State.WORK and worker.target_grid_pos == cell
	)
	caption.scale = Vector2.ONE / scale_in_view
	show()
	for placement: Vector2 in [below if has_worker else above, above if has_worker else below,
			Vector2(area.end.x + margin.x, centered.y), Vector2(area.position.x - margin.x - caption.size.x, centered.y)]:
		var screen_position := placement.round()
		var rect := Rect2(screen_position, caption.size)
		if (plots.is_empty() or bounds.encloses(rect)) and hud.map_space_clear(rect):
			caption.position = transform.affine_inverse() * screen_position - position
			caption.show()
			return
	caption.hide()

func _draw() -> void:
	var half_cell := Vector2(tile_map.tile_set.tile_size) / 2 - Vector2.ONE
	if not preview_plots.is_empty():
		for plot in preview_plots:
			var local_center := tile_map.map_to_local(plot) - position
			var box := Rect2(local_center - half_cell, half_cell * 2)
			draw_rect(box, Color(ink, 0.15))
			draw_rect(box, ink, false, 1.15)
		return
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var tip: Vector2 = half_cell * corner
		var stroke := PackedVector2Array([tip - Vector2(4 * corner.x, 0), tip, tip - Vector2(0, 4 * corner.y)])
		draw_polyline(stroke, Color("#382519"), 2.6)
		draw_polyline(stroke, ink, 1.1)
