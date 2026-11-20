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
	_expect(map.active_route.text == "当前指路 · 收货牌" and map.active_swatch.visible and not map.preview_badge.visible,
		"The open map identifies the current route.")
	map.region_buttons.get_child(map.Region.RAVINE).pressed.emit()
	map.destination_buttons["柳湾"].pressed.emit()
	await process_frame
	_expect(map.active_route.text == "当前指路 · 收货牌" and map.preview_badge.visible
		and map.active_swatch.visible and map.preview_swatch.visible
		and map.route_button.text == "指路去柳湾" and not map.place_detail.text.is_empty(),
		"The preview shows a new destination without replacing the current one.")
	_check_paths(map)
	var modal: Control = map.modal
	for backward in [false, true]:
		for step in 24:
			await _tab(backward)
			var focus := root.gui_get_focus_owner()
			_expect(focus != null and modal.is_ancestor_of(focus), "Tab must stay in the open map.")
	var meadow_click := InputEventMouseButton.new()
	meadow_click.button_index = MOUSE_BUTTON_LEFT
	meadow_click.position = map.MEADOW_ICON + Vector2(0, 30)
	map.paper.gui_input.emit(meadow_click)
	_expect(map.selected_place == "桥东草甸" and map.active_route.text == "当前指路 · 收货牌",
		"Clicking the meadow caption still selects its preview.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_paths(map: Control) -> void:
	var bridge := Vector2(0.35, 0.0)
	var foot: Vector2 = map._road_point(bridge)
	var market: PackedVector2Array = map._route_points("收货牌", bridge)
	var ravine: PackedVector2Array = map._route_points("柳湾", bridge)
	_expect(market[0] == foot and ravine[0] == foot and market[1].x < foot.x and ravine[1].x > foot.x
		and market[-1] == map.POINTS[map.Region.MARKET] and ravine[-1] == map.POINTS[map.Region.RAVINE],
		"The two directions begin at the real bridge position and cover only the remaining roads.")
	var outward: PackedVector2Array = map._route_points("水源", bridge)
	_expect(ravine.slice(0, outward.size()) == outward,
		"A longer route shares the part of the road the player still has to walk.")

	var meadow := Vector2(0.75, 0.78)
	var from_trail: PackedVector2Array = map._route_points("收货牌", meadow)
	var to_meadow: PackedVector2Array = map._route_points("桥东草甸", meadow)
	_expect(from_trail[0] == to_meadow[0] and from_trail[1] == map.MEADOW_BEND
		and from_trail[2] == map.MEADOW_TURN and to_meadow.size() == 2 and to_meadow[-1] == map.MEADOW_ICON,
		"The route out of the meadow returns through the turn and the preview ahead goes straight to the stop.")
	var already_there: PackedVector2Array = map._route_points("桥东草甸", Vector2(0.75, 1.0))
	_expect(already_there == PackedVector2Array([map.MEADOW_ICON]), "The meadow stop needs no route when already reached.")

	var state := root.get_node("Global")
	var garden_day: int = state.ravine_journal.garden_day
	var saved_region: int = map.region
	var south_trail: Callable = map.uses_south_trail
	map.region = map.Region.ESTATE
	map.uses_south_trail = func(place: String) -> bool: return place == "砾滩"
	state.ravine_journal.garden_day = 1
	var north: PackedVector2Array = map._route_points("柳湾", Vector2.ZERO)
	var south: PackedVector2Array = map._route_points("砾滩", Vector2.ZERO)
	var local: PackedVector2Array = map._route_points("水源", Vector2.ZERO)
	_expect(north == PackedVector2Array(map.EAST_TRAIL) and south == PackedVector2Array(map.SHORTCUT)
		and local == PackedVector2Array([map.POINTS[map.Region.ESTATE]]),
		"Two ravine destinations can branch through different gates and a local stop stays within the region.")
	state.ravine_journal.garden_day = 0
	_expect(map._route_points("砾滩", Vector2.ZERO) == north, "The locked shortcut never replaces the gate path.")
	state.ravine_journal.garden_day = garden_day
	map.uses_south_trail = south_trail
	map.region = saved_region
