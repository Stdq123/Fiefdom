extends Node

signal bindings_changed
signal reading_size_changed

const PATH := "user://settings.cfg"
const DEFAULT_VOLUME := 0.75
const DEFAULT_MUSIC_VOLUME := 0.8
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_AMBIENCE_VOLUME := 0.8
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1024, 576),
]
const READING_FONT_STEPS: Array[int] = [0, 3, 6]

var volume := DEFAULT_VOLUME
var music_volume := DEFAULT_MUSIC_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
var ambience_volume := DEFAULT_AMBIENCE_VOLUME
var fullscreen := false
# Zero keeps the startup window dimensions until a preset is selected.
var window_size := Vector2i.ZERO
var reading_size := 0
var autosave := true
var map_zoom := 2.0
var _bindings := KeyBindings.DEFAULTS.duplicate()

func _ready() -> void:
	restore()

func restore() -> void:
	var settings := ConfigFile.new()
	settings.load(PATH)
	volume = _read_volume(settings, "master", DEFAULT_VOLUME)
	music_volume = _read_volume(settings, "music", DEFAULT_MUSIC_VOLUME)
	sfx_volume = _read_volume(settings, "sfx", DEFAULT_SFX_VOLUME)
	ambience_volume = _read_volume(settings, "ambience", DEFAULT_AMBIENCE_VOLUME)
	fullscreen = settings.get_value("display", "fullscreen", false) == true
	var saved_size: Variant = settings.get_value("display", "window_size", Vector2i.ZERO)
	window_size = saved_size if saved_size is Vector2i and saved_size in WINDOW_SIZES else Vector2i.ZERO
	var saved_reading: Variant = settings.get_value("display", "reading_size", 0)
	reading_size = saved_reading if saved_reading is int and _valid_reading_size(saved_reading) else 0
	autosave = settings.get_value("game", "autosave", true) == true
	_bindings = _read_bindings(settings)
	_install_bindings()
	_apply_bus_volume(&"Master", volume)
	apply_music_volume()
	apply_sfx_volume()
	apply_ambience_volume()
	_apply_display()
	bindings_changed.emit()
	reading_size_changed.emit()

func _read_volume(settings: ConfigFile, key: String, fallback: float) -> float:
	var saved: Variant = settings.get_value("audio", key, fallback)
	return clampf(float(saved), 0.0, 1.0) if saved is float or saved is int else fallback

func set_volume(value: float) -> Error:
	volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(&"Master", volume)
	return _save()

func set_music_volume(value: float) -> Error:
	music_volume = clampf(value, 0.0, 1.0)
	apply_music_volume()
	return _save()

func set_sfx_volume(value: float) -> Error:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply_sfx_volume()
	return _save()

func set_ambience_volume(value: float) -> Error:
	ambience_volume = clampf(value, 0.0, 1.0)
	apply_ambience_volume()
	return _save()

func set_fullscreen(value: bool) -> Error:
	var previous := fullscreen
	fullscreen = value
	var result := _save()
	if result == OK:
		_apply_display()
	else:
		fullscreen = previous
	return result

func set_window_size(value: Vector2i) -> Error:
	if value not in WINDOW_SIZES:
		return ERR_INVALID_PARAMETER
	var previous := window_size
	window_size = value
	var result := _save()
	if result == OK:
		_apply_display()
	else:
		window_size = previous
	return result

func set_reading_size(value: int) -> Error:
	if not _valid_reading_size(value):
		return ERR_INVALID_PARAMETER
	if value == reading_size:
		return OK
	var previous := reading_size
	reading_size = value
	var result := _save()
	if result == OK:
		reading_size_changed.emit()
	else:
		reading_size = previous
	return result

func _valid_reading_size(value: int) -> bool:
	return value >= 0 and value < READING_FONT_STEPS.size()

func reading_font_size(standard: int) -> int:
	return standard + READING_FONT_STEPS[reading_size]

func set_autosave(value: bool) -> Error:
	autosave = value
	return _save()

func binding(action: StringName) -> Key:
	return _bindings[action]

func key_label(action: StringName) -> String:
	return KeyBindings.key_text(binding(action))

func seed_label(crop_id: String) -> String:
	return key_label(KeyBindings.SEEDS[CropData.IDS.find(crop_id)])

func bound_action(code: Key) -> StringName:
	var action: Variant = _bindings.find_key(code)
	return action if action != null else &""

func matches(event: InputEvent, action: StringName) -> bool:
	# Some synthesized key events carry only their logical key.
	if event is InputEventKey and event.physical_keycode == KEY_NONE:
		return event.keycode == binding(action)
	return event.is_action(action)

func set_binding(action: StringName, code: Key) -> Error:
	if not KeyBindings.accepts(action, code):
		return ERR_INVALID_PARAMETER
	var previous_action := bound_action(code)
	if previous_action == action:
		return OK
	var next := _bindings.duplicate()
	if previous_action != &"":
		var old_key := binding(action)
		if not KeyBindings.accepts(previous_action, old_key):
			return ERR_ALREADY_IN_USE
		next[previous_action] = old_key
	next[action] = code
	return _save_bindings(next)

func reset_bindings() -> Error:
	return _save_bindings(KeyBindings.DEFAULTS.duplicate())

func _save_bindings(next: Dictionary[StringName, Key]) -> Error:
	var before := _bindings
	_bindings = next
	var result := _save()
	if result == OK:
		_install_bindings()
		bindings_changed.emit()
	else:
		_bindings = before
	return result

func _read_bindings(settings: ConfigFile) -> Dictionary[StringName, Key]:
	var keys := KeyBindings.DEFAULTS.duplicate()
	var used := {}
	var needs_backpack_key := not settings.has_section_key("controls", KeyBindings.BACKPACK)
	for action in keys:
		if needs_backpack_key and action == KeyBindings.BACKPACK:
			continue
		var value: Variant = settings.get_value("controls", action, keys[action])
		if value is int and KeyBindings.accepts(action, value as Key):
			keys[action] = value as Key
		if used.has(keys[action]):
			return KeyBindings.DEFAULTS.duplicate()
		used[keys[action]] = true
	if needs_backpack_key and used.has(keys[KeyBindings.BACKPACK]):
		# Older settings may already use I. Reserve their keys before assigning the new action.
		for candidate: int in [KEY_B] + range(KEY_A, KEY_Z + 1):
			if not used.has(candidate):
				keys[KeyBindings.BACKPACK] = candidate as Key
				break
	return keys

func _install_bindings() -> void:
	for action in _bindings:
		if InputMap.has_action(action):
			Input.action_release(action)
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = _bindings[action]
		InputMap.action_add_event(action, event)

func apply_music_volume() -> void:
	_apply_bus_volume(&"Music", music_volume)

func apply_sfx_volume() -> void:
	_apply_bus_volume(&"SFX", sfx_volume)

func apply_ambience_volume() -> void:
	_apply_bus_volume(&"Ambience", ambience_volume)

func _apply_bus_volume(bus_name: StringName, value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, is_zero_approx(value))
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.001, value)))

func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	var target := Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if window.mode != target:
		window.mode = target
	if fullscreen or window_size == Vector2i.ZERO or window.size == window_size:
		return
	var work_area := DisplayServer.screen_get_usable_rect(window.current_screen)
	window.size = window_size
	if work_area.has_area():
		var outer_size := window.get_size_with_decorations()
		var frame_offset := window.position - window.get_position_with_decorations()
		window.position = work_area.position + ((work_area.size - outer_size) / 2).max(Vector2i.ZERO) + frame_offset

func _save() -> Error:
	var settings := ConfigFile.new()
	settings.set_value("audio", "master", volume)
	settings.set_value("audio", "music", music_volume)
	settings.set_value("audio", "sfx", sfx_volume)
	settings.set_value("audio", "ambience", ambience_volume)
	settings.set_value("display", "fullscreen", fullscreen)
	if window_size != Vector2i.ZERO:
		settings.set_value("display", "window_size", window_size)
	settings.set_value("display", "reading_size", reading_size)
	settings.set_value("game", "autosave", autosave)
	for action in _bindings:
		settings.set_value("controls", action, _bindings[action])
	return settings.save(PATH)
