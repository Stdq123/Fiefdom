extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _settle() -> void:
	for frame in 4:
		await process_frame

func _load_map(path: String) -> Node:
	if change_scene_to_file(path) != OK:
		push_error("Could not load the paused display at " + path)
		quit(1)
		return null
	await scene_changed
	await _settle()
	return current_scene

func _snapshot(state: Node, walker: Node2D) -> Array:
	return [state.current_day, state.day_progress, state.money, state.food_storage, state.current_stamina,
		state.health, walker.position, hash(state.fish_collection), hash(state.season_order_receipts), state.saved_games().size()]

func _check_layout(sign: Control) -> void:
	var bounds := sign.get_global_rect()
	_expect(sign.visible and root.get_visible_rect().encloses(bounds), "A route sign fits inside the game window.")
	for control: Control in [sign.direction_label, sign.destination_label, sign.step_label, sign.cancel_button]:
		if control.is_visible_in_tree():
			_expect(bounds.encloses(control.get_global_rect()), "The sign fits " + String(control.name))
			if control is Label:
				_expect(control.get_visible_line_count() == control.get_line_count(), "Every wrapped line remains visible.")

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the travel route check with an isolated smoke profile.")
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	var events := root.get_node("GameEvents")
	var preferences := root.get_node("Preferences")
	var market := await _load_map(state.WEST_MARKET_SCENE)
	var chart: Control = market.market_map
	var sign: Control = chart.route_sign
	var wallet: Control = market.get_node("UI/Control/MarketName")
	var compact := wallet.size.y
	var font := sign.destination_label.get_theme_font_size(&"font_size") as int
	_expect(preferences.set_reading_size(2) == OK and sign.destination_label.get_theme_font_size(&"font_size") == font + 6,
		"Destination labels follow the reading preference.")
	var before := _snapshot(state, market.player)
	chart.follow_region_destination(state.WATER_SOURCE)
	await _settle()
	_expect(sign.destination_label.text == "封地 · 水源" and "西市东口" in sign.step_label.text
		and chart.route_target == chart.places[state.MARKET_RETURN], "The route to the spring names the actual east exit.")
	_check_layout(sign)
	events.modal_visibility_changed.emit(true)
	await _settle()
	_expect(not sign.visible and not chart.pin.visible and state.market_trip_target == state.WATER_SOURCE,
		"A covering menu hides the sign and pin without dropping the route.")
	events.modal_visibility_changed.emit(false)
	await _settle()
	sign.cancel_button.grab_focus()
	sign.cancel_button.pressed.emit()
	await _settle()
	_expect(not sign.visible and not chart.pin.visible and chart.open_button.has_focus()
		and state.regional_destination().is_empty() and _snapshot(state, market.player) == before,
		"Cancel clears only directions and restores focus to the map button.")
	_expect(is_equal_approx(wallet.size.y, compact), "The date plaque returns to its compact height after cancelling.")

	var road := await _load_map(state.WEST_ROAD_SCENE)
	sign = road.route_sign
	before = _snapshot(state, road.player)
	road._follow_region_destination(state.MARKET_ORDERS)
	await _settle()
	_expect(sign.destination_label.text == "西市 · 收货牌" and sign.direction_label.text == "←"
		and "西市东口" in sign.step_label.text, "The bridge sign shows the westward leg to market.")
	road._follow_region_destination("柳湾")
	await _settle()
	_expect(sign.destination_label.text == "竹涧 · 柳湾" and sign.direction_label.text == "→"
		and "东关" in sign.step_label.text, "A ravine destination uses the other gate.")
	_check_layout(sign)
	sign.cancel_button.pressed.emit()
	_expect(not sign.visible and state.regional_destination().is_empty() and road.route_direction == Vector2.ZERO
		and _snapshot(state, road.player) == before, "The bridge can cancel without opening a map or walking.")

	state.ravine_journal.garden_day = 1
	var ravine := await _load_map(state.WILDERNESS_SCENE)
	chart = ravine.ravine_map
	sign = chart.route_sign
	before = _snapshot(state, ravine.get_node("Player"))
	_expect(chart.follow_first_field("西门回封地") and "西门" in sign.step_label.text,
		"A return via the west trail shows the west gate.")
	_expect(chart.follow_first_field("南路小径") and "南路小径" in sign.step_label.text
		and sign.destination_label.text == "封地 · 井田 1", "A return via the unlocked shortcut names that trail.")
	_check_layout(sign)
	sign.cancel_button.pressed.emit()
	_expect(not sign.visible and chart.guide.route.is_empty() and state.regional_destination().is_empty()
		and paused and _snapshot(state, ravine.get_node("Player")) == before and state.saved_games().is_empty(),
		"Reading or clearing route signs leaves the paused journey and saves in place.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
