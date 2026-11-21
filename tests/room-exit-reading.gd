extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error(detail)

func _settle() -> void:
	for frame in 5:
		await process_frame

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run room-exit-reading with an isolated profile.")
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	var preferences := root.get_node("Preferences")
	_expect(preferences.set_reading_size(2) == OK, "Use the largest reading size.")
	state.day_progress = 0.36
	state.silk_workshop.built = true
	await _check_room(state, state.EstateRoom.HALL, "HallInterior", "公田")
	await _check_room(state, state.EstateRoom.SILK_SHED, "SilkInterior", "收货牌")
	_expect(state.saved_games().is_empty(), "The staged rooms do not create saves.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_room(state: Node, room_kind: int, node_name: String, title: String) -> void:
	state.estate_room = room_kind
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		_expect(false, "Load the fixed estate to review " + node_name)
		return
	await scene_changed
	await _settle()
	var world := current_scene.get_node("World")
	var ui := current_scene.get_node("UI")
	var directions: Control = ui.directions
	var room: Node2D = world.get_node(node_name)
	var threshold: CollisionShape2D = room.get_node("Exit/CollisionShape2D")
	var before := [state.current_day, state.day_progress, state.money, state.food_storage, state.current_stamina]
	_expect(room.is_visible_in_tree() and state.estate_room == room_kind, "The fixture is inside " + node_name)
	ui._process(0.0)
	_expect(not directions.visible, "An idle room has no route marker.")
	if title == "公田":
		_expect(ui._follow_tribute_plot(state.TributeRoute.TEND, false), "Mark the public plot from the hall.")
	else:
		ui._on_west_market_directions_requested(state.MARKET_ORDERS)
	var target: Dictionary = directions.destination()
	ui._process(0.0)
	var exit_center := threshold.get_global_transform_with_canvas().origin
	_expect(directions.visible and directions.caption.is_visible_in_tree()
		and directions.caption.text.begins_with("出门后") and title in directions.caption.text
		and directions.outline.get_center().is_equal_approx(exit_center),
		"The actual south threshold displays the tracked destination in " + node_name)
	_expect(not directions.road_guide.visible, "Outdoor paths are hidden while the player is inside.")
	world.player.conversation_open = true
	ui._process(0.0)
	_expect(not directions.visible and directions.destination() == target, "A covering conversation hides only the exit marker.")
	world.player.conversation_open = false
	room._leave_room()
	await _settle()
	ui._process(0.0)
	_expect(state.estate_room == state.EstateRoom.OUTDOORS and directions.destination() == target and directions.visible
		and not directions.caption.text.begins_with("出门后"), "The same destination is shown on the outdoor leg.")
	directions.cancel_tracking()
	_expect(directions.destination().is_empty() and before == [state.current_day, state.day_progress,
		state.money, state.food_storage, state.current_stamina], "Directions and the staged room change preserve the estate accounts and clock.")
