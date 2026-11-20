extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	paused = true
	var state := root.get_node("Global")
	var views := {
		state.ESTATE_SCENE: "World/Landscape/FoliageWind",
		state.WILDERNESS_SCENE: "Landscape/FoliageWind",
		state.WEST_ROAD_SCENE: "Ground/FoliageWind",
		state.WEST_MARKET_SCENE: "Ground/FoliageWind"
	}
	for path: String in views:
		state.current_day = _day(state, "立春")
		if change_scene_to_file(path) != OK:
			_expect(false, "Could not mount the tree artwork in " + path)
			break
		await scene_changed
		current_scene.process_mode = Node.PROCESS_MODE_PAUSABLE
		await process_frame
		var wind := current_scene.get_node(views[path])
		var drift := wind.get_node_or_null("CanopyDrift") as Node2D
		if not _expect(drift != null and drift.visible and drift.petals, "Spring petals are present in " + path):
			continue
		_expect(drift.crowns.any(func(crown) -> bool: return crown.blooms)
			and drift.crowns.any(func(crown) -> bool: return not crown.blooms), "The map has actual bloom and leaf sources.")
		state.current_day = _day(state, "白露")
		wind._refresh_weather()
		wind._process(0.5)
		_expect(drift.visible and not drift.petals and drift.elapsed > 0.0 and drift.wind_phase == wind.phase,
			"Autumn leaves advance with the shared wind phase.")
		var elapsed: float = drift.elapsed
		state.estate_room = state.EstateRoom.HALL
		wind._refresh_room()
		_expect(not drift.visible and not wind.is_processing(), "Indoor rooms hide and pause the canopy effects.")
		state.estate_room = state.EstateRoom.OUTDOORS
		wind._refresh_room()
		_expect(drift.visible and wind.is_processing(), "Autumn wind resumes outside.")
		for term in ["小满", "大雪", state.balance.rain_solar_term]:
			state.current_day = _day(state, term)
			wind._refresh_weather()
			wind._process(0.5)
			_expect(not drift.visible and drift.elapsed == elapsed, "Canopy particles are idle in " + term)
	_expect(state.saved_games().is_empty(), "The fixed views do not write campaign saves.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _day(state: Node, term: String) -> int:
	return state.SOLAR_TERMS.find(term) * state.balance.days_per_solar_term + 1

func _expect(ok: bool, detail: String) -> bool:
	if not ok:
		failed = true
		push_error(detail)
	return ok
