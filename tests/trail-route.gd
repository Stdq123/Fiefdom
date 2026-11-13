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

func _walk_trail(destination: Vector2) -> void:
	await Campaign.walk_ravine_to(self, current_scene, destination)

func _gather(code: Key = KEY_E, pack := false) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.shift_pressed = pack
		key.pressed = pressed
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
	_expect(walker.position.distance_to(current_scene.get_node("WestArrival").position) < 3.0,
		"The trail opens just inside its west gate.")
	return true

func _return_home() -> bool:
	await Campaign.walk_to_ravine_exit(self, current_scene)
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

	var terrain: Node = root.get_node("AudioManager").terrain_audio
	_expect(is_zero_approx(terrain.creek.volume_linear) and is_zero_approx(terrain.rain.volume_linear),
		"No creek or rain is audible at the dry west entrance.")
	var starting_food: int = state.food_storage
	var clock: float = state.day_progress
	await _walk_trail(RavineLayout.FRUIT + Vector2(-8, 16))
	var travel_seconds: float = (state.day_progress - clock) * state.balance.daylight_seconds
	_expect(travel_seconds > 2.8, "The grove takes a distinct stretch of forest trail from the entrance.")
	print("RAVINE_GROVE_WALK seconds=", snappedf(travel_seconds, 0.01), " foot=", walker.position)
	_expect(terrain.birds.volume_linear > 0.2 and is_zero_approx(terrain.creek.volume_linear),
		"The dry berry grove brings in birdsong before the creek comes into range.")
	await _gather()
	_expect(state.food_storage == starting_food + state.balance.wild_food_yield, "The west-side berry grove still provides food.")
	await _walk_trail(Vector2(89, -44))
	await _move(&"ui_right", 63)
	_expect(walker.position.x < 125, "The deep creek stops walking between the crossings.")
	_expect(terrain.creek.volume_linear > 0.1, "The creek gains volume near its bank.")
	var steps_at_bank: int = terrain.step_variant
	await _move(&"ui_right", 25)
	_expect(terrain.step_variant == steps_at_bank, "Pushing against the bank does not produce steps.")

	await _walk_trail(Vector2(109, 36))
	await _walk(Vector2(151, 36))
	_expect(terrain.footsteps.stream.resource_path.get_file().begins_with("plank-"), "Walking across the bridge plays wood steps.")
	await _walk(Vector2(208, 36))
	_expect(walker.position.x > 202, "The bridge deck connects both banks.")
	await _walk_trail(RavineLayout.HERBS + Vector2(0, 17))
	state.hurt_player(17)
	var injured: int = state.health
	await _gather()
	_expect(state.health == injured and "今日" in current_scene.get_node("WildHerbs").hint.text, "Food and medicine share the daily gathering slot.")
	await _gather(KEY_E, true)
	_expect(not state.wild_herbs_packed, "The packed dose shares the berries' daily gathering slot.")

	await _walk_trail(RavineLayout.FORD_EAST)
	await _walk(RavineLayout.FORD)
	_expect(terrain.footsteps.stream.resource_path.get_file().begins_with("water-"), "Wading in the ford plays water steps.")
	await _walk(RavineLayout.FORD_WEST)
	_expect(walker.position.distance_to(RavineLayout.FORD_WEST) < 3.0, "The shallow crossing provides an alternate way back.")
	if not await _return_home():
		return
	await create_timer(0.65).timeout
	_expect(is_zero_approx(terrain.creek.volume_linear) and is_zero_approx(terrain.birds.volume_linear),
		"Leaving Bamboo Ravine fades the local creek and birds on the shared players.")
	_expect(state.active_crops.has(planted) and state.active_crops[planted]["watered"], "A day trip preserves the farm.")
	current_scene.get_node("UI").sleep_button.pressed.emit()
	await create_timer(1.15).timeout
	if not await _enter_trail():
		return

	await _walk_trail(RavineLayout.FORD_WEST)
	await _walk(RavineLayout.FORD_EAST)
	_expect(walker.position.distance_to(RavineLayout.FORD_EAST) < 3.0, "The ford also works from west to east.")
	await _walk_trail(RavineLayout.HERBS + Vector2(0, 17))
	var full_health: int = state.health
	await _gather()
	_expect(full_health == state.balance.player_max_health and state.last_forage_day != state.current_day,
		"Medicine at full health does not spend the day's opportunity.")
	state.hurt_player(27)
	injured = state.health
	await _gather()
	_expect(state.health == mini(injured + state.balance.wild_herb_healing, state.balance.player_max_health)
		and state.last_forage_day == state.current_day, "Picking medicinal leaves heals and spends the slot.")

	if not await _return_home():
		return
	var saved_health: int = state.health
	var saved_day: int = state.current_day
	_expect(state.save_game() == OK and state.load_game() == OK, "The day after a trail trip saves and reloads.")
	await scene_changed
	_expect(state.current_day == saved_day and state.last_forage_day == saved_day and state.last_fishing_day == 0
		and state.health == saved_health
		and state.active_crops.has(planted) and state.active_crops[planted]["age"] == 1,
		"The save preserves the gathering limit, health and crop growth.")

	for night in range(state.SOLAR_TERMS.size() * state.balance.days_per_solar_term):
		if state.has_rain():
			break
		current_scene.get_node("UI").sleep_button.pressed.emit()
		await create_timer(1.15).timeout
	_expect(state.has_rain() and terrain.rain.volume_linear > 0.1 and is_zero_approx(terrain.creek.volume_linear),
		"Rain reaches the estate after sleeping into the right solar term.")
	if not await _enter_trail():
		return
	await _walk_trail(RavineLayout.HERBS + Vector2(0, 17))
	var herbs: Node2D = current_scene.get_node("WildHerbs")
	var preferences := root.get_node("Preferences")
	_expect(state.health == full_health and herbs.pack_button.visible,
		"The nearby herb patch offers one dose to a healthy player.")
	_expect(preferences.set_binding(&"interact", KEY_G) == OK and "Shift+G" in herbs.pack_button.text,
		"The carry shortcut follows the remapped interact key.")
	await _gather(KEY_E, true)
	_expect(not state.wild_herbs_packed and state.last_forage_day != state.current_day,
		"An old interact binding no longer packs herbs.")
	await _gather(KEY_G, true)
	_expect(state.wild_herbs_packed and state.health == full_health and state.last_forage_day == state.current_day
		and not herbs.pack_button.visible, "Packing a dose preserves health and spends the shared daily chance.")
	_expect(preferences.set_binding(&"interact", KEY_E) == OK, "Restore the default interaction for the rest of the replay.")
	await _walk_trail(RavineLayout.FRUIT + Vector2(-8, 16))
	_expect(is_zero_approx(terrain.birds.volume_linear) and terrain.rain.volume_linear > 0.1,
		"In rain, the grove layers rain in place of the dry-weather birdsong.")
	var packed_food: int = state.food_storage
	await _gather()
	_expect(state.food_storage == packed_food, "Packing herbs also blocks a berry harvest that day.")
	if not await _return_home():
		return
	current_scene.get_node("UI").sleep_button.pressed.emit()
	await create_timer(1.15).timeout
	_expect(not state.has_rain() and is_zero_approx(terrain.rain.volume_linear), "The rain fades away after the weather clears.")
	var forage_day: int = state.last_forage_day
	_expect(state.save_game() == OK and state.load_game() == OK, "A packed remedy saves after returning and sleeping.")
	await scene_changed
	_expect(state.wild_herbs_packed and state.last_forage_day == forage_day and state.current_day > forage_day,
		"Reload restores the remedy alongside the refreshed daily allowance.")
	await _gather(KEY_I)
	var bag: Control = current_scene.get_node("CampaignHUD").backpack
	if is_instance_valid(bag) and bag.herb_pouch.visible:
		bag.use_herbs_button.pressed.emit()
		_expect(state.wild_herbs_packed and "气血充足" in bag.herb_notice.text,
			"Using the pouch at full health keeps the dose.")
		state.hurt_player(11)
		bag.use_herbs_button.pressed.emit()
		_expect(not state.wild_herbs_packed and state.health == full_health and state.last_forage_day == forage_day
			and not bag.herb_pouch.visible and "11" in bag.herb_notice.text,
			"Using carried herbs heals only the missing health without spending the next day's forage.")
		await _gather(KEY_ESCAPE)
	else:
		_expect(false, "The estate backpack shows the loaded herb dose.")
	var legacy_path := "user://before-wild-herbs.json"
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.manual_save_path()))
	snapshot.erase("wild_herbs_packed")
	var legacy := FileAccess.open(legacy_path, FileAccess.WRITE)
	if legacy != null:
		legacy.store_string(JSON.stringify(snapshot))
		legacy.close()
		state.wild_herbs_packed = true
		if state.load_game(legacy_path) == OK:
			await scene_changed
			_expect(not state.wild_herbs_packed and state.last_forage_day == forage_day,
				"An earlier save defaults to an empty remedy slot and preserves its forage day.")
		else:
			_expect(false, "The earlier save still loads.")
	else:
		_expect(false, "Write the earlier save fixture.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
