extends RefCounted

const MUSIC := preload("res://scripts/MusicPractice.gd")
const REASSIGNED := {
	KeyBindings.UP: KEY_I, KeyBindings.INTERACT: KEY_G, KeyBindings.MAP: KEY_J,
	KeyBindings.ALMANAC: KEY_K, KeyBindings.MEAL: KEY_L, KeyBindings.RHYTHM: KEY_P,
	KeyBindings.BACKPACK: KEY_V,
	KeyBindings.FILL: KEY_T, KeyBindings.ROTATE: KEY_U, &"seed_1": KEY_5, &"seed_5": KEY_1,
}

var tree: SceneTree
var preferences: Node
var state: Node
var captures: String
var failures := 0

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		failures += 1
		push_error(detail)

func _raw(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	_raw(event)

func _key(code: Key, physics_frames := 0) -> void:
	_key_event(code, true)
	for frame in physics_frames:
		await tree.physics_frame
	_key_event(code, false)
	await tree.process_frame

func _pad(code: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = code
		event.pressed = pressed
		_raw(event)
		await tree.process_frame

func _click(point: Vector2, shift := false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.shift_pressed = shift
	tree.root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.shift_pressed = shift
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame

func _button(button: Button) -> void:
	await tree.process_frame
	var rect := button.get_global_rect()
	_expect(button.is_visible_in_tree() and not button.disabled and tree.root.get_visible_rect().encloses(rect),
		"The player can reach %s at %s." % [button.text, rect])
	await _click(rect.get_center())

func _frame(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(captures.path_join(name + ".png")) == OK, "Save key binding frame " + name)
	print("BINDING_FRAME ", name, " window=", tree.root.size, " image=", image.get_size())

func _configure(settings: Panel) -> void:
	var page: VBoxContainer = settings.bindings_page
	_expect(page.keys.size() == KeyBindings.DEFAULTS.size() and preferences.binding(KeyBindings.MAP) == KEY_M
		and preferences.binding(KeyBindings.UP) == KEY_I and preferences.binding(KeyBindings.BACKPACK) == KEY_B,
		"The settings page offers Backpack on B while an older movement binding keeps I.")
	await _button(page.keys[KeyBindings.MAP])
	await _key(KEY_UP)
	_expect(page.pending == KeyBindings.MAP and preferences.binding(KeyBindings.MAP) == KEY_M,
		"The arrow keys stay reserved and the binding stays in capture.")
	await _frame("02-capture")
	await _key(KEY_ESCAPE)
	_expect(page.pending == &"" and page.visible, "Escape cancels capture before returning to settings.")
	for action in REASSIGNED:
		if action == &"seed_5":
			continue # Choosing 5 for the first slot also reassigns the fifth slot to 1.
		await _button(page.keys[action])
		await _key(REASSIGNED[action])
	for action in REASSIGNED:
		_expect(preferences.binding(action) == REASSIGNED[action] and page.keys[action].text == preferences.key_label(action),
			"The settings page reflects the newly saved key for " + KeyBindings.label(action))
	_expect(page.status.text.begins_with("已互换"), "Swapping seed keys explains the two changes.")
	await _frame("03-reassigned")

func _play() -> void:
	var estate := tree.current_scene
	var world := estate.get_node("World")
	var ui := estate.get_node("UI")
	var actor: Player = world.player
	var keeper: Retainer = world.retainer_instances[state.retainers[0]]
	keeper.set_physics_process(false)
	var start := actor.position
	await _key(KEY_W, 12)
	_expect(actor.position.is_equal_approx(start), "The previous movement key is released.")
	await _key(KEY_I, 12)
	_expect(actor.position.y < start.y - 14.0 and "I / A / S / D" in ui.hud.guide.text,
		"The new key moves the player and the opening guide lists the four keys separately.")
	await _key(KEY_DOWN, 34)
	await _key(KEY_RIGHT, 21)
	_expect(actor.interaction_target == keeper and keeper.hint.text.ends_with(" · G"),
		"Arrow keys still walk and the retainer shows the new interaction key.")
	await _key(KEY_E)
	_expect(not actor.conversation_open, "The old interaction key is released.")
	await _key(KEY_G)
	_expect(actor.conversation_open and ui.has_node("Control/DialoguePanel"), "The new key opens the resident's dialogue.")
	var dialogue: Control = ui.get_node("Control/DialoguePanel")
	_expect(dialogue.controls_hint.text == "G 继续", "The dialogue uses the reassigned interaction key in its hint.")
	await _key(KEY_E)
	_expect(actor.conversation_open, "The old key does not dismiss the resident's dialogue.")
	await _key(KEY_G)
	_expect(not actor.conversation_open, "The new interaction key also finishes the dialogue.")
	await _key(KEY_1)
	_expect(world.current_seed_id == world.SEED_ORDER[4] and ui.hud.seed_buttons[world.SEED_ORDER[4]].get_node("Shortcut").text == "1",
		"A swapped seed key selects and labels the fifth seed.")
	await _key(KEY_5)
	_expect(world.current_seed_id == world.SEED_ORDER[0], "The other swapped key selects the first seed.")
	await _frame("04-estate")
	await _key(KEY_M)
	_expect(not ui.estate_map.modal.visible, "The old map key is released.")
	await _key(KEY_J)
	_expect(ui.estate_map.modal.visible, "The new map key opens the paused overlay.")
	await _key(KEY_J)
	_expect(not tree.paused, "The same key closes the map while paused.")
	await _key(KEY_K)
	_expect(ui.calendar.modal.visible, "The new almanac key opens its overlay.")
	await _key(KEY_ESCAPE)
	await _pad(JOY_BUTTON_Y)
	_expect(ui.estate_map.modal.visible and ui.estate_map.close_button.text.ends_with("  B"),
		"Gamepad Y still opens the map and the hint uses the gamepad button.")
	await _pad(JOY_BUTTON_B)
	# Supply the meal and unlock the canal to exercise their inputs in the opening estate.
	state.current_stamina = 60
	state.travel_meal = TravelMeal.BEAN_MILLET
	tree.root.get_node("GameEvents").travel_meal_changed.emit()
	await _key(KEY_F)
	_expect(not state.travel_meal.is_empty() and actor.meal_button.text.begins_with("L"), "The packed meal shows L and stays packed when pressing F.")
	await _key(KEY_L)
	_expect(state.travel_meal.is_empty() and state.current_stamina > 60, "L consumes the meal and restores stamina.")
	await _canal(world, ui)
	var music: Panel = MUSIC.new()
	ui.get_node("Control").add_child(music)
	music.set_process(false)
	music.elapsed = music.BEAT_SECONDS - music.HIT_WINDOW / 2.0
	await _key(KEY_SPACE)
	_expect(music.hits == 0 and music.strike_button.text.ends_with(" · P"), "The timing practice shows the new key and releases Space.")
	await _key(KEY_P)
	_expect(music.hits == 1, "The new timing key can strike the bell.")
	await _key(KEY_ESCAPE)
	await _button(ui.settings_button)
	var settings: Panel = ui.panel_manager.settings_panel_instance
	await _frame("05-estate-settings")
	await _button(settings.find_child("KeyboardBindings", true, false))
	await _button(settings.bindings_page.keys[KeyBindings.UP])
	var standing := actor.position
	await _key(KEY_I, 12)
	_expect(actor.position.is_equal_approx(standing), "Capturing a movement key in the estate leaves the player in place.")
	await _frame("06-estate-keyboard")
	await _key(KEY_ESCAPE)
	await _button(settings.close_button)
	_expect(not actor.menu_open, "Returning from the keyboard page and closing settings restores controls.")

func _canal(world: Node, ui: Node) -> void:
	state.tech_unlocked["irrigation"] = true
	state.channel_survey_day = 1
	state.money = 5
	var events := tree.root.get_node("GameEvents")
	events.irrigation_unlocked.emit()
	events.channel_survey_learned.emit()
	await _button(ui.channel_button)
	var cell := Vector2i(3, 5)
	var tiles: TileMapLayer = world.tile_map
	var point := tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)
	await _click(point)
	await _click(point, true)
	_expect(state.irrigation.channels.has(cell) and "T+左键填渠" in ui.help_label.text, "Shift now leaves an existing canal in place and the hint shows T.")
	_key_event(KEY_T, true)
	await _click(point)
	_key_event(KEY_T, false)
	_expect(not state.irrigation.channels.has(cell), "Holding T while clicking fills the canal.")
	await _button(ui.hud.survey_button)
	await _key(KEY_R)
	_expect(world.irrigation_overlay.horizontal_first, "The old survey rotation key is released.")
	await _key(KEY_U)
	_expect(not world.irrigation_overlay.horizontal_first and "U 换弯" in ui.help_label.text, "The survey rotates using the new key.")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)

func _restore(page: VBoxContainer) -> void:
	for action in REASSIGNED:
		_expect(preferences.binding(action) == REASSIGNED[action], "Restart restores " + KeyBindings.label(action))
	_expect(is_equal_approx(preferences.volume, 0.65) and not preferences.autosave, "Other settings survive the key changes.")
	await _button(page.find_child("RestoreBindings", true, false))
	preferences.restore()
	for action in KeyBindings.DEFAULTS:
		_expect(preferences.binding(action) == KeyBindings.DEFAULTS[action], "Reset persists the default for " + KeyBindings.label(action))
	_expect(is_equal_approx(preferences.volume, 0.65) and not preferences.autosave, "Reset restores only keyboard settings.")
	print("BINDING_RESTART restored=", REASSIGNED.size(), " reset=", KeyBindings.DEFAULTS.size())

func run(host: SceneTree, directory := "", reload := false, same_process := false) -> void:
	tree = host
	preferences = tree.root.get_node("Preferences")
	state = tree.root.get_node("Global")
	captures = directory
	if not reload:
		var old := ConfigFile.new()
		old.set_value("audio", "master", 0.65)
		old.set_value("game", "autosave", false)
		_expect(old.save(preferences.PATH) == OK, "Save the settings fixture without any controls section.")
		preferences.restore()
		_expect(preferences.binding(KeyBindings.UP) == KEY_W and preferences.binding(KeyBindings.BACKPACK) == KEY_I,
			"A settings file without remapped controls uses I for Backpack.")
		old.set_value("controls", KeyBindings.UP, KEY_I)
		old.set_value("controls", KeyBindings.LEFT, KEY_B)
		_expect(old.save(preferences.PATH) == OK, "Save an older settings fixture that already uses I and B.")
		preferences.restore()
		_expect(preferences.binding(KeyBindings.UP) == KEY_I and preferences.binding(KeyBindings.LEFT) == KEY_B
			and preferences.binding(KeyBindings.BACKPACK) == KEY_A,
			"The next available key is used when an older file already uses both I and B.")
		old.set_value("controls", KeyBindings.LEFT, KEY_I)
		_expect(old.save(preferences.PATH) == OK, "Save a fixture with a duplicate older movement key.")
		preferences.restore()
		_expect(preferences.binding(KeyBindings.UP) == KEY_W and preferences.binding(KeyBindings.BACKPACK) == KEY_I,
			"An older file with duplicate movement bindings still restores the defaults.")
		old.erase_section_key("controls", KeyBindings.LEFT)
		_expect(old.save(preferences.PATH) == OK, "Save the legacy settings fixture.")
		preferences.restore()
	tree.change_scene_to_file("res://scenes/Title.tscn")
	await tree.scene_changed
	tree.root.notify_mouse_entered()
	var title := tree.current_scene
	await _button(title.get_node("Center/Menu/Settings"))
	var settings: Panel = title.settings_panel
	await _frame("00-settings")
	await _button(settings.find_child("KeyboardBindings", true, false))
	if reload:
		await _restore(settings.bindings_page)
	else:
		await _frame("01-keyboard")
		await _configure(settings)
		await _key(KEY_ESCAPE)
		_expect(settings.general.visible and not settings.bindings_page.visible, "Escape returns to the main settings page.")
		await _key(KEY_ESCAPE)
		await _button(title.new_button)
		if tree.current_scene == null:
			await tree.scene_changed
		if tree.current_scene.scene_file_path != "res://scenes/Main.tscn":
			push_error("Starting from the title must enter the estate.")
			tree.quit(1)
			return
		await _play()
		if same_process:
			preferences.restore()
			var ui := tree.current_scene.get_node("UI")
			await _button(ui.settings_button)
			settings = ui.panel_manager.settings_panel_instance
			await _button(settings.find_child("KeyboardBindings", true, false))
			await _restore(settings.bindings_page)
		print("BINDING_PLAY rebound=", REASSIGNED.size(), " input=keyboard,mouse,gamepad")
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures > 0 else 0)
