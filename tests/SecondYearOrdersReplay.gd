extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const PLOTS := [Vector2i(4, 4), Vector2i(4, 5)]
const FIXTURE := "user://second-year-order-fixture.json"

var tree: SceneTree
var state: Node
var world: Node2D
var ui: CanvasLayer
var capture_dir := ""
var failed := false

func _expect(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		push_error(message)
	return ok

func _baseline() -> void:
	for day in [1, 7, 13, 19]:
		var first: Dictionary = state.season_order(day).order
		var second: Dictionary = state.season_order(day + 24).order
		_expect(first.id == second.id and first.need == second.need, "The older Windows build repeats the first year's recipe.")
		print("YEAR_ORDERS_BASELINE day=", day + 24, " title=", second.title, " need=", second.need)
	var legacy_dir := OS.get_environment("FIEFDOM_YEAR_LEGACY_EXPORT")
	if legacy_dir.is_empty():
		return
	state.start_new_game()
	await tree.scene_changed
	state.current_day = 36
	state.day_progress = 0.8
	state.crop_stock.add("rice", 2)
	state.pin_season_order(true)
	_expect(state.save_game() == OK, "Create an older checkpoint with a pinned second-year order.")
	_write(legacy_dir.path_join("unfinished-summer.json"), FileAccess.get_file_as_string(state.latest_saved_game().path))
	_expect(state.deliver_season_order(31, true) and state.save_game() == OK, "Create an older checkpoint with an accepted shipment.")
	_write(legacy_dir.path_join("loaded-summer-cart.json"), FileAccess.get_file_as_string(state.latest_saved_game().path))
	print("YEAR_ORDERS_LEGACY_CREATED day=36 order=summer dispatch=", state.season_order_receipts.summer.dispatch_day)

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _fixture(day: int, settings: Dictionary) -> bool:
	var save := {
		"save_version": 2, "current_day": day, "legacy_order_start": 0, "current_rank": 1,
		"money": 100, "food_storage": 30, "king_storage": 4, "reputation": 110,
		"well_fields": [
			{"field_id": 0, "center_pos": "5,5", "is_unlocked": true, "reclamation_progress": 4},
			{"field_id": 1, "center_pos": "9,5", "is_unlocked": true, "reclamation_progress": 4},
		],
	}
	save.merge(settings, true)
	_write(FIXTURE, JSON.stringify(save))
	if not _expect(state.load_game(FIXTURE) == OK, "Load the prepared estate for day %d." % day):
		return false
	await tree.scene_changed
	_estate()
	await tree.process_frame
	return true

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")

func _button(button: Button) -> void:
	await tree.process_frame
	var bounds := button.get_global_rect()
	if _expect(button.is_visible_in_tree() and not button.disabled
		and tree.root.get_visible_rect().encloses(bounds), "Use the visible button " + button.text):
		await _click(bounds.get_center())

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	tree.root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		tree.root.push_input(event, true)
		await tree.process_frame

func _key_event(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	tree.root.push_input(event, true)

func _key(code: Key) -> void:
	_key_event(code, true)
	await tree.process_frame
	_key_event(code, false)
	await tree.process_frame

func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var shot := tree.root.get_texture().get_image()
	_expect(shot.save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)
	print("YEAR_ORDERS_FRAME ", name, " window=", tree.root.size, " image=", shot.get_size())

func _night() -> void:
	await _button(ui.sleep_button)
	await tree.create_timer(1.15).timeout

func _plot(cell: Vector2i) -> void:
	var tiles: TileMapLayer = world.tile_map
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))

func _plant_pair(seed: Key) -> int:
	await _key(seed)
	for cell: Vector2i in PLOTS:
		await _plot(cell)
		await _plot(cell)
		if world.is_crop_dry(cell):
			await _plot(cell)
	return int(state.active_crops[PLOTS[0]].growth_nights)

func _manage() -> Control:
	await _button(ui.manage_button)
	return ui.panel_manager.management_panel_instance

func _orders() -> Control:
	var panel := await _manage()
	panel.show_season_orders()
	await tree.process_frame
	return panel.season_order_panel

func _close_management() -> void:
	await _button(ui.panel_manager.management_panel_instance.get_node("CloseButton"))

func _catalog() -> void:
	var titles := ["南路续种", "柳湾夏鲜", "东岗换防", "岁末麦帛"]
	var crops := [{"beans": 2, "millet": 2, "wheat": 1}, {"rice": 2},
		{"sorghum": 2, "beans": 1, "hemp": 1}, {"wheat": 2}]
	for season in titles.size():
		var day := 1 + season * 6
		var first: Dictionary = state.season_order(day).order
		var second: Dictionary = state.season_order(day + 24).order
		_expect(first.id != second.id and second.title == titles[season] and second.need == crops[season],
			"A later season has its own commission and crops.")
		print("YEAR_ORDERS_SCHEDULE day=", day + 24, " title=", second.title, " crops=", second.need,
			" fish=", second.get("fish", ""), " silk=", second.get("silk", 0))
	_expect(SeasonOrders.window(48, 2).order.id == "winter"
		and SeasonOrders.window(49, 2).order.id == "spring_seed_share", "The change follows the configured calendar length.")

func _spring() -> void:
	if not await _fixture(24, {"food_storage": 0, "player_inventory": 4, "crop_stock": {"millet": 2, "beans": 2},
		"night_rations": {"enabled": true, "copper_limit": 0},
		"active_crops": {"4,4": {"id": "wheat", "age": 2, "growth_nights": 2},
			"4,5": {"id": "wheat", "age": 2, "growth_nights": 2}}}):
		return
	for cell: Vector2i in PLOTS:
		await _plot(cell)
	var book := await _orders()
	_expect("冬路粮与麻" in book.order_title.text and "南路续种" in book.next_details.text and "麦 1" in book.next_details.text,
		"The first winter previews keeping wheat for the next spring.")
	await _capture("01-next-spring")
	await _close_management()
	await _night()
	_expect(state.current_day == 25 and state.crop_stock.count("wheat") == 1 and state.night_rations.last.used.get("wheat") == 1,
		"At year rollover the household eats the surplus wheat and keeps one for the order.")
	book = await _orders()
	_expect("南路续种" in book.order_title.text and "领 7 口粮" in book.food_button.text,
		"The harvest is sufficient for the follow-up spring shipment.")
	await _button(book.food_button)
	_expect(state.food_storage == 7 and state.player_inventory == 0 and state.king_storage == 4,
		"Only the listed private crops go to the order and the treasury is intact.")
	print("YEAR_ORDERS_SPRING day=", state.current_day, " ration_wheat=", state.night_rations.last.used.wheat,
		" reward=", state.food_storage)
	await _close_management()

func _walk(actor: Node2D, stops: Array) -> void:
	for point: Vector2 in stops:
		await Campaign.walk_to(tree, actor, point)

func _cross(action: StringName, path: String) -> bool:
	Input.action_press(action)
	for frame in 52:
		await tree.physics_frame
		if tree.root.get_node("MapTravel").active:
			break
	Input.action_release(action)
	await Campaign.wait_for_map_change(tree)
	await tree.process_frame
	return _expect(tree.current_scene.scene_file_path == path, "Walk through the road to " + path)

func _catch_minnow() -> bool:
	var trail := tree.current_scene as Node2D
	var spot := trail.get_node("WillowPool") as Node2D
	var directions: Node2D = trail.get_node("RavineDirections")
	var map: Control = trail.get_node("CampaignHUD").view.get_node("RavineMap")
	_expect(directions.destination_name == "柳湾" and directions.destination == spot.position,
		"The order's route resumes at the actual willow pool after entering through the east gate.")
	await _button(map.open_button)
	_expect("白鲦" in map.route_status.text and "5 体力" in map.route_status.text,
		"The trail map gives the same catch and cost as the forecast.")
	await _capture("02b-willow-route")
	await _key(KEY_ESCAPE)
	await Campaign.walk_ravine_to(tree, trail, spot.global_position + Vector2(0, 12))
	_expect(state.ravine_trip_target.is_empty(), "The trip is complete once the fishing spot is in reach.")
	var stamina: int = state.current_stamina
	await _key(KEY_E)
	var panel: Control = trail.get_node_or_null("FishingUI/FishingPanel")
	if not _expect(panel != null and tree.paused, "Cast at the actual willow pool."):
		return false
	for frame in 230:
		if panel.phase != panel.Phase.WAITING:
			break
		await tree.process_frame
	if not _expect(panel.phase == panel.Phase.BITE, "Wait for the summer fish to bite."):
		return false
	_key_event(KEY_SPACE, true)
	for frame in 350:
		await tree.process_frame
		if panel.phase != panel.Phase.REELING:
			break
		if panel.holding and panel.tension >= 0.64:
			_key_event(KEY_SPACE, false)
		elif not panel.holding and panel.tension <= 0.43:
			_key_event(KEY_SPACE, true)
	_key_event(KEY_SPACE, false)
	var landed := _expect(panel.phase == panel.Phase.DONE and panel.catch_icon.visible
		and state.fish_count("minnow") == 1 and state.last_forage_day == state.current_day
		and state.current_stamina == stamina - state.balance.fishing_stamina_cost,
		"Land one minnow using the fishing controls.")
	await _capture("03-willow-catch")
	await _key(KEY_ESCAPE)
	await _button(map.open_button)
	_expect("今日已有外出收获" in map.markers["野果坳"].tooltip_text
		and "今日已有外出收获" in map.markers["望溪台"].tooltip_text,
		"The catch consumes the single outing for both kinds of gathering.")
	await _key(KEY_ESCAPE)
	await Campaign.walk_to_ravine_exit(tree, trail)
	return landed and await _cross(&"ui_left", state.ESTATE_SCENE)

func _summer() -> void:
	if not await _fixture(31, {"tech_unlocked": {"irrigation": true}, "irrigation_channels": ["2,5", "3,5", "3,4"],
		"visitor_encounters": [VisitorData.RAVINE_GUIDE], "visitor_talk_days": {VisitorData.RAVINE_GUIDE: 28}}):
		return
	var nights := await _plant_pair(KEY_3)
	for night in nights:
		await _night()
	for cell: Vector2i in PLOTS:
		await _plot(cell)
	if not _expect(state.crop_stock.count("rice") == 2, "Grow two irrigated private rice crops."):
		return
	var chart: Control = ui.estate_map
	await _button(ui.hud.map_button)
	await _button(chart.tabs.get_node("Ravine"))
	var details := {}
	for entry: Dictionary in chart.row_buttons.values():
		details[entry.title] = entry.detail
	_expect("白鲦" in details.get("柳湾", "") and "鲤鱼" in details.get("砾滩", ""),
		"The estate chart compares today's species at both fishing spots.")
	await _capture("02a-ravine-forecast")
	await _key(KEY_ESCAPE)
	var book := await _orders()
	_expect("柳湾夏鲜" in book.order_title.text and "白鲦 缺 1 尾" in book.status.text and "柳湾" in book.status.text
		and "东岗换防" in book.next_details.text and "麻 1" in book.next_details.text and book.food_button.disabled,
		"The book names the fishing place and previews autumn's hemp.")
	_expect(not state.deliver_season_order(31, true) and state.crop_stock.count("rice") == 2,
		"An incomplete mixed order leaves the harvested rice in stock.")
	await _capture("02-summer-needs-fish")
	await _button(book.pin_button)
	await _button(book.fish_route_button)
	_expect(state.ravine_trip_target == "柳湾" and ui.directions.tracked_place == "竹涧 · 柳湾"
		and not ui.panel_manager.management_panel_instance.visible, "The summer order starts the east gate route.")
	await _walk(world.player, [Vector2(66, 36), Vector2(360, 4)])
	if not await _cross(&"ui_right", state.WILDERNESS_SCENE) or not await _catch_minnow():
		return
	_estate()
	_expect("白鲦 1/1" in ui.hud.pinned_order.text and "去西市交货" in ui.hud.pinned_order.text,
		"The pinned entry updates for the fish, as well as for rice.")
	await _walk(world.player, [Vector2(360, 36), Vector2(66, 36), Vector2(66, 60), Vector2(-181, 60), Vector2(-181, 0), Vector2(-270, -21)])
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return
	var market := tree.current_scene as Node2D
	await Campaign.walk_market_to(tree, market, market.market_map.places["收货牌"])
	await _key(KEY_E)
	book = market.counter.orders
	var food: int = state.food_storage
	var catch_day: int = state.fish_collection.minnow.first_day
	if not _expect(book.is_visible_in_tree() and "领 7 口粮" in book.food_button.text, "Open the mixed order at the actual west cart."):
		return
	await _button(book.food_button)
	var freight: SeasonFreight = market.get_node("Freight")
	_expect(state.food_storage == food + 7 and state.crop_stock.count("rice") == 0 and state.fish_count("minnow") == 0
		and state.fish_collection.minnow.first_day == catch_day and state.king_storage == 4
		and freight.shown_order == "summer_willow_catch" and freight.cargo.get_child_count() == 2,
		"The real dispatch takes both ingredients and retains the fish's first-catch record.")
	await _capture("04-summer-receipt")
	print("YEAR_ORDERS_SUMMER day=", state.current_day, " catch_day=", catch_day, " reward=", state.food_storage - food)
	await _key(KEY_ESCAPE)
	if not _expect(state.save_game() == OK, "Save the mixed shipment at the west market."):
		return
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.scene_file_path == state.WEST_MARKET_SCENE
		and state.season_order_delivered_at(state.season_order()) == catch_day
		and not state.deliver_season_order(31, false), "Continue at the market and prevent a second reward."):
		return
	await _follow_summer_shipment()

func _follow_summer_shipment() -> void:
	var arrival := SeasonOrders.EVENING_DISPATCH + SeasonOrders.TRAVEL_FRACTION + 0.01
	state.advance_daylight((arrival - state.day_progress) * state.balance.daylight_seconds)
	var market := tree.current_scene as Node2D
	await Campaign.walk_to_market_exit(tree, market)
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return
	_estate()
	await Campaign.walk_estate_road_to(tree, world, EstateLayout.FREIGHT_APPROACH)
	var cart := world.get_node("Freight") as SeasonFreight
	_expect(cart.arrived and cart.shown_order == "summer_willow_catch" and cart.cargo.get_child_count() == 2,
		"The mixed load reaches the pavilion on the ordinary cart route after reload.")
	await _key(KEY_E)
	var dialog: Control = ui.get_node_or_null("Control/DialoguePanel")
	if _expect(dialog != null and dialog.name_label.text == "申禾" and "白鲦" in dialog.text_label.text and "下游" in dialog.text_label.text,
		"The driver explains who received the rice and fish."):
		await _capture("05-summer-pavilion")
		await _button(dialog.options_container.get_child(1))

func _autumn() -> void:
	if not await _fixture(37, {"player_inventory": 4, "crop_stock": {"sorghum": 2, "beans": 1, "hemp": 1}}):
		return
	var book := await _orders()
	var copper: int = state.money
	_expect("东岗换防" in book.order_title.text and book.cargo.get_child_count() == 3 and "领 26 铜钱" in book.copper_button.text,
		"The autumn book shows all three lots and the patrol's reward.")
	await _button(book.copper_button)
	_expect(state.player_inventory == 0 and state.money == copper + 26 and state.king_storage == 4,
		"The patrol receives its three kinds of private stock.")
	print("YEAR_ORDERS_AUTUMN day=", state.current_day, " reward=", state.money - copper)
	await _close_management()

func _silk_page() -> Control:
	var panel := await _manage()
	var workshop: Control = panel.tabs.get_node("蚕桑")
	panel.tabs.current_tab = panel.tabs.get_tab_idx_from_control(workshop)
	await tree.process_frame
	return workshop

func _winter() -> void:
	if not await _fixture(43, {"silk_workshop": {"built": true, "leaves": 4}}):
		return
	var book := await _orders()
	_expect("岁末麦帛" in book.order_title.text and "丝绸 缺 1 匹" in book.status.text
		and "蚕棚" in book.status.text, "The winter order shows the workshop requirement.")
	await _close_management()
	var nights := await _plant_pair(KEY_4)
	var workshop := await _silk_page()
	await _button(workshop.buttons[SilkWorkshop.Action.START_BATCH])
	await _close_management()
	for night in maxi(nights, state.balance.silk_batch_nights):
		for cell: Vector2i in PLOTS:
			if world.is_crop_dry(cell):
				await _plot(cell)
		await _night()
	for cell: Vector2i in PLOTS:
		await _plot(cell)
	workshop = await _silk_page()
	await _button(workshop.buttons[SilkWorkshop.Action.REEL])
	await _button(workshop.buttons[SilkWorkshop.Action.REEL])
	await _button(workshop.buttons[SilkWorkshop.Action.WEAVE])
	await _close_management()
	var before: int = state.money
	book = await _orders()
	_expect(state.crop_stock.count("wheat") == 2 and state.silk_workshop.bolts == 1 and "领 51 铜钱" in book.copper_button.text,
		"Growing wheat and weaving a bolt produce the complete winter shipment.")
	await _capture("06-winter-wheat-and-silk")
	await _button(book.copper_button)
	_expect(state.money == before + 51 and state.silk_workshop.bolts == 0 and state.crop_stock.count("wheat") == 0
		and state.silk_bolts_offered == 0 and state.silk_bolts_sold == 0 and state.king_storage == 4,
		"The commission settles both goods once and leaves the council's dedicated silk milestones intact.")
	print("YEAR_ORDERS_WINTER day=", state.current_day, " reward=", state.money - before, " silk=", state.silk_workshop.bolts)
	await _close_management()

func _legacy() -> void:
	var source := OS.get_environment("FIEFDOM_YEAR_LEGACY_EXPORT")
	var open_order := {"current_day": 36, "day_progress": 0.8, "pinned_season_start": 31, "player_inventory": 2,
		"crop_stock": {"rice": 2}, "food_storage": 20, "king_storage": 4}
	var loaded_cart := {"current_day": 36, "day_progress": 0.8, "food_storage": 24, "king_storage": 4,
		"season_order_receipts": {"summer": {"day": 36, "dispatch_day": 37, "paid_in_food": true}}}
	for name in ["unfinished-summer", "loaded-summer-cart"]:
		var record := JSON.stringify(open_order if name == "unfinished-summer" else loaded_cart) if source.is_empty() else (
			FileAccess.get_file_as_string(source.path_join(name + ".json")))
		_write(FIXTURE, record)
		if not _expect(state.load_game(FIXTURE) == OK, "Continue a previous version's second-year order."):
			return
		await tree.scene_changed
		_estate()
		var schedule: Dictionary = state.season_order()
		_expect(schedule.order.id == "summer" and not schedule.order.has("fish"),
			"The current old window honors the old crop request.")
		if name == "unfinished-summer":
			if not _expect(state.save_game() == OK and state.load_game() == OK, "Save the open order again in the updated game."):
				return
			await tree.scene_changed
			_estate()
			schedule = state.season_order()
			_expect(schedule.order.id == "summer", "The updated checkpoint retains the inherited request for this season.")
			_expect(state.is_season_order_pinned(schedule) and state.can_deliver_season_order(schedule)
				and state.deliver_season_order(31, false), "A pinned old request can still be completed with its original recipe.")
		else:
			_expect(state.season_order_delivered_at(schedule) == 36 and not state.deliver_season_order(31, false),
				"The old shipped receipt cannot pay twice.")
		await _night()
		var cart := world.get_node("Freight") as SeasonFreight
		_expect(state.season_order().order.id == "autumn_watch_relief" and cart.previous_lot.order.id == "summer",
			"The next season uses its new order and the pending cart still carries the original shipment.")
	print("YEAR_ORDERS_LEGACY day=", state.current_day, " next=", state.season_order().order.id,
		" previous_package=", not source.is_empty())

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated season order profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_YEAR_CAPTURES")
	tree.root.notify_mouse_entered()
	seed(2543)
	if not state.has_method("season_order_stock"):
		await _baseline()
	else:
		state.balance.raid_first_day = 10000
		_catalog()
		await _spring()
		if not failed:
			await _summer()
		if not failed:
			await _autumn()
		if not failed:
			await _winter()
		if not failed and DisplayServer.get_name() == "headless":
			await _legacy()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
