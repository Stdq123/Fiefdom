extends "res://tests/FishMarketReplay.gd"

const SOUTH_PATH := "南路小径"
const SHOAL := "砾滩"
const CROP := Vector2i(6, 5)

var baseline := false

func _seed_survey() -> void:
	var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"current_day": 7, "day_progress": 0.22, "king_storage": 2, "food_storage": 14,
		"current_stamina": 82, "health": 83, "visitor_encounters": ["蒲宁"],
		"ravine_journal": {"recorded_days": [5, 4, 6]},
		"active_crops": {"6,5": {"id": "millet", "age": 1, "growth_nights": 2, "watered": true}},
	}))
	file.close()

func _continue_from_title() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await tree.process_frame

func _check_closed_gate() -> bool:
	var gate := world.get_node("RavineTrailGate") as Node2D
	await Campaign.walk_estate_road_to(tree, world, gate.global_position + Vector2(-18, 3))
	Input.action_press(&"ui_right")
	for frame in 22:
		await tree.physics_frame
	Input.action_release(&"ui_right")
	await tree.process_frame
	var blocked := _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE
		and world.player.position.x < gate.position.x and not gate.get_node("Barrier/Shape").disabled
		and "未开" in gate.get_node("Caption").text, "The bamboo bar blocks the route before handing in the three notes.")
	await _snapshot("01-closed-gate")
	return blocked

func _hand_in_survey() -> bool:
	var guide: Node2D = world.neighbor_actor(VisitorData.RAVINE_GUIDE)
	await Campaign.walk_estate_road_to(tree, world, guide.global_position + Vector2(0, 16))
	await _key(KEY_E)
	var dialogue := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialogue != null and dialogue.name_label.text == VisitorData.RAVINE_GUIDE, "Reach the guide on foot."):
		return false
	await _snapshot("02-hand-in-notes")
	for choice: Button in dialogue.options_container.get_children():
		if choice.text == "交溪行手记":
			await _button(choice)
			break
	_expect(state.ravine_journal.garden_day == 7 and world.get_node("HerbGarden").visible,
		"The normal dialogue completes the survey and opens the garden.")
	if baseline:
		return not failed
	var gate := world.get_node("RavineTrailGate")
	return _expect(gate.get_node("Barrier/Shape").disabled and "未开" not in gate.get_node("Caption").text,
		"The same handoff lifts the bamboo bar.")

func _choose_shoal_from_estate() -> void:
	await _key(KEY_M)
	var chart: Control = ui.estate_map
	await _button(chart.get_node("%RegionMap"))
	var overview: Control = chart.region_map
	await _button(overview.region_buttons.get_node("Ravine"))
	await _button(overview.destination_buttons[SHOAL])
	_expect(overview.route_label.text == "封地 → 竹涧 · 经竹涧小径", "The regional map names the unlocked southern route.")
	await _snapshot("03a-region-shortcut")
	await _button(overview.route_button)
	await _key(KEY_M)
	await _button(chart.tabs.get_node("Ravine"))
	for row: Button in chart.row_buttons:
		if chart.row_buttons[row].title == SHOAL:
			await _button(row)
			break
	_expect(state.ravine_trip_target == SHOAL and chart.target.point == world.get_node("RavineTrailGate").position
		and chart.road_path.has(EstateLayout.FESTIVAL_FORK) and "经竹涧小径" in chart.status.text,
		"The chart routes a trip from the south estate through the shortcut.")
	await _snapshot("03-estate-route")
	await _key(KEY_ESCAPE)

func _reach_shoal(use_shortcut: bool) -> Node2D:
	var approach := world.get_node("RavineTrailArrival" if use_shortcut else "EastArrival") as Marker2D
	var start := Engine.get_physics_frames()
	await Campaign.walk_estate_road_to(tree, world, approach.global_position)
	if not await _cross(&"ui_right", state.WILDERNESS_SCENE):
		return null
	await tree.process_frame
	var ravine := tree.current_scene as Node2D
	var player := ravine.get_node("Player") as Player
	var entry := ravine.get_node("SouthTrailArrival" if use_shortcut else "WestArrival") as Marker2D
	_expect(player.position.distance_to(entry.position) < 3.0
		and player.facing_direction() == (Vector2.UP if use_shortcut else Vector2.RIGHT),
		"Arrive beyond the gate and face the interior trail.")
	for enemy in tree.get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	if use_shortcut:
		_expect(ravine.ravine_map.guide.destination_name == SHOAL and ravine.ravine_map.guide.route.has(RavineLayout.FORD),
			"The destination resumes at the south arrival and crosses the existing ford.")
	var shoal := ravine.get_node("GravelShoal") as Node2D
	await Campaign.walk_ravine_to(tree, ravine, shoal.global_position + Vector2(0, 12))
	_expect(player.position.distance_to(shoal.global_position + Vector2(0, 12)) < 4.0, "Reach the same dry fishing stand on foot.")
	var seconds := (Engine.get_physics_frames() - start) / float(Engine.physics_ticks_per_second)
	print("SHORTCUT_WALK gate=", "south" if use_shortcut else "east", " seconds=", snappedf(seconds, 0.01))
	return ravine

func _save_in_ravine(ravine: Node2D, hint: String) -> bool:
	await _key(KEY_ESCAPE)
	var panel: Control = ravine.settings
	if not _expect(panel.visible and tree.paused, "Open the normal settings panel in the ravine."):
		return false
	for button: Button in panel.general.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	_expect(panel.save_status.text == "游戏已保存 · " + hint and state.latest_saved_game().get("location") == "竹涧",
		"Saving names the resume point and keeps the ravine in the save archive.")
	await _snapshot("05-save")
	await _button(panel.close_button)
	return not failed

func _choose_south_exit(ravine: Node2D) -> void:
	await _key(KEY_M)
	var chart: Control = ravine.ravine_map
	await _button(chart.markers[SOUTH_PATH])
	_expect(chart.guide.destination_name == SOUTH_PATH and "回封地南路" in chart.route_status.text,
		"The chart marks the south shortcut back to the estate.")
	await _snapshot("04-ravine-route")
	await _key(KEY_ESCAPE)

func _walk_back(ravine: Node2D) -> void:
	await Campaign.walk_ravine_to(tree, ravine, ravine.get_node("SouthTrailArrival").position)
	if not await _cross(&"ui_down", state.ESTATE_SCENE):
		return
	await _estate()
	var player := world.player as Player
	_expect(player.position.distance_to(world.get_node("RavineTrailArrival").position) < 3.0
		and player.facing_direction() == Vector2.LEFT and state.king_storage == 2 and state.food_storage == 14
		and state.active_crops.get(CROP, {}).get("watered", false),
		"The return lands beside the south road and keeps the estate's tribute, food and watered crop.")
	await _snapshot("07-south-estate-return")

func _legacy_route() -> void:
	await _continue_from_title()
	var ravine := tree.current_scene as Node2D
	if not _expect(ravine.scene_file_path == state.WILDERNESS_SCENE
		and ravine.get_node("Player").position == ravine.get_node("WestArrival").position,
		"A save from the older package still resumes at the west arrival."):
		return
	_expect(state.ravine_journal.garden_day == 7 and state.last_forage_day == 7 and state.last_fishing_day == 7 and ravine.active_waypoint() == "柳湾"
		and not ravine.ravine_map.markers[SOUTH_PATH].disabled, "The old survey, catch and wayfinding survive and the shortcut is open.")
	for enemy in tree.get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await _choose_south_exit(ravine)
	await _walk_back(ravine)
	print("SHORTCUT_LEGACY day=", state.current_day, " garden_day=", state.ravine_journal.garden_day)

func _play() -> void:
	_seed_survey()
	await _continue_from_title()
	await _estate()
	if not baseline and not await _check_closed_gate():
		return
	if not await _hand_in_survey():
		return
	world.player.arrive_at_position(EstateLayout.SOUTH_PAVILION + Vector2(0, 21), Vector2.DOWN)
	if not baseline:
		await _choose_shoal_from_estate()
	var ravine := await _reach_shoal(not baseline)
	if ravine == null:
		return
	var fish_id: String = state.fish_at_today(CreekFish.Site.SHOAL)
	if not await _catch_at(ravine.get_node("GravelShoal"), fish_id, ""):
		return
	if baseline:
		ravine.ravine_map.follow_place("柳湾")
		await _save_in_ravine(ravine, "从竹涧西门继续")
		return
	await _choose_south_exit(ravine)
	var stamina: int = state.current_stamina
	var health: int = state.health
	var time: float = state.day_progress
	if not await _save_in_ravine(ravine, "从竹涧南路小径继续"):
		return
	await _continue_from_title()
	ravine = tree.current_scene
	if not _expect(ravine.scene_file_path == state.WILDERNESS_SCENE
		and ravine.get_node("Player").position.distance_to(ravine.get_node("SouthTrailArrival").position) < 3.0,
		"The new save continues at the south entrance."):
		return
	_expect(state.current_stamina == stamina and state.health == health and absf(state.day_progress - time) < 0.01
		and state.fish_count(fish_id) == 1 and state.last_fishing_day == 7 and state.last_forage_day != 7
		and ravine.active_waypoint() == SOUTH_PATH,
		"Continue preserves clock, vitals, catch and the selected exit.")
	await _snapshot("06-south-resume")
	await _walk_back(ravine)
	print("SHORTCUT_ROUND_TRIP day=", state.current_day, " fish=", fish_id, " food=", state.food_storage)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	state = tree.root.get_node("Global")
	capture_dir = capture_path
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated shortcut profile."):
		tree.quit(1)
		return
	if legacy:
		await _legacy_route()
	else:
		await _play()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
