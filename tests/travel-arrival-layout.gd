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
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		quit(1)
		return
	var state := root.get_node("Global")
	var events := root.get_node("GameEvents")
	travel = root.get_node("MapTravel")
	var preferences := root.get_node("Preferences")
	_expect(preferences.set_reading_size(2) == OK and travel.arrival_name.get_theme_font_size(&"font_size") == 31
		and travel.arrival_note.get_theme_font_size(&"font_size") == 22,
		"The arrival title and gate note follow the reading preference.")
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
		_expect(not travel.arrival_note.is_visible_in_tree(), "An arrival without a gate note keeps the compact plaque.")
		_expect(not travel.active and not travel.cover.visible, "Release the input lock while the sign is visible.")
		var plaque: Control = travel.arrival_plate.get_node("Plaque")
		_expect(root.get_visible_rect().encloses(plaque.get_global_rect()) and plaque.is_in_group(&"interaction_prompt_obstacle"),
			"Keep the plaque inside the window and reserve its space for nearby prompts.")
	await _check_gate_notes(state)
	travel.relocate(_under_cover.bind(true), state.WEST_ROAD_SCENE)
	await travel.finished
	_expect(travel.arrival_note.text.is_empty() and not travel.arrival_note.is_visible_in_tree(),
		"A plain reveal after crossing clears the previous gate note.")
	events.modal_visibility_changed.emit(true)
	_expect(not travel.arrival_plate.visible, "A modal dismisses the plaque.")
	travel.relocate(_under_cover.bind(false), state.WEST_MARKET_SCENE, "西市东口 · 石板街通各摊")
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

func _check_gate_notes(state: Node) -> void:
	var gates := {
		state.ESTATE_SCENE: {"World/WestMarketGate": "向西过桥", "World/EastGate": "竹涧西门", "World/RavineTrailGate": "浅滩"},
		state.WEST_ROAD_SCENE: {"MarketGate": "西市东口", "EstateGate": "封地西关"},
		state.WEST_MARKET_SCENE: {"EstateRoad": "向东过桥"},
		state.WILDERNESS_SCENE: {"ExitArea": "封地东关", "SouthTrailGate": "竹涧小径"},
	}
	var seen: Dictionary[String, bool] = {}
	for path: String in gates:
		var source := (load(path) as PackedScene).instantiate()
		for name: String in gates[path]:
			var gate := source.get_node(name)
			var note: String = gate.arrival_note
			_expect(gates[path][name] in note and not seen.has(note), "The authored gate supplies distinct context: " + name)
			seen[note] = true
			travel.relocate(_under_cover.bind(true), gate.destination, note)
			await travel.finished
			var plaque: Control = travel.arrival_plate.get_node("Plaque")
			_expect(travel.arrival_note.is_visible_in_tree() and travel.arrival_note.text == note
				and root.get_visible_rect().encloses(plaque.get_global_rect())
				and travel.arrival_note.get_visible_line_count() == travel.arrival_note.get_line_count(),
				"The gate note fits at the largest reading size.")
			if name == "MarketGate":
				await create_timer(1.2).timeout
				_expect(travel.arrival_plate.visible and not travel.active and not travel.cover.visible,
					"The longer gate note stays readable after the curtain releases input.")
		source.free()
	_expect(seen.size() == 8, "All outdoor entries have their own context.")

func _under_cover(allowed: bool) -> bool:
	_expect(not travel.arrival_plate.visible and is_equal_approx(travel.cover.color.a, 1.0),
		"Switch the scene with the curtain closed and the old name dismissed.")
	return allowed

func _open_paused() -> bool:
	paused = true
	return _under_cover(true)
