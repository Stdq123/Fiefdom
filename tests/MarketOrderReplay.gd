extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const BEANS := [Vector2i(4, 4), Vector2i(4, 5), Vector2i(5, 4)]
const MILLET := [Vector2i(4, 6), Vector2i(5, 5), Vector2i(6, 5)]
const CART_APPROACH := Vector2(-65, 70)

var tree: SceneTree
var state: Node
var capture_dir := ""
var failed := false

func _expect(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		push_error(message)
	return ok

func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame

func _button(button: Button) -> void:
	await tree.process_frame
	if _expect(button.is_visible_in_tree() and not button.disabled
			and tree.root.get_visible_rect().encloses(button.get_global_rect()), "Use the visible control " + button.text):
		await _click(button.get_global_rect().get_center())

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)
	await tree.process_frame

func _snapshot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await tree.create_timer(0.24).timeout
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Save the frame " + name)
	print("ORDER_FRAME ", name, " window=", tree.root.size, " image=", image.get_size())

func _cross(actor: Player, waypoints: Array, action: StringName, path: String) -> bool:
	for at: Vector2 in waypoints:
		await Campaign.walk_to(tree, actor, at)
	Input.action_press(action)
	for frame in 48:
		await tree.physics_frame
		if tree.root.get_node("MapTravel").active:
			break
	Input.action_release(action)
	await Campaign.wait_for_map_change(tree)
	return _expect(tree.current_scene.scene_file_path == path, "Walk through the road to " + path)

func _to_market() -> bool:
	var actor := tree.current_scene.get_node("World/Player") as Player
	return await _cross(actor, [Vector2(-181, 54), Vector2(-181, 0), Vector2(-270, -21)],
		&"ui_left", state.WEST_MARKET_SCENE)

func _to_estate() -> bool:
	var actor := tree.current_scene.get_node("Player") as Player
	return await _cross(actor, [Vector2(176, 34)], &"ui_right", state.ESTATE_SCENE)

func _open_cart() -> bool:
	var market := tree.current_scene as Node2D
	await Campaign.walk_to(tree, market.player, CART_APPROACH)
	await _key(KEY_E)
	return _expect(market.counter.orders.is_visible_in_tree() and market.player.conversation_open,
		"The cart opens the order book on foot at %s." % market.player.position)

func _continue(expected_scene: String) -> bool:
	if not _expect(state.save_game() == OK, "Save the current order checkpoint."):
		return false
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	await tree.process_frame
	return _expect(tree.current_scene.scene_file_path == expected_scene, "Continue restores " + expected_scene)

func _plot(tiles: TileMapLayer, cell: Vector2i) -> void:
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))

func _grow_and_harvest() -> bool:
	var estate := tree.current_scene
	var world := estate.get_node("World") as Node2D
	var ui := estate.get_node("UI") as CanvasLayer
	var tiles := world.tile_map as TileMapLayer
	var tracked: Button = ui.hud.pinned_order
	if not _expect(tracked.is_visible_in_tree() and "菽 0/2" in tracked.text and "第 6 天" in tracked.text,
		"The spring pin survives a title continue and shows what to grow."):
		return false
	var plots := BEANS + MILLET
	var harvest_day := 1
	for crop in [{"key": KEY_5, "id": "beans", "cells": BEANS}, {"key": KEY_1, "id": "millet", "cells": MILLET}]:
		await _key(crop.key)
		for cell: Vector2i in crop.cells:
			await _plot(tiles, cell)
			await _plot(tiles, cell)
		harvest_day = maxi(harvest_day, state.current_day + state.sowing_nights(ItemManager.get_crop(crop.id)))
	await _snapshot("02-tracker-at-farm")
	for night in range(1, harvest_day):
		for cell: Vector2i in plots:
			if world.is_crop_dry(cell):
				await _plot(tiles, cell)
		await _button(ui.sleep_button)
		await tree.create_timer(1.12).timeout
	await _button(tracked)
	var management: Control = ui.panel_manager.management_panel_instance
	var book: Control = management.season_order_panel
	_expect(book.is_visible_in_tree() and "私田有 3 格已熟" in book.status.text,
		"The book distinguishes ripe private beans from stock already in the warehouse.")
	await _button(management.get_node("CloseButton"))
	for cell: Vector2i in plots:
		await _plot(tiles, cell)
	_expect(state.crop_stock.count("beans") == 3 and state.crop_stock.count("millet") == 2 and state.king_storage == 1,
		"The order and the meal use real private harvests, with one public unit in the treasury.")
	_expect("去西市交货" in tracked.text, "The tracker turns into a delivery direction after harvest.")
	await _button(tracked)
	return _expect(ui.directions.tracked_place == "西市 · 收货牌" and state.market_trip_target == "收货牌",
		"The delivery button points through the west gate to the order board.")

func _deliver() -> void:
	var market := tree.current_scene as Node2D
	var book: Control = market.counter.orders
	var freight := market.get_node("Freight") as SeasonFreight
	var before_grain: int = state.food_storage
	var before_money: int = state.money
	var reward: int = state.season_order_rewards(state.season_order()).food
	await _button(book.food_button)
	_expect(freight.cargo.visible and "酉时发车" in book.status.text and state.food_storage == before_grain + reward
		and state.money == before_money and state.player_inventory == 2 and state.king_storage == 1,
		"The cart loads the delivery, advertises its departure and pays the chosen reward.")
	await _snapshot("03-delivery-receipt")
	await _key(KEY_ESCAPE)
	await _snapshot("04-loaded-cart")
	if not await _continue(state.WEST_MARKET_SCENE):
		return
	market = tree.current_scene
	_expect(market.get_node("Freight/Cargo").visible and not state.is_season_order_pinned(state.season_order())
		and state.food_storage == before_grain + reward, "Continue shows the loaded cart and settled reward.")
	await _freight_to_pavilion()

func _set_watch(progress: float) -> void:
	state.advance_daylight((progress - state.day_progress) * state.balance.daylight_seconds)
	await tree.process_frame
	await tree.process_frame

func _freight_to_pavilion() -> void:
	var market_cart := tree.current_scene.get_node("Freight") as SeasonFreight
	await _set_watch(SeasonOrders.EVENING_DISPATCH + 0.02)
	_expect(market_cart.travelling and market_cart.driver.walking and market_cart.route_offset > 0.0,
		"The driver and loaded cart move along the market road at the advertised watch.")
	await _snapshot("05-market-departure")
	if await _to_estate():
		var estate := tree.current_scene
		_expect(estate.get_node("World/SeasonBoard").delivered and not estate.get_node("UI").hud.pinned_order.visible,
			"The pavilion uses the same receipt and the farm tracker clears.")
		var market_length := SeasonFreight.market_road.get_baked_length()
		var route_length := market_length + SeasonFreight.estate_road.get_baked_length()
		await _set_watch(SeasonOrders.EVENING_DISPATCH + SeasonOrders.TRAVEL_FRACTION * (market_length + 115.0) / route_length)
		var cart := estate.get_node("World/Freight") as SeasonFreight
		_expect(cart.travelling and cart.cargo.is_visible_in_tree(), "The same load enters the estate by the west road.")
		await _snapshot("06-estate-road")
		var checkpoint := cart.route_offset
		if not await _continue(state.ESTATE_SCENE):
			return
		estate = tree.current_scene
		cart = estate.get_node("World/Freight") as SeasonFreight
		_expect(cart.travelling and absf(cart.route_offset - checkpoint) < 12.0,
			"Resuming mid-trip keeps the cart at the same place on the road.")
		await Campaign.walk_to(tree, estate.get_node("World/Player"), Vector2(111, 313))
		await _set_watch(SeasonOrders.EVENING_DISPATCH + SeasonOrders.TRAVEL_FRACTION + 0.01)
		_expect(cart.arrived and cart.position.is_equal_approx(SeasonFreight.PAVILION_STOP),
			"The cart stops at South Pavilion.")
		await _key(KEY_E)
		var dialog := estate.get_node("UI/Control/DialoguePanel") as Control
		_expect(dialog.name_label.text == "申禾" and "来亭里就能领种" in dialog.text_label.text,
			"The driver describes where the spring seed is going.")
		await _snapshot("07-south-pavilion")
		print("ORDER_DELIVERED day=", state.current_day, " grain_reward=", state.season_order_rewards(state.season_order()).food,
			" tribute=", state.king_storage)
		await _button(dialog.options_container.get_child(0))
		_expect(estate.get_node("UI").directions.tracked_place == "南路灶台", "The driver can point to the new hearth.")
		await _meal_from_harvest()

func _open_hearth(approach: Array, frame := "") -> Control:
	var estate := tree.current_scene
	var actor := estate.get_node("World/Player") as Player
	for point: Vector2 in approach:
		await Campaign.walk_to(tree, actor, point)
	await Campaign.walk_to(tree, actor, Vector2(218, 337))
	_expect(estate.get_node("UI").directions.tracked_place != "南路灶台", "The stove's direction label clears at the front step.")
	if not frame.is_empty():
		await _snapshot(frame)
	await _key(KEY_E)
	return estate.get_node_or_null("UI/Control/DialoguePanel") as Control

func _meal_from_harvest() -> void:
	var estate := tree.current_scene
	var hearth := estate.get_node("World/TravelHearth")
	var dialogue := await _open_hearth([Vector2(111, 333)], "08-lit-hearth")
	if not _expect(hearth.get_node("Glow").enabled and dialogue != null and dialogue.name_label.text == "南路灶台",
		"The first order lights the accessible hearth east of the pavilion."):
		return
	var grain := dialogue.options_container.get_child(0) as Button
	var fish := dialogue.options_container.get_child(1) as Button
	_expect(not grain.disabled and fish.disabled and "菽 1/1、黍 1/1" in dialogue.text_label.text,
		"The menu uses the harvested leftovers and identifies the missing fish and rice.")
	await _snapshot("09-hearth-recipes")
	await _button(grain)
	_expect(state.travel_meal == TravelMeal.BEAN_MILLET and state.player_inventory == 0 and state.king_storage == 1,
		"The meal costs exactly one bean and one millet, separate from the public harvest.")
	if not await _continue(state.ESTATE_SCENE):
		return
	estate = tree.current_scene
	var actor := estate.get_node("World/Player") as Player
	_expect(actor.meal_button.is_visible_in_tree() and "菽黍饭" in actor.meal_button.text,
		"The carried meal survives the title continue.")
	await _button(estate.get_node("UI").sleep_button)
	await tree.create_timer(1.12).timeout
	var grain_stock: int = state.food_storage
	await _key(KEY_F)
	_expect(state.current_day == 4 and state.travel_meal == TravelMeal.BEAN_MILLET and state.current_stamina == state.max_stamina,
		"The meal survives the night and remains packed when stamina is full.")
	await _plot(estate.get_node("World").tile_map, BEANS[0])
	var stamina_before: int = state.current_stamina
	await _snapshot("10-carried-meal")
	await _key(KEY_F)
	_expect(state.travel_meal.is_empty() and not actor.meal_button.visible and stamina_before < state.max_stamina
		and state.current_stamina == state.max_stamina and state.food_storage == grain_stock,
		"The shortcut consumes the meal once, restores stamina up to the cap, and leaves the granary intact.")
	print("MEAL_HARVEST day=", state.current_day, " restored=", state.current_stamina - stamina_before)

func _fish_meal_on_trail() -> void:
	var path := "user://fish-meal.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"current_day": 7, "day_progress": 0.23,
		"health": 55, "current_stamina": 47, "player_inventory": 1, "crop_stock": {"rice": 1},
		"season_order_receipts": {"spring": {"day": 3, "paid_in_food": true, "dispatch_day": 3}},
		"fish_collection": {"crucian": {"first_day": 5, "first_site": 0, "stock": 1},
			"carp": {"first_day": 6, "first_site": 0, "stock": 1}}}))
	file.close()
	if not _expect(state.load_game(path) == OK, "Load a prepared checkpoint with rice and two caught fish."):
		return
	await tree.scene_changed
	var dialogue := await _open_hearth([Vector2(35, 158), Vector2(44, 290), Vector2(56, 333)])
	if not _expect(dialogue != null and dialogue.name_label.text == "南路灶台" and "鲫鱼 1/1" in dialogue.text_label.text,
		"The summer hearth is still open and names the actual fish being used."):
		return
	await _button(dialogue.options_container.get_child(1))
	_expect(state.travel_meal == TravelMeal.RICE_FISH and state.fish_count("crucian") == 0 and state.fish_count("carp") == 1
		and state.fish_collection["crucian"].first_day == 5 and state.crop_stock.count("rice") == 0,
		"Soup uses one rice and the fish shown on the menu, retaining the first-catch record.")
	var actor := tree.current_scene.get_node("World/Player") as Player
	if not await _cross(actor, [Vector2(319, 333), Vector2(354, 6)], &"ui_right", state.WILDERNESS_SCENE):
		return
	actor = tree.current_scene.get_node("Player") as Player
	var before := Vector2i(state.current_stamina, state.health)
	var benefits := TravelMeal.benefits(TravelMeal.RICE_FISH, state.balance)
	await _snapshot("11-soup-at-ravine")
	await _button(actor.meal_button)
	_expect(state.travel_meal.is_empty() and state.current_stamina == before.x + benefits.x and state.health == before.y + benefits.y,
		"The meal crosses the East Gate and its HUD button restores both stamina and health.")
	print("MEAL_RAVINE stamina=", state.current_stamina, " health=", state.health, " carp_left=", state.fish_count("carp"))

func _late_delivery() -> void:
	var path := "user://late-freight.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"current_day": 6, "day_progress": 0.84, "location": "west_market",
		"player_inventory": 3, "crop_stock": {"beans": 2, "millet": 1}}))
	file.close()
	if not _expect(state.load_game(path) == OK, "Load the late spring checkpoint."):
		return
	await tree.scene_changed
	_expect(state.deliver_season_order(1, true) and state.season_order_receipts["spring"].dispatch_day == 7,
		"A late delivery schedules the next morning, even on the last day of the season.")
	state.begin_next_day()
	if not await _continue(state.WEST_MARKET_SCENE):
		return
	var cart := tree.current_scene.get_node("Freight") as SeasonFreight
	_expect(cart.cargo.visible and cart.shown_order == "spring" and state.season_order().order.id == "summer",
		"The spring load remains at the market under the new summer order.")
	await _set_watch(SeasonOrders.MORNING_DISPATCH + 0.01)
	_expect(cart.travelling and cart.shown_order == "spring", "Yesterday's cargo departs at the next morning watch.")
	print("ORDER_LATE day=", state.current_day, " cargo=", cart.shown_order, " offset=", snappedf(cart.route_offset, 0.1))

func _legacy_receipt(path: String) -> void:
	if not _expect(state.load_game(path) == OK, "Load the spring receipt saved by the previous Windows build."):
		return
	await tree.scene_changed
	var receipt: Dictionary = state.season_order_receipts["spring"]
	var cart := tree.current_scene.get_node("Freight") as SeasonFreight
	_expect(receipt.dispatch_day == receipt.day and receipt.paid_in_food and cart.cargo.visible,
		"A receipt without a dispatch field still loads as a paid, waiting spring shipment.")
	_expect(state.travel_hearth_open() and state.travel_meal.is_empty(), "The old receipt opens the hearth with an empty meal slot.")
	print("ORDER_LEGACY_RECEIPT day=", receipt.day, " dispatch=", receipt.dispatch_day, " grain=", state.food_storage)

func _play() -> void:
	await _button(tree.current_scene.new_button)
	_expect(not state.travel_hearth_open() and not tree.current_scene.get_node("World/TravelHearth/Glow").enabled,
		"The hearth is unlit before a first order.")
	if not await _to_market() or not await _open_cart():
		return
	var market := tree.current_scene as Node2D
	var book: Control = market.counter.orders
	var bean_day: int = state.current_day + state.sowing_nights(ItemManager.get_crop("beans"))
	_expect("菽 缺 2 份" in book.status.text and ("第 %d 天收" % bean_day) in book.status.text
		and "稻须接通水渠" in book.next_details.text, "The first order shows actual growing time and the next order's irrigation need.")
	await _button(book.pin_button)
	await _snapshot("01-order-plan")
	await _key(KEY_ESCAPE)
	if not await _to_estate() or not await _continue(state.ESTATE_SCENE) or not await _grow_and_harvest():
		return
	if await _to_market() and await _open_cart():
		await _deliver()

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_ORDER_CAPTURES")
	tree.root.notify_mouse_entered()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _play()
	if not failed:
		await _fish_meal_on_trail()
	var previous_save := OS.get_environment("FIEFDOM_LEGACY_ORDER_SAVE")
	if not failed and not previous_save.is_empty():
		await _legacy_receipt(previous_save)
	if not failed and DisplayServer.get_name() == "headless":
		await _late_delivery()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
