extends "res://tests/FieldWorksiteReplay.gd"

const Campaign := preload("res://tests/CampaignReplay.gd")
const PUBLIC := Vector2i(5, 5)
const DIAGONAL_START := Vector2(4.25, 4.25)
const DIAGONAL_END := Vector2(6.70, 5.05)
const PRIVATE_PATH := [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(6, 5)]
const WALK_START := Vector2(11.45, 6.45)
const WALK_MIDDLE := Vector2i(12, 6)
const WALK_END := Vector2i(13, 6)
const HOVER_CROP := Vector2i(13, 4)
const BATCH_PRIVATE := Vector2i(6, 5)

func _fixture() -> void:
	var crops := {}
	for cell: Vector2i in PRIVATE_PATH + [PUBLIC, Vector2i(4, 5), Vector2i(5, 6), Vector2i(11, 6), WALK_MIDDLE, WALK_END, HOVER_CROP]:
		crops["%d,%d" % [cell.x, cell.y]] = {"id": "millet", "age": 2, "growth_nights": 2}
	var save := FileAccess.open(state.SAVE_PATH, FileAccess.WRITE)
	save.store_string(JSON.stringify({
		"save_version": 2, "current_day": 18, "current_rank": state.Rank.ZHONG_SHI, "food_storage": 30,
		"well_fields": [
			{"center_pos": "5,5", "is_unlocked": true, "reclamation_progress": 4},
			{"center_pos": "12,5", "is_unlocked": true, "reclamation_progress": 4},
		],
		"active_crops": crops,
	}))
	save.close()

func _save_manually() -> void:
	await _button(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	_expect(settings.save_status.text == "游戏已保存", "Save the mature plots through Settings.")
	await _button(settings.close_button)

func _grid_point(at: Vector2) -> Vector2:
	var size := Vector2(tiles.tile_set.tile_size)
	var origin := tiles.map_to_local(Vector2i.ZERO) - size * 0.5
	return tiles.get_global_transform_with_canvas() * (origin + at * size)

func _motion(at: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	tree.root.push_input(event, true)
	await tree.process_frame

func _mouse(at: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT, shifted := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	event.global_position = at
	event.shift_pressed = shifted
	tree.root.push_input(event, true)
	await tree.process_frame

func _stroke(from: Vector2, to: Vector2) -> void:
	await _motion(from, false)
	await _mouse(from, true)
	await _motion(to, true)

func _diagonal(baseline: bool) -> void:
	var stamina: int = state.current_stamina
	var stock: int = state.player_inventory
	var tribute: int = state.king_storage
	var money: int = state.money
	var price := ItemManager.get_crop("millet").sell_price
	var from := _grid_point(DIAGONAL_START)
	var to := _grid_point(DIAGONAL_END)
	await _stroke(from, to)
	var public_gain: int = state.king_storage - tribute
	var private_gain: int = state.player_inventory - stock
	var harvests := public_gain + private_gain
	if baseline:
		_expect(harvests == 3 and public_gain == 1 and private_gain == 2
			and state.active_crops.has(PRIVATE_PATH[1]) and state.active_crops.has(PRIVATE_PATH[2]),
			"The old diagonal jumps into the public center and skips the two private plots under the cursor.")
	else:
		_expect(harvests == 4 and public_gain == 0 and private_gain == 4 and state.active_crops.has(PUBLIC)
			and state.money == money + price * 4 and state.current_stamina == stamina - 12,
			"One fast stroke harvests the four touched private plots and preserves the public center.")
		for cell in PRIVATE_PATH:
			_expect(not state.active_crops.has(cell), "Each plot crossed by the physical drag is harvested.")
	await _capture("01-diagonal-harvest")
	await _mouse(to, false)
	print("FIELD_STROKE_DIAGONAL baseline=", baseline, " harvests=", harvests, " public=", public_gain, " private=", private_gain)
	if not baseline:
		await _click(_point(PUBLIC))
		_expect(state.king_storage == tribute + 1 and state.player_inventory == stock + 4,
			"A separate click still sends the public harvest to the treasury.")
		var receipt := ui.hud.get_node("HarvestReceipt") as Control
		var caption := receipt.get_node("Caption") as Label
		_expect(receipt.visible and "收获 5 格" in caption.text and "国库 +1" in caption.text
			and "作物 +4" in caption.text and "铜钱 +%d" % (price * 4) in caption.text,
			"The separate click and the preceding drag share one public and private receipt.")
		_expect(ui.hud.map_space_clear(receipt.get_global_rect()), "The receipt stays above the seed belt and within the viewport.")
		await _capture("01b-combined-harvest-receipt")
		print("FIELD_STROKE_RECEIPT plots=5 public=1 private=4 copper=", price * 4)

func _rapid_separate_harvest() -> void:
	await tree.create_timer(1.65).timeout
	var receipt := ui.hud.get_node("HarvestReceipt") as Control
	var caption := receipt.get_node("Caption") as Label
	_expect(not receipt.visible, "The previous harvest receipt has expired.")
	var stock: int = state.player_inventory
	await _click(_point(Vector2i(4, 5)))
	await _click(_point(Vector2i(5, 6)))
	_expect(state.player_inventory == stock + 2 and receipt.visible and "收获 2 格" in caption.text
		and "作物 +2" in caption.text and "国库" not in caption.text,
		"Two ordinary presses make a fresh receipt without retaining earlier tribute.")
	await _capture("01c-two-separate-harvest-clicks")
	await tree.create_timer(1.65).timeout
	_expect(not receipt.visible, "The new receipt also fades and disappears.")

func _camera_drag(baseline: bool) -> void:
	var start := _grid_point(WALK_START)
	await _motion(start, false)
	await _mouse(start, true)
	await _move(&"ui_right", 19)
	await tree.create_timer(0.44).timeout
	_expect(world.field_at(start) == WALK_END and state.active_crops.has(WALK_MIDDLE) and state.active_crops.has(WALK_END),
		"A moving camera shifts two cells under the held pointer before it moves.")
	var finish := start + Vector2(2, 0)
	_expect(world.field_at(finish) == WALK_END, "The next mouse motion stays inside the new visible tile.")
	await _motion(finish, true)
	_expect(not state.active_crops.has(WALK_END) and state.active_crops.has(WALK_MIDDLE) != baseline,
		"Only screen-space mouse travel acts on the field after the camera follows the player.")
	var kept_middle: bool = state.active_crops.has(WALK_MIDDLE)
	await _capture("02-camera-during-stroke")
	await _mouse(finish, false)
	print("FIELD_STROKE_CAMERA baseline=", baseline, " middle_ripe=", kept_middle)

func _exact_corner() -> void:
	var from := _grid_point(Vector2(11.5, 5.5))
	var to := _grid_point(Vector2(12.5, 4.5))
	await _stroke(from, _grid_point(Vector2(12, 5)))
	await _motion(to, true)
	await _mouse(to, false)
	_expect(state.tilled_cells.has(Vector2i(11, 5)) and state.tilled_cells.has(Vector2i(12, 4))
		and not state.tilled_cells.has(Vector2i(12, 5)) and not state.tilled_cells.has(Vector2i(11, 4)),
		"Sampling exactly at a corner tills the two diagonal interiors.")

func _hover_near_calendar(baseline: bool) -> void:
	var player: Player = world.player
	var center := tree.root.get_visible_rect().get_center()
	await _motion(center, false)
	await _mouse(center, true, MOUSE_BUTTON_WHEEL_UP)
	_expect(player.camera.zoom == Vector2(3, 3), "The player can use the close camera view.")
	var calendar := ui.hud.get_node("Calendar") as Control
	var cover := calendar.get_global_rect()
	var scale_in_view := tiles.get_global_transform_with_canvas().get_scale()
	var half_tile := Vector2(tiles.tile_set.tile_size) * scale_in_view * 0.5
	var desired := Vector2(cover.get_center().x, cover.end.y + half_tile.y + 5.0)
	var shift := (_point(HOVER_CROP) - desired) / scale_in_view
	await Campaign.walk_to(tree, player, player.global_position + shift)
	await tree.create_timer(0.55).timeout
	await _motion(_point(HOVER_CROP), false)
	await tree.process_frame
	await tree.process_frame
	var cursor: Node2D = tiles.get_node("FieldCursor")
	var caption: Control = cursor.caption
	var label_rect := caption.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, caption.size)
	var covered := calendar.get_global_rect().intersects(label_rect)
	_expect(cursor.visible and caption.visible and "收获" in cursor.label.text and covered == baseline,
		"The crop action is near the cursor and clear of the calendar in the close view.")
	await _capture("03-hover-at-calendar")
	print("FIELD_STROKE_HOVER baseline=", baseline, " covered=", covered, " caption=", label_rect)

func _whole_field() -> void:
	var at := _point(PUBLIC)
	await _motion(at, false)
	var cursor: Node2D = tiles.get_node("FieldCursor")
	_expect(cursor.visible and cursor.caption.visible and "预览整田翻地" in cursor.label.text,
		"Pointing at fresh soil explains the whole-field modifier in game.")
	var modifier := InputEventKey.new()
	modifier.keycode = KEY_SHIFT
	modifier.physical_keycode = KEY_SHIFT
	modifier.pressed = true
	Input.parse_input_event(modifier)
	Input.flush_buffered_events()
	await tree.process_frame
	await tree.process_frame
	_expect(cursor.preview_plots.size() == 9 and "公田 1 · 私田 8" in cursor.label.text
		and "18 体力" in cursor.label.text and state.tilled_cells.is_empty(), "The full quote previews all nine plots without changing them.")
	var caption: Control = cursor.caption
	var label_rect := caption.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, caption.size)
	var field_rect := Rect2(_grid_point(Vector2(4, 4)), _grid_point(Vector2(7, 7)) - _grid_point(Vector2(4, 4)))
	_expect(not label_rect.intersects(field_rect), "The quote leaves the nine highlighted plots visible.")
	await _capture("field-batch-01-till-preview")
	await _mouse(at, true, MOUSE_BUTTON_LEFT, true)
	await _mouse(at, false, MOUSE_BUTTON_LEFT, true)
	_expect(state.tilled_cells.size() == 9 and state.current_stamina == 82 and state.active_crops.is_empty(),
		"One deliberate press tills the nine plots, applies nine normal costs and never plants on the same press.")
	await _mouse(at, true, MOUSE_BUTTON_LEFT, true)
	await _mouse(at, false, MOUSE_BUTTON_LEFT, true)
	_expect(state.active_crops.size() == 9 and state.current_stamina == 64 and state.field_crop_is_dry(PUBLIC),
		"A fresh press plants the selected seed once in each tilled plot.")
	modifier.pressed = false
	Input.parse_input_event(modifier)
	Input.flush_buffered_events()
	await _click(_point(BATCH_PRIVATE))
	_expect(state.current_stamina == 63 and not state.field_crop_is_dry(BATCH_PRIVATE) and state.field_crop_is_dry(PUBLIC),
		"Releasing the modifier restores a single-plot tool on the same field.")
	var full: int = state.current_stamina
	state.current_stamina = 7
	GameEvents.stamina_changed.emit(state.current_stamina)
	await tree.create_timer(0.65).timeout
	modifier.pressed = true
	Input.parse_input_event(modifier)
	Input.flush_buffered_events()
	await _motion(at, false)
	await tree.process_frame
	_expect(cursor.preview_plots.size() == 8 and "还差 1" in cursor.label.text,
		"The watering quote excludes the wet plot and gives the exact shortfall.")
	await _capture("field-batch-02-insufficient-water")
	await _mouse(at, true, MOUSE_BUTTON_LEFT, true)
	await _mouse(at, false, MOUSE_BUTTON_LEFT, true)
	_expect(state.current_stamina == 7 and state.field_crop_is_dry(PUBLIC), "An unaffordable field job changes no plot.")
	state.current_stamina = full
	GameEvents.stamina_changed.emit(state.current_stamina)
	await _mouse(at, true, MOUSE_BUTTON_LEFT, true)
	await _mouse(at, false, MOUSE_BUTTON_LEFT, true)
	_expect(state.current_stamina == 55 and not state.field_crop_is_dry(PUBLIC), "The eight dry plots each take one stamina.")
	modifier.pressed = false
	Input.parse_input_event(modifier)
	Input.flush_buffered_events()
	await _sleep()
	await _mouse(_point(PUBLIC), true, MOUSE_BUTTON_LEFT, true)
	await _mouse(_point(PUBLIC), false, MOUSE_BUTTON_LEFT, true)
	await _sleep()
	_expect(state.current_day == 3 and state.field_crop_is_ripe(PUBLIC) and state.field_crop_is_ripe(BATCH_PRIVATE),
		"A whole field still needs the ordinary two watered nights.")
	await _save_manually()
	await _continue_latest()
	var storage: int = state.food_storage
	var price := ItemManager.get_crop("millet").sell_price
	await _mouse(_point(PUBLIC), true, MOUSE_BUTTON_LEFT, true)
	await _mouse(_point(PUBLIC), false, MOUSE_BUTTON_LEFT, true)
	_expect(state.king_storage == 1 and state.crop_stock.count("millet") == 8 and state.money == 8 * price
		and state.active_crops.is_empty() and state.food_storage == storage and state.current_stamina == 73,
		"After continuing, one harvest yields one tribute unit, eight private crops and ordinary copper without spending food.")
	var receipt: Control = ui.hud.get_node("HarvestReceipt")
	_expect(receipt.visible and receipt.plots == 9 and receipt.tribute == 1 and receipt.stock == 8,
		"The harvest displays a single receipt with the public and private totals.")
	await _capture("field-batch-03-harvest-receipt")
	print("FIELD_BATCH result day=", state.current_day, " tribute=", state.king_storage, " private=", state.player_inventory,
		" copper=", state.money, " harvest_stamina=", 100 - state.current_stamina)

func _batch_respects_field_edges() -> void:
	var tribute: int = state.king_storage
	var stock: int = state.player_inventory
	await _mouse(_point(PUBLIC), true, MOUSE_BUTTON_LEFT, true)
	await _mouse(_point(PUBLIC), false, MOUSE_BUTTON_LEFT, true)
	_expect(state.king_storage == tribute + 1 and state.player_inventory == stock + 6
		and state.field_crop_is_ripe(HOVER_CROP) and state.field_crop_is_ripe(WALK_END),
		"The first field harvest does not reach the next field or act on the two bare plots.")

func run_field_stroke(game_tree: SceneTree, baseline := false, captures := "") -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the field stroke replay."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = captures
	tree.root.notify_mouse_entered()
	if not legacy:
		_fixture()
	await _continue_latest()
	if baseline:
		await _save_manually()
	await _diagonal(baseline)
	if not baseline and not legacy:
		await _rapid_separate_harvest()
	await _camera_drag(baseline)
	if not baseline:
		await _exact_corner()
	await _hover_near_calendar(baseline)
	tree.unload_current_scene()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)

func run_field_batch(game_tree: SceneTree, captures := "", mixed := false) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the whole-field replay."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = captures
	tree.root.notify_mouse_entered()
	if mixed:
		_fixture()
		await _continue_latest()
		await _batch_respects_field_edges()
	else:
		tree.change_scene_to_file(state.TITLE_SCENE)
		await tree.scene_changed
		var start: Button = tree.current_scene.new_button
		await tree.process_frame
		var at := start.get_global_rect().get_center()
		await _motion(at, false)
		await _mouse(at, true)
		# The release changes the scene on its deferred path before the next frame.
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = at
		release.global_position = at
		tree.root.push_input(release, true)
		for frame in range(30):
			if tree.current_scene and tree.current_scene.scene_file_path == state.ESTATE_SCENE:
				break
			await tree.process_frame
		if not _expect(tree.current_scene and tree.current_scene.scene_file_path == state.ESTATE_SCENE,
			"Start a fresh field batch from the title button."):
			tree.quit(1)
			return
		await _estate()
		await _whole_field()
	tree.unload_current_scene()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
