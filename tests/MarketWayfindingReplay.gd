extends "res://tests/FishMarketReplay.gd"

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
	await _walk(market.player, [Vector2(0, 34), chart.places["鱼摊"]])
	_expect(state.market_trip_target == "鱼摊" and market.player.interaction_target == market.get_node("Stalls/FishStall"),
		"The guide lands at the open side of the actual counter and stays until interaction.")
	await _snapshot("04-fish-counter-approach")
	await _key(KEY_E)
	if not _expect(market.counter.fish.is_visible_in_tree() and state.market_trip_target.is_empty(),
		"Opening the selected counter clears directions."):
		return false
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
	await _walk(market.player, [Vector2(board.x, 34), board])
	await gamepad._tap(JOY_BUTTON_X)
	_expect(market.counter.orders.is_visible_in_tree() and state.market_trip_target.is_empty()
		and market.counter.close_button.text.ends_with("  B") and not market.counter.keeper_card.visible,
		"The controller opens the marked board with its own heading and return button.")
	await _snapshot("05-delivery-board")
	await gamepad._tap(JOY_BUTTON_B)
	_expect(not market.counter.visible, "B leaves the delivery board and returns to the street.")
	await _button(chart.open_button)
	await _button(chart.markers["回封地"])
	await _key(KEY_M)
	await _walk(market.player, [Vector2(board.x, 34), Vector2(176, 34)])
	if await _cross(&"ui_right", state.ESTATE_SCENE):
		await _estate()
		_expect(state.market_trip_target.is_empty() and ui.directions.tracked_place.is_empty()
			and state.fish_count("minnow") == 1, "Crossing the marked return gate completes the route and keeps the trade.")
		print("MARKET_WAYFINDING_RETURN day=", state.current_day, " fish_left=", state.fish_count("minnow"))
