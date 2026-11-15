extends "res://tests/FieldStrokeReplay.gd"

func _write_initial_checkpoint() -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await _estate()
	var walker: Player = world.player
	await Campaign.walk_estate_road_to(tree, world, Vector2(135, 122))
	if not _expect(walker.global_position.distance_to(Vector2(135, 122)) < 5.0, "Walk to the first field from the title's ordinary new game."):
		return false
	for _action in 3:
		await _click(_point(PUBLIC))
	if not _expect(state.active_crops.get(PUBLIC, {}).get("watered", false), "Plant and water the public plot normally."):
		return false
	var original := walker.global_position
	var facing := walker.facing_direction()
	var stamina: int = state.current_stamina
	await _save_manually()
	await _capture("00-field-before-continue")
	await _continue_latest()
	walker = world.player
	if not _expect(walker.global_position.is_equal_approx(original) and walker.facing_direction() == facing
		and state.current_stamina == stamina and state.current_day == 1 and state.active_crops[PUBLIC].watered,
		"Continue restores the actual field position, facing, stamina and watered crop."):
		return false
	await _capture("01-field-continued")
	print("WALKING_CHECKPOINT_ESTATE saved=", original, " restored=", walker.global_position, " facing=", facing)
	await _sleep()
	var dawn_path: String = state.latest_saved_game().path
	var dawn: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dawn_path))
	if not _expect(state.current_day == 2 and state.active_crops[PUBLIC].age == 1 and dawn.save_origin == "dawn"
		and not dawn.has("walking_checkpoint"), "Dawn saves keep the established wake-up and farm growth rules."):
		return false
	await Campaign.walk_estate_road_to(tree, world, Vector2(-270, -21))
	if not _expect(await Campaign.walk_through_gates(tree, &"ui_left", state.WEST_ROAD_SCENE), "Cross the actual west gate to the bridge road."):
		return false
	var road: Node2D = tree.current_scene
	await Campaign.walk_straight(tree, road.player, Vector2(-17, 36))
	await _button(road.get_node("%SettingsButton"))
	await _button(road.settings.save_button)
	var path: String = state.manual_save_path()
	var point: Vector2 = road.player.global_position
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var checkpoint: Dictionary = saved.get("walking_checkpoint", {})
	var stored := Vector2(checkpoint.get("x", INF), checkpoint.get("y", INF))
	if not _expect(road.settings.save_status.text == "游戏已保存" and road.ground.LAYOUT.BRIDGE.has_point(point)
		and saved.location == "west_road" and stored.is_equal_approx(point),
		"Save from the bridge deck with the real settings control. Standing at %s, saved %s." % [point, stored]):
		return false
	await _button(road.settings.close_button)
	await _capture("02-bridge-manual-checkpoint")
	print("WALKING_CHECKPOINT_WRITE scene=", saved.location, " day=", saved.current_day,
		" foot=", point, " facing=", road.player.facing_direction(), " sha256=", FileAccess.get_sha256(path))
	return true

func _read_bridge_checkpoint() -> void:
	var entry: Dictionary = state.latest_saved_game()
	if not _expect(entry.get("location") == "溪桥道", "Start continuation from the actual bridge manual checkpoint."):
		return
	var path: String = entry.path
	var original := FileAccess.get_sha256(path)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var point := Vector2(saved.walking_checkpoint.x, saved.walking_checkpoint.y)
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	var road: Node2D = tree.current_scene
	if not _expect(road.scene_file_path == state.WEST_ROAD_SCENE and road.player.global_position.is_equal_approx(point)
		and state.current_day == 2 and road.player.facing_direction() == Vector2.LEFT,
		"Ordinary Continue restores the bridge deck and original heading."):
		return
	await _capture("03-bridge-continued")
	print("WALKING_CHECKPOINT_CONTINUE scene=west_road day=", state.current_day,
		" foot=", road.player.global_position, " facing=", road.player.facing_direction(), " sha256=", FileAccess.get_sha256(path))
	var gate := road.get_node("EstateGate") as Area2D
	var blocked := Vector2(-42, -106)
	_expect(Geometry2D.is_point_in_polygon(blocked, road.ground.water), "Test an actual position inside the stream.")
	var rejects := {
		"river": {"x": blocked.x, "y": blocked.y, "facing": "0,1"},
		"threshold": {"x": gate.global_position.x, "y": gate.global_position.y, "facing": "1,0"},
		"outside": {"x": 3200, "y": -1500, "facing": "-1,0"},
		"malformed": {"x": "-17", "y": 36, "facing": "-1,0"},
	}
	for key: String in rejects:
		var clone := saved.duplicate(true)
		clone.walking_checkpoint = rejects[key]
		var altered := "user://walking-%s.json" % key
		var file := FileAccess.open(altered, FileAccess.WRITE)
		file.store_string(JSON.stringify(clone))
		file.close()
		if not _expect(state.load_game(altered) == OK, "The original game data survives an invalid position (%s)." % key):
			return
		await tree.scene_changed
		await tree.physics_frame
		road = tree.current_scene
		var fallback := road.get_node("MarketArrival" if saved.west_road_from_market else "EstateArrival") as Marker2D
		_expect(road.scene_file_path == state.WEST_ROAD_SCENE and road.player.global_position.is_equal_approx(fallback.global_position)
			and not MapTravel.active and state.current_day == 2 and state.active_crops[PUBLIC].age == 1,
			"Resume at a usable entrance if the saved position is invalid (%s)." % key)
		print("WALKING_CHECKPOINT_FALLBACK kind=", key, " foot=", road.player.global_position)
	_expect(FileAccess.get_sha256(path) == original, "Loading positions and using the fallback preserves the original file.")
	var before: Vector2 = road.player.global_position
	var toward_bridge := Vector2(16, 0) if saved.west_road_from_market else Vector2(-16, 0)
	await Campaign.walk_straight(tree, road.player, before + toward_bridge)
	_expect(road.player.global_position.distance_to(before) > 10.0, "Walk out of the fallback arrival without getting stuck.")

func run_walking_checkpoint(host: SceneTree, captures := "", variant := "walking-checkpoint") -> void:
	tree = host
	state = tree.root.get_node("Global")
	capture_dir = captures
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated walking checkpoint profile."):
		tree.quit(1)
		return
	tree.root.notify_mouse_entered()
	if variant != "walking-checkpoint-restart" and not await _write_initial_checkpoint():
		tree.quit(1)
		return
	if variant != "walking-checkpoint-write":
		await _read_bridge_checkpoint()
	tree.unload_current_scene()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
