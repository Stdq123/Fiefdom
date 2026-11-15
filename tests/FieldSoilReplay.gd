extends "res://tests/NightRationsReplay.gd"

const PUBLIC := Vector2i(5, 5)
const PRIVATE := Vector2i(6, 5)
const RAW := Vector2i(4, 4)
const EXPANSION := Vector2i(9, 5)

var world: Node2D
var management: Control
var mouse_entered := false

func run_soil(host: SceneTree, mode := "", captures := "") -> void:
	tree = host
	state = tree.root.get_node("Global")
	capture_dir = captures
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"),
			"Use an isolated soil-planning profile."):
		_end()
		return
	if mode == "field-soil-resume":
		await _enter_title(false)
	else:
		await _enter_title(true)
		await _first_harvest()
	await _early_plan(mode == "field-soil-baseline")
	if mode.is_empty() or mode == "field-soil-plans":
		await _expanded_field()
	_end()

func _enter_title(new_game: bool) -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	if not mouse_entered:
		tree.root.notify_mouse_entered()
		mouse_entered = true
	await tree.process_frame
	var button: Button = tree.current_scene.new_button if new_game else tree.current_scene.continue_button
	await _click(button)
	if tree.current_scene == null:
		await tree.scene_changed
	_estate()

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	for worker: Retainer in world.retainer_instances.values():
		worker.set_physics_process(false)

func _plot(cell: Vector2i, whole_field := false) -> void:
	var tiles: TileMapLayer = world.tile_map
	var point := tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.shift_pressed = whole_field
		click.pressed = pressed
		tree.root.push_input(click, true)
		await tree.process_frame
	await tree.process_frame

func _first_harvest() -> void:
	state.set_field_seed_plan(RAW, "millet")
	_expect(not state.field_seed_plans.has(RAW), "Before the first tribute, unturned soil is the player's first lesson.")
	for cell in [PUBLIC, PRIVATE]:
		await _plot(cell)
		await _plot(cell)
	for night in 2:
		for cell in [PUBLIC, PRIVATE]:
			await _plot(cell)
		await _sleep()
	await _plot(PUBLIC)
	await _plot(PRIVATE)
	await _plot(PUBLIC)
	_expect(state.current_day == 3 and state.king_storage == 1 and state.crop_stock.count("millet") == 1
		and state.tilled_cells.size() == 2 and state.active_crops.has(PUBLIC),
		"From a normal new game, harvest just one public and one private crop, then sow the public next crop.")

func _save_at_settings() -> void:
	await _click(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _click(button)
			break
	_expect(settings.save_status.text == "游戏已保存", "The actual Settings menu saves the field checkpoint.")
	await _click(settings.close_button)

func _select_item(picker: OptionButton, index: int) -> void:
	await _click(picker)
	if not _expect(picker.get_popup().visible, "Open the ordinary plan selector."):
		return
	picker.get_popup().set_focused_item(index)
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await tree.process_frame
	await tree.process_frame
	_expect(picker.selected == index, "Confirm the selected field plan or steward.")

func _next_crop(picker: OptionButton, seed: String) -> void:
	for index in range(1, picker.item_count):
		if picker.get_item_metadata(index) == seed:
			await _select_item(picker, index)
			return
	_expect(false, "The requested crop is available in the selector.")

func _early_plan(baseline: bool) -> void:
	if not _expect(state.current_day == 3 and state.tilled_cells.size() == 2 and state.king_storage == 1
			and state.crop_stock.count("millet") == 1, "Both executables start from the same two harvested plots."):
		return
	var stamina: int = state.current_stamina
	if baseline:
		await _save_at_settings()
		await _plot(RAW, true)
		_expect(state.tilled_cells.size() == 9, "The old plan needs the player's Shift till before scheduling raw ground.")
		await _click(ui.manage_button)
	else:
		await _click(ui.hud.opening_action)
		var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
		if not _expect(dialog != null, "The journal opens the first harvest discussion."):
			return
		for option: Button in dialog.choices:
			if option.text == "安排门客种下茬":
				await _capture("01-first-harvest-choice")
				await _click(option)
				break
	management = ui.panel_manager.management_panel_instance
	if not _expect(management.is_visible_in_tree(), "Open the existing estate sowing page."):
		return
	await _next_crop(management.seed_plan_picker, "millet")
	if not baseline:
		_expect(management.include_untilled.is_visible_in_tree() and not management.include_untilled.button_pressed
			and management.apply_private_plan.text == "安排私田 · 1 格", "The default batch is for the one prepared private plot.")
		var pad = load("res://tests/GamepadReplay.gd").new()
		pad.tree = tree
		pad.pad = tree.root.get_node("GamepadInput")
		await pad._click(management.include_untilled)
		_expect(pad.failures == 0 and management.include_untilled.button_pressed
			and "7 格先翻地" in management.seed_plan_note.text, "The pad can explicitly include the seven raw plots.")
		await _capture("02-preparing-seven-plots")
	await _click(management.apply_private_plan)
	_expect(state.field_seed_plans.size() == 8 and not state.field_seed_plans.has(PUBLIC)
		and state.tilled_cells.size() == (9 if baseline else 2), "The chosen plan schedules only private crops without planting them.")
	await _click(management.close_button)
	if not baseline:
		await _save_at_settings()
		await _enter_title(false)
		var keeper: Retainer = world.retainer_instances[state.retainers[0]]
		var next: Vector2i = world.find_work_crop(keeper)
		_expect(state.field_seed_plans.get(RAW) == "millet" and not state.tilled_cells.has(RAW)
			and next in [PUBLIC, PRIVATE] and state.field_job(keeper.data, next) != state.FieldJob.TILL,
			"Continue restores the raw plans, and prepared ground comes before opening new soil. Next: %s" % next)
		var earlier: float = state.day_progress
		state.day_progress = 0.999
		_expect(state.field_wait_offer().plots == 9 and state.wait_for_field_work().is_empty()
			and not state.tilled_cells.has(RAW), "When daylight is too short, soil plans wait for another day.")
		state.day_progress = earlier
	var ledger := await _open()
	ledger.scroll.ensure_control_visible(ledger.wait_button)
	await tree.process_frame
	if not _expect(ledger.wait_button.is_visible_in_tree(), "Let the worker finish available jobs from the night ledger."):
		return
	await _click(ledger.wait_button)
	var work: Dictionary = state.field_wait_report.duplicate()
	var spent: int = stamina - state.current_stamina
	_expect(work.get("tilled", 0) == (0 if baseline else 7) and work.get("sown") == 8 and work.get("watered") == 9
		and state.active_crops.size() == 9 and world.tile_map.get_cell_atlas_coords(RAW).y == 1
		and spent == (7 * world.field_cost(world.FieldAction.TILL) if baseline else 0),
		"Both paths sow and water the same nine plots, with the intended stamina and soil labor.")
	await _capture("03-daytime-field-work")
	await _click(ledger.close_button)
	await _sleep("04-morning-after-plan")
	_expect(state.current_day == 4 and state.active_crops[RAW].age == 1 and state.night_rations.last.served == 1
		and state.king_storage == 1 and state.crop_stock.count("millet") == 1,
		"An ordinary night grows the new crop, charges one meal, and preserves both accounts.")
	if not baseline:
		_expect(state.last_dawn.get("field_wait", {}).get("tilled") == 7, "The morning record keeps seven tilled plots.")
	print("FIELD_SOIL_OPENING baseline=", baseline, " stamina_spent=", spent,
		" worker_minutes=", work.get("minutes"), " worked=", work, " saved_day=", state.current_day)

func _expanded_field() -> void:
	var path := "user://soil-expansion.json"
	var save := FileAccess.open(path, FileAccess.WRITE)
	save.store_string(JSON.stringify({
		"save_version": 2, "current_day": 28, "current_rank": state.Rank.ZHONG_SHI,
		"king_storage": 8, "quest_progress": 8, "private_harvest_total": 12, "food_storage": 20,
		"money": 40, "reputation": 100, "well_fields": [
			{"center_pos": "5,5", "is_unlocked": true, "reclamation_progress": 4},
			{"center_pos": "9,5", "is_unlocked": true, "reclamation_progress": 4},
		],
		"retainers": [{"name": "渠伯", "school": 2, "duty": RetainerData.Duty.FIELD, "loyalty": 90}],
		"last_dawn": {"day": 27, "completed_fields": [2]},
	}))
	save.close()
	if not _expect(state.load_game(path) == OK, "Load a just-completed, entirely unturned second field."):
		return
	await tree.scene_changed
	_estate()
	await _click(ui.hud.morning_button)
	var ledger := _panel()
	if not _expect(ledger != null and ledger.plan_field.is_visible_in_tree(), "The morning record links to the actual completed site."):
		return
	ledger.scroll.ensure_control_visible(ledger.plan_field)
	await tree.process_frame
	await _click(ledger.plan_field)
	await tree.process_frame
	management = ui.panel_manager.management_panel_instance
	if not _expect(management.visible and management.well_field_selector.get_selected_id() == 1,
			"The site shortcut opens the new field's original stewardship controls."):
		return
	await _select_item(management.steward_picker, management.steward_picker.get_item_index(0))
	await _click(management.include_untilled)
	_expect("9 格待门客翻地" in management.steward_preview.text
		and tree.root.get_visible_rect().encloses(management.apply_steward.get_global_rect()),
		"The completed site's pending ground and action fit inside the window.")
	await _capture("05-new-field-handover")
	await _click(management.apply_steward)
	var keeper: RetainerData = state.retainers[0]
	if not _expect(state.stewarded_field(keeper).field_id == 1 and keeper.duty == RetainerData.Duty.STEWARD
			and state.field_seed_plans.size() == 9 and state.tilled_cells.is_empty(),
			"The steward accepts all nine explicitly planned plots without instantly completing labor."):
		return
	var private_cell := EXPANSION + Vector2i.RIGHT
	state.set_field_sowing_deferred(private_cell, true)
	_expect(state.field_job(keeper, private_cell) == state.FieldJob.NONE, "A paused plan also holds back the opening of raw soil.")
	state.set_field_sowing_deferred(private_cell, false)
	await _click(management.close_button)
	var stamina: int = state.current_stamina
	world.retainer_instances[keeper].set_physics_process(true)
	for frame in range(900):
		if not state.tilled_cells.is_empty():
			break
		await tree.physics_frame
	if not _expect(not state.tilled_cells.is_empty() and state.current_stamina == stamina,
			"The local worker actually opens the new soil without a player tool action."):
		return
	await _capture("06-steward-turning-soil")
	await _let_steward_work_away()
	_expect(state.tilled_cells.size() == 9 and state.active_crops.size() == 9 and state.current_stamina == stamina
		and not state.tilled_cells.has(PUBLIC) and state.away_field_report.get("tilled", 0) > 0,
		"The turn-soil job also works on the road and stays on the delegated field.")
	await _capture("07-prepared-and-sown")
	ledger = await _open()
	_expect("外出田务 · 翻地" in ledger.field_forecast.text, "Today's trip report records ground actually opened.")
	ledger.scroll.ensure_control_visible(ledger.wait_before_sleep)
	await tree.process_frame
	await _click(ledger.wait_before_sleep)
	_expect(state.wait_for_fields_before_sleep, "The ordinary bedtime policy can finish later watering.")
	await _click(ledger.close_button)
	var nights := 0
	for crop: Dictionary in state.active_crops.values():
		nights = maxi(nights, int(crop.growth_nights))
	for night in nights:
		await _sleep()
	ledger = await _open()
	if ledger.wait_button.is_visible_in_tree():
		ledger.scroll.ensure_control_visible(ledger.wait_button)
		await tree.process_frame
		await _click(ledger.wait_button)
	_expect(state.king_storage > 8 and state.private_harvest_total > 12 and state.night_rations.last.served == 2,
		"The new field yields public tribute and private crops through ordinary growth and steward work.")
	await _capture("08-steward-harvest")
	print("FIELD_SOIL_EXPANSION till=", state.tilled_cells.size(), " day=", state.current_day,
		" tribute=", state.king_storage, " private=", state.private_harvest_total, " meal=", state.night_rations.last.served)

func _let_steward_work_away() -> void:
	var campaign = load("res://tests/CampaignReplay.gd")
	var road := "res://scenes/WestRoad.tscn"
	for point in [Vector2(-181, 60), Vector2(-181, 0), Vector2(-270, -21)]:
		await campaign.walk_to(tree, world.player, point)
	if not _expect(await campaign.walk_through_gates(tree, &"ui_left", road), "Walk out onto the west road."):
		return
	for frame in range(4500):
		if state.active_crops.size() == 9 and state.active_crops.values().all(func(crop: Dictionary) -> bool: return crop.watered):
			break
		await tree.physics_frame
	if _expect(await campaign.walk_through_gates(tree, &"ui_right", state.ESTATE_SCENE), "Return through the normal estate gate."):
		_estate()
