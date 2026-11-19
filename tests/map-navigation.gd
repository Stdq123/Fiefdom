extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _tab(backward: bool) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.physical_keycode = KEY_TAB
		event.shift_pressed = backward
		event.pressed = down
		root.push_input(event, true)
	await process_frame

func _run() -> void:
	var background := Button.new()
	background.text = "HUD"
	root.add_child(background)
	var map = load("res://scenes/RegionMap.tscn").instantiate()
	root.add_child(map)
	map.setup(map.Region.ROAD, func(): return false, func(): return "收货牌",
		func(_place: String) -> bool:
			_expect(false, "Preview must not confirm a new destination.")
			return false,
		func(): _expect(false, "Preview must not clear the current route."),
		null, Callable(), func(): return Vector2(0.5, 0))
	map.open_map()
	await process_frame
	_expect(map.active_route.text == "当前指路 · 收货牌" and not map.preview_badge.visible,
		"The open map identifies the current route.")
	map.region_buttons.get_child(map.Region.RAVINE).pressed.emit()
	map.destination_buttons["柳湾"].pressed.emit()
	await process_frame
	_expect(map.active_route.text == "当前指路 · 收货牌" and map.preview_badge.visible
		and map.route_button.text == "指路去柳湾" and not map.place_detail.text.is_empty(),
		"The preview shows a new destination without replacing the current one.")
	var modal: Control = map.modal
	for backward in [false, true]:
		for step in 24:
			await _tab(backward)
			var focus := root.gui_get_focus_owner()
			_expect(focus != null and modal.is_ancestor_of(focus), "Tab must stay in the open map.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
