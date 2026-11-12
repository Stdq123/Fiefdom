extends "res://tests/WestMarketReplay.gd"

const ROAD_SCENE := "res://scenes/WestRoad.tscn"

var baseline := false
var from_older_save := false
var capture_path := ""

func _play() -> void:
	if not capture_path.is_empty():
		capture_dir = capture_path
	if from_older_save:
		await _continue_old_market()
		return
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	var world := tree.current_scene.get_node("World") as Node2D
	var ui := tree.current_scene.get_node("UI") as CanvasLayer
	await _button(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	management.show_market()
	await tree.process_frame
	await _button(management.market_panel.get_node("MarketHeader/MarketDirections"))
	await Campaign.walk_estate_road_to(tree, world, Vector2(-270, -21))
	await _snapshot("00-estate-west-gate")
	if not await _measure_outbound():
		return
	var market := tree.current_scene as Node2D
	await tree.create_timer(0.05).timeout
	_expect(market.market_map.pin.visible and state.market_trip_target == "粮摊", "The grain marker continues into the market.")
	await _snapshot("01-market-arrival")
	if baseline:
		await _button(market.get_node("%SettingsButton"))
		await _button(market.settings.save_button)
		_expect(FileAccess.file_exists(state.manual_save_path()), "Write the previous build's real market checkpoint.")
		print("WEST_ROAD_OLD_SAVE path=", ProjectSettings.globalize_path(state.manual_save_path()))
	else:
		await _return_and_continue(market)

func _measure_outbound() -> bool:
	var start := Time.get_ticks_msec()
	var path: Array[String] = [state.ESTATE_SCENE]
	var travel := tree.root.get_node("MapTravel")
	var road_ticks := 0
	Input.action_press(&"ui_left")
	for tick in 460:
		await tree.physics_frame
		var scene := tree.current_scene
		if scene == null:
			continue
		if path.back() != scene.scene_file_path:
			path.append(scene.scene_file_path)
		if not travel.active:
			if scene.scene_file_path == ROAD_SCENE:
				road_ticks += 1
			elif scene.scene_file_path == state.WEST_MARKET_SCENE:
				break
	Input.action_release(&"ui_left")
	await tree.process_frame
	var elapsed := float(Time.get_ticks_msec() - start) / 1000.0
	var walked := float(road_ticks) / Engine.physics_ticks_per_second
	print("WEST_ROAD_WALK baseline=", baseline, " seconds=", snappedf(elapsed, 0.01), " crossing_seconds=",
		snappedf(walked, 0.01), " scenes=", path)
	if baseline:
		return _expect(path == [state.ESTATE_SCENE, state.WEST_MARKET_SCENE], "The previous build opens directly into the market.")
	return _expect(path == [state.ESTATE_SCENE, ROAD_SCENE, state.WEST_MARKET_SCENE]
		and walked >= 4.5 and walked <= 5.0, "Holding left crosses the new road and enters the market at walking speed.")

func _return_and_continue(market: Node2D) -> void:
	await _key(KEY_M)
	await _button(market.market_map.markers[state.MARKET_RETURN])
	await _key(KEY_M)
	if not await _cross(&"ui_right", ROAD_SCENE):
		return
	var road := tree.current_scene as Node2D
	var player: Player = road.player
	_expect(state.market_trip_target == state.MARKET_RETURN and road.route_direction == Vector2.RIGHT,
		"The market return marker continues east on the bridge road.")
	await _snapshot("02-market-end-of-road")
	await _walk(player, [Vector2(-70, -70)])
	await Campaign.walk_straight(tree, player, Vector2(12, -70))
	_expect(player.position.x < -43 and not Geometry2D.is_point_in_polygon(player.position, road.ground.water),
		"Deep water stops the player at the visible bank away from the bridge.")
	await _walk(player, [Vector2(-82, 36), Vector2(-17, 36)])
	_expect(road.ground.LAYOUT.BRIDGE.has_point(player.position), "The bridge connects the two banks.")
	await _snapshot("03-creek-bridge")
	await _button(road.get_node("%SettingsButton"))
	var progress: float = state.day_progress
	await tree.create_timer(0.30).timeout
	_expect(road.settings.visible and state.day_progress == progress, "The road clock pauses in settings.")
	await _button(road.settings.save_button)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.manual_save_path()))
	_expect(saved.location == "west_road" and saved.west_road_from_market and saved.market_trip_target == state.MARKET_RETURN,
		"Save records the nearer gate and the trip target.")
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	var title := tree.current_scene as Control
	_expect("溪桥道" in title.status.text, "The title names the bridge road checkpoint.")
	await _button(title.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	road = tree.current_scene
	if not _expect(road.scene_file_path == ROAD_SCENE, "Continue returns to the bridge road."):
		return
	_expect(road.player.position == road.get_node("MarketArrival").position and road.route_direction == Vector2.RIGHT,
		"Continue starts inside the market-side gate and points toward the estate.")
	await _snapshot("04-road-continued")
	if await _cross(&"ui_right", state.ESTATE_SCENE):
		var world := tree.current_scene.get_node("World") as Node2D
		_expect(world.player.position.distance_to(world.get_node("WestMarketArrival").position) < 4.0
			and state.market_trip_target.is_empty(), "The return marker clears on reaching the estate.")
		await _snapshot("05-estate-returned")
	print("WEST_ROAD_RETURN save_side=market facing=east continued=", not failed)

func _continue_old_market() -> void:
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await tree.create_timer(0.05).timeout
	var market := tree.current_scene as Node2D
	if _expect(market.scene_file_path == state.WEST_MARKET_SCENE and market.market_map.pin.visible
			and state.market_trip_target == "粮摊", "The older market checkpoint keeps its entrance and grain-stall waypoint."):
		await _snapshot("00-older-market-continued")
		await _cross(&"ui_right", state.ESTATE_SCENE)
	print("WEST_ROAD_OLD_CONTINUE day=", state.current_day, " success=", not failed)
