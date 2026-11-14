extends SceneTree

const Campaign := preload("res://tests/CampaignReplay.gd")

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

func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for frame in range(frames):
		await physics_frame
	Input.action_release(action)
	await Campaign.wait_for_map_change(self)

func _interact() -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	root.push_input(event, true)
	await process_frame

func _choose(dialog: Control, prefix: String) -> bool:
	for option in dialog.options_container.get_children():
		if option.text.begins_with(prefix) and not option.disabled:
			option.pressed.emit()
			await process_frame
			return true
	_expect(false, "Missing dialogue option: " + prefix)
	return false

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run raids-forage with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	seed(325)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	var state := root.get_node("Global")
	var world := current_scene.get_node("World")
	var ui := current_scene.get_node("UI")
	var tribute := Vector2i(5, 5)
	world.handle_interaction(tribute)
	for batch in range(2):
		world.handle_interaction(tribute)
		for night in range(2):
			world.handle_interaction(tribute)
			await _sleep(ui)
		world.handle_interaction(tribute)
	await _sleep(ui)
	await Campaign.walk_estate_road_to(self, world, world.active_visitors.front().global_position)
	await _interact()
	var dialog := ui.get_node_or_null("Control/DialoguePanel")
	_expect(dialog != null and dialog.name_label.text == "弋戎", "The military visitor is available in ordinary play before the first raid.")
	if dialog == null:
		quit(1)
		return
	dialog.options_container.get_child(2).pressed.emit()
	await process_frame
	_expect(state.retainers.size() == 2 and state.retainers.back().school == state.retainers.back().School.MILITARY,
		"Regular tribute pays for a military retainer.")
	while state.current_day < state.balance.raid_first_day - 1:
		await _sleep(ui)
	_expect(ui.hud.raid_alert.is_visible_in_tree() and "明日有敌袭" in ui.hud.raid_alert.text, "The raid is announced a day early.")
	var crop := Vector2i(6, 5)
	world.handle_interaction(crop)
	world.handle_interaction(crop)
	_expect(state.active_crops.has(crop), "A standing crop is at risk during the raid.")
	await _sleep(ui)
	_expect(state.raid_day == state.current_day and get_nodes_in_group("estate_raiders").size() == 1, "One raider enters the estate.")
	_expect(state.save_game() == OK and state.load_game() == OK, "A pending raid can be saved.")
	await scene_changed
	ui = current_scene.get_node("UI")
	_expect(get_nodes_in_group("estate_raiders").size() == 1, "Reloading restores the pending threat once.")
	ui.manage_button.pressed.emit()
	await process_frame
	var panel = ui.panel_manager.management_panel_instance
	var guard = panel.retainer_list_container.get_child(1)
	guard.duty_picker.item_selected.emit(3)
	panel.get_node("CloseButton").pressed.emit()
	await create_timer(2.2).timeout
	_expect(state.raid_day == 0 and state.raids_defeated == 1 and get_nodes_in_group("estate_raiders").is_empty(),
		"The assigned guard fires at the raider and clears the attack.")
	_expect(state.active_crops.has(crop) and state.last_defense.get("guard") == "弋戎" and state.last_defense.get("losses") == 0,
		"The actual guard shot preserves the crop and records the defender.")
	world = current_scene.get_node("World")
	var resident: Node2D = world.retainer_instances[state.retainers.back()]
	await Campaign.walk_to(self, world.player, resident.global_position)
	await _interact()
	dialog = ui.get_node_or_null("Control/DialoguePanel")
	_expect(dialog != null and dialog.name_label.text == "弋戎" and "作物全保住" in dialog.text_label.text,
		"The resident debrief names the result of the defense.")
	if dialog == null or not await _choose(dialog, "复盘守备"):
		quit(1)
		return
	var watch := world.get_node("Scenery/EastWatch") as Node2D
	_expect(watch.visible and state.east_watch_day == state.current_day, "Debriefing raises the watch board once.")
	await Campaign.walk_to(self, world.player, watch.global_position + Vector2(-12, 8))
	await _interact()
	dialog = ui.get_node_or_null("Control/DialoguePanel")
	_expect(dialog != null and dialog.name_label.text == "东岗守备牌" and "弋戎放了末一箭" in dialog.text_label.text,
		"The watch board records the actual guard's arrow.")
	if dialog == null or not await _choose(dialog, "合上"):
		quit(1)
		return
	_expect(state.save_game() == OK and state.load_game() == OK, "The watch board and its record can be saved.")
	await scene_changed
	_expect(current_scene.get_node("World/Scenery/EastWatch").visible and state.last_defense.get("guard") == "弋戎",
		"The watch board and defender survive a reload.")

	await _move(&"ui_up", 48)
	await _move(&"ui_right", 213)
	_expect(current_scene.name == "Wilderness", "The wild route can be entered after defending the estate.")
	if current_scene.name != "Wilderness":
		quit(1)
		return
	var fruit := current_scene.get_node("WildFruit") as Node2D
	await Campaign.walk_ravine_to(self, current_scene, fruit.global_position + Vector2(-7, 19))
	var food: int = state.food_storage
	await _interact()
	_expect(state.food_storage == food + state.balance.wild_food_yield and "采得野果" in current_scene.get_node("CampaignHUD").notice.text,
		"Wild berries are visible and supply food through E.")
	await _interact()
	_expect(state.food_storage == food + state.balance.wild_food_yield, "The same bush cannot be harvested twice in a day.")
	await Campaign.walk_to_ravine_exit(self, current_scene)
	await _move(&"ui_left", 26)
	_expect(current_scene.name == "Main" and state.raids_defeated == 1 and state.last_forage_day == state.current_day,
		"Returning preserves the defended estate and the forage limit.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
