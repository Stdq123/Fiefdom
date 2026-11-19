extends Node2D
class_name WellFieldMarker

const WORKSITE := preload("res://scripts/FieldWorksite.gd")
const INSCRIPTION := preload("res://scripts/VillageInscription.gd")
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

	var form := INSCRIPTION.Form.FIELD if field["is_unlocked"] else INSCRIPTION.Form.SURVEY
	var foot := Vector2(6.0 if field["is_unlocked"] else 0.0, -half_span.y - 7.0)
	if entrance == Vector2.UP:
		foot.y = half_span.y + INSCRIPTION.HEIGHTS[form] + 5.0
	var signboard := INSCRIPTION.place(marker, foot, form, title, Vector2.ZERO, true)
	# Both the bank and its writing sit below passing workers and their tools.
	signboard.z_as_relative = false
	signboard.z_index = -1
	signboard.caption.z_as_relative = false
	signboard.caption.z_index = -1
