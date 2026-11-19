extends SceneTree

var tree: SceneTree
var state: Node
var terrain: Node
var prefs: Node
var destination := ""
var failed := false

func _initialize() -> void:
	_review.call_deferred(self)

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout

func _record(name: String, duration := 0.7) -> float:
	if destination.is_empty():
		return 0.0
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	await tree.create_timer(duration, true, false, true).timeout
	record.set_recording_active(false)
	var wave := record.get_recording()
	AudioServer.remove_bus_effect(0, slot)
	_expect(wave != null and wave.get_length() > duration * 0.7, "The mixer supplies enough samples for " + name)
	if wave == null:
		return 0.0
	var samples := wave.data
	var energy := 0.0
	var peak := 0.0
	for offset in range(0, samples.size(), 2):
		var sample := float(samples.decode_s16(offset)) / 32768.0
		energy += sample * sample
		peak = maxf(peak, absf(sample))
	var rms := sqrt(energy / maxf(1.0, samples.size() / 2.0))
	_expect(wave.save_to_wav(destination.path_join(name)) == OK and peak < 0.55, "Save a mix with headroom for " + name)
	print("SEASONAL_AMBIENCE_MIX ", name, " rms=", rms, " peak=", peak, " seconds=", wave.get_length())
	return rms

func _same_wind_phase() -> void:
	if not destination.is_empty():
		terrain.wind.seek(5.0)
		await _wait(0.07)

func _mount(path: String, emitter: NodePath) -> Node:
	if tree.change_scene_to_file(path) != OK:
		_expect(false, "Cannot mount the paused sample scene " + path)
		return null
	await tree.scene_changed
	for frame in 5:
		await tree.process_frame
	return tree.current_scene.get_node(emitter)

func _sample(landscape: Node2D, position: Vector2) -> void:
	var listener: Node2D = landscape.player
	listener.global_position = landscape.to_global(position)
	landscape._refresh_ambience()
	await _wait(0.78)

func _day_for(term: String) -> int:
	return 1 + state.SOLAR_TERMS.find(term) * state.balance.days_per_solar_term

func _estate_snapshot() -> Array:
	return [state.current_day, state.day_progress, state.money, state.food_storage, state.current_stamina,
		state.king_storage, state.active_crops.duplicate(true), state.retainers.size(), state.saved_games().size()]

func _check_outdoors(landscape: Node2D, settings: Control) -> float:
	var before := _estate_snapshot()
	await _sample(landscape, Vector2(52, 32))
	_expect(terrain.birds.volume_linear > 0.20 and is_equal_approx(terrain.wind.volume_linear, 0.115),
		"The first courtyard has birds and a light spring wind.")
	if not destination.is_empty():
		terrain.birds.seek(2.4)
		await _same_wind_phase()
	var yard := await _record("01-hall-yard")
	await _sample(landscape, Vector2(185, 160))
	_expect(is_zero_approx(terrain.birds.volume_linear), "The courtyard and pavilion birds fade away at the field road.")
	await _same_wind_phase()
	var open := await _record("02-open-field")
	if not destination.is_empty():
		_expect(open > 0.006 and open < 0.05 and yard > open, "The courtyard gains a natural sound and the field keeps a quiet bed.")
	var slider := settings.find_child("AmbienceVolume", true, false) as HSlider
	_expect(slider != null, "The normal settings panel contains the environment slider.")
	if slider:
		slider.value = 0.25
		await _same_wind_phase()
		var quarter := await _record("03-open-quarter")
		slider.value = 0.0
		await _same_wind_phase()
		var silenced := await _record("04-open-muted")
		if not destination.is_empty():
			_expect(absf(quarter / maxf(0.0001, open) - 0.25) < 0.035 and silenced == 0.0,
				"The ordinary environment slider controls the mixed wind and mutes it at zero.")
			terrain.wind.seek(35.78)
		slider.value = 1.0
		await _record("05-wind-loop")
		if not destination.is_empty():
			_expect(terrain.wind.playing and terrain.wind.get_playback_position() < 1.0, "The exported wind crosses the end of its loop.")
	await _sample(landscape, Vector2(184, 421))
	_expect(terrain.birds.volume_linear > 0.19, "The tree beside the south pavilion has its own birds.")
	await _record("06-south-pavilion")
	_expect(before == _estate_snapshot(), "Sampling the wind and birds does not advance the estate.")
	return open

func _check_weather(landscape: Node2D) -> void:
	state.current_day = _day_for("立冬")
	await _sample(landscape, Vector2(52, 32))
	_expect(is_zero_approx(terrain.birds.volume_linear) and is_equal_approx(terrain.wind.volume_linear, 0.175),
		"The dry winter wind is stronger and winter trees are quiet.")
	await _same_wind_phase()
	await _record("07-winter")

	state.current_day = _day_for("立夏")
	state.day_progress = 0.90
	await _sample(landscape, Vector2(77, 397))
	_expect(is_zero_approx(terrain.birds.volume_linear) and terrain.crickets.volume_linear > 0.30
		and is_equal_approx(terrain.wind.volume_linear, 0.08), "A clear summer evening keeps crickets and a softer wind.")
	await _record("08-summer-evening")

	state.current_day = _day_for(state.balance.rain_solar_term)
	state.day_progress = 0.12
	await _sample(landscape, Vector2(211, 410))
	_expect(is_equal_approx(terrain.rain.volume_linear, 0.39) and is_equal_approx(terrain.wind.volume_linear, 0.0805)
		and is_zero_approx(terrain.birds.volume_linear), "Open rain turns down the wind and hushes the birds.")
	var wet := await _record("09-open-rain")
	await _sample(landscape, Vector2(260, 396))
	_expect(is_equal_approx(terrain.rain.volume_linear, 0.12) and is_equal_approx(terrain.wind.volume_linear, 0.01932)
		and is_equal_approx(terrain._rain_filter.cutoff_hz, 1500.0), "The rain shelter softens and filters wind and rain together.")
	var eaves := await _record("10-under-eaves")
	if not destination.is_empty():
		_expect(eaves > 0.0 and eaves < wet * 0.48, "The real mix under the eaves is quieter than open rain.")

func _check_hall(field_rms: float) -> void:
	state.current_day = 1
	state.day_progress = 0.12
	state.estate_room = state.EstateRoom.HALL
	var land := await _mount(state.ESTATE_SCENE, ^"World/Landscape")
	if land == null:
		return
	var before := _estate_snapshot()
	land._refresh_ambience()
	await _wait(0.78)
	_expect(tree.current_scene.get_node("World/HallInterior").visible and is_zero_approx(terrain.birds.volume_linear)
		and is_equal_approx(terrain.wind.volume_linear, 0.0276), "The hall has quiet wind through the walls and trees stay outside.")
	await _same_wind_phase()
	var indoors := await _record("11-hall")
	if not destination.is_empty():
		_expect(indoors < field_rms * 0.30 and indoors > field_rms * 0.10, "The room leaves a soft, filtered trace of the field wind.")
	_expect(before == _estate_snapshot(), "The listening sample leaves the room and the estate intact.")

func _check_maps() -> void:
	state.estate_room = state.EstateRoom.OUTDOORS
	var wind := terrain.wind as AudioStreamPlayer
	await _same_wind_phase()
	var before := wind.get_playback_position()
	var cases := [
		[state.WEST_ROAD_SCENE, ^".", 0.13225, "12-creek-road"],
		[state.WEST_MARKET_SCENE, ^".", 0.0828, "13-west-market"],
		[state.WILDERNESS_SCENE, ^"Landscape", 0.0897, "14-ravine"],
	]
	for item in cases:
		var source := await _mount(item[0], item[1])
		if source == null:
			return
		var snapshot := _estate_snapshot()
		source._refresh_ambience()
		await _wait(0.78)
		_expect(terrain.wind == wind and is_equal_approx(wind.volume_linear, item[2]), "Use the right wind exposure at " + item[3])
		var position := wind.get_playback_position()
		if not destination.is_empty():
			_expect(wind.playing and position > before, "The wind carries the previous playback into " + item[3])
		before = position
		print("SEASONAL_AMBIENCE_MAP ", item[3], " wind_gain=", wind.volume_linear, " playhead=", position)
		await _record(item[3])
		_expect(snapshot == _estate_snapshot(), "The ambient mix does not advance a mounted map.")

func _review(scenario: SceneTree) -> void:
	tree = scenario
	var profile := OS.get_user_data_dir()
	if not ("fiefdom-smoke-" in profile or "fiefdom-seasonal-ambience-" in profile):
		push_error("Use an isolated profile for the seasonal ambience check.")
		tree.quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		destination = args[0]
	tree.paused = true
	state = tree.root.get_node("Global")
	prefs = tree.root.get_node("Preferences")
	terrain = tree.root.get_node("AudioManager").terrain_audio
	for bus in [&"Music", &"SFX"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), true)
	_expect(prefs.set_ambience_volume(1.0) == OK, "Use the full environment channel for the reference.")
	var stream := terrain.wind.stream as AudioStreamWAV
	_expect(stream != null and is_equal_approx(stream.get_length(), 36.0) and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
		and AudioServer.get_bus_send(AudioServer.get_bus_index(terrain.wind.bus)) == &"Ambience",
		"The packaged resource supplies a looping wind on the existing environment path.")
	state.current_day = 1
	state.day_progress = 0.12
	var landscape := await _mount(state.ESTATE_SCENE, ^"World/Landscape") as Node2D
	if landscape == null:
		tree.quit(1)
		return
	var settings: Control = tree.current_scene.get_node("UI").panel_manager.settings_panel_instance
	var field_rms := await _check_outdoors(landscape, settings)
	await _check_weather(landscape)
	await _check_hall(field_rms)
	await _check_maps()
	var title := await _mount(state.TITLE_SCENE, ^".")
	_expect(title != null, "Return to the title presentation.")
	await _wait(0.85)
	_expect(is_zero_approx(terrain.wind.volume_linear) and not terrain.wind.playing, "The outdoor wind fades out at the title.")
	_expect(is_zero_approx(await _record("15-title-after-travel")), "The title receives no outdoor residue.")
	_expect(tree.paused and state.saved_games().is_empty(), "No sample runs the estate or writes a save.")
	if not failed:
		print("SEASONAL_AMBIENCE_REVIEW_OK paused=true saves=0 window=", tree.root.size)
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
