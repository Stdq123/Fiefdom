extends Area2D

const APPROACH_LENGTH := 46.0
const APPROACH_MARGIN := 4.0

@export_file("*.tscn") var destination: String
@export var arrival_path: NodePath
@export var player_path: NodePath
@export var arrival_note := ""

var _mouth: CollisionShape2D

func _ready() -> void:
	add_to_group("travel_threshold")
	body_entered.connect(_on_body_entered)
	for child in get_children():
		if child is CollisionShape2D:
			_mouth = child
			break
	if _mouth and _mouth.shape and not MapTravel.place_name(destination).is_empty():
		add_to_group(&"outdoor_gates")

func approach_distance(foot: Vector2, heading: Vector2) -> float:
	if not monitoring or _mouth.disabled:
		return INF
	var mouth := _mouth.global_transform * _mouth.shape.get_rect()
	var across_x := mouth.size.x < mouth.size.y
	var along := Vector2.RIGHT if across_x else Vector2.DOWN
	var toward := mouth.get_center() - foot
	var padding := Vector2(APPROACH_LENGTH, APPROACH_MARGIN) if across_x else Vector2(APPROACH_MARGIN, APPROACH_LENGTH)
	var approach := Rect2(mouth.position - padding, mouth.size + padding * 2.0)
	if approach.has_point(foot) and not mouth.has_point(foot) and heading.dot(along) * signf(toward.dot(along)) > 0.5:
		return toward.length()
	return INF

func approach_caption() -> String:
	return "沿路前往%s" % MapTravel.place_name(destination)

func mouth_in_viewport() -> Rect2:
	return _mouth.get_global_transform_with_canvas() * _mouth.shape.get_rect()

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player and not player.conversation_open and not player.resting:
		MapTravel.cross(destination, arrival_path, player_path, arrival_note)
