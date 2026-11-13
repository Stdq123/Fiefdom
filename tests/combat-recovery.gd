extends SceneTree

const Campaign := preload("res://tests/CampaignReplay.gd")

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		push_error(detail)
		failed = true

func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for frame in range(frames):
		await physics_frame
	Input.action_release(action)
	await Campaign.wait_for_map_change(self)

func _wait_for_attack(enemy: Node, attack: int) -> void:
	for frame in range(180):
		if enemy.pending_attack == attack:
			return
		await physics_frame
	_expect(false, "The enemy must begin the expected windup.")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run combat-recovery with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	seed(17)
	root.size = Vector2i(1280, 720)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	var state := root.get_node("Global")
	var world := current_scene.get_node("World")
	var cell := Vector2i(6, 5)
	world.handle_interaction(cell)
	world.handle_interaction(cell)
	state.tech_unlocked["composite_bow"] = true
	_expect(state.save_game() == OK, "A healthy campaign can save before going to the wilderness.")
	await _move(&"ui_up", 48)
	await _move(&"ui_right", 213)
	_expect(current_scene.name == "Wilderness", "The eastern portal leads into the wilderness.")
	if current_scene.name != "Wilderness":
		quit(1)
		return
	var player := current_scene.get_node("Player") as Node2D
	var dog := current_scene.get_node("Enemy") as Node2D
	var scout := current_scene.get_node("Enemy2") as Node2D
	scout.position = player.position + Vector2(0, 62)
	dog.position = player.position + Vector2(210, 0)
	dog.set_physics_process(false)
	await _wait_for_attack(scout, scout.Attack.SHOT)
	_expect(state.health == 100, "The scout's aim cue precedes damage.")
	var locked_aim: Vector2 = scout.aim
	await _move(&"ui_right", 28)
	_expect(scout.aim == locked_aim, "Moving across the lane does not rotate the scout's aim.")
	await create_timer(0.55).timeout
	_expect(state.health == 100, "Walking out of the marked arrow lane avoids the shot.")
	await _wait_for_attack(scout, scout.Attack.SHOT)
	await create_timer(state.balance.scout_shot_windup + 0.33).timeout
	_expect(state.health == 85, "A scout arrow hits the player for its own damage despite the player's upgraded bow.")
	scout.set_physics_process(false)
	dog.position = player.position + Vector2(22, 0)
	dog.set_physics_process(true)
	await _wait_for_attack(dog, dog.Attack.BITE)
	_expect(state.health == 85, "The bite cue gives the player time to move.")
	await _move(&"ui_up", 18)
	await create_timer(0.38).timeout
	_expect(state.health == 85, "Leaving the marked bite sector avoids damage.")
	await _wait_for_attack(dog, dog.Attack.BITE)
	await create_timer(state.balance.dog_bite_windup + 0.1).timeout
	_expect(state.health == 73, "Staying in the marked bite sector deals damage once.")
	dog.position = player.position + Vector2(65, 0)
	dog.set_physics_process(false)
	var arrow_input := InputEventMouseButton.new()
	arrow_input.button_index = MOUSE_BUTTON_RIGHT
	arrow_input.pressed = true
	arrow_input.position = player.get_canvas_transform() * dog.position
	arrow_input.global_position = arrow_input.position
	root.push_input(arrow_input, true)
	await create_timer(0.4).timeout
	_expect(not is_instance_valid(dog) and state.player_stats.stats["ARCHERY"]["xp"] == 20, "A player arrow still kills the dog and awards archery XP.")
	state.balance.scout_arrow_damage = 100
	scout.position = player.position + Vector2(0, 62)
	scout.set_physics_process(true)
	for frame in range(360):
		if state.outcome == state.Outcome.DEFEAT_COMBAT:
			break
		await process_frame
	await process_frame
	_expect(state.outcome == state.Outcome.DEFEAT_COMBAT and paused, "Lethal damage pauses play and shows defeat.")
	var hud := current_scene.get_node("CampaignHUD")
	var restore := hud.find_child("RestoreCampaign", true, false) as Button
	_expect(restore != null and not restore.disabled, "Defeat offers the last checkpoint.")
	if restore == null:
		quit(1)
		return
	restore.pressed.emit()
	await scene_changed
	_expect(not paused and current_scene.name == "Main" and state.health == 100 and state.active_crops.has(cell),
		"Loading the checkpoint returns alive to the estate and restores the planted crop.")

	var ui := current_scene.get_node("UI")
	state.current_rank = state.Rank.ZHONG_SHI
	state.reputation = state.balance.rank_strip_threshold + 1
	state.days_without_contribution = state.balance.no_contribution_threshold - 1
	ui.sleep_button.pressed.emit()
	await create_timer(1.1).timeout
	_expect(state.current_rank == state.Rank.XIA_SHI and state.outcome == state.Outcome.RUNNING, "Missed tribute first demotes an elevated rank.")
	state.days_without_contribution = state.balance.no_contribution_threshold - 1
	ui.sleep_button.pressed.emit()
	await create_timer(1.1).timeout
	_expect(state.outcome == state.Outcome.DEFEAT_ESTATE and paused, "Continued missed tribute at the lowest rank loses the estate.")
	hud = current_scene.get_node("CampaignHUD")
	var title_button := hud.find_child("ReturnToTitle", true, false) as Button
	title_button.pressed.emit()
	await scene_changed
	_expect(not paused and current_scene.name == "Title", "The defeat menu can return to the title.")
	current_scene.new_button.pressed.emit()
	current_scene.new_confirmation.confirmed.emit()
	await scene_changed
	_expect(state.health == 100 and state.outcome == state.Outcome.RUNNING and state.current_day == 1,
		"A new campaign after defeat starts healthy and ready.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
