extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")

var tree: SceneTree
var state: Node
var capture_dir := ""
var film_dir := ""
var failed := false

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failed = true
		push_error(detail)
	return condition

func _capture(name: String, directory: String) -> void:
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	var picture := tree.root.get_texture().get_image()
	_expect(picture.save_png(directory.path_join(name + ".png")) == OK, "Could not capture " + name)

func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for tick in frames:
		await tree.physics_frame
	Input.action_release(action)
	await Campaign.wait_for_map_change(tree)

func _enter_ravine() -> bool:
	var player: Node2D = tree.current_scene.get_node("World/Player")
	await Campaign.walk_to(tree, player, Vector2(player.position.x, 0))
	await _move(&"ui_right", 285)
	await tree.process_frame
	if not _expect(tree.current_scene.name == "Wilderness", "Walk east from the estate into Bamboo Ravine."):
		return false
	for enemy in tree.get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	return true

func _leave_ravine() -> bool:
	await Campaign.walk_to_ravine_exit(tree, tree.current_scene)
	await _move(&"ui_left", 23)
	return _expect(tree.current_scene.name == "Main", "Walk through the west gate to return to the estate.")

func _sleep_on(target_term: String) -> void:
	state.current_day = state.SOLAR_TERMS.find(target_term) * state.balance.days_per_solar_term
	tree.current_scene.get_node("UI").sleep_button.pressed.emit()
	await tree.create_timer(1.15).timeout

func _watch_frog(player: Node2D, frog: Node2D) -> void:
	await Campaign.walk_ravine_to(tree, tree.current_scene, frog.global_position + Vector2(-108, 0))
	var record: AudioEffectRecord
	var ambience := AudioServer.get_bus_index("Ambience")
	var effect := AudioServer.get_bus_effect_count(ambience)
	if not film_dir.is_empty():
		record = AudioEffectRecord.new()
		AudioServer.add_bus_effect(ambience, record)
		record.set_recording_active(true)
	var heard_call := false
	var saw_leap := false
	var saw_ripple := false
	Input.action_press(&"ui_right")
	for tick in 100:
		await tree.physics_frame
		if tick == 55:
			Input.action_release(&"ui_right")
		heard_call = heard_call or frog.croak.playing
		if tick == 30:
			await _capture("03-frog-on-the-bank", capture_dir)
		if frog.phase == frog.Phase.LEAP and frog.phase_time >= 0.12 and not saw_leap:
			saw_leap = true
			_expect(frog.body.frame == 1 and frog.body.position.y < -4.0, "The leap changes pose and lifts the frog.")
			await _capture("04-frog-leap", capture_dir)
		if frog.phase == frog.Phase.WATER and frog.phase_time >= 0.11 and not saw_ripple:
			saw_ripple = true
			_expect(not frog.body.visible, "The frog disappears at the ripple's center.")
			await _capture("05-ripple-in-the-creek", capture_dir)
		if not film_dir.is_empty() and tick % 4 == 0:
			await _capture("frame-%03d" % floori(tick / 4.0), film_dir)
	if record:
		record.set_recording_active(false)
		_expect(record.get_recording().save_to_wav(film_dir.path_join("creek")) == OK, "Could not record creek ambience.")
		AudioServer.remove_bus_effect(ambience, effect)
	_expect(saw_leap and saw_ripple, "Approaching the bank must trigger a leap and a ripple.")
	_expect(frog.croak.bus == &"Ambience" and frog.croak.max_distance == frog.HEARING_RANGE
		and frog.croak.global_position == frog.global_position, "The croak follows the ambience setting and originates at the bank.")
	_expect(heard_call or DisplayServer.get_name() == "headless", "The real sound player croaks as the player nears the bank.")
	await tree.create_timer(frog.HIDE_SECONDS).timeout
	_expect(frog.phase == frog.Phase.WATER, "The frog stays hidden while the player waits at the bank.")
	await Campaign.walk_to(tree, player, frog.global_position + Vector2(-92, 0))
	_expect(frog.phase == frog.Phase.BANK and frog.body.visible, "Leaving the bank lets the frog return after a pause.")
	print("WILDLIFE_FROG leap=", saw_leap, " ripple=", saw_ripple, " positional_sound=", heard_call)

func _finish() -> void:
	tree.unload_current_scene()
	tree.root.get_node("AudioManager").bgm_player.stop()
	# Allow the audio mixer to release the last stream playbacks before quitting.
	await tree.create_timer(0.18).timeout
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the wildlife replay's save directory."):
		await _finish()
		return
	capture_dir = OS.get_environment("FIEFDOM_WILDLIFE_CAPTURES")
	film_dir = OS.get_environment("FIEFDOM_WILDLIFE_FILM")
	state = tree.root.get_node("Global")
	tree.change_scene_to_file("res://scenes/Title.tscn")
	await tree.scene_changed
	tree.current_scene.new_button.pressed.emit()
	await tree.scene_changed
	await tree.process_frame
	state.balance.raid_first_day = 10000
	var pavilion: Node2D = tree.current_scene.get_node("World/Scenery/PavilionButterfly")
	var actor: Node2D = tree.current_scene.get_node("World/Player")
	await Campaign.walk_to(tree, actor, Vector2(108, 306))
	var first_at := pavilion.position
	var wings_seen: Dictionary[int, bool] = {}
	for tick in 30:
		wings_seen[pavilion.wings.frame] = true
		await tree.physics_frame
	_expect(pavilion.visible and pavilion.position != first_at and wings_seen.size() == 3,
		"The spring butterfly circles the flowers and shows all three wing poses.")
	if not capture_dir.is_empty():
		for frame in 12:
			if pavilion.wings.frame_coords.x == 0:
				break
			await tree.process_frame
	await _capture("01-pavilion-butterfly", capture_dir)
	if not await _enter_ravine():
		await _finish()
		return
	actor = tree.current_scene.get_node("Player")
	var grove: Node2D = tree.current_scene.get_node("Scenery/GroveButterfly")
	_expect(grove.visible and grove.wings.frame_coords.y == 1, "The sunny grove uses the second butterfly art.")
	await Campaign.walk_ravine_to(tree, tree.current_scene, grove.global_position + Vector2(-3, 6))
	if not capture_dir.is_empty():
		for frame in 12:
			if grove.wings.frame_coords.x == 0:
				break
			await tree.process_frame
	await _capture("02-grove-butterfly", capture_dir)
	await _watch_frog(actor, tree.current_scene.get_node("Scenery/CreekFrog"))
	if not await _leave_ravine():
		await _finish()
		return
	await _sleep_on("谷雨")
	pavilion = tree.current_scene.get_node("World/Scenery/PavilionButterfly")
	_expect(state.has_rain() and not pavilion.visible and not pavilion.is_processing(),
		"The pavilion butterfly shelters after sleeping into rain.")
	if not await _enter_ravine():
		await _finish()
		return
	grove = tree.current_scene.get_node("Scenery/GroveButterfly")
	var frog: Node2D = tree.current_scene.get_node("Scenery/CreekFrog")
	_expect(not grove.visible and frog.visible, "Rain hides the grove butterfly while the frog remains.")
	if not await _leave_ravine():
		await _finish()
		return
	await _sleep_on("立冬")
	pavilion = tree.current_scene.get_node("World/Scenery/PavilionButterfly")
	_expect(state.season_index() == state.Season.WINTER and not pavilion.visible, "The pavilion butterfly stays hidden in winter.")
	if not await _enter_ravine():
		await _finish()
		return
	grove = tree.current_scene.get_node("Scenery/GroveButterfly")
	frog = tree.current_scene.get_node("Scenery/CreekFrog")
	_expect(not grove.visible and not frog.visible and not frog.is_processing() and not frog.croak.playing,
		"The grove and creek are dormant in winter.")
	print("WILDLIFE_WEATHER sun_frames=", wings_seen.keys(), " rain_frog=true winter_dormant=true")
	await _finish()
