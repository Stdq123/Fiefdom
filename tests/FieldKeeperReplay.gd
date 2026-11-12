extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const PUBLIC := Vector2i(5, 5)
const ROTATED := Vector2i(6, 5)
const RESERVE := Vector2i(5, 6)
const ORDINARY := Vector2i(6, 6)

var tree: SceneTree
var root: Window
var state: Node
var world: Node
var ui: Node
var capture_dir := ""
var failed := false

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failed = true
		push_error(detail)
	return condition

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.physical_keycode = code
	root.push_input(event, true)

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await tree.process_frame

func _click_cell(cell: Vector2i) -> void:
	var tiles: TileMapLayer = world.tile_map
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))

func _water(cell: Vector2i) -> void:
	if world.field_action(cell) == world.FieldAction.WATER:
		await _click_cell(cell)

func _plant(cell: Vector2i, seed_key: Key) -> void:
	_key(seed_key)
	if world.field_action(cell) == world.FieldAction.TILL:
		await _click_cell(cell)
	await _click_cell(cell)
	_expect(state.active_crops.has(cell), "Planting through the map must put a crop in %s." % cell)
	await _water(cell)

func _night() -> void:
	await _click(ui.sleep_button.get_global_rect().get_center())
	await tree.create_timer(1.18).timeout

func _open_at(actor: Node2D, offset := Vector2(0, 15)) -> Control:
	await Campaign.walk_to(tree, world.player, actor.global_position + offset)
	_key(KEY_E)
	await tree.process_frame
	return ui.get_node_or_null("Control/DialoguePanel") as Control

func _option(dialog: Control, prefix: String) -> Button:
	if dialog:
		for button: Button in dialog.options_container.get_children():
			if button.text.begins_with(prefix):
				return button
	return null

func _choose(dialog: Control, prefix: String) -> void:
	var button := _option(dialog, prefix)
	if _expect(button != null and not button.disabled, "Expected available choice " + prefix):
		await _click(button.get_global_rect().get_center())

func _journal() -> Control:
	await _click(ui.hud.neighbors_button.get_global_rect().get_center())
	var management: Control = ui.panel_manager.management_panel_instance
	return management.neighbor_journal

func _close_journal() -> void:
	var button := ui.panel_manager.management_panel_instance.get_node("CloseButton") as Button
	await _click(button.get_global_rect().get_center())

func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	_expect(frame.save_png(capture_dir.path_join(name + ".png")) == OK, "Could not capture " + name)
	print("FIELD_FRAME ", name, " ", frame.get_size())

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	root = tree.root
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run field-keeper with Test-GodotSmoke.ps1 to isolate its save.")
		tree.quit(1)
		return
	seed(3083)
	capture_dir = OS.get_environment("FIEFDOM_FIELD_CAPTURES")
	state = root.get_node("Global")
	tree.change_scene_to_file("res://scenes/Title.tscn")
	await tree.scene_changed
	tree.current_scene.new_button.pressed.emit()
	await tree.scene_changed
	await _estate()
	# These visits and farm actions can be compared across windows without an active raid.
	state.balance.raid_first_day = 10000
	var keeper: Node2D = world.retainer_instances[state.retainers.front()]
	var dialog := await _open_at(keeper)
	_expect(dialog != null and _option(dialog, "约定") == null and not state.agree_to_rotation(),
		"The story begins after the first public harvest.")
	await _choose(dialog, "离开")
	await _plant(PUBLIC, KEY_1)
	for night in 2:
		await _water(PUBLIC)
		await _night()
	await _click_cell(PUBLIC)
	_expect(state.king_storage == 1 and state.current_day == 3, "The first public crop reaches the treasury as usual.")
	dialog = await _open_at(keeper)
	_expect(dialog != null and "荒年" in dialog.text_label.text and "私田" in dialog.text_label.text,
		"The first tribute opens Qu Bo's personal story.")
	await _capture("01-a-promise-in-the-field")
	await _choose(dialog, "约定试一回轮作")
	_expect(state.field_rotation.promise_day == 3 and not state.agree_to_rotation(), "The promise is recorded once.")
	for cell in [PUBLIC, ROTATED, RESERVE]:
		await _plant(cell, KEY_5)
	await _plant(ORDINARY, KEY_1)
	for night in 2:
		for cell in [PUBLIC, ROTATED, RESERVE, ORDINARY]:
			await _water(cell)
		await _night()
	await _click_cell(PUBLIC)
	await _click_cell(ORDINARY)
	_expect(state.king_storage == 2 and state.field_rotation.beans_day == 0 and state.field_rotation.harvest_day == 0,
		"Public beans and ordinary private harvests do not progress the rotation story.")
	await _click_cell(ROTATED)
	await _click_cell(RESERVE)
	_expect(state.field_rotation.beans_day == 5 and state.fertile_cells.has(ROTATED) and state.fertile_cells.has(RESERVE),
		"Private beans give the existing soil benefit and update the journal.")
	if not _expect(state.save_game() == OK and state.load_game() == OK, "The promise and bean harvest can be saved."):
		tree.quit(1)
		return
	await tree.scene_changed
	await _estate()
	keeper = world.retainer_instances[state.retainers.front()]
	_expect(state.field_rotation.promise_day == 3 and state.field_rotation.beans_day == 5
		and state.fertile_cells.has(ROTATED), "Reloading restores the dated promise and the prepared plot.")
	var journal := await _journal()
	_expect(journal.selected == "渠伯" and "第 5 天" in journal.memory.text and "金角标" in journal.next_step.text,
		"The neighbor page points to the prepared plot after reloading.")
	await _close_journal()
	await _plant(PUBLIC, KEY_1)
	await _plant(ROTATED, KEY_4)
	for night in 3:
		for cell in [PUBLIC, ROTATED]:
			await _water(cell)
		await _night()
	await _click_cell(PUBLIC)
	_expect(state.king_storage == 4 and state.field_rotation.harvest_day == 0,
		"A public rotation preserves the existing yield bonus and leaves the private story open.")
	var copper: int = state.money
	await _click_cell(ROTATED)
	_expect(state.field_rotation.harvest_day == 8 and state.field_rotation.crop_id == "wheat"
		and state.field_rotation.field_number == 1 and state.crop_stock.count("wheat") == 2
		and state.money == copper + 2 * root.get_node("ItemManager").get_crop("wheat").sell_price,
		"The actual second crop and field are recorded, with the ordinary rotation yield and copper.")
	var book := world.get_node("FieldRotationBook") as Node2D
	var landscape := world.get_node("Landscape")
	var tracks_before: int = landscape.estate_tracks.size()
	_expect(not book.visible and not book.is_in_group("interactable"), "The field book appears after the second conversation.")
	dialog = await _open_at(keeper)
	_expect(dialog != null and "今儿收的麦" in dialog.text_label.text, "Qu Bo remembers the crop the player chose.")
	await _capture("02-two-harvests")
	await _choose(dialog, "一起记进轮作簿")
	_expect(state.field_rotation.signed_day == 8 and book.visible and book.is_in_group("interactable")
		and landscape.estate_tracks.size() == tracks_before + 1 and not state.sign_rotation_book(),
		"Signing opens the in-world book and its path once.")
	journal = await _journal()
	_expect("井田 1 的麦" in journal.memory.text and "轮作簿" in journal.next_step.text
		and journal.portrait.texture.region.position.x == 576.0, "The completed page shows the crop, book, and new portrait.")
	await _capture("03-neighbor-journal")
	await _close_journal()
	var record: AudioEffectRecord
	var bus := AudioServer.get_bus_index("SFX")
	var effect_index := AudioServer.get_bus_effect_count(bus)
	if not capture_dir.is_empty():
		record = AudioEffectRecord.new()
		AudioServer.add_bus_effect(bus, record)
		record.set_recording_active(true)
	dialog = await _open_at(book)
	_expect(dialog != null and dialog.name_label.text == "轮作簿" and "现在有 1 格" in dialog.text_label.text,
		"The physical book shows the saved story and the current number of fertile plots.")
	await _capture("04-rotation-book")
	if record:
		await tree.create_timer(0.33).timeout
		record.set_recording_active(false)
		var tap := record.get_recording()
		_expect(tap != null and tap.save_to_wav(capture_dir.path_join("bamboo-book.wav")) == OK,
			"The book sound can be recorded from the game's SFX bus.")
		AudioServer.remove_bus_effect(bus, effect_index)
	await _choose(dialog, "标出肥地")
	await Campaign.walk_to(tree, world.player, Vector2(60, 127))
	_expect(world.irrigation_overlay.fertility_highlight != null and state.fertile_cells.has(RESERVE),
		"Walking back to the field keeps the live gold highlight visible.")
	await _capture("05-fertile-plot")
	var departed: Resource = state.retainers.front()
	state.dismiss_retainer(departed)
	_expect(not is_instance_valid(world.field_guest) and state.next_field_keeper_visit() == 9,
		"A departed Qu Bo is scheduled to return as a neighbor.")
	await _night()
	_expect(world.current_visitor() != null and is_instance_valid(world.field_guest)
		and world.irrigation_overlay.fertility_highlight == null, "His visit preserves the day's other guest, and overnight clears the highlight.")
	if is_instance_valid(world.field_guest):
		dialog = await _open_at(world.field_guest)
		_expect(dialog != null and "回访" in dialog.context_label.text and "日头烈" in dialog.text_label.text
			and _option(dialog, "招募") == null, "The returning neighbor remembers the story and mentions the current season.")
		await _capture("06-returning-neighbor")
		await _choose(dialog, "离开")
	if not _expect(state.save_game() == OK and state.load_game() == OK, "A signed book can be saved after a resident departs."):
		tree.quit(1)
		return
	await tree.scene_changed
	await _estate()
	book = world.get_node("FieldRotationBook")
	_expect(book.visible and state.field_rotation.signed_day == 8 and state.field_rotation.crop_id == "wheat"
		and is_instance_valid(world.field_guest), "Reloading preserves the book, the chosen crop, and today's scheduled visit.")
	print("FIELD_STORY promised=", state.field_rotation.promise_day, " beans=", state.field_rotation.beans_day,
		" crop=", state.field_rotation.crop_id, " signed=", state.field_rotation.signed_day, " return=", state.current_day)

	var legacy := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	legacy.store_string('{"current_day":12,"king_storage":1,"retainers":[],"neighbor_met_days":{"渠伯":1}}')
	legacy.close()
	if not _expect(state.load_game(state.SAVE_PATH) == OK, "A save created before the rotation story still loads."):
		tree.quit(1)
		return
	await tree.scene_changed
	await _estate()
	_expect(state.field_rotation.promise_day == 0 and not world.get_node("FieldRotationBook").visible
		and is_instance_valid(world.field_guest), "An old save adds the visit without inventing a story or its reward.")
	if is_instance_valid(world.field_guest):
		await _choose(await _open_at(world.field_guest), "约定试一回轮作")
		_expect(state.field_rotation.promise_day == 12, "The returning neighbor can open the story on an old save.")
	tree.change_scene_to_file("res://scenes/Title.tscn")
	await tree.scene_changed
	root.get_node("AudioManager").bgm_player.stop()
	await tree.create_timer(0.35).timeout
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
