extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _settle() -> void:
	for frame in 5:
		await process_frame

func _bounds(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _inspect(player: Node2D, plaque: Control, expected: String) -> void:
	var bounds := _bounds(plaque)
	var body: Sprite2D = player.sprite
	_expect(plaque.is_visible_in_tree() and root.get_visible_rect().grow(-7.0).encloses(bounds)
		and not bounds.intersects(body.get_global_transform_with_canvas() * body.get_rect()),
		"The focused caption stays inside the frame and off the player.")
	_expect(expected in plaque.description.text and plaque.description.text == plaque.source_label.text
		and plaque.description.get_line_count() == plaque.description.get_visible_line_count(),
		"The plaque reads the live action cue, including its whole text.")
	_expect(plaque.source_label.self_modulate.a == 0.0, "The focused caption appears once.")

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the interaction prompt check with an isolated smoke profile.")
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	var prefs := root.get_node("Preferences")
	var events := root.get_node("GameEvents")
	var pad := root.get_node("GamepadInput")
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	var world := current_scene.get_node("World")
	var ui := current_scene.get_node("UI")
	var player: Node2D = world.player
	var camera: Camera2D = player.camera
	var plaque: Control = player.interaction_prompt
	var hall := world.get_node("HallRest") as Node2D
	player.global_position = hall.global_position + Vector2(0, 42)
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2.ONE * 3.0
	camera.force_update_scroll()
	var before := [state.current_day, state.day_progress, state.money, state.food_storage,
		state.current_stamina, player.position, hash(state.active_crops), hash(state.visitor_encounters)]
	var target: Node2D = player._nearest_interactable()
	_expect(target == hall, "The normal focus selection finds the hall at its public approach.")
	player._set_interaction_target(target)
	await _settle()
	_inspect(player, plaque, "E  今夜安排")
	_expect(ui.hud.map_space_clear(_bounds(plaque).grow(-0.01)), "The hall cue fits around the HUD.")
	var old_label: Label = plaque.source_label
	var original_font: int = plaque.description.get_theme_font_size(&"font_size")
	var original_size := plaque.size
	camera.zoom = Vector2.ONE * 1.5
	camera.force_update_scroll()
	await _settle()
	_expect(plaque.size == original_size, "Camera zoom affects the anchor and preserves the on-screen reading size.")
	_expect(prefs.set_reading_size(2) == OK, "Set the largest reading size.")
	await _settle()
	_expect(plaque.description.get_theme_font_size(&"font_size") == original_font + 6 and plaque.size.y > original_size.y,
		"Reading size remeasures the live plaque.")
	_expect(prefs.set_binding(&"interact", KEY_G) == OK, "Rebind the normal interaction action in the test profile.")
	await _settle()
	_inspect(player, plaque, "G  今夜安排")
	pad.active = true
	pad.changed.emit()
	await _settle()
	_inspect(player, plaque, "X  今夜安排")
	events.modal_visibility_changed.emit(true)
	await _settle()
	_expect(not plaque.visible and old_label.self_modulate.a == 0.0, "A full-screen menu covers both versions of the cue.")
	events.modal_visibility_changed.emit(false)
	await _settle()
	_inspect(player, plaque, "X  今夜安排")
	player._set_interaction_target(null)
	_expect(not plaque.visible and old_label.self_modulate.a == 1.0, "Clearing focus restores the source label appearance.")
	pad.active = false
	pad.changed.emit()
	_expect(paused and state.saved_games().is_empty() and before == [state.current_day, state.day_progress, state.money,
		state.food_storage, state.current_stamina, player.position, hash(state.active_crops), hash(state.visitor_encounters)],
		"Changing the displayed help keeps the player and campaign in place.")

	if change_scene_to_file(state.WEST_MARKET_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	player = current_scene.get_node("Player")
	plaque = player.interaction_prompt
	var fish_stall := current_scene.get_node("Stalls/FishStall") as Node2D
	player.global_position = fish_stall.to_global(Vector2(0, 24))
	player.camera.position_smoothing_enabled = false
	player.camera.force_update_scroll()
	target = player._nearest_interactable()
	_expect(target == fish_stall and not plaque.estate_obstacles.is_valid(), "Reach the fish stall in the separate market scene.")
	player._set_interaction_target(target)
	await _settle()
	_inspect(player, plaque, "渔生 · 鱼摊 · G")
	_expect(paused and state.saved_games().is_empty(), "The market cue can be checked on a frozen scene.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
