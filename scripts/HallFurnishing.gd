extends Node2D

enum Use { STUDY, SLEEP, WARDROBE, DECOR }

@export var action := Use.STUDY
@onready var hint: Label = $Hint

func _ready() -> void:
	GameEvents.day_advanced.connect(_refresh_hint.unbind(1))
	_refresh_hint()

func can_interact_from(point: Vector2) -> bool:
	return is_visible_in_tree() and global_position.distance_squared_to(point) <= 24.0 * 24.0

func set_interaction_focused(active: bool) -> void:
	hint.visible = active
	if active:
		_refresh_hint()

func interact() -> void:
	match action:
		Use.SLEEP:
			GameEvents.night_rations_requested.emit()
		Use.WARDROBE:
			GameEvents.wardrobe_requested.emit()
		Use.DECOR:
			GameEvents.hall_decor_requested.emit()
		Use.STUDY:
			if not Global.study_bamboo_slips():
				GameEvents.practice_feedback.emit("今日已研读 · 明日可再读")
			_refresh_hint()

func _refresh_hint() -> void:
	var key := GamepadInput.interact_key()
	match action:
		Use.SLEEP: hint.text = key + "  今夜安排"
		Use.WARDROBE: hint.text = "更衣 · " + key
		Use.DECOR: hint.text = "布置堂屋 · " + key
		Use.STUDY:
			hint.text = key + "  研读简册" if Global.can_practice_today(PlayerStats.Art.LITERACY) else "今日已研读"
