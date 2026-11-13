extends "res://tests/WestMarketReplay.gd"

const TAO := VisitorData.SILK_MERCHANT
const ROAD_SCENE := "res://scenes/WestRoad.tscn"

var legacy := false
var capture_path := ""
var world: Node2D
var ui: CanvasLayer

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")

func _road_to_market() -> bool:
	await Campaign.walk_estate_road_to(tree, world, world.get_node("WestMarketArrival").global_position)
	return await _cross(&"ui_left", state.WEST_MARKET_SCENE)

func _talk(host: Node, choice: String, capture := "") -> bool:
	await _key(KEY_E)
	var dialog: Control = host.get_node_or_null("UI/Control/DialoguePanel")
	if not _expect(dialog != null and dialog.name_label.text == TAO, "Press the normal interact key to speak to Tao Xin."):
		return false
	if not capture.is_empty():
		var paused: float = state.day_progress
		await tree.create_timer(0.25).timeout
		_expect(state.day_progress == paused and "蔡娘" in dialog.text_label.text,
			"Tao Xin's market conversation mentions the displayed sample and pauses the clock.")
		await _snapshot(capture)
	for button: Button in dialog.options_container.get_children():
		if button.text.begins_with(choice) and not button.disabled:
			await _button(button)
			return true
	return _expect(false, "The conversation offers " + choice)

func _sleep_through(day: int) -> void:
	for date in range(state.current_day, day):
		await _button(ui.sleep_button)
		await tree.create_timer(1.16).timeout
		if not _expect(state.current_day == date + 1, "One night advances one day."):
			return

func _save_and_continue() -> bool:
	if not _expect(state.save_game() == OK, "Save at the current stop of the trip."):
		return false
	return await _continue_saved(tree.current_scene.scene_file_path, state.day_progress)

func _continue_saved(location: String, clock: float) -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	return _expect(tree.current_scene.scene_file_path == location and absf(state.day_progress - clock) < 0.02,
		"Continue restores the saved scene and time of day.")

func _merchant_journal() -> Control:
	await _button(ui.hud.neighbors_button)
	var journal: Control = ui.panel_manager.management_panel_instance.neighbor_journal
	await _button(journal.roster.get_node(TAO))
	return journal

func _give_sample() -> bool:
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	_estate()
	state.balance.raid_first_day = 60
	await _harvest(world, ui)
	await _sleep_through(4)
	# The silk-interior scenario covers harvesting mulberry, raising silkworms, and weaving this bolt.
	state.silk_workshop.built = true
	state.silk_workshop.bolts = 1
	state.campaign_name = "春日南路东篱新领采邑织帛春事记一"
	var tao: Node2D = world.neighbor_actor(TAO)
	if not _expect(tao != null, "The first merchant visits the west court."):
		return false
	await Campaign.walk_estate_road_to(tree, world, tao.global_position + Vector2(0, 18))
	if not await _talk(tree.current_scene, "交谈"):
		return false
	var purse: int = state.money
	if not await _talk(tree.current_scene, "交样绸"):
		return false
	_expect(state.silk_sample_day == 4 and state.silk_bolts_sold == 1 and state.silk_workshop.bolts == 0
		and state.money == purse + state.silk_sample_price(), "Deliver and pay for the sample exactly once.")
	if not await _road_to_market():
		return false
	var market := tree.current_scene
	_expect(not market.sample.visible and market.silk_guest == null, "The sample reaches the market the following morning.")
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return false
	_estate()
	await _sleep_through(9)
	print("SILK_MARKET_SAMPLE day=", state.silk_sample_day, " sold=", state.silk_bolts_sold, " first_return=", state.current_day)
	return not failed

func _follow_merchant() -> bool:
	var tao: Visitor = world.neighbor_actor(TAO)
	if not _expect(tao != null and tao.visit_location() == "西廊绸架", "Start the morning in the west court."):
		return false
	_expect("午、未时" in ui.hud.visitor_label.text, "The estate announces the afternoon visit.")
	await Campaign.walk_estate_road_to(tree, world, EstateLayout.WEST_COURT_TURN + Vector2(16, 10))
	await _time_at(VisitorData.SILK_MARKET_DEPART - 0.002)
	await tree.create_timer(0.72).timeout
	_expect(tao.activity == VisitorData.VisitActivity.TO_SILK_MARKET and tao.walking_to_stop, "The merchant walks out at 巳时.")
	await _snapshot("00-west-court-departure")
	# Allow the merchant to reach the bridge on the shared timetable.
	await tree.create_timer(7.5).timeout
	_expect(world.neighbor_actor(TAO) == null and "正沿西路" in world.silk_trip_note(), "The visitor leaves through the west gate.")

	var journal := await _merchant_journal()
	_expect("正沿西路" in journal.where.text and journal.locate_button.text == "指路去西市",
		"The journal reports the trip to the market.")
	await _snapshot("01-neighbor-journal")
	await _button(journal.locate_button)
	_expect(ui.directions.destination().point == world.get_node("WestMarketGate").position
		and not ui.panel_manager.management_panel_instance.visible and state.market_trip_target == TAO,
		"The journal leads to the west gate while the merchant is off the estate.")
	if not await _save_and_continue():
		return false
	_estate()
	_expect(ui.directions.tracked_neighbor == TAO and state.market_trip_target == TAO,
		"The selected merchant survives Continue before the crossing.")
	await Campaign.walk_estate_road_to(tree, world, world.get_node("WestMarketArrival").global_position)
	await _time_at(VisitorData.SILK_MARKET_DEPART + 0.045)
	if not await _cross(&"ui_left", ROAD_SCENE) or not await _bridge_encounter(false):
		return false
	return await _cross(&"ui_left", state.WEST_MARKET_SCENE)

func _bridge_encounter(returning: bool) -> bool:
	var road := tree.current_scene as Node2D
	var tao: Visitor = road.silk_guest
	var name := "return" if returning else "outbound"
	if not _expect(tao != null and tao.walking_to_stop and tao.visit_location() == VisitorData.SILK_BRIDGE_PLACE,
		"The merchant actually walks on the bridge road on the %s trip." % name):
		return false
	print("SILK_BRIDGE_ENTER leg=", name, " player=", road.player.position, " tao=", tao.position, " progress=", state.day_progress)
	var origin := tao.position
	await tree.create_timer(0.3).timeout
	var motion := (tao.position - origin).x * (1.0 if returning else -1.0)
	_expect(motion > 3.0 and tao.sprite.walking and tao.sprite.flip_h == (not returning),
		"The sprite moves and faces toward the next map.")
	_expect(state.market_trip_target == TAO and road.route.size() > 1
		and road.route[-1].distance_to(tao.position) < 2.0, "The cross-map route ends at the merchant on the road.")
	var bridge_center: Vector2 = road.ground.LAYOUT.BRIDGE.get_center()
	await Campaign.walk_straight(tree, road.player, bridge_center + Vector2(0, 4))
	var action := &"ui_right" if returning else &"ui_left"
	var towards_market := -1.0 if returning else 1.0
	for frame in 340:
		if not is_instance_valid(tao) or tao.position.distance_to(road.player.position) < 24.0:
			break
		if (tao.position.x - road.player.position.x) * towards_market < -24.0:
			Input.action_press(action)
		await tree.physics_frame
	Input.action_release(action)
	if not _expect(is_instance_valid(tao) and road.player.position.distance_to(tao.position) < 26.0,
		"The player can reach the walking merchant from the same road, %s at %s." % [name, road.player.position]):
		return false
	await _snapshot("01-bridge-" + name)
	await _key(KEY_E)
	var dialogue := road.get_node_or_null("UI/Control/DialoguePanel") as Control
	if not _expect(dialogue != null and dialogue.name_label.text == TAO
		and ("南路亭" if returning else "绸摊") in dialogue.text_label.text
		and state.market_trip_target.is_empty(), "Road dialogue describes the next stop and completes the current route."):
		return false
	var clock: float = state.day_progress
	var feet := tao.position
	var reputation: int = state.reputation
	await tree.create_timer(0.3).timeout
	_expect(state.day_progress == clock and tao.position == feet and not tao.sprite.walking,
		"Conversation stops the clock and the merchant, even mid-bridge.")
	var bridge: Rect2 = road.ground.LAYOUT.BRIDGE
	_expect(bridge.has_point(feet) and absf(feet.y - road.player.position.y) >= 11.0,
		"The merchant uses the other side of the bridge, leaving room to pass.")
	await _snapshot("02-bridge-talk-" + name)
	if returning:
		_expect("已交谈" in dialogue.options_container.get_child(0).text
			and dialogue.options_container.get_child(0).disabled, "Talking in the morning already earned the daily reward.")
		await _key(KEY_ESCAPE)
	else:
		await _button(dialogue.options_container.get_child(0))
		_expect(state.reputation == reputation + state.balance.interaction_reputation_gain,
			"The ordinary talk action awards the same daily reputation on the road.")
	await tree.create_timer(0.3).timeout
	_expect(state.day_progress > clock and tao.position.distance_to(feet) > 3.0 and not road.settings.visible,
		"Closing dialogue resumes the trip without opening settings.")
	print("SILK_BRIDGE_WALK day=", state.current_day, " leg=", name, " merchant=", feet, " direction=", signf(motion))
	# Keep following him through the next gate and continue using the existing town and estate checks.
	state.market_trip_target = TAO
	if returning:
		return not failed
	await _button(road.get_node("%SettingsButton"))
	await _button(road.settings.save_button)
	var save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.manual_save_path()))
	_expect(save.location == "west_road" and save.market_trip_target == TAO, "Save normally while Tao Xin is on the bridge road.")
	var saved_foot := tao.position
	if not await _continue_saved(ROAD_SCENE, save.day_progress):
		return false
	road = tree.current_scene
	tao = road.silk_guest
	if not _expect(tao != null and tao.position.distance_to(saved_foot) < 5.0 and not road.route.is_empty()
		and road.route[-1].distance_to(tao.position) <= 2.1,
		"Continue restores the merchant along the same segment and follows him from the nearer gate."):
		return false
	await _snapshot("03-bridge-continued")
	print("SILK_BRIDGE_CONTINUE day=", state.current_day, " foot=", tao.position, " waypoint=", state.market_trip_target)
	return not failed

func _approach_tao(market: Node2D) -> void:
	await Campaign.walk_market_to(tree, market, market.ground.LAYOUT.TAO_STOP + Vector2(0, 22))

func _market_visit() -> bool:
	var market := tree.current_scene
	_expect(market.sample.visible and market.silk_guest == null, "Find the sample and wait for the merchant at the market.")
	var chart: Control = market.market_map
	await tree.create_timer(0.06).timeout
	_expect(chart.pin.visible and state.market_trip_target == TAO and "午时到绸摊" in chart.cancel_button.text
		and chart.pin.global_position.is_equal_approx(chart.places["绸摊"]),
		"The route leads to the meeting spot while the merchant is still on the road.")
	print("SILK_MARKET_ROUTE_WAIT day=", state.current_day, " point=", chart.pin.global_position)
	await _snapshot("01a-wait-at-the-silk-stall")
	await _approach_tao(market)
	await _time_at(VisitorData.SILK_MARKET_ARRIVE - 0.002)
	await tree.create_timer(0.70).timeout
	if not _expect(market.silk_guest != null and market.silk_guest.walking_to_stop, "At noon Tao Xin walks in from the east gate."):
		return false
	var first_foot: Vector2 = market.silk_guest.position
	await tree.create_timer(0.20).timeout
	_expect(first_foot.distance_to(market.silk_guest.position) > 4.0
		and chart.pin.global_position.distance_to(market.silk_guest.position) < 2.0,
		"The world marker follows the moving merchant.")
	await _snapshot("02-market-arrival")
	await tree.create_timer(7.6).timeout
	var tao: Visitor = market.silk_guest
	_expect(tao != null and not tao.walking_to_stop, "The merchant reaches Cai Niang's stall.")
	await _key(KEY_M)
	_expect(chart.modal.visible and chart.merchant_button.is_visible_in_tree() and chart.merchant_button.button_pressed
		and "在绸摊理货" in chart.route_status.text
		and tree.root.get_visible_rect().encloses(chart.merchant_button.get_global_rect()),
		"The market chart shows the current appointment and selected merchant.")
	await _snapshot("02a-merchant-on-market-chart")
	await _key(KEY_ESCAPE)
	await _approach_tao(market)
	if not await _talk(market, "离开", "03-market-conversation"):
		return false
	_expect(state.market_trip_target.is_empty(), "Opening the merchant's dialogue completes the route.")
	var reputation: int = state.reputation
	state.change_attire(PlayerAttire.SAMPLE)
	await _key(KEY_E)
	var dialog: Control = market.get_node("UI/Control/DialoguePanel")
	_expect(dialog.options_container.get_child(0).disabled and "衣上的纹" in dialog.text_label.text,
		"The same day's reward is shared across maps, and the merchant recognizes the matching clothes.")
	await _key(KEY_ESCAPE)
	_expect(not market.player.conversation_open and not market.settings.visible and state.reputation == reputation,
		"Escape closes the dialogue and keeps the stall and settings closed.")
	if not await _stall(market, "SilkStall", ""):
		return false
	_expect(state.campaign_name in market.counter.silk_sample.text and market.counter.silk_sample.visible,
		"Cai Niang's counter names the estate that produced the sample.")
	await _snapshot("04-silk-counter")
	await _key(KEY_ESCAPE)
	await _key(KEY_M)
	await _button(chart.merchant_button)
	await _key(KEY_ESCAPE)
	if not await _save_and_continue():
		return false
	market = tree.current_scene
	await tree.create_timer(0.06).timeout
	_expect(market.silk_guest != null and market.sample.visible and state.market_trip_target == TAO
		and market.market_map.pin.visible, "Continue in the market restores the guide to the actual resident.")
	print("SILK_MARKET_VISIT day=", state.current_day, " clock=", state.day_watch_label(), " sample=", market.sample.visible)
	return not failed

func _back_to_pavilion() -> bool:
	var market := tree.current_scene
	var chart: Control = market.market_map
	await _time_at(VisitorData.SILK_MARKET_LEAVE - 0.002)
	await tree.create_timer(0.72).timeout
	_expect(market.silk_guest != null and market.silk_guest.walking_to_stop and market.silk_guest.position.x > 150,
		"At 申时 Tao Xin walks back to the gate.")
	await tree.create_timer(7.6).timeout
	_expect(market.silk_guest == null and chart.pin.visible and "回封地找陶辛" in chart.cancel_button.text
		and chart.pin.global_position.is_equal_approx(market.get_node("EstateRoad").position),
		"After the merchant leaves, the guide switches to the return gate.")
	await _snapshot("04a-market-return-guide")
	await Campaign.walk_to_market_exit(tree, market)
	await _time_at(VisitorData.SILK_MARKET_LEAVE + 0.057)
	if not await _cross(&"ui_right", ROAD_SCENE) or not await _bridge_encounter(true):
		return false
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return false
	_estate()
	_expect(world.neighbor_actor(TAO) == null and "返程" in world.silk_trip_note(), "No estate duplicate while the merchant is on the road.")
	var stop: Dictionary = ui.directions.destination()
	_expect(ui.directions.tracked_neighbor == TAO and "酉时南路亭" in stop.get("title", "")
		and stop.point == world.get_node("Landscape").PAVILION_REST_FOOT,
		"On the estate, the guide points to his next stop at the pavilion.")
	var journal := await _merchant_journal()
	_expect(journal.locate_button.text == "指路去南路亭", "The neighbor journal also offers the next stop instead of the gate.")
	await _button(journal.locate_button)
	await _key(KEY_M)
	var map: Control = ui.estate_map
	await _button(map.tabs.get_node("People"))
	var marked := false
	for button: Button in map.row_buttons:
		var entry: Dictionary = map.row_buttons[button]
		if entry.title == TAO:
			marked = button.button_pressed and entry.point == stop.point
	_expect(marked and map.target.point == stop.point, "The selected portrait, destination and estate map agree on the pavilion.")
	print("SILK_MARKET_ROUTE_RETURN point=", stop.point, " journal=", journal.locate_button.text)
	await _snapshot("04b-estate-pavilion-guide")
	await _key(KEY_ESCAPE)
	await _time_at(VisitorData.SILK_MARKET_RETURN - 0.002)
	await tree.create_timer(0.70).timeout
	var tao: Visitor = world.neighbor_actor(TAO)
	if not _expect(tao != null and tao.walking_to_stop and tao.visit_location() == "南路亭",
			"At 酉时 the merchant returns along the west road toward the pavilion."):
		return false
	_expect(ui.directions.destination().point.distance_to(tao.position) < 2.0,
		"Once back on the estate, the pointer resumes tracking the actual merchant.")
	await _snapshot("05-back-on-the-estate")
	for frame in 840:
		if tao.resting_at_pavilion():
			break
		await tree.physics_frame
	_expect(tao.resting_at_pavilion(), "Tao Xin follows the road all the way to the pavilion. Position: %s, route stop: %d." % [
		tao.position, tao.next_stop])
	print("SILK_MARKET_RETURN day=", state.current_day, " at=", tao.visit_location(), " landed=", tao.resting_at_pavilion())
	return not failed

func _rain_and_recruit() -> void:
	# Skip to a real rainy merchant rotation in the third spring.
	state.current_day = 54
	state.day_progress = 0.40
	tree.change_scene_to_file(state.ESTATE_SCENE)
	await tree.scene_changed
	_estate()
	var tao: Visitor = world.neighbor_actor(TAO)
	_expect(state.has_rain() and tao != null and tao.visit_location() == "西廊绸架"
		and world.silk_trip_note().is_empty(), "Rain keeps the scheduled merchant at the estate.")
	if not await _road_to_market():
		return
	var market := tree.current_scene
	_expect(market.sample.visible and market.silk_guest == null, "The sample is still on display during the rain.")
	await _key(KEY_M)
	_expect(market.market_map.modal.visible and not market.market_map.merchant_button.visible,
		"The market chart offers the merchant only on his actual trip.")
	await _key(KEY_ESCAPE)
	state.current_day = 9
	state.day_progress = 0.40
	state.reputation = maxi(state.reputation, state.balance.recruit_reputation_requirement)
	tree.change_scene_to_file(state.WEST_MARKET_SCENE)
	await tree.scene_changed
	market = tree.current_scene
	await _approach_tao(market)
	if not await _talk(market, "招募"):
		return
	_expect(market.silk_guest == null and market.sample.visible, "Recruitment ends the trip and leaves the sample on display.")
	await Campaign.walk_to_market_exit(tree, market)
	if await _cross(&"ui_right", state.ESTATE_SCENE):
		_estate()
		_expect(world.neighbor_actor(TAO) is Retainer and world.current_visitor() == null
			and state.king_storage == 1 and state.silk_bolts_sold == 1,
			"Return to find one retained Tao Xin and preserve the public harvest and sample sale.")
		print("SILK_MARKET_VARIANTS rain=true recruited=", world.neighbor_actor(TAO) is Retainer,
			" public=", state.king_storage, " sales=", state.silk_bolts_sold)

func _continue_old_sample() -> void:
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	_estate()
	_expect(state.silk_sample_day == 4 and world.neighbor_actor(TAO) == null
		and VisitorData.SILK_MARKET_PLACE in world.silk_trip_note(),
		"The previous Windows save derives the new itinerary from its original sample date.")
	await _key(KEY_M)
	var map: Control = ui.estate_map
	await _button(map.tabs.get_node("People"))
	var person: Dictionary = {}
	for entry: Dictionary in map.people:
		if entry.title == TAO:
			person = entry
			break
	_expect(person.get("point") == world.get_node("WestMarketGate").position and "西市绸摊" in person.get("detail", ""),
		"The estate map lists Tao Xin at the west road while he is in the market.")
	await _key(KEY_ESCAPE)
	if await _road_to_market():
		var market := tree.current_scene
		_expect(market.sample.visible and market.silk_guest != null, "A legacy sample is displayed at the market.")
		print("SILK_MARKET_LEGACY sample=", state.silk_sample_day, " display=", market.sample.visible)

func _play() -> void:
	if not capture_path.is_empty():
		capture_dir = capture_path
	if legacy:
		await _continue_old_sample()
	elif await _give_sample() and await _follow_merchant() and await _market_visit() and await _back_to_pavilion():
		await _rain_and_recruit()
	tree.unload_current_scene()
	for stream in tree.root.get_node("AudioManager").get_children():
		if stream is AudioStreamPlayer:
			stream.stop()
	await tree.process_frame
