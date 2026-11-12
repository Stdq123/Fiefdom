extends "res://tests/WestMarketReplay.gd"

const MULBERRY := Vector2i(6, 5)
var world: Node2D
var ui: CanvasLayer
var legacy := false

func _fixture() -> void:
	var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"save_version": 2, "current_day": 27, "money": 40, "food_storage": 24, "king_storage": 3,
		"retainers": [{"name": "渠伯", "school": 2, "duty": 0}],
		"well_fields": [{"center_pos": "5,5", "is_unlocked": true, "reclamation_progress": 4}],
		"active_crops": {
			"5,5": {"id": "millet", "age": 2, "growth_nights": 2},
			"6,5": {"id": "mulberry", "age": 4, "growth_nights": 4},
		},
		"silk_workshop": {"built": true, "leaves": 14},
	}))
	file.close()

func _continue() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await tree.process_frame
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	state.balance.raid_first_day = 1000

func _silk() -> Control:
	await _button(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	management.show_silk()
	await tree.process_frame
	return management.silk_panel

func _close_management() -> void:
	await _button(ui.panel_manager.management_panel_instance.get_node("CloseButton"))

func _overnight() -> void:
	await _button(ui.sleep_button)
	await tree.create_timer(1.18).timeout

func _plan() -> Control:
	await _button(ui.hud.rations_button)
	return ui.get_node("Control/NightRationsPanel")

func _choose_reeling() -> void:
	var list: VBoxContainer = ui.panel_manager.management_panel_instance.retainer_list_container
	var picker: OptionButton = list.get_child(0).duty_picker
	await _button(picker)
	var menu := picker.get_popup()
	if not _expect(menu.visible, "Open the keeper's duty selector."):
		return
	menu.set_focused_item(picker.get_item_index(RetainerData.Duty.REEL))
	for pressed in [true, false]:
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = pressed
		Input.parse_input_event(enter)
		Input.flush_buffered_events()
		await tree.process_frame
	_expect(state.retainers[0].duty == RetainerData.Duty.REEL, "The keeper takes the reeling duty.")

func _click_crop(cell: Vector2i) -> void:
	var layer: TileMapLayer = world.tile_map
	await _click(layer.get_global_transform_with_canvas() * layer.map_to_local(cell))

func _first_three_batches() -> void:
	var panel := await _silk()
	_expect(not panel.repeat_button.button_pressed and "共用 4 片桑叶" in panel.status_label.text,
		"The workshop explains the full batch cost and waits for the player to enable repeat.")
	await _button(panel.repeat_button)
	_expect(state.silk_workshop.repeat_batches and state.silk_workshop.nights_left == 0 and state.silk_workshop.leaves == 14,
		"Setting the schedule leaves stock alone until the night.")
	await _snapshot("01-automatic-setup")
	await _close_management()
	var plan := await _plan()
	_expect(plan.silk_note.visible and "续养一批 · 用桑叶 2 片" in plan.silk_note.text,
		"The bedtime preview shows the same planned first feed.")
	await _snapshot("02-first-night-preview")
	await _button(plan.get_node("%Sleep"))
	await tree.create_timer(1.18).timeout
	await _continue()
	_expect(state.current_day == 28 and state.silk_workshop.repeat_batches and state.silk_workshop.nights_left == 1
		and state.silk_workshop.leaves == 12, "Continue keeps the scheduled repeat and the already fed night.")
	for night in 5:
		await _overnight()
	_expect(state.current_day == 33 and state.silk_workshop.leaves == 2 and state.silk_workshop.cocoons == 6,
		"The six ordinary nights turn twelve leaves into six cocoons without restarting each batch.")
	panel = await _silk()
	var reel: Button = panel.bulk_buttons[SilkWorkshop.Action.REEL]
	_expect(reel.text == "缫完 6 茧", "The bulk reel names the amount in stock.")
	await _snapshot("03-bulk-cocoons")
	await _button(reel)
	_expect(state.silk_workshop.cocoons == 0 and state.silk_workshop.raw_silk == 12,
		"Reeling the lot uses every cocoon and the ordinary thread yield.")
	var weave: Button = panel.bulk_buttons[SilkWorkshop.Action.WEAVE]
	_expect(weave.text == "织完 3 匹", "The bulk weave shows the number of complete bolts.")
	await _snapshot("04-bulk-weave")
	var gamepad = load("res://tests/GamepadReplay.gd").new()
	gamepad.tree = tree
	gamepad.pad = tree.root.get_node("GamepadInput")
	tree.root.notify_mouse_exited()
	await gamepad._click(weave, true)
	_expect(gamepad.failures == 0, "A controller can weave the lot from the management page.")
	_expect(state.silk_workshop.bolts == 3 and state.silk_workshop.raw_silk == 0 and state.silk_workshop.cocoons == 0
		and state.money == 40 and state.king_storage == 3, "Produce the same three bolts with one switch and two bulk actions.")
	print("SILK_BATCH_REPEAT day=", state.current_day, " bolts=", state.silk_workshop.bolts, " leaves=", state.silk_workshop.leaves, " inputs=3")
	await _close_management()

func _wait_and_resume() -> void:
	var plan := await _plan()
	_expect("续养还差 2 片桑叶" in plan.silk_note.text, "One night's feed is insufficient to start a repeat batch.")
	await _snapshot("05-waiting-on-leaves")
	await _button(plan.close_button)
	await _overnight()
	_expect(state.current_day == 34 and state.silk_workshop.leaves == 2 and state.silk_workshop.nights_left == 0
		and state.silk_workshop.last_work_summary().is_empty(), "Waiting consumes no leaf and clears the last night's receipt.")
	await _click_crop(PUBLIC)
	_expect(state.king_storage == 4 and state.silk_workshop.leaves == 2, "The public millet goes to tribute.")
	await _click_crop(MULBERRY)
	_expect(state.player_inventory == 1 and state.silk_workshop.leaves == 6, "Harvest the private mulberry through the field controls.")
	await _overnight()
	_expect(state.current_day == 35 and state.silk_workshop.leaves == 4 and state.silk_workshop.nights_left == 1,
		"An ordinary private harvest supplies the next batch on the following night.")
	var panel := await _silk()
	await _button(panel.repeat_button)
	await _choose_reeling()
	await _button(panel.night_reeling_button)
	_expect(not state.silk_workshop.repeat_batches and state.silk_workshop.nights_left == 1,
		"Stopping future batches preserves the current silkworms.")
	await _close_management()
	plan = await _plan()
	_expect("用桑叶 2 片 · 结茧 2 只 · 缫 1 茧得 3 生丝" in plan.silk_note.text,
		"The funded retainer can reel a newly finished cocoon on the same night.")
	await _snapshot("06-combined-night-plan")
	await _button(plan.close_button)
	await _overnight()
	await _continue()
	_expect(state.current_day == 36 and state.silk_workshop.leaves == 2 and state.silk_workshop.cocoons == 1
		and state.silk_workshop.raw_silk == 3 and state.silk_workshop.last_hatched == 2 and state.silk_workshop.last_reeled == 1
		and not state.silk_workshop.repeat_batches and state.night_rations.last.served == 2,
		"The combined night and exact ration settlement survive the morning checkpoint.")
	plan = await _plan()
	_expect("昨夜蚕棚 · 用桑叶 2 片 · 结茧 2 只 · 缫 1 茧得 3 生丝" in plan.silk_receipt.text,
		"The sleep ledger reads the recorded result.")
	await _snapshot("07-overnight-receipt")
	await _button(plan.close_button)
	print("SILK_BATCH_RESUMED day=", state.current_day, " cocoons=", state.silk_workshop.cocoons,
		" thread=", state.silk_workshop.raw_silk, " fed=", state.night_rations.last.served)

func _sell_a_bolt() -> void:
	await _walk(world.player, [Vector2(-181, 54), Vector2(-181, 0), Vector2(-270, -21)])
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return
	var market := tree.current_scene as Node2D
	if not await _stall(market, "SilkStall", ""):
		return
	var copper: int = state.money
	await _button(market.counter.sell_silk)
	_expect(state.silk_workshop.bolts == 2 and state.money == copper + state.balance.silk_sell_price
		and state.silk_bolts_sold == 1, "The ordinary market sells one of the bulk-woven bolts.")
	await _snapshot("08-silk-stall-sale")
	print("SILK_BATCH_SALE day=", state.current_day, " bolts_left=", state.silk_workshop.bolts, " copper=", state.money - copper)

func _continue_old_batch() -> void:
	_expect(state.current_day == 28 and not state.silk_workshop.repeat_batches and state.silk_workshop.nights_left == 1
		and state.silk_workshop.leaves == 12, "Read a genuinely old batch halfway through its feed.")
	await _overnight()
	_expect(state.current_day == 29 and state.silk_workshop.nights_left == 0 and state.silk_workshop.leaves == 10
		and state.silk_workshop.cocoons == 2, "One ordinary night finishes the batch in the older save.")
	print("SILK_BATCH_OLD_SAVE day=", state.current_day, " leaves=", state.silk_workshop.leaves, " cocoons=", state.silk_workshop.cocoons)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_SILK_BATCH_CAPTURES")
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated profile."):
		tree.quit(1)
		return
	if not legacy:
		_fixture()
	await _continue()
	if legacy:
		await _continue_old_batch()
	else:
		await _first_three_batches()
		if not failed:
			await _wait_and_resume()
		if not failed:
			await _sell_a_bolt()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
