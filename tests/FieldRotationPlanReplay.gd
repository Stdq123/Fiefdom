extends "res://tests/FieldPlanningReplay.gd"

var capture_path := ""

func run(host: SceneTree) -> void:
	tree = host
	capture_dir = capture_path
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated rotation profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	tree.root.notify_mouse_entered()
	seed(323)
	if legacy:
		await _continue_fixed_plans()
	elif await _prepare_rotation() and await _choose_plots() and await _first_harvest():
		if await _connect_water_and_visit_market():
			await _second_harvest()
	tree.unload_current_scene()
	for stream in tree.root.get_node("AudioManager").get_children():
		if stream is AudioStreamPlayer:
			stream.stop()
	await tree.process_frame
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func _prepare_rotation() -> bool:
	if not await _fixture():
		return false
	state.king_storage = 1
	state.food_storage = 36
	state.active_crops.erase(PUBLIC)
	state.tilled_cells[FIRST] = true
	state.tilled_cells[SECOND_PRIVATE] = true
	state.fertile_cells[FIRST] = true
	state.field_rotation.promise_day = 3
	state.field_rotation.beans_day = 5
	state.field_rotation.harvest_day = 8
	state.field_rotation.field_number = 1
	state.field_rotation.crop_id = "wheat"
	if not _expect(state.save_game() == OK and state.load_game() == OK, "Load the two-field fixture with Qu Bo waiting to record the harvest."):
		return false
	await tree.scene_changed
	_estate()
	var panel := await _management()
	await _select(panel, "millet")
	_expect(not panel.rotate_seed.visible, "Rotation is earned by signing the book.")
	await _button(panel.get_node("CloseButton"))
	var keeper: Node2D = world.neighbor_actor(VisitorData.FIELD_KEEPER)
	if not await _interact_with(keeper, "一起记进轮作簿"):
		return false
	var book := world.get_node("FieldRotationBook") as Node2D
	return _expect(state.field_rotation.signed_day == 32 and book.visible, "Signing creates the book on the estate.") \
		and await _interact_with(book, "安排轮作", "01-rotation-book")

func _interact_with(actor: Node2D, action: String, frame := "") -> bool:
	await Campaign.walk_to(tree, world.player, actor.global_position + Vector2(0, 15))
	await _key(KEY_E)
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialog != null, "Open a conversation at " + actor.name):
		return false
	if not frame.is_empty():
		await _snapshot(frame)
	for choice: Button in dialog.options_container.get_children():
		if choice.text == action:
			await _button(choice)
			return true
	return _expect(false, "The dialogue offers " + action)

func _choose_plots() -> bool:
	var panel: Control = ui.panel_manager.management_panel_instance
	if not _expect(panel.visible and panel.rotate_seed.visible and panel.tabs.current_tab == 0,
			"The book opens the field management controls."):
		return false
	for seed_id in ["beans", "mulberry"]:
		await _select(panel, seed_id)
		_expect(panel.rotate_seed.disabled, "The selected crop cannot be alternated with beans: " + seed_id)
	await _select(panel, "millet")
	await _button(panel.rotate_seed)
	await _button(_plot(panel, FIRST))
	await _select(panel, "rice")
	await _button(_plot(panel, RICE))
	_expect("下茬黍" in _plot(panel, FIRST).text and "下茬菽" in _plot(panel, RICE).text
		and "收菽留肥" in panel.seed_timing.text, "The two plots preview different next crops based on fertility.")
	await _snapshot("02-first-field-plans")
	await _field(panel, 1)
	await _select(panel, "wheat")
	_expect(panel.apply_private_plan.text == "安排私田 · 1 格", "The batch selects the one prepared private plot in the second field.")
	await _button(panel.apply_private_plan)
	_expect(state.field_seed_plans.get(SECOND_PRIVATE) == FieldSeedPlan.with_beans("wheat")
		and not state.field_seed_plans.has(PUBLIC) and not state.field_seed_plans.has(ORCHARD),
		"Batch rotation skips the other public center and the mulberry tree.")
	var duty: OptionButton = panel.retainer_list_container.get_child(1).duty_picker
	duty.item_selected.emit(duty.get_item_index(RetainerData.Duty.HARVEST))
	await _button(panel.get_node("CloseButton"))
	return not failed

func _seed_at(cell: Vector2i) -> String:
	return state.active_crops.get(cell, {}).get("id", "")

func _ready_to_sleep() -> bool:
	for cell: Vector2i in [FIRST, RICE, SECOND_PRIVATE]:
		if not state.active_crops.has(cell) or state.field_crop_is_ripe(cell) or state.field_crop_is_dry(cell):
			return false
	return true

func _night() -> bool:
	var next_day: int = state.current_day + 1
	var food_after: int = state.food_storage - state.retainer_food_cost()
	_expect(state.current_stamina == state.max_stamina, "Delegated work uses no player stamina.")
	await _button(ui.sleep_button)
	await tree.create_timer(1.20).timeout
	return _expect(state.current_day == next_day and state.food_storage == food_after,
		"Ordinary sleep advances one day and uses the posted household rations.")

func _first_harvest() -> bool:
	if not await _wait_for(_ready_to_sleep, "The keeper sows and waters all three rotation plots.", 18.0):
		return false
	_expect(_seed_at(FIRST) == "millet" and _seed_at(RICE) == "beans" and _seed_at(SECOND_PRIVATE) == "beans",
		"A fertile public plot starts with millet, and the two other plots start with beans.")
	for night in 2:
		if night > 0 and not await _wait_for(_ready_to_sleep, "The keeper waters the second day's young crops."):
			return false
		if not await _night():
			return false
	var first_cycle := func() -> bool:
		return _seed_at(FIRST) == "beans" and _seed_at(RICE).is_empty() and state.fertile_cells.has(RICE) \
			and _seed_at(SECOND_PRIVATE) == "wheat"
	if not await _wait_for(first_cycle, "Harvest ends the millet and bean stages and starts the next crops.", 18.0):
		return false
	_expect(state.king_storage == 3 and not state.fertile_cells.has(FIRST) and state.crop_stock.count("beans") == 2
		and state.planned_field_seed(RICE).is_empty(), "Public millet contributes two units. Private beans stay in stock and dry rice waits.")
	var panel := await _management()
	await _field(panel, 0)
	_expect("待渠水" in _plot(panel, RICE).text and "下茬黍" in _plot(panel, FIRST).text,
		"The field overview shows blocked rice and the crop following the new beans.")
	await _snapshot("03-rice-waits-for-water")
	await _button(panel.get_node("CloseButton"))
	print("FIELD_ROTATION_FIRST day=", state.current_day, " tribute=", state.king_storage,
		" beans=", state.crop_stock.count("beans"), " rice_waiting=", state.planned_field_seed(RICE).is_empty())
	return not failed and await _resume_plan()

func _connect_water_and_visit_market() -> bool:
	_expect(state.field_seed_plans.get(RICE) == FieldSeedPlan.with_beans("rice")
		and state.fertile_cells.has(RICE) and _seed_at(RICE).is_empty(), "Continue retains the rotation's unplanted rice phase.")
	# Leave the first rice sowing to the away simulation so the market report can prove it happened there.
	for worker: Retainer in world.retainer_instances.values():
		worker.set_physics_process(false)
	await Campaign.walk_to(tree, world.player, Vector2(66, 98))
	await _button(ui.channel_button)
	var tiles: TileMapLayer = world.tile_map
	for cell in [Vector2i(2, 5), Vector2i(3, 5)]:
		await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))
	await _key(KEY_ESCAPE)
	if not _expect(state.irrigation.supplies(RICE), "Build the two channel cells through the field controls."):
		return false
	for point: Vector2 in [Vector2(66, 67), Vector2(-181, 67), Vector2(-181, 0), Vector2(-270, -21)]:
		await Campaign.walk_to(tree, world.player, point)
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return false
	if not await _wait_for(func() -> bool: return _seed_at(RICE) == "rice",
			"The keeper sows the rotated rice while the player is in the market.", 15.0):
		return false
	_expect(state.away_field_report.sown == 1 and state.active_crops[RICE].growth_nights == 3,
		"The away report counts one sowing using summer rice growth.")
	print("FIELD_ROTATION_AWAY day=", state.current_day, " sown=", state.away_field_report.sown,
		" crop=", _seed_at(RICE), " nights=", state.active_crops[RICE].growth_nights)
	await Campaign.walk_to_market_exit(tree, tree.current_scene)
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return false
	_estate()
	return not failed

func _second_harvest() -> void:
	for night in 3:
		if not await _wait_for(_ready_to_sleep, "Water both fields and replace harvested crops before sleep.", 18.0) or not await _night():
			return
	var planted_again := func() -> bool: return _seed_at(RICE) == "beans" and _seed_at(SECOND_PRIVATE) == "beans"
	if not await _wait_for(planted_again, "Both private fields return to beans after the cash crops.", 18.0):
		return
	_expect(state.king_storage == 4 and state.crop_stock.count("rice") == 2 and state.crop_stock.count("wheat") == 2
		and state.current_stamina == state.max_stamina,
		"Across five nights, both rotating private harvests double, the public center contributes again, and the player spends no farming stamina.")
	var panel := await _management()
	await _field(panel, 0)
	await _snapshot("04-back-to-beans")
	await _select(panel, "")
	await _button(_plot(panel, RICE))
	_expect(_seed_at(RICE) == "beans" and not state.field_seed_plans.has(RICE)
		and state.field_seed_plans.get(SECOND_PRIVATE) == FieldSeedPlan.with_beans("wheat"), "Cancelling a plan leaves the current crop and other field alone.")
	print("FIELD_ROTATION_RESULT day=", state.current_day, " tribute=", state.king_storage,
		" rice=", state.crop_stock.count("rice"), " wheat=", state.crop_stock.count("wheat"),
		" grain=", state.food_storage, " manual_farming_clicks=0")

func _continue_fixed_plans() -> void:
	if not await _continue_from_title():
		return
	var panel := await _management()
	_expect(state.field_rotation.signed_day == 8 and panel.rotate_seed.visible and not panel.rotate_seed.button_pressed
		and state.field_seed_plans.get(FIRST) == "millet" and state.field_seed_plans.get(PUBLIC) == "sorghum"
		and state.planned_field_seed(FIRST) == "millet", "Fixed plans saved by the prior executable stay fixed.")
	print("FIELD_ROTATION_LEGACY signed=", state.field_rotation.signed_day, " plans=", state.field_seed_plans)
