extends SceneTree

var state: Node
var travel: CanvasLayer
var failed := false

func _initialize() -> void:
	_check.call_deferred()

func _expect(valid: bool, description: String) -> void:
	if not valid:
		failed = true
		push_error(description)

func _check() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		quit(1)
		return
	state = root.get_node("Global")
	travel = root.get_node("MapTravel")
	if DisplayServer.get_name() == "headless":
		process_frame.connect(_give_loader_time)
	state.current_day = 5
	state.day_progress = 0.35
	travel.prepare("res://scenes/UnavailableMap.tscn")
	_expect(travel._loading.is_empty(), "An unavailable path does not leave a pending request.")
	if failed or change_scene_to_file(state.ESTATE_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	var ravine: String = state.WILDERNESS_SCENE
	travel.prepare(ravine)
	travel.prepare(ravine)
	_expect(travel._loading.count(ravine) == 1 or travel._preloads.get(ravine) is PackedScene,
		"Two preparations share a single request or an already loaded scene.")
	var deadline := Time.get_ticks_msec() + 8000
	while not travel._loading.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(travel._preloads.get(ravine) is PackedScene and not travel.is_processing(),
		"A completed load is kept for the next travel and stops the polling process.")
	if failed:
		quit(1)
		return
	await process_frame

	# Call the gates on a fixed scene fixture, without walking or advancing the test day.
	await _try_gate(^"World/EastGate")
	if not failed:
		await _try_gate(^"ExitArea")
	if not failed:
		await _try_gate(^"World/WestMarketGate")
	if not failed:
		await _try_gate(^"MarketGate")
	_expect(state.current_day == 5 and state.saved_games().is_empty(), "The test uses one fixed campaign day and no saves.")
	if not failed:
		print("MAP_PREPARATION gates=4 missing_arrivals=4 no_orphans=true")
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _give_loader_time() -> void:
	# Fixed-rate smoke frames run without a display clock or sleep between frames.
	if not travel._loading.is_empty():
		OS.delay_msec(1)

func _try_gate(at: NodePath) -> void:
	var origin := current_scene
	var gate := origin.get_node_or_null(at)
	if gate == null:
		_expect(false, "The fixture has the real map gate " + str(at))
		return
	var destination: String = gate.destination
	var actor_path: NodePath = gate.player_path
	var arrival_path: NodePath = gate.arrival_path
	var clock: float = state.day_progress
	var before := origin.process_mode
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	travel.cross(destination, ^"UnavailableArrival", actor_path)
	await travel.finished
	_expect(current_scene == origin and origin.process_mode == before and not travel.cover.visible and not travel.active,
		"A failed arrival releases input and restores the previous scene.")
	_expect(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) <= orphans,
		"An unmounted destination leaves no orphan nodes.")
	travel.cross(destination, arrival_path, actor_path)
	await travel.finished
	if current_scene == null or current_scene.scene_file_path != destination:
		_expect(false, "The requested map reaches the reveal.")
		return
	var player := current_scene.get_node(actor_path) as Node2D
	var marker := current_scene.get_node(arrival_path) as Node2D
	_expect(player.global_position.is_equal_approx(marker.global_position) and state.day_progress == clock
		and not paused and not travel.cover.visible and not travel.active, "The arriving player is in place before play resumes.")
	var landscape := current_scene.get_node_or_null("World/Landscape")
	if landscape == null:
		landscape = current_scene.get_node_or_null("Landscape")
	if landscape:
		_expect(landscape._scenery_ready, "The first reveal includes the scenery and terrain.")
