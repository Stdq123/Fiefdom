extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect_shape(button: BaseButton, shape: Control.CursorShape) -> void:
	if button.get_cursor_shape(button.size * 0.5) != shape:
		failed = true
		push_error("%s has the wrong cursor while disabled=%s." % [button.name, button.disabled])

func _settle() -> void:
	for frame in 4:
		await process_frame

func _review() -> void:
	if change_scene_to_file("res://scenes/Title.tscn") != OK:
		quit(1)
		return
	await scene_changed
	current_scene._open_settings()
	await _settle()
	var panel: Control = current_scene.settings_panel
	var size_picker: OptionButton = panel.window_size_picker
	_expect_shape(panel.close_button, Control.CURSOR_POINTING_HAND)
	_expect_shape(size_picker, Control.CURSOR_POINTING_HAND)
	size_picker.disabled = true
	await _settle()
	_expect_shape(size_picker, Control.CURSOR_ARROW)
	size_picker.disabled = false
	await _settle()
	_expect_shape(size_picker, Control.CURSOR_POINTING_HAND)
	# A control with its own cursor keeps it across redraws.
	size_picker.mouse_default_cursor_shape = Control.CURSOR_HELP
	size_picker.disabled = true
	await _settle()
	_expect_shape(size_picker, Control.CURSOR_HELP)
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
