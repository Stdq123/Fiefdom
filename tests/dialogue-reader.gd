extends SceneTree

var tree: SceneTree
var screen: Window
var failed := false
var capture_directory := ""
var choice_calls := 0

func _initialize() -> void:
	_review.call_deferred(self)

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _settle() -> void:
	for frame in 8:
		await tree.process_frame

func _capture(view: String) -> void:
	if capture_directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := screen.get_texture().get_image()
	_expect(image.save_png(capture_directory.path_join(view + ".png")) == OK, "Save " + view)
	print("DIALOGUE_READER_FRAME ", view, " window=", screen.size, " pixels=", image.get_size())
	await tree.process_frame

func _key(code: Key, physical_only := false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_NONE if physical_only else code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _pointer(button: MouseButton, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.global_position = position
	event.factor = 1.0
	event.pressed = pressed
	screen.push_input(event, true)

func _pad(button: JoyButton) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await tree.process_frame
	await _settle()

func _estate_snapshot(state: Node, actor: Node) -> Array:
	return [state.current_day, state.day_progress, state.money, state.food_storage, state.current_stamina,
		state.player_inventory, state.active_crops.duplicate(true), state.neighbor_met_days.duplicate(),
		state.pavilion_stories_heard.duplicate(), actor.global_position, state.saved_games().size()]

func _layout(dialog: Control) -> void:
	var frame_rect: Rect2 = dialog.frame.get_global_rect()
	var speech_rect: Rect2 = dialog.speech.get_global_rect()
	var options_rect: Rect2 = dialog.options_container.get_global_rect()
	var footer_rect: Rect2 = dialog.footer.get_global_rect()
	_expect(screen.get_visible_rect().encloses(frame_rect), "The dialogue card fits inside the viewport.")
	_expect(frame_rect.encloses(speech_rect) and frame_rect.encloses(options_rect) and frame_rect.encloses(footer_rect)
		and speech_rect.end.y <= options_rect.position.y and options_rect.end.y <= footer_rect.position.y,
		"The scroll area, choices and reading controls have separate positions inside the card.")
	for choice: Button in dialog.options_container.get_children():
		_expect(options_rect.encloses(choice.get_global_rect()), "The full response button fits in the choice area.")
	if dialog.page_controls.visible:
		for part: Control in [dialog.controls_hint, dialog.page_back, dialog.page_count, dialog.page_forward]:
			_expect(footer_rect.encloses(part.get_global_rect()), "The footer fits the hints and page controls.")

func _review_reader(manager: Node, prior: Button, prefs: Node) -> void:
	var lines := PackedStringArray()
	for index in 45:
		lines.append("第 %d 条 · 看清渠口的水有多深，等过田埂，再看谷穗。" % (index + 1))
	var responses: Array[String] = ["接着听渠伯讲完旧事", "现在开工（体力不足）", "看看井田的水从哪里来", "合上竹简回到田边"]
	var unavailable: Array[int] = [1]
	prior.grab_focus()
	var dialog: Control = manager._open("渠伯", "井田南口", "\n".join(lines), responses, unavailable, null)
	dialog.option_selected.connect(func(_index: int): choice_calls += 1)
	await _settle()
	var last: Button = dialog.choices.back()
	var scrollbar: VScrollBar = dialog.scrollbar
	_expect(dialog.portrait.texture != null and dialog.page_controls.visible and scrollbar.visible, "The long text has its portrait and pagination.")
	_expect(last.has_focus() and dialog.choices.size() == 3 and dialog.options_container.get_child(1).focus_mode == Control.FOCUS_NONE,
		"The initial response focus skips the unavailable choice.")
	var page_total: int = int(dialog.page_count.text.get_slice(" / ", 1))
	_expect(page_total >= 3 and dialog.page_count.text == "1 / %d" % page_total
		and dialog.page_back.disabled and not dialog.page_forward.disabled, "Open at the first page.")
	_layout(dialog)
	await _capture("01-reader-start")

	var position := last.get_global_rect().get_center()
	_pointer(MOUSE_BUTTON_WHEEL_DOWN, position, true)
	var wheel_trip: int = dialog.speech.scroll_vertical
	_expect(wheel_trip > 0 and last.has_focus(), "The wheel reads through the choice row and keeps its focus.")
	_key(KEY_PAGEDOWN)
	var page_trip: int = dialog.speech.scroll_vertical - wheel_trip
	_expect(page_trip > wheel_trip and last.has_focus(), "Page Down reads a full page while a choice is focused.")
	_key(KEY_PAGEUP, true)
	_expect(dialog.speech.scroll_vertical == wheel_trip and last.has_focus(), "Page Up also accepts a physical-only key.")
	var next_at := (dialog.page_forward as Button).get_global_rect().get_center()
	_pointer(MOUSE_BUTTON_LEFT, next_at, true)
	_pointer(MOUSE_BUTTON_LEFT, next_at, false)
	_expect(dialog.speech.scroll_vertical > wheel_trip and choice_calls == 0, "Click Next only turns the page.")
	await _capture("02-reader-middle")

	_expect(prefs.set_binding(&"interact", KEY_PAGEDOWN) == OK, "Page Down can be assigned to the interaction action.")
	dialog.speech.scroll_vertical = 0
	last.grab_focus()
	await _settle()
	_expect("PgDn" not in dialog.page_forward.text and dialog.page_forward.text == "下一页", "The assigned action owns its key hint.")
	_key(KEY_PAGEDOWN)
	_expect(dialog.speech.scroll_vertical == 0 and choice_calls == 0, "Remapping preserves the interaction binding.")
	_key(KEY_TAB)
	_expect(dialog.page_forward.has_focus(), "Tab reaches the next-page button from the choices.")
	_key(KEY_ENTER)
	_expect(dialog.speech.scroll_vertical > 0 and choice_calls == 0, "Enter on the pager works with a remapped shortcut.")
	await _capture("03-reader-remapped")
	_expect(prefs.reset_bindings() == OK, "Restore the isolated reading profile's default keys.")

	last.grab_focus()
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	_expect("RB" in dialog.page_forward.text and last.has_focus(), "The right shoulder reads on and keeps the selected response.")
	for index in page_total:
		if dialog.page_forward.disabled:
			break
		await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(dialog.page_forward.disabled and not dialog.page_back.disabled and dialog.speech.scroll_vertical >= scrollbar.max_value - scrollbar.page - 1.0
		and dialog.page_count.text == "%d / %d" % [page_total, page_total], "The footer shows the last page and disables Next.")
	_layout(dialog)
	await _capture("04-reader-end")
	await _pad(JOY_BUTTON_LEFT_SHOULDER)
	_expect(not dialog.page_forward.disabled and last.has_focus() and choice_calls == 0, "The left shoulder reads back from the last page.")
	await _pad(JOY_BUTTON_B)
	var pad := screen.get_node("GamepadInput")
	_expect(not tree.has_group("dialogue_panel") and prior.has_focus()
		and pad.cursor.position.distance_to(prior.get_global_rect().get_center()) < 2.0, "B restores the previous HUD control and pointer.")
	print("DIALOGUE_READER_READ pages=", page_total, " wheel=", wheel_trip, " page_step=", page_trip,
		" last_page=true focus_restored=", prior.has_focus())

func _review_replacement(manager: Node, actor: Node, prior: Button) -> void:
	var more: Array[String] = ["接着听"]
	var leave: Array[String] = ["离开"]
	var no_disabled: Array[int] = []
	prior.grab_focus()
	var first: Control = manager._open("渠伯", "井田南口", "坐一会，接着读一段。", more, no_disabled, null)
	first.option_selected.connect(func(_index: int):
		manager._open("渠伯", "井田南口", "读罢这段，再回田边。", leave, no_disabled, null)
	)
	await _settle()
	_key(KEY_E)
	var after := tree.get_nodes_in_group("dialogue_panel")
	_expect(after.size() == 1 and after[0] != first and actor.world_controls_blocked(), "Only the successor is active during a replacement.")
	await _settle()
	_expect(not is_instance_valid(first) and actor.conversation_open and after.size() == 1
		and after[0].name == "DialoguePanel", "The successor keeps the conversation lock and the normal node path.")
	_key(KEY_ESCAPE)
	await _settle()
	_expect(not actor.conversation_open and prior.has_focus() and not tree.has_group("dialogue_panel"),
		"Escape returns to the original control at the end of the dialogue.")
	print("DIALOGUE_READER_HANDOFF successor_keeps_lock=true returned_focus=", prior.has_focus())

func _review_estate_cards(ui: Node, state: Node) -> void:
	ui._on_retainer_interacted(state.retainers[0])
	await _settle()
	var neighbor := tree.get_first_node_in_group("dialogue_panel") as Control
	_expect(neighbor != null, "The first resident's card opens through the existing UI entry.")
	if neighbor != null:
		_expect(neighbor.name_label.text == "渠伯" and neighbor.portrait.texture != null
			and not neighbor.page_controls.visible and neighbor.controls_hint.text == "E 继续",
			"The short resident card keeps its portrait, response and current interaction key.")
		_layout(neighbor)
		await _capture("05-first-neighbor")
		_key(KEY_ESCAPE)
		await _settle()

	# Seed the existing warning at its deadline. The estate stays paused.
	var day: int = state.current_day
	var missed: int = state.days_without_contribution
	state.current_day = state.tribute_deadline()
	state.days_without_contribution = state.balance.no_contribution_threshold - 1
	_expect(ui._warn_before_first_tribute("粮仓还有口粮，过夜前也可查看今夜安排。"), "The deadline warning opens through the estate UI.")
	await _settle()
	var warning := tree.get_first_node_in_group("dialogue_panel") as Control
	if warning != null:
		_expect(warning.get_node("%TributeDue").text == "首贡期限 · 今夜到期" and "声望" in warning.text_label.text
			and warning.choices[0].has_focus() and warning.choices.back().text == "仍然过夜",
			"The real tribute warning keeps its deadline, consequence and safer default action.")
		_layout(warning)
		await _capture("06-first-tribute")
		_key(KEY_ESCAPE)
		await _settle()
	state.current_day = day
	state.days_without_contribution = missed
	_expect(not tree.has_group("dialogue_panel"), "The warning closes without choosing an action.")

func _review(scenario: SceneTree) -> void:
	tree = scenario
	screen = tree.root
	var profile := OS.get_user_data_dir()
	if not ("fiefdom-smoke-" in profile or "fiefdom-dialogue-reader-" in profile):
		push_error("Use an isolated profile for the dialogue reading check.")
		tree.quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		capture_directory = args[0]
	tree.paused = true
	AudioServer.set_bus_mute(0, true)
	var state := screen.get_node("Global")
	var prefs := screen.get_node("Preferences")
	_expect(prefs.set_reading_size(2) == OK, "Use the largest reading size.")
	if tree.change_scene_to_file(state.ESTATE_SCENE) != OK:
		tree.quit(1)
		return
	await tree.scene_changed
	var world := tree.current_scene.get_node("World")
	var ui := tree.current_scene.get_node("UI")
	var manager := ui.dialog_manager as Node
	var actor := world.player as Node
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	await _settle()
	var snapshot := _estate_snapshot(state, actor)
	await _review_reader(manager, ui.manage_button, prefs)
	await _review_replacement(manager, actor, ui.manage_button)
	await _review_estate_cards(ui, state)
	_expect(tree.paused and snapshot == _estate_snapshot(state, actor) and state.saved_games().is_empty(),
		"The frozen reading samples keep the estate state and leave no save.")
	var pavilion_review = load("res://tests/PavilionConversationReview.gd").new()
	_expect(await pavilion_review.run(tree, capture_directory), "The pavilion reading samples follow the speakers.")
	if not failed:
		print("DIALOGUE_READER_VIEWS_OK paused=true saves=0 window=", screen.size)
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
