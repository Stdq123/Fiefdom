extends "res://tests/CanalFlowReplay.gd"

const PUBLIC := Vector2i(5, 5)
const PRIVATE := [Vector2i(6, 4), Vector2i(6, 5), Vector2i(6, 6)]
const STARTER := [Vector2i(2, 5), Vector2i(3, 5)]
const RICE := Vector2i(4, 5)

var baseline := false
var legacy := false

func _open_from_title(continue_game := false) -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	var title := tree.current_scene
	await _button(title.continue_button if continue_game else title.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await _estate()

func _walk_to_source() -> void:
	var water: Vector2 = world.get_crop_world_pos(state.irrigation.source_cell)
	await Campaign.walk_to(tree, world.player, world.to_global(water + Vector2(-9, 12)))
	await tree.physics_frame

func _source_dialog() -> Control:
	await _walk_to_source()
	await _key(KEY_E)
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	_expect(dialog != null and dialog.name_label.text == "水源", "Use the interact key at the spring.")
	return dialog

func _close_management(panel: Control) -> void:
	await _button(panel.close_button)

func _show_section(index: int) -> Control:
	await _button(ui.manage_button)
	var panel: Control = ui.panel_manager.management_panel_instance
	await _button(panel.section_buttons[index])
	return panel

func _read(panel: Control) -> void:
	_expect(panel.visible and panel.read_button.is_visible_in_tree() and not panel.read_button.disabled,
		"The six arts page offers today's reading.")
	await _button(panel.read_button)
	await _close_management(panel)

func _sleep() -> void:
	await _button(ui.sleep_button)
	await tree.create_timer(1.12).timeout

func _first_study() -> void:
	await _walk_to_source()
	await _capture("01-water-source")
	if baseline:
		await _key(KEY_E)
		_expect(not ui.has_node("Control/DialoguePanel"), "The previous spring is scenery when inspected.")
		await _read(await _show_section(2))
		return
	var spring: Node2D = world.irrigation_overlay.water_source
	_expect(world.player.interaction_target == spring and "E" in spring.hint.text,
		"The spring label names the interaction key at the correct tile.")
	var dialog := await _source_dialog()
	if dialog == null:
		return
	_expect("书艺 1/3" in dialog.text_label.text and "渠水" in dialog.text_label.text
		and dialog.choices[0].text == "去研读", "The spring explains how to learn waterworks on day one.")
	await _capture("02-reading-cue")
	await _button(dialog.choices[0])
	await _read(ui.panel_manager.management_panel_instance)

func _unlock_irrigation() -> void:
	var panel: Control
	if baseline:
		panel = await _show_section(3)
	else:
		await _walk_to_source()
		var pad = load("res://tests/GamepadReplay.gd").new()
		pad.tree = tree
		pad.pad = tree.root.get_node("GamepadInput")
		await pad._tap(JOY_BUTTON_X)
		var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
		if not _expect(dialog != null and dialog.choices[0].text == "打开科技" and "书艺已达 3 级" in dialog.text_label.text,
			"The controller opens the spring and sees that waterworks can be learned."):
			return
		await _capture("03-controller-technology-cue")
		await pad._tap(JOY_BUTTON_DPAD_LEFT)
		await pad._tap(JOY_BUTTON_A)
		await pad._mouse_handoff()
		_expect(pad.failures == 0, "Keyboard and mouse can take over from the controller.")
		panel = ui.panel_manager.management_panel_instance
	_expect(panel.visible and panel.irrigation_button.is_visible_in_tree() and not panel.irrigation_button.disabled,
		"The usual technology page is ready to unlock waterworks.")
	await _button(panel.irrigation_button)
	_expect(state.tech_unlocked["irrigation"] and not ui.channel_button.disabled, "Use the normal technology button.")
	await _close_management(panel)

func _dig_first_channel() -> void:
	if baseline:
		await _button(ui.channel_button)
	else:
		var dialog := await _source_dialog()
		if dialog == null:
			return
		var price: int = 2 * state.channel_cost()
		_expect("共需 %d 铜钱" % price in dialog.text_label.text and dialog.choices[0].text == "标出引水位置",
			"The unlocked spring prices both new cells before editing.")
		await _capture("04-first-channel-price")
		await _button(dialog.choices[0])
		_expect(world.channel_mode and world.irrigation_overlay.starter_canal == STARTER and state.money == 15
			and "共 8 铜钱" in ui.hud.canal_preview.text,
			"The suggestion marks the real cells without spending copper.")
		await _capture("05-starter-canal")
	await _click(_point(STARTER[0]))
	_expect(state.irrigation.is_channel_wet(STARTER[0]) and not state.irrigation.supplies(RICE),
		"The first outlet flows and stops one tile short of the field.")
	if not baseline:
		_expect(world.irrigation_overlay.starter_canal == [STARTER[1]], "Only the remaining stretch is marked.")
	await _click(_point(STARTER[1]))
	_expect(state.irrigation.supplies(RICE) and state.money == 7 and "已通水" in ui.help_label.text,
		"Two actual map clicks feed the field and charge eight copper.")
	if not baseline:
		_expect(world.irrigation_overlay.starter_canal.is_empty(), "The starter guide clears once a field is supplied.")
	await _key(KEY_ESCAPE)
	await _pointer(Vector2(650, 14))
	await _capture("06-connected")

func _save_from_settings() -> void:
	await _button(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	if not _expect(settings.visible, "Open the regular settings before saving."):
		return
	await _button(settings.save_button)
	_expect("游戏已保存" in settings.save_status.text, "Write a normal manual save.")
	await _button(settings.close_button)

func _check_resume() -> void:
	await _open_from_title(true)
	_expect(state.current_day == 6 and state.king_storage == 1 and state.money == 7
		and state.irrigation.supplies(RICE) and state.active_crops.get(RICE, {}).get("age") == 1,
		"Continue preserves the private rice, public tribute, copper and water network.")
	var dialog := await _source_dialog()
	if dialog == null:
		return
	_expect("1 块井田接水" in dialog.context_label.text and "供到 1 格田" in dialog.text_label.text
		and dialog.choices[0].text == "进入挖渠", "The spring reports actual coverage after loading.")
	await _capture("07-restored-coverage")
	await _button(dialog.choices.back())
	print("SPRING_RESUME day=", state.current_day, " copper=", state.money, " tribute=", state.king_storage)

func _check_cut_and_harvest() -> void:
	await _button(ui.channel_button)
	await _click(_point(STARTER[0]), true)
	await _key(KEY_ESCAPE)
	await _sleep()
	_expect(state.active_crops[RICE].age == 1, "Dry rice stops growing through a night.")
	await _button(ui.channel_button)
	await _click(_point(STARTER[0]))
	await _key(KEY_ESCAPE)
	for night in 3:
		await _sleep()
	await _click(_point(RICE))
	_expect(not state.active_crops.has(RICE) and state.money == 15 and state.king_storage == 1,
		"The reconnected crop matures into private income and preserves the public share.")
	print("SPRING_HARVEST day=", state.current_day, " copper=", state.money, " tribute=", state.king_storage)

func _new_campaign() -> void:
	await _open_from_title()
	_expect(ui.channel_button.disabled, "Digging starts locked.")
	await _first_study()
	if failed:
		return
	var crops: Array[Vector2i] = [PUBLIC]
	crops.append_array(PRIVATE)
	for cell in crops:
		await _click(_point(cell))
		await _click(_point(cell))
		await _click(_point(cell))
	await _sleep()
	for cell in crops:
		await _click(_point(cell))
	await _read(await _show_section(2))
	await _sleep()
	for cell in crops:
		await _click(_point(cell))
	_expect(state.king_storage == 1 and state.money == 15, "Three private crops earn the first copper beside one public tribute.")
	await _key(KEY_3)
	await _click(_point(RICE))
	await _click(_point(RICE))
	_expect(state.tilled_cells.has(RICE) and not state.active_crops.has(RICE), "Dry land cannot take new rice.")
	for night in 2:
		await _read(await _show_section(2))
		await _sleep()
	await _read(await _show_section(2))
	await _unlock_irrigation()
	if failed:
		return
	await _dig_first_channel()
	if not _expect(not failed and not world.channel_mode, "Return to farming after digging."):
		return
	await _click(_point(RICE))
	if not _expect(state.active_crops.has(RICE) and state.active_crops[RICE].requires_channel,
		"The supplied plot accepts rice."):
		return
	await _sleep()
	_expect(state.active_crops[RICE].age == 1, "The rice grows through a night using channel water.")
	await _save_from_settings()
	if baseline:
		print("SPRING_BASELINE day=", state.current_day, " copper=", state.money, " tribute=", state.king_storage)
	if not baseline and not failed:
		await _check_resume()
		if not failed:
			await _check_cut_and_harvest()

func run_irrigation(game_tree: SceneTree, capture_path := "") -> void:
	tree = game_tree
	state = tree.root.get_node("Global")
	captures = capture_path
	if _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the irrigation replay's save."):
		tree.root.notify_mouse_entered()
		if legacy:
			await _check_resume()
		else:
			await _new_campaign()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
