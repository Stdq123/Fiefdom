extends RefCounted

const TITLE := "res://scenes/Title.tscn"

var tree: SceneTree
var state: Node
var world: Node
var capture_dir := ""
var film_dir := ""
var failed := false

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failed = true
		push_error(message)
	return condition

func _press(button: Button) -> void:
	await tree.process_frame
	if not _expect(button.is_visible_in_tree() and not button.disabled, "Use a visible ending action."):
		return
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = button.get_global_rect().get_center()
		click.global_position = click.position
		click.pressed = pressed
		tree.root.push_input(click, true)
		await tree.process_frame
	await tree.process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame

func _capture(name: String, directory: String) -> void:
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(directory.path_join(name + ".png")) == OK, "Could not capture " + name)

func _new_estate() -> void:
	tree.paused = false
	tree.change_scene_to_file(TITLE)
	await tree.scene_changed
	await tree.process_frame
	var title := tree.current_scene
	await _press(title.new_button)
	if tree.current_scene == title and title.new_confirmation.visible:
		title.new_confirmation.confirmed.emit()
	if tree.current_scene == null:
		await tree.scene_changed
	await tree.process_frame
	world = tree.current_scene.get_node("World")

func _stage_result(traditional: bool) -> void:
	# Stage endgame totals to exercise both films at real speed.
	state.current_day = 56 if traditional else 59
	state.current_rank = state.Rank.DA_FU
	state.tax_reform_day = 53
	state.tax_reform_choice = state.TaxReformChoice.TRADITIONAL if traditional else state.TaxReformChoice.REFORMED
	state.king_storage = 44
	state.private_harvest_total = 67
	state.quest_progress = state.quest_target
	state.quest_completed = true
	state.set_route_baseline()
	state.raids_defeated = 3
	state.silk_workshop.built = true
	if traditional:
		state.king_storage += 8
		state.silk_bolts_offered += 2
		state.field_rotation.promise_day = 4
		state.field_rotation.beans_day = 7
		state.field_rotation.harvest_day = 11
		state.field_rotation.field_number = 1
		state.field_rotation.crop_id = "wheat"
		state.field_rotation.signed_day = 11
	else:
		state.private_harvest_total += 15
		state.silk_bolts_sold += 2
		state.money = 187
		state.road_provisions_delivered = true
		state.road_provisions_day = 9
		state.road_rest_paid_day = 12
		state.last_defense = {"day": 33, "kind": 0, "losses": 0, "guard": "弋戎"}
		state.east_watch_day = 34
	var cell: Vector2i = state.well_fields[0]["center_pos"]
	state.tilled_cells[cell] = true
	if _expect(world.sow_crop(cell, "millet"), "Prepare a ripe crop for play after the ending."):
		state.active_crops[cell]["age"] = state.active_crops[cell]["growth_nights"]
	var events := tree.root.get_node("GameEvents")
	events.tax_reform_choice_made.emit(state.tax_reform_choice)
	events.crop_harvested.emit(traditional)
	await tree.process_frame
	await tree.process_frame

func _record_rows(ending: Control) -> Array[String]:
	var rows: Array[String] = []
	for row: HBoxContainer in ending.results.get_children():
		rows.append(row.get_child(0).text + " " + row.get_child(1).text)
	for line: Label in ending.memories.get_children():
		rows.append(line.text)
	return rows

func _watch_film(ending: Control, branch: String) -> void:
	var frames_dir := ""
	var recording: AudioEffectRecord
	var bus := AudioServer.get_bus_index(&"Music")
	var slot := AudioServer.get_bus_effect_count(bus)
	if not film_dir.is_empty():
		frames_dir = film_dir.path_join(branch)
		DirAccess.make_dir_recursive_absolute(frames_dir)
		recording = AudioEffectRecord.new()
		AudioServer.add_bus_effect(bus, recording)
		recording.set_recording_active(true)
	var first_position: Vector2 = ending.camera.global_position
	var sampled_move := false
	var reached := false
	var first_audio: bool = DisplayServer.get_name() == "headless" or ending.score.playing
	await _capture(branch + "-fields", capture_dir)
	var frames := 0
	var next_sample := Time.get_ticks_msec()
	while ending.film.visible:
		await tree.process_frame
		if ending.shot == ending.Shot.CEREMONY:
			if not reached and ending.envoy.position.is_equal_approx(ending.walk_end):
				reached = true
				_expect(ending.camera.global_position.distance_to(first_position) > 70.0, "The view moves to a distinct location.")
				await _capture(branch + "-ceremony", capture_dir)
			if ending.walk_sprite.walking and ending.walk_sprite.frame_coords.x in [1, 2]:
				sampled_move = true
		if recording and Time.get_ticks_msec() >= next_sample:
			await _capture("frame-%03d" % frames, frames_dir)
			frames += 1
			next_sample += 95
	if recording:
		recording.set_recording_active(false)
		var track := recording.get_recording()
		_expect(track != null and track.save_to_wav(frames_dir.path_join("score")) == OK,
			"Capture the score from the live music bus.")
		AudioServer.remove_bus_effect(bus, slot)
	_expect(reached and sampled_move and first_audio and ending.report.visible, "The envoy walks into view, then the film opens the ledger.")
	await _capture(branch + "-ledger", capture_dir)
	print("ENDING_FILM branch=", branch, " arrival=", reached, " footsteps=", sampled_move, " sampled_frames=", frames)

func _play_ending(traditional: bool) -> void:
	await _new_estate()
	await _stage_result(traditional)
	var branch := "traditional" if traditional else "reformed"
	var hud := tree.current_scene.get_node("CampaignHUD")
	var ending: Control = hud.summary
	if not _expect(ending != null and tree.paused and ending.shot == ending.Shot.FIELD, "The finished route starts on its fields."):
		return
	await _watch_film(ending, branch)
	var rows := _record_rows(ending)
	if traditional:
		_expect(rows[0].begins_with("新增公田纳贡 8 /") and "渠伯把麦的收成记进轮作簿。" in rows
			and not rows.has("季青和你在南路亭西修了歇脚处。"), "The traditional record reflects its actual deeds.")
	else:
		_expect(rows[0].begins_with("新增计税收成 15 /") and "季青和你在南路亭西修了歇脚处。" in rows
			and "弋戎把守田的战果留在东岗。" in rows, "The reform record reflects its actual deeds.")
	await _press(ending.save_button)
	_expect(hud.status.text == "结局已存档。", "The ledger can be stored.")
	_expect(ending.restore_button.disabled, "A finished record or another estate cannot supply a playable checkpoint.")
	await _press(ending.title_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await _press(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	ending = tree.current_scene.get_node("CampaignHUD").summary
	_expect(ending.report.visible and _record_rows(ending) == rows and not ending.score.playing,
		"Continuing the saved ending reproduces its route and deeds.")
	var stage: Node2D = ending.stage
	await _press(ending.replay_button)
	_expect(ending.film.visible and ending.stage == stage, "Replay reuses the stage.")
	await _press(ending.skip_button)
	_expect(ending.report.visible and _record_rows(ending) == rows and not ending.score.playing, "Skip stops the score and restores the same ledger.")
	await _press(ending.replay_button)
	await _key(KEY_ESCAPE)
	_expect(ending.report.visible and _record_rows(ending) == rows and not ending.score.playing and tree.paused,
		"Esc ends the replay with the same ledger and keeps the finished estate paused.")
	await _play_after_ending(ending, traditional, branch, rows)

func _play_after_ending(ending: Control, traditional: bool, branch: String, rows: Array[String]) -> void:
	var date: String = ending.date.text
	var day: int = state.current_day
	var campaign: String = state.campaign_id
	var at := Vector2(59, 79)
	var preferences := tree.root.get_node("Preferences")
	preferences.autosave = traditional
	var player := tree.get_first_node_in_group("player")
	player.arrive_at_position(at, Vector2.LEFT)
	await _press(ending.continue_button)
	preferences.autosave = true
	if not _expect(state.outcome == state.Outcome.RUNNING and state.campaign_id == campaign and state.current_day == day
		and not tree.paused, "Continue opens the same estate on the day the route was won."):
		return
	var scene := tree.current_scene
	world = scene.get_node("World")
	player = world.player
	_expect(player.global_position.is_equal_approx(at) and player.facing_direction() == Vector2.LEFT
		and player.camera.is_current() and scene.get_node("UI").visible, "The HUD, field camera and player position return after the film.")
	var checkpoint: Dictionary = state.latest_saved_game()
	_expect(checkpoint["source"] == ("续营自动存档" if traditional else "手动存档"), "Continuing respects the autosave preference.")
	var public_before: int = state.king_storage
	var private_before: int = state.private_harvest_total
	var cell: Vector2i = state.well_fields[0]["center_pos"]
	_expect(world.harvest_crop(cell), "A ripe plot remains harvestable after continuing.")
	await tree.process_frame
	await tree.process_frame
	_expect((state.king_storage > public_before and state.private_harvest_total == private_before) if traditional else
		(state.king_storage == public_before and state.private_harvest_total > private_before), "The center plot still follows the chosen tax route.")
	_expect(scene.get_node("CampaignHUD").summary == null and not tree.paused, "Harvesting after victory does not play the ending again.")
	var stand := world.get_node("Scenery/EndingRecord") as Sprite2D
	if not _expect(stand.visible and stand.is_in_group("interactable"), "The route record has a physical place in the continuing estate."):
		return
	player.arrive_at_position(stand.global_position + Vector2(0, 17), Vector2.UP)
	await tree.physics_frame
	await tree.process_frame
	await tree.create_timer(0.55).timeout
	await _capture(branch + "-record-stand", capture_dir)
	await _key(KEY_M)
	var map := scene.get_node("UI/Control/EstateMap")
	var first_place: Dictionary = map.places.front()
	_expect(map.modal.visible and first_place["title"] == stand.record_name
		and first_place["point"] == world.to_local(stand.global_position), "The first place on the map locates the physical record.")
	await _capture(branch + "-record-map", capture_dir)
	await _key(KEY_ESCAPE)
	await _key(KEY_E)
	var archive: Control = scene.get_node("CampaignHUD").summary
	if not _expect(archive != null and tree.paused, "Use E near the stand to read the record."):
		return
	_expect(archive.date.text == date and _record_rows(archive) == rows and player.camera.is_current()
		and not archive.save_button.visible and not archive.replay_button.visible, "The saved accounts and date remain fixed after harvesting.")
	await _capture(branch + "-record-read", capture_dir)
	await _key(KEY_ESCAPE)
	_expect(not tree.paused and tree.current_scene == scene and scene.get_node("CampaignHUD").summary == null,
		"Closing the record returns to the same spot without playing the film.")
	print("POST_END_RECORD branch=", branch, " day=", day, " public=", state.king_storage - public_before,
		" private=", state.private_harvest_total - private_before, " archive=", stand.record_name)

func _verify_old_record() -> void:
	var path: String = state.manual_save_path()
	var prior: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	prior.erase("route_baseline")
	prior.erase("ending_record")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(prior))
	file.close()
	tree.paused = false
	tree.change_scene_to_file(TITLE)
	await tree.scene_changed
	await tree.process_frame
	_expect(state.load_game(path) == OK, "Read the old ending through the normal save loader.")
	if tree.current_scene == null:
		await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	var ending: Control = tree.current_scene.get_node("CampaignHUD").summary
	var rows := _record_rows(ending)
	_expect(ending.report.visible and not ending.has_route_totals and rows[0].begins_with("国库 44"),
		"An old finished save shows its known totals without inventing route deltas.")

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the ending replay's profile."):
		tree.quit(1)
		return
	tree.root.notify_mouse_entered()
	capture_dir = OS.get_environment("FIEFDOM_ENDING_CAPTURES")
	film_dir = OS.get_environment("FIEFDOM_ENDING_FILMS")
	state = tree.root.get_node("Global")
	await _play_ending(true)
	await _play_ending(false)
	await _verify_old_record()
	tree.paused = false
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.create_timer(0.25).timeout
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
