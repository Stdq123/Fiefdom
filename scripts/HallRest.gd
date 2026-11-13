extends "res://scripts/EstateEntrance.gd"

func set_available(available: bool) -> void:
	if visible == available:
		return
	super.set_available(available)
	if available:
		add_to_group("interactable")
	else:
		remove_from_group("interactable")
		set_interaction_focused(false)

func set_interaction_focused(active: bool) -> void:
	$InteractionHint.visible = active
	if active:
		$InteractionHint.text = "堂屋 · 走上台阶进门\n%s  今夜安排" % GamepadInput.interact_key()

func interact() -> void:
	GameEvents.night_rations_requested.emit()
