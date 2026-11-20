extends SceneTree

const MISSING := "res://scenes/UnavailableForLoadingReview.tscn"

var state: Node
var travel: Node
var bar: ProgressBar
var progress: Dictionary[String, Array] = {}
var failure := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		push_error("Run loading-feedback with an isolated profile.")
		quit(1)
		return
	state = root.get_node("Global")
	travel = root.get_node("MapTravel")
	bar = travel._session_plate.get_node("%Activity")
	bar.value_changed.connect(_record_progress)
	if change_scene_to_file(state.TITLE_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var title := current_scene
	var initial := _state()

	var missing: Error = await travel.prepare_session(MISSING, "正在读取存档")
	_expect(missing == ERR_FILE_NOT_FOUND and _released(), "Missing destinations return an error without blocking the title.")
	_prepare_estate()
	_expect(travel.active and travel.cover.visible and travel._session_plate.visible
		and bar.indeterminate and travel._session_caption.text == "正在打开封地"
		and travel._session_stage.text == "地图资源", "Draw an honest waiting cue before the first resource query.")
	var busy: Error = await travel.prepare_session(state.WEST_MARKET_SCENE, "正在读取存档")
	_expect(busy == ERR_BUSY, "A second request cannot replace an active load.")
	await travel.finished
	await process_frame
	var estate_stages := {
		"地图资源": state.ESTATE_SCENE,
		"预备关口 · 竹涧": state.WILDERNESS_SCENE,
		"预备关口 · 溪桥道": state.WEST_ROAD_SCENE,
	}
	for stage: String in estate_stages:
		_expect_complete(stage, estate_stages[stage])
	_expect(_released() and current_scene == title and _state() == initial,
		"Preparing real estate assets keeps the title and campaign data intact.")
	var ready: Error = await travel.prepare_session(state.ESTATE_SCENE, "正在打开封地")
	_expect(ready == OK and _released(), "A ready map needs no waiting screen.")

	progress.clear()
	travel.cross(state.WEST_MARKET_SCENE, ^"UnavailableArrivalForReview", ^"Player")
	await travel.finished
	_expect_complete("地图资源", state.WEST_MARKET_SCENE)
	_expect(travel._session_caption.text == "正在前往西市" and current_scene == title and _released(),
		"A cold gate reads only the named map and releases the screen if its arrival marker is missing.")

	title._resume_entry = {"scene": MISSING}
	await title._continue_game()
	_expect(title.status.text == "无法读取存档所需地图。" and title.new_button.has_focus() and _released(),
		"Continue can return to a usable title and report a missing map.")
	title._open_archive()
	var archive := title.get_node("SaveArchive") as Control
	var row := Button.new()
	archive.records.add_child(row)
	row.grab_focus()
	await archive._load({"path": "user://unavailable-for-review.json", "scene": MISSING}, "")
	_expect(paused and archive.status.visible and archive.status.text.begins_with("无法读取这份存档所需的地图")
		and archive.close_button.has_focus() and not row.disabled and _released(),
		"The archive stays open and available when the required map could not be prepared.")
	archive.close_button.pressed.emit()
	await process_frame
	_expect(not paused and title.menu.visible and current_scene == title and _state() == initial
		and state.saved_games().is_empty(), "The loading checks never start or write a campaign.")
	if not failure:
		print("SCENARIO_OK")
	quit(1 if failure else 0)

func _prepare_estate() -> void:
	var result: Error = await travel.prepare_session(state.ESTATE_SCENE, "正在打开封地")
	_expect(result == OK, "The packaged estate scene can be prepared.")

func _record_progress(read: float) -> void:
	if bar.indeterminate or not travel._session_plate.visible or read == 0.0:
		return
	var stage: String = travel._session_stage.text
	if not progress.has(stage):
		progress[stage] = []
	var completed := int(read)
	var total := int(bar.max_value)
	_expect(completed <= total and travel._session_count.text == "%d/%d 项" % [completed, total],
		"The resource count and bar describe the same work in " + stage)
	var history: Array = progress[stage]
	_expect(history.is_empty() or completed > history.back(), "Progress moves forward within " + stage)
	history.append(completed)

func _expect_complete(stage: String, path: String) -> void:
	var history: Array = progress.get(stage, [])
	var expected := ResourceLoader.get_dependencies(path).size() + 1
	_expect(not history.is_empty() and history.back() == expected and travel._preloads.has(path),
		stage + " reaches the actual resource total for " + path)

func _released() -> bool:
	return not travel.active and not travel.cover.visible and not travel._session_plate.visible and not travel.is_processing_input()

func _state() -> Array:
	return [state.campaign_id, state.current_day, state.day_progress, state.money, state.food_storage,
		state.current_stamina, hash(state.active_crops), hash(state.well_fields)]

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failure = true
		push_error(detail)
