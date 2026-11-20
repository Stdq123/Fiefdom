extends Area2D

@export_file("*.tscn") var destination: String
@export var arrival_path: NodePath
@export var player_path: NodePath
@export var arrival_note := ""

func _ready() -> void:
	add_to_group("travel_threshold")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player and not player.conversation_open and not player.resting:
		MapTravel.cross(destination, arrival_path, player_path, arrival_note)
