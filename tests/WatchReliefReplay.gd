extends "res://tests/SecondYearOrdersReplay.gd"

const ORDER := "autumn_watch_relief"
const AUTUMN_END := 42
const POST_DAY := 43
const POST_APPROACH := EstateLayout.EAST_WATCH + Vector2(-15, 0)
const POST_CLOCK := 0.32
const CARGO := {"sorghum": 2, "beans": 1, "hemp": 1}
const SNARE_CROP := Vector2i(6, 5)

var baseline := false
var from_older_save := false
var capture_path := ""

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated watch delivery profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = capture_path
	tree.root.notify_mouse_entered()
	state.balance.raid_first_day = 10000
	if from_older_save:
		if await _continue_estate():
			await _inspect_post("01-continued-old-post")
	elif await _prepare_autumn() and await _send_after_evening():
		if baseline:
			await _inspect_baseline()
		elif await _follow_patrol() and await _inspect_post("04-new-flag"):
			await _thank_the_player()
			if not failed:
				await _defend_with_watch_snare()
			if not failed:
				await _next_year()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func _prepare_autumn() -> bool:
	return await _fixture(AUTUMN_END, {"crop_stock": CARGO, "player_inventory": 4,
		"active_crops": {"6,5": {"id": "sorghum", "age": 1, "growth_nights": 2, "watered": true}},
		"retainers": [{"name": "弋戎", "school": RetainerData.School.MILITARY, "duty": RetainerData.Duty.FIELD}],
		"east_watch_day": 10, "raids_defeated": 1, "last_defense": {"day": 9, "kind": 0, "losses": 0, "guard": "弋戎"}})

func _set_clock(at: float) -> void:
	state.advance_daylight((at - state.day_progress) * state.balance.daylight_seconds)
	await tree.process_frame
	await tree.process_frame

func _continue_estate() -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE, "Continue the estate through the title screen."):
		return false
	_estate()
	await tree.process_frame
	return true

func _send_after_evening() -> bool:
	await Campaign.walk_estate_road_to(tree, world, Vector2(-270, -21))
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return false
	var market := tree.current_scene as Node2D
	await Campaign.walk_market_to(tree, market, market.market_map.places[state.MARKET_ORDERS])
	await _set_clock(0.71)
	await _key(KEY_E)
	var book: Control = market.counter.orders
	_expect("东岗换防" in book.order_title.text, "The physical west market counter has the autumn watch order.")
	await _button(book.copper_button)
	var receipt: Dictionary = state.season_order_receipts.get(ORDER, {})
	if not _expect(receipt.get("dispatch_day") == POST_DAY and state.money == 126 and state.player_inventory == 0,
		"The paid last-day order takes the private stock and departs the next morning."):
		return false
	await _capture("01-late-autumn-receipt")
	await _key(KEY_ESCAPE)
	await Campaign.walk_to_market_exit(tree, market)
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return false
	_estate()
	await _night()
	return _expect(state.current_day == POST_DAY and state.season_order().order.id != ORDER and state.king_storage == 4,
		"Wake in winter with the autumn receipt and public tribute preserved.")

func _inspect_baseline() -> void:
	await _set_clock(0.5)
	await Campaign.walk_estate_road_to(tree, world, POST_APPROACH)
	await _capture("02-old-post")
	if not _expect(state.save_game() == OK, "Write the old packaged winter checkpoint with the autumn receipt."):
		return
	print("WATCH_RELIEF_OLD_SAVE path=", ProjectSettings.globalize_path(state.manual_save_path()))
	await _key(KEY_E)
	var dialog: Control = ui.get_node_or_null("Control/DialoguePanel")
	_expect(dialog != null and "末一箭" in dialog.text_label.text and "新麻绳" not in dialog.text_label.text,
		"The previous watch has the original battle record after the cart has arrived.")
	await _capture("03-old-watch-log")
	print("WATCH_RELIEF_BASELINE day=", state.current_day, " dispatch=", state.season_order_receipts[ORDER].dispatch_day)

func _follow_patrol() -> bool:
	var courier := world.get_node("WatchReliefCourier") as Node2D
	_expect(not courier.visible and state.watch_relief_day() == 0, "At dawn the pending order has yet to be unloaded.")
	await Campaign.walk_estate_road_to(tree, world, EstateLayout.FREIGHT_APPROACH)
	await _set_clock(SeasonOrders.MORNING_DISPATCH + SeasonOrders.TRAVEL_FRACTION + 0.004)
	var freight := world.get_node("Freight") as SeasonFreight
	_expect(freight.arrived and freight.shown_order == ORDER and not freight.cargo.visible
		and courier.visible and state.watch_relief_day() == 0,
		"The late autumn cart unloads in winter and the courier leaves with the sacks.")
	await _capture("02-courier-from-cart")
	await _key(KEY_E)
	var dialog: Control = ui.get_node_or_null("Control/DialoguePanel")
	if not _expect(dialog != null and dialog.name_label.text == "申禾" and "巡人" in dialog.text_label.text,
		"Speak to the arrived driver at the unloading point."):
		return false
	var watch_choice: Button = dialog.options_container.get_child(0)
	_expect(watch_choice.text == "指路去东路岗", "The driver's first route follows the cargo to its recipient.")
	await _button(watch_choice)
	_expect(ui.directions.tracked_place == "东路岗" and ui.directions.destination().point == EstateLayout.EAST_WATCH,
		"The normal road directions lead to the east watch.")
	var foot: Vector2 = courier.position
	await tree.create_timer(0.8).timeout
	_expect(courier.visible and courier.position.distance_to(foot) > 18.0 and courier.body.walking,
		"The porter visibly walks along the route as the clock advances.")
	await Campaign.walk_estate_road_to(tree, world, EstateLayout.PAVILION_TURN)
	_expect(courier.visible and courier.position.y < EstateLayout.SOUTH_FORK.y,
		"The patrol leaves the unloading road and follows the path past the pavilion.")
	await _capture("03-patrol-by-the-pavilion")
	var saved_progress: float = state.watch_relief_progress()
	if not _expect(state.save_game() == OK, "Save while the patrol is in transit.") or not await _continue_estate():
		return false
	courier = world.get_node("WatchReliefCourier")
	var resumed: float = state.watch_relief_progress()
	var expected: Vector2 = courier.road.sample_baked(resumed * courier.road.get_baked_length())
	_expect(courier.visible and absf(resumed - saved_progress) < 0.04 and courier.position.distance_to(expected) < 7.0,
		"Continue restores the courier on the same road at the saved watch.")
	await Campaign.walk_estate_road_to(tree, world, POST_APPROACH)
	await _set_clock(POST_CLOCK)
	return _expect(not courier.visible and state.watch_relief_day() == POST_DAY, "The courier reaches the post and completes the handoff.")

func _inspect_post(frame: String) -> bool:
	await Campaign.walk_estate_road_to(tree, world, POST_APPROACH)
	var post := world.get_node("Scenery/EastWatch") as Node2D
	_expect(post.visible and post.relief_day == POST_DAY and state.watch_relief_day() == POST_DAY,
		"The flag and provisions are visible after delivery, including when continuing an older receipt.")
	await _capture(frame)
	await _key(KEY_E)
	var dialog: Control = ui.get_node_or_null("Control/DialoguePanel")
	if not _expect(dialog != null and "末一箭" in dialog.text_label.text and "第 43 天" in dialog.text_label.text
		and "新麻绳" in dialog.text_label.text, "Read both the original defence and the new dated delivery from the post."):
		return false
	await _capture("05-watch-log")
	await _button(dialog.options_container.get_child(-1))
	await _key(KEY_M)
	var entry: Array = ui.estate_map.places.filter(func(place: Dictionary): return place.title == "东路岗")
	_expect(entry.size() == 1 and "巡粮已到" in entry[0].detail, "The actual map shows where the delivered provisions are.")
	await _key(KEY_ESCAPE)
	print("WATCH_RELIEF_POST day=", state.watch_relief_day(), " defense=", state.last_defense.day)
	return not failed

func _thank_the_player() -> void:
	var guard: Node2D = world.neighbor_actor(VisitorData.EAST_WATCHER)
	await Campaign.walk_estate_road_to(tree, world, guard.global_position - Vector2(14, 0))
	await _key(KEY_E)
	var dialog: Control = ui.get_node_or_null("Control/DialoguePanel")
	if _expect(dialog != null and dialog.name_label.text == "弋戎" and "你送的稷和菽" in dialog.text_label.text,
		"The actual named guard acknowledges the completed shipment."):
		await _capture("06-guard-thanks")
		await _button(dialog.options_container.get_child(0))

func _defend_with_watch_snare() -> void:
	state.balance.raid_first_day = 44
	ui.hud._refresh_raid_alert()
	await _button(ui.hud.raid_alert)
	var prep: Control = ui.get_node_or_null("Control/NightRationsPanel")
	if not _expect(prep != null, "The raid warning opens the evening preparation panel."):
		return
	await _capture("07-watch-preparation")
	await _button(prep.find_watch)
	_expect(ui.directions.tracked_place == "东路岗", "The warning can guide the player to prepare at the watch.")
	await Campaign.walk_estate_road_to(tree, world, POST_APPROACH)
	await _key(KEY_E)
	var dialog: Control = ui.get_node_or_null("Control/DialoguePanel")
	if not _expect(dialog != null and dialog.options_container.get_child(0).text == "布拦索（用换防麻）",
		"The delivered hemp is offered once as the material for the snare."):
		return
	var tribute: int = state.king_storage
	var hemp: int = state.crop_stock.count("hemp")
	var food: int = state.food_storage
	await _button(dialog.options_container.get_child(0))
	_expect(state.watch_snare_armed and not state.watch_snare_relief_available() and state.crop_stock.count("hemp") == hemp
		and state.food_storage == food, "Setting the snare spends the delivered hemp instead of private stock or food.")
	await Campaign.walk_estate_road_to(tree, world, EstateLayout.EAST_RAID_SNARE + Vector2(-26, 0))
	await _capture("08-snare-ready")
	if not _expect(state.save_game() == OK, "Save with the snare still armed.") or not await _continue_estate():
		return
	_expect(state.watch_snare_armed and not state.watch_snare_relief_available(), "Continue restores the armed snare and the used shipment.")
	await _night()
	var enemy := tree.get_first_node_in_group("estate_raiders") as Node2D
	if not _expect(enemy != null and state.raid_day == 44, "The next dawn starts a real estate raid."):
		return
	for frame in 90:
		if not state.watch_snare_armed:
			break
		await tree.physics_frame
	if not _expect(state.raid_snare_left > 0.0 and not state.watch_snare_armed and enemy.pending_attack == enemy.Attack.NONE,
		"The raider stops at the visible snare before an attack can start."):
		return
	var caught_at := enemy.position
	await tree.create_timer(0.25).timeout
	_expect(enemy.position.distance_to(caught_at) < 0.1 and state.raid_crop_losses == 0,
		"The raider stays in place while the snare runs down.")
	if not _expect(state.save_game() == OK, "Save while the raider is held.") or not await _continue_estate():
		return
	enemy = tree.get_first_node_in_group("estate_raiders") as Node2D
	if not _expect(enemy != null and enemy.position.distance_to(caught_at) <= 4.0
		and state.raid_snare_left > 0.0 and state.raid_snare_left < state.balance.raid_snare_seconds,
		"Continue restores the stopped raider and only its remaining snare time."):
		return
	await Campaign.walk_straight(tree, world.player, Vector2(209, 151))
	await _capture("09-raider-caught")
	var point := enemy.get_global_transform_with_canvas().origin + Vector2(0, -5)
	var shot := InputEventMouseButton.new()
	shot.position = point
	shot.global_position = point
	shot.button_index = MOUSE_BUTTON_RIGHT
	shot.pressed = true
	tree.root.push_input(shot, true)
	shot = shot.duplicate()
	shot.pressed = false
	tree.root.push_input(shot, true)
	await tree.create_timer(0.24).timeout
	if not _expect(state.raid_day == 0 and state.raids_defeated == 2 and state.last_defense.get("snare", false)
		and state.raid_snare_left < 0.0 and state.king_storage == tribute
		and state.active_crops.has(SNARE_CROP) and state.last_defense.losses == 0,
		"The real shot ends the raid, preserves the standing crop and credits the snare."):
		return
	await Campaign.walk_estate_road_to(tree, world, POST_APPROACH)
	await _key(KEY_E)
	dialog = ui.get_node_or_null("Control/DialoguePanel")
	if _expect(dialog != null and "拦索绊住了来敌" in dialog.text_label.text
		and "来敌正被拦索绊住" not in dialog.text_label.text
		and dialog.options_container.get_child(0).disabled, "The watch board recalls the snare and the shipment cannot be used again."):
		await _capture("10-snare-report")
		await _button(dialog.options_container.get_child(-1))
	var guard: Node2D = world.neighbor_actor(VisitorData.EAST_WATCHER)
	await Campaign.walk_estate_road_to(tree, world, guard.global_position + Vector2(16, 0))
	await _key(KEY_E)
	dialog = ui.get_node_or_null("Control/DialoguePanel")
	if _expect(dialog != null and "一脚绊在东路" in dialog.text_label.text, "The named defender acknowledges the actual snare."):
		await _button(dialog.options_container.get_child(-1))
	print("WATCH_SNARE day=", state.current_day, " relief=", state.watch_snare_relief_used_day, " raid_won=", state.raids_defeated)

func _prepare_from_private_stock() -> void:
	var old_record := {"day": 9, "kind": 0, "losses": 0, "guard": ""}
	if not await _fixture(17, {"east_watch_day": 10, "last_defense": old_record,
			"crop_stock": {"hemp": 2}, "player_inventory": 2, "retainers": []}):
		return
	await Campaign.walk_estate_road_to(tree, world, POST_APPROACH)
	await _key(KEY_E)
	var dialog: Control = ui.get_node_or_null("Control/DialoguePanel")
	if _expect(dialog != null and dialog.options_container.get_child(0).text == "布拦索（麻 ×1）",
		"An existing watch without a shipment offers a one-hemp purchase."):
		await _button(dialog.options_container.get_child(0))
		_expect(state.watch_snare_armed and not state.prepare_watch_snare()
			and state.crop_stock.count("hemp") == 1 and state.king_storage == 4,
			"Only one private hemp is used and a second placement cannot spend another.")
		print("WATCH_SNARE_PRIVATE day=", state.current_day, " hemp=", state.crop_stock.count("hemp"))

func _next_year() -> void:
	if not await _fixture(61, {"player_inventory": 4, "crop_stock": CARGO,
			"season_order_receipts": {ORDER: {"day": 42, "dispatch_day": 43}}}):
		return
	var book := await _orders()
	await _button(book.copper_button)
	_expect(state.watch_relief_day() == POST_DAY and state.watch_relief_progress() < 0.0,
		"The old flag remains while the next year's replacement shipment is queued.")
	await _close_management()
	if not _expect(state.save_game() == OK, "Save the repeated seasonal order.") or not await _continue_estate():
		return
	_expect(state.east_watch_day == 0 and state.watch_relief_day() == POST_DAY
		and world.get_node("Scenery/EastWatch").visible, "The previous goods remain visible after reload, including without a defence board.")
	await Campaign.walk_estate_road_to(tree, world, POST_APPROACH)
	await _set_clock(0.95)
	await _key(KEY_E)
	var dialog: Control = ui.get_node_or_null("Control/DialoguePanel")
	_expect(dialog != null and dialog.name_label.text == "东岗巡粮簿" and "第 61 天" in dialog.text_label.text,
		"With no defence board, the new handoff date is readable on its own.")
	print("WATCH_RELIEF_REPEAT previous=43 latest=", state.watch_relief_day())
	if not failed:
		await _prepare_from_private_stock()
