extends SceneTree

const Campaign := preload("res://tests/CampaignReplay.gd")

var state: Node
var world: Node
var ui: Node
var walker: Node2D
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		push_error(message)
	return ok

func _key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.pressed = pressed
	event.keycode = code
	event.physical_keycode = code
	root.push_input(event, true)

func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for index in frames:
		await physics_frame
	Input.action_release(action)
	await Campaign.wait_for_map_change(self)

func _estate() -> void:
	world = current_scene.get_node("World")
	ui = current_scene.get_node("UI")
	walker = world.player

func _enter_trail() -> bool:
	await Campaign.walk_to(self, walker, Vector2(359, 4))
	await _move(&"ui_right", 36)
	if not _expect(current_scene.name == "Wilderness", "The East Gate leads to the fishing trail."):
		return false
	walker = current_scene.get_node("Player")
	# Keep the native trail enemies in place while testing the fishing rules and routes.
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	return true

func _return_home(east_bank := false) -> bool:
	if east_bank:
		await Campaign.walk_to(self, walker, Vector2(243, 119))
		await Campaign.walk_to(self, walker, Vector2(115, 119))
	await Campaign.walk_to(self, walker, Vector2(-160, 3))
	await _move(&"ui_left", 26)
	if not _expect(current_scene.name == "Main", "The trail exit returns fish and player to the estate."):
		return false
	_estate()
	return true

func _night() -> void:
	ui.sleep_button.pressed.emit()
	await create_timer(1.12).timeout

func _open_fishing(spot: Node2D) -> Control:
	await Campaign.walk_to(self, walker, spot.global_position + Vector2(0, 12))
	_key(KEY_E)
	await process_frame
	return current_scene.get_node_or_null("FishingUI/FishingPanel") as Control

func _close_fishing() -> void:
	_key(KEY_ESCAPE)
	await process_frame
	_expect(not paused and not current_scene.get_node("FishingUI").has_node("FishingPanel"), "Putting the rod away resumes the trail.")

func _hold(panel: Control, mouse: bool, pressed: bool) -> void:
	if not mouse:
		_key(KEY_SPACE, pressed)
		return
	var point: Vector2 = panel.pull_button.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func _wait_for_bite(panel: Control) -> void:
	while panel.phase == panel.Phase.WAITING:
		await process_frame
	_expect(panel.phase == panel.Phase.BITE and panel.spot.submerged, "A visible, submerged float marks the actual bite.")

func _catch(spot: Node2D, id: String, mouse := false) -> bool:
	var cost: int = state.balance.fishing_stamina_cost
	var before: int = state.current_stamina
	var held: int = state.fish_count(id)
	var panel := await _open_fishing(spot)
	if not _expect(panel != null and paused and state.current_stamina == before - cost, "Casting costs stamina and holds the view at the bank."):
		return false
	await _wait_for_bite(panel)
	_hold(panel, mouse, true)
	for frame in range(400):
		if panel.phase != panel.Phase.REELING:
			break
		if panel.holding and panel.tension >= 0.64:
			_hold(panel, mouse, false)
		elif not panel.holding and panel.tension <= 0.43:
			_hold(panel, mouse, true)
		await process_frame
	_hold(panel, mouse, false)
	var caught := _expect(panel.phase == panel.Phase.DONE and panel.catch_icon.visible
		and state.fish_count(id) == held + 1 and state.last_forage_day == state.current_day,
		"The expected fish is landed once when tension stays in the safe band.")
	await _close_fishing()
	_expect(not spot.line_visible, "The float and line disappear on close.")
	return caught

func _fish_ledger() -> Control:
	ui.manage_button.pressed.emit()
	await process_frame
	var management: Control = ui.panel_manager.management_panel_instance
	management.tabs.current_tab = 1
	await process_frame
	_expect(management.market_panel.fish_book_button.is_visible_in_tree(), "The market shows the fish ledger after the introduction.")
	management.market_panel.fish_book_button.pressed.emit()
	await process_frame
	_expect(management.fish_ledger.is_visible_in_tree(), "The market button opens the fish ledger.")
	return management.fish_ledger

func _close_ledger() -> void:
	ui.panel_manager.management_panel_instance.get_node("CloseButton").pressed.emit()
	await process_frame

func _save_reload() -> bool:
	if not _expect(state.save_game() == OK and state.load_game() == OK, "The fish inventory and notes save and reload."):
		return false
	await scene_changed
	_estate()
	return true

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run creek-fishing in an isolated smoke profile.")
		quit(1)
		return
	seed(642)
	state = root.get_node("Global")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	_estate()
	if not await _enter_trail():
		quit(1)
		return
	var pool := current_scene.get_node("WillowPool") as Node2D
	_expect(await _open_fishing(pool) == null and state.current_stamina == state.max_stamina,
		"The first visit points to Pu Ning without spending stamina.")
	if not await _return_home():
		quit(1)
		return
	while state.current_day < 5:
		await _night()
	var guest: Node2D = world.active_visitors.front()
	await Campaign.walk_to(self, walker, Vector2(116, 42))
	await Campaign.walk_to(self, walker, guest.global_position + Vector2(0, 18))
	_key(KEY_E)
	await process_frame
	var dialogue := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialogue != null and dialogue.name_label.text == "蒲宁", "Talk to Pu Ning at the bamboo path on day five."):
		quit(1)
		return
	dialogue.options_container.get_child(0).pressed.emit()
	await process_frame
	if not await _enter_trail():
		quit(1)
		return
	pool = current_scene.get_node("WillowPool")
	var panel := await _open_fishing(pool)
	if not _expect(panel != null and paused, "The introduction lets the player cast from Willow Pool."):
		quit(1)
		return
	await _close_fishing()
	_expect(state.fish_collection.is_empty() and state.last_forage_day == 0 and not pool.line_visible, "Cancelling does not claim a catch.")
	panel = await _open_fishing(pool)
	_key(KEY_SPACE)
	await process_frame
	_key(KEY_SPACE, false)
	_expect(panel.phase == panel.Phase.DONE and "太早" in panel.status.text and state.last_forage_day == 0,
		"Early pulling costs the attempt but leaves the day's outing available.")
	await _close_fishing()
	panel = await _open_fishing(pool)
	await _wait_for_bite(panel)
	_key(KEY_SPACE)
	while panel.phase != panel.Phase.DONE:
		await process_frame
	_key(KEY_SPACE, false)
	_expect("太紧" in panel.status.text and state.last_forage_day == 0, "Holding continuously makes a fish escape.")
	await _close_fishing()
	if not await _catch(pool, "crucian"):
		quit(1)
		return
	var before: int = state.current_stamina
	_expect(await _open_fishing(pool) == null and state.current_stamina == before, "A second catch on the same day is blocked before charging stamina.")
	var food: int = state.food_storage
	await Campaign.walk_to(self, walker, Vector2(-52, -73))
	_key(KEY_E)
	await process_frame
	_expect(state.food_storage == food, "A catch shares the berry and herb gathering opportunity.")
	if not await _return_home() or not await _save_reload():
		quit(1)
		return
	var ledger := await _fish_ledger()
	_expect(state.fish_count("crucian") == 1 and "第 5 天" in ledger.rows.crucian.history.text, "Fish stock and first-catch notes survive saving.")
	ledger.rows.crucian.food.pressed.emit()
	_expect(state.fish_count("crucian") == 0 and state.food_storage == food + 4 and "柳湾" in ledger.rows.crucian.history.text,
		"Converting fish supplies food without losing the record.")
	await _close_ledger()
	await _night()
	if not await _enter_trail():
		quit(1)
		return
	pool = current_scene.get_node("WillowPool")
	_expect(state.has_rain(), "The next outing falls on Grain Rain.")
	if not await _catch(pool, "carp", true) or not await _return_home():
		quit(1)
		return
	ledger = await _fish_ledger()
	var copper: int = state.money
	ledger.rows.carp.sell.pressed.emit()
	_expect(state.money == copper + 12 and state.fish_count("carp") == 0 and ledger.rows.carp.sell.disabled,
		"Selling one fish pays the displayed coins and removes its stock.")
	await _close_ledger()
	await _night()
	if not await _enter_trail():
		quit(1)
		return
	pool = current_scene.get_node("WillowPool")
	if not await _catch(pool, "minnow") or not await _return_home():
		quit(1)
		return
	# Set the autumn date to verify the other shore without adding six days of farm actions to this scenario.
	state.current_day = 13
	if not await _save_reload() or not await _enter_trail():
		quit(1)
		return
	await Campaign.walk_to(self, walker, Vector2(109, 36))
	await Campaign.walk_to(self, walker, Vector2(243, 36))
	var shoal := current_scene.get_node("GravelShoal") as Node2D
	if not await _catch(shoal, "perch") or not await _return_home(true) or not await _save_reload():
		quit(1)
		return
	ledger = await _fish_ledger()
	_expect("4/4" in ledger.summary.text and "砾滩" in ledger.rows.perch.history.text and state.fish_count("minnow") == 1,
		"All four records, including stock that was sold or eaten, remain in the ledger.")
	print("FISH_RECORDS ", state.fish_collection)
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
