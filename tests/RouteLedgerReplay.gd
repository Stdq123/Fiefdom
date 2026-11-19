extends "res://tests/RouteGoalsReplay.gd"

const EstateRecord := preload("res://scripts/EstateRecordStand.gd")

func run_ledger(host: SceneTree, captures := "", previous := false) -> void:
	tree = host
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the route ledger replay."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = captures
	seed(1979)
	tree.root.notify_mouse_entered()
	if previous:
		await _resume_previous()
	else:
		await _traditional_desk()
		if failures == 0:
			await _reformed_desk()
	tree.paused = false
	tree.unload_current_scene()
	for stream in tree.root.get_node("AudioManager").get_children():
		if stream is AudioStreamPlayer:
			stream.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(0 if failures == 0 else 1)

func _desk() -> EstateRecord:
	return world.get_node("Scenery/EndingRecord")

func _walk_to_desk() -> void:
	await Campaign.walk_estate_road_to(tree, world, _desk().global_position + Vector2(0, 16))
	await tree.process_frame

func _read_desk() -> bool:
	if not _expect(world.player._nearest_interactable() == _desk(), "The visible ledger can be reached from the road."):
		return false
	await _key(KEY_E)
	var book: Control = ui.route_goals
	var sheet: Control = book.modal.get_node("Center/Ledger")
	var has_entry: bool = not state.route_harvest.is_empty()
	return _expect(book.modal.visible and tree.paused and tree.root.get_visible_rect().encloses(sheet.get_global_rect())
		and book.harvest_entry.visible == has_entry,
		"Reading the desk opens a fitted ledger, with a harvest line only once there is an entry.")

func _check_ledger_on_map() -> void:
	await _key(KEY_M)
	var map: Control = ui.estate_map
	var desk := _desk()
	var matches := func(entry: Dictionary) -> bool:
		return (entry.title == desk.record_name and entry.point == world.to_local(desk.global_position)
			and "收成与目标" in entry.detail)
	_expect(map.modal.visible and map.places.any(matches), "The survey describes the ledger at the actual desk before goals are ready.")
	await _key(KEY_ESCAPE)

func _traditional_desk() -> void:
	if not await _choose_route(state.TaxReformChoice.TRADITIONAL, 1):
		return
	_expect(_desk().visible and _desk().record_name == "贡簿" and not _desk().ready_to_present
		and not _desk().harvest_mark, "Confirming the traditional route puts a working tribute book in the court.")
	await _check_ledger_on_map()
	await _walk_to_desk()
	await _capture("01-traditional-desk-open")
	if not await _read_desk():
		return
	await _capture("02-before-tribute")
	await _key(KEY_ESCAPE)
	await Campaign.walk_estate_road_to(tree, world, world.to_global(Vector2(109, 150)))
	await _click_plot(PRIVATE)
	_expect(state.route_harvest.is_empty() and not _desk().harvest_mark and state.king_storage == 12,
		"The traditional book only starts with a new public contribution.")
	await _click_plot(SECOND)
	var recorded: Dictionary = state.route_harvest.duplicate()
	_expect(recorded.get("crop") == "millet" and recorded.get("field") == 1 and recorded.get("worker") == ""
		and recorded.get("amount") == 1 and state.king_storage == 13 and _desk().harvest_mark,
		"The public plot records its actual harvest and places a filled sack next to the tribute book.")
	await _click_plot(FIRST)
	_expect(state.route_harvest == recorded, "The next public harvest leaves the opening entry intact.")
	await _walk_to_desk()
	await _capture("03-tribute-sack")
	if not await _read_desk():
		return
	_expect("你从井田 2 收下 1 份黍，入国库" in ui.route_goals.harvest_entry.text,
		"The court ledger names the field, crop and contribution.")
	await _capture("04-tribute-entry")
	print("ROUTE_LEDGER_TRADITIONAL day=", state.current_day, " entry=", recorded, " tribute=", state.king_storage)
	await _key(KEY_ESCAPE)

func _reformed_desk() -> void:
	if not await _choose_route(state.TaxReformChoice.REFORMED, 1):
		return
	_expect(_desk().visible and _desk().record_name == "新税册" and not _desk().harvest_mark,
		"Confirming reform opens the new register at the pavilion before harvesting.")
	await _check_ledger_on_map()
	var worker: Retainer = world.neighbor_actor(VisitorData.WATER_GUIDE)
	if not _expect(worker != null and state.assign_duty(worker.data, RetainerData.Duty.HARVEST), "Assign Shi Mo to field harvest."):
		return
	state.assign_retainer_plot(worker.data, PRIVATE)
	worker.set_physics_process(true)
	for step in 1500:
		if not state.route_harvest.is_empty():
			break
		await tree.physics_frame
	worker.set_physics_process(false)
	var recorded: Dictionary = state.route_harvest.duplicate()
	if not _expect(recorded.get("worker") == VisitorData.WATER_GUIDE and recorded.get("crop") == "wheat"
		and recorded.get("amount") == 2 and recorded.get("copper") == 12 and recorded.get("levy") == 4
		and state.private_harvest_total == 16 and state.money == 99 and _desk().harvest_mark,
		"Live retainer harvest records the real worker, amount and tax while crediting the usual stock and coin."):
		return
	await Campaign.walk_to(tree, world.player, worker.global_position + Vector2(0, 13))
	await _key(KEY_E)
	var dialog: Control = ui.get_node_or_null("Control/DialoguePanel")
	if not _expect(dialog != null and "麦已收进私仓" in dialog.text_label.text and "南路亭" in dialog.text_label.text,
		"The worker talks about the crop he just gathered and where he recorded it."):
		return
	await _capture("05-worker-remembers")
	await _key(KEY_ENTER)
	await _walk_to_desk()
	await _capture("06-register-sack")
	if not await _read_desk():
		return
	var text: String = ui.route_goals.harvest_entry.text
	_expect("石墨从井田 1 收下 2 份麦" in text and "实扣税 4 铜钱" in text and "实收 12 铜钱" in text,
		"The read register agrees with the recorded harvest and the cash movement.")
	await _capture("07-tax-entry")
	await _key(KEY_ESCAPE)
	_expect(state.save_game() == OK, "Save the filed harvest.")
	await _title()
	await _button(tree.current_scene.continue_button)
	await _estate()
	_expect(state.route_harvest == recorded and state.route_harvest_note() == text and _desk().harvest_mark,
		"Continue preserves the same filed entry and sack.")
	print("ROUTE_LEDGER_REFORM day=", state.current_day, " entry=", recorded, " copper=", state.money)

func _resume_previous() -> void:
	await _title()
	if not _expect(tree.current_scene.continue_button.visible, "A previous build supplied a real post-council save."):
		return
	await _button(tree.current_scene.continue_button)
	await _estate()
	if not _expect(state.current_day == 53 and state.private_harvest_total == 16 and state.money == 99
		and state.route_harvest.is_empty() and _desk().visible and not _desk().harvest_mark,
		"Continue preserves known old-route totals with an empty harvest entry."):
		return
	await _walk_to_desk()
	if not await _read_desk():
		return
	await _capture("08-previous-accounts")
	await _key(KEY_ESCAPE)
	var worker: Retainer = world.neighbor_actor(VisitorData.FIELD_KEEPER)
	state.assign_duty(worker.data, RetainerData.Duty.HARVEST)
	state.assign_retainer_plot(worker.data, SECOND)
	await Campaign.walk_estate_road_to(tree, world, world.get_node("WestMarketGate").global_position + Vector2(18, 0))
	await Campaign.walk_through_gate(tree, &"ui_left", 45)
	if not _expect(tree.current_scene.scene_file_path == state.WEST_ROAD_SCENE, "Walk through the west gate before the filed harvest."):
		return
	for step in 900:
		if not state.route_harvest.is_empty():
			break
		await tree.physics_frame
	var recorded: Dictionary = state.route_harvest.duplicate()
	_expect(recorded.get("worker") == VisitorData.FIELD_KEEPER and recorded.get("field") == 1
		and recorded.get("crop") == "millet" and state.private_harvest_total > 16 and state.money > 99,
		"A fresh harvest while the player is outside fills the book with the actual worker from the old estate.")
	await Campaign.walk_through_gate(tree, &"ui_right", 80)
	if not _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE, "Walk back through the gate to check the new entry."):
		return
	await _estate()
	await _walk_to_desk()
	if not await _read_desk():
		return
	await _capture("09-resumed-register")
	print("ROUTE_LEDGER_PREVIOUS day=", state.current_day, " entry=", recorded, " copper=", state.money)
