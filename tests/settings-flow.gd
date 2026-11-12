extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run settings-flow with an isolated profile.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var preferences := root.get_node("Preferences")
	var config := ConfigFile.new()
	config.set_value("audio", "master", 0.65)
	if config.save(preferences.PATH) != OK:
		push_error("Could not write the legacy settings fixture.")
		quit(1)
		return
	preferences.restore()
	if not is_equal_approx(preferences.volume, 0.65) or preferences.ambience_volume != preferences.DEFAULT_AMBIENCE_VOLUME \
			or preferences.music_volume != preferences.DEFAULT_MUSIC_VOLUME:
		push_error("Legacy settings keep their master volume and use the new defaults.")
		quit(1)
		return

	change_scene_to_file("res://scenes/Title.tscn")
	await scene_changed
	current_scene.get_node("Center/Menu/Settings").pressed.emit()
	var panel: Panel = current_scene.settings_panel
	var volume := panel.find_child("MasterVolume", true, false) as HSlider
	var music := panel.find_child("MusicVolume", true, false) as HSlider
	var ambience := panel.find_child("AmbienceVolume", true, false) as HSlider
	var fullscreen := panel.find_child("Fullscreen", true, false) as CheckButton
	var music_bus := AudioServer.get_bus_index(&"Music")
	var ambience_bus := AudioServer.get_bus_index(&"Ambience")
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	music.value = 0
	if not AudioServer.is_bus_mute(music_bus) or AudioServer.is_bus_mute(ambience_bus) \
			or AudioServer.is_bus_mute(sfx_bus) or AudioServer.is_bus_mute(0):
		push_error("The music control only mutes the Music bus.")
		quit(1)
		return
	ambience.value = 0
	if ambience_bus < 0 or not AudioServer.is_bus_mute(ambience_bus) or AudioServer.is_bus_mute(0):
		push_error("Ambience can be muted while master sound remains on.")
		quit(1)
		return
	volume.value = 0
	fullscreen.button_pressed = true
	if config.load(preferences.PATH) != OK or config.get_value("audio", "master") != 0.0 \
			or config.get_value("audio", "music") != 0.0 or config.get_value("audio", "ambience") != 0.0 \
			or not config.get_value("display", "fullscreen"):
		push_error("Title settings write all three volume levels and display mode.")
		quit(1)
		return
	if not AudioServer.is_bus_mute(0) or panel.preferences_status.text != "设置已保存":
		push_error("Zero volume mutes the master bus and displays a saved status.")
		quit(1)
		return
	preferences.volume = 1.0
	preferences.music_volume = 1.0
	preferences.ambience_volume = 1.0
	preferences.fullscreen = false
	AudioServer.set_bus_mute(0, false)
	AudioServer.set_bus_mute(music_bus, false)
	AudioServer.set_bus_mute(ambience_bus, false)
	preferences.restore()
	if preferences.volume != 0.0 or not preferences.fullscreen or not AudioServer.is_bus_mute(0):
		push_error("Startup restores the persisted settings.")
		quit(1)
		return
	if preferences.ambience_volume != 0.0 or not AudioServer.is_bus_mute(ambience_bus):
		push_error("Startup restores the persisted ambience mute.")
		quit(1)
		return
	if preferences.music_volume != 0.0 or not AudioServer.is_bus_mute(music_bus):
		push_error("Startup restores the persisted music mute.")
		quit(1)
		return
	volume.value = 0.35
	music.value = 0.55
	ambience.value = 0.2
	fullscreen.button_pressed = false
	preferences.restore()
	if AudioServer.is_bus_mute(0) or not is_equal_approx(preferences.volume, 0.35) or preferences.fullscreen:
		push_error("Unmute and windowed mode also persist.")
		quit(1)
		return
	if AudioServer.is_bus_mute(ambience_bus) or not is_equal_approx(preferences.ambience_volume, 0.2):
		push_error("The ambience level persists independently.")
		quit(1)
		return
	if AudioServer.is_bus_mute(music_bus) or not is_equal_approx(preferences.music_volume, 0.55):
		push_error("The music level persists independently.")
		quit(1)
		return
	current_scene.new_button.pressed.emit()
	await scene_changed
	var ui := current_scene.get_node("UI")
	ui.settings_button.pressed.emit()
	panel = ui.panel_manager.settings_panel_instance
	ambience = panel.find_child("AmbienceVolume", true, false) as HSlider
	music = panel.find_child("MusicVolume", true, false) as HSlider
	if not is_equal_approx(music.value, 0.55):
		push_error("In-game settings open at the saved music level.")
		quit(1)
		return
	ambience.value = 0.4
	await process_frame
	await process_frame
	var close := panel.find_child("Close", true, false) as Button
	if not panel.get_global_rect().encloses(close.get_global_rect()) or not is_equal_approx(preferences.ambience_volume, 0.4):
		push_error("The in-game settings save ambience and keep the close button inside the panel.")
		quit(1)
		return
	print("SCENARIO_OK")
	quit()
