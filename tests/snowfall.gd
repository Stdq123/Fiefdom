extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	paused = true
	var state := root.get_node("Global")
	var light_day := _day(state, "小雪")
	var heavy_day := _day(state, "大雪")
	var clear_day := _day(state, "冬至")
	var rain_day := _day(state, state.balance.rain_solar_term)
	var views := {
		state.ESTATE_SCENE: "World/Landscape/Rain",
		state.WILDERNESS_SCENE: "Landscape/Rain",
		state.WEST_ROAD_SCENE: "Rain",
		state.WEST_MARKET_SCENE: "Rain",
	}
	for path: String in views:
		state.current_day = light_day
		if change_scene_to_file(path) != OK:
			_expect(false, "Cannot mount the weather scene " + path)
			break
		await scene_changed
		current_scene.process_mode = Node.PROCESS_MODE_PAUSABLE
		await process_frame
		var veil := current_scene.get_node(views[path]) as Node2D
		var light_count: int = veil.snowflake_count
		_expect(light_count > 0 and veil.visible and veil.is_processing() and not veil.splashes.visible,
			"Light snow uses the shared outdoor veil in " + path)
		state.current_day = heavy_day
		veil._refresh()
		_expect(veil.snowflake_count > light_count and veil.visible and not veil.splashes.visible,
			"Heavy snow adds flakes in " + path)
		for room: int in [state.EstateRoom.HALL, state.EstateRoom.SILK_SHED]:
			state.estate_room = room
			veil._refresh()
			_expect(not veil.visible and not veil.is_processing() and veil.snowflake_count == 0, "Rooms stop the snowfall.")
		state.estate_room = state.EstateRoom.OUTDOORS
		state.current_day = clear_day
		veil._refresh()
		_expect(not veil.visible and not veil.is_processing(), "The air stays clear on the winter solstice in " + path)
		state.current_day = rain_day
		veil._refresh()
		_expect(veil.visible and veil.is_processing() and veil.splashes.visible and veil.snowflake_count == 0,
			"Grain Rain still uses rain streaks and contact splashes in " + path)
	_expect(state.saved_games().is_empty(), "The weather fixture leaves saves untouched.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _day(state: Node, term: String) -> int:
	return state.SOLAR_TERMS.find(term) * state.balance.days_per_solar_term + 1

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
