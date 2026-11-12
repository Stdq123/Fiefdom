extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		push_error(detail)
		failed = true

func _key(code: Key) -> void:
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = code
	key.physical_keycode = code
	root.push_input(key, true)

func _drive_to(player: Node2D, target: Vector2) -> void:
	for frame in range(240):
		var direction := target - player.position
		if direction.length() <= 6.0:
			break
		if direction.x > 3.0:
			Input.action_press("ui_right")
		elif direction.x < -3.0:
			Input.action_press("ui_left")
		if direction.y > 3.0:
			Input.action_press("ui_down")
		elif direction.y < -3.0:
			Input.action_press("ui_up")
		await physics_frame
		for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
			Input.action_release(action)
	await process_frame

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run six-arts with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	var state := root.get_node("Global")
	var world := current_scene.get_node("World")
	var ui := current_scene.get_node("UI")
	ui.manage_button.pressed.emit()
	await process_frame
	var management = ui.panel_manager.management_panel_instance
	management.get_node("HBoxContainer/RightPanel").current_tab = 2
	management.music_button.pressed.emit()
	var practice = management.get_node("MusicPractice")
	_expect(paused, "The rhythm panel pauses the estate during the exercise.")
	for beat in range(1, 5):
		var hit_at: float = practice.BEAT_SECONDS * beat - practice.HIT_WINDOW / 2.0
		while practice.elapsed < hit_at:
			await process_frame
		_key(KEY_SPACE)
		_key(KEY_SPACE)
	while not practice.finished:
		await process_frame
	_expect(practice.hits == 4 and state.player_stats.stats["MUSIC"]["xp"] == 30,
		"Four timed strikes earn music XP, and a beat cannot be scored twice.")
	_key(KEY_ESCAPE)
	await process_frame
	_expect(not paused and management.music_button.disabled, "Closing the exercise resumes the estate and locks its daily reward.")

	management.driving_button.pressed.emit()
	var course := world.get_node("DrivingPractice")
	_expect(not management.visible and world.player.training_cart.visible, "Driving starts on the map with the cart visible.")
	for marker in course.ROUTE:
		await _drive_to(world.player, marker)
	_expect(not course.is_processing() and not world.player.training_cart.visible
		and state.player_stats.stats["DRIVING"]["xp"] == 30 and "驾御完成" in ui.hud.practice_label.text,
		"Driving through the ordered route completes it and earns XP.")
	_expect(state.save_game() == OK and state.load_game() == OK, "Practice rewards can be saved.")
	await scene_changed
	ui = current_scene.get_node("UI")
	ui.manage_button.pressed.emit()
	await process_frame
	management = ui.panel_manager.management_panel_instance
	_expect(management.music_button.disabled and management.driving_button.disabled, "Reloading preserves the daily reward limits.")
	management.get_node("CloseButton").pressed.emit()
	ui.sleep_button.pressed.emit()
	await create_timer(1.1).timeout
	_expect(not management.music_button.disabled and not management.driving_button.disabled, "Practice becomes available on the next day.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
