extends Node2D

@onready var tile_map: TileMapLayer = get_parent()
@onready var world = tile_map.get_parent()

@onready var caption := PanelContainer.new()
@onready var label := Label.new()
var pointer := Vector2.ZERO
var pointer_seen := false
var ink := Color("#edce88")

func _ready() -> void:
	z_index = 52
	material = preload("res://resources/world_hint_material.tres")
	hide()
	caption.use_parent_material = true
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color("#202c22fa")
	plate.border_color = Color("#a3a577")
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(4)
	plate.content_margin_left = 8
	plate.content_margin_right = 8
	plate.content_margin_top = 3
	plate.content_margin_bottom = 4
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
	if not pointer_seen or not bounds.has_point(pointer) or viewport.gui_get_hovered_control() != null or world.channel_mode or world.player.conversation_open:
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
	_place_caption(cell, text, tone)

func _place_caption(cell: Vector2i, text: String, tone: Color) -> void:
	if tone != ink:
		ink = tone
		queue_redraw()
	if text != label.text:
		label.text = text
		caption.size = caption.get_combined_minimum_size()
	label.modulate = ink
	position = tile_map.map_to_local(cell)
	var bounds := get_viewport().get_visible_rect()
	var transform := tile_map.get_global_transform_with_canvas()
	var scale_in_view := transform.get_scale()
	var half_cell := Vector2(tile_map.tile_set.tile_size) / 2
	var at := transform * position
	var width := caption.size.x
	var height := caption.size.y
	var y := at.y - half_cell.y * scale_in_view.y - height - 4
	var below := at.y + half_cell.y * scale_in_view.y + 4
	var has_worker: bool = world.retainer_instances.values().any(func(worker: Retainer) -> bool:
		return worker.current_state == Retainer.State.WORK and worker.target_grid_pos == cell
	)
	if y < bounds.position.y + 4 or (has_worker and below + height <= bounds.end.y - 4):
		y = below
	var screen_position := Vector2(clampf(at.x - width / 2, bounds.position.x + 4, bounds.end.x - width - 4), y)
	caption.scale = Vector2.ONE / scale_in_view
	caption.position = transform.affine_inverse() * screen_position.round() - position
	show()

func _draw() -> void:
	var half_cell := Vector2(tile_map.tile_set.tile_size) / 2 - Vector2.ONE
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var tip: Vector2 = half_cell * corner
		var stroke := PackedVector2Array([tip - Vector2(4 * corner.x, 0), tip, tip - Vector2(0, 4 * corner.y)])
		draw_polyline(stroke, Color("#243229"), 2.6)
		draw_polyline(stroke, ink, 1.1)
