extends Label

func _ready() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - 9, 0.85)
	tween.tween_property(self, "modulate:a", 0.0, 0.30).set_delay(0.55)
	tween.chain().tween_callback(queue_free)
