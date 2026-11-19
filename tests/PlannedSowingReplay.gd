extends "res://tests/FieldStrokeReplay.gd"

const MIXED := {PUBLIC: "millet", Vector2i(4, 4): "hemp", Vector2i(5, 4): "wheat", Vector2i(6, 4): "beans"}
const PRIVATE_RICE := Vector2i(4, 5)
const RESTING := Vector2i(6, 5)
const SPARE := Vector2i(4, 6)
const MULBERRY := Vector2i(6, 6)
const CROP_KEYS := {"millet": KEY_1, "rice": KEY_3, "wheat": KEY_4, "beans": KEY_5, "mulberry": KEY_6, "hemp": KEY_7}

func _seed_key(code: Key) -> void:
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		tree.root.push_input(key, true)
		await tree.process_frame

func _batch(cell: Vector2i) -> void:
	await _mouse(_point(cell), true, MOUSE_BUTTON_LEFT, true)
	await _mouse(_point(cell), false, MOUSE_BUTTON_LEFT, true)

func _choose_plan(panel: Control, cell: Vector2i, plan: String) -> void:
	var picker: OptionButton = panel.seed_plan_picker
	for index in picker.item_count:
		if picker.get_item_metadata(index) == plan:
			picker.select(index)
			picker.item_selected.emit(index)
			for tile: Button in panel.map_grid_container.get_children():
				if tile.grid_pos == cell:
					await _button(tile)
					return
	_expect(false, "The overview offers plan %s for %s." % [plan, cell])

func _prepare_mixed_field() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _button(tree.current_scene.new_button)
	for frame in range(60):
		if tree.current_scene and tree.current_scene.scene_file_path == state.ESTATE_SCENE:
			break
		await tree.process_frame
	if not _expect(tree.current_scene and tree.current_scene.scene_file_path == state.ESTATE_SCENE,
		"Start the new campaign using its ordinary title button."):
		return
	await _estate()
	await _batch(PUBLIC)
	for cell in [PUBLIC, RESTING]:
		await _click(_point(cell))
	await _batch(PUBLIC)
	await _sleep()
	await _seed_key(KEY_6)
	await _click(_point(MULBERRY))
	await _batch(PUBLIC)
	await _sleep()
	for cell in [RESTING, PUBLIC]:
		await _click(_point(cell))
	if not _expect(state.current_day == 3 and state.king_storage == 1 and state.crop_stock.count("millet") == 1,
		"Start from a normal new estate and collect its first two harvests."):
		return
	await _button(ui.manage_button)
	var panel: Control = ui.panel_manager.management_panel_instance
	panel.show_estate(0)
	await tree.process_frame
	for cell: Vector2i in MIXED:
		await _choose_plan(panel, cell, FieldSeedPlan.SEASONAL if MIXED[cell] == "beans" else MIXED[cell])
	await _choose_plan(panel, PRIVATE_RICE, "rice")
	await _choose_plan(panel, RESTING, "hemp")
	await _choose_plan(panel, RESTING, "defer_sowing")
	await _button(panel.close_button)

func _check_arrangements() -> bool:
	return _expect(state.current_day == 3 and state.king_storage == 1 and state.tilled_cells.size() == 9
		and state.active_crops.size() == 1 and state.active_crops[MULBERRY].id == "mulberry"
		and state.field_seed_plans.size() == 6 and state.field_seed_plans[Vector2i(6, 4)] == FieldSeedPlan.SEASONAL
		and state.deferred_field_sowing.has(RESTING) and not state.irrigation.supplies(PRIVATE_RICE),
		"The actual arrangements include four ready plans, a dry rice plot, a hold and a standing mulberry.")

func _sow_separately() -> void:
	await _pointer(_point(PUBLIC))
	await _capture("00-before-seed-belt")
	for cell: Vector2i in MIXED:
		await _seed_key(CROP_KEYS[MIXED[cell]])
		await _pointer(_point(cell))
		if MIXED[cell] == "wheat":
			await _capture("01-before-one-crop-at-a-time")
		await _click(_point(cell))

func _sow_by_plan(controller: bool) -> void:
	var pad = null
	if controller:
		pad = load("res://tests/GamepadReplay.gd").new()
		pad.tree = tree
		pad.pad = GamepadInput
		await pad._tap(JOY_BUTTON_RIGHT_SHOULDER) # Mulberry to hemp.
		await pad._tap(JOY_BUTTON_RIGHT_SHOULDER) # Hemp to planned sowing.
		await pad._aim(_point(PUBLIC))
	else:
		await _button(ui.hud.sow_from_plan)
		await _pointer(_point(PUBLIC))
	_expect(world.sow_from_plan and ui.hud.sow_from_plan.button_pressed and ui.hud.sow_from_plan.is_visible_in_tree(),
		"Select the normal seed-belt mode or reach it with the controller shoulder button.")
	if controller:
		pad._axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	else:
		Input.action_press(KeyBindings.FILL)
	await tree.process_frame
	await tree.process_frame
	var cursor := tiles.get_node("FieldCursor")
	_expect(cursor.caption.visible and cursor.preview_seeds == MIXED and cursor.preview_plots.size() == 4
		and "公田 1 · 私田 3" in cursor.label.text and "8 体力" in cursor.label.text
		and "麦 1" in cursor.label.text and "菽 1" in cursor.label.text,
		"The preview shows the crop and cost of each affordable plan and excludes rice, the hold and fallow plots.")
	await _capture("01-planned-sowing-preview")
	if controller:
		await pad._tap(JOY_BUTTON_A)
		pad._axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
		_expect(pad.failures == 0, "The controller can aim and confirm the whole field.")
	else:
		var stamina: int = state.current_stamina
		state.current_stamina = 7
		GameEvents.stamina_changed.emit(7)
		await _batch(PUBLIC)
		_expect(state.current_stamina == 7 and state.active_crops.size() == 1,
			"A batch short by one stamina sows none of the planned field.")
		state.current_stamina = stamina
		GameEvents.stamina_changed.emit(stamina)
		await tree.create_timer(1.05).timeout
		await _batch(PUBLIC)
		Input.action_release(KeyBindings.FILL)
	await _capture("02-seeds-in-ground")
	if not controller:
		var stamina: int = state.current_stamina
		for cell in [PRIVATE_RICE, RESTING, SPARE]:
			await _click(_point(cell))
		_expect(state.current_stamina == stamina, "Ineligible plots take no stamina in plan mode.")
		await _seed_key(KEY_6)
		_expect(not world.sow_from_plan and ui.hud.seed_buttons["mulberry"].button_pressed,
			"Even the former seed shortcut returns to explicit manual sowing.")

func _check_sown(stamina: int, first_plans: Dictionary, branch: String) -> int:
	var nights := 0
	var crops := PackedStringArray()
	for cell: Vector2i in MIXED:
		var crop: Dictionary = state.active_crops.get(cell, {})
		if _expect(crop.get("id") == MIXED[cell] and crop.age == 0 and not crop.watered,
			"Each eligible plot is sown once with its actual next crop."):
			nights = maxi(nights, crop.growth_nights)
			crops.append("%s/%d" % [crop.id, crop.growth_nights])
	_expect(state.active_crops.size() == 5 and state.active_crops.has(MULBERRY)
		and state.current_stamina == stamina - 8 and state.king_storage == 1
		and state.field_seed_plans == first_plans and state.deferred_field_sowing.has(RESTING),
		"The two methods sow the same four cells at normal cost without clearing saved plans or booking a harvest.")
	print("PLANNED_SOWING method=", branch, " day=", state.current_day, " crops=", ",".join(crops),
		" stamina=", state.current_stamina, " plans=", first_plans.size())
	return nights

func _harvest_mix(nights: int) -> void:
	for night in nights:
		for cell: Vector2i in MIXED:
			if state.field_crop_is_dry(cell):
				await _batch(cell)
				break
		await _sleep()
	for cell: Vector2i in MIXED:
		if _expect(state.field_crop_is_ripe(cell), "Each seeded plot grows on its ordinary schedule."):
			await _click(_point(cell))
	_expect(state.king_storage == 2 and state.private_harvest_total == 4
		and state.crop_stock.count("beans") == 1 and state.fertile_cells.has(Vector2i(6, 4)),
		"Harvest sends millet to the treasury, three crops to the owner and keeps beans' soil benefit.")
	await _capture("03-mixed-harvest")
	print("PLANNED_SOWING_HARVEST day=", state.current_day, " public=", state.king_storage,
		" private=", state.private_harvest_total, " money=", state.money, " food=", state.food_storage)

func _sow_on_fertile_soil() -> void:
	# Exercise an unlocked rotation on the two plots that really grew beans and wheat.
	var fertile := Vector2i(6, 4)
	var unfertilized := Vector2i(5, 4)
	state.field_rotation.signed_day = state.current_day
	for cell in [fertile, unfertilized]:
		state.set_field_seed_plan(cell, FieldSeedPlan.with_beans("wheat"))
	await _button(ui.hud.sow_from_plan)
	var stamina: int = state.current_stamina
	await _click(_point(fertile))
	await _click(_point(unfertilized))
	_expect(state.active_crops.get(fertile, {}).get("id") == "wheat"
		and state.active_crops.get(unfertilized, {}).get("id") == "beans"
		and state.current_stamina == stamina - 4 and state.fertile_cells.has(fertile),
		"Single-plot sowing applies the actual soil-dependent rotation, leaving fertilizer for harvest.")
	print("PLANNED_SOWING_ROTATION fertile=wheat ordinary=beans stamina_cost=", stamina - state.current_stamina)

func run_planned_sowing(host: SceneTree, captures := "", variant := "planned-sowing") -> void:
	tree = host
	state = tree.root.get_node("Global")
	capture_dir = captures
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated sowing profile."):
		tree.quit(1)
		return
	tree.root.notify_mouse_entered()
	if variant == "planned-sowing-legacy":
		await _continue_latest()
	else:
		await _prepare_mixed_field()
	if _check_arrangements():
		var stamina: int = state.current_stamina
		var plans: Dictionary = state.field_seed_plans.duplicate()
		var baseline := variant == "planned-sowing-before"
		if baseline:
			await _save_manually()
			await _sow_separately()
		else:
			await _sow_by_plan(variant == "planned-sowing-pad")
		var nights := _check_sown(stamina, plans, "separate" if baseline else variant)
		if variant != "planned-sowing-pad" and failures == 0:
			await _harvest_mix(nights)
			if variant == "planned-sowing" and failures == 0:
				await _sow_on_fertile_soil()
	tree.unload_current_scene()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
