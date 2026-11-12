extends "res://tests/WestMarketReplay.gd"

const TAO := VisitorData.SILK_MERCHANT

var legacy := false
var capture_path := ""
var world: Node2D
var ui: CanvasLayer

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")

func _road_to_market() -> bool:
	await _walk(world.player, [Vector2(-181, 54), Vector2(-181, 0), Vector2(-270, -21)])
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
	await _walk(world.player, [Vector2(-84, 137), Vector2(-84, 84), tao.global_position + Vector2(0, 18)])
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
	await _walk(world.player, [Vector2(-180, 50), Vector2(-119, 63)])
	await _time_at(VisitorData.SILK_MARKET_DEPART - 0.002)
	await tree.create_timer(0.72).timeout
	_expect(tao.activity == VisitorData.VisitActivity.TO_SILK_MARKET and tao.walking_to_stop, "The merchant walks out at 巳时.")
	await _snapshot("00-west-court-departure")
	await tree.create_timer(6.0).timeout
	_expect(world.neighbor_actor(TAO) == null and "正沿西路" in world.silk_trip_note(), "The visitor leaves through the west gate.")

	await _button(ui.hud.neighbors_button)
	var panel: Control = ui.panel_manager.management_panel_instance
	var journal: Control = panel.neighbor_journal
	await _button(journal.roster.get_node(TAO))
	_expect("正沿西路" in journal.where.text, "The journal reports the trip in progress.")
	await _snapshot("01-neighbor-journal")
	await _button(journal.locate_button)
	_expect(ui.directions.destination().point == world.get_node("WestMarketGate").position and not panel.visible,
		"The journal leads to the west gate while the merchant is off the estate.")
	return await _road_to_market()

func _market_visit() -> bool:
	var market := tree.current_scene
	_expect(market.sample.visible and market.silk_guest == null, "Find the sample and wait for the merchant at the market.")
	await _walk(market.player, [Vector2(151, 63)])
	await _time_at(VisitorData.SILK_MARKET_ARRIVE - 0.002)
	await tree.create_timer(0.70).timeout
	if not _expect(market.silk_guest != null and market.silk_guest.walking_to_stop, "At noon Tao Xin walks in from the east gate."):
		return false
	await _snapshot("02-market-arrival")
	await tree.create_timer(1.65).timeout
	var tao: Visitor = market.silk_guest
	_expect(tao != null and not tao.walking_to_stop, "The merchant reaches Cai Niang's stall.")
	await _walk(market.player, [Vector2(151, 63)])
	if not await _talk(market, "交谈", "03-market-conversation"):
		return false
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
	if not _expect(state.save_game() == OK, "Save in the market during Tao Xin's visit."):
		return false
	var saved_time: float = state.day_progress
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	market = tree.current_scene
	_expect(market.scene_file_path == state.WEST_MARKET_SCENE and market.silk_guest != null and market.sample.visible
		and absf(state.day_progress - saved_time) < 0.02, "The market and its resident resume at the saved time.")
	print("SILK_MARKET_VISIT day=", state.current_day, " clock=", state.day_watch_label(), " sample=", market.sample.visible)
	return not failed

func _back_to_pavilion() -> bool:
	var market := tree.current_scene
	await _time_at(VisitorData.SILK_MARKET_LEAVE - 0.002)
	await tree.create_timer(0.72).timeout
	_expect(market.silk_guest != null and market.silk_guest.walking_to_stop and market.silk_guest.position.x > 150,
		"At 申时 Tao Xin walks back to the gate.")
	await tree.create_timer(1.65).timeout
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return false
	_estate()
	_expect(world.neighbor_actor(TAO) == null and "返程" in world.silk_trip_note(), "No estate duplicate while the merchant is on the road.")
	await _time_at(VisitorData.SILK_MARKET_RETURN - 0.002)
	await tree.create_timer(0.70).timeout
	var tao: Visitor = world.neighbor_actor(TAO)
	if not _expect(tao != null and tao.walking_to_stop and tao.visit_location() == "南路亭",
			"At 酉时 the merchant returns along the west road toward the pavilion."):
		return false
	await _snapshot("05-back-on-the-estate")
	await tree.create_timer(10.6).timeout
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
	state.current_day = 9
	state.day_progress = 0.40
	state.reputation = maxi(state.reputation, state.balance.recruit_reputation_requirement)
	tree.change_scene_to_file(state.WEST_MARKET_SCENE)
	await tree.scene_changed
	market = tree.current_scene
	await _walk(market.player, [Vector2(151, 63)])
	if not await _talk(market, "招募"):
		return
	_expect(market.silk_guest == null and market.sample.visible, "Recruitment ends the trip and leaves the sample on display.")
	await _walk(market.player, [Vector2(176, 34)])
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
