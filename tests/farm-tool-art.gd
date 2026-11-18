extends SceneTree

var failed := false

func _initialize() -> void:
	check_art.call_deferred()

func expect(ok: bool, reason: String) -> void:
	if not ok:
		failed = true
		push_error(reason)

func check_art() -> void:
	paused = true
	var state := root.get_node("Global")
	var before := [state.current_day, state.day_progress, state.current_stamina, state.attire_id, state.food_storage]
	var actor = load("res://scenes/Player.tscn").instantiate()
	var footsteps = load("res://scripts/NeighborMotion.gd")
	root.add_child(actor)
	actor._update_walk_sprite(Vector2.RIGHT, 1.0)
	actor._update_walk_sprite(Vector2.RIGHT, 20.0)
	expect(actor.sprite.frame_coords == Vector2i(2, actor.Facing.PROFILE), "The far foot follows the distance walked.")
	actor._update_walk_sprite(Vector2.LEFT, 0.0)
	expect(actor.sprite.flip_h and actor.sprite.frame_coords.x == 0, "A stationary actor must face the wall with both feet planted.")
	var tool: ToolGesture = actor.tool_gesture
	expect(tool.texture.get_size() == Vector2(160, 32) and tool.hframes == ToolGesture.Action.size(), "Farm tool atlas dimensions.")
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN, Vector2.UP]:
		var contacts := {}
		for action: ToolGesture.Action in [ToolGesture.Action.TILL, ToolGesture.Action.SOW, ToolGesture.Action.WATER, ToolGesture.Action.HARVEST]:
			tool.show_sample(action, direction, 0.16, 0.0)
			var raised := tool.transform
			expect(tool.visible and tool.work_pose() == 0, "A new farm stroke has a raised pose.")
			tool.show_sample(action, direction, 0.16, 0.16)
			expect(tool.visible and tool.transform != raised and tool.work_pose() == 1, "Contact must move the held tool and body.")
			expect(tool.show_behind_parent == (direction == Vector2.UP), "Rear-facing stroke draws behind the actor.")
			if action == ToolGesture.Action.TILL:
				var mirror := -1.0 if tool.flip_h else 1.0
				var cutting_edge := tool.transform * Vector2(12.0 * mirror, 6.0)
				expect(cutting_edge.dot(direction) > 12.0, "The hoe must land ahead of the actor in all four directions.")
			contacts[tool.transform] = true
			tool.show_sample(action, direction, 0.16, 0.35)
			expect(not tool.visible and tool.work_pose() == -1, "Tool clears after recovery.")
		expect(contacts.size() == 4, "The four tools must have different contact poses.")
	tool.carry_pail(Vector2.RIGHT, -1.0)
	expect(tool.carrying and tool.rotation == 0.0 and tool.work_pose() == -1, "Carried water stays level.")
	tool.perform(ToolGesture.Action.WATER, Vector2.RIGHT, 0.14)
	tool._process(0.06)
	tool.perform(ToolGesture.Action.WATER, Vector2.RIGHT, 0.14)
	expect(not tool.carrying and is_equal_approx(tool.elapsed, 0.06), "Repeating a stroke keeps its current progress.")
	var panel = load("res://scenes/WardrobePanel.tscn").instantiate()
	root.add_child(panel)
	panel._show_map()
	for id: String in PlayerAttire.CATALOG:
		panel.rows[id].pressed.emit()
		actor.sprite.texture = PlayerAttire.texture(id)
		for motion: int in panel.POSES:
			panel.pose_buttons[motion].pressed.emit()
			expect(panel.pose_buttons.values().filter(func(button: Button) -> bool: return button.button_pressed).size() == 1
				and panel.rows.values().filter(func(button: Button) -> bool: return button.button_pressed).size() == 1, "One garment and one motion are selected.")
			panel._process(0.36)
			for figure in panel.figures:
				var col := 0
				if motion == figure.WALK:
					col = footsteps.walk_column(0.36 * actor.SPEED, PlayerAttire.PASS_COLUMN)
				elif motion >= 0:
					col = PlayerAttire.WORK_COLUMN + 1
				expect(figure.body.frame_coords == Vector2i(col, figure.facing) and figure.tool.visible == (motion >= 0), "Dressing pose " + id)
				expect(figure.tool.sleeve == PlayerAttire.CATALOG[id].sleeve and figure.body.texture.get_size() == actor.sprite.texture.get_size(), "World and dressing figure use the same outfit.")
				if id != PlayerAttire.DEFAULT:
					expect(figure.body.texture.region == actor.sprite.texture.region, "Outfit row changed during preview.")
	expect(before == [state.current_day, state.day_progress, state.current_stamina, state.attire_id, state.food_storage], "Trying a motion must leave the estate and worn clothing intact.")
	panel.close_map()
	expect(not panel.is_processing(), "The closed rack must stop animating.")
	panel.free()
	actor.free()
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
