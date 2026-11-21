extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var world := current_scene.get_node("World") as Node2D
	var worker: Node2D = world.retainer_instances[state.retainers.front()]
	var field: Vector2i = state.well_fields[0].center_pos
	var plot: Vector2 = world.to_global(world.get_crop_world_pos(field))
	var before := [state.current_day, state.day_progress, state.money, state.food_storage,
		state.current_stamina, hash(state.tilled_cells), hash(state.active_crops)]
	for facing: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(0.8, -0.6)]:
		for job: int in [state.FieldJob.TILL, state.FieldJob.SOW, state.FieldJob.WATER, state.FieldJob.HARVEST]:
			_check_stroke(worker, field, plot, facing, job)
	_check_exact_center(worker, field, plot, state.FieldJob.WATER)
	worker.tool_gesture.clear()
	worker.tool_gesture.carry_field_tool(ToolGesture.Action.TILL, Vector2.RIGHT, 0.0)
	worker.target_grid_pos = worker.NO_CELL
	worker._show_approach(Vector2.RIGHT, plot)
	_expect(not worker.tool_gesture.visible, "Leaving a field route clears the carried tool.")
	_expect(paused and before == [state.current_day, state.day_progress, state.money, state.food_storage,
		state.current_stamina, hash(state.tilled_cells), hash(state.active_crops)] and state.saved_games().is_empty(),
		"Fixed presentation samples leave the current campaign record intact.")
	current_scene.queue_free()
	await process_frame
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_stroke(worker: Node2D, field: Vector2i, plot: Vector2, facing: Vector2, job: int) -> void:
	worker.target_grid_pos = field
	worker.field_job = job
	worker.global_position = plot - facing * 3.0
	worker.art.position = Vector2.ZERO
	worker._stance = Vector2.INF
	worker.last_heading = Vector2(-facing.y, facing.x)
	var body := worker.global_position
	var tool: ToolGesture = worker.tool_gesture
	tool.clear()
	tool.carry_field_tool(worker.WORK_GESTURES[job], facing, -1.0, 0.65)
	var carried := tool.transform
	var flipped := tool.flip_h
	worker.set_state(worker.State.WORK)
	var duration: float = worker.work_left
	if flipped != tool.flip_h:
		carried = Transform2D(-carried.get_rotation(), carried.origin * Vector2(-1.0, 1.0))
	_expect(tool.visible and not tool.carrying and tool.transform.is_equal_approx(carried),
		"Windup starts from the carried grip, including when the stance changes side.")
	_expect(is_equal_approx(duration, 1.0 / maxf(worker.data.get_work_efficiency(), 0.1)), "Keep the assigned work duration.")
	_expect(not worker._advance_field_pose(duration * 0.50), "Windup ends before the contact tick.")
	var foot: Vector2 = worker.art.global_position
	var prep_column: int = worker.sprite.frame_coords.x
	_expect(is_equal_approx(foot.distance_to(plot), worker.FIELD_STANCE_DISTANCE)
		and tool.aim.is_equal_approx(foot.direction_to(plot)) and tool.work_pose() == 0,
		"Line up with the plot and plant the feet during windup.")
	if facing == Vector2.UP:
		_expect(absf(foot.x - plot.x) > 8.0 and tool.aim.y < -0.8, "Stand to one side so the plant remains visible from behind.")
	else:
		_expect(tool.aim.is_equal_approx(facing), "Use the approach direction where the plot is visible.")
	_expect(worker._advance_field_pose(duration), "A long presentation frame stops at exact contact.")
	_expect(worker.global_position == body and worker.art.global_position == foot
		and tool._near_field_point().is_equal_approx(worker.art.to_local(plot)), "The contact retains the planted visual stance.")
	_expect(tool.work_pose() == 1 and worker.sprite.frame_coords.x == prep_column + 1,
		"Hands and body present the same contact frame.")
	var mirror := Vector2(-1, 1) if tool.flip_h else Vector2.ONE
	match tool.frame:
		tool.Action.TILL:
			_expect(tool.to_global(tool.HOE_EDGE * mirror).distance_to(plot) < 1.0, "The hoe meets the selected soil.")
		tool.Action.WATER:
			var lip: Vector2 = tool.transform * (tool.PAIL_LIP * mirror)
			var water: PackedVector2Array = tool._water_stream(lip, mirror.x, 1.0)
			_expect(worker.art.to_global(water[-1]).is_equal_approx(plot), "Water travels from the tilted lip to the selected plot.")
		tool.Action.HARVEST:
			_expect(tool.to_global(tool.SICKLE_EDGE * mirror).distance_to(plot - Vector2(0, 3)) < 1.0,
				"The sickle meets the selected stem above the soil.")

func _check_exact_center(worker: Node2D, field: Vector2i, plot: Vector2, job: int) -> void:
	worker.target_grid_pos = field
	worker.field_job = job
	worker.global_position = plot
	worker.art.position = Vector2.ZERO
	worker._stance = Vector2.INF
	worker.last_heading = Vector2.UP
	worker.set_state(worker.State.WORK)
	worker._advance_field_pose(worker.work_left * 0.10)
	_expect(worker.sprite.walking and worker.art.global_position.y > plot.y,
		"A worker starting on the crop takes a short step back.")
	worker._advance_field_pose(worker.work_left)
	var foot: Vector2 = worker.art.global_position
	_expect(is_equal_approx(foot.distance_to(plot), worker.FIELD_STANCE_DISTANCE)
		and foot.y > plot.y and absf(foot.x - plot.x) > 8.0
		and not worker.sprite.walking, "The step back settles before the pail tips.")

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error(detail)
