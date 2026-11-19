extends "res://tests/FieldRoutesReplay.gd"

const PRIVATE_B := Vector2i(4, 5)
const PRIVATE_C := Vector2i(4, 6)
const PLOT_SEEDS := {PUBLIC: "millet", FIRST_PRIVATE: "wheat", PRIVATE_B: "beans", PRIVATE_C: "hemp",
	SECOND_FIELD: "millet", SECOND_RIPE: "sorghum"}

var controller: RefCounted
var use_gamepad := false

func _fixture_data(public_route := false, reformed := false) -> Dictionary:
	var crops := {}
	for cell: Vector2i in PLOT_SEEDS:
		crops[str(cell)] = {"id": PLOT_SEEDS[cell], "age": 6, "growth_nights": 2}
	return {
		"current_day": 31, "king_storage": 5, "money": 40, "food_storage": 9, "current_stamina": 80,
		"well_fields": [
			{"center_pos": str(PUBLIC), "is_unlocked": true, "reclamation_progress": 4},
			{"center_pos": str(SECOND_FIELD), "is_unlocked": true, "reclamation_progress": 4}],
		"fertile_cells": [str(PRIVATE_C)], "active_crops": crops, "field_route_public_only": public_route,
		"field_route_status": state.NightGrowth.READY if public_route else -1,
		"tax_reform_choice": state.TaxReformChoice.REFORMED if reformed else state.TaxReformChoice.NONE,
		"tax_rate": 0.2 if reformed else 0.0,
	}

func _write_checkpoint(path: String, fixture: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()

func _resume_at_title() -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE, "Continue through the normal title."):
		return false
	await _use_estate()
	return _expect(state.current_day == 31, "Resume the day 31 checkpoint.")

func _point_at(cell: Vector2i) -> Vector2:
	var tiles: TileMapLayer = world.tile_map
	return tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)

func _hold_batch(active: bool, pad: bool) -> void:
	if pad:
		controller._axis(JOY_AXIS_TRIGGER_LEFT, 1.0 if active else 0.0)
	else:
		var shift := InputEventKey.new()
		shift.keycode = KEY_SHIFT
		shift.physical_keycode = KEY_SHIFT
		shift.pressed = active
		Input.parse_input_event(shift)
		Input.flush_buffered_events()
	await tree.process_frame

func _preview_at(cell: Vector2i, pad := false) -> Control:
	var point := _point_at(cell)
	if pad:
		await controller._aim(point)
	else:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		tree.root.push_input(motion, true)
	await _hold_batch(true, pad)
	await tree.process_frame
	return world.tile_map.get_node("FieldCursor").caption

func _take_batch(cell: Vector2i, pad := false) -> void:
	if pad:
		await controller._tap(JOY_BUTTON_A)
	else:
		await _click(_point_at(cell))
	await _hold_batch(false, pad)
	await tree.process_frame

func _private_route() -> void:
	await _button(ui.hud.farm_status)
	var map: Control = ui.estate_map
	if not _expect(map.modal.visible and "可收 6" in map.harvest_route.text
		and map.public_harvest_route.text == "收公田 2" and map.private_harvest_route.text == "收私田 4"
		and map.public_harvest_route.is_visible_in_tree() and map.private_harvest_route.is_visible_in_tree(),
		"The map offers both ownership scopes and the original combined route."):
		return
	await _snapshot("01-choose-harvest-group")
	await _button(map.public_harvest_route)
	_expect(state.field_route_scope == state.FieldScope.PUBLIC and ui.directions.tracked_plot == PUBLIC,
		"The map's public option starts at the first public crop.")
	await _button(ui.hud.farm_status)
	if use_gamepad:
		await controller._click(map.private_harvest_route, true)
	else:
		await _button(map.private_harvest_route)
	if not _expect(not tree.paused and state.field_route_scope == state.FieldScope.PRIVATE
		and not state.is_public_plot(ui.directions.tracked_plot) and state.save_game() == OK,
		"Start the private harvest route and save it."):
		return
	if not await _resume_at_title():
		return
	_expect(state.field_route_scope == state.FieldScope.PRIVATE and state.field_crop_is_ripe(PUBLIC)
		and "收获私田" in ui.hud.cancel_directions.text, "Continue restores the private route and all crops.")
	await _preview_at(PUBLIC)
	var hint: Node2D = world.tile_map.get_node("FieldCursor")
	_expect("批量只收私田" in hint.label.text and hint.preview_plots.is_empty(), "Tell the player when a public plot is outside the batch.")
	await _take_batch(PUBLIC)
	_expect(state.king_storage == 5 and state.current_stamina == 80, "The out-of-scope batch changes nothing.")
	var caption := await _preview_at(FIRST_PRIVATE, use_gamepad)
	var bounds := caption.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, caption.size)
	_expect(tree.root.get_visible_rect().encloses(bounds) and hint.preview_plots == [FIRST_PRIVATE, PRIVATE_B, PRIVATE_C]
		and "批收私田" in hint.label.text and "私仓 +4" in hint.label.text and "9 体力" in hint.label.text,
		"Preview three private plots, the rotation yield and the stamina cost without covering the screen.")
	var quoted_copper := ItemManager.get_crop("wheat").sell_price + ItemManager.get_crop("beans").sell_price \
		+ 2 * ItemManager.get_crop("hemp").sell_price
	await _snapshot("02-private-batch-preview")
	await _take_batch(FIRST_PRIVATE, use_gamepad)
	_expect(state.king_storage == 5 and state.field_crop_is_ripe(PUBLIC) and state.field_crop_is_ripe(SECOND_FIELD)
		and state.player_inventory == 4 and state.money == 40 + quoted_copper and state.current_stamina == 71
		and ui.directions.tracked_plot == SECOND_RIPE, "One batch settles the private yield and advances to the other field.")
	await _snapshot("03-private-harvest-receipt")
	await _preview_at(SECOND_RIPE)
	await _take_batch(SECOND_RIPE)
	_expect(state.field_route_status == -1 and state.field_route_scope == state.FieldScope.ALL
		and state.king_storage == 5 and state.player_inventory == 5 and state.food_storage == 9,
		"Finish the private route while leaving both public crops and the pantry.")
	print("HARVEST_SCOPE_PRIVATE plots=4 batch_presses=2 tribute=", state.king_storage,
		" private=", state.player_inventory, " stamina=", state.current_stamina)

func _public_checkpoint(before: bool) -> void:
	if not _expect(ui.directions.tracked_plot == PUBLIC and "收获公田" in ui.hud.cancel_directions.text,
		"The old public-only save resumes at the public field."):
		return
	await _preview_at(PUBLIC)
	await _snapshot("04-public-route-preview")
	await _take_batch(PUBLIC)
	var expected_stock := 4 if before else 0
	_expect(state.king_storage == 6 and state.player_inventory == expected_stock
		and state.field_crop_is_ripe(FIRST_PRIVATE) != before
		and state.current_stamina == (68 if before else 77) and ui.directions.tracked_plot == SECOND_FIELD,
		"Settle the day 31 public batch with the expected scope and ordinary costs.")
	await _snapshot("05-public-route-receipt")
	print("HARVEST_SCOPE_PUBLIC before=", before, " tribute=", state.king_storage,
		" private=", state.player_inventory, " stamina=", state.current_stamina)

func _after_reform() -> void:
	var path := "user://reformed-batch.json"
	_write_checkpoint(path, _fixture_data(false, true))
	if not _expect(state.load_game(path) == OK, "Load the same plots under reform."):
		return
	await tree.scene_changed
	await _use_estate()
	await _button(ui.hud.farm_status)
	var map: Control = ui.estate_map
	_expect(map.harvest_route.is_visible_in_tree() and not map.public_harvest_route.visible
		and not map.private_harvest_route.visible, "After reform, the harvest entry covers all private land.")
	await _button(map.harvest_route)
	await _preview_at(PUBLIC)
	var hint: Node2D = world.tile_map.get_node("FieldCursor")
	_expect("私仓 +5" in hint.label.text and "扣税" in hint.label.text, "Quote the converted public cell and the actual levy.")
	var quote: Dictionary = world.batch_harvest_totals(hint.preview_plots)
	await _take_batch(PUBLIC)
	var receipt: Control = ui.hud.get_node("HarvestReceipt")
	_expect(state.king_storage == 5 and state.player_inventory == 5 and state.current_stamina == 68
		and state.money == 40 + quote.copper and quote.levy > 0 and receipt.levy == quote.levy,
		"The merged harvest keeps its normal stamina and income rules after reform.")

func run_harvest_scope(game_tree: SceneTree, captures := "", variant := "harvest-scope") -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated harvest scope profile."):
		tree.quit(1)
		return
	capture_dir = captures
	state = tree.root.get_node("Global")
	tree.root.notify_mouse_entered()
	use_gamepad = variant == "harvest-scope-pad"
	if use_gamepad:
		controller = load("res://tests/GamepadReplay.gd").new()
		controller.tree = tree
		controller.pad = tree.root.get_node("GamepadInput")
	var before := variant == "harvest-scope-before"
	var resume_public := variant == "harvest-scope-resume"
	if not resume_public:
		_write_checkpoint(state.SAVE_PATH, _fixture_data(before))
	if await _resume_at_title():
		if before or resume_public:
			if not before or _expect(state.save_game() == OK, "Keep the previous export's public route save."):
				await _public_checkpoint(before)
		else:
			await _private_route()
			if not failed:
				var path := "user://legacy-public-batch.json"
				_write_checkpoint(path, _fixture_data(true))
				if _expect(state.load_game(path) == OK, "Read a legacy public-only route."):
					await tree.scene_changed
					await _use_estate()
					await _public_checkpoint(false)
			if not failed:
				await _after_reform()
	if controller:
		_expect(controller.failures == 0, "The gamepad can select and confirm the split batch.")
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
