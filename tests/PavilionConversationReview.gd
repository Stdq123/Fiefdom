extends RefCounted

var tree: SceneTree
var evidence := ""
var failed := false

func run(scenario: SceneTree, directory := "") -> bool:
	tree = scenario
	evidence = directory
	tree.paused = true
	await _review(7, "road_grain", "dry")
	await _review(6, "watch_lantern", "rain")
	return not failed

func _review(day: int, id: String, sample: String) -> void:
	var state := tree.root.get_node("Global")
	var speakers := PavilionStories.speakers(id)
	state.current_day = day
	state.day_progress = 1.0
	state.road_provisions_delivered = id == "road_grain"
	state.east_watch_day = 5 if id == "watch_lantern" else 0
	state.retainers.assign([RetainerData.new(speakers[1])])
	for speaker: String in speakers:
		state.neighbor_met_days[speaker] = day
	if not _expect(tree.change_scene_to_file(state.ESTATE_SCENE) == OK, "Open the frozen estate."):
		return
	await tree.scene_changed
	var world := tree.current_scene.get_node("World") as Node2D
	var ui := tree.current_scene.get_node("UI")
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	var table: PavilionRest = world.pavilion_rest
	var walker: Player = world.player
	var visitor := table.seated_neighbor(speakers[0]) as Visitor
	var retainer := table.seated_neighbor(speakers[1]) as Retainer
	if not _expect(table.story_id == id and visitor != null and retainer != null, "The table finds both seated neighbors."):
		return
	walker.arrive_at_position(table.global_position + Vector2(-6, 0), Vector2.UP)
	var feet := [visitor.global_position, retainer.global_position]
	var at_rest := [_heading(visitor.sprite), _heading(retainer.sprite)]
	var snapshot := [state.current_day, state.day_progress, state.money, state.food_storage,
		state.current_stamina, hash(state.active_crops), state.pavilion_stories_heard.duplicate()]

	table.interact()
	var menu := _dialog()
	if not _expect(menu != null and not walker.seated and not table.speech_cue.visible, "The invitation leaves the view at rest."):
		return
	menu.choices[0].pressed.emit()
	await tree.process_frame
	await tree.process_frame
	visitor._idle_at_stop(0.0)
	retainer._stand_at_stop()
	if not _check_turn(visitor, retainer, table, walker):
		return
	await _capture(sample + "-visitor", table)

	_dialog().choices[0].pressed.emit()
	await tree.process_frame
	await tree.process_frame
	if not _check_turn(retainer, visitor, table, walker):
		return
	await _capture(sample + "-retainer", table)

	_dialog().choices[0].pressed.emit()
	await tree.process_frame
	await tree.process_frame
	if not _check_turn(visitor, retainer, table, walker):
		return
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	tree.root.push_input(cancel, true)
	await tree.process_frame
	await tree.process_frame
	_expect(_dialog() == null and not walker.conversation_open and not walker.seated and not table.speech_cue.visible,
		"Esc ends the pose and removes the speaker cue.")
	_expect(visitor.pavilion_partner == null and retainer.pavilion_partner == null
		and at_rest == [_heading(visitor.sprite), _heading(retainer.sprite)], "Both neighbors look back toward their usual stop.")
	_expect(table.hint.visible and visitor.hint.visible and not retainer.hint.visible, "The usual names and table prompt return to their earlier visibility.")
	_expect(feet == [visitor.global_position, retainer.global_position], "Turning at the table keeps both neighbors on their mats.")
	_expect(snapshot == [state.current_day, state.day_progress, state.money, state.food_storage,
		state.current_stamina, hash(state.active_crops), state.pavilion_stories_heard]
		and state.saved_games().is_empty(), "Leaving the sample keeps the clock, economy, story and saves untouched.")
	print("PAVILION_CONVERSATION ", sample, " speakers=", speakers, " seats=", feet, " saves=", state.saved_games().size())

func _check_turn(speaker: Node2D, listener: Node2D, table: PavilionRest, walker: Player) -> bool:
	var dialog := _dialog()
	var toward: Vector2 = listener.global_position - speaker.global_position
	return _expect(dialog != null and dialog.name_label.text == speaker.data.name and dialog.portrait.texture != null
		and walker.seated and walker.global_position == table.global_position and table.speech_cue.is_visible_in_tree()
		and table.speech_cue.global_position == speaker.global_position + PavilionRest.SPEECH_OFFSET
		and not table.hint.visible and not speaker.hint.visible and not listener.hint.visible
		and _faces(speaker.sprite, toward) and _faces(listener.sprite, -toward),
		"The visible portrait and cue follow the speaker while all three stay seated.")

func _heading(sprite: NeighborMotion) -> Vector2i:
	return Vector2i(sprite.facing, int(sprite.flip_h))

func _faces(sprite: NeighborMotion, toward: Vector2) -> bool:
	if absf(toward.x) > absf(toward.y):
		return _heading(sprite) == Vector2i(NeighborMotion.Facing.PROFILE, int(toward.x < 0.0))
	return sprite.facing == (NeighborMotion.Facing.BACK if toward.y < 0.0 else NeighborMotion.Facing.FRONT)

func _dialog() -> Control:
	return tree.get_first_node_in_group("dialogue_panel") as Control

func _capture(name: String, table: PavilionRest) -> void:
	if evidence.is_empty():
		return
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	var cue := table.speech_cue
	var transform := tree.root.get_stretch_transform() * cue.get_global_transform_with_canvas()
	var area := Rect2i(transform * Rect2(Vector2(-9, -6), Vector2(18, 15)))
	if not _expect(Rect2i(Vector2i.ZERO, frame.get_size()).encloses(area), "The speech cue fits inside the rendered view."):
		return
	_expect(frame.save_png(evidence.path_join(name + ".png")) == OK, "Capture the fixed listening view.")
	cue.hide()
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var hidden := tree.root.get_texture().get_image()
	cue.show()
	var changed := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var before := frame.get_pixel(x, y)
			var after := hidden.get_pixel(x, y)
			if absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b) > 0.30:
				changed += 1
	_expect(changed > 80, "The speech cue is actually drawn over the scene and visible through the dialog shade.")
	print("PAVILION_FRAME ", name, " size=", frame.get_size(), " cue_pixels=", changed)

func _expect(ok: bool, detail: String) -> bool:
	if not ok:
		failed = true
		push_error(detail)
	return ok
