extends "res://tests/SecondYearOrdersReplay.gd"

const GARDEN := preload("res://scripts/SeedGarden.gd")
const SPRING_END := 6
const ARRIVAL_DAY := 7

func _continue_estate() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	_estate()
	await tree.process_frame

func _advance_clock(watch: float) -> void:
	state.advance_daylight((watch - state.day_progress) * state.balance.daylight_seconds)
	await tree.process_frame
	await tree.process_frame

func _send_seed() -> bool:
	if not await _fixture(SPRING_END, {"day_progress": 0.71, "crop_stock": {"beans": 2, "millet": 1},
			"player_inventory": 3, "retainers": [{"name": "渠伯", "school": 2}]}):
		return false
	var book := await _orders()
	await _button(book.food_button)
	await _close_management()
	_expect(state.season_order_receipts.spring.dispatch_day == ARRIVAL_DAY and state.player_inventory == 0
		and state.food_storage == 35 and state.king_storage == 4 and state.seed_garden_day() == 0,
		"The late spring order uses private stock and pays the normal food reward while the garden waits.")
	await _night()
	return _expect(state.current_day == ARRIVAL_DAY and state.food_storage == 34,
		"The order crosses into summer and the household eats its usual ration.")

func _follow_seeds() -> bool:
	await Campaign.walk_estate_road_to(tree, world, EstateLayout.FREIGHT_APPROACH)
	await _advance_clock(SeasonOrders.MORNING_DISPATCH + SeasonOrders.TRAVEL_FRACTION + 0.008)
	var garden: Node2D = world.get_node("Scenery/SeedGarden")
	var freight: SeasonFreight = world.get_node("Freight")
	if not _expect(freight.arrived and not freight.cargo.visible and garden.courier.visible and garden.in_transit
		and garden.planted_day == 0, "Lin Liao takes the unloaded seed and starts walking from the yard."):
		return false
	await _capture("01-seeds-leave-the-yard")
	await _key(KEY_E)
	var dialog: Control = ui.get_node("Control/DialoguePanel")
	var guide: Button = dialog.options_container.get_child(0)
	_expect(dialog.name_label.text == "申禾" and guide.text == "指路去亭西种圃", "The driver points to the recipient's garden.")
	await _button(guide)
	_expect(ui.directions.tracked_place == GARDEN.PLACE, "The driver's option starts the normal estate route.")
	var foot: Vector2 = garden.courier.position
	_expect(state.save_game() == OK, "Save during the short seed delivery.")
	await _continue_estate()
	garden = world.get_node("Scenery/SeedGarden")
	_expect(garden.courier.visible and garden.courier.position.distance_to(foot) < 12.0,
		"Reload puts Lin Liao back on the same road.")
	await Campaign.walk_estate_road_to(tree, world, EstateLayout.SEED_GARDEN_APPROACH)
	await _advance_clock(0.34)
	if not _expect(garden.planted_day == ARRIVAL_DAY and garden.stage == 0 and garden.courier.visible,
		"The two seedbeds open only once the seed reaches the pavilion."):
		return false
	await _capture("02-seedbeds")
	await _key(KEY_E)
	dialog = ui.get_node("Control/DialoguePanel")
	_expect(dialog.name_label.text == GARDEN.HOST and "菽和黍" in dialog.text_label.text
		and "第 10 天巳时" in dialog.text_label.text, "Lin Liao explains what she planted and when she will return.")
	await _capture("03-lin-liao")
	await _button(dialog.options_container.get_child(0))
	await _key(KEY_M)
	var places: Array = ui.estate_map.places
	_expect(places.any(func(entry: Dictionary) -> bool: return entry.title == GARDEN.PLACE),
		"The estate chart now lists the seed garden.")
	_expect(places.any(func(entry: Dictionary) -> bool:
		return entry.title == GARDEN.PLACE and "第 10 天巳时" in entry.detail),
		"The chart shows the appointment at the actual garden.")
	await _key(KEY_ESCAPE)
	return not failed

func _first_harvest() -> void:
	await _night()
	var garden: Node2D = world.get_node("Scenery/SeedGarden")
	_expect(garden.stage == 1 and not state.take_seed_garden_gift("beans"), "Seedlings appear after one night without an early harvest.")
	await _capture("04-young-plants")
	for night in SeasonOrders.SEED_GROW_NIGHTS - 1:
		await _night()
	_expect(garden.stage == 2 and state.current_day == ARRIVAL_DAY + SeasonOrders.SEED_GROW_NIGHTS, "The plants mature after three nights.")
	await _capture("05-mature-plants")
	await _advance_clock(0.30)
	var first := garden.recipients.get_child(0) as Node2D
	var arrival := first.position
	await tree.create_timer(0.24).timeout
	_expect(garden.host_present() and first.visible and first.position.distance_to(arrival) > 2.0
		and first.get_node("Motion").walking and garden.packets_left == 2,
		"Lin Liao opens the table and a recipient walks up from the lane.")
	await _capture("05a-arriving-for-seed")
	await _advance_clock(0.42)
	var second := garden.recipients.get_child(1) as Node2D
	if not _expect(first.visible and second.visible and first.get_node("Packet").visible
		and second.get_node("Packet").visible and garden.packets_left == 0,
		"Both recipients take a packet, leaving the player's share by the sign. Clock %s, packets left %s." % [
			state.day_progress, garden.packets_left]):
		return
	await _capture("06-neighbors-collect")
	await _key(KEY_E)
	var dialog: Control = ui.get_node("Control/DialoguePanel")
	var gift: Button = dialog.options_container.get_child(0)
	_expect(dialog.name_label.text == GARDEN.HOST and "阿绥和禾伯" in dialog.text_label.text
		and gift.text == "取一份菽", "Lin Liao offers a share in person during the seed gathering.")
	await _capture("07-lin-liao-shares")
	await _button(dialog.choices.back())
	_expect(state.seed_garden_gift.is_empty() and state.crop_stock.count("beans") == 0,
		"Leaving the share in the garden spends and awards nothing.")
	_expect(state.save_game() == OK, "Save while neighbors are still at the garden.")
	await _continue_estate()
	garden = world.get_node("Scenery/SeedGarden")
	_expect(garden.host_present() and garden.packets_left == 0 and garden.recipients.get_child(0).visible,
		"Reload reconstructs who has collected a packet at the saved time.")
	await Campaign.walk_estate_road_to(tree, world, EstateLayout.SEED_GARDEN_APPROACH)
	await _advance_clock(0.78)
	_expect(not garden.courier.visible and not garden.recipients.visible and garden.stage == 3,
		"The neighbors leave in the evening, and the crop beds show the harvested stubble.")
	await _capture("08-after-seed-sharing")
	await _key(KEY_E)
	dialog = ui.get_node("Control/DialoguePanel")
	_expect(dialog.name_label.text == GARDEN.PLACE and "木签" in dialog.text_label.text,
		"After hours the sign still lets the player collect the reserved share.")
	gift = dialog.options_container.get_child(0)
	await _button(gift)
	_expect(state.crop_stock.count("beans") == 1 and state.king_storage == 4 and state.seed_garden_gift == "beans"
		and not state.take_seed_garden_gift("millet"), "Only one sample reaches the private pantry.")
	_expect(state.save_game() == OK, "Save the sample and garden.")
	await _continue_estate()
	_expect(state.seed_garden_day() == ARRIVAL_DAY and state.seed_garden_gift == "beans" and state.crop_stock.count("beans") == 1,
		"The garden and its claimed share persist from the title screen.")
	print("SEED_GARDEN sent=", SPRING_END, " planted=", state.seed_garden_day(), " mature=", state.current_day,
		" private=", state.player_inventory, " tribute=", state.king_storage)
	print("SEED_GARDEN_SHARING day=", state.current_day, " two_recipients=true late_claim=", state.seed_garden_gift)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the seed garden profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_SEED_GARDEN_CAPTURES")
	tree.root.notify_mouse_entered()
	state.balance.raid_first_day = 10000
	if await _send_seed() and await _follow_seeds():
		await _first_harvest()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
