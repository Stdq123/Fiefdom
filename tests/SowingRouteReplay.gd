extends "res://tests/PlannedSowingReplay.gd"

const SECOND := Vector2i(9, 5)
const SECOND_PLANS := {SECOND: "beans", SECOND + Vector2i.DOWN: "wheat"}
const UNTILLED := Vector2i(10, 6)

var controller: RefCounted

func _stage_expansion() -> bool:
	# Keep the real opening, and stage a finished second field for the routing comparison.
	state.reputation = state.promotion_reputation()
	if not _expect(state.check_rank_up() and state.add_well_field(SECOND), "Stage the second well on a normal site."):
		return false
	for _night in state.RECLAMATION_NIGHTS:
		state.advance_reclamation(1)
	tree.change_scene_to_file(state.ESTATE_SCENE)
	await tree.scene_changed
	await _estate()
	for cell: Vector2i in SECOND_PLANS:
		await _click(_point(cell))
		state.set_field_seed_plan(cell, SECOND_PLANS[cell])
	state.set_field_seed_plan(UNTILLED, "millet")
	return _expect(state.field_seed_plans.size() == 9 and state.tilled_cells.has(SECOND) and state.tilled_cells.has(SECOND + Vector2i.DOWN)
		and not state.tilled_cells.has(UNTILLED),
		"Two prepared plots and one unworked plan in the second well complete the fixture.")

func _open_field_page() -> Control:
	await _button(ui.hud.farm_status)
	await tree.process_frame
	return ui.estate_map

func _start_sowing_route(capture := "") -> bool:
	var map := await _open_field_page()
	if not _expect(map.modal.visible and tree.paused and map.sow_route.is_visible_in_tree() and not map.sow_route.disabled,
		"The ordinary field page offers the available sowing route."):
		return false
	if not capture.is_empty():
		var counted: int = map.field_tasks.values().count(state.SowingRoute.READY)
		if not _expect("待播 6" in map.sow_route.text and counted == 6 and "待播 4" in map.fields[0].needs
			and "待播 2" in map.fields[1].needs and not map.field_tasks.has(PRIVATE_RICE)
			and not map.field_tasks.has(RESTING) and not map.field_tasks.has(UNTILLED),
			"Both wells map six prepared plots. Reported %s, %s." % [map.sow_route.text, map.field_tasks]):
			return false
		_expect(tree.root.get_visible_rect().encloses(map.sow_route.get_global_rect()), "The new route control fits in the map.")
		await _capture(capture)
	if controller:
		await controller._click(map.sow_route)
	else:
		await _button(map.sow_route)
	return _expect(not tree.paused and not map.modal.visible and world.sow_from_plan and ui.hud.sow_from_plan.button_pressed
		and ui.directions.tracked_plot in MIXED and "按安排播" in ui.directions.destination().get("title", ""),
		"The route restores play, selects the plan and marks an empty plot in the nearest well.")

func _sow_marked(whole_field: bool, capture := "") -> void:
	var cell: Vector2i = ui.directions.tracked_plot
	if controller:
		await controller._aim(_point(cell))
		if whole_field:
			controller._axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
		await tree.process_frame
	else:
		await _pointer(_point(cell))
		if whole_field:
			Input.action_press(KeyBindings.FILL)
		await tree.process_frame
	if not capture.is_empty():
		await _capture(capture)
	if controller:
		await controller._tap(JOY_BUTTON_A)
		controller._axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	elif whole_field:
		await _batch(cell)
		Input.action_release(KeyBindings.FILL)
	else:
		await _click(_point(cell))
	await tree.process_frame

func _guide_two_fields() -> void:
	var stamina: int = state.current_stamina
	var wealth := Vector3i(state.money, state.king_storage, state.player_inventory)
	var plans: Dictionary = state.field_seed_plans.duplicate()
	if not await _start_sowing_route("01-available-sowing-plots"):
		return
	await _seed_key(KEY_1)
	_expect(state.field_route_status == -1 and ui.directions.tracked_plot == null and not world.sow_from_plan,
		"Explicitly choosing a seed cancels the guidance without using the saved crop plan.")
	if not await _start_sowing_route():
		return
	var first: Vector2i = ui.directions.tracked_plot
	await _sow_marked(false)
	if not _expect(state.active_crops.get(first, {}).get("id") == MIXED[first] and ui.directions.tracked_plot in MIXED,
		"A single sowing points to another empty plot in the same well."):
		return
	await _save_manually()
	await _continue_latest()
	await tree.process_frame
	if not _expect(state.field_route_status == state.SowingRoute.READY and world.sow_from_plan
		and ui.directions.tracked_plot in MIXED and ui.directions.tracked_plot != first,
		"Continue restores one of the remaining plans, got status=%d plan=%s plot=%s." % [
			state.field_route_status, world.sow_from_plan, ui.directions.tracked_plot]):
		return
	await _sow_marked(true, "02-remaining-first-field")
	if not _expect(ui.directions.tracked_plot in SECOND_PLANS and world.sow_from_plan,
		"After finishing the first well, the marker continues to the second well."):
		return
	await _capture("03-continue-to-second-field")
	await _sow_marked(true, "04-sowing-the-second-well")
	var crops := MIXED.duplicate()
	crops.merge(SECOND_PLANS)
	for cell: Vector2i in crops:
		_expect(state.active_crops.get(cell, {}).get("id") == crops[cell], "Sow the expected crop at %s." % cell)
	_expect(state.current_stamina == stamina - 12 and state.active_crops.size() == 7 and state.active_crops[MULBERRY].id == "mulberry"
		and Vector3i(state.money, state.king_storage, state.player_inventory) == wealth and state.field_seed_plans == plans
		and state.deferred_field_sowing.has(RESTING) and state.field_route_status == -1 and ui.directions.tracked_plot == null,
		"Six real sowings use ordinary stamina, preserve reserves and holds, and finish the route.")
	var map := await _open_field_page()
	_expect(map.sow_route.disabled and "待播 0" in map.sow_route.text, "Reopening the map shows that the sowing work is done.")
	await _capture("05-sowing-queue-cleared")
	await _button(map.close_button)
	print("SOWING_ROUTE_RESULT day=", state.current_day, " fields=2 plots=6 stamina=", stamina - state.current_stamina,
		" controller=", controller != null, " remaining=", state.field_route_status)

func run_guided_sowing(host: SceneTree, captures := "", variant := "sowing-route") -> void:
	tree = host
	state = tree.root.get_node("Global")
	capture_dir = captures
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated sowing route profile."):
		tree.quit(1)
		return
	tree.root.notify_mouse_entered()
	var legacy := variant == "sowing-route-legacy"
	if legacy:
		await _continue_latest()
	else:
		await _prepare_mixed_field()
		if _check_arrangements():
			await _stage_expansion()
	if failures == 0 and _expect(state.current_day == 3 and state.well_fields.size() == 2 and state.field_route_status == -1,
		"The fixture starts with two wells and no active guidance."):
		if variant == "sowing-route-before":
			await _save_manually()
			var map := await _open_field_page()
			_expect(not map.has_node("%SowRoute"), "The old field page has no sowing guidance.")
			await _capture("01-previous-field-map")
			await _button(map.close_button)
		else:
			if variant == "sowing-route-pad":
				controller = load("res://tests/GamepadReplay.gd").new()
				controller.tree = tree
				controller.pad = GamepadInput
			await _guide_two_fields()
			_expect(controller == null or controller.failures == 0, "Controller aiming and confirmations succeed.")
	tree.unload_current_scene()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
