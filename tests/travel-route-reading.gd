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

func _check_readable_label(label: Label, plaque: Control, size: int) -> void:
	_expect(label.is_visible_in_tree() and label.get_theme_font_size(&"font_size") == size
		and plaque.get_global_rect().encloses(label.get_global_rect())
		and label.get_visible_line_count() == label.get_line_count(), "The enlarged travel text fits inside its plaque.")

func _check_cached_bearing() -> void:
	var roads := load("res://scripts/RoadNetwork.gd") as GDScript
	var path := PackedVector2Array([Vector2.ZERO, Vector2(20, 0), Vector2(20, 20), Vector2(40, 20)])
	_expect(roads.next_direction(path, Vector2(14, 0)).is_equal_approx(Vector2.RIGHT)
		and roads.next_direction(path, Vector2(20, 5)).is_equal_approx(Vector2.DOWN),
		"A cached trail points forward on both sides of a bend.")
	_expect(roads.next_direction(path, Vector2(8, -8)).is_equal_approx(Vector2.DOWN)
		and roads.next_direction(path, Vector2(37, 20)).is_zero_approx(),
		"An off-road walker rejoins the trail, and the final approach settles on the destination.")
	var switchback := PackedVector2Array([Vector2.ZERO, Vector2(30, 0), Vector2(30, 8), Vector2(0, 8)])
	_expect(roads.next_direction(switchback, Vector2.ZERO).is_equal_approx(Vector2.RIGHT),
		"A close destination across a bend does not replace the direction of the road.")

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the travel route check with an isolated smoke profile.")
		quit(1)
		return
	paused = true
	_check_cached_bearing()
	var state := root.get_node("Global")
	var events := root.get_node("GameEvents")
	var preferences := root.get_node("Preferences")
	var market := await _load_map(state.WEST_MARKET_SCENE)
	var chart: Control = market.market_map
	var sign: Control = chart.route_sign
	var wallet: Control = market.get_node("UI/Control/MarketName")
	var settings_button: Button = market.get_node("%SettingsButton")
	var font := sign.destination_label.get_theme_font_size(&"font_size") as int
	_expect(preferences.set_reading_size(2) == OK and sign.destination_label.get_theme_font_size(&"font_size") == font + 6,
		"Destination labels follow the reading preference.")
	state.money = 1234567890123456
	state.food_storage = 123456789012345
	events.money_changed.emit(state.money)
	events.food_changed.emit(state.food_storage)
	await _settle()
	var compact := wallet.size.y
	var place: Label = wallet.get_node("Stack/Header/Place")
	var copper: Label = market.stock
	var food: Label = market.food_stock
	_check_readable_label(place, wallet, 26)
	_check_readable_label(market.date, wallet, 22)
	_check_readable_label(copper, wallet, 22)
	_check_readable_label(food, wallet, 22)
	_expect(copper.text == "1234567890123456 铜钱" and food.text == "123456789012345 粮食"
		and food.get_global_rect().position.y >= copper.get_global_rect().end.y
		and wallet.get_global_rect().position.x >= settings_button.get_global_rect().end.x,
		"Long balances keep their units on separate rows and leave settings clear.")
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
	var market_origin: Vector2 = market.player.position
	market.player.position = Vector2(48, 74)
	chart.follow_region_destination("鱼摊")
	chart._process(0.0)
	_expect(sign.direction_label.text == "←", "Approach the fish lane along the westbound stone street.")
	market.player.position = Vector2(-38, 61)
	chart._process(0.0)
	_expect(sign.direction_label.text == "↑" and sign.direction_label.accessibility_name == "向北",
		"At the fish lane, the visible arrow and spoken direction turn north.")
	chart._clear()
	market.player.position = market_origin

	var road := await _load_map(state.WEST_ROAD_SCENE)
	sign = road.route_sign
	var road_plaque: Control = road.get_node("UI/Control/RoadName")
	_check_readable_label(road_plaque.get_node("Stack/Header/Place"), road_plaque, 26)
	_check_readable_label(road.get_node("%Date"), road_plaque, 22)
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
	var road_origin: Vector2 = road.player.position
	road.player.position = Vector2(59, 36)
	road._follow_region_destination("桥东草甸")
	_expect(sign.direction_label.text == "→", "The meadow route stays on the eastbound road before the fork.")
	road.player.position = Vector2(127, 32)
	road._refresh_route()
	_expect(sign.direction_label.text == "↓", "At the meadow fork, the arrow follows the southern branch.")
	road.player.position = Vector2(161, 134)
	road._refresh_route()
	_expect(sign.direction_label.text == "◆" and not sign.step_label.visible,
		"The meadow route settles at the destination and releases the fork instructions.")
	road._clear_regional_trip()
	road.player.position = road_origin

	state.ravine_journal.garden_day = 1
	var ravine := await _load_map(state.WILDERNESS_SCENE)
	var hud: CanvasLayer = ravine.get_node("CampaignHUD")
	var trail_plaque: Control = hud.trail_date.get_parent().get_parent()
	_check_readable_label(hud.trail_date, trail_plaque, 22)
	_check_readable_label(hud.outing_label, trail_plaque, 22)
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
	var walker := ravine.get_node("Player") as Node2D
	var ravine_origin := walker.position
	walker.position = Vector2(223, 27)
	_expect(chart.follow_region_destination("望溪台") and sign.direction_label.text == "→",
		"The lookout sign points along the trail beyond the bridge.")
	var cached: PackedVector2Array = chart.guide.route.duplicate()
	walker.position = RavineLayout.RIDGE_FORK
	chart._process(0.0)
	_expect(sign.direction_label.text == "↗" and chart.guide.route == cached,
		"The lookout arrow follows a bend in the cached trail before the next route calculation.")
	chart.guide.clear()
	walker.position = ravine_origin
	_expect(_snapshot(state, walker) == before, "Fixed route positions do not advance the journey or write a save.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
