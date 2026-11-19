extends "res://tests/FieldPreparationReplay.gd"

const SECOND_BEANS := Vector2i(8, 5)
const SECOND_HEMP := Vector2i(10, 5)
const FIRST_RIPE := {PUBLIC: "millet", BEANS: "beans", WET_RICE: "rice", DRY_RICE: "millet",
	RESTING: "sorghum", MULBERRY: "mulberry"}
const SECOND_RIPE_CROPS := {SECOND_FIELD: "millet", SECOND_BEANS: "wheat", SECOND_HEMP: "sorghum"}
const FIRST_REPLANT := {PUBLIC: "millet", BEANS: "wheat", WET_RICE: "rice"}
const SECOND_REPLANT := {SECOND_FIELD: "millet", SECOND_BEANS: "beans", SECOND_HEMP: "hemp"}

var confirmations := 0

func _stage_ripe_wells(rain: bool, reform: bool) -> bool:
	if not await _staged_estate(rain):
		return false
	state.set_field_seed_plan(FAR_PLAN, "")
	if not rain:
		state.set_field_seed_plan(BARE, "")
	if reform:
		state.set_field_seed_plan(RESTING, "")
		state.tax_reform_choice = state.TaxReformChoice.REFORMED
		state.tax_rate = 0.2
	var ripe := FIRST_RIPE.duplicate()
	ripe.merge(SECOND_RIPE_CROPS)
	for cell: Vector2i in ripe:
		if cell == MULBERRY:
			continue
		state.tilled_cells[cell] = true
		if not _expect(state.sow_field_crop(cell, ripe[cell]), "Place the mature crop at %s." % cell):
			return false
		state.active_crops[cell].age = state.active_crops[cell].growth_nights
	for cell: Vector2i in SECOND_REPLANT:
		var plan := FieldSeedPlan.with_beans("wheat") if cell == SECOND_BEANS else String(SECOND_REPLANT[cell])
		state.set_field_seed_plan(cell, plan)
	state.fertile_cells[SECOND_BEANS] = true
	state.tilled_cells[FALLOW] = true
	state.sow_field_crop(FALLOW, "millet")
	tree.change_scene_to_file(state.ESTATE_SCENE)
	await tree.scene_changed
	await _estate()
	return true

func _ledger() -> Vector4i:
	return Vector4i(state.king_storage, state.player_inventory, state.money, state.private_harvest_total)

func _settlement(ripe: Dictionary) -> Vector4i:
	var result := Vector4i.ZERO
	for cell: Vector2i in ripe:
		var price := ItemManager.get_crop(ripe[cell]).sell_price
		var amount := 2 if cell == SECOND_BEANS else 1
		if state.is_public_plot(cell):
			result.x += amount
		else:
			result.y += amount
			var paid := int(price * 0.8) if state.tax_reform_choice == state.TaxReformChoice.REFORMED else price
			result.z += amount * paid
			result.w += amount * (price - paid)
	return result

func _test_well(aim: Vector2i, original: Dictionary, next: Dictionary, before: bool, check_shortfall: bool) -> void:
	var ledger := _ledger()
	var gains := _settlement(original)
	var leaves: int = state.silk_workshop.leaves
	var stamina: int = state.current_stamina
	var water := 0 if state.has_rain() else next.size() - int(next.has(WET_RICE))
	var cost := 3 * original.size() + 2 * next.size() + water
	var first := aim.x < SECOND_FIELD.x - 1
	await _aim_plot(aim)
	await _hold_batch(true)
	var cursor: Node2D = tiles.get_node("FieldCursor")
	if before:
		_expect("整田收割" in cursor.label.text and cursor.preview_seeds.is_empty(), "The previous release previews a separate harvest.")
	else:
		var prompt := "A 确认" if pad else "左键确认"
		var text: String = cursor.label.text
		_expect(cursor.visible and cursor.preview_plots.size() == original.size() and cursor.preview_seeds == next
			and "收后续播" in text and "续播 %d 格 · 浇水 %d 格" % [next.size(), water] in text
			and "%d 体力 · %s" % [cost, prompt] in text, "Quote the complete crop, cost, and controls. %s" % text)
		_expect((gains.x == 0 or "国库 +%d" % gains.x in text) and "私仓 +%d" % gains.y in text
			and (gains.w == 0 or "扣税 %d" % gains.w in text), "Quote public, private and taxed proceeds.")
		var caption: Control = cursor.caption
		var box := caption.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, caption.size)
		_expect(tree.root.get_visible_rect().encloses(box), "Keep the entire quote on screen.")
	await _capture("01-first-well-preview" if first else "04-second-well-preview")
	if check_shortfall:
		state.current_stamina = cost - 1
		GameEvents.stamina_changed.emit(state.current_stamina)
		await tree.process_frame
		await tree.process_frame
		_expect("还差 1" in cursor.label.text, "Show the one-point shortfall before any commit.")
		await _capture("02-one-point-short")
		var crops: Dictionary = state.active_crops.duplicate(true)
		var soil: Dictionary = state.fertile_cells.duplicate()
		await _confirm(aim)
		_expect(state.current_stamina == cost - 1 and _ledger() == ledger and state.active_crops == crops
			and state.fertile_cells == soil, "An unaffordable confirmation preserves every crop, fertility, and account.")
		state.current_stamina = stamina
		GameEvents.stamina_changed.emit(stamina)
		await _aim_plot(aim)
	await _confirm(aim)
	confirmations += 1
	if before:
		await _aim_plot(aim)
		_expect("整备空田" in cursor.label.text, "The old release needs a separate preparation confirmation.")
		await _capture("02-preparation-preview" if first else "04a-preparation-preview")
		await _confirm(aim)
		confirmations += 1
	else:
		_expect(world.player.tool_gesture.frame == ToolGesture.Action.HARVEST,
			"The combined operation finishes with the harvest tool cue.")
	await _hold_batch(false)
	_expect(_ledger() - ledger == Vector4i(gains.x, gains.y, gains.z, gains.y)
		and state.current_stamina == stamina - cost, "Settle the quoted yields and spend the full normal cost.")
	_expect(state.silk_workshop.leaves - leaves == int(original.has(MULBERRY)) * state.balance.mulberry_leaves_per_harvest,
		"Settle the usual mulberry leaves for this batch.")
	for cell: Vector2i in original:
		var crop: Dictionary = state.active_crops.get(cell, {})
		if next.has(cell):
			_expect(crop.get("id") == next[cell] and crop.get("age") == 0 and not state.field_crop_is_dry(cell)
				and crop.get("watered") == (cell != WET_RICE and not state.has_rain()), "Renew and water the planned plot %s." % cell)
		elif cell == MULBERRY:
			_expect(crop.get("id") == "mulberry" and not state.field_crop_is_ripe(cell), "Collect mulberry leaves and leave the perennial standing.")
		else:
			_expect(crop.is_empty(), "Leave the harvested plot %s empty while its plan is blocked or paused." % cell)
	print("HARVEST_REPLANT_WELL cell=", aim, " harvest=", original.size(), " seeds=", next.size(), " water=", water,
		" tribute=", gains.x, " stock=", gains.y, " copper=", gains.z, " levy=", gains.w, " stamina=", cost)
	await _capture("03-first-well-settled" if first else "05-second-well-settled")

func _run_wells(variant: String) -> void:
	var before := variant == "harvest-replant-before"
	var private_route := variant == "harvest-replant-rain"
	var first_ripe := FIRST_RIPE.duplicate()
	var first_seeds := FIRST_REPLANT.duplicate()
	var second_ripe := SECOND_RIPE_CROPS.duplicate()
	var second_seeds := SECOND_REPLANT.duplicate()
	await _press(ui.hud.sow_from_plan)
	if before:
		await _press(ui.hud.prepare_empty_plots)
	else:
		var option: Button = ui.hud.replant_after_harvest
		_expect(option.is_visible_in_tree() and not option.button_pressed
			and tree.root.get_visible_rect().encloses(option.get_global_rect()), "Renewal is visible and opt-in after choosing planned seeds.")
		await _press(option)
		_expect(option.button_pressed and world.replant_after_harvest, "The toggle works with the active input method.")
	if private_route:
		first_ripe.erase(PUBLIC)
		first_seeds.erase(PUBLIC)
		second_ripe.erase(SECOND_FIELD)
		second_seeds.erase(SECOND_FIELD)
		await _press(ui.hud.farm_status)
		await _press(ui.estate_map.private_harvest_route)
		await _aim_plot(PUBLIC)
		await _hold_batch(true)
		var hud_cursor: Node2D = tiles.get_node("FieldCursor")
		_expect("批量只收私田" in hud_cursor.label.text, "Explain the scope at an excluded public plot.")
		var before_stamina: int = state.current_stamina
		await _confirm(PUBLIC)
		await _hold_batch(false)
		_expect(state.field_crop_is_ripe(PUBLIC) and state.current_stamina == before_stamina, "Reject out-of-scope batch confirmation.")
	var growing: Dictionary = state.active_crops[FALLOW].duplicate()
	var ledger := _ledger()
	var stamina: int = state.current_stamina
	await _test_well(BEANS if private_route else PUBLIC, first_ripe, first_seeds, before, not before and not private_route)
	if private_route:
		_expect(state.field_route_scope == state.FieldScope.PRIVATE and ui.directions.tracked_plot.x >= SECOND_FIELD.x - 1,
			"The private harvest route continues to the second well.")
	var end_of_path: Vector2 = world.to_global(world.get_crop_world_pos(SECOND_FIELD) + Vector2(0, 28))
	await Campaign.walk_estate_road_to(tree, world, end_of_path)
	await _test_well(SECOND_BEANS if private_route else SECOND_FIELD, second_ripe, second_seeds, before, false)
	_expect(state.active_crops[FALLOW] == growing and not state.active_crops.has(BARE) and not state.tilled_cells.has(BARE)
		and state.fertile_cells.has(BEANS) and not state.fertile_cells.has(SECOND_BEANS),
		"The neighboring plots stay as they were, while harvesting beans and wheat updates their actual soil.")
	if private_route:
		_expect(state.field_crop_is_ripe(PUBLIC) and state.field_crop_is_ripe(SECOND_FIELD)
			and state.field_seed_plans.has(BARE) and state.deferred_field_sowing.has(RESTING),
			"Rain supplies all renewed seeds. Public crops, the empty planned plot, and the paused plan stay in place.")
	var gains := _ledger() - ledger
	print("HARVEST_REPLANT method=", variant, " day=", state.current_day, " confirms=", confirmations,
		" tribute=", gains.x, " stock=", gains.y, " copper=", gains.z, " stamina=", stamina - state.current_stamina,
		" window=", tree.root.size)
	if private_route:
		var before_single: int = state.current_stamina
		await _click(_point(SECOND_FIELD))
		_expect(world.replant_after_harvest and not state.active_crops.has(SECOND_FIELD) and state.field_crop_is_ripe(PUBLIC)
			and state.current_stamina == before_single - 3, "An ordinary click still harvests only its own plot without replanting.")
	elif not before:
		await _check_night_and_mode(first_seeds, second_seeds)

func _check_night_and_mode(first_seeds: Dictionary, second_seeds: Dictionary) -> void:
	if pad:
		var tomorrow: int = state.current_day + 1
		await _press(ui.sleep_button)
		await tree.create_timer(1.20).timeout
		_expect(state.current_day == tomorrow, "The controller advances one normal night.")
	else:
		await _sleep()
	for cell: Vector2i in first_seeds.keys() + second_seeds.keys():
		_expect(state.active_crops[cell].age == 1, "Every renewed seed progresses on the following night.")
	await _capture("06-morning-growth")
	await _press(ui.hud.seed_buttons["millet"])
	_expect(not world.replant_after_harvest and not ui.hud.replant_after_harvest.is_visible_in_tree(), "Selecting a seed ends the renewal mode.")

func run_replanting(host: SceneTree, captures := "", variant := "harvest-replant") -> void:
	tree = host
	state = tree.root.get_node("Global")
	capture_dir = captures
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the replanting replay profile."):
		tree.quit(1)
		return
	tree.root.notify_mouse_entered()
	var rain := variant == "harvest-replant-rain"
	var reform := variant == "harvest-replant-reform"
	if not state.latest_saved_game().is_empty():
		await _continue_latest()
	elif not await _stage_ripe_wells(rain, reform):
		tree.quit(1)
		return
	if variant == "harvest-replant-before":
		await _save_manually()
		await _continue_latest()
	if variant == "harvest-replant-pad":
		pad = load("res://tests/GamepadReplay.gd").new()
		pad.tree = tree
		pad.pad = GamepadInput
	state.balance.raid_first_day = 10000
	if _expect(state.has_rain() == rain and state.irrigation.supplies(WET_RICE) and not state.irrigation.supplies(DRY_RICE)
		and state.field_crop_is_ripe(PUBLIC) and state.field_crop_is_ripe(SECOND_FIELD)
		and state.field_seed_plans.get(BEANS) == FieldSeedPlan.with_beans("wheat"), "Start from both well plots with the saved rotation and water supply."):
		await _run_wells(variant)
	if pad:
		_expect(pad.failures == 0, "The controller finds the intended buttons and cells.")
	tree.unload_current_scene()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
