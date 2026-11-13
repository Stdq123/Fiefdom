extends "res://tests/WestMarketReplay.gd"

const PRIVATE := Vector2i(6, 5)

var legacy := false
var capture_path := ""
var world: Node2D
var ui: CanvasLayer
var keeper: Retainer
var first_evening_line := ""

func _bind_estate() -> bool:
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE, "The real estate is loaded."):
		return false
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	keeper = world.neighbor_actor(VisitorData.FIELD_KEEPER) as Retainer
	await tree.process_frame
	return true

func _plot(cell: Vector2i) -> void:
	var tiles := world.tile_map as TileMapLayer
	for step in 2:
		await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))

func _move_pointer_off_the_field() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(12, tree.root.get_visible_rect().get_center().y)
	motion.global_position = motion.position
	tree.root.push_input(motion, true)
	await tree.process_frame

func _settled(actor: Retainer) -> bool:
	for frame in 540:
		if actor.resting_at_pavilion():
			return _expect(actor.position == world.pavilion_rest.seat_for(actor.data), "The resident settles on the assigned mat.")
		await tree.physics_frame
	return _expect(false, actor.data.name + " reaches the pavilion after work.")

func _check_first_walk() -> bool:
	_expect(not world.pavilion_rest.visible and keeper.pavilion_note().is_empty(), "The first morning starts with the keeper at his duty station.")
	keeper.set_physics_process(false)
	await _plot(PUBLIC)
	if not _expect(state.field_crop_is_dry(PUBLIC), "Sow a dry public plot before the change of watch."):
		return false
	await _time_at(0.69)
	keeper.set_physics_process(true)
	var worked := false
	var walked_lane := false
	for frame in 570:
		worked = worked or keeper.current_state == Retainer.State.WORK
		if keeper.pavilion_note() == "正往南路亭" and keeper.sprite.walking and keeper.position.distance_to(Vector2(46, 177)) < 10.0:
			walked_lane = true
			await _snapshot("01-walk-to-pavilion")
			break
		await tree.physics_frame
	if not _expect(worked and walked_lane and state.active_crops[PUBLIC].watered,
		"He waters the queued crop before taking the south lane to the pavilion.") or not await _settled(keeper):
		return false
	await _plot(PRIVATE)
	for frame in 270:
		if state.active_crops.get(PRIVATE, {}).get("watered", false):
			break
		await tree.physics_frame
	if not _expect(state.active_crops.get(PRIVATE, {}).get("watered", false), "A new dry plot brings him back from the mat to work."):
		return false
	print("PAVILION_EVENING_WORK queued_watered=true new_plot_watered=true used_south_lane=true")
	return await _settled(keeper)

func _first_night() -> bool:
	await Campaign.walk_estate_road_to(tree, world, keeper.global_position + Vector2(-16, 16))
	await _key(KEY_E)
	var dialogue := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialogue != null and dialogue.name_label.text == VisitorData.FIELD_KEEPER
		and "南路亭" in dialogue.context_label.text, "Speak to the keeper at the evening mat."):
		return false
	first_evening_line = dialogue.text_label.text
	await _key(KEY_ESCAPE)
	var food: int = state.food_storage
	var table: PavilionRest = world.pavilion_rest
	await _walk(world.player, [table.position + PavilionRest.APPROACH])
	await _key(KEY_E)
	var plan := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(plan != null and state.food_storage == food and "1 份" in plan.need.text,
		"The table opens the same ration plan without spending food."):
		return false
	await _snapshot("02-table-rations")
	await _button(plan.get_node("%Sleep"))
	await tree.create_timer(1.18).timeout
	_expect(state.current_day == 2 and not table.visible and keeper.pavilion_note().is_empty()
		and state.food_storage == food - 1 and state.active_crops[PUBLIC].age == 1,
		"Sleep at the table uses the normal rations and crop growth and restores the morning duty.")
	print("PAVILION_EVENING_DAWN day=", state.current_day, " food=", food, "->", state.food_storage, " crop_age=", state.active_crops[PUBLIC].age)
	return true

func _recruit_and_settle() -> bool:
	# Supply recruitment reputation so the second evening can cover different jobs.
	state.reputation = state.balance.recruit_reputation_requirement
	var guest: Visitor = world.current_visitor_actor()
	if not _expect(guest != null and guest.data.name == VisitorData.ROAD_KEEPER, "Ji Qing visits on the second morning."):
		return false
	await _walk(world.player, [guest.position + Vector2(0, 12)])
	await _key(KEY_E)
	var dialogue := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialogue != null and dialogue.name_label.text == VisitorData.ROAD_KEEPER, "Recruit through the normal conversation."):
		return false
	await _button(dialogue.options_container.get_child(2))
	var teacher := world.neighbor_actor(VisitorData.ROAD_KEEPER) as Retainer
	if not _expect(teacher != null and state.assign_duty(teacher.data, RetainerData.Duty.TEACH), "Put the recruited neighbor on lessons."):
		return false
	var guard_data := RetainerData.new(VisitorData.EAST_WATCHER, "弓士", RetainerData.School.MILITARY)
	guard_data.duty = RetainerData.Duty.GUARD
	state.retainers.append(guard_data)
	tree.root.get_node("GameEvents").retainer_recruited.emit(guard_data)
	var guard: Retainer = world.retainer_instances[guard_data]
	await _time_at(0.85)
	if not await _settled(teacher) or not await _settled(keeper):
		return false
	_expect(teacher.position != keeper.position and guard.position == guard.home_position and guard.pavilion_note().is_empty(),
		"Two named residents use separate places while the guard keeps the east road.")
	print("PAVILION_EVENING_RESIDENTS keeper=", keeper.position, " teacher=", teacher.position, " guard=", guard.position)
	return true

func _evening_conversation() -> bool:
	await _button(ui.hud.neighbors_button)
	var management: Control = ui.panel_manager.management_panel_instance
	var journal: Control = management.neighbor_journal
	await _button(journal.roster.get_node(VisitorData.ROAD_KEEPER))
	_expect("南路亭 · 灯下歇脚" in journal.where.text, "The journal reports the actual evening location.")
	await _button(journal.locate_button)
	_expect(not management.visible and ui.directions.tracked_neighbor == VisitorData.ROAD_KEEPER, "The journal can guide the player to his mat.")
	await _button(ui.hud.map_button)
	var map: Control = ui.estate_map
	await _button(map.tabs.get_node("People"))
	var place: Array = map.places.filter(func(entry: Dictionary) -> bool: return entry.title == PavilionRest.PLACE)
	var person: Array = map.people.filter(func(entry: Dictionary) -> bool: return entry.title == VisitorData.ROAD_KEEPER)
	_expect(place.size() == 1 and person.size() == 1 and "灯下歇脚" in person[0].detail
		and person[0].point == world.neighbor_actor(VisitorData.ROAD_KEEPER).position,
		"The chart maps the table and the actual position of the seated teacher.")
	await _snapshot("03-evening-map")
	await _button(map.close_button)
	await _button(ui.hud.cancel_directions)
	await Campaign.walk_estate_road_to(tree, world, keeper.global_position + Vector2(-16, 16))
	await _move_pointer_off_the_field()
	await _snapshot("04-pavilion-lanterns")
	await _key(KEY_E)
	var dialogue := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialogue != null and dialogue.name_label.text == VisitorData.FIELD_KEEPER
		and "南路亭" in dialogue.context_label.text and dialogue.text_label.text != first_evening_line,
		"The keeper has a different conversation on the second evening."):
		return false
	await _snapshot("05-evening-conversation")
	await _key(KEY_ESCAPE)
	return true

func _resume_and_travel() -> void:
	await _button(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	if not _expect(settings.save_status.text == "游戏已保存", "Save after the residents have settled."):
		return
	await _button(settings.close_button)
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if not await _bind_estate():
		return
	var teacher := world.neighbor_actor(VisitorData.ROAD_KEEPER) as Retainer
	_expect(state.current_day == 2 and keeper.resting_at_pavilion() and teacher.resting_at_pavilion(), "Continue restores the late-evening positions.")
	await _walk(world.player, [Vector2(-181, 54), Vector2(-181, 0), Vector2(-270, -21)])
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return
	var market := tree.current_scene as Node2D
	await Campaign.walk_to_market_exit(tree, market)
	if not await _cross(&"ui_right", state.ESTATE_SCENE) or not await _bind_estate():
		return
	teacher = world.neighbor_actor(VisitorData.ROAD_KEEPER) as Retainer
	_expect(keeper.resting_at_pavilion() and teacher.resting_at_pavilion() and teacher.position == world.pavilion_rest.seat_for(teacher.data),
		"Returning from the market after dusk restores the same activity.")
	print("PAVILION_EVENING_RETURN day=", state.current_day, " keeper=", keeper.position, " teacher=", teacher.position)
	state.current_day = 6 # Exercise the rainy evening without replaying the prior four days.
	await _time_at(0.88)
	_expect(state.has_rain() and not world.pavilion_rest.visible and not keeper.resting_at_pavilion(), "The outdoor table closes in the rain.")
	state.current_day = 7
	state.raid_day = 7
	await _time_at(0.88)
	_expect(not state.has_rain() and not world.pavilion_rest.visible, "A raid holds the evening gathering.")
	print("PAVILION_EVENING_WEATHER rain_closed=true raid_closed=true")

func _play() -> void:
	capture_dir = capture_path
	await _button(tree.current_scene.continue_button if legacy else tree.current_scene.new_button)
	if not await _bind_estate():
		return
	if legacy:
		var earlier_evening: bool = state.current_day == 1 and state.food_storage == 10
		var teacher := world.neighbor_actor(VisitorData.ROAD_KEEPER) as Retainer
		var previous_evening: bool = (state.current_day == 2 and state.food_storage == 9 and state.retainers.size() == 3
			and state.active_crops.size() == 2 and state.well_fields.size() == 1 and teacher != null
			and teacher.resting_at_pavilion() and teacher.position == world.pavilion_rest.seat_for(teacher.data))
		if not _expect((earlier_evening or previous_evening) and state.day_watch_label() == "戌时"
			and keeper.resting_at_pavilion() and keeper.position == world.pavilion_rest.seat_for(keeper.data),
			"The genuine previous save keeps the evening clock, household and crops at the relocated pavilion."):
			return
		var table: PavilionRest = world.pavilion_rest
		await Campaign.walk_estate_road_to(tree, world, table.global_position + PavilionRest.APPROACH)
		await _key(KEY_E)
		_expect(ui.has_node("Control/NightRationsPanel"), "The table on the new road opens the night plan after continuing the save.")
		await _snapshot("01-legacy-evening-table")
		print("PAVILION_EVENING_LEGACY day=", state.current_day, " watch=", state.day_watch_label(),
			" keeper=", keeper.position, " food=", state.food_storage, " crops=", state.active_crops.size())
		return
	if await _check_first_walk() and await _first_night() and await _recruit_and_settle() and await _evening_conversation():
		await _resume_and_travel()
