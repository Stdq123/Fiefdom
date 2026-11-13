extends SceneTree

const LEFT := Vector2i(4, 5)
const CENTER := Vector2i(5, 5)
const RIGHT := Vector2i(6, 5)
const ROW := [LEFT, CENTER, RIGHT]

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

func _position(cell: Vector2i) -> Vector2:
	var tiles: TileMapLayer = world.tile_map
	return tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)

func _motion(cell: Vector2i, held := true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _position(cell)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event, true)
	await process_frame

func _button(cell: Vector2i, held: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = _position(cell)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = held
	root.push_input(event, true)
	await process_frame

func _sweep(first: Vector2i, last: Vector2i) -> void:
	await _motion(first, false)
	await _button(first, true)
	await _motion(last)
	await _button(last, false)

func _expect_row_feedback(action: int) -> void:
	var tool: Sprite2D = world.player.tool_gesture
	_expect(tool.visible and tool.frame == action, "The sweeping player shows the matching farm tool.")
	var marked: Array[Vector2] = []
	for node in world.get_children():
		if node is Sprite2D and node.texture == world.FIELD_IMPACTS and node.frame_coords.x == action:
			marked.append(node.position)
	_expect(marked.size() == ROW.size(), "Each successful tile gets one impact during a quick sweep.")
	for cell in ROW:
		_expect(world.get_crop_world_pos(cell) in marked, "The impact stays on its own farm tile.")

func _sleep() -> void:
	var tomorrow: int = state.current_day + 1
	var saw_dawn := false
	ui.sleep_button.pressed.emit()
	for frame in range(240):
		await process_frame
		if ui.dawn_caption.visible:
			saw_dawn = ui.dawn_caption.text.begins_with("第 %d 天" % tomorrow) and state.get_current_solar_term() in ui.dawn_caption.text
		if state.current_day == tomorrow and ui.fader.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			_expect(saw_dawn and not ui.dawn_caption.visible, "The dawn caption shows the solar term and clears before farming.")
			return
	_expect(false, "The day must advance before the next set of actions.")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run farm-sweep with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	state = root.get_node("Global")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	await process_frame
	world = current_scene.get_node("World")
	ui = current_scene.get_node("UI")
	# Keep the input test deterministic by isolating the player's watering from the starter retainer's.
	world.retainer_instances[state.retainers[0]].set_physics_process(false)

	await _sweep(LEFT, RIGHT)
	_expect_row_feedback(ToolGesture.Action.TILL)
	_expect(state.current_stamina == 94 and state.tilled_cells.size() == 3 and state.active_crops.is_empty(),
		"A fast jump across the row tills each crossed tile once without changing action.")
	await _motion(LEFT, false)
	await _button(LEFT, true)
	await _motion(RIGHT)
	await _motion(LEFT)
	await _button(LEFT, false)
	_expect_row_feedback(ToolGesture.Action.SOW)
	_expect(state.current_stamina == 88 and state.active_crops.size() == 3 and "待浇 3" in ui.hud.farm_status.text,
		"Sowing and passing back across the same tiles cannot water them.")
	for cell in ROW:
		_expect(not state.active_crops[cell]["watered"], "Every newly planted crop should still be dry.")
	await _sweep(CENTER, CENTER)
	await _sweep(LEFT, RIGHT)
	_expect_row_feedback(ToolGesture.Action.WATER)
	_expect(state.current_stamina == 85 and "待浇 0" in ui.hud.farm_status.tooltip_text,
		"A watering sweep skips the already-watered center without charging again.")
	await _sleep()
	await _sweep(LEFT, RIGHT)
	_expect("今夜成熟 3" in ui.hud.farm_status.tooltip_text, "Tonight's forecast uses the three actual watered crops.")
	await _sleep()
	_expect("可收 3" in ui.hud.farm_status.text, "The morning marks all three crops as ripe.")
	await _motion(LEFT, false)
	await _button(LEFT, true)
	await _motion(RIGHT)
	_expect_row_feedback(ToolGesture.Action.HARVEST)
	_expect(state.king_storage == 1 and state.player_inventory == 2 and state.money == 10,
		"One harvest sweep still sends the center crop to tribute and the others to the household.")
	_expect(is_instance_valid(world.sweep_popup) and "收获 3 格" in world.sweep_popup.text and "国库 +1" in world.sweep_popup.text,
		"The harvest sweep reports the combined results in one popup.")
	await _motion(LEFT)
	await _button(LEFT, false)
	_expect(state.active_crops.is_empty() and state.current_stamina == 91, "A harvest sweep does not plant again on cleared tiles.")

	var upper_left := LEFT + Vector2i.UP
	var upper_right := RIGHT + Vector2i.UP
	state.current_stamina = 3
	await _motion(upper_left, false)
	await _button(upper_left, true)
	await _motion(upper_right)
	_expect(state.tilled_cells.has(upper_left) and not state.tilled_cells.has(upper_right) and state.current_stamina == 1,
		"Running out of stamina leaves the next cells unchanged.")
	state.current_stamina = 100
	await _motion(CENTER + Vector2i.UP)
	_expect(not state.tilled_cells.has(CENTER + Vector2i.UP), "A stopped sweep cannot resume without a new press.")
	await _button(CENTER + Vector2i.UP, false)
	await _motion(LEFT, false)
	await _button(LEFT, true)
	world.select_seed("beans")
	await _motion(RIGHT)
	await _button(RIGHT, false)
	_expect(state.active_crops.size() == 1 and state.active_crops[LEFT]["id"] == "millet",
		"Changing seed during a sweep ends the gesture before another seed is planted.")

	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
