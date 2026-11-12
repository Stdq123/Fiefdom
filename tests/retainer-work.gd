extends SceneTree

const FIRST := Vector2i(6, 6)
const SECOND := Vector2i(4, 6)

var failed := false
var state: Node
var world: Node
var worker: Node

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error(detail)

func _click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame

func _click_field(cell: Vector2i) -> void:
	var tile_map: TileMapLayer = world.tile_map
	await _click(tile_map.get_global_transform_with_canvas() * tile_map.map_to_local(cell))

func _water_marks(cell: Vector2i) -> int:
	var count := 0
	for node in world.get_children():
		if (node is Sprite2D and node.texture == world.FIELD_IMPACTS
				and node.frame_coords.x == ToolGesture.Action.WATER and node.position == world.get_crop_world_pos(cell)):
			count += 1
	return count

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run retainer-work with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	state = root.get_node("Global")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	await process_frame
	var new_button: Button = current_scene.new_button
	await _click(new_button.get_global_rect().get_center())
	if current_scene == null or current_scene.name != "Main":
		await scene_changed
	world = current_scene.get_node("World")
	worker = world.retainer_instances[state.retainers.front()]
	await _click_field(FIRST)
	await _click_field(FIRST)

	var saw_carry := false
	var saw_pour := false
	var initial_stamina: int = state.current_stamina
	for step in range(300):
		if worker.target_grid_pos == FIRST and worker.tool_gesture.visible:
			saw_carry = saw_carry or worker.tool_gesture.carrying
			saw_pour = saw_pour or (worker.current_state == worker.State.WORK and not worker.tool_gesture.carrying)
		if state.active_crops[FIRST]["watered"]:
			break
		await physics_frame
	_expect(saw_carry and saw_pour, "The starter retainer visibly carries and tips a pail during real work.")
	_expect(state.active_crops[FIRST]["watered"] and _water_marks(FIRST) == 1 and state.current_stamina == initial_stamina,
		"The retainer's completed work wets the selected tile and marks it once without costing player stamina.")
	await create_timer(0.36).timeout
	await _click_field(FIRST)
	_expect(_water_marks(FIRST) == 0 and not world.player.tool_gesture.visible and state.current_stamina == initial_stamina,
		"Clicking already wet soil produces neither a new gesture nor another splash.")

	await _click_field(SECOND)
	await _click_field(SECOND)
	for step in range(270):
		if worker.current_state == worker.State.WORK and worker.target_grid_pos == SECOND:
			break
		await physics_frame
	_expect(worker.current_state == worker.State.WORK and worker.target_grid_pos == SECOND,
		"The helper approaches the next dry plot through his normal assignment.")
	await _click_field(SECOND)
	_expect(state.active_crops[SECOND]["watered"] and _water_marks(SECOND) == 1
		and world.player.tool_gesture.frame == ToolGesture.Action.WATER,
		"Manual watering can finish the same plot while the helper is preparing.")
	await create_timer(maxf(0.36, worker.work_left + 0.04)).timeout
	_expect(_water_marks(SECOND) == 0 and not worker.tool_gesture.visible, "The delayed helper makes no duplicate impact.")
	_expect(state.save_game() == OK and state.load_game() == OK, "The resulting moisture survives the normal save path.")
	await scene_changed
	world = current_scene.get_node("World")
	worker = world.retainer_instances[state.retainers.front()]
	_expect(state.active_crops[FIRST]["watered"] and state.active_crops[SECOND]["watered"]
		and not worker.tool_gesture.visible and _water_marks(SECOND) == 0, "Load restores moisture and leaves transient gestures behind.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
