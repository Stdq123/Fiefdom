extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		push_error(detail)
		failed = true

func _sleep(ui: Node) -> void:
	ui.sleep_button.pressed.emit()
	await create_timer(1.1).timeout

func _open_management(ui: Node) -> Control:
	ui.manage_button.pressed.emit()
	await process_frame
	return ui.panel_manager.management_panel_instance

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run silk-chain with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	seed(122)
	change_scene_to_file("res://scenes/Main.tscn")
	await scene_changed
	var state := root.get_node("Global")
	var world := current_scene.get_node("World")
	var ui := current_scene.get_node("UI")
	var crop_cells := [Vector2i(4, 5), Vector2i(6, 5), Vector2i(5, 5)]
	world.current_seed_id = "mulberry"
	for cell in crop_cells:
		world.handle_interaction(cell)
		world.handle_interaction(cell)
	for night in range(state.active_crops[crop_cells[0]]["growth_nights"]):
		for cell in crop_cells:
			world.handle_interaction(cell)
		await _sleep(ui)
	for cell in crop_cells:
		world.handle_interaction(cell)
	_expect(state.king_storage == 1 and state.money == 30 and state.silk_workshop.leaves == 8, "Private mulberry harvests supply leaves and public harvests enter the treasury.")

	var management := await _open_management(ui)
	var tabs := management.get_node("HBoxContainer/RightPanel") as TabContainer
	var workshop_panel := tabs.get_node("蚕桑")
	var action = state.silk_workshop.Action
	tabs.current_tab = 4
	_expect(workshop_panel.buttons[action.BUILD].disabled, "Literacy gates the workshop even with enough copper.")
	tabs.current_tab = 2
	var read := tabs.get_node("君子六艺/Actions/ReadButton") as Button
	read.pressed.emit()
	var literacy_art: int = state.player_stats.Art.LITERACY
	read.pressed.emit()
	_expect(read.disabled and state.player_stats.get_stat(literacy_art).xp == 50, "A second press cannot award literacy on the same day.")
	_expect(state.save_game() == OK and state.load_game() == OK, "The study session saves.")
	await scene_changed
	world = current_scene.get_node("World")
	ui = current_scene.get_node("UI")
	management = await _open_management(ui)
	_expect(management.read_button.disabled, "Reloading on the same day preserves the study limit.")
	management.get_node("CloseButton").pressed.emit()
	await _sleep(ui)
	management = await _open_management(ui)
	tabs = management.get_node("HBoxContainer/RightPanel")
	workshop_panel = tabs.get_node("蚕桑")
	tabs.current_tab = 2
	_expect(not management.read_button.disabled, "A new day opens another study session.")
	management.read_button.pressed.emit()
	tabs.current_tab = 4
	_expect(not workshop_panel.buttons[action.BUILD].disabled, "Reading unlocks the workshop button.")
	workshop_panel.buttons[action.BUILD].pressed.emit()
	_expect(state.silk_workshop.built and state.money == 5, "Building charges the configured price once.")
	_expect(workshop_panel.buttons[action.WEAVE].disabled, "Weaving is unavailable without thread.")
	state.balance.silk_leaves_per_night = 5
	workshop_panel.buttons[action.START_BATCH].pressed.emit()
	management.get_node("CloseButton").pressed.emit()
	await _sleep(ui)
	_expect(state.silk_workshop.leaves == 3 and state.silk_workshop.nights_left == 1, "The batch consumes the configured feed.")
	_expect(state.save_game() == OK and state.load_game() == OK, "An active batch survives saving and loading.")
	await scene_changed
	world = current_scene.get_node("World")
	ui = current_scene.get_node("UI")
	await _sleep(ui)
	_expect(state.silk_workshop.nights_left == 1 and state.silk_workshop.leaves == 3, "A batch pauses when feed runs out.")
	var mulberry: Vector2i = crop_cells[0]
	for night in range(4):
		if world.field_action(mulberry) == world.FieldAction.HARVEST:
			break
		world.handle_interaction(mulberry)
		await _sleep(ui)
	world.handle_interaction(mulberry)
	await _sleep(ui)
	_expect(state.silk_workshop.leaves == 2 and state.silk_workshop.cocoons == 2, "A second leaf harvest resumes the batch and produces cocoons.")

	management = await _open_management(ui)
	tabs = management.get_node("HBoxContainer/RightPanel")
	tabs.current_tab = 4
	workshop_panel = tabs.get_node("蚕桑")
	workshop_panel.buttons[action.REEL].pressed.emit()
	_expect(state.silk_workshop.raw_silk == 2 and workshop_panel.buttons[action.WEAVE].disabled, "The first cocoon makes thread and weaving waits for enough.")
	workshop_panel.buttons[action.REEL].pressed.emit()
	workshop_panel.buttons[action.WEAVE].pressed.emit()
	_expect(state.silk_workshop.bolts == 1 and state.silk_workshop.raw_silk == 0, "Weaving consumes thread and makes silk.")
	var money_before: int = state.money
	state.balance.silk_sell_price = 43
	workshop_panel.buttons[action.SELL].pressed.emit()
	_expect(state.money == money_before + 43 and state.silk_workshop.bolts == 0, "Selling a bolt pays the configured price.")

	state.balance.silk_leaves_per_night = 1
	workshop_panel.buttons[action.START_BATCH].pressed.emit()
	management.get_node("CloseButton").pressed.emit()
	for night in range(2):
		await _sleep(ui)
	management = await _open_management(ui)
	workshop_panel.buttons[action.REEL].pressed.emit()
	workshop_panel.buttons[action.REEL].pressed.emit()
	workshop_panel.buttons[action.WEAVE].pressed.emit()
	var reputation_before: int = state.reputation
	workshop_panel.buttons[action.OFFER].pressed.emit()
	_expect(state.reputation == reputation_before + 30 and state.silk_workshop.bolts == 0, "Offering silk consumes one bolt and earns reputation.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
