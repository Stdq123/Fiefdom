extends RefCounted

const TITLE := "res://scenes/Title.tscn"
const ESTATE := "res://scenes/Main.tscn"
const PUBLIC := Vector2i(5, 5)
const PRIVATE := Vector2i(6, 5)

var tree: SceneTree
var state: Node
var pad: Node
var world: Node
var ui: Node
var capture_dir := ""
var failures := 0

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failures += 1
		push_error(detail)
	return condition

func _joy(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	_joy(event)

func _button(index: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	_joy(event)
	await tree.process_frame

func _tap(index: JoyButton) -> void:
	await _button(index, true)
	await _button(index, false)
	await tree.process_frame

func _aim(point: Vector2, left_stick := false) -> void:
	var x := JOY_AXIS_LEFT_X if left_stick else JOY_AXIS_RIGHT_X
	var y := JOY_AXIS_LEFT_Y if left_stick else JOY_AXIS_RIGHT_Y
	for frame in range(250):
		var offset: Vector2 = point - pad.cursor.position
		if offset.length() < 4.0:
			break
		var speed := clampf(offset.length() / 72.0, 0.06, 1.0)
		var stick := offset.normalized() * lerpf(pad.DEADZONE, 1.0, sqrt(speed))
		_axis(x, stick.x)
		_axis(y, stick.y)
		await tree.process_frame
	_axis(x, 0.0)
	_axis(y, 0.0)
	await tree.process_frame
	_expect(pad.cursor.position.distance_to(point) < 4.0, "A stick can point at %s from %s." % [point, pad.cursor.position])

func _click(button: Button, left_stick := false) -> void:
	if _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "The controller target button is available."):
		await _aim(button.get_global_rect().get_center(), left_stick)
		await _tap(JOY_BUTTON_A)

func _walk(axis: JoyAxis, strength: float, frames: int) -> void:
	_axis(axis, strength)
	for frame in range(frames):
		await tree.physics_frame
	_axis(axis, 0.0)
	await tree.process_frame

func _point(cell: Vector2i) -> Vector2:
	var tiles: TileMapLayer = world.tile_map
	return tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)

func _sweep() -> void:
	await _aim(_point(PUBLIC))
	await _button(JOY_BUTTON_A, true)
	await _aim(_point(PRIVATE))
	await _button(JOY_BUTTON_A, false)

func _sleep() -> void:
	var tomorrow: int = state.current_day + 1
	await _click(ui.sleep_button)
	for frame in range(240):
		if state.current_day == tomorrow and not world.player.resting:
			return
		await tree.process_frame
	_expect(false, "The visible sleep button advances the date and ends the dawn fade.")

func _scene_is(path: String) -> bool:
	for frame in range(120):
		if tree.current_scene and tree.current_scene.scene_file_path == path:
			await tree.process_frame
			return true
		await tree.process_frame
	return _expect(false, "The controller reaches " + path)

func _snapshot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(capture_dir.path_join(name + ".png")) == OK, "Save controller frame " + name)
	print("GAMEPAD_FRAME ", name, " window=", tree.root.size, " image=", frame.get_size())

func _estate_flow() -> bool:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	# As in farm-sweep, stop the field keeper from watering during the player's input replay.
	world.retainer_instances[state.retainers[0]].set_physics_process(false)
	_expect(pad.active and "按 A 翻地" in ui.hud.guide.text, "The opening instructions follow the selected input.")
	var start: Vector2 = world.player.position
	await _walk(JOY_AXIS_LEFT_Y, 0.12, 10)
	_expect(world.player.position == start, "Small stick drift leaves the player at rest.")
	await _walk(JOY_AXIS_LEFT_Y, 1.0, 22)
	_expect(world.player.position.y > start.y + 20.0, "The left stick moves the player at normal speed.")
	await _button(JOY_BUTTON_DPAD_RIGHT, true)
	for frame in range(21):
		await tree.physics_frame
	await _button(JOY_BUTTON_DPAD_RIGHT, false)
	_expect(world.player.position.x > start.x + 20.0, "The D-pad can walk alongside the field.")
	await _tap(JOY_BUTTON_X)
	_expect(world.player.conversation_open and ui.has_node("Control/DialoguePanel"), "X opens the nearby resident's dialogue.")
	await _tap(JOY_BUTTON_B)
	_expect(not world.player.conversation_open, "B closes the dialogue and restores movement.")

	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	_expect(world.current_seed_id == world.SEED_ORDER.back(), "LB wraps to the last seed.")
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(world.current_seed_id == "millet", "RB returns to the opening millet.")
	await _aim(_point(PUBLIC))
	var hint: Node2D = world.tile_map.get_node("FieldCursor")
	_expect(hint.visible and "公田" in hint.label.text, "The stick points to the same public plot as a mouse.")
	await _snapshot("01-field")
	await _sweep()
	_expect(state.tilled_cells.has(PUBLIC) and state.tilled_cells.has(PRIVATE) and state.current_stamina == 96,
		"Holding A tills both plots once and only charges each plot's cost.")
	await _sweep()
	_expect(state.active_crops.size() == 2 and state.current_stamina == 92, "A new sweep plants both plots without watering them.")
	await _sweep()
	_expect(state.current_stamina == 90, "Watering both newly sown plots costs two stamina.")
	await _sleep()
	await _sweep()
	await _sleep()
	await _sweep()
	_expect(state.current_day == 3 and state.king_storage == 1 and state.player_inventory == 1 and state.money == 5,
		"The first controller harvest sends public grain to tribute and private grain and proceeds to the player.")
	print("GAMEPAD_FARM day=", state.current_day, " public=", state.king_storage, " private=", state.player_inventory, " copper=", state.money)
	var campaign_hud := tree.current_scene.get_node("CampaignHUD")
	await _click(campaign_hud.backpack_button)
	_expect(tree.paused and campaign_hud.backpack != null and campaign_hud.backpack.items.has_node("millet"),
		"The controller opens the backpack and sees the freshly harvested millet.")
	await _tap(JOY_BUTTON_B)
	_expect(not tree.paused and campaign_hud.backpack == null, "B closes the backpack and returns to the estate.")

	await _tap(JOY_BUTTON_Y)
	_expect(tree.paused and ui.estate_map.modal.visible and ui.estate_map.close_button.text.ends_with("  B"),
		"Y opens the map with the controller return shortcut.")
	await _snapshot("02-map")
	await _tap(JOY_BUTTON_B)
	_expect(not tree.paused, "B leaves the map.")
	await _tap(JOY_BUTTON_BACK)
	_expect(tree.paused and ui.calendar.modal.visible, "View opens the almanac.")
	await _tap(JOY_BUTTON_B)
	await _click(ui.manage_button)
	_expect(world.player.menu_open, "A opens management.")
	var standing: Vector2 = world.player.position
	await _aim(_point(PUBLIC), true)
	await _tap(JOY_BUTTON_A)
	_expect(world.player.position == standing and state.current_stamina == 94,
		"The left stick navigates the menu and a click behind the panel cannot start field work.")
	await _tap(JOY_BUTTON_B)
	_expect(not world.player.menu_open, "B leaves management.")

	await _aim(_point(PUBLIC) + Vector2(60.0, 0.0))
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.85)
	await tree.process_frame
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.95)
	await tree.process_frame
	_expect(world.player.tool_gesture.visible and world.player.tool_gesture.frame == ToolGesture.Action.BOW,
		"RT fires an arrow in the direction of the pointer.")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await tree.process_frame
	var original_zoom: Vector2 = world.player.camera.zoom
	await _tap(JOY_BUTTON_LEFT_STICK)
	_expect(world.player.camera.zoom.x < original_zoom.x, "Clicking the left stick zooms out.")
	await _tap(JOY_BUTTON_RIGHT_STICK)
	_expect(world.player.camera.zoom == original_zoom, "Clicking the right stick restores the zoom.")
	await _irrigation()

	await _click(ui.settings_button)
	var settings: Panel = ui.panel_manager.settings_panel_instance
	_expect(settings.visible and not tree.current_scene.get_node("CampaignHUD").notice.visible,
		"Settings opens without a world notice covering its controls.")
	await _snapshot("03-settings")
	var title_button: Button
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "返回标题" and button.get_window() == tree.root:
			title_button = button
	await _click(title_button, true)
	var confirmation: ConfirmationDialog = settings.get_node("TitleConfirmation")
	if not _expect(confirmation.visible and confirmation.is_embedded(), "Returning to the title opens the embedded confirmation."):
		return false
	await _tap(JOY_BUTTON_B)
	_expect(not confirmation.visible and settings.visible, "B closes the confirmation without leaving settings.")
	await _click(title_button, true)
	await _confirm(confirmation, "04-return")
	return await _scene_is(TITLE)

func _irrigation() -> void:
	# Unlock construction here to test the input gesture after the normal opening harvest.
	state.tech_unlocked["irrigation"] = true
	tree.root.get_node("GameEvents").irrigation_unlocked.emit()
	await _click(ui.channel_button)
	_expect(world.channel_mode and "LT+A" in ui.help_label.text, "The canal controls show the gamepad fill gesture.")
	var channel := Vector2i(3, 5)
	await _aim(_point(channel))
	await _tap(JOY_BUTTON_A)
	_expect(state.money == 5 - state.channel_cost() and "已挖渠" in ui.help_label.text, "A pays to dig a canal segment.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.85)
	await tree.process_frame
	await _tap(JOY_BUTTON_A)
	_expect("水渠已填平" in ui.help_label.text, "Holding LT while pressing A fills the canal.")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await tree.process_frame
	await _tap(JOY_BUTTON_B)
	_expect(not world.channel_mode, "B leaves canal editing.")

func _confirm(window: ConfirmationDialog, frame_name: String) -> void:
	var ok := window.get_ok_button()
	await _aim(Vector2(window.position) + ok.get_global_rect().get_center(), true)
	await _snapshot(frame_name)
	await _tap(JOY_BUTTON_A)

func _second_campaign() -> bool:
	var title := tree.current_scene
	await _click(title.new_button, true)
	var confirmation: ConfirmationDialog = title.new_confirmation
	if not _expect(confirmation.visible and not title.new_name.text.is_empty(),
			"The second campaign proposes a name that can be accepted with the controller."):
		return false
	await _confirm(confirmation, "05-new-estate")
	return await _scene_is(ESTATE)

func _fishing() -> void:
	# Set up the fishing visit so the replay can exercise both edges of X without five opening nights.
	state.current_day = 5
	state.talk_to_visitor(VisitorData.RAVINE_GUIDE)
	tree.change_scene_to_file(state.WILDERNESS_SCENE)
	await tree.scene_changed
	var trail := tree.current_scene
	_expect(trail.get_node("CampaignHUD").camera_hint.text.begins_with("RT "), "The trail shows the controller's bow hint.")
	var pool: Node2D = trail.get_node("WillowPool")
	var angler: Player = trail.get_node("Player")
	angler.arrive_at_position(pool.global_position + Vector2(0, 12), Vector2.UP)
	await tree.process_frame
	await _tap(JOY_BUTTON_X)
	var panel := trail.get_node_or_null("FishingUI/FishingPanel")
	if not _expect(panel != null and tree.paused, "X casts a line at the willow pool."):
		return
	for frame in range(180):
		if panel.phase != panel.Phase.WAITING:
			break
		await tree.process_frame
	_expect(panel.phase == panel.Phase.BITE, "The bobber reaches its bite phase.")
	await _button(JOY_BUTTON_X, true)
	for frame in range(400):
		if panel.phase != panel.Phase.REELING:
			break
		if panel.holding and panel.tension >= 0.64:
			await _button(JOY_BUTTON_X, false)
		elif not panel.holding and panel.tension <= 0.43:
			await _button(JOY_BUTTON_X, true)
		await tree.process_frame
	await _button(JOY_BUTTON_X, false)
	_expect(panel.phase == panel.Phase.DONE and panel.catch_icon.visible, "Pressing and releasing X lands the fish.")
	await _snapshot("06-fishing")
	await _tap(JOY_BUTTON_B)
	_expect(not tree.paused and not trail.has_node("FishingUI/FishingPanel"), "B ends fishing and resumes the trail.")
	print("GAMEPAD_FISH caught=", state.last_fishing_day == state.current_day)

func _mouse_handoff() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(420, 270)
	motion.global_position = motion.position
	motion.relative = Vector2(2, 0)
	_joy(motion)
	await tree.process_frame
	_expect(not pad.active and not pad.cursor.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"Moving the mouse restores the system cursor.")

func run(host: SceneTree, capture := "") -> void:
	tree = host
	capture_dir = capture
	state = tree.root.get_node("Global")
	pad = tree.root.get_node("GamepadInput")
	seed(642)
	tree.change_scene_to_file(TITLE)
	await tree.scene_changed
	await _tap(JOY_BUTTON_A)
	if await _scene_is(ESTATE) and await _estate_flow() and await _second_campaign():
		await _fishing()
		await _mouse_handoff()
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(0 if failures == 0 else 1)
