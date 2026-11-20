extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect_shape(button: BaseButton, shape: Control.CursorShape, under_pointer := false) -> void:
	if button.get_cursor_shape(button.size * 0.5) != shape:
		failed = true
		push_error("%s has the wrong cursor while disabled=%s." % [button.name, button.disabled])
	if under_pointer and DisplayServer.get_name() != "headless":
		if root.gui_get_hovered_control() != button or int(DisplayServer.cursor_get_shape()) != int(shape):
			failed = true
			push_error("The native cursor must follow the hovered button without another mouse movement.")

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
	var motion := InputEventMouseMotion.new()
	motion.position = size_picker.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)
	await _settle()
	_expect_shape(size_picker, Control.CURSOR_POINTING_HAND, true)
	size_picker.disabled = true
	await _settle()
	_expect_shape(size_picker, Control.CURSOR_ARROW, true)
	size_picker.disabled = false
	await _settle()
	_expect_shape(size_picker, Control.CURSOR_POINTING_HAND, true)
	# A control with its own cursor keeps it across redraws.
	size_picker.mouse_default_cursor_shape = Control.CURSOR_HELP
	size_picker.disabled = true
	await _settle()
	_expect_shape(size_picker, Control.CURSOR_HELP)
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
