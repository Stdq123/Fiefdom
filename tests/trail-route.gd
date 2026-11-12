extends SceneTree

const Campaign := preload("res://tests/CampaignReplay.gd")

var failed := false
var state: Node
var walker: Node2D

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for step in frames:
		await physics_frame
	Input.action_release(action)
	await Campaign.wait_for_map_change(self)

func _walk(destination: Vector2) -> void:
	await Campaign.walk_to(self, walker, destination)

func _gather() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	key.pressed = true
	root.push_input(key, true)
	await process_frame

func _enter_trail() -> bool:
	var estate_player := current_scene.get_node("World/Player") as Node2D
	await Campaign.walk_to(self, estate_player, Vector2(359, 4))
	await _move(&"ui_right", 36)
	if current_scene.name != "Wilderness":
		push_error("Walking through East Gate must enter Bamboo Ravine.")
		quit(1)
		return false
	walker = current_scene.get_node("Player")
	# Combat is covered by combat-recovery. Keep these actors in place while measuring routes.
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	_expect(walker.position.x < -120 and walker.position.x > -179, "The trail opens just inside its west gate.")
	return true

func _return_home() -> bool:
	await _walk(Vector2(-161, 3))
	await _move(&"ui_left", 24)
	if current_scene.name != "Main":
		push_error("The trail's west gate must return to the estate.")
		quit(1)
		return false
	walker = current_scene.get_node("World/Player")
	_expect(walker.position.x > 310 and walker.position.x < 381, "The return arrives inside East Gate without looping.")
	return true

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run trail-route with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	seed(650)
	state = root.get_node("Global")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	var planted := Vector2i(6, 5)
	for action in 3:
		current_scene.get_node("World").handle_interaction(planted)
	if not await _enter_trail():
		return

	var terrain := current_scene.get_node("Landscape/TerrainAudio")
	_expect(is_zero_approx(terrain.creek.volume_linear) and is_zero_approx(terrain.rain.volume_linear),
		"No creek or rain is audible at the dry west entrance.")
	var starting_food: int = state.food_storage
	await _walk(Vector2(-59, -70))
	_expect(terrain.birds.volume_linear > 0.2 and is_zero_approx(terrain.creek.volume_linear),
		"The dry berry grove brings in birdsong before the creek comes into range.")
	await _gather()
	_expect(state.food_storage == starting_food + state.balance.wild_food_yield, "The west-side berry grove still provides food.")
	await _walk(Vector2(89, -44))
	await _move(&"ui_right", 63)
	_expect(walker.position.x < 125, "The deep creek stops walking between the crossings.")
	_expect(terrain.creek.volume_linear > 0.1, "The creek gains volume near its bank.")
	var steps_at_bank: int = terrain.step_variant
	await _move(&"ui_right", 25)
	_expect(terrain.step_variant == steps_at_bank, "Pushing against the bank does not produce steps.")

	await _walk(Vector2(109, 36))
	await _walk(Vector2(151, 36))
	_expect(terrain.footsteps.stream.resource_path.get_file().begins_with("plank-"), "Walking across the bridge plays wood steps.")
	await _walk(Vector2(208, 36))
	_expect(walker.position.x > 202, "The bridge deck connects both banks.")
	await _walk(Vector2(305, -24))
	state.hurt_player(17)
	var injured: int = state.health
	await _gather()
	_expect(state.health == injured and "今日" in current_scene.get_node("WildHerbs").hint.text, "Food and medicine share the daily gathering slot.")

	await _walk(Vector2(234, 119))
	await _walk(Vector2(165, 119))
	_expect(terrain.footsteps.stream.resource_path.get_file().begins_with("water-"), "Wading in the ford plays water steps.")
	await _walk(Vector2(117, 119))
	_expect(walker.position.x < 122, "The shallow crossing provides an alternate way back.")
	if not await _return_home():
		return
	_expect(not is_instance_valid(terrain), "Leaving Bamboo Ravine releases its audio players.")
	_expect(state.active_crops.has(planted) and state.active_crops[planted]["watered"], "A day trip preserves the farm.")
	current_scene.get_node("UI").sleep_button.pressed.emit()
	await create_timer(1.15).timeout
	if not await _enter_trail():
		return

	await _walk(Vector2(125, 119))
	await _walk(Vector2(233, 119))
	_expect(walker.position.x > 225, "The ford also works from west to east.")
	await _walk(Vector2(305, -24))
	var full_health: int = state.health
	await _gather()
	_expect(full_health == state.balance.player_max_health and state.last_forage_day != state.current_day,
		"Medicine at full health does not spend the day's opportunity.")
	state.hurt_player(27)
	injured = state.health
	await _gather()
	_expect(state.health == mini(injured + state.balance.wild_herb_healing, state.balance.player_max_health)
		and state.last_forage_day == state.current_day, "Picking medicinal leaves heals and spends the slot.")

	await _walk(Vector2(201, 36))
	await _walk(Vector2(111, 36))
	if not await _return_home():
		return
	var saved_health: int = state.health
	var saved_day: int = state.current_day
	_expect(state.save_game() == OK and state.load_game() == OK, "The day after a trail trip saves and reloads.")
	await scene_changed
	_expect(state.current_day == saved_day and state.last_forage_day == saved_day and state.health == saved_health
		and state.active_crops.has(planted) and state.active_crops[planted]["age"] == 1,
		"The save preserves the gathering limit, health and crop growth.")

	terrain = current_scene.get_node("World/Landscape/TerrainAudio")
	for night in range(state.SOLAR_TERMS.size() * state.balance.days_per_solar_term):
		if state.has_rain():
			break
		current_scene.get_node("UI").sleep_button.pressed.emit()
		await create_timer(1.15).timeout
	_expect(state.has_rain() and terrain.rain.volume_linear > 0.1 and is_zero_approx(terrain.creek.volume_linear),
		"Rain reaches the estate after sleeping into the right solar term.")
	if not await _enter_trail():
		return
	terrain = current_scene.get_node("Landscape/TerrainAudio")
	await _walk(Vector2(-59, -70))
	_expect(is_zero_approx(terrain.birds.volume_linear) and terrain.rain.volume_linear > 0.1,
		"In rain, the grove layers rain in place of the dry-weather birdsong.")
	if not await _return_home():
		return
	terrain = current_scene.get_node("World/Landscape/TerrainAudio")
	current_scene.get_node("UI").sleep_button.pressed.emit()
	await create_timer(1.15).timeout
	_expect(not state.has_rain() and is_zero_approx(terrain.rain.volume_linear), "The rain fades away after the weather clears.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
