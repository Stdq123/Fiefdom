extends "res://tests/PlannedSowingReplay.gd"

const BEANS := Vector2i(5, 4)
const BARE := Vector2i(6, 4)
const WET_RICE := Vector2i(4, 5)
const DRY_RICE := Vector2i(4, 4)
const FALLOW := Vector2i(5, 6)
const FAR_PLAN := Vector2i(10, 6)
const SECOND_FIELD := Vector2i(9, 5)
const EXPECTED := {PUBLIC: "millet", BEANS: "beans", BARE: "wheat", WET_RICE: "rice"}

var pad: RefCounted

func _staged_estate(rain: bool) -> bool:
	if not _expect(state.start_new_game() == OK, "Start an isolated estate for the preparation comparison."):
		return false
	await tree.scene_changed
	state.current_day = 3
	if rain:
		for day in range(1, 100):
			if state.has_rain(day):
				state.current_day = day
				break
	state.current_rank = state.Rank.ZHONG_SHI
	state._update_max_well_fields()
	state.king_storage = 1
	state.quest_progress = 1
	state.food_storage = 24
	state.retainers.clear()
	if not _expect(state.add_well_field(SECOND_FIELD), "Use a valid second field position."):
		return false
	for _night in state.RECLAMATION_NIGHTS:
		state.advance_reclamation(1)
	state.tech_unlocked.irrigation = true
	var channels: Dictionary[Vector2i, bool] = {Vector2i(2, 5): true, Vector2i(3, 5): true}
	state.irrigation.restore(Vector2i(1, 5), channels)
	for cell in [PUBLIC, BEANS, WET_RICE, DRY_RICE, RESTING, MULBERRY]:
		state.tilled_cells[cell] = true
	state.field_rotation.promise_day = 1
	state.field_rotation.beans_day = 2
	state.field_rotation.harvest_day = 3
	state.field_rotation.field_number = 1
	state.field_rotation.crop_id = "wheat"
	state.field_rotation.signed_day = 3
	state.set_field_seed_plan(PUBLIC, "millet")
	state.set_field_seed_plan(BEANS, FieldSeedPlan.with_beans("wheat"))
	state.set_field_seed_plan(BARE, "wheat")
	state.set_field_seed_plan(WET_RICE, "rice")
	state.set_field_seed_plan(DRY_RICE, "rice")
	state.set_field_seed_plan(RESTING, "hemp")
	state.set_field_sowing_deferred(RESTING, true)
	state.set_field_seed_plan(FAR_PLAN, "hemp")
	if not _expect(state.sow_field_crop(MULBERRY, "mulberry"), "Keep a standing perennial in the well."):
		return false
	state.active_crops[MULBERRY].age = state.active_crops[MULBERRY].growth_nights
	tree.change_scene_to_file(state.ESTATE_SCENE)
	await tree.scene_changed
	await _estate()
	return true

func _press(button: Button) -> void:
	if pad:
		await pad._click(button)
	else:
		await _button(button)

func _aim_plot(cell: Vector2i) -> void:
	if pad:
		await pad._aim(_point(cell))
	else:
		await _pointer(_point(cell))

func _hold_batch(held: bool) -> void:
	if pad:
		pad._axis(JOY_AXIS_TRIGGER_LEFT, 1.0 if held else 0.0)
	elif held:
		Input.action_press(KeyBindings.FILL)
	else:
		Input.action_release(KeyBindings.FILL)
	await tree.process_frame
	await tree.process_frame

func _confirm(cell: Vector2i) -> void:
	if pad:
		await pad._tap(JOY_BUTTON_A)
	else:
		await _batch(cell)

func _prepare_batch(cost: int, watering: int, rain: bool) -> bool:
	await _press(ui.hud.farm_status)
	var map: Control = ui.estate_map
	if not _expect(map.modal.visible and "待播 3" in map.sow_route.text and "待翻 1" in map.fields[0].needs
		and "待翻 1" in map.fields[1].needs, "The map shows three tilled plots and one further planned plot in each well."):
		return false
	await _capture("00-field-map")
	await _press(map.sow_route)
	var control: Button = ui.hud.prepare_empty_plots
	if not _expect(world.sow_from_plan and control.is_visible_in_tree() and not control.button_pressed
		and tree.root.get_visible_rect().encloses(control.get_global_rect()), "The ordinary sowing route offers opt-in preparation at the field."):
		return false
	await _press(control)
	if not _expect(control.button_pressed and world.prepare_empty_plots, "The preparation control works with the current input method."):
		return false
	await _aim_plot(BARE)
	await _hold_batch(true)
	var cursor := tiles.get_node("FieldCursor")
	_expect(cursor.caption.visible and cursor.preview_seeds == EXPECTED and "公田 1 · 私田 3" in cursor.label.text
		and "翻地 1 · 播种 4 · 浇水 %d" % watering in cursor.label.text and "%d 体力" % cost in cursor.label.text,
		"The preview names the actual plots, seeds, operations and full stamina cost. %s" % cursor.label.text)
	var caption_rect: Rect2 = cursor.caption.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, cursor.caption.size)
	_expect(tree.root.get_visible_rect().encloses(caption_rect), "The preparation preview fits on screen.")
	await _capture("01-preparation-preview")
	if not rain:
		var stamina: int = state.current_stamina
		state.current_stamina = cost - 1
		GameEvents.stamina_changed.emit(state.current_stamina)
		await tree.process_frame
		await tree.process_frame
		_expect("还差 1" in cursor.label.text, "A shortfall is shown before confirmation.")
		await _capture("02-stamina-shortfall")
		await _confirm(BARE)
		_expect(not state.tilled_cells.has(BARE) and state.active_crops.size() == 1 and state.current_stamina == cost - 1,
			"An unaffordable batch changes no land, crops or stamina.")
		state.current_stamina = stamina
		GameEvents.stamina_changed.emit(stamina)
		await _aim_plot(FALLOW)
		await _confirm(FALLOW)
		_expect(not state.tilled_cells.has(FALLOW) and not state.tilled_cells.has(BARE) and state.current_stamina == stamina,
			"An unplanned position does not trigger an ordinary batch till while preparation is selected.")
		await _aim_plot(BARE)
	await _confirm(BARE)
	await _hold_batch(false)
	await _capture("03-preparation-complete")
	return true

func _check_prepared(stamina: int, cost: int, rain: bool, plans: Dictionary, balance: Vector3i) -> void:
	for cell: Vector2i in EXPECTED:
		var crop: Dictionary = state.active_crops.get(cell, {})
		_expect(crop.get("id") == EXPECTED[cell] and crop.get("age") == 0
			and crop.get("watered") == (cell != WET_RICE and not rain) and not state.field_crop_is_dry(cell),
			"Each planned plot uses the ordinary seed, age, and source of water at %s." % cell)
	_expect(state.tilled_cells.has(BARE) and not state.tilled_cells.has(FALLOW) and not state.tilled_cells.has(FAR_PLAN)
		and state.active_crops.size() == 5 and state.active_crops[MULBERRY].id == "mulberry"
		and state.current_stamina == stamina - cost and state.deferred_field_sowing.has(RESTING)
		and state.field_seed_plans == plans and balance == Vector3i(state.king_storage, state.player_inventory, state.money),
		"The other field, dormant plans, standing crop, and crop accounts are preserved at normal cost.")

func _harvest_prepared() -> void:
	var day: int = state.current_day
	var maximum_nights := 0
	for cell: Vector2i in EXPECTED:
		maximum_nights = maxi(maximum_nights, state.active_crops[cell].growth_nights)
	for night in maximum_nights:
		for cell: Vector2i in EXPECTED:
			if state.field_crop_is_dry(cell):
				await _batch(cell)
				break
		await _sleep()
		if night == 0:
			for cell: Vector2i in EXPECTED:
				_expect(state.current_day == day + 1 and state.active_crops[cell].age == 1,
					"Each crop advances one night through the ordinary sleep flow.")
	for cell: Vector2i in EXPECTED:
		if _expect(state.field_crop_is_ripe(cell), "Preparation reaches a normal harvest."):
			await _click(_point(cell))
	_expect(state.king_storage == 2 and state.private_harvest_total == 3 and state.crop_stock.count("wheat") == 1
		and state.crop_stock.count("rice") == 1 and state.crop_stock.count("beans") == 1 and state.fertile_cells.has(BEANS),
		"The public harvest goes to tribute, the private harvests to stock, and beans leave fertile soil.")
	print("FIELD_PREPARATION_HARVEST day=", state.current_day, " tribute=", state.king_storage, " private=", state.private_harvest_total)

func run_preparation(host: SceneTree, captures := "", variant := "field-preparation") -> void:
	tree = host
	state = tree.root.get_node("Global")
	capture_dir = captures
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated preparation profile."):
		tree.quit(1)
		return
	tree.root.notify_mouse_entered()
	var baseline := variant == "field-preparation-before"
	var rain := variant == "field-preparation-rain"
	if variant in ["field-preparation-pad", "field-preparation-resume"] and not state.latest_saved_game().is_empty():
		await _continue_latest()
	elif not await _staged_estate(rain):
		tree.quit(1)
		return
	if baseline:
		await _save_manually()
		await _continue_latest()
	state.balance.raid_first_day = 10000
	var stamina: int = state.current_stamina
	var plans: Dictionary = state.field_seed_plans.duplicate()
	var balance := Vector3i(state.king_storage, state.player_inventory, state.money)
	var watering := 0 if rain else 3
	var cost := 10 + watering
	if _expect(state.has_rain() == rain and state.irrigation.supplies(WET_RICE) and not state.irrigation.supplies(DRY_RICE)
		and plans.size() == 7 and plans.get(BEANS) == FieldSeedPlan.with_beans("wheat")
		and not state.tilled_cells.has(BARE) and not state.tilled_cells.has(FAR_PLAN),
		"The starting position retains the rotation, one bare plan in each field, and both kinds of rice plot. %s" % [plans]):
		if baseline:
			await _button(ui.hud.sow_from_plan)
			await _click(_point(BARE))
			await _batch(PUBLIC)
			await _batch(PUBLIC)
		else:
			if variant == "field-preparation-pad":
				pad = load("res://tests/GamepadReplay.gd").new()
				pad.tree = tree
				pad.pad = GamepadInput
			await _prepare_batch(cost, watering, rain)
			if pad:
				_expect(pad.failures == 0, "Controller navigation and confirmation succeed.")
		_check_prepared(stamina, cost, rain, plans, balance)
		print("FIELD_PREPARATION method=", variant, " day=", state.current_day, " confirms=", 3 if baseline else 1,
			" plots=", EXPECTED.size(), " stamina=", stamina - state.current_stamina, " watered=", watering,
			" window=", tree.root.size)
		if not baseline and failures == 0:
			await _seed_key(KEY_1)
			_expect(not world.prepare_empty_plots and not ui.hud.prepare_empty_plots.is_visible_in_tree(),
				"Returning to a seed clears the opt-in preparation mode.")
			if not pad and not rain:
				await _harvest_prepared()
	tree.unload_current_scene()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
