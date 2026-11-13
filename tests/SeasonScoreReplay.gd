extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const SEASONS := ["spring", "summer", "autumn", "winter", "spring"]
const MUSIC_DIR := "res://assets/audio/music/"

var tree: SceneTree
var state: Node
var audio: Node
var capture_dir := ""
var rendered := false
var failures := 0

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		push_error(message)
	return condition

func _wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout

func _button(button: Button) -> void:
	await tree.process_frame
	if not _expect(button.is_visible_in_tree() and not button.disabled, "Use the visible " + button.text + " button."):
		return
	await _click(button.get_global_rect().get_center())
	await tree.process_frame

func _click(point: Vector2) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.global_position = point
		click.pressed = pressed
		tree.root.push_input(click, true)
		await tree.process_frame

func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for frame in frames:
		await tree.physics_frame
	Input.action_release(action)
	await Campaign.wait_for_map_change(tree)

func _check_cue(cue: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = audio.bgm_player
	if not _expect(player != null, "The scene should choose the " + cue + " cue."):
		return null
	var track := player.stream as AudioStreamOggVorbis
	if not _expect(track != null and track.resource_path == MUSIC_DIR + "score-" + cue + ".ogg",
			"Use the imported " + cue + " arrangement."):
		return null
	var minimum := 100.0 if cue == "title" else 180.0
	_expect(track.loop and track.loop_offset == 0.0 and track.get_length() >= minimum and track.get_length() <= 300.0,
		"The complete " + cue + " arrangement loops at its beginning.")
	_expect(player.bus == &"Music" and (not rendered or player.playing), "The chosen cue plays through Music.")
	print("SEASON_SCORE_CUE ", cue, " day=", state.current_day, " seconds=", snappedf(track.get_length(), 0.01),
		" position=", snappedf(player.get_playback_position(), 0.01))
	return player

func _record_bus(name: String, bus_name: StringName, seconds: float) -> void:
	if not rendered:
		return
	var bus := AudioServer.get_bus_index(bus_name)
	var slot := AudioServer.get_bus_effect_count(bus)
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, record)
	record.set_recording_active(true)
	await _wait(seconds)
	record.set_recording_active(false)
	var wave := record.get_recording()
	AudioServer.remove_bus_effect(bus, slot)
	if not _expect(wave != null, "Receive mixed audio for " + name):
		return
	var samples := wave.data
	var peak := 0
	for offset in range(0, samples.size() - 1, 2):
		peak = maxi(peak, absi(samples.decode_s16(offset)))
	_expect(wave.get_length() >= seconds * 0.75 and peak > 230 and peak < 32000, "Hear unclipped live audio for " + name)
	if not capture_dir.is_empty():
		_expect(wave.save_to_wav(capture_dir.path_join(name)) == OK, "Save the live mix for " + name)
	print("SEASON_SCORE_AUDIO ", name, " bus=", bus_name, " seconds=", snappedf(wave.get_length(), 0.01),
		" peak_dbfs=", snappedf(linear_to_db(peak / 32768.0), 0.1))

func _night() -> void:
	var sleep: Button = tree.current_scene.get_node("UI").sleep_button
	await _button(sleep)
	Campaign.confirm_optional_tribute_warning(tree.current_scene.get_node("UI"))
	await _wait(1.07)

func _check_fade(previous: AudioStreamPlayer, next: AudioStreamPlayer) -> void:
	if previous == null or next == null:
		return
	_expect(previous != next and previous.stream != null and previous.volume_linear > 0.0
		and next.volume_linear > 0.0, "The two cues overlap while fading.")
	if rendered:
		_expect(previous.playing and next.playing, "Both sides of the transition are actually playing.")
	await _wait(1.52)
	_expect(previous.stream == null and not previous.playing and next.volume_linear > 0.3,
		"The outgoing cue stops after the incoming cue reaches its normal level.")

func _seasons(spring: AudioStreamPlayer) -> void:
	var position := spring.get_playback_position()
	await _night()
	_expect(state.current_day == 2 and audio.bgm_player == spring and spring.stream != null,
		"An ordinary dawn keeps the same playback.")
	if rendered:
		_expect(spring.get_playback_position() > position + 0.7, "An ordinary dawn continues from the existing position.")
	var days: int = state.balance.days_per_solar_term * SeasonOrders.TERMS_PER_SEASON
	# Jump to each season's final day, then use the actual sleep button.
	for index in range(1, SEASONS.size()):
		var previous: AudioStreamPlayer = audio.bgm_player
		state.current_day = index * days
		await _night()
		_expect(state.current_day == index * days + 1, "Use the next day's season at dawn.")
		var next := _check_cue(SEASONS[index])
		await _check_fade(previous, next)
		if index < SEASONS.size() - 1:
			await _record_bus(SEASONS[index], &"Music", 2.2)

func _ravine() -> void:
	var spring: AudioStreamPlayer = audio.bgm_player
	await _move(&"ui_up", 48)
	await _move(&"ui_right", 213)
	if not _expect(tree.current_scene.name == "Wilderness", "Walk from the estate through East Gate."):
		return
	await _wait(0.18)
	var ravine := _check_cue("ravine")
	var estate_position := spring.get_playback_position()
	await _check_fade(spring, ravine)
	await _record_bus("ravine", &"Music", 2.2)
	if rendered and ravine:
		ravine.seek(ravine.stream.get_length() - 0.28)
		await _wait(0.75)
		var position := ravine.get_playback_position()
		_expect(ravine.playing and position > 0.05 and position < 1.2, "The ravine cue plays across its loop seam.")
		print("SEASON_SCORE_LOOP ravine resumed_at=", snappedf(position, 0.01))
	await Campaign.walk_to_ravine_exit(tree, tree.current_scene)
	await _move(&"ui_left", 24)
	if not _expect(tree.current_scene.name == "Main", "Walk back through West Gate."):
		return
	await _wait(0.18)
	spring = _check_cue("spring")
	if rendered and spring:
		_expect(estate_position > 2.0 and spring.get_playback_position() >= estate_position - 0.1,
			"Return from the ravine at the estate cue's earlier position.")
		print("SEASON_SCORE_RESUME estate_before=", snappedf(estate_position, 0.01),
			" estate_after=", snappedf(spring.get_playback_position(), 0.01))
	await _check_fade(ravine, spring)

func _settings_and_practice() -> void:
	var ui := tree.current_scene.get_node("UI")
	await _button(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	var close := settings.find_child("Close", true, false) as Button
	var music := settings.find_child("MusicVolume", true, false) as HSlider
	_expect(settings.visible and settings.get_global_rect().encloses(close.get_global_rect())
		and tree.root.get_visible_rect().encloses(settings.get_global_rect()) and music.is_visible_in_tree(),
		"The music and close controls both fit inside the in-game panel.")
	if rendered and not capture_dir.is_empty():
		await RenderingServer.frame_post_draw
		var image := tree.root.get_texture().get_image()
		_expect(image.save_png(capture_dir.path_join("music-settings.png")) == OK, "Capture the in-game settings.")
		print("SEASON_SCORE_FRAME music-settings window=", tree.root.size, " image=", image.get_size())
	for bus_name in [&"Music", &"Ambience", &"Master"]:
		var slider := settings.find_child(str(bus_name) + "Volume", true, false) as HSlider
		var bus := AudioServer.get_bus_index(bus_name)
		var value := slider.value
		var rect := slider.get_global_rect()
		await _click(rect.position + Vector2(2, rect.size.y * 0.5))
		_expect(is_zero_approx(slider.value) and AudioServer.is_bus_mute(bus), "The " + str(bus_name) + " slider mutes its bus on click.")
		slider.value = value
		_expect(not AudioServer.is_bus_mute(bus), "Restoring the slider unmutes " + str(bus_name))
	print("SEASON_SCORE_SETTINGS window=", tree.root.size, " sliders=3")
	await _button(close)
	await _button(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	management.tabs.current_tab = management.tabs.get_tab_idx_from_control(management.get_node("HBoxContainer/RightPanel/君子六艺"))
	var player: AudioStreamPlayer = audio.bgm_player
	var normal_gain := player.volume_linear
	await _button(management.music_button)
	var practice := management.get_node_or_null("MusicPractice")
	if not _expect(practice != null and tree.paused, "Open the actual bell exercise from Six Arts."):
		return
	await _wait(0.29)
	_expect(player.volume_linear < normal_gain * 0.28 and player.volume_linear > 0.0,
		"The soundtrack ducks while the practice panel owns the pause.")
	while practice.elapsed < 0.71:
		await tree.process_frame
	practice.strike_button.pressed.emit()
	_expect(practice.hits == 1 and (not rendered or practice.bell.playing), "The correctly timed bell sounds over the quieter cue.")
	await _record_bus("bell-practice", &"Master", 0.7)
	await _button(practice.close_button)
	await _wait(0.63)
	_expect(not tree.paused and audio.bgm_player == player and is_equal_approx(player.volume_linear, normal_gain),
		"Closing the practice resumes the full music level at the same playback position.")
	print("SEASON_SCORE_BELL gain_restored=", snappedf(player.volume_linear, 0.001))

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the seasonal score replay's profile."):
		tree.quit(1)
		return
	seed(650)
	state = tree.root.get_node("Global")
	audio = tree.root.get_node("AudioManager")
	rendered = DisplayServer.get_name() != "headless"
	capture_dir = OS.get_environment("FIEFDOM_SEASON_SCORE_CAPTURES")
	tree.root.notify_mouse_entered()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _wait(1.54)
	var title := _check_cue("title")
	await _record_bus("title", &"Music", 2.2)
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if _expect(tree.current_scene.name == "Main", "Start a new estate from the title."):
		state.balance.raid_first_day = 10000
		await _wait(0.24)
		var spring := _check_cue("spring")
		if spring:
			await _check_fade(title, spring)
			await _record_bus("spring", &"Music", 2.2)
			await _seasons(spring)
			await _ravine()
			if tree.current_scene.name == "Main" and audio.bgm_player:
				await _settings_and_practice()
	tree.paused = false
	tree.unload_current_scene()
	for player in audio.get_children():
		if player is AudioStreamPlayer:
			player.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
