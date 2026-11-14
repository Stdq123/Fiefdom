extends "res://tests/EstateDirectionsReplay.gd"

var baseline := false

func _click_whole_field() -> void:
	var at := _point_on_field()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.shift_pressed = true
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame
	await tree.process_frame

func _choose(dialog: Control, option: String) -> bool:
	var reply := _button(dialog, option) if is_instance_valid(dialog) else null
	if not _expect(reply != null and reply.is_visible_in_tree() and not reply.disabled, "Choose " + option):
		return false
	await _click(reply.get_global_rect().get_center())
	return true

func _rotation_guide() -> Control:
	var prompt: Button = ui.hud.rotation_guide_button
	if not _expect(prompt.is_visible_in_tree() and not prompt.disabled, "The journal offers rotation without taking over the main goal."):
		return null
	await _click(prompt.get_global_rect().get_center())
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialog != null and dialog.name_label.text == "轮作试种" and _button(dialog, "合上").has_focus(),
			"The journal opens the rotation preview with Close focused."):
		return null
	var card := dialog.get_node("Panel") as Control
	_expect(tree.root.get_visible_rect().encloses(card.get_global_rect())
		and dialog.text_label.size.y >= dialog.text_label.get_content_height()
		and not dialog.text_label.get_global_rect().intersects(dialog.options_container.get_global_rect()),
		"The rotation preview fits the window without truncating the next action.")
	return dialog

func _first_batch() -> bool:
	await _click_whole_field()
	await _click_whole_field()
	while not state.field_crop_is_ripe(PUBLIC) and state.current_day < 4:
		await _click_whole_field()
		await _night()
	await _click_whole_field()
	if not _expect(state.current_day == 3 and state.king_storage == 1 and state.crop_stock.count("millet") == 8
			and state.field_rotation.promise_day == 0 and ui.hud.opening_action.text == "首茬收成 · 安排去处",
			"Harvest public and private millet together through normal play, before agreeing to rotate."):
		return false
	await _click(ui.hud.opening_action.get_global_rect().get_center())
	if not await _choose(ui.get_node_or_null("Control/DialoguePanel"), "留作物 · 看时令单"):
		return false
	await _key(KEY_ESCAPE)
	if not _expect(state.first_harvest_reviewed and state.crop_stock.count("millet") == 8,
			"Keep the first harvest and leave the order screen."):
		return false
	print("ROTATION_GUIDE_AFTER_BATCH day=", state.current_day, " tribute=", state.king_storage, " millet=", state.crop_stock.count("millet"),
		" main_action=", ui.hud.opening_action.text, " baseline=", baseline)
	await _capture("01-rotation-after-first-harvest")
	if baseline:
		return _expect(ui.hud.get_node_or_null("%RotationGuideButton") == null
			and ui.hud.opening_action.text != "找渠伯谈轮作", "The previous package loses the invitation after the first batch harvest.")
	return true

func _start_rotation() -> bool:
	var dialog := await _rotation_guide()
	if dialog == null:
		return false
	_expect("原格" in dialog.text_label.text and "门客管一整块井田" in dialog.text_label.text,
		"Explain the same-plot bonus and the reason to follow the optional story.")
	var gamepad = load("res://tests/GamepadReplay.gd").new()
	gamepad.tree = tree
	gamepad.pad = tree.root.get_node("GamepadInput")
	await gamepad._tap(JOY_BUTTON_B)
	_expect(not is_instance_valid(dialog) and state.field_rotation.promise_day == 0
		and directions.tracked_neighbor.is_empty() and world.current_seed_id == "millet",
		"Closing the preview leaves the agreement, route and seed untouched.")
	await gamepad._tap(JOY_BUTTON_B)
	await gamepad._click(ui.hud.rotation_guide_button)
	if not _expect(gamepad.failures == 0 and gamepad.pad.active, "Open the new journal entry through the gamepad pointer."):
		return false
	dialog = ui.get_node_or_null("Control/DialoguePanel")
	if not _expect(dialog != null, "The controller opens the menu."):
		return false
	await gamepad._tap(JOY_BUTTON_DPAD_LEFT)
	if not _expect(_button(dialog, "指路去找渠伯").has_focus(), "The D-pad reaches the visit action."):
		return false
	await _capture("02-rotation-promise-gamepad")
	await gamepad._tap(JOY_BUTTON_A)
	if not _expect(directions.tracked_neighbor == KEEPER and not state.field_rotation.waiting_for_harvest(),
			"Choosing directions locates the keeper without making the agreement."):
		return false
	return await _choose(await _meet(KEEPER), "约定试一回轮作")

func _grow_marked_crop(cell: Vector2i, seed: String) -> bool:
	await _click(_point_on_field(cell))
	if not _expect(state.active_crops.get(cell, {}).get("id") == seed, "Sow the offered seed on the marked plot."):
		return false
	var nights: int = state.active_crops[cell].growth_nights
	for night in nights:
		if state.field_crop_is_dry(cell):
			await _click(_point_on_field(cell))
		if state.field_crop_is_dry(PUBLIC):
			await _click(_point_on_field())
		await _night()
		if not _expect(directions.tracked_plot == cell, "The same marked plot survives the night and any rain."):
			return false
	return _expect(state.field_crop_is_ripe(cell), "The marked crop can be harvested after the quoted nights.")

func _harvest_two_crops(spawn: Vector2) -> bool:
	await Campaign.walk_to(tree, world.player, spawn)
	var dialog := await _rotation_guide()
	if not await _choose(dialog, "标出这格私田 · 换菽种"):
		return false
	var cell: Vector2i = directions.tracked_plot
	if not _expect(state.rotation_route_cell == cell and not state.is_public_plot(cell) and world.current_seed_id == "beans",
			"The player confirms the exact private plot and seed."):
		return false
	await _capture("03-marked-beans")
	await Campaign.walk_to(tree, world.player, Vector2(spawn.x, 340.0))
	_expect(directions.mark == directions.Mark.EDGE and directions.edge_direction.y < -0.6
		and directions.tracked_plot == cell, "The pinned plot is still findable after walking south out of sight.")
	await Campaign.walk_to(tree, world.player, spawn)
	await _click(ui.hud.cancel_directions.get_global_rect().get_center())
	_expect(directions.tracked_plot == null and state.rotation_route_cell == null and world.current_seed_id == "beans",
		"Cancelling clears only the guide and leaves the selected seed alone.")
	if not await _choose(await _rotation_guide(), "标出这格私田 · 换菽种"):
		return false
	# Replant the public plot early enough that the independent tribute schedule still holds.
	await _key(KEY_1)
	await _click(_point_on_field())
	await _click(_point_on_field())
	_expect("换菽种" in directions.caption.text and state.active_crops[PUBLIC].id == "millet",
		"Changing seed for the public plot keeps the rotation plot and updates its seed cue.")
	await _key(KEY_5)
	if not await _grow_marked_crop(cell, "beans"):
		return false
	await _click(_point_on_field(cell))
	if not _expect(state.fertile_cells.has(cell) and state.crop_stock.count("beans") == 1
			and state.field_rotation.beans_day == state.current_day and state.field_route_status == -1,
			"The bean harvest leaves fertility and ends the first plot route."):
		return false
	if not _expect(state.field_crop_is_ripe(PUBLIC), "The separate public planting is also ready."):
		return false
	await _click(_point_on_field())
	dialog = await _rotation_guide()
	if not _expect(dialog != null and "这格留着豆茬的肥" in dialog.text_label.text, "Explain the existing fertile plot and the next harvest."):
		return false
	await _capture("04-rotation-follow-up")
	if not await _choose(dialog, "标出这格私田 · 换黍种"):
		return false
	if not _expect(directions.tracked_plot == cell and world.current_seed_id == "millet"
			and state.field_route_status == Global.RotationRoute.FOLLOWUP, "Return to the same fertile plot, even with other open private plots."):
		return false
	var fertile_day: int = state.current_day
	await _save_and_continue()
	if not _expect(state.current_day == fertile_day and directions.tracked_plot == cell and state.fertile_cells.has(cell)
			and "留肥私田" in directions.caption.text,
			"Continue restores the exact fertile plot and what to do there."):
		return false
	await _capture("05-continued-fertile-plot")
	var public: int = state.king_storage
	var private_stock: int = state.crop_stock.count("millet")
	if not await _grow_marked_crop(cell, "millet"):
		return false
	await _click(_point_on_field(cell))
	print("ROTATION_GUIDE_HARVEST day=", state.current_day, " cell=", cell, " public=", state.king_storage,
		" millet=", private_stock, "->", state.crop_stock.count("millet"))
	return _expect(state.field_rotation.ready_to_sign() and state.field_rotation.field_number == 1
		and state.crop_stock.count("millet") == private_stock + 2 and state.king_storage == public
		and not state.fertile_cells.has(cell) and state.field_route_status == -1,
		"The second harvest consumes the soil bonus, gives two private millet and completes the plot directions.")

func _sign_and_appoint() -> void:
	var action: Button = ui.hud.opening_action
	if not _expect(action.visible and action.text == "找渠伯记轮作", "The finished crop offers a route to the keeper."):
		return
	await _click(action.get_global_rect().get_center())
	if not await _choose(await _meet(KEEPER), "一起记进轮作簿"):
		return
	# Close out the day so the saved journey can still be resumed from the journal.
	await _night()
	await _save_and_continue()
	action = ui.hud.rotation_guide_button
	if not _expect(action.visible and action.text == "找轮作簿" and state.field_steward_unlocked(), "The signed book remains findable the next day after continuing."):
		return
	await _click(action.get_global_rect().get_center())
	var book := world.get_node("FieldRotationBook") as Node2D
	if not _expect(directions.destination().title == "轮作簿", "The journal points to the built book."):
		return
	await Campaign.walk_estate_road_to(tree, world, book.global_position + Vector2(0, 12))
	await _key(KEY_E)
	if not await _choose(ui.get_node_or_null("Control/DialoguePanel"), "安排轮作与管事"):
		return
	var panel: Control = ui.panel_manager.management_panel_instance
	var picker: OptionButton = panel.steward_picker
	if not _expect(panel.visible and panel.well_field_selector.get_selected_id() == 0 and picker.has_focus()
			and picker.item_count == 2 and KEEPER in picker.get_item_text(1), "The player's first field offers its own keeper as steward."):
		return
	await _click(picker.get_global_rect().get_center())
	var menu := picker.get_popup()
	if not _expect(menu.visible, "The roster menu opens through the visible steward picker."):
		return
	menu.set_focused_item(1)
	for pressed in [true, false]:
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = pressed
		Input.parse_input_event(enter)
		Input.flush_buffered_events()
		await tree.process_frame
	var rations: int = state.retainer_food_cost()
	if not _expect(picker.selected == 1 and not panel.apply_steward.disabled and "用粮 1 → 2 份" in panel.steward_preview.text,
			"Select Qu Bo and inspect the ration and sowing plan before confirming: %s" % panel.steward_preview.text):
		return
	await _capture("06-appoint-first-steward")
	await _click(panel.apply_steward.get_global_rect().get_center())
	await _key(KEY_ESCAPE)
	await _save_and_continue()
	if not _expect(state.retainers.size() == 1, "The confirmed household is restored after saving."):
		return
	var worker: RetainerData = state.retainers[0]
	_expect(worker.name == KEEPER and worker.duty == RetainerData.Duty.STEWARD and state.stewarded_field(worker).field_id == 0
		and state.retainer_food_cost() == rations + 1 and not ui.hud.rotation_guide_button.visible,
		"Keep the confirmed duty, field and actual ration rate after continuing, and dismiss the handoff.")
	print("ROTATION_GUIDE_STEWARD day=", state.current_day, " field=", state.stewarded_field(worker).field_id + 1,
		" promised=", state.field_rotation.promise_day, " beans=", state.field_rotation.beans_day,
		" extra_crop=", state.field_rotation.harvest_day, " signed=", state.field_rotation.signed_day,
		" rations=", rations, "->", state.retainer_food_cost())
	await _watch_delegated_farming()

func _watch_delegated_farming() -> void:
	var day: int = state.current_day
	var paid: int = state.retainer_food_cost()
	for frame in 2400:
		if state.active_crops.size() == 9 and state.active_crops.values().all(func(crop: Dictionary) -> bool: return crop.watered):
			break
		await tree.physics_frame
	_expect(state.field_seed_plans.size() == 9 and state.active_crops.size() == 9
		and state.active_crops.get(PUBLIC, {}).get("id") == "millet" and not state.field_crop_is_dry(PUBLIC),
		"The new steward sows the appointed field and waters the public crop without farming clicks.")
	await _capture("07-steward-at-work")
	await _night()
	_expect(state.current_day == day + 1 and state.night_rations.last.served == paid,
		"The steward takes the quoted amount at dawn.")
	print("ROTATION_GUIDE_DELEGATED day=", state.current_day, " plans=", state.field_seed_plans.size(),
		" planted=", state.active_crops.size(), " tribute=", state.king_storage, " private=", state.private_harvest_total,
		" night_rations=", state.night_rations.last.served)

func _load_schedule_fixture(completed: bool) -> bool:
	var fixture := {
		"current_day": 5, "quest_progress": 1, "king_storage": 1, "food_storage": 12,
		"retainers": [], "field_rotation": {"promise_day": 3},
		"well_fields": [{"center_pos": "5,5", "is_unlocked": true, "reclamation_progress": Global.RECLAMATION_NIGHTS}],
		"tilled_cells": ["6,5"], "fertile_cells": [] if completed else ["6,5"],
	}
	if completed:
		fixture.field_rotation.merge({"harvest_day": 4, "field_number": 1, "crop_id": "millet", "beans_day": 3})
	var path := "user://rotation-guide-schedule.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _expect(file != null, "Write the isolated schedule fixture."):
		return false
	file.store_string(JSON.stringify(fixture))
	file.close()
	if not _expect(state.load_game(path) == OK, "Read a rotation save without any pinned plot."):
		return false
	await _use_estate()
	return true

func _check_saved_states() -> void:
	if not await _load_schedule_fixture(false):
		return
	var dialog := await _rotation_guide()
	if not await _choose(dialog, "标出这格私田 · 换黍种"):
		return
	if not _expect(directions.tracked_plot == Vector2i(6, 5) and state.field_rotation.beans_day == 0,
			"An existing fertile plot works even when beans were harvested before the agreement."):
		return
	# A second fertile plot appears before saving. Continuing must restore the pinned cell.
	var alternate: Vector2i = PUBLIC + Vector2i.DOWN
	state.tilled_cells[alternate] = true
	state.fertile_cells[alternate] = true
	await _save_and_continue()
	_expect(state.fertile_cells.has(alternate) and directions.tracked_plot == Vector2i(6, 5),
		"Restoring the route keeps the chosen plot even when another could serve the same step.")
	if not await _load_schedule_fixture(true):
		return
	dialog = await _rotation_guide()
	if not _expect(dialog != null and "第 6 天回井田西南" in dialog.text_label.text
			and _button(dialog, "指路去记簿") == null and directions.tracked_neighbor.is_empty(),
			"The journal gives the next real visit date while Qu Bo is away."):
		return
	await _key(KEY_ESCAPE)
	await _night()
	_expect(state.current_day == 6 and world.neighbor_actor(KEEPER) != null and ui.hud.opening_action.text == "找渠伯记轮作",
		"The visitor appears that day and the journal can lead the player to him.")
	print("ROTATION_GUIDE_VISIT absent=5 expected=6 available=", state.current_day)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated rotation guide profile."):
		await _finish()
		return
	if capture_dir.is_empty():
		capture_dir = OS.get_environment("FIEFDOM_ROTATION_CAPTURES")
	state = tree.root.get_node("Global")
	tree.root.notify_mouse_entered()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _click(tree.current_scene.new_button.get_global_rect().get_center())
	await _use_estate()
	var start: Vector2 = world.player.global_position
	if await _first_batch() and not baseline and await _start_rotation() and await _harvest_two_crops(start):
		await _sign_and_appoint()
		if not failed:
			await _check_saved_states()
	await _finish()
