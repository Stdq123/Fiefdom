extends SceneTree

const SLOT := "user://savegame.json"
const MARKET_SAVE := {"current_day": 9, "money": 37, "location": "west_market"}

var state: Node
var travel: CanvasLayer
var failed := false
var arrivals := 0

func _initialize() -> void:
	_run.call_deferred()

func _expect(valid: bool, detail: String) -> void:
	if not valid:
		failed = true
		push_error(detail)

func _show_title() -> Node:
	if change_scene_to_file(state.TITLE_SCENE) != OK:
		return null
	await scene_changed
	await process_frame
	return current_scene

func _write_save(data: String) -> String:
	var handle := FileAccess.open(SLOT, FileAccess.WRITE)
	if handle == null:
		_expect(false, "Write the isolated archive fixture.")
		return ""
	handle.store_string(data)
	handle.close()
	return FileAccess.get_sha256(SLOT)

func _expect_loading(caption: String) -> void:
	_expect(travel.active and travel.cover.visible and travel._session_plate.visible
		and travel._session_caption.text == caption, "A cold entry displays its loading message before loading.")

func _expect_revealed() -> void:
	_expect(not travel.active and not travel.cover.visible and travel.cover.color.a == 0.0
		and not travel._session_plate.visible, "The session releases its screen cover and input.")

func _new_estate(title: Node) -> void:
	var events := root.get_node("GameEvents")
	events.estate_arrived.connect(func(): arrivals += 1)
	var initial_campaign: String = state.campaign_id
	title.new_button.pressed.emit()
	_expect_loading("正在打开封地")
	title.new_button.pressed.emit()
	await process_frame
	_expect(current_scene == title and state.campaign_id == initial_campaign,
		"Keep the title in place during the first loading frame and ignore an extra press.")
	await scene_changed
	await process_frame
	_expect(state.current_day == 1 and current_scene.scene_file_path == state.ESTATE_SCENE
		and arrivals == 1 and state.saved_games().is_empty(), "One request starts one estate without writing a save.")
	_expect(travel._preloads.has(state.ESTATE_SCENE) and travel._preloads.has(state.WILDERNESS_SCENE)
		and travel._preloads.has(state.WEST_ROAD_SCENE), "The estate and its two neighboring gates are ready at entry.")
	_expect_revealed()

func _continue_market() -> void:
	var checksum := _write_save(JSON.stringify(MARKET_SAVE))
	var title := await _show_title()
	if title == null:
		_expect(false, "Open the title for the saved market fixture.")
		return
	_expect(title.continue_button.has_focus() and state.latest_saved_game()["scene"] == state.WEST_MARKET_SCENE,
		"Continue points at the map recorded by the save.")
	title.continue_button.pressed.emit()
	_expect_loading("正在读取存档")
	await scene_changed
	_expect(current_scene.scene_file_path == state.WEST_MARKET_SCENE and state.current_day == 9
		and state.money == 37 and FileAccess.get_sha256(SLOT) == checksum, "Resume the market fixture without altering its record.")
	_expect_revealed()

func _select_save() -> void:
	var title := await _show_title()
	if title == null:
		_expect(false, "Open the title for archive selection.")
		return
	title.archive_button.pressed.emit()
	var archive := title.get_node("SaveArchive") as Control
	var row := archive.records.get_child(0) as Button
	_expect(paused and not row.disabled, "The save picker exposes the fixture before the file changes.")
	_write_save("[]")
	travel._preloads.erase(state.WEST_MARKET_SCENE)
	row.pressed.emit()
	_expect_loading("正在读取存档")
	await travel.finished
	await process_frame
	_expect(current_scene == title and paused and row.disabled and archive.close_button.has_focus()
		and archive.status.visible, "An unavailable file leaves the picker open with a readable error and return focus.")
	_expect_revealed()
	archive.close_button.pressed.emit()
	await process_frame
	_expect(not paused and title.menu.visible and title.archive_button.has_focus(), "Close returns to the title at the same menu item.")
	var checksum := _write_save(JSON.stringify(MARKET_SAVE))
	title.archive_button.pressed.emit()
	archive = title.get_node("SaveArchive") as Control
	archive.records.get_child(0).pressed.emit()
	await scene_changed
	_expect(not paused and current_scene.scene_file_path == state.WEST_MARKET_SCENE
		and FileAccess.get_sha256(SLOT) == checksum, "A restored archive entry resumes the original record.")
	_expect_revealed()

func _run() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		quit(1)
		return
	state = root.get_node("Global")
	travel = root.get_node("MapTravel")
	var title := await _show_title()
	if title == null:
		quit(1)
		return
	await _new_estate(title)
	if not failed:
		await _continue_market()
	if not failed:
		await _select_save()
	if not failed:
		print("SESSION_LOADING new=ok continue=market archive_failure=restored archive_retry=ok")
		print("SCENARIO_OK")
	quit(1 if failed else 0)
