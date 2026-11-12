extends SceneTree

const Campaign := preload("res://tests/CampaignReplay.gd")

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _mouse(button: MouseButton, point: Vector2, pressed := true) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)

func _click_cell(tile_map: TileMapLayer, cell: Vector2i) -> void:
	var point := tile_map.get_global_transform_with_canvas() * tile_map.map_to_local(cell)
	_mouse(MOUSE_BUTTON_LEFT, point)
	_mouse(MOUSE_BUTTON_LEFT, point, false)

func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for frame in range(frames):
		await physics_frame
	Input.action_release(action)
	await Campaign.wait_for_map_change(self)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run camera-view with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.notify_mouse_entered()
	change_scene_to_file("res://scenes/Title.tscn")
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	var state := root.get_node("Global")
	var ui := current_scene.get_node("UI")
	ui.panel_manager.hide_debug_panel()
	var camera := current_scene.get_node("World/Player/Camera2D") as Camera2D
	var tile_map := current_scene.get_node("World/TileMapLayer") as TileMapLayer
	var point := Vector2(640, 360)
	var cell := Vector2i(6, 5)
	_expect(camera.zoom == Vector2(2, 2), "The default scale is the standard view.")
	for attempt in range(3):
		_mouse(MOUSE_BUTTON_WHEEL_DOWN, point)
	_expect(camera.zoom == Vector2(1.5, 1.5), "Repeated zooming out stops at the overview.")
	_click_cell(tile_map, cell)
	_expect(state.tilled_cells.has(cell), "The overview maps clicks to the same soil tile.")

	ui.manage_button.pressed.emit()
	await process_frame
	_mouse(MOUSE_BUTTON_WHEEL_UP, point)
	_expect(camera.zoom == Vector2(1.5, 1.5), "Scrolling over the management panel leaves the map scale unchanged.")
	ui.panel_manager.management_panel_instance.get_node("CloseButton").pressed.emit()
	await process_frame
	for attempt in range(3):
		_mouse(MOUSE_BUTTON_WHEEL_UP, point)
	_expect(camera.zoom == Vector2(3, 3), "Repeated zooming in stops at the close view.")
	_click_cell(tile_map, cell)
	_expect(state.active_crops.has(cell), "The close view plants on the tilled tile after the camera changes scale.")

	await _move(&"ui_up", 48)
	await _move(&"ui_right", 213)
	if current_scene.name != "Wilderness":
		push_error("The estate entrance must remain usable after zooming.")
		quit(1)
		return
	camera = current_scene.get_node("Player/Camera2D") as Camera2D
	_expect(camera.zoom == Vector2(3, 3), "The view follows the player into the wilderness.")
	_mouse(MOUSE_BUTTON_WHEEL_DOWN, point)
	_expect(camera.zoom == Vector2(2, 2), "The wilderness also accepts map scroll input.")
	await _move(&"ui_left", 37)
	if current_scene.name != "Main":
		push_error("The wilderness exit must remain usable after zooming.")
		quit(1)
		return
	camera = current_scene.get_node("World/Player/Camera2D") as Camera2D
	_expect(camera.zoom == Vector2(2, 2), "The view follows the player back to the estate.")
	var arrival := current_scene.get_node("World/Player") as Node2D
	_expect(arrival.position.x > 310 and arrival.position.x < 381, "A return lands inside the eastern gate.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
