extends Node2D

func set_available(available: bool) -> void:
	if visible == available:
		return
	visible = available
	for shape: CollisionShape2D in $Walls.get_children():
		shape.set_deferred("disabled", not available)
