extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const BEANS := [Vector2i(4, 4), Vector2i(4, 5), Vector2i(5, 4)]
const MILLET := [Vector2i(4, 6), Vector2i(5, 5), Vector2i(6, 5)]
const RICE := [Vector2i(4, 5), Vector2i(4, 6)]
const RICE_CANAL := [Vector2i(2, 5), Vector2i(3, 5), Vector2i(3, 6)]

var tree: SceneTree
var state: Node
var capture_dir := ""
var failed := false
var summer := false
var waiting_shipment := false

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

func _key_state(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	tree.root.push_input(event, true)

func _key(code: Key) -> void:
	_key_state(code, true)
	_key_state(code, false)
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
	return _expect(await Campaign.walk_through_gates(tree, action, path), "Walk through the road to " + path)

func _to_market() -> bool:
	var actor := tree.current_scene.get_node("World/Player") as Player
	return await _cross(actor, [Vector2(-181, 54), Vector2(-181, 0), Vector2(-270, -21)],
		&"ui_left", state.WEST_MARKET_SCENE)

func _to_estate() -> bool:
	var market := tree.current_scene
	await Campaign.walk_to_market_exit(tree, market)
	return await _cross(market.player, [], &"ui_right", state.ESTATE_SCENE)

func _open_cart() -> bool:
	var market := tree.current_scene as Node2D
	await Campaign.walk_market_to(tree, market, market.market_map.places["收货牌"])
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
	var beans := [Vector2i(5, 4), Vector2i(6, 4), Vector2i(6, 6)] if summer else BEANS
	var millet := [Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 5)] if summer else MILLET
	var plots := beans + millet
	var harvest_day := 1
	for crop in [{"key": KEY_5, "id": "beans", "cells": beans}, {"key": KEY_1, "id": "millet", "cells": millet}]:
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
		if night == harvest_day - 1:
			await _button(tracked)
			var preview: Control = ui.panel_manager.management_panel_instance
			_expect(preview.season_order_panel.is_visible_in_tree() and "3 格明日熟" in preview.season_order_panel.status.text,
				"The order distinguishes watered crops that can ripen overnight.")
			await _snapshot("02a-tomorrow-harvest")
			await _button(preview.close_button)
		if summer:
			await _button(ui.manage_button)
			var study: Control = ui.panel_manager.management_panel_instance
			await _button(study.section_buttons[2])
			await _button(study.read_button)
			await _button(study.close_button)
		await _button(ui.sleep_button)
		await tree.create_timer(1.12).timeout
	_expect("收备货私田" in tracked.text and state.player_inventory == 0,
		"Ripe private crops become an action without counting as stock.")
	await _snapshot("02b-harvest-ready")
	await _button(tracked)
	var first: Variant = ui.directions.tracked_plot
	_expect(first in plots and not state.is_public_plot(first) and ui.directions.destination().title.contains("备货"),
		"The tracker marks the first relevant private crop, even with a ripe public plot nearby.")
	if failed:
		return false
	await _snapshot("02c-harvest-directions")
	if not await _continue(state.ESTATE_SCENE):
		return false
	estate = tree.current_scene
	world = estate.get_node("World")
	ui = estate.get_node("UI")
	tiles = world.tile_map
	tracked = ui.hud.pinned_order
	await tree.process_frame
	var harvested := 0
	while ui.directions.tracked_plot != null and harvested < 3:
		var cell: Vector2i = ui.directions.tracked_plot
		_expect(not state.is_public_plot(cell), "Order directions do not switch to tribute.")
		await _plot(tiles, cell)
		await tree.process_frame
		harvested += 1
	_expect(harvested == 3 and ui.directions.tracked_plot == null and "去西市交货" in tracked.text
		and state.king_storage == 0 and state.player_inventory == 3,
		"The saved route advances through three needed private plots, then offers delivery.")
	for cell: Vector2i in plots:
		if world.is_crop_ripe(cell):
			await _plot(tiles, cell)
	_expect(state.crop_stock.count("beans") == 3 and state.crop_stock.count("millet") == 2 and state.king_storage == 1,
		"The order and the meal use real private harvests, with one public unit in the treasury.")
	_expect("去西市交货" in tracked.text, "The tracker turns into a delivery direction after harvest.")
	print("ORDER_HARVEST day=", state.current_day, " needed_private=", harvested, " tribute_after_other_plots=", state.king_storage)
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
	if summer:
		await _summer_handoff(book)
		return
	if not _expect(book.freight_route.is_visible_in_tree() and "预计第 3 天戌时到南路卸货场" in book.status.text,
		"The paid receipt quotes the cart arrival and provides directions."):
		return
	await _button(book.freight_route)
	await tree.process_frame
	_expect(not market.counter.visible and state.market_trip_target == state.FREIGHT_YARD
		and state.FREIGHT_YARD in market.market_map.cancel_button.text,
		"The receipt's action starts an eastbound route without changing the booked trade.")
	await _snapshot("04-loaded-cart")
	if not await _continue(state.WEST_MARKET_SCENE):
		return
	market = tree.current_scene
	_expect(market.get_node("Freight/Cargo").visible and not state.is_season_order_pinned(state.season_order())
		and state.food_storage == before_grain + reward and state.market_trip_target == state.FREIGHT_YARD
		and state.FREIGHT_YARD in market.market_map.cancel_button.text,
		"Continue restores the loaded cart, settled reward and return route.")
	if waiting_shipment:
		await _try_freight_bench()
	else:
		await _freight_to_pavilion()

func _walk_to_bench() -> Player:
	var world: Node2D = tree.current_scene.get_node("World")
	var player: Player = world.player
	await Campaign.walk_estate_road_to(tree, world, EstateLayout.FREIGHT_APPROACH)
	if player.position.distance_to(EstateLayout.FREIGHT_APPROACH) > 4.0:
		await Campaign.walk_straight(tree, player, EstateLayout.FREIGHT_APPROACH)
	return player

func _open_bench() -> Control:
	await _key(KEY_E)
	var dialog := tree.current_scene.get_node_or_null("UI/Control/DialoguePanel") as Control
	return dialog if _expect(dialog != null and dialog.name_label.text == "候货座", "Interact with the bench at the unloading yard.") else null

func _tap_pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await tree.process_frame
	await tree.process_frame

func _try_freight_bench() -> void:
	if not await _to_estate():
		return
	var player := await _walk_to_bench()
	var world: Node2D = tree.current_scene.get_node("World")
	var ui: CanvasLayer = tree.current_scene.get_node("UI")
	var wagon := world.get_node("Freight") as SeasonFreight
	var wait_panel: Control = ui.freight_wait
	var receipt: Dictionary = state.pending_freight_receipt().duplicate(true)
	var arrival := SeasonOrders.arrival_progress(receipt)
	var natural: float = (arrival - state.day_progress) * state.balance.daylight_seconds
	if not _expect(natural > 12.0 and ui.directions.destination().title == state.FREIGHT_YARD,
			"Walk from the market receipt to the bench before the first cart arrives."):
		return
	var dialog := await _open_bench()
	if dialog == null:
		return
	_expect("第 3 天戌时" in dialog.text_label.text and dialog.choices.size() == 2,
		"The bench advertises the same watch and offers a choice.")
	print("FREIGHT_WAIT_BASE day=", state.current_day, " clock=", snappedf(state.day_progress, 0.0001),
		" remaining_seconds=", snappedf(natural, 0.01))
	await _snapshot("06-bench-options")
	await _key(KEY_ESCAPE)
	var resources := Vector4i(state.current_day, state.king_storage, state.player_inventory, state.food_storage)
	var money: int = state.money
	var stamina: int = state.current_stamina
	var before: float = state.day_progress
	await _tap_pad(JOY_BUTTON_X)
	dialog = ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialog != null and dialog.name_label.text == "候货座", "Use the gamepad to reopen the bench."):
		return
	await _tap_pad(JOY_BUTTON_DPAD_LEFT)
	await _tap_pad(JOY_BUTTON_A)
	await tree.create_timer(0.38).timeout
	_expect(wait_panel.visible and wait_panel.stand.text.ends_with("B") and player.resting and player.seated
		and not wagon.arrived and state.day_progress > before,
		"A short sit advances the same day's visible clock.")
	await _tap_pad(JOY_BUTTON_B)
	_expect(not wait_panel.visible and not player.resting and not player.seated and state.day_progress < arrival
		and state.market_trip_target == state.FREIGHT_YARD, "Standing up leaves the shipment on its way and keeps directions.")
	var stopped: float = state.day_progress
	if not await _continue(state.ESTATE_SCENE):
		return
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	wagon = world.get_node("Freight") as SeasonFreight
	wait_panel = ui.freight_wait
	player = world.player
	_expect(not wait_panel.visible and not player.resting and state.day_progress - stopped < 0.01
		and state.pending_freight_receipt() == receipt and state.market_trip_target == state.FREIGHT_YARD,
		"Continue restores the clock and receipt after standing up.")
	await _walk_to_bench()
	var resumed_remaining: float = (arrival - state.day_progress) * state.balance.daylight_seconds
	dialog = await _open_bench()
	if dialog == null:
		return
	await _button(dialog.choices[0])
	var wait_started := Engine.get_process_frames()
	await _snapshot("07-waiting-for-wagon")
	var wait_seconds := 0.0
	var saw_approach := false
	var saw_walking := false
	while wait_panel.visible and wait_seconds < 6.0:
		saw_approach = saw_approach or ("赶车过来" in wait_panel.status.text and wagon.travelling)
		saw_walking = saw_walking or (wagon.travelling and wagon.driver.walking)
		await tree.create_timer(0.05).timeout
		wait_seconds += 0.05
	await tree.physics_frame
	var sat_seconds := float(Engine.get_process_frames() - wait_started) / 60.0
	_expect(not wait_panel.visible and not player.resting and wagon.arrived and saw_approach and saw_walking
		and sat_seconds <= 5.0 and sat_seconds < resumed_remaining and state.day_progress - arrival < 0.004
		and state.seed_garden_day() == 0 and state.day_watch_label() == "戌时",
		"Waiting ends at this wagon's normal arrival with the final approach and the seed relay still to come.")
	_expect(resources == Vector4i(state.current_day, state.king_storage, state.player_inventory, state.food_storage)
		and state.money == money and state.current_stamina == stamina and state.pending_freight_receipt() == receipt,
		"Waiting spends no stock, stamina, or money and does not settle an overnight.")
	await _key(KEY_E)
	dialog = ui.get_node_or_null("Control/DialoguePanel") as Control
	if _expect(dialog != null and dialog.name_label.text == "申禾" and state.market_trip_target.is_empty(),
			"Talk to the arriving driver from the usual approach and clear the route."):
		await _snapshot("08-talk-to-the-driver")
		await _key(KEY_ESCAPE)
	print("FREIGHT_WAIT_DONE day=", state.current_day, " remaining_before_sit=", snappedf(resumed_remaining, 0.01),
		" sat_seconds=", snappedf(sat_seconds, 0.01),
		" resumed_clock=", snappedf(stopped, 0.0001))

func _summer_handoff(book: Control) -> void:
	var market := tree.current_scene as Node2D
	var stock: int = state.food_storage
	await _button(book.next_water_button)
	_expect(not market.counter.visible and state.market_trip_target == state.WATER_SOURCE
		and state.pinned_season_start == 7 and "水源" in market.market_map.cancel_button.text,
		"The delivered spring order leads from the market to the estate spring and tracks summer.")
	await _snapshot("04-spring-route-from-market")
	if not await _continue(state.WEST_MARKET_SCENE):
		return
	market = tree.current_scene
	_expect(state.pinned_season_start == 7 and state.food_storage == stock
		and "水源" in market.market_map.cancel_button.text, "Continue restores both the summer order and the return route.")
	await Campaign.walk_to_market_exit(tree, market)
	if not await _cross(market.player, [], &"ui_right", state.WEST_ROAD_SCENE):
		return
	var road := tree.current_scene
	_expect("水源 →" in road.get_node("%Route").text, "The bridge sends the player east to the spring.")
	await _snapshot("05-spring-route-on-bridge")
	if not await _cross(road.player, [], &"ui_right", state.ESTATE_SCENE):
		return
	var estate := tree.current_scene
	var world: Node2D = estate.get_node("World")
	var ui: CanvasLayer = estate.get_node("UI")
	var spring: Node2D = world.irrigation_overlay.water_source
	var approach := spring.global_position + Vector2(-9, 12)
	_expect(ui.directions.tracked_place == state.WATER_SOURCE and ui.hud.pinned_order.visible,
		"The estate continues the same route to the actual spring.")
	await Campaign.walk_estate_road_to(tree, world, approach)
	await _key(KEY_E)
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialog != null and dialog.name_label.text == state.WATER_SOURCE and state.market_trip_target.is_empty(),
		"Inspecting the spring completes the route."):
		return
	_expect(dialog.choices[0].text == "去研读", "Players who arrive early can start the existing study path.")
	await _snapshot("06-reading-for-summer")
	await _button(dialog.choices[0])
	var panel: Control = ui.panel_manager.management_panel_instance
	await _button(panel.read_button)
	await _button(panel.close_button)
	for day in range(4, 8):
		await _button(ui.sleep_button)
		await tree.create_timer(1.12).timeout
		_expect(state.current_day == day, "Sleep advances toward the summer delivery window.")
		if state.player_stats.get_level(PlayerStats.Art.LITERACY) < Irrigation.UNLOCK_LITERACY_LEVEL:
			await _button(ui.manage_button)
			await _button(panel.section_buttons[2])
			await _button(panel.read_button)
			await _button(panel.close_button)
	# The campaign and watch-relief replays cover raids. Keep this one focused on the order and irrigation.
	state.balance.raid_first_day = 10000

	await _button(ui.hud.pinned_order)
	var summer_book: Control = panel.season_order_panel
	_expect(summer_book.is_visible_in_tree() and summer_book.water_route_button.visible,
		"The summer order still points to water while the plots are dry.")
	await _button(summer_book.water_route_button)
	await Campaign.walk_to(tree, world.player, approach)
	await _key(KEY_E)
	dialog = ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialog != null and dialog.choices[0].text == "打开科技",
		"Daily reading and ordinary farm work reach the existing irrigation technology."):
		return
	await _button(dialog.choices[0])
	await _button(panel.irrigation_button)
	await _button(panel.close_button)
	await _key(KEY_E)
	dialog = ui.get_node_or_null("Control/DialoguePanel") as Control
	var price: int = RICE_CANAL.size() * state.channel_cost()
	if not _expect(dialog != null and dialog.choices[0].text == "标出备稻渠线"
		and "再给 2 格私田供水" in dialog.text_label.text and ("共需 %d 铜钱" % price) in dialog.text_label.text,
		"The spring quotes the three cells and their coverage."):
		return
	await _snapshot("07-rice-ditch-price")
	var copper: int = state.money
	await _button(dialog.choices[0])
	var canal: Array[Vector2i] = world.irrigation_overlay.starter_canal
	var plots: Array[Vector2i] = world.irrigation_overlay.rice_plot_highlight
	_expect(canal.size() == RICE_CANAL.size() and RICE_CANAL.all(func(cell: Vector2i) -> bool: return canal.has(cell))
		and plots.size() == RICE.size() and RICE.all(func(cell: Vector2i) -> bool: return plots.has(cell)),
		"The spring marks the actual ditch and private plots. Ditch %s, plots %s." % [canal, plots])
	await _snapshot("08-rice-ditch-plan")
	var tiles: TileMapLayer = world.tile_map
	for cell: Vector2i in RICE_CANAL:
		await _plot(tiles, cell)
	await _key(KEY_ESCAPE)
	_expect(state.money == copper - price and state.irrigation.supplies(RICE[0]) and state.irrigation.supplies(RICE[1])
		and not state.irrigation.supplies(Vector2i(5, 5)) and world.current_seed_id == "rice",
		"The three digs charge the listed cost and select rice for the two supplied private plots.")
	await _snapshot("09-two-plots-supplied")
	for cell: Vector2i in RICE:
		if not state.tilled_cells.has(cell):
			await _plot(tiles, cell)
		await _plot(tiles, cell)
	var harvest_day: int = state.current_day + state.sowing_nights(ItemManager.get_crop("rice"))
	for day in range(state.current_day, harvest_day):
		await _button(ui.sleep_button)
		await tree.create_timer(1.12).timeout
	for cell: Vector2i in RICE:
		await _plot(tiles, cell)
	_expect(state.crop_stock.count("rice") == 2 and state.king_storage == 1 and "去西市交货" in ui.hud.pinned_order.text,
		"Rice grown in the marked plots fills the tracked order and leaves the public tribute in the treasury.")
	await _button(ui.hud.pinned_order)
	if not await _to_market() or not await _open_cart():
		return
	book = tree.current_scene.counter.orders
	await _button(book.food_button)
	_expect(state.season_order_delivered_at(state.season_order()) == harvest_day and state.crop_stock.count("rice") == 0
		and state.pond_landing_day() == 0, "The summer delivery takes the two home-grown portions. The landing waits for the shipment.")
	print("SUMMER_RICE_DELIVERED day=", harvest_day, " canal_cost=", price, " public=", state.king_storage)
	await _snapshot("10-summer-delivery")
	await _key(KEY_ESCAPE)
	market = tree.current_scene
	await Campaign.walk_market_to(tree, market, market.market_map.places[MarketStall.TITLES[MarketStall.Kind.GRAIN]])
	await _key(KEY_E)
	await _button(market.counter.market_produce)
	_expect(state.crop_stock.count("rice") == 1, "The summer grain stall supplies a separate serving for the meal.")
	await _pond_after_delivery()

func _pond_after_delivery() -> void:
	await _key(KEY_ESCAPE)
	if not await _to_estate():
		return
	var estate := tree.current_scene
	var world: Node2D = estate.get_node("World")
	var ui: CanvasLayer = estate.get_node("UI")
	var landing: Node2D = world.get_node("Scenery/PondLanding")
	var cart := world.get_node("Freight") as SeasonFreight
	_expect(not landing.visible, "The landing stays closed on the way back before the freight arrives.")
	await _set_watch(SeasonOrders.EVENING_DISPATCH + SeasonOrders.TRAVEL_FRACTION + 0.01)
	await Campaign.walk_estate_road_to(tree, world, EstateLayout.FREIGHT_APPROACH)
	if not _expect(cart.arrived and landing.visible and world.player.interaction_target == cart,
		"The summer shipment opens the landing at the actual arrival."):
		return
	await _key(KEY_E)
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialog != null and dialog.choices[0].text == "指路去南池钓台", "Shen He offers the landing route."):
		return
	await _snapshot("11-rice-arrival")
	await _button(dialog.choices[0])
	_expect(ui.directions.tracked_place == CreekFish.PLACES[CreekFish.Site.POND], "The route points to the pond's west bank.")
	await Campaign.walk_estate_road_to(tree, world, landing.global_position)
	if not _expect(world.player.interaction_target == landing and not state.knows_ravine_journal(),
		"The new dock can be reached from the bank, before learning about the ravine."):
		return
	await _snapshot("12-pond-landing")
	var energy: int = state.current_stamina
	var day: int = state.current_day
	await _key(KEY_E)
	var panel := ui.get_node_or_null("Control/FishingPanel") as Control
	if not _expect(panel != null and tree.paused and panel.spot == landing, "The same fishing controls open at the pond."):
		return
	while panel.phase == panel.Phase.WAITING:
		await tree.process_frame
	await _snapshot("13-pond-fishing")
	_key_state(KEY_SPACE, true)
	for frame in 300:
		await tree.process_frame
		if panel.phase != panel.Phase.REELING:
			break
		if panel.holding and panel.tension >= 0.64:
			_key_state(KEY_SPACE, false)
		elif not panel.holding and panel.tension <= 0.43:
			_key_state(KEY_SPACE, true)
	_key_state(KEY_SPACE, false)
	_expect(panel.catch_icon.visible and state.fish_count("crucian") == 1
		and state.fish_collection.crucian.first_site == CreekFish.Site.POND
		and state.last_fishing_day == day and state.current_stamina == energy - state.balance.fishing_stamina_cost,
		"A real catch consumes today's fishing opportunity and records its location.")
	await _snapshot("14-pond-catch")
	await _button(panel.actions.get_node("HearthRoute"))
	_expect(not tree.paused and ui.directions.tracked_place == "南路灶台" and not state.cast_fishing_line(CreekFish.Site.POND),
		"The catch points back to the hearth and today's fishing opportunity is used.")
	if not await _continue(state.ESTATE_SCENE):
		return
	estate = tree.current_scene
	world = estate.get_node("World")
	ui = estate.get_node("UI")
	_expect(world.get_node("Scenery/PondLanding").visible and state.pond_landing_day() == day
		and state.fish_collection.crucian.first_site == CreekFish.Site.POND, "The dock and its first catch survive a title continue.")
	var hearth := await _open_hearth()
	if not _expect(hearth != null and not hearth.choices[1].disabled, "The local rice and fish make a travel meal."):
		return
	await _button(hearth.choices[1])
	_expect(state.travel_meal == TravelMeal.RICE_FISH and state.fish_count("crucian") == 0
		and state.crop_stock.count("rice") == 0 and state.king_storage == 1,
		"Packing the meal consumes the market rice and the pond fish.")
	print("POND_LANDING day=", day, " fish=crucian site=", CreekFish.Site.POND, " meal=", state.travel_meal)

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
	var market := tree.current_scene as Node2D
	await Campaign.walk_to_market_exit(tree, market)
	if not await _cross(market.player, [], &"ui_right", state.WEST_ROAD_SCENE):
		return
	var road := tree.current_scene as Node2D
	_expect(state.market_trip_target == state.FREIGHT_YARD and state.FREIGHT_YARD in road.get_node("%Route").text,
		"The bridge continues the unloading-yard route through the east gate.")
	var bridge_progress := (SeasonFreight.west_road_start + SeasonFreight.west_road.get_baked_length() * 0.5) / SeasonFreight.route_length
	await _set_watch(SeasonOrders.EVENING_DISPATCH + SeasonOrders.TRAVEL_FRACTION * bridge_progress)
	var road_cart := road.get_node("Freight") as SeasonFreight
	_expect(road_cart.travelling and road_cart.cargo.is_visible_in_tree() and road.ground.LAYOUT.BRIDGE.has_point(road_cart.position),
		"The same loaded cart passes over the bridge between the market and the estate.")
	print("WEST_ROAD_FREIGHT at=", road_cart.position, " cargo=", road_cart.cargo.is_visible_in_tree())
	await _snapshot("05a-bridge-shipment")
	if await _cross(road.player, [], &"ui_right", state.ESTATE_SCENE):
		var estate := tree.current_scene
		var ui := estate.get_node("UI")
		_expect(estate.get_node("World/SeasonBoard").delivered and not ui.hud.pinned_order.visible
			and ui.directions.destination().point == EstateLayout.FREIGHT_APPROACH,
			"The paid farm tracker clears and the west gate hands off to the actual unloading yard.")
		await _snapshot("05b-unloading-yard-route")
		var travel := (SeasonFreight.estate_start + 115.0) / SeasonFreight.route_length
		await _set_watch(SeasonOrders.EVENING_DISPATCH + SeasonOrders.TRAVEL_FRACTION * travel)
		var cart := estate.get_node("World/Freight") as SeasonFreight
		_expect(cart.travelling and cart.cargo.is_visible_in_tree(), "The same load enters the estate by the west road.")
		await _snapshot("06-estate-road")
		var checkpoint := cart.route_offset
		var saved_watch: float = state.day_progress
		if not await _continue(state.ESTATE_SCENE):
			return
		estate = tree.current_scene
		cart = estate.get_node("World/Freight") as SeasonFreight
		var advanced: float = state.day_progress - saved_watch
		var expected := checkpoint + advanced * SeasonFreight.route_length / SeasonOrders.TRAVEL_FRACTION
		_expect(cart.travelling and absf(advanced) < 0.01 and absf(cart.route_offset - expected) < 8.0,
			"The resumed cart's position matches the restored clock and the time since resuming.")
		await _set_watch(SeasonOrders.EVENING_DISPATCH + SeasonOrders.TRAVEL_FRACTION + 0.01)
		var world := estate.get_node("World") as Node2D
		await Campaign.walk_estate_road_to(tree, world, EstateLayout.FREIGHT_APPROACH)
		_expect(cart.arrived and cart.position.is_equal_approx(EstateLayout.FREIGHT_STOP)
			and world.player.interaction_target == cart,
			"The west-road shipment stops in the unloading yard, with room to approach the driver.")
		await _key(KEY_E)
		var dialog := estate.get_node("UI/Control/DialoguePanel") as Control
		_expect(dialog.name_label.text == "申禾" and "来亭里就能领种" in dialog.text_label.text
			and state.market_trip_target.is_empty(), "Talking to the driver completes the route and names the recipients.")
		await _snapshot("07-south-pavilion")
		print("ORDER_DELIVERED day=", state.current_day, " grain_reward=", state.season_order_rewards(state.season_order()).food,
			" tribute=", state.king_storage)
		await _button(dialog.options_container.get_child(1))
		_expect(estate.get_node("UI").directions.tracked_place == "南路灶台", "The driver can point to the new hearth.")
		await _meal_from_harvest()

func _open_hearth(frame := "") -> Control:
	var estate := tree.current_scene
	var world := estate.get_node("World") as Node2D
	var approach := world.get_node("TravelHearth/Approach") as Marker2D
	await Campaign.walk_estate_road_to(tree, world, approach.global_position)
	_expect(estate.get_node("UI").directions.tracked_place != "南路灶台", "The stove's direction label clears at the front step.")
	if not frame.is_empty():
		await _snapshot(frame)
	await _key(KEY_E)
	return estate.get_node_or_null("UI/Control/DialoguePanel") as Control

func _meal_from_harvest() -> void:
	var estate := tree.current_scene
	var hearth := estate.get_node("World/TravelHearth")
	var dialogue := await _open_hearth("08-lit-hearth")
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
	var dialogue := await _open_hearth()
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
	var market := tree.current_scene
	await _open_cart()
	var book: Control = market.counter.orders
	_expect(book.freight_route.visible and book.freight_route.text.begins_with("上一季货车")
		and "第 7 天巳时" in book.freight_route.tooltip_text,
		"The new summer page can still mark where the previous spring shipment will arrive.")
	await _button(book.freight_route)
	_expect(state.market_trip_target == state.FREIGHT_YARD, "The late load starts the same return route after rollover.")
	print("ORDER_LATE day=", state.current_day, " cargo=", cart.shown_order, " offset=", snappedf(cart.route_offset, 0.1))

func _check_wait_boundaries() -> void:
	var day := 6
	var late := {"day": day, "dispatch_day": day + 1, "paid_in_food": true}
	var crop := Vector2i(5, 5)
	var private_crop := Vector2i(6, 5)
	var path := "user://late-freight-seat.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _expect(file != null, "Create an evening receipt at the last day of spring."):
		return
	file.store_string(JSON.stringify({"current_day": day, "day_progress": 0.84, "market_trip_target": state.FREIGHT_YARD,
		"king_storage": 1, "food_storage": 10, "season_order_receipts": {"spring": late}}))
	file.close()
	if not _expect(state.load_game(path) == OK, "Load an earlier save with tomorrow's shipment."):
		return
	await tree.scene_changed
	await tree.process_frame
	var world: Node2D = tree.current_scene.get_node("World")
	var ui: CanvasLayer = tree.current_scene.get_node("UI")
	var tiles: TileMapLayer = world.tile_map
	for cell in [crop, private_crop]:
		for click in 3:
			await _plot(tiles, cell)
	await _walk_to_bench()
	var dialog := await _open_bench()
	if dialog == null:
		return
	_expect(dialog.choices.size() == 1 and "第 7 天巳时" in dialog.text_label.text,
		"An overnight shipment offers its ETA and requires sleeping as usual.")
	await _snapshot("09-tomorrow-delivery")
	await _key(KEY_ESCAPE)
	await _button(ui.sleep_button)
	await tree.create_timer(1.15).timeout
	var morning: Variant = state.pending_freight_receipt()
	_expect(state.current_day == 7 and state.food_storage == 9 and state.market_trip_target == state.FREIGHT_YARD
		and morning == late and state.active_crops.get(crop, {}).get("age") == 1
		and state.active_crops.get(private_crop, {}).get("age") == 1,
		"Ordinary overnight rolls spring into summer, feeds the household, and grows both plots once.")
	# Advance to the morning departure with the player still beside the bench.
	var next_receipt := {"day": 7, "dispatch_day": 7, "paid_in_food": false}
	state.season_order_receipts["summer"] = next_receipt
	var events := tree.root.get_node("GameEvents")
	events.inventory_changed.emit(state.player_inventory)
	ui.directions.follow_freight_yard()
	await _set_watch(SeasonOrders.MORNING_DISPATCH + 0.01)
	var before_raid: float = state.day_progress
	state.raid_day = state.current_day
	events.raid_started.emit()
	dialog = await _open_bench()
	if dialog == null:
		return
	_expect(dialog.choices.size() == 1 and "东路有来敌" in dialog.text_label.text
		and state.day_progress - before_raid < 0.01, "An active raid bars sitting while keeping the arrival information.")
	await _key(KEY_ESCAPE)
	state.raid_day = 0
	events.raid_defeated.emit()
	dialog = await _open_bench()
	if dialog == null:
		return
	await _button(dialog.choices[0])
	await tree.process_frame
	_expect(ui.freight_wait.visible, "The player can wait for the previous season's cart this morning.")
	state.raid_day = state.current_day
	events.raid_started.emit()
	_expect(not ui.freight_wait.visible and not world.player.resting,
		"A raid interrupts a wait and gives movement controls back immediately.")
	state.raid_day = 0
	events.raid_defeated.emit()
	dialog = await _open_bench()
	if dialog == null:
		return
	await _button(dialog.choices[0])
	await tree.create_timer(4.95).timeout
	var wagon := world.get_node("Freight") as SeasonFreight
	_expect(wagon.arrived and wagon.shown_order == "spring" and not ui.freight_wait.visible and state.current_day == 7
		and state.day_watch_label() == "巳时"
		and state.food_storage == 9 and state.king_storage == 1 and state.player_inventory == 0
		and state.active_crops.get(crop, {}).get("age") == 1 and state.active_crops.get(private_crop, {}).get("age") == 1,
		"Sitting for the morning wagon preserves the overnight results and the cargo from spring.")
	await _key(KEY_E)
	dialog = ui.get_node_or_null("Control/DialoguePanel") as Control
	_expect(dialog != null and dialog.name_label.text == "申禾" and "托的菽和黍" in dialog.text_label.text,
		"The spring driver remains available after his cart arrives. Current target: %s." % world.player.interaction_target)
	_expect(state.market_trip_target == state.FREIGHT_YARD, "The morning handoff keeps the return route for the summer cart.")
	await _key(KEY_ESCAPE)
	var bench := world.get_node("FreightBench") as Node2D
	await Campaign.walk_to(tree, world.player, bench.global_position + Vector2(7, 9))
	dialog = await _open_bench()
	if dialog == null:
		return
	_expect("第 7 天戌时" in dialog.text_label.text, "The bench now offers the second delivery.")
	await _button(dialog.choices[0])
	await tree.create_timer(4.95).timeout
	_expect(wagon.arrived and wagon.shown_order == "summer", "The evening cart replaces the morning cart when it reaches the yard.")
	await _key(KEY_E)
	_expect(state.market_trip_target.is_empty(), "Talking to the tracked cart clears the remaining directions.")
	await _key(KEY_ESCAPE)
	print("FREIGHT_WAIT_ROLLOVER day=", state.current_day, " food=", state.food_storage,
		" morning=spring evening=", wagon.shown_order, " public_and_private_age=", state.active_crops.get(crop, {}).get("age"),
		",", state.active_crops.get(private_crop, {}).get("age"))

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
	if capture_dir.is_empty():
		capture_dir = OS.get_environment("FIEFDOM_ORDER_CAPTURES")
	tree.root.notify_mouse_entered()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _play()
	if waiting_shipment:
		if not failed:
			await _check_wait_boundaries()
		if not failed:
			print("SCENARIO_OK")
		tree.quit(1 if failed else 0)
		return
	if summer:
		if not failed:
			print("SCENARIO_OK")
		tree.quit(1 if failed else 0)
		return
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
