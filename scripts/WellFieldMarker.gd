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
		line.width = 1.0
		line.default_color = Color("#a29467")
		line.z_index = 50
		marker.add_child(line)
	else:
		var worksite := WORKSITE.new()
		worksite.name = "Worksite"
		worksite.stage = field["reclamation_progress"]
		worksite.scale = cell_size / 16.0
		worksite.z_index = 1
		marker.add_child(worksite)
		title = "%s · 余 %d 夜" % [
			Global.reclamation_stage(worksite.stage), Global.RECLAMATION_NIGHTS - worksite.stage]

	var label := Label.new()
	label.material = preload("res://resources/world_hint_material.tres")
	label.name = "Status"
	label.text = title
	label.position = -half_span + Vector2(0, -15)
	if entrance == Vector2.UP:
		label.position.y = half_span.y + 2.0
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#e1ddbb"))
	label.add_theme_color_override("font_outline_color", Color("#263d2e"))
	label.add_theme_constant_override("outline_size", 2)
	label.z_index = 51
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(label)
