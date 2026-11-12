extends "res://tests/SilkMarketReplay.gd"

const GUIDE := VisitorData.RAVINE_GUIDE
const WATER := VisitorData.WATER_GUIDE

func _play() -> void:
	capture_dir = capture_path
	seed(1734)
	if legacy:
		await _check_previous_save()
	elif await _prepare_handoff() and await _read_appointments() and await _see_market_trip():
		if await _deliver_journal():
			await _recruit_guide()
	tree.unload_current_scene()
	for stream in tree.root.get_node("AudioManager").get_children():
		if stream is AudioStreamPlayer:
			stream.stop()
	await tree.process_frame

func _prepare_handoff() -> bool:
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	_estate()
	# Pick a second-year morning with an unfinished handoff and a sample already displayed at the market.
	state.current_day = 33
	state.day_progress = 0.12
	state.food_storage = 50
	state.king_storage = 2
	state.reputation = 80
	state.visitor_encounters[GUIDE] = 5
	state.visitor_encounters[TAO] = 8
	state.silk_sample_day = 9
	state.ravine_journal.recorded_days.assign([29, 30, 31])
	state.balance.raid_first_day = 10000
	return await _save_and_continue()

func _read_appointments() -> bool:
	var water_guide: Visitor = world.neighbor_actor(WATER)
	var guide: Visitor = world.neighbor_actor(GUIDE)
	if not _expect(water_guide != null and guide != null and world.active_visitors.size() == 2
			and world.current_visitor_actor() == water_guide and guide.visit_location() == "南边竹径",
			"On day 33 both the scheduled water guide and the handoff guide are on the estate."):
		return false
	_expect(WATER in ui.hud.visitor_label.text and GUIDE in ui.hud.visitor_label.text, "The estate journal mentions both people.")
	await _button(ui.hud.calendar_button)
	_expect(WATER in ui.calendar.forecast.text and GUIDE in ui.calendar.forecast.text, "The almanac shows the visit and handoff together.")
	await _snapshot("01-almanac")
	await _key(KEY_ESCAPE)
	await _key(KEY_M)
	var map: Control = ui.estate_map
	await _button(map.tabs.get_node("People"))
	var guide_entries: Array = map.people.filter(func(person: Dictionary) -> bool: return person.title == GUIDE)
	var water_entries: Array = map.people.filter(func(person: Dictionary) -> bool: return person.title == WATER)
	_expect(guide_entries.size() == 1 and water_entries.size() == 1
		and guide_entries[0].point != water_entries[0].point, "The map gives each visitor one marker at a different location.")
	await _snapshot("02-people-map")
	await _key(KEY_ESCAPE)
	await _button(ui.hud.neighbors_button)
	var panel: Control = ui.panel_manager.management_panel_instance
	var journal: Control = panel.neighbor_journal
	await _button(journal.roster.get_node(TAO))
	_expect(state.next_visitor_day(TAO) == 34 and "第 34 天" in journal.where.text
		and "西市绸摊" in journal.where.text, "The cloth merchant has a definite date and place while the handoff is pending.")
	await _snapshot("03-next-visit")
	await _button(panel.get_node("CloseButton"))
	print("HANDOFF_APPOINTMENTS day=", state.current_day, " regular=", world.current_visitor().name,
		" handoff=", guide.data.name, " next_tao=", state.next_visitor_day(TAO))
	return not failed

func _see_market_trip() -> bool:
	await _sleep_through(34)
	_expect(world.current_visitor().name == TAO and world.handoff_visitor() != null, "The promised visitor comes on the next morning.")
	await _time_at(0.44)
	_expect(world.neighbor_actor(TAO) == null and world.handoff_visitor() != null and "西市绸摊" in ui.hud.visitor_label.text
		and "蒲宁" in ui.hud.visitor_label.text, "The merchant travels west and the guide remains at the bamboo path.")
	await _walk(world.player, [Vector2(66, 67)])
	if not await _road_to_market():
		return false
	var market := tree.current_scene
	if not _expect(market.silk_guest != null and market.sample.visible, "Find Tao Xin and the displayed sample in the market."):
		return false
	await _approach_tao(market)
	if not await _talk(market, "离开", "04-market-visit"):
		return false
	print("HANDOFF_MARKET day=", state.current_day, " clock=", state.day_watch_label(), " pending=", state.ravine_handoff_ready())
	await Campaign.walk_to_market_exit(tree, market)
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return false
	_estate()
	return not failed

func _deliver_journal() -> bool:
	await _button(ui.hud.neighbors_button)
	var panel: Control = ui.panel_manager.management_panel_instance
	var journal: Control = panel.neighbor_journal
	await _button(journal.roster.get_node(GUIDE))
	_expect("等交手记" in journal.where.text and journal.locate_button.visible, "The guide's page shows the handoff and offers directions.")
	await _button(journal.locate_button)
	var guide: Visitor = world.neighbor_actor(GUIDE)
	_expect(ui.directions.destination().point == guide.position and not panel.visible, "Directions point to the guide at the bamboo path.")
	await _walk(world.player, [Vector2(-181, 0), Vector2(-181, 67), Vector2(19, 67), Vector2(19, 142),
		Vector2(37, 214), guide.global_position + Vector2(0, 16)])
	if not await _guide_choice("交溪行手记", "05-handoff"):
		return false
	_expect(state.ravine_journal.garden_day == 34 and world.get_node("HerbGarden").visible
		and guide.activity == VisitorData.VisitActivity.HERBS, "Delivery establishes a garden and starts the guide's walk there.")
	await _time_at(0.44)
	if not await _save_and_continue():
		return false
	guide = world.neighbor_actor(GUIDE)
	_expect(guide != null and guide.visit_location() == "竹径药圃" and VisitorData.SILK_MARKET_PLACE in world.silk_trip_note(),
		"Same-day continue restores the guide at the garden and the merchant at the market.")
	return not failed

func _recruit_guide() -> void:
	var guide: Visitor = world.neighbor_actor(GUIDE)
	await _walk(world.player, [Vector2(29, 241), Vector2(64, 241), guide.global_position + Vector2(0, 17)])
	if not await _guide_choice("招募"):
		return
	_expect(world.neighbor_actor(GUIDE) is Retainer and VisitorData.SILK_MARKET_PLACE in world.silk_trip_note(),
		"Recruiting the extra guide preserves the merchant's appointment.")
	if not await _save_and_continue():
		return
	_expect(state.last_recruit_day == 34 and world.neighbor_actor(GUIDE) is Retainer
		and VisitorData.SILK_MARKET_PLACE in world.silk_trip_note(), "Continue preserves both the resident and the ordinary visit.")
	await _time_at(VisitorData.SILK_MARKET_RETURN + 0.03)
	var tao: Visitor = world.neighbor_actor(TAO)
	if not _expect(tao != null and tao.visit_location() == "南路亭" and world.active_visitors.size() == 1,
			"Tao Xin returns to the pavilion as scheduled after the handoff and recruitment."):
		return
	tao.interact()
	await tree.process_frame
	var dialog: Control = ui.get_node_or_null("Control/DialoguePanel")
	var recruit: Button = dialog.options_container.get_child(2)
	_expect(recruit.text.begins_with("招募") and recruit.disabled, "The existing single-recruit limit still applies.")
	await _key(KEY_ESCAPE)
	print("HANDOFF_RESULT day=", state.current_day, " garden=", state.ravine_journal.garden_day,
		" retained=", world.neighbor_actor(GUIDE) is Retainer, " ordinary=", tao.visit_location())

func _guide_choice(prefix: String, frame := "") -> bool:
	await _key(KEY_E)
	var dialog: Control = ui.get_node_or_null("Control/DialoguePanel")
	if not _expect(dialog != null and dialog.name_label.text == GUIDE, "Talk to the guide using the normal interact key."):
		return false
	if not frame.is_empty():
		await _snapshot(frame)
	for choice: Button in dialog.options_container.get_children():
		if choice.text.begins_with(prefix) and not choice.disabled:
			await _button(choice)
			return true
	return _expect(false, "The guide offers " + prefix)

func _save_and_continue() -> bool:
	if not _expect(state.save_game() == OK, "Save the current appointment and story state."):
		return false
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	return await _continue_estate()

func _continue_estate() -> bool:
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE, "Continue the saved estate."):
		return false
	_estate()
	return true

func _check_previous_save() -> void:
	if not await _continue_estate():
		return
	var guide: Visitor = world.neighbor_actor(GUIDE)
	_expect(state.current_day == 34 and state.ravine_handoff_ready() and guide != null and guide.visit_location() == "南边竹径"
		and VisitorData.SILK_MARKET_PLACE in world.silk_trip_note(), "The previous save retains the completed pages and restores the merchant's regular itinerary.")
	print("HANDOFF_LEGACY day=", state.current_day, " pages=", state.ravine_journal.count(), " merchant=", world.silk_trip_note())
