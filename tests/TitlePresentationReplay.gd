extends RefCounted

const PUBLIC := Vector2i(5, 5)
const ESTATE_NAME := "南路亭东竹涧西岸雨前试作井田记一"

var tree: SceneTree
var state: Node
var capture_dir: String
var failures := 0

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		push_error(message)
	return condition

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	tree.root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame

func _button(button: Button) -> void:
	await tree.process_frame
	var rect := button.get_global_rect()
	if _expect(button.is_visible_in_tree() and not button.disabled and tree.root.get_visible_rect().encloses(rect),
			"Use the visible %s button." % button.text):
		await _click(rect.get_center())

func _find_button(panel: Control, text: String) -> Button:
	for button: Button in panel.find_children("*", "Button", true, false):
		if button.text == text and button.get_window() == tree.root:
			return button
	return null

func _frame(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(capture_dir.path_join(name + ".png")) == OK, "Save the title frame " + name)
	print("TITLE_FRAME ", name, " window=", tree.root.size, " image=", frame.get_size())

func _opening_menu(title: Control) -> void:
	var heading: Label = title.get_node("Center/Menu/Heading")
	var font := heading.get_theme_font("font")
	for index in heading.text.length():
		_expect(font.has_char(heading.text.unicode_at(index)), "The shipped heading font contains every title glyph.")
	_expect(not title.continue_button.visible and not title.archive_button.visible and title.new_button.has_focus(),
		"With a fresh profile, New Game is the first visible and focused action.")
	await _frame("01-morning-title")
	var clock: float = state.day_progress
	var light := title.get_node("Lighting") as AnimationPlayer
	var twilight: TextureRect = title.get_node("Twilight")
	_expect(light.is_playing(), "The scene starts its light cycle automatically.")
	light.seek(14.0, true)
	var blend := twilight.modulate.a
	_expect(blend > 0.0 and blend < 1.0, "The two exposures blend during the light cycle.")
	await tree.create_timer(0.18).timeout
	_expect(twilight.modulate.a > blend, "The light cycle continues on its own while the title is open.")
	light.seek(21.0, true)
	_expect(is_equal_approx(twilight.modulate.a, 1.0) and state.day_progress == clock
		and tree.get_nodes_in_group("player").is_empty(), "Twilight is visible on the title without running a campaign scene.")
	await _frame("02-dusk-title")
	light.seek(41.5, true)
	_expect(is_zero_approx(twilight.modulate.a), "The cycle returns to the morning exposure.")
	print("TITLE_LIGHT glyphs=", heading.text.length(), " middle_alpha=", blend, " campaign_clock=", state.day_progress)
	var settings_button := title.get_node("Center/Menu/Settings") as Button
	await _button(settings_button)
	var settings: Panel = title.settings_panel
	_expect(settings.visible and not title.menu.visible, "Settings uses the landscape without the main menu underneath.")
	await _frame("03-title-settings")
	await _button(settings.close_button)
	_expect(title.menu.visible and settings_button.has_focus(), "Closing settings restores the title and its focus.")

func _first_harvest() -> void:
	var estate := tree.current_scene
	var tiles := estate.get_node("World/TileMapLayer") as TileMapLayer
	var ui := estate.get_node("UI")
	var hud: Control = ui.hud
	var public_point := tiles.get_global_transform_with_canvas() * tiles.map_to_local(PUBLIC)
	estate.get_node("World").retainer_instances[state.retainers[0]].set_physics_process(false)
	var journal: Control = hud.get_node("Journal")
	var calendar: Control = hud.get_node("Calendar")
	await tree.process_frame
	_expect(journal.get_global_rect().end.y < 240 and calendar.get_global_rect().end.y < 190,
		"The fresh estate HUD leaves the terrain visible below both top cards.")
	await _button(hud.ledger_toggle)
	_expect(hud.ledger_details.visible and hud.king_label.is_visible_in_tree(), "The ledger expands to show the treasury.")
	await _button(hud.ledger_toggle)
	_expect(not hud.ledger_details.visible and calendar.get_global_rect().end.y < 190,
		"Collapsing the ledger releases the map space it covered.")
	await _frame("04-first-field")
	for step in 3:
		await _click(public_point)
	_expect(hud.opening_action.visible and not hud.visitor_label.is_visible_in_tree(),
		"The first-day keeper shortcut is available with the journal collapsed.")
	await _button(hud.journal_details)
	_expect(hud.visitor_label.is_visible_in_tree() and "渠伯" in hud.visitor_label.text and hud.opening_action.visible,
		"The expanded journal shows the keeper's whereabouts alongside his shortcut.")
	await _frame("04a-journal-expanded")
	await _button(hud.journal_details)
	_expect(not hud.visitor_label.is_visible_in_tree(), "The same button collapses the visitor note.")
	await _frame("04a-private-option")
	await _button(hud.first_private_button)
	var private_cell: Vector2i = hud.guide.opening_cell
	var private_point := tiles.get_global_transform_with_canvas() * tiles.map_to_local(private_cell)
	_expect(private_cell != PUBLIC and ui.directions.outline.has_point(private_point),
		"The optional private path points directly to a private plot on day one.")
	await _frame("04b-private-plot")
	await _button(hud.first_private_button)
	_expect(hud.guide.heading.text == "第一次纳贡" and ui.directions.mark == ui.directions.Mark.BUTTON,
		"Return to the tribute route and bedtime shortcut without changing either plot.")
	await _button(hud.first_private_button)
	for step in 3:
		await _click(private_point)
	_expect(state.active_crops[private_cell].watered and not hud.first_private_button.visible,
		"The side task closes after watering and the main guide resumes.")
	await _button(ui.sleep_button)
	await tree.create_timer(1.12).timeout
	await _click(public_point)
	_expect(hud.guide.opening_cell == private_cell and ui.directions.outline.has_point(private_point),
		"The optional path returns to the same planted plot when the public crop has water on day two.")
	await _click(private_point)
	await _button(ui.sleep_button)
	await tree.create_timer(1.12).timeout
	await _click(public_point)
	await _click(private_point)
	_expect(state.current_day == 3 and state.king_storage == 1 and state.player_inventory == 1 and state.money == 5,
		"The title leads into ordinary tilling, watering, overnight growth and separate public and private harvests.")
	await _frame("04c-same-morning-harvests")
	print("TITLE_FIRST_HARVEST day=", state.current_day, " public=", state.king_storage,
		" private=", state.player_inventory, " copper=", state.money)

func _save_and_title() -> void:
	var ui := tree.current_scene.get_node("UI")
	await _button(ui.settings_button)
	var settings: Panel = ui.panel_manager.settings_panel_instance
	await _button(_find_button(settings, "保存游戏"))
	_expect(settings.save_status.text == "游戏已保存", "The usual settings menu saves the current estate.")
	await _button(_find_button(settings, "返回标题"))
	var confirmation := settings.get_node("TitleConfirmation") as ConfirmationDialog
	_expect(confirmation.visible, "Returning still shows its confirmation.")
	confirmation.confirmed.emit()
	await tree.scene_changed

func _save_menu() -> void:
	await _save_and_title()
	var title := tree.current_scene
	_expect(title.continue_button.visible and title.continue_button.has_focus() and title.archive_button.visible
		and "第 3 天" in title.status.text, "Continue is the first focused action and shows the current save date.")
	await _frame("05-continue-title")
	await _button(title.new_button)
	_expect(title.new_confirmation.visible, "New Game asks for a separate estate name when saves exist.")
	title.new_name.text = ESTATE_NAME
	title.new_confirmation.confirmed.emit()
	await tree.scene_changed
	await _save_and_title()
	title = tree.current_scene
	_expect(ESTATE_NAME.length() == title.new_name.max_length and ESTATE_NAME in title.status.text
		and "第 1 天" in title.status.text, "The title displays the full latest estate name and the matching date.")
	await _frame("06-named-estate")
	await _button(title.archive_button)
	var archive: Control = title.get_node("SaveArchive")
	_expect(archive.campaigns.size() == 2 and tree.paused, "The save picker shows both separate estates.")
	await _frame("07-save-picker")
	await _button(archive.close_button)
	await _button(title.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	_expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE and state.campaign_name == ESTATE_NAME
		and state.current_day == 1 and state.active_crops.is_empty(), "The Continue action loads the same estate its caption names.")
	print("TITLE_RESUME name=", state.campaign_name, " day=", state.current_day)

func run(host: SceneTree, directory := "") -> void:
	tree = host
	state = tree.root.get_node("Global")
	capture_dir = directory
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	tree.root.notify_mouse_entered()
	var title := tree.current_scene
	await _opening_menu(title)
	await _button(title.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE, "New Game opens the estate directly."):
		await _first_harvest()
		await _save_menu()
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures > 0 else 0)
