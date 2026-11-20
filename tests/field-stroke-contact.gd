extends SceneTree

var failed := false
var world: Node2D
var actor
var tool

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
	world = current_scene.get_node("World")
	actor = world.player
	tool = actor.tool_gesture
	var before := [state.current_day, state.day_progress, state.current_stamina, state.food_storage,
		state.money, hash(state.active_crops), hash(state.tilled_cells)]
	var cell: Vector2i = state.well_fields[0].center_pos
	var plot := world.to_global(world.get_crop_world_pos(cell))
	for facing: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		actor.arrive_at_position(plot - facing * 16.0, facing)
		for action: int in range(4):
			_check_stroke(cell, action, plot)
	actor.arrive_at_position(plot - Vector2(16, 0), Vector2.RIGHT)
	_check_drag(cell)
	_check_replacement(cell)
	actor.arrive_at_position(plot - Vector2(64, 0), Vector2.RIGHT)
	_check_far_plot(cell, plot)
	_expect(paused and before == [state.current_day, state.day_progress, state.current_stamina, state.food_storage,
		state.money, hash(state.active_crops), hash(state.tilled_cells)] and state.saved_games().is_empty(),
		"Present fixed field feedback while the campaign is paused.")
	_reset()
	current_scene.queue_free()
	await process_frame
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_stroke(cell: Vector2i, action: int, plot: Vector2) -> void:
	_reset()
	world._play_field_stroke(cell, action)
	tool._process(0.04)
	_expect(tool.visible and _impacts().is_empty(), "Allow the windup to show before feedback.")
	tool._process(0.06)
	var impacts := _impacts()
	_expect(tool.work_pose() == 1 and impacts.size() == 1, "Draw one tile impact on the contact pose.")
	_expect(actor.sprite.frame_coords.x == PlayerAttire.WORK_COLUMN + 1, "Draw the stationary actor in the contact frame.")
	if impacts.size() == 1:
		_expect(impacts[0].global_position.is_equal_approx(plot) and impacts[0].frame_coords.x == action,
			"Each tool effect uses the selected plot and its own atlas column.")
	var ground: Vector2 = actor.to_local(plot)
	var mirror := Vector2(-1, 1) if tool.flip_h else Vector2.ONE
	match action:
		tool.Action.TILL:
			_expect((tool.transform * (tool.HOE_EDGE * mirror)).distance_to(ground) < 1, "The hoe reaches the soil.")
		tool.Action.HARVEST:
			_expect((tool.transform * (tool.SICKLE_EDGE * mirror)).distance_to(ground - Vector2(0, 3)) < 1,
				"The cutting edge meets the stalk a little above the soil.")
		tool.Action.WATER:
			var lip: Vector2 = tool.transform * (tool.PAIL_LIP * mirror)
			var stream: PackedVector2Array = tool._water_stream(lip, mirror.x, 1.0)
			_expect(stream[0].is_equal_approx(lip) and stream[-1].is_equal_approx(ground), "The pail pours into the aimed plot.")
	tool._process(0.04)
	_expect(_impacts().size() == 1, "Recovery plays the contact once.")

func _check_drag(cell: Vector2i) -> void:
	_reset()
	var next := cell + Vector2i.RIGHT
	world._play_field_stroke(cell, tool.Action.TILL)
	tool._process(0.03)
	world._play_field_stroke(next, tool.Action.TILL)
	_expect(_impacts().is_empty(), "The next plot can join the current windup.")
	tool._process(0.10)
	var positions := _impacts().map(func(mark: Sprite2D): return mark.position)
	_expect(positions == [world.get_crop_world_pos(cell), world.get_crop_world_pos(next)],
		"The shared stroke leaves one impact on each plot.")

func _check_replacement(cell: Vector2i) -> void:
	_reset()
	world._play_field_stroke(cell, tool.Action.SOW)
	tool._process(0.02)
	world._play_field_stroke(cell, tool.Action.WATER)
	var first := _impacts()
	_expect(first.size() == 1 and first[0].frame_coords.x == tool.Action.SOW, "Replacing a tool confirms the settled action.")
	tool._process(0.40)
	var all := _impacts()
	_expect(all.size() == 2 and all[1].frame_coords.x == tool.Action.WATER and tool.work_pose() == 1,
		"A slow frame still draws the next contact pose.")

func _check_far_plot(cell: Vector2i, plot: Vector2) -> void:
	_reset()
	world._play_field_stroke(cell, tool.Action.WATER)
	tool._process(0.08)
	var mirror := Vector2(-1, 1) if tool.flip_h else Vector2.ONE
	var lip: Vector2 = tool.transform * (tool.PAIL_LIP * mirror)
	var water: PackedVector2Array = tool._water_stream(lip, mirror.x, 1.0)
	var marks := _impacts()
	_expect(lip.distance_to(water[-1]) < 10 and marks.size() == 1 and marks[0].global_position.is_equal_approx(plot),
		"A distant plot gets its field effect while the pail stays at hand scale.")

func _impacts() -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	for item in world.get_children():
		if item is Sprite2D and item.texture == world.FIELD_IMPACTS:
			found.append(item)
	return found

func _reset() -> void:
	tool.clear()
	for mark in _impacts():
		mark.free()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
