extends "res://tests/FishMarketReplay.gd"

const FISH_STALL := "鱼摊"
const WILLOW := "柳湾"
const FISH := "minnow"

func _fixture() -> void:
	var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"current_day": 35, "location": "west_market", "food_storage": 10, "king_storage": 3, "legacy_order_start": 0,
		"player_inventory": 2, "crop_stock": {"rice": 2}, "visitor_encounters": ["蒲宁"],
		"well_fields": [{"center_pos": "5,5", "is_unlocked": true, "reclamation_progress": 4}],
		"active_crops": {"6,5": {"id": "hemp", "age": 0, "growth_nights": 3, "watered": true}},
	}))
	file.close()

func _continue() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await tree.process_frame

func _to_estate() -> bool:
	await _walk(market.player, [Vector2(176, 34)])
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return false
	await _estate()
	return true

func _to_ravine() -> bool:
	await _walk(world.player, [Vector2(-181, -21), Vector2(-181, 63), Vector2(355, 63), Vector2(362, 6)])
	return await _cross(&"ui_right", state.WILDERNESS_SCENE)

func _catch_willow() -> bool:
	var ravine := tree.current_scene as Node2D
	for enemy in tree.get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await _walk(ravine.get_node("Player"), [Vector2(99, -39)])
	return await _catch_at(ravine.get_node("WillowPool"), FISH, "", false)

func _save_and_continue(settings: Control) -> bool:
	var location: String = tree.current_scene.scene_file_path
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	if not _expect(settings.save_status.text == "游戏已保存", "Save the journey through the normal settings menu."):
		return false
	await _button(settings.close_button)
	await _continue()
	return _expect(tree.current_scene.scene_file_path == location, "Continue on the map where the route was saved.")

func _start_from_market() -> bool:
	if not await _open_cart():
		return false
	var orders: Control = market.counter.orders
	_expect("白鲦 缺 1 尾" in orders.status.text and orders.fish_route_button.text == "去柳湾钓白鲦",
		"The cart identifies the fish and offers the appropriate fishing spot.")
	await _snapshot("01-cart-departure")
	await _button(orders.fish_route_button)
	var chart: Control = market.market_map
	_expect(not market.counter.visible and state.ravine_trip_target == WILLOW and state.market_trip_target.is_empty()
		and "竹涧 · 柳湾" in chart.cancel_button.text
		and chart.pin.global_position.is_equal_approx(market.get_node("EstateRoad").global_position),
		"The order closes and marks the real exit from the western market.")
	if legacy:
		print("FISH_JOURNEY_OLD_SAVE day=", state.current_day, " rice=", state.crop_stock.count("rice"), " goal=", state.ravine_trip_target)
		return false
	await _button(chart.cancel_button)
	_expect(state.ravine_trip_target.is_empty() and state.market_trip_target.is_empty() and not chart.pin.visible,
		"Cancel removes the whole outbound route.")
	if not await _stall(market, "FishStall", ""):
		return false
	var offer: Control = market.counter.fish.market_offer
	_expect("白鲦" in offer.title.text and "13 铜钱" in offer.status.text and offer.directions.text == "去柳湾钓鱼",
		"The fish counter shows the quote and can start the same trip.")
	await _snapshot("02-fish-stall-departure")
	await _button(offer.directions)
	await _button(market.get_node("UI/Control/Wallet/SettingsButton"))
	if not await _save_and_continue(market.settings):
		return false
	market = tree.current_scene as Node2D
	chart = market.market_map
	_expect(state.ravine_trip_target == WILLOW and chart.pin.visible and "柳湾" in chart.cancel_button.text,
		"Continuing in the western market restores the first leg.")
	await _snapshot("03-west-market-route")
	print("FISH_JOURNEY_OUTBOUND day=", state.current_day, " goal=", state.ravine_trip_target)
	return not failed

func _choose_return() -> bool:
	if not await _to_estate():
		return false
	_expect(ui.directions.tracked_place == "竹涧 · 柳湾" and state.ravine_trip_target == WILLOW,
		"The first crossing carries the route to the estate's east gate.")
	await _snapshot("04-east-gate-route")
	if not await _to_ravine():
		return false
	await tree.process_frame
	var ravine := tree.current_scene as Node2D
	var guide := ravine.get_node("RavineDirections")
	_expect(guide.destination_name == WILLOW and guide.route.size() > 1,
		"The second crossing continues to the actual bank.")
	if not await _catch_willow():
		return false
	var result := ravine.get_node("FishingUI/FishingPanel") as Control
	var trail_hud := ravine.get_node("CampaignHUD")
	var fish := result.find_child("FishDelivery", true, false) as Button
	var orders := result.find_child("SeasonDelivery", true, false) as Button
	if not _expect(fish != null and orders != null and "这尾鱼也可交时令单" in result.detail.text
		and state.ravine_trip_target.is_empty() and not trail_hud.notice.visible,
		"The last fish has two routes, with the unlock notice held until the result closes."):
		return false
	await _snapshot("05-catch-choices")
	await _button(fish)
	var map: Control = ravine.ravine_map
	_expect(not tree.paused and trail_hud.notice.visible and state.market_trip_target == FISH_STALL and guide.destination_name == "西门回封地"
		and "西市 · 鱼摊" in map.cancel_button.text and state.fish_count(FISH) == 1,
		"Choosing the stall resumes play and guides to the west exit without trading the fish.")
	await _key(KEY_M)
	_expect(map.modal.visible and map.fish_delivery.visible and map.season_delivery.visible,
		"Both deliveries are still available in the trail chart after closing the fishing result.")
	await _snapshot("06-ravine-return-chart")
	await _button(map.clear_button)
	_expect(state.market_trip_target.is_empty() and guide.route.is_empty(), "Cancelling the return clears the market destination.")
	var gamepad = load("res://tests/GamepadReplay.gd").new()
	gamepad.tree = tree
	gamepad.pad = tree.root.get_node("GamepadInput")
	tree.root.notify_mouse_exited()
	await gamepad._click(map.season_delivery, true)
	_expect(gamepad.failures == 0, "The new chart action works with the gamepad cursor.")
	_expect(not map.modal.visible and not tree.paused and state.market_trip_target == state.MARKET_ORDERS
		and "西市 · 收货牌" in map.cancel_button.text, "The chart can restart the trip for the other destination.")
	await _walk(ravine.get_node("Player"), [Vector2(-160, 3)])
	if not await _cross(&"ui_left", state.ESTATE_SCENE):
		return false
	await _estate()
	_expect(ui.directions.tracked_place == "西市 · 收货牌", "The return route continues to the western gate.")
	await _button(ui.settings_button)
	if not await _save_and_continue(ui.panel_manager.settings_panel_instance):
		return false
	await _estate()
	_expect(ui.directions.tracked_place == "西市 · 收货牌" and state.fish_count(FISH) == 1
		and state.crop_stock.count("rice") == 2, "Continuing in the estate restores the return route and the cargo.")
	return not failed

func _deliver_to_cart() -> void:
	await _walk(world.player, [Vector2(world.player.position.x, 62), Vector2(-181, 62), Vector2(-181, 0), Vector2(-270, -21)])
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return
	await tree.process_frame
	await tree.process_frame
	market = tree.current_scene as Node2D
	var chart: Control = market.market_map
	_expect(chart.pin.visible and state.market_trip_target == state.MARKET_ORDERS and "收货牌" in chart.cancel_button.text,
		"The fourth crossing leads to the receiving board (pin=%s, target=%s, sign=%s)." % [
			chart.pin.visible, state.market_trip_target, chart.cancel_button.text])
	await _snapshot("07-back-in-market")
	if not await _open_cart():
		return
	var orders: Control = market.counter.orders
	var before: int = state.food_storage
	var schedule: Dictionary = state.season_order()
	var payout: int = state.season_order_rewards(schedule).food
	_expect(state.market_trip_target.is_empty() and "鱼摊留鱼单会缺鱼" in orders.status.text,
		"Opening the correct cart clears the waypoint and explains the single-fish trade-off.")
	await _button(orders.food_button)
	var crop: Dictionary = state.active_crops[Vector2i(6, 5)]
	_expect(state.food_storage == before + payout and state.fish_count(FISH) == 0 and state.crop_stock.count("rice") == 0
		and state.fish_market_offer().receipt.is_empty() and state.season_order_delivered_at(schedule) == 35
		and state.king_storage == 3 and crop.age == 0 and crop.watered and state.current_day == 35,
		"The real delivery settles once, without changing the day or the planted field.")
	await _snapshot("08-order-receipt")
	print("FISH_JOURNEY_DELIVERY day=", state.current_day, " food=", state.food_storage - before,
		" rice=", state.crop_stock.count("rice"), " fish=", state.fish_count(FISH))

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_FISH_JOURNEY_CAPTURES")
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated market profile."):
		tree.quit(1)
		return
	seed(917)
	if not legacy:
		_fixture()
	await _continue()
	market = tree.current_scene as Node2D
	if _expect(market.scene_file_path == state.WEST_MARKET_SCENE and state.current_day == 35
		and state.crop_stock.count("rice") == 2 and state.fish_count(FISH) == 0,
		"Resume the existing summer order from the market."):
		if await _start_from_market() and await _choose_return():
			await _deliver_to_cart()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
