extends SceneTree

var state: Node
var pad: Node
var prefs: Node
var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		push_error("Run the control cue check with an isolated profile.")
		quit(1)
		return
	paused = true
	AudioServer.set_bus_mute(0, true)
	state = root.get_node("Global")
	pad = root.get_node("GamepadInput")
	prefs = root.get_node("Preferences")
	_expect(prefs.set_reading_size(2) == OK, "Use the largest reading size.")
	var background := Button.new()
	background.text = "Background focus target"
	background.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(background)
	var initial := _state()
	await _council()
	await _endings()
	await _fishing()
	await _map_cues()
	_expect(initial == _state() and state.saved_games().is_empty(), "The check only reads interfaces in a paused fixture.")
	pad._use_mouse()
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _council() -> void:
	pad._use_mouse()
	var panel = load("res://scenes/EventPanel.tscn").instantiate()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(panel)
	var choices: Array[Dictionary] = []
	var values: Array = [state.TaxReformChoice.REFORMED, state.TaxReformChoice.TRADITIONAL, state.TaxReformChoice.DELAYED]
	for choice: int in values:
		choices.append({"text": ["改行初税亩", "保留井田制", "延期研究"][choices.size()], "choice_type": choice,
			"levy": "查看当户田赋。", "harvest": "国库 +2 · 私仓 +6", "household": "每夜用粮 3 份",
			"heading": "方案与门槛", "detail": ("可先比较现有收成，再选择一案查看。\n").repeat(16)})
	panel.setup({"title": "初税亩", "speaker": "召简", "text": "请看这份收成账。",
		"ledger": "国库 11 份 · 私仓 5 份", "choices": choices})
	panel.choice_selected.connect(func(_choice: int): _expect(false, "A menu preview must not settle a choice."))
	await _frames(6)
	_expect(panel.selection_label.text.ends_with("Esc 稍后再议") and panel.confirm_button.disabled, "The initial footer describes leaving without a choice.")
	var first: Button = panel.option_buttons[values[0]]
	var second: Button = panel.option_buttons[values[1]]
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_expect(second.has_focus() and panel.confirm_button.disabled and _at(second), "D-pad moves focus across the choice headings.")
	await _pad(JOY_BUTTON_A)
	_expect(panel.selection_label.text.ends_with("B 清除选择") and not panel.confirm_button.disabled
		and panel.selected_choice == values[1], "A previews the focused option and updates the back cue.")
	var scrollbar: VScrollBar = panel.scroll.get_v_scroll_bar()
	_expect(scrollbar.visible, "Long comparison prose uses the scroll control.")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect(scrollbar.has_focus(), "D-pad reaches the comparison scroll.")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect(panel.scroll.scroll_vertical > 0 and scrollbar.has_focus(), "D-pad reads more of the comparison.")
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_expect(panel.confirm_button.has_focus(), "The confirmation is reachable after reviewing a preview.")
	await _pad(JOY_BUTTON_B)
	_expect(panel.confirm_button.disabled and first.has_focus() and _at(first)
		and panel.selection_label.text.ends_with("B 稍后再议"), "B clears the preview and restores the first heading and pointer.")
	await _pad(JOY_BUTTON_B)
	_expect(not is_instance_valid(panel), "B with no selection dismisses the comparison.")

func _endings() -> void:
	var original: Dictionary = state.ending_record
	var ending = load("res://scenes/EstateEnding.tscn")
	for outcome: int in [state.Outcome.TRADITIONAL, state.Outcome.REFORMED]:
		state.ending_record = _record(outcome)
		var archive: Control = ending.instantiate()
		root.add_child(archive)
		archive.close_requested.connect(archive.queue_free)
		archive.open_archive()
		await _frames(4)
		_expect(archive.title_button.text == "返回封地  B", "Both archived routes describe the active gamepad.")
		_tab_inside(archive.report, 12)
		pad._use_mouse()
		_expect(archive.title_button.text == "返回封地  Esc", "Keyboard input restores the Esc cue without reopening.")
		await _pad(JOY_BUTTON_B)
		_expect(not is_instance_valid(archive), "Gamepad B leaves the archived ledger.")
	var report: Control = ending.instantiate()
	root.add_child(report)
	report._populate_record()
	report._show_record()
	await _frames(5)
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_expect(report.replay_button.has_focus() and _at(report.replay_button), "D-pad browses the full settlement footer.")
	var bar: VScrollBar = report.report_scroll.get_v_scroll_bar()
	await _pad(JOY_BUTTON_DPAD_UP)
	_expect(bar.has_focus(), "D-pad reaches the settlement record.")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect(report.report_scroll.scroll_vertical > 0, "D-pad scrolls through longer settlement notes.")
	var reading_position: int = report.report_scroll.scroll_vertical
	report.report.hide()
	report.restore_confirmation.show()
	report._focus_action(report.stay_button)
	await _frames(4)
	_expect(report.stay_button.text == "留在结算  B", "The restore overlay describes its back action.")
	_tab_inside(report.restore_confirmation, 8)
	await _pad(JOY_BUTTON_B)
	_expect(report.report.visible and not report.restore_confirmation.visible and report.restore_button.has_focus(),
		"B closes the restore overlay at its entry control.")
	_expect(report.report_scroll.scroll_vertical == reading_position, "Closing the restore overlay keeps the same passage.")
	report.report.hide()
	report.film.show()
	report.shot = report.Shot.FIELD
	report.skip_button.grab_focus()
	_expect(report.skip_button.text == "跳过结尾  B", "The cutscene skip control describes the same B action.")
	await _pad(JOY_BUTTON_B)
	_expect(report.report.visible and not report.film.visible and report.continue_button.has_focus(), "B skips to the settlement page.")
	report.free()
	state.ending_record = original

func _record(outcome: int) -> Dictionary:
	var account := "新增公田纳贡" if outcome == state.Outcome.TRADITIONAL else "新增计税收成"
	return {"outcome": outcome, "date": "第 48 天 · 冬至",
		"accounts": [{"label": account, "value": 4, "target": 4}],
		"memories": ["记下年成与同伴。".repeat(36), "堂前收起旧账。".repeat(25)]}

func _fishing() -> void:
	var stage := Node2D.new()
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(stage)
	var actor = load("res://scenes/Player.tscn").instantiate()
	var spot = load("res://scripts/FishingSpot.gd").new()
	stage.add_child(actor)
	stage.add_child(spot)
	var panel = load("res://scripts/FishingPanel.gd").new()
	panel.spot = spot
	panel.angler = actor
	stage.add_child(panel)
	panel.set_process(false)
	pad._use_mouse()
	_expect(prefs.set_binding(&"rhythm", KEY_G) == OK, "Set a different rhythm key in the isolated profile.")
	_expect(panel.pull_button.text.ends_with("G") and panel.close_button.text == "收竿 · Esc", "The fishing footer uses the current keyboard shortcut.")
	pad._use_gamepad(31)
	_expect(panel.pull_button.text.ends_with("X") and panel.close_button.text == "收竿 · B", "Fishing instructions follow the device change.")
	stage.free()

func _map_cues() -> void:
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		_expect(false, "Mount the paused estate for the night-sheet cue.")
		return
	await scene_changed
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var ui := current_scene.get_node("UI")
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	ui._show_night_rations()
	var rations := ui.get_node("Control/NightRationsPanel")
	_expect(rations.close_button.tooltip_text == "B", "The night sheet shows the gamepad close shortcut.")
	pad._use_mouse()
	_expect(rations.close_button.tooltip_text == "Esc", "The night sheet switches to Esc.")
	rations.queue_free()
	await _frames(3)
	if change_scene_to_file(state.WILDERNESS_SCENE) != OK:
		_expect(false, "Mount the paused ravine for the settings cue.")
		return
	await scene_changed
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	current_scene.get_node("Landscape").process_mode = Node.PROCESS_MODE_DISABLED
	var settings: Button = current_scene.get_node("CampaignHUD").view.get_node("SettingsButton")
	_expect(settings.tooltip_text == "系统设置  Esc", "The keyboard can find the ravine settings shortcut.")
	pad._use_gamepad(31)
	_expect(settings.tooltip_text == "系统设置  B", "The traveller sees the active gamepad settings shortcut.")

func _tab_inside(card: Control, repeats: int) -> void:
	for backward in [false, true]:
		var escaped := 0
		for step in repeats:
			for pressed in [true, false]:
				var event := InputEventKey.new()
				event.keycode = KEY_TAB
				event.physical_keycode = KEY_TAB
				event.shift_pressed = backward
				event.pressed = pressed
				root.push_input(event, true)
			var focus := root.gui_get_focus_owner()
			escaped += int(focus == null or not card.is_ancestor_of(focus))
		_expect(escaped == 0, "Repeated Tab stays on the active page.")

func _pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 31
		event.button_index = button
		event.pressed = pressed
		pad._window_input(event)
		await _frames(2)
	await _frames(3)

func _at(target: Control) -> bool:
	return pad.active and pad.cursor.position.is_equal_approx(target.get_global_rect().get_center())

func _state() -> Array:
	return [state.current_day, state.day_progress, state.money, state.food_storage, state.current_stamina,
		state.tax_reform_choice, hash(state.active_crops), state.last_fishing_day, hash(state.fish_collection)]

func _frames(count: int) -> void:
	for frame in count:
		await process_frame

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
