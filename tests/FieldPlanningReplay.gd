extends "res://tests/FieldSeedPlanReplay.gd"

const FIRST := Vector2i(5, 5)
const SECOND_PRIVATE := Vector2i(9, 6)

var legacy := false

func _prepare_planning() -> bool:
	if not await _fixture():
		return false
	state.current_day = 30
	for y in range(-1, 2):
		for x in range(-1, 2):
			state.tilled_cells[FIRST + Vector2i(x, y)] = true
	state.tilled_cells[SECOND_PRIVATE] = true
	var items := tree.root.get_node("ItemManager")
	var wheat: CropData = items.get_crop("wheat")
	state.active_crops[MANUAL] = {"id": "wheat", "data": wheat, "age": 1, "growth_nights": 2,
		"watered": true, "requires_channel": false}
	state.active_crops[FIRST] = {"id": "millet", "data": items.get_crop("millet"), "age": 2, "growth_nights": 2,
		"watered": false, "requires_channel": false}
	state.set_field_seed_plan(FIRST, "millet")
	state.set_field_seed_plan(PUBLIC, "sorghum")
	state.set_field_seed_plan(SITE, "hemp")
	if not _expect(state.save_game() == OK and state.load_game() == OK, "Open the prepared two-field spring estate."):
		return false
	await tree.scene_changed
	_estate()
	for worker: Retainer in world.retainer_instances.values():
		worker.set_physics_process(false)
	await tree.process_frame
	return true

func _select(panel: Control, id: String) -> void:
	var picker: OptionButton = panel.seed_plan_picker
	for index in range(1, picker.item_count):
		if picker.get_item_metadata(index) == id:
			picker.select(index)
			picker.item_selected.emit(index)
			await tree.process_frame
			return

func _plans_for_first(id: String) -> bool:
	for y in range(-1, 2):
		for x in range(-1, 2):
			var cell := FIRST + Vector2i(x, y)
			if cell != FIRST and state.field_seed_plans.get(cell, "") != id:
				return false
	return true

func _plan_both_fields() -> bool:
	var panel := await _management()
	await _button(panel.seed_plan_picker)
	var popup: PopupMenu = panel.seed_plan_picker.get_popup()
	_expect(popup.visible, "The seed menu is available on the estate overview.")
	await _snapshot("00-seed-menu")
	popup.hide()
	await _select(panel, "rice")
	_expect("稻 · 4 夜" in panel.seed_plan_picker.get_item_text(panel.seed_plan_picker.selected)
		and "明日立夏播种需 3 夜" in panel.seed_timing.text and panel.seed_timing.visible
		and "8 格待渠水" in panel.seed_plan_note.text and "1 格收后补播" in panel.seed_plan_note.text
		and "含 1 格改种" in panel.seed_plan_note.text and panel.apply_private_plan.text == "安排私田 · 8 格",
		"The preview includes sowing time, water, the crop to harvest, and the plan to replace.")
	await _snapshot("01-before-summer")
	await _button(panel.apply_private_plan)
	_expect(_plans_for_first("rice") and state.field_seed_plans[FIRST] == "millet"
		and state.field_seed_plans[PUBLIC] == "sorghum" and state.active_crops[MANUAL].id == "wheat"
		and panel.apply_private_plan.disabled and _plot(panel, RICE).icon != null,
		"One click prepares eight private plots, keeping the current wheat and both public plans.")
	await _snapshot("02-eight-private-plans")
	await _field(panel, 1)
	await _select(panel, "wheat")
	_expect(panel.apply_private_plan.text == "安排私田 · 1 格", "Only the second field's prepared annual plot is available.")
	await _button(panel.apply_private_plan)
	_expect(_plans_for_first("rice") and state.field_seed_plans[SECOND_PRIVATE] == "wheat"
		and not state.field_seed_plans.has(ORCHARD) and state.active_crops[ORCHARD].id == "mulberry"
		and not state.field_seed_plans.has(Vector2i(8, 4)),
		"Changing the second field preserves the other field, the orchard and untilled land.")
	await _snapshot("03-second-field")
	await _button(panel.get_node("CloseButton"))
	print("PLAN_BATCH private_cells=8 clicks=1 second_field=1 public_preserved=true")
	return not failed

func _harvest(cell: Vector2i) -> void:
	var tiles: TileMapLayer = world.tile_map
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))

func _next_season() -> bool:
	var evening_food: int = state.food_storage
	var meals: int = state.retainer_food_cost()
	await _button(ui.sleep_button)
	await tree.create_timer(1.20).timeout
	if not _expect(state.current_day == 31 and state.food_storage == evening_food - meals
		and state.field_crop_is_ripe(MANUAL) and not state.active_crops.has(RICE),
		"Ordinary dawn feeds the household, ripens the wheat and leaves dry rice pending."):
		return false
	await Campaign.walk_to(tree, world.player, world.to_global(Vector2(66, 98)))
	await _harvest(FIRST)
	await _harvest(MANUAL)
	_expect(state.king_storage == 1 and state.player_inventory == 1 and state.field_seed_plans[MANUAL] == "rice",
		"Public and private harvests settle into different stores, leaving the next seed planned.")
	var path: Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 5)]
	if not _expect(state.build_channel_path(path) == state.ChannelSite.AVAILABLE, "Connect canal water to the pending plot."):
		return false
	for worker: Retainer in world.retainer_instances.values():
		worker.set_physics_process(true)
	if not await _wait_for(func(): return state.active_crops.get(RICE, {}).get("id") == "rice",
		"The keeper sows rice after the plot receives canal water.", 16.0):
		return false
	var rice: Dictionary = state.active_crops[RICE]
	_expect(rice.growth_nights == 3 and state.irrigation.supplies(RICE) and not state.active_crops.has(SITE),
		"The sown rice uses summer growth while the nearby dry plot waits.")
	var panel := await _management()
	await _select(panel, "rice")
	_expect(not panel.seed_timing.visible and "3 夜 · 当令" in panel.seed_plan_picker.get_item_text(panel.seed_plan_picker.selected),
		"The picker reflects today's summer sowing time.")
	await _snapshot("04-irrigated-summer-rice")
	await _button(panel.get_node("CloseButton"))
	print("PLAN_SUMMER day=", state.current_day, " rice_nights=", rice.growth_nights,
		" public=", state.king_storage, " private=", state.player_inventory, " meals=", meals)
	return not failed

func _resume_plan() -> bool:
	if not _expect(state.save_game() == OK, "Save the current field plans."):
		return false
	return await _continue_from_title()

func _continue_from_title() -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	var title := tree.current_scene
	if not _expect(title.continue_button.visible, "Continue has a readable save."):
		return false
	await _button(title.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	_estate()
	await tree.process_frame
	return true

func _clear_and_reform() -> void:
	if not await _resume_plan():
		return
	var panel := await _management()
	_expect(_plans_for_first("rice") and state.field_seed_plans[SECOND_PRIVATE] == "wheat",
		"Continue restores plans for both fields.")
	await _select(panel, "")
	_expect(panel.apply_private_plan.text == "取消私田 · 8 格", "The clear action counts the eight private plans.")
	await _button(panel.apply_private_plan)
	_expect(_plans_for_first("") and state.field_seed_plans[FIRST] == "millet" and state.field_seed_plans[PUBLIC] == "sorghum"
		and state.field_seed_plans[SECOND_PRIVATE] == "wheat" and state.active_crops[RICE].id == "rice",
		"Clearing the first field's plans preserves the crop and the plans outside the selected private plots.")
	await _snapshot("05-clear-private-plans")
	# Exercise the same controls with the land classification used after a reform decision.
	state.tax_reform_choice = state.TaxReformChoice.REFORMED
	panel.refresh_well_fields()
	await _select(panel, "beans")
	_expect(panel.apply_private_plan.text == "安排私田 · 9 格", "Under reform the former public center is part of the private area.")
	await _button(panel.apply_private_plan)
	_expect(_plans_for_first("beans") and state.field_seed_plans[FIRST] == "beans", "The reformed scope includes all nine plots.")
	print("PLAN_RESUME private_cleared=8 reformed_scope=9")

func _previous_plans() -> void:
	if not await _continue_from_title():
		return
	var panel := await _management()
	await _select(panel, "wheat")
	_expect(_plans_for_first("wheat") and panel.apply_private_plan.disabled and state.field_seed_plans.size() == 8,
		"The previous package's eight individual plans are already reflected in the batch view.")
	print("PLAN_LEGACY private_cells=", state.field_seed_plans.size(), " wheat=", _plans_for_first("wheat"))

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated field planning profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_PLANNING_CAPTURES")
	tree.root.notify_mouse_entered()
	seed(3112)
	if legacy:
		await _previous_plans()
	elif await _prepare_planning() and await _plan_both_fields() and await _next_season():
		await _clear_and_reform()
	tree.unload_current_scene()
	for stream in tree.root.get_node("AudioManager").get_children():
		if stream is AudioStreamPlayer:
			stream.stop()
	await tree.process_frame
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
