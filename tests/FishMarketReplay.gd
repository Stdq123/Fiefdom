extends "res://tests/WestMarketReplay.gd"

var legacy := false
var capture_path := ""
var world: Node2D
var ui: CanvasLayer
var market: Node2D

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame

func _book() -> Control:
	await _button(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	management.show_market()
	await _button(management.market_panel.fish_book_button)
	return management.fish_ledger.market_offer

func _line(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = pressed
	tree.root.push_input(event, true)

func _catch_at(spot: Node2D, id: String, frame_name: String) -> bool:
	var stamina: int = state.current_stamina
	var held: int = state.fish_count(id)
	await _key(KEY_E)
	var panel := tree.current_scene.get_node_or_null("FishingUI/FishingPanel") as Control
	if not _expect(panel != null and panel.spot == spot and tree.paused, "Cast from the intended bank."):
		return false
	while panel.phase == panel.Phase.WAITING:
		await tree.process_frame
	_line(true)
	for frame in 360:
		await tree.process_frame
		if panel.phase != panel.Phase.REELING:
			break
		if panel.holding and panel.tension >= 0.64:
			_line(false)
		elif not panel.holding and panel.tension <= 0.43:
			_line(true)
	_line(false)
	var landed := _expect(state.fish_count(id) == held + 1 and panel.catch_icon.visible
		and state.current_stamina == stamina - state.balance.fishing_stamina_cost
		and state.last_forage_day == state.current_day, "Catch the intended fish and pay the normal casting cost.")
	if not frame_name.is_empty():
		_expect("渔生正在收这种鱼" in panel.detail.text, "The landed fish points to the current offer.")
		await _snapshot(frame_name)
	await _key(KEY_ESCAPE)
	return landed

func _fish_from_estate(site: CreekFish.Site, id: String, frame_name := "") -> bool:
	var shore: String = CreekFish.PLACES[site]
	await _walk(world.player, [Vector2(world.player.position.x, 63), Vector2(355, 63), Vector2(362, 6)])
	if not await _cross(&"ui_right", state.WILDERNESS_SCENE):
		return false
	var ravine := tree.current_scene as Node2D
	await tree.process_frame
	if not frame_name.is_empty():
		var guide := ravine.get_node("RavineDirections")
		_expect(guide.destination_name == shore and guide.route.size() >= 2, "The estate directions continue on the ravine map.")
	for enemy in tree.get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var angler := ravine.get_node("Player") as Player
	var spot := ravine.get_node("WillowPool" if site == CreekFish.Site.POOL else "GravelShoal") as Node2D
	if site == CreekFish.Site.SHOAL:
		await _walk(angler, [Vector2(110, 36), Vector2(202, 36), Vector2(238, 158)])
	else:
		await _walk(angler, [Vector2(99, -39)])
	if not await _catch_at(spot, id, frame_name):
		return false
	if site == CreekFish.Site.SHOAL:
		await _walk(angler, [Vector2(243, 119), Vector2(115, 119)])
	await _walk(angler, [Vector2(-160, 3)])
	if not await _cross(&"ui_left", state.ESTATE_SCENE):
		return false
	await _estate()
	return true

func _market_from_book() -> bool:
	var card := await _book()
	if not _expect(card.directions.text == "去西市交鱼" and not card.copper_button.visible,
		"The home ledger guides the player to the stall."):
		return false
	await _button(card.directions)
	_expect(ui.directions.tracked_place == "西市", "The western road is marked from the offer card.")
	await _walk(world.player, [Vector2(world.player.position.x, 62), Vector2(-181, 62), Vector2(-181, 0), Vector2(-270, -21)])
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return false
	market = tree.current_scene as Node2D
	return true

func _open_cart() -> bool:
	await _walk(market.player, [Vector2(-76, 40), Vector2(-77, 65)])
	await _key(KEY_E)
	return _expect(market.counter.visible and market.counter.orders.visible, "Open the seasonal orders at the cart.")

func _summer_trade() -> bool:
	if not await _open_cart():
		return false
	_expect("鱼摊留鱼单会缺鱼" in market.counter.orders.status.text and not market.counter.orders.food_button.disabled,
		"The last minnow can go to the seasonal order, which explains the trade-off.")
	await _snapshot("03-last-minnow-at-cart")
	await _key(KEY_ESCAPE)
	if not await _stall(market, "FishStall", ""):
		return false
	var card: Control = market.counter.fish.market_offer
	var offer: Dictionary = state.fish_market_offer()
	var money: int = state.money
	var food: int = state.food_storage
	_expect(card.tradeoff.visible and "柳湾夏鲜" in card.tradeoff.text and "13 铜钱" in card.copper_button.text and "5 份粮" in card.food_button.text
		and not market.fish_reserved, "The actual fish stall displays both prices and the competing request.")
	var panel: Control = market.counter.card
	_expect(tree.root.get_visible_rect().grow(-12.0).encloses(panel.get_global_rect()), "The fish counter has margins on all sides.")
	await _snapshot("04-fish-stall-offer")
	await _button(card.copper_button)
	_expect(state.money == money + offer.copper and state.food_storage == food and state.fish_count("minnow") == 0
		and state.fish_collection.minnow.first_day == 35 and not state.can_deliver_season_order(state.season_order())
		and "铜钱 +13" in card.status.text and market.fish_reserved and not card.copper_button.visible,
		"One delivery records the actual payout, updates the sign, and leaves the first-catch record.")
	print("FISH_MARKET_SUMMER day=", state.current_day, " copper=", state.money - money, " held=", state.fish_count("minnow"))
	await _snapshot("05-summer-receipt")
	await _key(KEY_ESCAPE)
	await _snapshot("06-stall-plaque")
	return true

func _continue_market() -> bool:
	await _button(market.get_node("UI/Control/Wallet/SettingsButton"))
	for button: Button in market.settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	if not _expect(market.settings.save_status.text == "游戏已保存", "Save the paid receipt in the market."):
		return false
	await _button(market.settings.close_button)
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.scene_file_path == state.WEST_MARKET_SCENE, "Continue at the market from the title."):
		return false
	market = tree.current_scene as Node2D
	if not await _stall(market, "FishStall", ""):
		return false
	_expect("铜钱 +13" in market.counter.fish.market_offer.status.text and market.fish_reserved
		and state.fish_count("minnow") == 0, "The counter and plaque show the saved delivery after Continue.")
	print("FISH_MARKET_CONTINUE receipt_day=", state.fish_order_receipt.day, " amount=", state.fish_order_receipt.amount)
	await _key(KEY_ESCAPE)
	await _walk(market.player, [Vector2(176, 34)])
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return false
	await _estate()
	return true

func _next_day() -> void:
	await _button(ui.sleep_button)
	await tree.create_timer(1.18).timeout

func _second_summer_fish() -> bool:
	await _next_day()
	if not _expect(state.current_day == 36, "Advance one night while the summer request is still settled."):
		return false
	if not await _fish_from_estate(CreekFish.Site.POOL, "minnow"):
		return false
	var offer: Dictionary = state.fish_market_offer()
	_expect(not state.deliver_fish_order(offer.start, true) and state.fish_count("minnow") == 1,
		"An extra fish is kept when the paid summer offer is submitted again.")
	await _button(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	management.show_season_orders()
	await _button(management.season_order_panel.food_button)
	var delivered: int = state.season_order_delivered_at(state.season_order())
	_expect(delivered == 36 and state.fish_count("minnow") == 0 and state.fish_order_receipt.day == 35,
		"The next minnow can fill the separate summer order with its own payout.")
	print("FISH_MARKET_SECOND day=", state.current_day, " seasonal_delivery=", delivered)
	await _button(management.get_node("CloseButton"))
	return true

func _autumn_trade() -> void:
	var old_start: int = state.fish_market_offer().start
	await _next_day()
	var offer: Dictionary = state.fish_market_offer()
	if not _expect(state.current_day == 37 and offer.fish == "perch" and offer.receipt.is_empty(), "The autumn watch has a fresh offer for a new species."):
		return
	var card := await _book()
	await _button(card.directions)
	if not await _fish_from_estate(CreekFish.Site.SHOAL, "perch", "07-shoal-perch"):
		return
	_expect(not state.deliver_fish_order(old_start, false) and state.fish_count("perch") == 1,
		"The summer quote cannot pay out after the season changes.")
	if not await _market_from_book() or not await _stall(market, "FishStall", ""):
		return
	card = market.counter.fish.market_offer
	var food: int = state.food_storage
	var money: int = state.money
	await _button(card.food_button)
	_expect(state.food_storage == food + offer.food and state.money == money and state.fish_count("perch") == 0
		and "粮食 +7" in card.status.text and state.fish_order_receipt.day == 37, "The new offer settles in food at the advertised rate.")
	print("FISH_MARKET_AUTUMN day=", state.current_day, " food=", state.food_storage - food)
	await _snapshot("08-autumn-receipt")

func _play() -> void:
	capture_dir = capture_path
	await _button(tree.current_scene.continue_button if legacy else tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if legacy:
		market = tree.current_scene as Node2D
		if not _expect(market.scene_file_path == state.WEST_MARKET_SCENE and state.current_day == 6
			and state.fish_count("carp") == 1 and state.fish_order_receipt.is_empty(), "Load the actual older save with its original fish stock."):
			return
		if await _stall(market, "FishStall", ""):
			var card: Control = market.counter.fish.market_offer
			_expect("鲤鱼" in card.title.text and "16 铜钱" in card.copper_button.text and not card.copper_button.disabled,
				"The old save can take the current season's offer from the counter.")
			print("FISH_MARKET_LEGACY day=", state.current_day, " carp=", state.fish_count("carp"))
		return
	await _estate()
	# Stage the second summer's order with rice already stored. All fish in this route are caught on the river.
	state.current_day = 35
	state.balance.raid_first_day = 1000
	state.talk_to_visitor(VisitorData.RAVINE_GUIDE)
	state.crop_stock.add("rice", 2)
	var card := await _book()
	if not _expect("白鲦" in card.title.text and "第 36 天截止" in card.status.text and card.directions.text == "去柳湾钓鱼",
		"The fish ledger shows the summer offer, deadline and a route to the right bank."):
		return
	await _snapshot("01-offer-before-departure")
	await _button(card.directions)
	if await _fish_from_estate(CreekFish.Site.POOL, "minnow", "02-willow-minnow") and await _market_from_book() \
			and await _summer_trade() and await _continue_market() and await _second_summer_fish():
		await _autumn_trade()
