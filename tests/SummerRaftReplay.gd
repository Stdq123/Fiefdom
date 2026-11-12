extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const PUBLIC := Vector2i(5, 5)
const PRIVATE := Vector2i(6, 5)

var tree: SceneTree
var state: Node
var capture_dir: String
var day := 0
var failures := 0

func _expect(ok: bool, message: String) -> bool:
	if not ok:
		failures += 1
		push_error(message)
	return ok

func _raw(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	_raw(event)

func _key(code: Key) -> void:
	_key_event(code, true)
	_key_event(code, false)
	await tree.process_frame

func _pad(code: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = code
		event.pressed = pressed
		_raw(event)
		await tree.process_frame

func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	_raw(event)

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	tree.root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame

func _button(button: Button) -> void:
	await tree.process_frame
	var rect := button.get_global_rect()
	if _expect(button.is_visible_in_tree() and not button.disabled and tree.root.get_visible_rect().encloses(rect),
			"Use the visible %s button." % button.text):
		await _click(rect.get_center())

func _frame(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Save raft frame " + name)
	print("RAFT_FRAME ", name, " window=", tree.root.size, " image=", image.get_size())

func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for frame in frames:
		await tree.physics_frame
		if tree.root.get_node("MapTravel").active:
			break
	Input.action_release(action)
	await Campaign.wait_for_map_change(tree)

func _sleep() -> void:
	var tomorrow: int = state.current_day + 1
	await _button(tree.current_scene.get_node("UI").sleep_button)
	await tree.create_timer(1.12).timeout
	_expect(state.current_day == tomorrow and state.outcome == state.Outcome.RUNNING, "Ordinary sleep advances the date.")

func _first_harvest() -> void:
	var world := tree.current_scene.get_node("World")
	world.retainer_instances[state.retainers[0]].set_physics_process(false)
	var tiles: TileMapLayer = world.tile_map
	var public_point := tiles.get_global_transform_with_canvas() * tiles.map_to_local(PUBLIC)
	var private_point := tiles.get_global_transform_with_canvas() * tiles.map_to_local(PRIVATE)
	for point in [public_point, private_point]:
		for action in 3:
			await _click(point)
	await _sleep()
	await _click(public_point)
	await _click(private_point)
	await _sleep()
	await _click(public_point)
	await _click(private_point)
	_expect(state.current_day == 3 and state.king_storage == 1 and state.player_inventory == 1 and state.money == 5,
		"Start the event replay after a normal harvest that separates public and private crops.")

func _tend_to_eve() -> void:
	var world := tree.current_scene.get_node("World")
	var tiles: TileMapLayer = world.tile_map
	for _night in range(state.current_day, day - 1):
		for cell in [PUBLIC, PRIVATE]:
			var point := tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)
			if world.is_crop_ripe(cell):
				await _click(point)
			if not state.active_crops.has(cell):
				await _click(point)
			if world.is_crop_dry(cell):
				await _click(point)
		await _sleep()
	_expect(state.current_day == day - 1 and state.king_storage > 1, "Tend both plots and reach the eve of the solstice through ordinary days.")

func _calendar(capture := "") -> void:
	var ui := tree.current_scene.get_node("UI")
	await _key(KEY_C)
	await _button(ui.calendar.seasons.get_node("Summer"))
	await _button(ui.calendar.dates.get_child(3))
	_expect(ui.calendar.event_note.visible and "夏至试筏" in ui.calendar.event_note.text,
		"The summer solstice has its own almanac entry.")
	if not capture.is_empty():
		await _frame(capture)

func _travel_to_ravine() -> bool:
	var world := tree.current_scene.get_node("World")
	var actor: Player = world.player
	if actor.position.x < 300.0:
		await _move(&"ui_up", 48)
		await _move(&"ui_right", 213)
	else:
		await _move(&"ui_right", 60)
	return _expect(tree.current_scene.scene_file_path == state.WILDERNESS_SCENE, "Walk through East Gate into the ravine.")

func _walk_to_landing() -> bool:
	await tree.process_frame
	var ravine := tree.current_scene
	var chart: Control = ravine.get_node("CampaignHUD").view.get_node("RavineMap")
	var guide := ravine.get_node("RavineDirections")
	if state.current_day == day:
		_expect(guide.destination_name == SummerRaft.PLACE and guide.route.size() >= 3,
			"The calendar destination transfers to a walkable ravine route.")
		print("RAFT_ROUTE destination=", guide.destination_name, " waypoints=", guide.route.size())
	await _key(KEY_M)
	await _button(chart.markers[SummerRaft.PLACE])
	if not _expect(guide.destination_name == SummerRaft.PLACE and guide.route.size() >= 3,
			"The raft landing is reachable from its map marker."):
		return false
	if state.current_day == day:
		await _frame("02-ravine-map")
	await _key(KEY_ESCAPE)
	var walker: Player = ravine.get_node("Player")
	for point: Vector2 in guide.route.duplicate():
		await Campaign.walk_to(tree, walker, point)
	await tree.physics_frame
	return _expect(walker.interaction_target == ravine.raft_landing and guide.destination_name.is_empty(),
		"Follow the marked path to the actual raft landing.")

func _race(trial: Node, steering := false, gamepad := false, capture := false) -> void:
	await _button(trial.start_button)
	for frame in 220:
		if trial.phase == trial.Phase.RUNNING:
			break
		await tree.physics_frame
	if gamepad:
		_axis(JOY_AXIS_LEFT_Y, 1.0)
	var command := 0
	for frame in 1500:
		if trial.phase != trial.Phase.RUNNING:
			break
		if steering and trial.next_gate < SummerRaft.GATES.size():
			var gate: Vector2 = SummerRaft.GATES[trial.next_gate]
			var difference: float = gate.x - trial.lateral
			var next := signi(roundi(difference)) if absf(difference) > 2.4 else 0
			if next != command:
				if gamepad:
					_axis(JOY_AXIS_LEFT_X, next)
				else:
					if command != 0:
						_key_event(KEY_J if command > 0 else KEY_A, false)
					if next != 0:
						_key_event(KEY_J if next > 0 else KEY_A, true)
				command = next
		elif command != 0:
			if gamepad:
				_axis(JOY_AXIS_LEFT_X, 0.0)
			else:
				_key_event(KEY_J if command > 0 else KEY_A, false)
			command = 0
		if capture and trial.next_gate == 1 and trial.lateral > 0.0:
			await _frame("04-steering")
			capture = false
		await tree.physics_frame
	if gamepad:
		_axis(JOY_AXIS_LEFT_X, 0.0)
		_axis(JOY_AXIS_LEFT_Y, 0.0)
	elif command != 0:
		_key_event(KEY_J if command > 0 else KEY_A, false)
	_expect(trial.phase == trial.Phase.RESULT, "A continuous current reaches the finish even without input.")

func _ride() -> bool:
	var ravine := tree.current_scene
	var actor: Player = ravine.get_node("Player")
	var standing := actor.position
	var experience: int = state.player_stats.get_stat(PlayerStats.Art.DRIVING).xp
	var stamina: int = state.current_stamina
	var forage_day: int = state.last_forage_day
	await _key(KEY_E)
	var trial := ravine.get_node_or_null("RaftTrial")
	if not _expect(trial != null and trial.camera.is_current() and trial.start_button.visible,
			"The actual summer landing opens the playable river course."):
		return false
	_expect("A / J" in trial.keys.text, "The landing shows the current custom movement keys.")
	await _frame("03-landing")
	await _button(trial.start_button)
	await _pad(JOY_BUTTON_B)
	await tree.process_frame
	if not _expect(not ravine.has_node("RaftTrial") and actor.visible and actor.camera.is_current() and not tree.paused
			and state.summer_raft_results.is_empty(), "B during the countdown returns the camera and creates no record."):
		return false
	await _key(KEY_E)
	trial = ravine.get_node("RaftTrial")
	var clock: float = state.day_progress
	await _race(trial)
	var drift: Dictionary = state.summer_raft_results.get(day, {})
	_expect(drift.get("gates", -1) == 2 and state.player_stats.get_stat(PlayerStats.Art.DRIVING).xp == experience,
		"Drifting clears only the left-hand gates and earns no experience.")
	await _race(trial, true, false, true)
	var best: Dictionary = state.summer_raft_results.get(day, {})
	if not _expect(best.get("gates", -1) == 4 and state.player_stats.get_stat(PlayerStats.Art.DRIVING).xp == experience + state.balance.summer_raft_driving,
			"Steering left and with the rebound right key clears all four gates and awards experience once."):
		return false
	await _frame("05-finish")
	await _race(trial, true, true)
	var faster: Dictionary = state.summer_raft_results[day]
	_expect(faster.gates == 4 and faster.time_ms < best.time_ms
		and state.player_stats.get_stat(PlayerStats.Art.DRIVING).xp == experience + state.balance.summer_raft_driving,
		"The gamepad can paddle faster and set a new best without repeating the yearly reward.")
	await _race(trial)
	_expect(state.summer_raft_results[day] == faster, "A slower attempt with fewer gates keeps the record.")
	_expect(is_equal_approx(state.day_progress, clock) and state.current_stamina == stamina and state.last_forage_day == forage_day,
		"The activity keeps the estate clock, stamina and outdoor gathering opportunity in place.")
	print("RAFT_RUN day=", day, " drift=", drift, " keyboard=", best, " gamepad=", faster)
	await _button(trial.close_button)
	_expect(not tree.paused and actor.position.is_equal_approx(standing) and actor.visible and actor.camera.is_current(),
		"Leaving the course restores the actual shore position and walking camera.")
	return true

func _return_to_estate() -> bool:
	var ravine := tree.current_scene
	await Campaign.walk_to_ravine_exit(tree, ravine)
	await _move(&"ui_left", 60)
	return _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE, "Return through West Gate after the trial.")

func _save_and_review() -> void:
	var best: Dictionary = state.summer_raft_results[day].duplicate()
	var ui := tree.current_scene.get_node("UI")
	await _button(ui.settings_button)
	var settings: Panel = ui.panel_manager.settings_panel_instance
	for button: Button in settings.general.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	_expect(settings.save_status.text == "游戏已保存", "Save the record from the normal settings menu.")
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE and state.summer_raft_results.get(day) == best,
			"Continuing from the title restores the record exactly."):
		return
	await _calendar("06-almanac-result")
	ui = tree.current_scene.get_node("UI")
	_expect(SummerRaft.score_text(best.gates, best.time_ms) in ui.calendar.event_note.text,
		"The almanac shows the saved best result.")
	await _key(KEY_ESCAPE)
	await _sleep()
	if await _travel_to_ravine() and await _walk_to_landing():
		await _key(KEY_E)
		var ledger := tree.current_scene.get_node("RaftTrial")
		_expect(not ledger.start_button.visible and SummerRaft.score_text(best.gates, best.time_ms) in ledger.detail.text,
			"Outside the summer date the landing is a readable ledger without a launch button.")
		await _frame("07-landing-ledger")
		await _key(KEY_ESCAPE)
	print("RAFT_RELOAD best=", best, " date=", state.current_day)

func run(host: SceneTree, directory := "") -> void:
	tree = host
	capture_dir = directory
	state = tree.root.get_node("Global")
	seed(377)
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	tree.root.notify_mouse_entered()
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await _first_harvest()
	# The campaign replays cover the first raid. Keep this route focused on the solstice.
	day = 1 + state.SOLAR_TERMS.find(SummerRaft.TERM) * state.balance.days_per_solar_term
	state.balance.raid_first_day = 10000
	await _tend_to_eve()
	await _calendar("01-almanac")
	var ui := tree.current_scene.get_node("UI")
	await _button(ui.calendar.guide)
	_expect(state.ravine_trip_target == SummerRaft.PLACE and ui.directions.tracked_place == "竹涧 · " + SummerRaft.PLACE,
		"The solstice's guide points to the East Gate and preserves the actual ravine destination.")
	await _sleep()
	_expect("今日夏至试筏" in ui.hud.gathering_label.text, "The estate calendar announces the event on the day it opens.")
	var preferences := tree.root.get_node("Preferences")
	_expect(preferences.set_binding(KeyBindings.RIGHT, KEY_J) == OK, "Use a custom steering key in the replay.")
	if await _travel_to_ravine() and await _walk_to_landing() and await _ride() and await _return_to_estate():
		await _save_and_review()
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures > 0 else 0)
