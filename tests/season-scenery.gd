extends SceneTree

const Campaign := preload("res://tests/CampaignReplay.gd")
const TerrainAudio := preload("res://scripts/TerrainAudio.gd")
const ORCHARD_FRAMES := [Vector2(0, 48), Vector2(48, 0), Vector2(48, 48), Vector2(144, 48)]
const ORCHARD_FOOT := Vector2(52, -17)

var failed := false
var state: Node

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error(detail)

func _tree_at(landscape: Node2D, position: Vector2) -> Sprite2D:
	for sprite: Sprite2D in landscape.scenery:
		if sprite.position == position:
			return sprite
	return null

func _sleep_into(season: int) -> void:
	# Skip the intervening calendar days, then let normal sleep update the world.
	state.current_day = season * 6 * state.balance.days_per_solar_term
	current_scene.get_node("UI").sleep_button.pressed.emit()
	await create_timer(1.15).timeout

func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for step in frames:
		await physics_frame
	Input.action_release(action)
	await Campaign.wait_for_map_change(self)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run season-scenery with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	seed(1991)
	state = root.get_node("Global")
	change_scene_to_file("res://scenes/Title.tscn")
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	await process_frame
	state.balance.raid_first_day = 10000
	var estate := current_scene.get_node("World/Landscape")
	var oak := _tree_at(estate, Vector2(-112, -17))
	var orchard := _tree_at(estate, ORCHARD_FOOT)
	if oak == null or orchard == null:
		push_error("The estate's spring trees must be present.")
		quit(1)
		return
	var oak_anchor := oak.offset
	var orchard_anchor := orchard.offset
	_expect(not estate.ground_cover.ground_marks.is_empty() and not estate.ground_cover.frost_marks.is_empty(),
		"The estate has both warm-season marks and winter frost details.")
	for season in 4:
		if season > 0:
			await _sleep_into(season)
		_expect(estate.season == season and oak.texture.region.position == Vector2(season * 48, 0)
			and orchard.texture.region.position == ORCHARD_FRAMES[season], "Sleeping updates the living trees for season %d." % season)
		_expect(oak.offset == oak_anchor and orchard.offset == orchard_anchor,
			"Every seasonal tree uses the same ground anchor.")
	var snowy_point := Vector2(190, 201)
	_expect(estate._surface_at(snowy_point) == TerrainAudio.Surface.SNOW, "The lower winter field margin has snow.")
	var tile_map := current_scene.get_node("World/TileMapLayer") as TileMapLayer
	var channel_cell := tile_map.local_to_map(tile_map.to_local(estate.to_global(snowy_point)))
	var channel_center: Vector2 = estate.to_local(tile_map.to_global(tile_map.map_to_local(channel_cell)))
	state.tech_unlocked["irrigation"] = true
	state.money = state.channel_cost()
	_expect(estate._surface_at(channel_center) == TerrainAudio.Surface.SNOW, "The canal site is snowy before construction.")
	_expect(state.build_channel(channel_cell) == state.ChannelSite.AVAILABLE, "The fixture can build a canal through a drift.")
	_expect(estate._surface_at(channel_center) != TerrainAudio.Surface.SNOW,
		"A canal built through the drift keeps its own ground surface.")
	_expect(state.save_game() == OK and state.load_game() == OK, "A winter day saves and reloads normally.")
	await scene_changed
	await process_frame
	estate = current_scene.get_node("World/Landscape")
	_expect(estate.season == 3 and estate.ground_cover.has_snow(snowy_point), "Loading restores the seasonal scene at the same location.")
	await _move(&"ui_up", 48)
	await _move(&"ui_right", 249)
	if current_scene.name != "Wilderness":
		push_error("Walking through East Gate must enter Bamboo Ravine.")
		quit(1)
		return
	await process_frame
	var walker := current_scene.get_node("Player") as Node2D
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var landscape := current_scene.get_node("Landscape")
	var terrain := landscape.terrain_audio as TerrainAudio
	var willow := _tree_at(landscape, Vector2(225, -169))
	_expect(willow != null and willow.texture.atlas.resource_path.get_file() == "winter-willow.svg",
		"Winter replaces the green willow silhouette with bare branches.")
	var snow_samples: Dictionary[String, bool] = {}
	walker.footstep.connect(func(at: Vector2) -> void:
		if absf(at.y - 97) < 3.0 and at.x >= -253 and at.x <= -208:
			snow_samples[terrain.footsteps.stream.resource_path.get_file()] = true
	)
	await Campaign.walk_to(self, walker, Vector2(-251, 97))
	await Campaign.walk_to(self, walker, Vector2(-210, 97))
	_expect(snow_samples.size() == 2 and snow_samples.has("snow-1.wav") and snow_samples.has("snow-2.wav")
		and not landscape.snow_footprints.prints.is_empty(), "Actual movement across snow plays two samples and leaves tracks.")
	await create_timer(4.0).timeout
	_expect(landscape.snow_footprints.prints.is_empty(), "Tracks fade after standing still.")
	await Campaign.walk_to(self, walker, Vector2(109, 36))
	await Campaign.walk_to(self, walker, Vector2(155, 36))
	_expect(terrain.footsteps.stream.resource_path.get_file().begins_with("plank-"), "The winter bridge still sounds like wood.")
	await Campaign.walk_to(self, walker, Vector2(226, 36))
	await Campaign.walk_ravine_to(self, current_scene, RavineLayout.FORD_EAST)
	await Campaign.walk_to(self, walker, RavineLayout.FORD)
	_expect(terrain.footsteps.stream.resource_path.get_file().begins_with("water-"), "The winter ford still sounds like water.")
	await Campaign.walk_to_ravine_exit(self, current_scene)
	await _move(&"ui_left", 24)
	if current_scene.name != "Main":
		push_error("The winter path home must remain open.")
		quit(1)
		return
	await _sleep_into(4)
	estate = current_scene.get_node("World/Landscape")
	_expect(estate.season == 0 and _tree_at(estate, ORCHARD_FOOT).texture.region.position == ORCHARD_FRAMES[0],
		"The next year returns the orchard to bloom.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
