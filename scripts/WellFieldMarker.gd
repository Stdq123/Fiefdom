extends Node2D
class_name WellFieldMarker

const WORKSITE := preload("res://scripts/FieldWorksite.gd")
const ENTRANCE_WIDTH := EstateLayout.FIELD_ENTRANCE_WIDTH

@onready var tile_map: TileMapLayer = get_parent()
@onready var landscape: Node2D = tile_map.get_parent().get_node("Landscape")

var marker_nodes: Dictionary[int, Node2D] = {}

func refresh_markers() -> void:
	for field_data in Global.well_fields:
		_update_marker(field_data["field_id"])

func _update_marker(field_id: int) -> void:
	var field := Global.get_well_field(field_id)
	if field.is_empty():
		return
	if marker_nodes.has(field_id):
		var previous := marker_nodes[field_id]
		remove_child(previous)
		previous.queue_free()
	var marker := Node2D.new()
	marker.name = "WellField%d" % (field_id + 1)
	marker.position = tile_map.map_to_local(field["center_pos"])
	add_child(marker)
	marker_nodes[field_id] = marker

	var cell_size := Vector2(tile_map.tile_set.tile_size)
	var half_span := cell_size * 1.5
	var entrance: Vector2 = landscape.field_entrance(field_id)
	var title := "井田 %d" % (field_id + 1)
	if field["is_unlocked"]:
		var line := Line2D.new()
		line.name = "Boundary"
		line.points = EstateLayout.field_boundary(Rect2(-half_span, half_span * 2.0), entrance, ENTRANCE_WIDTH)
		line.width = 0.5
		line.default_color = Color("#614d37")
		marker.add_child(line)
	else:
		var worksite := WORKSITE.new()
		worksite.name = "Worksite"
		worksite.stage = field["reclamation_progress"]
		worksite.entrance = entrance
		worksite.scale = cell_size / 16.0
		worksite.z_index = 1
		marker.add_child(worksite)
		title = "井田 %d · %s\n余 %d 夜" % [
			field_id + 1, Global.reclamation_stage(worksite.stage), Global.RECLAMATION_NIGHTS - worksite.stage]

	var label := Label.new()
	label.material = preload("res://resources/world_hint_material.tres")
	label.name = "Status"
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10 if field["is_unlocked"] else 9)
	label.add_theme_constant_override("line_spacing", -2)
	label.add_theme_color_override("font_color", Color("#e1ddbb"))
	label.add_theme_color_override("font_outline_color", Color("#263d2e"))
	label.add_theme_constant_override("outline_size", 2)
	# The field name belongs to the bank, beneath passing workers and their tools.
	label.z_as_relative = false
	label.z_index = -1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(label)
	var caption_size := label.get_combined_minimum_size()
	label.position.x = half_span.x - caption_size.x if field["is_unlocked"] else -caption_size.x * 0.5
	# Keep both the raised sluice and the top of the survey stakes clear of the caption.
	var margin := 11.0 if field["is_unlocked"] else 8.0
	label.position.y = half_span.y + margin if entrance == Vector2.UP else -half_span.y - caption_size.y - margin
