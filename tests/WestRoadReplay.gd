extends "res://tests/WestMarketReplay.gd"

const ROAD_SCENE := "res://scenes/WestRoad.tscn"

var baseline := false
var from_older_save := false
var bank_check := ""
var capture_path := ""

func _play() -> void:
	if not capture_path.is_empty():
		capture_dir = capture_path
	if from_older_save:
		await _continue_old_market()
		return
	if bank_check == "west-road-bank-resume":
		await _continue_from_creek()
		return
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	var world := tree.current_scene.get_node("World") as Node2D
	var ui := tree.current_scene.get_node("UI") as CanvasLayer
	if not bank_check.is_empty():
		await _check_creek_weather(world)
		return
	if baseline:
		await _button(ui.manage_button)
		var management: Control = ui.panel_manager.management_panel_instance
		management.show_market()
		await tree.process_frame
		await _button(management.market_panel.get_node("MarketHeader/MarketDirections"))
	else:
		await _start_from_estate(ui.estate_map)
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

func _start_from_estate(local: Control) -> void:
	await _key(KEY_M)
	await _button(local.get_node("%RegionMap"))
	var overview: Control = local.region_map
	var clock: float = state.day_progress
	_expect(overview.modal.visible and tree.paused and not local.modal.visible
		and overview.region == overview.Region.ESTATE, "Open the regional view from the estate map without resuming the clock.")
	await _button(overview.local_button)
	_expect(local.modal.visible and not overview.modal.visible and tree.paused and state.day_progress == clock,
		"Switch back to the local field map during the same pause.")
	await _button(local.get_node("%RegionMap"))
	await _key(KEY_M)
	_expect(not tree.paused and not local.modal.visible and not overview.modal.visible, "The map key closes the overview.")
	await _key(KEY_M)
	await _button(local.get_node("%RegionMap"))
	_expect(not overview.destination_buttons.has(state.MARKET_RETURN) and not state.ravine_shortcut_open(),
		"The starting estate has no return action or unlocked shortcut.")
	await _click(overview.paper.get_global_rect().position + Vector2(97, 184))
	await _button(overview.destination_buttons["粮摊"])
	_expect(overview.route_label.text == "封地 → 溪桥道 → 西市" and state.market_trip_target.is_empty(),
		"The overview previews the crossing before the player commits a waypoint.")
	await _snapshot("00a-estate-regions")
	await _button(overview.route_button)
	_expect(not tree.paused and state.market_trip_target == "粮摊",
		"Confirm the grain stall and guide to the first gate.")

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
	var local: Control = market.market_map
	await _button(local.get_node("%RegionMap"))
	var overview: Control = local.region_map
	await _button(overview.region_buttons.get_node("Ravine"))
	await _button(overview.destination_buttons["柳湾"])
	_expect(overview.route_label.text == "西市 → 溪桥道 → 封地 → 竹涧 · 经东关"
		and state.market_trip_target == "粮摊" and state.ravine_trip_target.is_empty(),
		"See the full trip to Willow Bend before replacing the active stall waypoint.")
	await _snapshot("01a-market-to-ravine")
	await _button(overview.region_buttons.get_node("Estate"))
	await _button(overview.destination_buttons[state.MARKET_RETURN])
	await _button(overview.route_button)
	if not await _cross(&"ui_right", ROAD_SCENE):
		return
	var road := tree.current_scene as Node2D
	var player: Player = road.player
	var west_position: Vector2 = road._map_road_progress()
	_expect(state.market_trip_target == state.MARKET_RETURN and road.route_direction == Vector2.RIGHT,
		"The market return marker continues east on the bridge road.")
	await _snapshot("02-market-end-of-road")
	await _walk(player, [Vector2(-70, -70)])
	await Campaign.walk_straight(tree, player, Vector2(12, -70))
	_expect(player.position.x < -43 and not Geometry2D.is_point_in_polygon(player.position, road.ground.water),
		"Deep water stops the player at the visible bank away from the bridge.")
	var west_edge := _distance_to_bank(player.position, road.ground.shelf_edges[0])
	await _walk(player, [Vector2(-82, 36), Vector2(-53, 36)])
	var west_step := _last_step()
	_expect(road.ground.bridge_apron_at(player.position) and west_step.begins_with("stone-"),
		"The west stone apron connects to the dirt road and plays a stone footstep.")
	await Campaign.walk_straight(tree, player, Vector2(-17, 36))
	var deck_step := _last_step()
	_expect(deck_step.begins_with("plank-"), "The deck plays a timber footstep.")
	_expect(road.ground.LAYOUT.BRIDGE.has_point(player.position), "The bridge connects the two banks.")
	var bridge: Node2D = road.get_node("CreekBridge")
	var deck: Node2D = bridge.get_node("Deck")
	var rail: Node2D = bridge.get_node("NearRail")
	_expect(bridge.y_sort_enabled and deck.z_index < player.sprite.z_index and rail.z_index == player.sprite.z_index
		and rail.global_position.y == road.ground.LAYOUT.BRIDGE.end.y,
		"The deck lies under the traveler and the near rail sorts against the traveler's feet.")
	_expect(west_position.x < 0.1 and absf(road._map_road_progress().x - 0.5) < 0.06,
		"The map marker moves from the market side to the bridge according to the player's position.")
	await _snapshot("03-creek-bridge")
	var low_side := Vector2(-17, road.ground.LAYOUT.BRIDGE.end.y - 9.0)
	await Campaign.walk_straight(tree, player, low_side)
	_expect(player.position.distance_to(low_side) < 3.0 and player.position.y < rail.global_position.y,
		"The lower strip of planks stays walkable behind the near railing.")
	await _snapshot("03a-behind-bridge-rail")
	print("WEST_ROAD_RAIL foot=", player.position, " rail_y=", rail.global_position.y)
	await Campaign.walk_straight(tree, player, Vector2(-17, 36))
	await _check_east_bank(road, west_edge, west_step, deck_step)
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
	await _key(KEY_M)
	overview = road.region_map
	_expect(overview.modal.visible and overview.region == overview.Region.ROAD
		and overview.route_label.text == "溪桥道 → 封地 · 正在指路" and not overview.local_button.visible,
		"The bridge opens directly to the regional map and restores the saved return waypoint.")
	await _snapshot("04a-bridge-regions")
	await _button(overview.clear_button)
	_expect(state.market_trip_target.is_empty() and road.route_direction == Vector2.ZERO and tree.paused,
		"Clearing the trip on the bridge removes the arrows while the map stays open.")
	await _button(overview.region_buttons.get_node("WestMarket"))
	await _button(overview.destination_buttons["鱼摊"])
	await _button(overview.route_button)
	_expect(state.market_trip_target == "鱼摊" and road.route_direction == Vector2.LEFT and not tree.paused,
		"Change destination on the bridge and get the opposite exit.")
	await _key(KEY_M)
	await _button(overview.region_buttons.get_node("Estate"))
	await _button(overview.destination_buttons[state.MARKET_RETURN])
	await _button(overview.route_button)
	if await _cross(&"ui_right", state.ESTATE_SCENE):
		var world := tree.current_scene.get_node("World") as Node2D
		_expect(world.player.position.distance_to(world.get_node("WestMarketArrival").position) < 4.0
			and state.market_trip_target.is_empty(), "The return marker clears on reaching the estate.")
		await _snapshot("05-estate-returned")
	print("WEST_ROAD_RETURN save_side=market facing=east continued=", not failed)

func _distance_to_bank(foot: Vector2, rim: PackedVector2Array) -> float:
	var distance := INF
	for index in range(1, rim.size()):
		var nearest := Geometry2D.get_closest_point_to_segment(foot, rim[index - 1], rim[index])
		distance = minf(distance, foot.distance_to(nearest))
	return distance

func _last_step() -> String:
	var sample: AudioStream = AudioManager.terrain_audio.footsteps.stream
	return sample.resource_path.get_file() if sample else ""

func _check_east_bank(road: Node2D, west_edge: float, west_step: String, deck_step: String) -> void:
	var actor: Player = road.player
	await Campaign.walk_straight(tree, actor, Vector2(67, 36))
	var east_step := _last_step()
	_expect(road.ground.bridge_apron_at(actor.position) and east_step.begins_with("stone-"),
		"The east stone apron also stays walkable and plays a stone footstep.")
	await _snapshot("03b-east-apron")
	await _walk(actor, [Vector2(70, -70), Vector2(-82, -70)])
	var east_edge := _distance_to_bank(actor.position, road.ground.shelf_edges[1])
	var body := actor.get_node("CollisionShape2D") as CollisionShape2D
	var footprint := body.shape.get_rect().size.length() * 0.5 + actor.safe_margin
	_expect(not Geometry2D.is_point_in_polygon(actor.position, road.ground.water)
		and west_edge <= footprint and east_edge <= footprint and actor.position.x > -27.0,
		"Approaching from either bank stops within the actor's footprint of the painted rim.")
	_expect(not Geometry2D.triangulate_polygon(road.ground.exposed_water).is_empty()
		and not Geometry2D.triangulate_polygon(road.ground.deep_water).is_empty(),
		"The water remains continuous between the two faces.")
	await _snapshot("03c-east-bank-stop")
	print("WEST_ROAD_BANK_EDGES west_distance=", snappedf(west_edge, 0.01), " east_distance=", snappedf(east_edge, 0.01),
		" steps=", [west_step, deck_step, east_step], " window=", tree.root.size)
	await _walk(actor, [Vector2(70, -70), Vector2(70, 36), Vector2(-17, 36)])

func _check_creek_weather(world: Node2D) -> void:
	var rain := bank_check == "west-road-bank-rain"
	for day in range(1, 100):
		if (state.has_rain(day) if rain else state.season_index(day) == state.Season.WINTER):
			state.current_day = day
			break
	await Campaign.walk_estate_road_to(tree, world, Vector2(-270, -21))
	if not await _cross(&"ui_left", ROAD_SCENE):
		return
	var road: Node2D = tree.current_scene
	var deck: Node2D = road.get_node("CreekBridge")
	_expect(deck.wet == rain and (rain or deck.season == state.Season.WINTER), "The road enters the expected rain or winter state.")
	await Campaign.walk_straight(tree, road.player, Vector2(-17, 36))
	_expect(road.ground.LAYOUT.BRIDGE.has_point(road.player.position) and _last_step().begins_with("plank-"),
		"The bridge stays walkable with timber steps through seasonal weather.")
	await _snapshot("00-rain-creek" if rain else "00-frost-creek")
	print("WEST_ROAD_BANK_WEATHER day=", state.current_day, " rain=", rain, " season=", deck.season, " window=", tree.root.size)

func _continue_from_creek() -> void:
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	var road: Node2D = tree.current_scene
	if not _expect(road.scene_file_path == ROAD_SCENE and road.route_direction == Vector2.RIGHT
		and road.player.position.distance_to(road.get_node("MarketArrival").position) < 4.0,
		"The old bridge save restores the market-side arrival and the estate guide."):
		return
	await Campaign.walk_straight(tree, road.player, Vector2(-17, 36))
	await _snapshot("00-continued-creek")
	await Campaign.walk_straight(tree, road.player, Vector2(224, 36))
	if await _cross(&"ui_right", state.ESTATE_SCENE):
		_expect(state.market_trip_target.is_empty(), "The saved homeward guide clears on reaching the estate.")
		print("WEST_ROAD_BANK_RESUME day=", state.current_day, " reached=estate")

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
