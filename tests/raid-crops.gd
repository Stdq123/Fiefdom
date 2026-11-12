extends SceneTree

const Campaign := preload("res://tests/CampaignReplay.gd")
const CELLS := [Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5)]

var failed := false
var state: Node
var world: Node
var ui: Node

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error(detail)

func _estate() -> void:
	world = current_scene.get_node("World")
	ui = current_scene.get_node("UI")

func _sleep() -> void:
	var tomorrow: int = state.current_day + 1
	ui.sleep_button.pressed.emit()
	for frame in range(240):
		await process_frame
		if state.current_day == tomorrow and ui.fader.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return
	_expect(false, "The day must advance and the screen must fade back in.")

func _click(at: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = button
	event.position = world.get_canvas_transform() * at
	event.global_position = event.position
	root.push_input(event, true)
	await process_frame

func _interact() -> Control:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	root.push_input(event, true)
	await process_frame
	return ui.get_node_or_null("Control/DialoguePanel")

func _wait_for_crop_cue(enemy: Node) -> bool:
	for frame in range(300):
		if enemy.pending_attack == enemy.Attack.CROP:
			return true
		await physics_frame
	_expect(false, "The raider must mark a planted crop before attacking it.")
	return false

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run raid-crops with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	seed(405)
	state = root.get_node("Global")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	_estate()
	state.balance.raid_first_day = 3
	state.balance.raid_interval_days = 4
	for cell in CELLS:
		await _click(world.get_crop_world_pos(cell), MOUSE_BUTTON_LEFT)
		await _click(world.get_crop_world_pos(cell), MOUSE_BUTTON_LEFT)
	for night in range(2):
		for cell in CELLS:
			await _click(world.get_crop_world_pos(cell), MOUSE_BUTTON_LEFT)
		if night == 1:
			await Campaign.walk_to(self, world.player, Vector2(-83, 98))
		await _sleep()

	var enemy := get_first_node_in_group("estate_raiders") as Node2D
	_expect(enemy != null and state.raid_day == 3, "The early test raid must enter on day three.")
	if enemy == null or not await _wait_for_crop_cue(enemy):
		quit(1)
		return
	var saved_by_harvest: Vector2i = enemy.target_crop_pos
	await create_timer(0.4).timeout
	_expect(state.active_crops.has(saved_by_harvest) and state.raid_crop_losses == 0, "The marked crop remains intact during windup.")
	await _click(world.get_crop_world_pos(saved_by_harvest), MOUSE_BUTTON_LEFT)
	_expect(not state.active_crops.has(saved_by_harvest) and state.raid_crop_losses == 0, "Harvesting the threatened tile counts as a normal harvest.")
	await create_timer(state.balance.raid_crop_windup).timeout
	_expect(state.raid_crop_losses == 0, "A strike on the harvested plot cannot add a loss.")

	if not await _wait_for_crop_cue(enemy):
		quit(1)
		return
	var lost: Vector2i = enemy.target_crop_pos
	_expect(state.active_crops.has(lost), "The second cue names a different standing crop.")
	await create_timer(state.balance.raid_crop_windup + 0.10).timeout
	_expect(state.raid_crop_losses == 1 and not state.active_crops.has(lost) and state.active_crops.size() == 1,
		"Letting the windup finish destroys exactly the marked crop.")
	_expect(state.save_game() == OK and state.load_game() == OK, "An ongoing raid and its loss count can be saved.")
	await scene_changed
	await process_frame
	_estate()
	_expect(state.raid_crop_losses == 1 and state.active_crops.size() == 1, "The loss and remaining crop survive the reload.")
	enemy = get_first_node_in_group("estate_raiders") as Node2D
	if enemy == null:
		_expect(false, "Reload restores the pending raider.")
		quit(1)
		return
	await _click(enemy.global_position + Vector2(-10, 0), MOUSE_BUTTON_RIGHT)
	for frame in range(100):
		if state.raid_day == 0:
			break
		await physics_frame
	_expect(state.raids_defeated == 1 and state.last_defense.get("day") == 3 and state.last_defense.get("losses") == 1
		and state.last_defense.get("guard") == "", "The real player shot records one crop lost and no guard finishing the raid.")
	_expect(state.active_crops.size() == 1, "The player saves the remaining crop.")

	while state.current_day < 6:
		await _sleep()
	_expect("复盘守备" in ui.hud.visitor_label.text and "手记" not in ui.hud.visitor_label.text,
		"The estate points to the debrief without advertising an unopened journal.")
	var visitor: Node2D = world.active_visitors.front()
	await Campaign.walk_to(self, world.player, visitor.global_position)
	var dialog := await _interact()
	_expect(dialog != null and dialog.name_label.text == "弋戎" and "损失 1 格作物" in dialog.text_label.text,
		"A visiting archer can discuss the solo defense and its actual losses.")
	if dialog == null:
		quit(1)
		return
	for option in dialog.options_container.get_children():
		if option.text == "复盘守备":
			option.pressed.emit()
			await process_frame
			break
	var watch := world.get_node("Scenery/EastWatch") as Node2D
	var alert: Button = ui.hud.raid_alert
	_expect(watch.visible and alert.is_visible_in_tree() and "明日有敌袭" in alert.text and "斥候" in alert.text,
		"The watch identifies tomorrow's next raider as soon as it is built.")
	await _sleep()
	_expect(watch.visible and "警旗" in watch.hint.text and not watch.is_in_group("interactable"),
		"The board raises a warning during a live raid.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
