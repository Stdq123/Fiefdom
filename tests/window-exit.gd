extends SceneTree

const FIXTURE_CAMPAIGN := "window-exit-save"
const FIXTURE_NAME := "竹影照溪桥田畴渐绿西市夕阳满巷"
const FIXTURE_POINT := Vector2(135, 122)
const PAD_DEVICE := 42

var tree: SceneTree
var state: Node
var pad: Node
var dialog: ConfirmationDialog
var failed := false

func _initialize() -> void:
	_run.call_deferred(self)

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _frames(count: int = 3) -> void:
	for _frame in count:
		await tree.process_frame

func _open_fixture(campaign: String, day: int) -> void:
	tree.paused = true
	state.campaign_id = campaign
	state.campaign_name = FIXTURE_NAME
	state.current_day = day
	state.day_progress = 0.35
	state.outcome = state.Outcome.RUNNING
	state.ending_record.clear()
	_expect(tree.change_scene_to_file(state.ESTATE_SCENE) == OK, "Open the estate with a static day fixture.")
	await tree.scene_changed
	await _frames()
	# Freeze the authoring fixture independently of the pause state under test.
	tree.current_scene.get_node("World").process_mode = Node.PROCESS_MODE_DISABLED

func _cancel_and_wait_for_transitions() -> void:
	await _open_fixture("window-exit-cancel", 4)
	var travel := tree.root.get_node("MapTravel")
	var ui := tree.current_scene.get_node("UI")
	var focus: Button = ui.panel_manager.settings_panel_instance.close_button
	ui.panel_manager.show_settings_panel()
	focus.grab_focus()
	tree.paused = false
	pad.suspend_pointer(true)
	travel.active = true
	tree.root.close_requested.emit()
	tree.root.close_requested.emit()
	await _frames()
	_expect(not dialog.visible and not tree.paused, "Coalesced close requests wait for a scene crossing.")
	ui.sleep_tween = ui.create_tween()
	ui.sleep_tween.tween_interval(15.0)
	travel.active = false
	await _frames()
	_expect(not dialog.visible and not tree.paused, "A close request also waits for the overnight transition.")
	ui.sleep_tween.kill()
	await _frames()
	_expect(dialog.visible and tree.paused and not pad.pointer_suspended and dialog.save_button.has_focus()
		and "本局尚无存档" in dialog.dialog_text and "第 4 天" in dialog.dialog_text,
		"The safe default and present date are visible once both transitions clear.")
	tree.root.close_requested.emit()
	if DisplayServer.get_name() == "headless":
		dialog.get_cancel_button().pressed.emit()
	else:
		_pad_button(JOY_BUTTON_B, true)
		_pad_button(JOY_BUTTON_B, false)
	await _frames()
	_expect(not dialog.visible and not tree.paused and pad.pointer_suspended and focus.has_focus()
		and state.latest_campaign_save().is_empty(), "Cancel returns to the original focus, input mode and pause state without saving.")
	pad.suspend_pointer(false)
	print("WINDOW_EXIT_CANCEL days_unchanged=4 focus_restored=", focus.has_focus())
	await _return_prompt(ui.panel_manager.settings_panel_instance, focus)

func _return_prompt(settings: Panel, opener: Button) -> void:
	var confirmation := settings.get_node("TitleConfirmation") as ConfirmationDialog
	var label := confirmation.get_label()
	var text_size := label.get_theme_font_size(&"font_size")
	var save_size: int = confirmation.save_button.get_theme_font_size(&"font_size")
	var preferences := tree.root.get_node("Preferences")
	confirmation.ask("保存后返回标题。")
	_expect(preferences.set_reading_size(2) == OK, "Select maximum reading size for the save prompt.")
	await _frames()
	_expect(confirmation.visible and confirmation.save_button.has_focus()
		and "第 4 天" in label.text and "本局尚无存档" in label.text
		and label.get_theme_font_size(&"font_size") == text_size + 6
		and confirmation.save_button.get_theme_font_size(&"font_size") == save_size + 6,
		"The Return to Title prompt shows the present day and respects the selected reading size.")
	confirmation.get_cancel_button().pressed.emit()
	await _frames()
	_expect(not confirmation.visible and opener.has_focus() and not tree.paused,
		"Canceling Return to Title restores the prior control and session state.")
	_expect(preferences.set_reading_size(0) == OK, "Restore the test profile's standard reading size.")

func _defeat() -> void:
	await _open_fixture("window-exit-defeat", 7)
	_expect(state.save_game() == OK, "Write a usable checkpoint before the test outcome changes.")
	var path: String = state.manual_save_path()
	var before := FileAccess.get_sha256(path)
	state.current_day = 8
	state.outcome = state.Outcome.DEFEAT_ESTATE
	tree.root.close_requested.emit()
	await _frames()
	_expect(dialog.visible and not dialog.save_button.visible and dialog.get_cancel_button().has_focus()
		and dialog.get_cancel_button().text == "留在结算" and "第 7 天" in dialog.dialog_text,
		"Defeat offers to stay or quit with the old record still available.")
	dialog.get_cancel_button().pressed.emit()
	await _frames()
	_expect(not dialog.visible and tree.paused and FileAccess.get_sha256(path) == before,
		"Staying at defeat preserves the original pause and checkpoint.")
	print("WINDOW_EXIT_DEFEAT checkpoint_preserved=", FileAccess.get_sha256(path) == before)

func _write_close_marker(path: String) -> void:
	var marker := FileAccess.open(path, FileAccess.WRITE)
	if marker == null:
		_expect(false, "Notify the isolated launcher that the close window is ready.")
		return
	var handle := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, tree.root.get_window_id())
	marker.store_string(str(handle))
	marker.close()

func _pad_button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = PAD_DEVICE
	event.button_index = button
	event.pressed = pressed
	tree.root.window_input.emit(event)

func _save_or_discard(args: PackedStringArray) -> void:
	await _open_fixture(FIXTURE_CAMPAIGN, 8)
	var discard := not args.is_empty() and args[0] == "discard"
	var settings: Node = tree.root.get_node("Preferences")
	_expect(settings.set_reading_size(2) == OK, "Select the largest text size in the review profile.")
	_expect(state.save_game() == OK, "Seed the previous manual checkpoint.")
	var path: String = state.manual_save_path()
	var before := FileAccess.get_sha256(path)
	state.current_day = 9
	var actor: Node2D = tree.get_first_node_in_group("player")
	actor.arrive_at_position(FIXTURE_POINT, Vector2.LEFT)
	if args.size() >= 2:
		print("WINDOW_EXIT_WAITING_NATIVE renderer=", RenderingServer.get_current_rendering_method(),
			" driver=", RenderingServer.get_current_rendering_driver_name(), " pixels=", tree.root.size)
		_write_close_marker(args[1])
		for frame in 180:
			if dialog.visible:
				break
			await tree.process_frame
	else:
		tree.root.close_requested.emit()
	await _frames()
	_expect(dialog.visible and tree.paused and dialog.save_button.has_focus()
		and "第 8 天" in dialog.dialog_text and "第 9 天" in dialog.dialog_text,
		"The current state and previous record are distinct, with Save and Exit initially focused.")
	if discard:
		dialog.return_requested.connect(func():
			_expect(FileAccess.get_sha256(path) == before, "Direct Exit preserves the previous checkpoint bytes.")
			_report("WINDOW_EXIT_DISCARD"))
		dialog.get_ok_button().pressed.emit()
		await _frames()
		_expect(false, "Direct Exit should close the game.")
		_finish("WINDOW_EXIT_STILL_OPEN")
		return
	var pending := "%s.%d.tmp" % [path, OS.get_process_id()]
	_expect(DirAccess.make_dir_recursive_absolute(pending) == OK, "Block the test save's temporary path.")
	dialog.save_button.pressed.emit()
	await _frames()
	var label := dialog.get_label()
	_expect(dialog.visible and tree.paused and "保存失败" in label.text and dialog.save_button.has_focus()
		and label.get_line_count() == label.get_visible_line_count() and FileAccess.get_sha256(path) == before,
		"Write failure keeps the whole message readable and leaves the previous checkpoint intact.")
	_expect(DirAccess.remove_absolute(pending) == OK, "Clear the temporary-path test blocker.")
	dialog.return_requested.connect(func():
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var standing: Dictionary = saved.get("walking_checkpoint", {})
		_expect(saved.get("current_day") == 9 and saved.get("location") == "estate"
			and standing.get("x") == FIXTURE_POINT.x and standing.get("y") == FIXTURE_POINT.y
			and standing.get("facing") == "-1,0" and tree.paused and FileAccess.get_sha256(path) != before,
			"A successful retry commits day nine and standing position before exit.")
		_report("WINDOW_EXIT_SAVE_RETRY"))
	if DisplayServer.get_name() == "headless":
		dialog.save_button.pressed.emit()
	else:
		pad.snap_pointer_to_focus()
		await _frames()
		_pad_button(JOY_BUTTON_A, true)
		await _frames()
		_pad_button(JOY_BUTTON_A, false)
	await _frames()
	_expect(false, "Save and Exit should quit after committing the record.")
	_finish("WINDOW_EXIT_STILL_OPEN")

func _restart() -> void:
	if tree.current_scene == null:
		await tree.scene_changed
	var title := tree.current_scene
	_expect(title.scene_file_path == state.TITLE_SCENE and title.continue_button.visible
		and title.continue_button.has_focus() and "第 9 天" in title.status.text and FIXTURE_NAME in title.status.text,
		"A fresh process offers to continue the day-nine estate fixture from the normal title.")
	tree.paused = true
	title.continue_button.pressed.emit()
	await tree.scene_changed
	var actor: Node2D = tree.get_first_node_in_group("player")
	_expect(state.current_day == 9 and tree.current_scene.scene_file_path == state.ESTATE_SCENE
		and actor.global_position.is_equal_approx(FIXTURE_POINT) and actor.facing_direction() == Vector2.LEFT,
		"The loaded day, position and facing match the saved fixture.")
	_finish("WINDOW_EXIT_RESTART")

func _title_close(marker: String) -> void:
	if tree.current_scene == null:
		await tree.scene_changed
	_expect(tree.current_scene.scene_file_path == state.TITLE_SCENE, "Wait for the title's actual close event.")
	_report("WINDOW_EXIT_TITLE_READY")
	_write_close_marker(marker)
	await tree.create_timer(4.0).timeout
	_expect(false, "The Windows close event should exit directly from the title.")
	_finish("WINDOW_EXIT_STILL_OPEN")

func _report(step: String) -> void:
	if not failed:
		print(step)
		print("SCENARIO_OK")

func _finish(step: String) -> void:
	_report(step)
	tree.quit(1 if failed else 0)

func _run(test_tree: SceneTree) -> void:
	tree = test_tree
	var profile := OS.get_user_data_dir()
	if not profile.contains("fiefdom-smoke-") and not profile.contains("fiefdom-window-exit-"):
		push_error("Run window-exit only in an isolated test profile.")
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	pad = tree.root.get_node("GamepadInput")
	dialog = tree.root.get_node("WindowExit/WindowExitConfirmation")
	_expect(not tree.auto_accept_quit, "Let the Windows close event reach the campaign confirmation.")
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0] == "restart":
		await _restart()
		return
	if args.size() >= 2 and args[0] == "title-close":
		await _title_close(args[1])
		return
	if args.is_empty() or args[0] == "native":
		await _cancel_and_wait_for_transitions()
		await _defeat()
	await _save_or_discard(args)
