extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const SECOND_PUBLIC := Vector2i(9, 5)
const WEST_PUBLIC := Vector2i(-1, -1)
const ORCHARD := Vector2i(6, 6)
const YOUNG := Vector2i(8, 6)
const READY := {
	Vector2i(5, 5): "millet",
	Vector2i(6, 5): "hemp",
	Vector2i(4, 6): "beans",
	ORCHARD: "mulberry",
	SECOND_PUBLIC: "sorghum",
	Vector2i(8, 5): "millet",
	Vector2i(10, 5): "wheat",
	Vector2i(10, 6): "beans",
}

var tree: SceneTree
var state: Node
var world: Node
var ui: Node
var baseline := ""
var failed := false

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failed = true
		push_error(message)
	return condition

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")

func _load_saved() -> bool:
	if not _expect(state.load_game() == OK, "The harvest fixture must load through the regular save path."):
		return false
	await tree.scene_changed
	_estate()
	await tree.process_frame
	return true

func _save_reload() -> bool:
	if not _expect(state.save_game() == OK, "The farm must save before its comparison run."):
		return false
	return await _load_saved()

func _restore_record(record: String) -> bool:
	var file := FileAccess.open(state.manual_save_path(), FileAccess.WRITE)
	if not _expect(file != null, "The isolated starting record must be writable."):
		return false
	file.store_string(record)
	file.close()
	return await _load_saved()

func _restore_baseline() -> bool:
	return await _restore_record(baseline)

func _stage_crop(cell: Vector2i, id: String, ripe: bool) -> void:
	var crop: CropData = tree.root.get_node("ItemManager").get_crop(id)
	var nights: int = state.sowing_nights(crop)
	state.tilled_cells[cell] = true
	state.active_crops[cell] = {"id": id, "data": crop, "age": nights if ripe else 0,
		"growth_nights": nights, "watered": false, "requires_channel": crop.is_water_crop}

func _prepare_estate() -> bool:
	state.current_day = 33
	state.current_rank = state.Rank.ZHONG_SHI
	state._update_max_well_fields()
	state.food_storage = 25
	state.money = 100
	state.reputation = 180
	state.king_storage = 10
	state.field_rotation.promise_day = 29
	state.field_rotation.beans_day = 32
	state.balance.raid_first_day = 10000
	var guard := RetainerData.new("弋戎", "弓士", RetainerData.School.MILITARY)
	guard.duty = RetainerData.Duty.GUARD
	state.retainers.append(guard)
	if not _expect(state.add_well_field(SECOND_PUBLIC), "The late estate needs a valid second well field."):
		return false
	for night in range(4):
		state.advance_reclamation(1)
	for cell: Vector2i in READY:
		_stage_crop(cell, READY[cell], true)
	_stage_crop(YOUNG, "sorghum", false)
	state.fertile_cells[Vector2i(6, 5)] = true
	if not await _save_reload():
		return false
	baseline = FileAccess.get_file_as_string(state.manual_save_path())
	return true

func _click_field(cell: Vector2i) -> void:
	var tile_map: TileMapLayer = world.tile_map
	var point := tile_map.get_global_transform_with_canvas() * tile_map.map_to_local(cell)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.global_position = point
		click.pressed = pressed
		tree.root.push_input(click, true)
		await tree.process_frame

func _assign_reaper(index: int, prioritize_second := true) -> void:
	ui.manage_button.pressed.emit()
	await tree.process_frame
	var panel: Control = ui.panel_manager.management_panel_instance
	var item: Control = panel.retainer_list_container.get_child(index)
	var picker: OptionButton = item.duty_picker
	var option := picker.get_item_index(RetainerData.Duty.HARVEST)
	if _expect(option >= 0 and not picker.is_item_disabled(option), "The normal duty picker offers harvest work."):
		picker.item_selected.emit(option)
	if prioritize_second:
		var field_index: int = panel.well_field_selector.get_item_index(1)
		var center: Vector2i = state.well_fields[1]["center_pos"]
		panel.well_field_selector.select(field_index)
		panel.well_field_selector.item_selected.emit(field_index)
		for tile in panel.map_grid_container.get_children():
			if tile.grid_pos == center:
				tile._drop_data(Vector2.ZERO, state.retainers[index])
				break
	panel.get_node("CloseButton").pressed.emit()
	await tree.process_frame

func _worker(index: int) -> Retainer:
	return world.retainer_instances[state.retainers[index]]

func _wait_for_swing(worker: Retainer, cell := SECOND_PUBLIC) -> bool:
	for frame in range(600):
		if worker.current_state == Retainer.State.WORK and worker.target_grid_pos == cell:
			return true
		await tree.physics_frame
	return _expect(false, "The assigned reaper must reach the priority plot and start cutting.")

func _wait_for_harvest() -> bool:
	for frame in range(1200):
		if not state.active_crops.keys().any(func(cell: Vector2i) -> bool: return world.is_crop_ripe(cell)):
			return true
		await tree.physics_frame
	return _expect(false, "The assigned worker must finish the ripe crops in the estate.")

func _settlement() -> Dictionary:
	return {"tribute": state.king_storage, "private": state.private_harvest_total, "money": state.money,
		"leaves": state.silk_workshop.leaves, "stock": state.crop_stock.lots.duplicate(),
		"fertile": state.fertile_cells.duplicate(), "rotation": state.field_rotation.crop_id}

func _compare_harvests() -> bool:
	var initial := _settlement()
	var stamina: int = state.current_stamina
	for cell: Vector2i in READY:
		await _click_field(cell)
	var manual := _settlement()
	var receipt := ui.hud.get_node("HarvestReceipt") as Control
	var caption := receipt.get_node("Caption") as Label
	_expect(receipt.visible and "国库 +2" in caption.text and "作物 +7" in caption.text
		and "桑叶 +4" in caption.text and "轮作增收" in caption.text and "留肥" in caption.text,
		"The receipt shows mixed crops, silk leaves and the effects of rotation.")
	var spent: int = stamina - state.current_stamina
	if not _expect(spent == READY.size() * 3 and manual.tribute == initial.tribute + 2
		and manual.private == initial.private + 7 and manual.rotation == "hemp",
		"Manual clicks harvest both public fields and the rotated private plot."):
		return false
	if not await _restore_baseline():
		return false
	var original_food_need: int = state.retainer_food_cost()
	await _assign_reaper(0)
	var worker := _worker(0)
	if not await _wait_for_swing(worker):
		return false
	_expect(worker.data.duty == RetainerData.Duty.HARVEST and worker.tool_gesture.visible
		and worker.tool_gesture.frame == ToolGesture.Action.HARVEST and not world.player.tool_gesture.visible,
		"The reaper performs the sickle gesture at the assigned plot.")
	if not await _save_reload():
		return false
	worker = _worker(0)
	_expect(worker.data.duty == RetainerData.Duty.HARVEST and worker.data.assigned_area == SECOND_PUBLIC
		and world.is_crop_ripe(SECOND_PUBLIC) and _settlement() == initial,
		"Saving during the swing retains the work order without booking unfinished produce.")
	if not await _wait_for_harvest():
		return false
	receipt = ui.hud.get_node("HarvestReceipt") as Control
	caption = receipt.get_node("Caption") as Label
	_expect(receipt.visible and ("渠伯代收" in caption.text or "门客代收" in caption.text),
		"The receipt credits the worker, including when several assisted plots are grouped.")
	_expect(_settlement() == manual and state.current_stamina == stamina,
		"Delegation produces the same tribute, cash, bins, leaves and rotation without player stamina.")
	_expect(state.active_crops[ORCHARD]["age"] == 1 and state.active_crops[YOUNG]["age"] == 0
		and state.fertile_cells.has(Vector2i(4, 6)) and not state.fertile_cells.has(Vector2i(6, 5)),
		"Leaves regrow, young crops remain, and bean fertility follows the ordinary harvest rules.")
	var need: int = state.night_rations_plan().need
	_expect(need == original_food_need + state.balance.specialist_food_per_night,
		"The harvest assignment is included in the evening food plan.")
	var food: int = state.food_storage
	ui.sleep_button.pressed.emit()
	await tree.create_timer(1.1).timeout
	_expect(state.current_day == 34 and state.food_storage == food - need and state.night_rations.last.served == need,
		"Overnight advance charges the stated specialist ration.")
	print("HARVEST_COMPARE plots=", READY.size(), " manual_clicks=", READY.size(), " delegated_clicks=0 manual_stamina=", spent,
		" delegated_stamina=0 tribute=", manual.tribute - initial.tribute, " private=", manual.private - initial.private,
		" copper=", manual.money - initial.money, " leaves=", manual.leaves - initial.leaves, " extra_food=", need - original_food_need)
	return not failed

func _check_overlap() -> bool:
	var legacy: Dictionary = JSON.parse_string(baseline)
	legacy["save_version"] = 1
	legacy["retainers"][0]["assigned_area"] = "-1,-1"
	legacy["retainers"][1]["assigned_area"] = "6,5"
	if not await _restore_record(JSON.stringify(legacy)):
		return false
	_expect(state.retainers[0].duty == RetainerData.Duty.FIELD and state.retainers[0].assigned_area == Retainer.NO_CELL
		and state.retainers[1].duty == RetainerData.Duty.GUARD and state.retainers[1].assigned_area == Vector2i(6, 5),
		"The old save retains existing jobs and priorities and reads the old unassigned marker correctly.")
	state.active_crops.clear()
	state.tilled_cells.clear()
	state.well_fields[1]["center_pos"] = WEST_PUBLIC
	_stage_crop(WEST_PUBLIC, "millet", true)
	_stage_crop(WEST_PUBLIC + Vector2i.RIGHT, "sorghum", false)
	if not await _save_reload():
		return false
	await _assign_reaper(0)
	await _assign_reaper(1)
	if not await _save_reload():
		return false
	var worker := _worker(0)
	_expect(worker.data.assigned_area == WEST_PUBLIC and _worker(1).data.assigned_area == WEST_PUBLIC,
		"The real plot at the old marker coordinate remains assignable and persists in the new save.")
	if not await _wait_for_swing(worker, WEST_PUBLIC):
		return false
	_expect(_worker(1).target_grid_pos == Retainer.NO_CELL, "Two reapers given the same ripe plot do not both target it.")
	var tribute: int = state.king_storage
	var windup := worker.work_left
	world.player.global_position = world.to_global(world.get_crop_world_pos(WEST_PUBLIC)) + Vector2(0, 30)
	world.player.camera.force_update_scroll()
	await tree.process_frame
	await _click_field(WEST_PUBLIC)
	await tree.create_timer(windup + 0.3).timeout
	_expect(state.king_storage == tribute + 1 and not world.is_crop_ripe(WEST_PUBLIC)
		and not worker.tool_gesture.visible, "A manual cut during a reaper's windup settles exactly once.")
	print("HARVEST_OVERLAP workers=2 priority=", WEST_PUBLIC, " tribute=", state.king_storage - tribute)
	return not failed

func _check_reform() -> void:
	if not await _restore_baseline():
		return
	state.active_crops.clear()
	state.current_day = 51
	state.current_rank = state.Rank.DA_FU
	_stage_crop(SECOND_PUBLIC, "mulberry", true)
	if not await _save_reload():
		return
	var event := await Campaign.meet_tax_envoy(tree)
	if not _expect(event != null, "The established estate must get the normal tax reform decision."):
		return
	var supported := false
	for button: Button in event.find_children("*", "Button", true, false):
		if button.text.begins_with("支持改革"):
			button.pressed.emit()
			event.confirm_button.pressed.emit()
			supported = true
			break
	if not _expect(supported and state.tax_reform_choice == state.TaxReformChoice.REFORMED,
		"Choose reform through the event panel before delegating."):
		return
	await tree.process_frame
	var mulberry: CropData = tree.root.get_node("ItemManager").get_crop("mulberry")
	var tax_payment := int(mulberry.sell_price * (1.0 - state.tax_rate))
	# The last ripe crop can make the handoff available while sleep is pending.
	state.private_harvest_total += state.balance.ending_reformed_private - 1
	state.money = state.balance.ending_reformed_wealth - tax_payment
	state.silk_bolts_sold += state.balance.ending_silk_target
	state.raids_defeated = state.balance.ending_raids_min
	var initial := _settlement()
	var day: int = state.current_day
	var food: int = state.food_storage
	await _assign_reaper(0)
	var worker := _worker(0)
	if not await _wait_for_swing(worker):
		return
	while worker.work_left > 0.20:
		await tree.physics_frame
	ui.sleep_button.pressed.emit()
	await tree.create_timer(0.34).timeout
	var receipt := ui.hud.get_node("HarvestReceipt") as Control
	var caption := receipt.get_node("Caption") as Label
	_expect(receipt.visible and "渠伯代收" in caption.text and "桑叶 +4" in caption.text and "国库" not in caption.text
		and "铜钱 +%d" % tax_payment in caption.text and "已扣税 %d" % (mulberry.sell_price - tax_payment) in caption.text,
		"A reformed harvest previews the actual net copper, tax, leaves and worker before dawn.")
	await tree.create_timer(0.41).timeout
	_expect(not receipt.visible, "The dawn clears the previous night's harvest receipt.")
	_expect(state.king_storage == initial.tribute and state.private_harvest_total == initial.private + 1
		and state.money == initial.money + tax_payment and state.silk_workshop.leaves == state.balance.mulberry_leaves_per_harvest
		and state.route_objectives()[0]["value"] == state.balance.ending_reformed_private,
		"The converted center pays taxed private income and contributes to the reform route and leaf stock.")
	print("HARVEST_REFORM tribute=", state.king_storage - initial.tribute, " private=", state.private_harvest_total - initial.private,
		" copper=", state.money - initial.money, " leaves=", state.silk_workshop.leaves, " day=", state.current_day,
		" food_spent=", food - state.food_storage, " outcome=", state.outcome)
	var stand: Sprite2D = world.get_node("Scenery/EndingRecord")
	_expect(state.outcome == state.Outcome.RUNNING and stand.visible and not stand.archived
		and not tree.paused and state.current_day == day + 1 and state.food_storage == food - state.retainer_food_cost(),
		"Delegated harvest opens the handoff while the requested night still advances and charges food once.")

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the harvest replay's player profile."):
		tree.quit(1)
		return
	tree.root.size = Vector2i(1280, 720)
	tree.root.notify_mouse_entered()
	state = tree.root.get_node("Global")
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	tree.current_scene.new_button.pressed.emit()
	await tree.scene_changed
	_estate()
	if await _prepare_estate() and await _compare_harvests() and await _check_overlap():
		await _check_reform()
	tree.paused = false
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.create_timer(0.25).timeout
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
