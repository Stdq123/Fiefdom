extends "res://tests/FishMarketReplay.gd"

const ROAD_LAYOUT := preload("res://scripts/WestRoadLayout.gd")

var chart: Control
var from_older_save := false

func _play() -> void:
	capture_dir = capture_path
	if from_older_save:
		await _continue_old_market()
		return
	seed(672)
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await _estate()
	# Put the summer order within reach so this replay can focus on navigation.
	state.current_day = 35
	state.balance.raid_first_day = 1000
	state.talk_to_visitor(VisitorData.RAVINE_GUIDE)
	state.crop_stock.add("rice", 2)
	state._store_creek_fish("minnow", CreekFish.Site.POOL, 2)
	var offer := await _book()
	await _button(offer.directions)
	var expected := "西市" if legacy else "西市 · 鱼摊"
	if not _expect(ui.directions.tracked_place == expected, "The fish ledger marks the western road for the errand."):
		return
	await _snapshot("01-estate-fish-directions")
	if not legacy:
		await _button(ui.settings_button)
		if not await _save_continue(ui.panel_manager.settings_panel_instance):
			return
		await _estate()
		_expect(state.market_trip_target == "鱼摊" and ui.directions.tracked_place == expected,
			"Continue at the estate restores the errand and the west-gate cue.")
	await _walk(world.player, [Vector2(-181, 54), Vector2(-181, 0), Vector2(-270, -21)])
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return
	market = tree.current_scene
	chart = market.get_node_or_null("UI/Control/WestMarketMap")
	await tree.create_timer(0.05).timeout
	print("MARKET_WAYFINDING_ARRIVAL chart=", chart != null, " estate_cue=", expected,
		" market_cue=", state.market_trip_target if chart else "")
	if legacy:
		await _key(KEY_M)
		_expect(chart == null and not tree.paused and not market.settings.visible,
			"The old market has no chart or handoff after crossing.")
		await _snapshot("02-old-market-arrival")
		await _button(market.get_node("UI/Control/Wallet/SettingsButton"))
		await _save(market.settings)
		return
	if not _expect(chart != null and chart.cancel_button.visible and state.market_trip_target == "鱼摊",
		"The west-gate errand continues at the actual fish stall on entry."):
		return
	_expect(chart.cancel_button.text.begins_with("←") and chart.route.has(Vector2(-38, 61))
		and chart.route[-1].is_equal_approx(chart.places["鱼摊"]),
		"The route starts along the main street and turns into the fish lane.")
	await _snapshot("02-market-arrival")
	await _key(KEY_M)
	if not _expect(chart.modal.visible and tree.paused and chart.markers["鱼摊"].button_pressed and _chart_fits(),
		"M opens the chart with the current stall selected and every marker visible."):
		return
	var time: float = state.day_progress
	var foot: Vector2 = market.player.position
	await tree.create_timer(0.26).timeout
	_expect(state.day_progress == time and market.player.position == foot, "Studying the chart pauses time and movement.")
	await _snapshot("03-market-chart")
	await _button(chart.markers["绸摊"])
	_expect(state.market_trip_target == "绸摊", "Select a different stall on the chart.")
	await _button(chart.clear_button)
	_expect(state.market_trip_target.is_empty(), "Clear directions on the chart.")
	await _button(chart.markers["鱼摊"])
	await _key(KEY_ESCAPE)
	_expect(not tree.paused and not market.settings.visible and chart.cancel_button.visible, "Escape returns to the market street.")
	await _button(market.get_node("UI/Control/Wallet/SettingsButton"))
	if not await _save_continue(market.settings):
		return
	market = tree.current_scene
	chart = market.get_node("UI/Control/WestMarketMap")
	await tree.create_timer(0.05).timeout
	_expect(state.market_trip_target == "鱼摊" and chart.cancel_button.visible,
		"Continue in the market restores the selected stall from the eastern entrance.")
	if not await _trade_at_fish_stall():
		return
	await _follow_to_cart_and_home()

func _continue_old_market() -> void:
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.scene_file_path == state.WEST_MARKET_SCENE and state.fish_count("minnow") == 2,
		"Continue the previous build's market save with its original fish stock."):
		return
	chart = tree.current_scene.get_node("UI/Control/WestMarketMap")
	await _key(KEY_M)
	_expect(chart.modal.visible and state.market_trip_target.is_empty() and chart.clear_button.disabled,
		"A market save created before wayfinding starts with no selected destination.")
	await _key(KEY_ESCAPE)
	print("MARKET_WAYFINDING_OLD_SAVE day=", state.current_day, " fish=", state.fish_count("minnow"))

func _chart_fits() -> bool:
	var panel: Control = chart.modal.get_node("Center/Panel")
	if not tree.root.get_visible_rect().grow(-10.0).encloses(panel.get_global_rect()):
		return false
	var buttons: Array[Rect2] = []
	for marker: Button in chart.markers.values():
		var bounds := marker.get_global_rect()
		if not marker.visible or not chart.chart.get_global_rect().encloses(bounds):
			return false
		for previous in buttons:
			if previous.intersects(bounds):
				return false
		buttons.append(bounds)
	return buttons.size() == 5

func _save(settings: Control) -> bool:
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	return _expect(settings.save_status.text == "游戏已保存", "Save via the visible settings panel.")

func _save_continue(settings: Control) -> bool:
	var location: String = tree.current_scene.scene_file_path
	if not await _save(settings):
		return false
	await _button(settings.close_button)
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	return _expect(tree.current_scene.scene_file_path == location and state.fish_count("minnow") == 2,
		"Continue preserves the save location and the fish awaiting delivery.")

func _trade_at_fish_stall() -> bool:
	var approach := [Vector2(273, 36), Vector2(206, 57), Vector2(134, 76), Vector2(48, 74), Vector2(-38, 61),
		Vector2(-41, 18), Vector2(-61, -32), Vector2(-96, -70), Vector2(-161, -112)]
	var walked := 0.0
	var start_time: float = state.day_progress
	for point: Vector2 in approach:
		walked += market.player.position.distance_to(point)
		await Campaign.walk_straight(tree, market.player, point)
		_expect(market.player.position.distance_to(point) < 3.0 and market.ground.is_on_street(market.player.position),
			"Walk through the paved turns and up the fish lane.")
	var seconds: float = (state.day_progress - start_time) * state.balance.daylight_seconds
	_expect(walked > 540.0 and seconds > 5.0 and market.player.position.distance_to(chart.places["鱼摊"]) < 3.0,
		"The fish counter is a distinct walk from the eastern gate at normal speed.")
	print("MARKET_FISH_WALK distance=", roundi(walked), " seconds=", snappedf(seconds, 0.01))
	_expect(state.market_trip_target == "鱼摊" and market.player.interaction_target == market.get_node("Stalls/FishStall"),
		"The guide lands at the open side of the actual counter and stays until interaction.")
	await _snapshot("04-fish-counter-approach")
	await _key(KEY_E)
	if not _expect(market.counter.fish.is_visible_in_tree() and state.market_trip_target.is_empty(),
		"Opening the selected counter clears directions."):
		return false
	await tree.create_timer(0.05).timeout
	_expect(not market.get_node("CampaignHUD").field_return_button.visible, "The counter hides the return button.")
	_expect("只要一尾" in market.counter.keeper_note.text, "The fish keeper explains the seasonal order before the trade.")
	await _key(KEY_M)
	_expect(not chart.modal.visible and not tree.paused, "The chart stays closed during a transaction.")
	var copper: int = state.money
	await _button(market.counter.fish.market_offer.copper_button)
	_expect(state.money == copper + 13 and state.fish_count("minnow") == 1 and "收好了" in market.counter.keeper_note.text,
		"The fish keeper acknowledges receipt as the advertised trade settles.")
	print("MARKET_WAYFINDING_TRADE copper=", state.money - copper, " fish_left=", state.fish_count("minnow"))
	await _key(KEY_ESCAPE)
	return not failed

func _follow_to_cart_and_home() -> void:
	var gamepad = load("res://tests/GamepadReplay.gd").new()
	gamepad.tree = tree
	gamepad.pad = tree.root.get_node("GamepadInput")
	# The inherited replay had already notified the viewport for synthetic mouse input.
	tree.root.notify_mouse_exited()
	await gamepad._tap(JOY_BUTTON_Y)
	_expect(chart.modal.visible and tree.paused and chart.open_button.text.ends_with("Y"), "The gamepad's map button opens the market chart.")
	await gamepad._click(chart.markers["收货牌"], true)
	await gamepad._tap(JOY_BUTTON_B)
	_expect(not chart.modal.visible and not tree.paused and state.market_trip_target == "收货牌", "B returns to the chosen delivery errand.")
	var board: Vector2 = chart.places["收货牌"]
	await Campaign.walk_market_to(tree, market, board)
	await gamepad._tap(JOY_BUTTON_X)
	_expect(market.counter.orders.is_visible_in_tree() and state.market_trip_target.is_empty()
		and market.counter.close_button.text.ends_with("  B") and not market.counter.keeper_card.visible,
		"The controller opens the marked board with its own heading and return button.")
	await _snapshot("05-delivery-board")
	await gamepad._tap(JOY_BUTTON_B)
	_expect(not market.counter.visible, "B leaves the delivery board and returns to the street.")
	var hud := market.get_node("CampaignHUD")
	var return_button: Button = hud.field_return_button
	var area := return_button.get_global_rect()
	_expect(not area.intersects(chart.open_button.get_global_rect()) and not area.intersects(hud.backpack_button.get_global_rect()),
		"The new button fits beside the other street controls.")
	await gamepad._click(return_button)
	if not _expect(state.market_trip_target == state.FIELD_RETURN and chart.pin.visible
		and "井田 1" in chart.cancel_button.text and chart.route[-1] == chart.places[state.MARKET_RETURN],
		"The gamepad starts the return and the first leg leads to the market's eastern gate."):
		return
	await _snapshot("return-market-east-gate")
	await Campaign.walk_to_market_exit(tree, market)
	if not await _cross(&"ui_right", state.WEST_ROAD_SCENE):
		return
	await _bridge_and_continue()

func _bridge_and_continue() -> void:
	var road := tree.current_scene as Node2D
	await tree.process_frame
	if not _expect(state.market_trip_target == state.FIELD_RETURN and road.route_direction == Vector2.RIGHT
		and not road.route.is_empty() and road.route[-1] == ROAD_LAYOUT.ESTATE_GATE,
		"Follow the marked road across the creek toward the estate."):
		return
	await _key(KEY_M)
	var overview: Control = road.region_map
	_expect(overview.route_label.text == "溪桥道 → 封地 → 井田 1 · 正在指路", "The regional map shows the field as the saved destination.")
	await _button(overview.clear_button)
	_expect(road.route.is_empty() and tree.paused, "Clearing the route on the bridge drops its gold trail.")
	await _key(KEY_M)
	await _button(road.get_node("CampaignHUD").field_return_button)
	await _button(road.get_node("%SettingsButton"))
	await _button(road.settings.save_button)
	var saved: Dictionary = state.latest_saved_game()
	if not _expect(road.settings.save_status.text.begins_with("游戏已保存 · 续档时从溪桥道")
		and saved.get("location") == "溪桥道", "Save the return trip in the bridge settings."):
		return
	var day: int = state.current_day
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	road = tree.current_scene
	await tree.process_frame
	if not _expect(road.scene_file_path == state.WEST_ROAD_SCENE and state.market_trip_target == state.FIELD_RETURN
		and not road.route.is_empty() and road.route[-1] == ROAD_LAYOUT.ESTATE_GATE,
		"Continuing from the title restores the bridge leg of the return trip."):
		return
	await _snapshot("return-market-bridge-resume")
	var path: PackedVector2Array = road.network.route_between(road.player.position, road.get_node("EstateArrival").position)
	for point in path.slice(1):
		await Campaign.walk_straight(tree, road.player, road.to_global(point))
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return
	await _estate()
	await tree.create_timer(0.05).timeout
	path = ui.directions.road_path
	var entrance: Vector2 = world.get_node("Landscape").field_approaches[0][-1]
	if not _expect(state.market_trip_target == state.FIELD_RETURN and not path.is_empty() and path[-1] == entrance,
		"The field waypoint survives both crossings and appears on the estate's roads."):
		return
	for point in path.slice(1):
		await Campaign.walk_straight(tree, world.player, world.to_global(point))
	_expect(world.player.position.distance_to(entrance) < 4.0 and state.market_trip_target.is_empty()
		and state.current_day == day and state.fish_count("minnow") == 1, "Arrive at the field and keep the day's fish trade.")
	print("MARKET_WAYFINDING_RETURN day=", state.current_day, " fish_left=", state.fish_count("minnow"), " entrance=", entrance)
