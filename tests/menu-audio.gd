extends SceneTree

const OPEN := "book-open.wav"
const PAGE := "page-turn.wav"
const CLOSE := "book-close.wav"

var tree: SceneTree
var screen: Window
var menu_sound: AudioStreamPlayer
var frames_path := ""
var measure_audio := false
var baseline := false
var failed := false

func _initialize() -> void:
	_review.call_deferred(self)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _wait(seconds: float) -> void:
	await tree.create_timer(seconds, true, false, true).timeout

func _press(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		screen.push_input(event, true)

func _peak(tag: String, action: Callable) -> float:
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	var effect := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	await _wait(0.08)
	action.call()
	await _wait(0.46)
	record.set_recording_active(false)
	var wave := record.get_recording()
	AudioServer.remove_bus_effect(0, effect)
	_expect(wave != null and wave.get_length() > 0.22, "The master recording is too short for " + tag)
	if wave == null:
		return 0.0
	var samples := wave.data
	var peak := 0
	for index in range(0, samples.size() - 1, 2):
		peak = maxi(peak, absi(samples.decode_s16(index)))
	if not frames_path.is_empty() and tag in ["settings-open", "settings-shortcuts", "settings-close", "settings-open-quarter", "settings-open-muted"]:
		_expect(wave.save_to_wav(frames_path.path_join(tag + ".wav")) == OK, "Could not save the meter capture for " + tag)
	var mix_peak := float(peak) / 32768.0
	print("MENU_CUE_PEAK ", tag, " peak=", mix_peak, " frames=", samples.size() / 4)
	return mix_peak

func _cue(tag: String, expected: String, action: Callable, audible := true) -> float:
	if menu_sound:
		menu_sound.stream = null
	var peak := 0.0
	if measure_audio:
		peak = await _peak(tag, action)
		var should_hear := audible and not expected.is_empty()
		if baseline:
			should_hear = tag in ["counter-open", "counter-orders", "counter-repeat"]
		_expect(peak > 0.009 and peak < 0.19 if should_hear else peak <= 0.0002, "Unexpected sound level for " + tag)
	else:
		action.call()
		await tree.process_frame
	if menu_sound:
		var file := menu_sound.stream.resource_path.get_file() if menu_sound.stream else ""
		_expect(file == expected, "%s played %s, wanted %s" % [tag, file, expected])
	return peak

func _title_checks(title: Control, state: Node) -> void:
	var button := title.get_node("Center/Menu/Settings") as Button
	await _cue("idle-title", "", func(): title.new_button.grab_focus())
	var normal := await _cue("settings-open", OPEN, button.pressed.emit)
	var settings: Panel = title.settings_panel
	await _cue("settings-shortcuts", PAGE, settings.shortcuts.pressed.emit)
	await _cue("settings-back", PAGE, _press.bind(KEY_ESCAPE))
	await _cue("settings-close", CLOSE, _press.bind(KEY_ESCAPE))
	_expect(not settings.visible and button.has_focus(), "Closing settings returns to the title menu.")

	var slider := settings.find_child("SfxVolume", true, false) as HSlider
	slider.value = 0.25
	var quarter := await _cue("settings-open-quarter", OPEN, button.pressed.emit)
	await _cue("settings-close-quarter", CLOSE, settings.close_button.pressed.emit)
	slider.value = 0.0
	await _cue("settings-open-muted", OPEN, button.pressed.emit, false)
	await _cue("settings-close-muted", CLOSE, settings.close_button.pressed.emit, false)
	if measure_audio and not baseline:
		_expect(absf(quarter / normal - 0.25) < 0.025, "The SFX slider controls new cues at one quarter of the original gain.")
	slider.value = 1.0

	# A damaged fixture enables the normal archive and new-name buttons without loading or starting a game.
	var path: String = state.SAVE_PATH
	var placeholder := FileAccess.open(path, FileAccess.WRITE)
	_expect(placeholder != null, "A test-only archive path must be writable.")
	if placeholder == null:
		return
	placeholder.store_string("{}")
	placeholder.close()
	await _cue("title-refresh", "", title._refresh_menu)
	await _cue("archive-open", OPEN, title.archive_button.pressed.emit)
	var archive := title.get_node_or_null("SaveArchive") as Control
	_expect(archive != null, "The title opens the archive on the damaged record.")
	if archive:
		await _cue("archive-close", CLOSE, archive.close_button.pressed.emit)
	await _cue("name-dialog-open", OPEN, title.new_button.pressed.emit)
	_expect(title.new_confirmation.visible, "The name prompt opens with an existing slot.")
	await _cue("name-dialog-cancel", CLOSE, _press.bind(KEY_ESCAPE))
	_expect(not title.new_confirmation.visible, "Escape closes the naming prompt.")
	_expect(DirAccess.remove_absolute(path) == OK and state.saved_games().is_empty(), "The title check leaves no saves.")

func _estate_checks(state: Node) -> void:
	tree.change_scene_to_file(state.ESTATE_SCENE)
	await tree.scene_changed
	var estate := tree.current_scene
	var world := estate.get_node("World")
	var ui := estate.get_node("UI")
	var hud := estate.get_node("CampaignHUD")
	world.process_mode = Node.PROCESS_MODE_DISABLED
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	await tree.process_frame
	state.last_dawn = {"day": 1}
	var before := _estate_state(state)

	await _cue("manage-open-on-technology", OPEN, ui._show_water_technology)
	var panel: Control = ui.panel_manager.management_panel_instance
	await _cue("manage-page", PAGE, panel.section_buttons[0].pressed.emit)
	await _cue("manage-repeat", "", panel.section_buttons[0].pressed.emit)
	await _cue("night-book-open", OPEN, panel.roster_night_rations.pressed.emit)
	var night := ui.get_node_or_null("Control/NightRationsPanel") as Control
	_expect(night != null and night.page_button.visible, "The fixture's previous-night page can be read.")
	if night:
		await _cue("night-book-page", PAGE, night.page_button.pressed.emit)
		await _cue("night-book-close", CLOSE, night.close_button.pressed.emit)
	await _cue("manage-close", CLOSE, panel.close_button.pressed.emit)

	# Map and backpack require a running tree. The world stays disabled throughout.
	tree.paused = false
	await _cue("map-open", OPEN, ui.estate_map.open_map)
	await _cue("map-overview", PAGE, ui.estate_map.get_node("%RegionMap").pressed.emit)
	var region := ui.get_node_or_null("Control/RegionMap") as Control
	_expect(region != null and region.modal.visible, "The map turns to the regional view.")
	if region:
		await _cue("map-browse", PAGE, region.region_buttons.get_child(0).pressed.emit)
		await _cue("map-close", CLOSE, region.close_button.pressed.emit)
	await _cue("calendar-open", OPEN, ui.calendar.open_map)
	await _cue("calendar-page", PAGE, ui.calendar.seasons.get_child(1).pressed.emit)
	await _cue("calendar-close", CLOSE, ui.calendar.close_button.pressed.emit)
	await _cue("backpack-open", OPEN, hud.backpack_button.pressed.emit)
	if hud.backpack:
		var bag: Control = hud.backpack
		await _cue("backpack-page", PAGE, bag.fish_tab.pressed.emit)
		await _cue("backpack-close", CLOSE, bag.close_button.pressed.emit)
	tree.paused = true
	_expect(_estate_state(state) == before, "The estate's clock, money, supplies, stamina and crops must be unchanged.")

func _estate_state(state: Node) -> Array:
	return [state.current_day, state.day_progress, state.money, state.food_storage,
		state.player_inventory, state.current_stamina, state.active_crops.duplicate(true)]

func _review(scenario: SceneTree) -> void:
	tree = scenario
	screen = tree.root
	var profile := OS.get_user_data_dir()
	if not ("fiefdom-smoke-" in profile or "fiefdom-menu-cues-" in profile):
		push_error("Run the menu audio check with an isolated player profile.")
		tree.quit(1)
		return
	measure_audio = DisplayServer.get_name() != "headless"
	var args := OS.get_cmdline_user_args()
	if measure_audio:
		frames_path = args[0]
		var dimensions := args[1].split("x")
		_expect(screen.size == Vector2i(dimensions[0].to_int(), dimensions[1].to_int()), "The check opened the requested window size.")
		baseline = args[2] == "baseline"
	var state := screen.get_node("Global")
	if state.has_saved_game():
		push_error("The menu check requires a fresh profile.")
		tree.quit(1)
		return
	tree.paused = true
	var audio := screen.get_node("AudioManager")
	menu_sound = audio.get_node_or_null("MenuSound") as AudioStreamPlayer
	_expect((menu_sound == null if baseline else menu_sound != null and menu_sound.bus == &"SFX"),
		"Menu cues use a dedicated player on the existing SFX bus.")
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Ambience"), true)
	await tree.process_frame
	if tree.current_scene == null:
		tree.change_scene_to_file(state.TITLE_SCENE)
		await tree.scene_changed
	var title := tree.current_scene as Control
	title.process_mode = Node.PROCESS_MODE_ALWAYS
	await tree.process_frame
	_expect(menu_sound == null or menu_sound.stream == null, "The title starts without an interface cue.")
	await _title_checks(title, state)
	await _estate_checks(state)

	tree.change_scene_to_file(state.WEST_MARKET_SCENE)
	await tree.scene_changed
	var market := tree.current_scene
	var counter: Control = market.counter
	var before := _estate_state(state)
	await _cue("counter-open", OPEN, counter.open_for.bind(0))
	await _cue("counter-orders", PAGE, counter.open_orders)
	await _cue("counter-repeat", "", counter.open_orders)
	await _cue("counter-close", CLOSE, counter.close_button.pressed.emit)
	_expect(tree.paused and _estate_state(state) == before and state.saved_games().is_empty(),
		"The isolated counter check keeps time, resources and saves untouched.")

	if not failed:
		print("MENU_CUE_REVIEW_OK window=", screen.size, " baseline=", baseline, " saves=0")
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
