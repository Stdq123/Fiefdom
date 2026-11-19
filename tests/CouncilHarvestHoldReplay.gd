extends "res://tests/SowingHoldReplay.gd"

const YOUNG_PRIVATE := Vector2i(4, 4)
const WEST_ROAD := "res://scenes/WestRoad.tscn"

var harvest_mode := "research"

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	state = tree.root.get_node("Global")
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated harvest hold profile."):
		tree.quit(1)
		return
	tree.root.notify_mouse_entered()
	if not FileAccess.file_exists(state.manual_save_path()):
		_write_harvest_fixture()
	await _continue()
	var actor := _stop_worker()
	if harvest_mode == "write":
		await _save_route()
	elif _expect(state.current_day == 48 and state.king_storage == 29 and state.private_harvest_total == 68
			and world.is_crop_ripe(PRIVATE_WHEAT) and state.get("hold_private_harvest") != true,
			"The previous save opens with the harvest policy off and a pending harvest."):
		await _play_harvest_policy(actor, harvest_mode)
	tree.paused = false
	tree.unload_current_scene()
	for stream in tree.root.get_node("AudioManager").get_children():
		if stream is AudioStreamPlayer:
			stream.stop()
	await tree.process_frame
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func _write_harvest_fixture() -> void:
	var save := SNAPSHOT.duplicate(true)
	save.current_day = 48
	save.current_rank = 3
	save.money = 40
	save.well_fields.resize(1)
	save.retainers[0].duty = RetainerData.Duty.STEWARD
	save.retainers[0].assigned_area = "6,5"
	save.active_crops.erase("12,5")
	save.active_crops["4,4"] = {"id": "wheat", "age": 0, "growth_nights": 3}
	save.tilled_cells = ["5,5", "6,5", "5,6", "4,5", "4,4"]
	save.field_seed_plans.clear()
	var fixture := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify(save))
	fixture.close()

func _stop_worker() -> Retainer:
	var actor: Retainer = world.retainer_instances[state.retainers[0]]
	actor.set_physics_process(false)
	return actor

func _play_harvest_policy(actor: Retainer, mode: String) -> void:
	# Let the actor start a real job before opening the modal. Finish one physics tick after closing it.
	actor.global_position = world.to_global(world.get_crop_world_pos(PRIVATE_WHEAT))
	actor.find_work()
	actor.set_physics_process(true)
	for frame in 30:
		await tree.physics_frame
		if actor.current_state == Retainer.State.WORK:
			break
	actor.set_physics_process(false)
	if not _expect(actor.field_job == state.FieldJob.HARVEST and actor.target_grid_pos == PRIVATE_WHEAT
			and actor.current_state == Retainer.State.WORK, "An assigned steward has already reached a ripe private plot."):
		return
	if mode == "research":
		await _check_busy_ledger()
	await _open_book()
	_expect("30.61%" in book.public_result.text and "29.13%" in book.mixed_result.text,
		"The same ledger forecasts both public-first and mixed proceeds.")
	var before := mode == "before"
	if not before:
		if mode == "research":
			var controller = load("res://tests/GamepadReplay.gd").new()
			controller.tree = tree
			controller.pad = tree.root.get_node("GamepadInput")
			tree.root.notify_mouse_exited()
			await controller._click(book.harvest_policy_button, true)
			_expect(controller.failures == 0, "The controller can reach the new policy.")
		else:
			await _button(book.harvest_policy_button)
		_expect(state.hold_private_harvest and "可亲手收" in book.harvest_policy_note.text,
			"The opt-in is visible and explains that the player can still harvest.")
	await _snapshot("01-harvest-forecast")
	await _button(book.close_button)
	actor.work_left = 0.01
	actor.set_physics_process(true)
	await tree.physics_frame
	await tree.physics_frame
	actor.set_physics_process(false)
	if not _expect(world.is_crop_ripe(PRIVATE_WHEAT) != before
			and state.private_harvest_total == (70 if before else 68), "An in-flight job respects the policy at completion."):
		return
	if not before:
		await _save_route()
		_stop_worker()
		_expect(state.hold_private_harvest and world.is_crop_ripe(PRIVATE_WHEAT), "A normal save and reload preserve the hold.")
	if mode == "research":
		await _take_bedtime_path()
	else:
		await _take_west_road(before)
		if not failed and not before:
			await _choose_final(state.TaxReformChoice.TRADITIONAL, "03-tradition")

func _check_busy_ledger() -> void:
	var rank: int = state.current_rank
	var plans: Dictionary = state.field_seed_plans.duplicate()
	var deferred: Dictionary = state.deferred_field_sowing.duplicate()
	state.current_rank = state.Rank.ZHONG_SHI
	state.field_seed_plans[PRIVATE_WHEAT] = "wheat"
	state.field_seed_plans[LEFTOVER_WHEAT] = "wheat"
	state.deferred_field_sowing[LEFTOVER_WHEAT] = true
	await _open_book()
	_expect(book.arts_button.visible and book.sowing_note.visible and book.petition_card.visible
		and book.public_card.visible and book.mixed_card.visible and book.harvest_policy_button.is_visible_in_tree(),
		"The ledger fits while showing both forecasts, promotion, petition, and both field policies.")
	await _snapshot("00-busy-ledger")
	await _button(book.close_button)
	state.current_rank = rank
	state.field_seed_plans.assign(plans)
	state.deferred_field_sowing.assign(deferred)

func _take_west_road(before: bool) -> void:
	await _walk(world.player, [Vector2(-181, 60), Vector2(-181, 0), Vector2(-270, -21)])
	if not await _cross(&"ui_left", WEST_ROAD):
		return
	await tree.create_timer(19.0).timeout
	var report: Dictionary = state.away_field_report
	_expect(state.king_storage == 30 and state.private_harvest_total == (73 if before else 68)
		and report.get("harvested") == (3 if before else 1) and report.get("watered") == 1
		and state.field_crop_is_ripe(LEFTOVER_WHEAT) != before,
		"Off-map work waters private seedlings and harvests the public crop. Private harvest follows the policy.")
	print("COUNCIL_HARVEST_AWAY hold=", not before, " tribute=", state.king_storage, " private=", state.private_harvest_total,
		" harvests=", report.get("harvested"), " watered=", report.get("watered"))
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	_stop_worker()
	await _sleep()
	_expect(state.current_day == 49 and state.tax_council_waiting() != before,
		"On the ordinary council date only the public-first harvest meets the ratio.")
	print("COUNCIL_HARVEST_DAWN day=", state.current_day, " invited=", state.tax_council_waiting(), " private=", state.private_harvest_total)
	await _snapshot("02-council-day")

func _take_bedtime_path() -> void:
	var panel := await _open_night_plan()
	panel.scroll.ensure_control_visible(panel.wait_before_sleep)
	await _button(panel.wait_before_sleep)
	await _button(panel.close_button)
	await _sleep()
	var report: Dictionary = state.last_dawn.get("field_wait", {})
	if not _expect(state.current_day == 49 and state.tax_council_waiting() and state.hold_private_harvest
			and report.get("harvested") == 1 and report.get("stock") == 0 and report.get("watered") == 1
			and state.active_crops[YOUNG_PRIVATE].age == 1 and world.is_crop_ripe(PRIVATE_MILLET),
			"Bedtime settles the public harvest, private watering, and growth while leaving ripe private crops."):
		return
	await _click_plot(PRIVATE_MILLET)
	_expect(state.private_harvest_total == 69 and not world.is_crop_ripe(PRIVATE_MILLET) and state.hold_private_harvest,
		"The player can harvest one private plot with the hold active.")
	print("COUNCIL_HARVEST_BEDTIME day=", state.current_day, " work=", report, " manual_private=", state.private_harvest_total)
	if not await _choose_council_option(state.TaxReformChoice.DELAYED, "02-delay-with-hold"):
		return
	_stop_worker()
	panel = await _open_night_plan()
	panel.scroll.ensure_control_visible(panel.release_private_harvest)
	await _snapshot("03-release-during-research")
	await _button(panel.release_private_harvest)
	_expect(not state.hold_private_harvest and not panel.release_private_harvest.visible
		and state.field_job(state.retainers[0], PRIVATE_WHEAT) == state.FieldJob.HARVEST,
		"The night plan can release the hold during research, when the preparation ledger is closed.")
	await _continue()
	_stop_worker()
	await _sleep()
	await _sleep()
	if _expect(state.current_day == 51 and state.research_choice_pending and state.hold_private_harvest
			and state.private_harvest_total == 69, "The saved research decision keeps the policy until the final verdict."):
		await _choose_final(state.TaxReformChoice.REFORMED, "04-reform")

func _open_night_plan() -> Control:
	await _button(ui.hud.rations_button)
	return ui.get_node("Control/NightRationsPanel")

func _choose_final(choice: int, frame: String) -> void:
	if not await _choose_council_option(choice, frame):
		return
	_stop_worker()
	_expect(not state.hold_private_harvest and state.field_job(state.retainers[0], PRIVATE_WHEAT) == state.FieldJob.HARVEST,
		"A final choice clears the hold in the council save.")
	var forecast: Dictionary = world.council_harvest_forecast(choice)
	var money: int = state.money
	await _wait_for_workers()
	_expect(not world.is_crop_ripe(PRIVATE_WHEAT) and state.private_harvest_total >= 73
		and state.money == money + forecast.copper and (forecast.levy > 0) == (choice == state.TaxReformChoice.REFORMED),
		"After the verdict the worker harvests again and settles the chosen tax treatment.")
	print("COUNCIL_HARVEST_FINAL day=", state.current_day, " choice=", choice, " private=", state.private_harvest_total,
		" copper=", state.money - money, " levy=", forecast.levy)
