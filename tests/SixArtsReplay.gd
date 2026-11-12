extends "res://tests/WestMarketReplay.gd"

var world: Node2D
var ui: CanvasLayer
var player: Player
var course: DrivingPractice
var controller
var legacy := false

func _enter_estate(resume: bool) -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button if resume else tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await tree.process_frame
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	player = world.player
	course = world.get_node("DrivingPractice")

func _open_arts() -> Control:
	await _button(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	var tabs: TabContainer = management.get_node("HBoxContainer/RightPanel")
	var bar := tabs.get_tab_bar()
	await _click(bar.get_global_transform_with_canvas() * bar.get_tab_rect(2).get_center())
	return management

func _cross_room(point: Vector2, room: int) -> void:
	await _walk(player, [point])
	for frame in 90:
		if state.estate_room == room:
			break
		await tree.physics_frame
	await Campaign.wait_for_map_change(tree)
	_expect(state.estate_room == room, "Use the hall door before and after checking the course.")

func _play_music(management: Control) -> void:
	await _button(management.music_button)
	var practice := management.get_node("MusicPractice")
	_expect(tree.paused, "The rhythm panel pauses the estate during the exercise.")
	for beat in range(1, 5):
		var hit_at: float = practice.BEAT_SECONDS * beat - practice.HIT_WINDOW / 2.0
		while practice.elapsed < hit_at:
			await tree.process_frame
		await _key(KEY_SPACE)
		await _key(KEY_SPACE)
	while not practice.finished:
		await tree.process_frame
	_expect(practice.hits == 4 and state.player_stats.stats.MUSIC.xp == 30,
		"Four timed strikes earn music XP, and a beat cannot be scored twice.")
	await _key(KEY_ESCAPE)
	_expect(not tree.paused and management.music_button.disabled, "Closing the exercise resumes the estate.")

func _reach_cart() -> void:
	await _walk(player, [Vector2(33, 70), Vector2(33, 128), Vector2(59, 166), Vector2(107, 165),
		Vector2(194, 160), course.START_POINT + Vector2(-6, 3)])
	_expect(player.interaction_target == course, "Follow the lane to the parked cart's interaction prompt.")

func _stick(direction: Vector2) -> void:
	controller._axis(JOY_AXIS_LEFT_X, direction.x)
	controller._axis(JOY_AXIS_LEFT_Y, direction.y)

func _steer_to(point: Vector2) -> void:
	for frame in 240:
		var remaining := point - player.position
		if remaining.length() < 3.0 and player.velocity.length() < 12.0:
			break
		var strength := clampf(remaining.length() / 32.0, 0.0, 1.0)
		_stick(remaining.normalized() * lerpf(controller.pad.DEADZONE, 1.0, strength))
		await tree.physics_frame
	_stick(Vector2.ZERO)
	await tree.process_frame
	_expect(player.position.distance_to(point) < 7.0, "Steer to the waypoint %s. At %s." % [point, player.position])

func _try_controls() -> void:
	await _key(KEY_E)
	await tree.create_timer(0.35).timeout
	_expect(course.is_processing() and player.training_cart.visible and course.elapsed == 0.0 and ui.directions.tracked_place.is_empty(),
		"On the cart the timer waits for movement and the route marker clears.")
	_expect(ui.hud.driving_panel.visible and not ui.hud.get_node("SeedBelt").visible,
		"The driving controls take the place of the farm controls.")
	await _snapshot("02-roadside-start")
	var stamina: int = state.current_stamina
	var tile: TileMapLayer = world.tile_map
	await _click(tile.get_global_transform_with_canvas() * tile.map_to_local(PUBLIC))
	_expect(state.current_stamina == stamina, "The mounted player cannot work a field with the cart controls.")
	Input.action_press(&"ui_left")
	for frame in 12:
		await tree.physics_frame
	var moving := player.position
	var speed := player.velocity.length()
	Input.action_release(&"ui_left")
	for frame in 5:
		await tree.physics_frame
	_expect(speed > 30.0 and speed < Player.CART_SPEED and player.velocity.length() < speed
		and player.position.x < moving.x - 2.0 and course.elapsed > 0.0, "The cart gathers speed and rolls a little after release.")
	print("DRIVING_INERTIA speed=", snappedf(speed, 0.1), " released=", snappedf(player.velocity.length(), 0.1))
	tree.root.notify_mouse_exited()
	await _steer_to(Vector2(222, 195))
	await _steer_to(Vector2(107, 195))
	await _steer_to(course.ROUTE[1])
	_expect(course.next_marker == 0, "Reaching the second gate first does not skip the first flag.")
	await controller._tap(JOY_BUTTON_B)
	_expect(not player.training_cart.visible and not course.is_processing() and course.parked_cart.visible
		and state.can_practice_today(PlayerStats.Art.DRIVING), "B dismounts and allows a fresh attempt without granting XP.")

func _record_hooves() -> AudioEffectRecord:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return null
	var bus := AudioServer.get_bus_index(&"SFX")
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(bus, record)
	record.set_recording_active(true)
	return record

func _finish_recording(record: AudioEffectRecord) -> void:
	if record == null:
		return
	record.set_recording_active(false)
	var bus := AudioServer.get_bus_index(&"SFX")
	var recording := record.get_recording()
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	_expect(recording != null and recording.save_to_wav(capture_dir.path_join("cart-sfx.wav")) == OK,
		"Record the game sound bus while driving the course.")

func _drive_course() -> void:
	await _walk(player, [Vector2(194, 160), course.START_POINT + Vector2(-6, 3)])
	await controller._tap(JOY_BUTTON_X)
	_expect(player.training_cart.visible and course.elapsed == 0.0, "Start again using the controller's interaction button.")
	var recording := _record_hooves()
	_stick(Vector2.LEFT)
	for frame in 12:
		await tree.physics_frame
	await _snapshot("03-first-gate")
	_stick(Vector2.ZERO)
	# Check the first gate during the running capture, then steer through the full lane.
	for gate: Vector2 in course.ROUTE:
		await _steer_to(gate)
	_expect(course.next_marker == course.ROUTE.size() and "停稳" in ui.hud.driving_hint.text,
		"Cross every flag in order and get the parking instruction.")
	_finish_recording(recording)
	await _steer_to(Vector2(44, 217))
	await _snapshot("04-parking")
	_stick(Vector2.DOWN)
	var crossed_at_speed := false
	for frame in 70:
		await tree.physics_frame
		if course.PARKING.has_point(player.position) and player.velocity.length() > 55.0:
			crossed_at_speed = true
		if player.position.y > course.PARKING.end.y + 4.0:
			break
	_stick(Vector2.ZERO)
	_expect(crossed_at_speed and course.is_processing() and state.best_driving_ms == 0,
		"Driving through the parking lines at speed does not complete the exercise.")
	# Slow into the pad until the game dismounts the driver.
	for frame in 190:
		if not course.is_processing():
			break
		var toward: Vector2 = course.PARKING.get_center() - player.position
		var strength := clampf(toward.length() / 32.0, 0.0, 0.65)
		_stick(toward.normalized() * lerpf(controller.pad.DEADZONE, 1.0, strength))
		await tree.physics_frame
	_stick(Vector2.ZERO)
	_expect(not course.is_processing() and not player.training_cart.visible and course.parked_cart.visible
		and state.player_stats.stats.DRIVING.xp == course.REWARD and state.best_driving_ms > 0
		and not ui.hud.driving_panel.visible and ui.hud.get_node("SeedBelt").visible,
		"Stopping inside the parking lines earns the daily reward and records the time.")
	_expect(state.king_storage == 1 and state.player_inventory == 2, "The drive preserves both farm harvest destinations.")
	print("DRIVING_FINISHED day=", state.current_day, " gates=", course.next_marker, " ms=", state.best_driving_ms,
		" xp=", state.player_stats.stats.DRIVING.xp, " public=", state.king_storage, " private=", state.player_inventory)
	await _snapshot("05-completion")

func _save_and_resume() -> void:
	var best: int = state.best_driving_ms
	await _button(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	_expect(settings.save_status.text == "游戏已保存", "Save the new course time with the normal save button.")
	await _enter_estate(true)
	var management := await _open_arts()
	_expect(state.best_driving_ms == best and management.driving_button.disabled and management.music_button.disabled
		and management.driving_record.is_visible_in_tree(), "Continue shows the saved best time and both daily practice limits.")
	await _snapshot("06-reloaded-record")
	await _button(management.get_node("CloseButton"))
	await _button(ui.sleep_button)
	await tree.create_timer(1.12).timeout
	_expect(state.current_day == 4 and state.night_rations.last.served == 1 and state.best_driving_ms == best
		and not management.driving_button.disabled and not management.music_button.disabled,
		"The next ordinary night resets practice and feeds the retainer while preserving the record.")
	print("DRIVING_RESUMED day=", state.current_day, " best=", best, " fed=", state.night_rations.last.served)

func _old_save() -> void:
	await _enter_estate(true)
	var management := await _open_arts()
	_expect(state.current_day == 1 and state.player_stats.stats.DRIVING.xp == 30 and state.best_driving_ms == 0
		and management.driving_button.disabled and not management.driving_record.visible,
		"The genuine old save keeps the already-earned reward with no recorded time.")
	await _button(management.get_node("CloseButton"))
	await _button(ui.sleep_button)
	await tree.create_timer(1.12).timeout
	_expect(state.current_day == 2 and not management.driving_button.disabled, "The old campaign can start the new course the following day.")
	await _reach_cart()
	await _key(KEY_E)
	_expect(course.is_processing() and course.elapsed == 0.0, "The resumed campaign mounts the new cart.")
	await _button(ui.hud.leave_cart)
	_expect(not course.is_processing() and state.player_stats.stats.DRIVING.xp == 30,
		"The mouse dismount control leaves the old experience intact.")
	print("DRIVING_OLD_SAVE day=", state.current_day, " xp=", state.player_stats.stats.DRIVING.xp)

func _play() -> void:
	await _enter_estate(false)
	await _harvest(world, ui)
	var hall := world.get_node("HallRest") as Node2D
	await _walk(player, [hall.get_node("Yard").global_position])
	await _cross_room(hall.get_node("Entrance").global_position, state.EstateRoom.HALL)
	var management := await _open_arts()
	await _play_music(management)
	await _button(management.driving_button)
	_expect(not management.visible and not course.is_processing() and not player.training_cart.visible
		and "南门" in ui.hud.practice_label.text and ui.directions.tracked_place == course.PLACE,
		"From the hall the arts page marks the road and leaves the stopwatch waiting.")
	await _snapshot("01-hall-wayfinding")
	var room := world.get_node("HallInterior") as Node2D
	await _cross_room(room.get_node("Exit").global_position + Vector2(0, 5), state.EstateRoom.OUTDOORS)
	await _reach_cart()
	controller = load("res://tests/GamepadReplay.gd").new()
	controller.tree = tree
	controller.pad = tree.root.get_node("GamepadInput")
	await _try_controls()
	if not failed:
		await _drive_course()
	if not failed:
		await _save_and_resume()

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_DRIVING_CAPTURES")
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated driving profile."):
		tree.quit(1)
		return
	if legacy:
		await _old_save()
	else:
		await _play()
	tree.unload_current_scene()
	for audio in tree.root.get_node("AudioManager").get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
	await tree.process_frame
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
