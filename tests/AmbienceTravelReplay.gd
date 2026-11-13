extends "res://tests/WestMarketReplay.gd"

const HallReplay := preload("res://tests/HallInteriorReplay.gd")

var legacy := false
var capture_path := ""
var record_slot := 0

func _play() -> void:
	capture_dir = capture_path
	seed(641)
	if await _start_in_rain() and await _rainy_trip() and await _rain_at_the_hall():
		if legacy or await _dry_morning():
			await _market_at_night()
	tree.unload_current_scene()
	for stream in tree.root.get_node("AudioManager").get_children():
		if stream is AudioStreamPlayer:
			stream.stop()
	await tree.process_frame

func _terrain() -> Node:
	var scene := tree.current_scene
	if scene.scene_file_path == state.WEST_MARKET_SCENE:
		return scene.audio
	var path := "World/Landscape" if scene.scene_file_path == state.ESTATE_SCENE else "Landscape"
	return scene.get_node(path).terrain_audio

func _start_in_rain() -> bool:
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	state.current_day = 6
	state.day_progress = 0.24
	if not _expect(state.save_game() == OK and state.load_game() == OK, "Prepare the rainy morning at the estate."):
		return false
	await tree.scene_changed
	await tree.create_timer(0.85).timeout
	var gain: float = _terrain().rain.volume_linear
	print("AMBIENCE_START day=", state.current_day, " rain=", state.has_rain(), " gain=", gain, " paused=", tree.paused)
	return _expect(state.has_rain() and is_equal_approx(gain, 0.39), "Guyu rain is already at the outdoor level.")

func _rainy_trip() -> bool:
	var player: Player = tree.current_scene.get_node("World/Player")
	await _walk(player, [Vector2(66, 36), Vector2(365, 6)])
	await _snapshot("01-estate-rain")
	if not await _rain_cross(&"ui_right", state.WILDERNESS_SCENE, "01-east-gate"):
		return false
	if not await _rain_cross(&"ui_left", state.ESTATE_SCENE, ""):
		return false
	player = tree.current_scene.get_node("World/Player")
	await _walk(player, [Vector2(66, 36), Vector2(-181, 54), Vector2(-181, 0), Vector2(-270, -21)])
	var music := tree.root.get_node("AudioManager")
	var score: AudioStreamPlayer = music.bgm_player
	if not await _rain_cross(&"ui_left", state.WEST_MARKET_SCENE, "02-west-gate"):
		return false
	_expect(music.bgm_player == score, "The estate and market keep their shared seasonal score.")
	var market := tree.current_scene
	if not legacy:
		await Campaign.walk_to_market_exit(tree, market)
	return await _rain_cross(&"ui_right", state.ESTATE_SCENE, "")

func _rain_cross(direction: StringName, destination: String, clip: String) -> bool:
	var source: AudioStreamPlayer = _terrain().rain
	var id := source.get_instance_id()
	var record := _start_recording() if not clip.is_empty() else null
	await tree.create_timer(0.36).timeout
	var position_before := source.get_playback_position()
	var start := Time.get_ticks_msec()
	if not await _cross(direction, destination):
		_finish_recording(record, clip)
		return false
	await tree.process_frame
	var arrived: AudioStreamPlayer = _terrain().rain
	var same_player := arrived.get_instance_id() == id
	var arriving_gain := arrived.volume_linear
	var position_after := arrived.get_playback_position()
	if legacy:
		_expect(not same_player and arriving_gain < 0.35, "The old build replaces the rain player and fades up from a lower level.")
	else:
		_expect(same_player and is_equal_approx(arriving_gain, 0.39), "The same rain stream and level persist through the gate.")
		if DisplayServer.get_name() != "headless":
			var length := arrived.stream.get_length()
			var seconds := (Time.get_ticks_msec() - start) / 1000.0
			var drift := wrapf(position_after - position_before - seconds, -length * 0.5, length * 0.5)
			_expect(arrived.playing and absf(drift) < 0.8, "The rain waveform advances continuously through the crossing.")
	print("AMBIENCE_CROSS destination=", destination.get_file(), " same_player=", same_player,
		" gain=", snappedf(arriving_gain, 0.001), " playback=", snappedf(position_before, 0.01), "->", snappedf(position_after, 0.01))
	await tree.create_timer(0.54).timeout
	_finish_recording(record, clip)
	return not failed

func _rain_at_the_hall() -> bool:
	var hall := HallReplay.new()
	hall.tree = tree
	hall.state = state
	if not await hall._estate():
		return false
	await _walk(hall.player, [Vector2(-181, 0), Vector2(-181, 56), Vector2(34, 57), hall.hall.get_node("Yard").global_position])
	await _stationary_clip("03-rain-outdoors")
	var rain: AudioStreamPlayer = _terrain().rain
	if not _expect(await hall._enter(), "Walk into the hall on the same rainy day."):
		return false
	await tree.create_timer(0.55).timeout
	_expect(_terrain().rain == rain and is_equal_approx(rain.volume_linear, 0.12), "The hall keeps the rain player and lowers its level.")
	var filter: AudioEffectLowPassFilter
	if not legacy:
		var bus := AudioServer.get_bus_index(rain.bus)
		filter = AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
		_expect(AudioServer.get_bus_send(bus) == &"Ambience" and filter != null and filter.cutoff_hz < 2000.0,
			"The indoor rain filter rolls off the treble on the existing ambience volume path.")
	await _snapshot("02-rain-at-the-hall")
	await _stationary_clip("04-rain-indoors")
	if not _expect(await hall._leave(), "Walk back outside through the same door."):
		return false
	await tree.create_timer(0.50).timeout
	_expect(_terrain().rain == rain and is_equal_approx(rain.volume_linear, 0.39), "The outdoor level returns on the same rain player.")
	if filter:
		_expect(filter.cutoff_hz > 18000.0, "The rain returns to its open-air tone outside.")
	return not failed

func _dry_morning() -> bool:
	var rain: AudioStreamPlayer = _terrain().rain
	if not _expect(state.save_game() == OK, "Save on a rainy day for the title transition."):
		return false
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.create_timer(0.55).timeout
	_expect(is_zero_approx(rain.volume_linear) and not rain.playing, "Returning to the title fades out the world's rain.")
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	var ui := tree.current_scene.get_node("UI")
	await _button(ui.sleep_button)
	await tree.create_timer(1.22).timeout
	return _expect(state.current_day == 7 and not state.has_rain() and is_zero_approx(rain.volume_linear) and not rain.playing,
		"The normal overnight clears the rain for the dry summer morning.")

func _market_at_night() -> void:
	tree.change_scene_to_file(state.WEST_MARKET_SCENE)
	await tree.scene_changed
	var market := tree.current_scene
	if legacy:
		await _walk(market.player, [Vector2(-174, 34)])
	else:
		await Campaign.walk_market_to(tree, market, Vector2(-171, 27))
	state.current_day = 7
	await _time_at(1.0)
	await tree.create_timer(0.55).timeout
	var summer: float = _terrain().crickets.volume_linear
	state.current_day = 22
	await _time_at(1.0)
	await tree.create_timer(0.55).timeout
	var winter: float = _terrain().crickets.volume_linear
	_expect(summer > 0.12 and (winter > 0.12 if legacy else is_zero_approx(winter)),
		"The test position has summer insects. Only the old market carries them into winter.")
	print("AMBIENCE_SEASONS foot=", market.player.position, " summer=", snappedf(summer, 0.001), " winter=", snappedf(winter, 0.001))

func _start_recording() -> AudioEffectRecord:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return null
	var bus := AudioServer.get_bus_index(&"Ambience")
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	record_slot = AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus, record)
	record.set_recording_active(true)
	return record

func _finish_recording(record: AudioEffectRecord, clip: String) -> void:
	if not record:
		return
	record.set_recording_active(false)
	var wave := record.get_recording()
	AudioServer.remove_bus_effect(AudioServer.get_bus_index(&"Ambience"), record_slot)
	if _expect(wave != null and wave.get_length() > 0.8, "Record the actual ambience bus for " + clip):
		_expect(wave.save_to_wav(capture_dir.path_join(clip)) == OK, "Write the recording for " + clip)
		print("AMBIENCE_RECORD ", clip, " seconds=", snappedf(wave.get_length(), 0.01))

func _stationary_clip(clip: String) -> void:
	var record := _start_recording()
	if record:
		await tree.create_timer(1.8).timeout
		_finish_recording(record, clip)
