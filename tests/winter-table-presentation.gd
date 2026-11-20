extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		push_error("Run the winter table display check with an isolated profile.")
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	var supper_data = load("res://scripts/WinterSupper.gd")
	var day: int = state.SOLAR_TERMS.find(supper_data.TERM) * state.balance.days_per_solar_term + 1
	state.current_day = day
	state.day_progress = 0.44
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var supper := current_scene.get_node("World/WinterSupper")
	var stock: Dictionary = state.crop_stock.lots.duplicate()
	_expect(supper.visible and supper.mats.is_visible_in_tree() and supper.mats.z_index < supper.guests.z_index,
		"The winter table sets out two mats below the guests.")
	_expect(not supper.heated and not supper.actors[0].visible and not supper.actors[1].visible,
		"The pot and seats wait for the evening.")

	state.day_progress = 0.69
	supper._process(0.0)
	_expect(_seated(supper.motions[0]) and not _seated(supper.motions[1]) and supper.motions[1].walking,
		"The first guest takes a seat while the second is still approaching.")
	state.day_progress = 0.76
	supper._process(0.0)
	_expect(_seated(supper.motions[0]) and _seated(supper.motions[1]) and supper.heated and not supper.steam_layer.visible,
		"Both sit around the lit and still-lidded pot.")

	for meal: String in supper_data.MENU:
		state.winter_suppers[day] = {"recipe": meal}
		supper._refresh()
		_expect(supper.scoop_time == 0.0 and supper.steam_layer.visible,
			"The ladle starts and steam rises from either dish.")
		for index in 2:
			_expect(not supper.motions[index].is_visible_in_tree() and _seated(supper.serving_poses[index]),
				"The seated food pose replaces the waiting pose.")
		supper.steam = 1.55
		supper._process(0.0)
		_expect(supper.serving_poses[0].frame == 1 and supper.serving_poses[1].frame == 0,
			"The first guest lifts their bowl.")
		supper.steam = 0.96
		supper._process(0.0)
		_expect(supper.serving_poses[0].frame == 0 and supper.serving_poses[1].frame == 1,
			"The second guest lifts their bowl independently.")

		supper.scoop_time = 0.24
		var dip: Vector2 = supper._ladle_bowl()
		supper.scoop_time = 0.72
		var lifted: Vector2 = supper._ladle_bowl()
		supper.scoop_time = 1.18
		var pour: Vector2 = supper._ladle_bowl()
		_expect(Rect2(-7, -25, 14, 5).has_point(dip) and lifted.y < -28.0
			and absf(pour.x - 22.5) < 2.0 and pour.y < -14.0,
			"The scoop dips inside the pot, clears its rim and tilts above the table bowl.")

	state.winter_suppers.erase(day)
	state.current_day = day + 1
	supper._refresh()
	_expect(not supper.visible and not supper.hearth_glow.enabled and not supper.steam_layer.visible,
		"The winter scene leaves no lit dining props behind on another day.")
	_expect(state.crop_stock.lots == stock and state.saved_games().is_empty(),
		"The presentation samples leave stock and saves intact.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _seated(sprite: Sprite2D) -> bool:
	var art := sprite.get_node_or_null("SeatedPose") as CanvasItem
	return is_instance_valid(art) and art.is_visible_in_tree()

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error(detail)
