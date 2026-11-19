extends SceneTree

var travel: CanvasLayer
var failed := false

func _initialize() -> void:
	_check.call_deferred()

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error(detail)

func _check() -> void:
	var state := root.get_node("Global")
	var events := root.get_node("GameEvents")
	travel = root.get_node("MapTravel")
	if change_scene_to_file(state.TITLE_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	var before := [state.current_day, state.day_progress, state.money]
	for path in [state.ESTATE_SCENE, state.WEST_ROAD_SCENE, state.WEST_MARKET_SCENE, state.WILDERNESS_SCENE]:
		var location: Variant = state.SAVE_SCENES.find_key(path)
		var place: String = "封地" if location == "estate" else state.SAVE_LOCATION_NAMES[location]
		travel.relocate(_under_cover.bind(true), path)
		await travel.finished
		_expect(travel.arrival_plate.visible and travel.arrival_name.text == place,
			"The reveal names the destination without extending the map lock.")
		_expect(not travel.active and not travel.cover.visible, "Release the input lock while the sign is visible.")
		_expect(root.get_visible_rect().encloses(travel.arrival_plate.get_node("Plaque").get_global_rect()),
			"Keep the plaque inside the window.")
	events.modal_visibility_changed.emit(true)
	_expect(not travel.arrival_plate.visible, "A modal dismisses the plaque.")
	travel.relocate(_under_cover.bind(false), state.WEST_MARKET_SCENE)
	await travel.finished
	_expect(not travel.arrival_plate.visible, "A refused crossing leaves no arrival plaque.")
	travel.relocate(_under_cover.bind(true))
	await travel.finished
	_expect(not travel.arrival_plate.visible, "A local relocation only uses the curtain.")
	travel.relocate(_open_paused, state.ESTATE_SCENE)
	await travel.finished
	_expect(paused and not travel.arrival_plate.visible, "A destination modal keeps the arrival area clear.")
	paused = false
	_expect(before == [state.current_day, state.day_progress, state.money], "The layout check preserves estate state.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _under_cover(allowed: bool) -> bool:
	_expect(not travel.arrival_plate.visible and is_equal_approx(travel.cover.color.a, 1.0),
		"Switch the scene with the curtain closed and the old name dismissed.")
	return allowed

func _open_paused() -> bool:
	paused = true
	return _under_cover(true)
