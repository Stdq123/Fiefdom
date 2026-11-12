extends RefCounted

const FIRST_SITE := Vector2i(12, 5)
const SECOND_SITE := Vector2i(1, 11)

var tree: SceneTree
var state: Node
var world: Node
var ui: Node
var tiles: TileMapLayer
var markers: Node
var failures := 0
var capture_dir := ""

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failures += 1
		push_error(detail)
	return condition

func _pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	tree.root.push_input(motion, true)
	await tree.process_frame

func _click(point: Vector2) -> void:
	await _pointer(point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame
	await tree.process_frame

func _button(button: Control) -> void:
	await _click(button.get_global_rect().get_center())

func _point(cell: Vector2i) -> Vector2:
	return tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)

func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for frame in frames:
		await tree.physics_frame
	Input.action_release(action)
	await tree.process_frame

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	tiles = world.tile_map
	markers = tiles.get_node("WellFieldMarker")
	for resident in world.retainer_instances.values():
		resident.set_physics_process(false)
	await tree.process_frame

func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var picture := tree.root.get_texture().get_image()
	_expect(picture.save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)
	print("WORKSITE_FRAME ", name, " ", picture.get_size())

func _sleep() -> String:
	await _button(ui.sleep_button)
	await tree.create_timer(0.62).timeout
	var caption: String = ui.dawn_caption.text
	await tree.create_timer(0.52).timeout
	return caption

func _book(center: Vector2i) -> bool:
	var balance: Resource = state.balance
	var price: int = balance.reclamation_cost_copper * (state.current_rank + 1)
	var grain: int = balance.reclamation_cost_food * (state.current_rank + 1)
	var funds: int = state.money
	var food: int = state.food_storage
	var size: int = state.well_fields.size()
	await _button(ui.reclaim_button)
	var panel: Control = ui.get_node_or_null("Control/ReclamationPanel")
	if not _expect(panel != null, "Open the ordinary reclamation panel."):
		return false
	await _click(_point(center))
	if not _expect(panel.has_selection and panel.selected_cell == center and not panel.reclaim_button.disabled,
		"Select the intended field with the mouse."):
		return false
	await _button(panel.reclaim_button)
	await _button(panel.get_node("Panel/CloseButton"))
	return _expect(state.well_fields.size() == size + 1 and state.money == funds - price and state.food_storage == food - grain,
		"Book the well field and pay the regular cost once.")

func _check_site(field_id: int, stage: int) -> bool:
	var field: Dictionary = state.get_well_field(field_id)
	var marker: Node2D = markers.marker_nodes.get(field_id)
	if not _expect(is_instance_valid(marker) and marker.position == tiles.map_to_local(field.center_pos), "The marker sits at the paid site."):
		return false
	var worksite := marker.get_node_or_null("Worksite")
	var label := marker.get_node("Status") as Label
	var title := state.reclamation_stage(stage) as String
	_expect(field.reclamation_progress == stage and not field.is_unlocked and worksite != null and worksite.stage == stage
		and title in label.text and "%d 夜" % (state.RECLAMATION_NIGHTS - stage) in label.text,
		"The visible stage and nights remaining follow the saved worksite.")
	for y in range(-1, 2):
		for x in range(-1, 2):
			_expect(tiles.get_cell_source_id(field.center_pos + Vector2i(x, y)) == -1, "The active worksite contains no usable field tiles.")
	print("WORKSITE_STAGE field=", field_id + 1, " day=", state.current_day, " stage=", stage, " ", label.text)
	return true

func _check_completed(field_id: int) -> void:
	var field: Dictionary = state.get_well_field(field_id)
	var marker: Node2D = markers.marker_nodes[field_id]
	_expect(field.is_unlocked and field.reclamation_progress == state.RECLAMATION_NIGHTS
		and marker.has_node("Boundary") and not marker.has_node("Worksite"), "The finished field replaces the worksite.")
	for y in range(-1, 2):
		for x in range(-1, 2):
			var cell: Vector2i = field.center_pos + Vector2i(x, y)
			var tile := tiles.get_cell_tile_data(cell)
			_expect(tile != null and tile.get_custom_data("is_public_field") == (x == 0 and y == 0),
				"The finished footprint has one public center and eight private tiles.")

func _continue_latest() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	tree.current_scene.continue_button.pressed.emit()
	await tree.scene_changed
	await _estate()

func _develop_sites() -> bool:
	if not await _book(FIRST_SITE) or not _check_site(1, 0):
		return false
	await _capture("01-survey-stakes")
	await _pointer(_point(FIRST_SITE))
	await tree.process_frame
	var cursor := tiles.get_node("FieldCursor")
	_expect(cursor.visible and "立桩" in cursor.label.text and "再过 4 夜" in cursor.label.text,
		"Hovering the site explains the current stage and when work can begin.")
	var stamina: int = state.current_stamina
	await _click(_point(FIRST_SITE))
	_expect(state.current_stamina == stamina and not state.tilled_cells.has(FIRST_SITE), "Clicking the site cannot farm it yet.")
	await _move(&"ui_down", 145)
	await _button(ui.hud.worksite_button)
	_expect(ui.directions.tracked_site == 1 and ui.directions.mark == ui.directions.Mark.EDGE and ui.directions.edge_direction.y < 0.0,
		"The worksite shortcut points back north from the pavilion.")
	await _move(&"ui_up", 145)
	await _sleep()
	_check_site(1, 1)
	await _capture("02-cleared-ground")
	if not await _book(SECOND_SITE) or not _check_site(2, 0):
		return false
	await _button(ui.hud.worksite_button)
	_expect(ui.directions.tracked_site == 2, "The shortcut finds the nearer southern site.")
	await _move(&"ui_right", 88)
	await _button(ui.hud.worksite_button)
	_expect(ui.directions.tracked_site == 1 and ui.directions.mark == ui.directions.Mark.WORKSITE,
		"Moving toward the eastern site changes which worksite the shortcut follows.")
	await _sleep()
	await _continue_latest()
	_check_site(1, 2)
	_check_site(2, 1)
	_expect(ui.hud.worksite_button.visible and ui.directions.tracked_site < 0, "Continue restores both sites and offers directions.")
	await _capture("03-leveled-ground-after-continue")
	await _button(ui.hud.worksite_button)
	await _sleep()
	_check_site(1, 3)
	_check_site(2, 2)
	await _capture("04-nine-plots-marked")
	await _move(&"ui_right", 88)
	await _button(ui.hud.worksite_button)
	var dawn := await _sleep()
	_check_completed(1)
	_check_site(2, 3)
	_expect("井田 2 已完工" in dawn and ui.directions.tracked_site < 0 and ui.hud.worksite_button.visible,
		"Completion appears at dawn, clears the completed route, and leaves the other site available.")
	print("WORKSITE_DAWN ", dawn.replace("\n", " / "))
	await _capture("05-finished-well-field")
	return true

func _farm_new_field() -> void:
	var private_cell := FIRST_SITE + Vector2i.RIGHT
	for cell in [FIRST_SITE, private_cell]:
		for step in 2:
			await _click(_point(cell))
	_expect(state.active_crops.has(FIRST_SITE) and state.active_crops.has(private_cell), "Both new plots accept planting through the ordinary field controls.")
	var dawn := await _sleep()
	_check_completed(2)
	_expect("井田 3 已完工" in dawn and not ui.hud.worksite_button.visible, "The last completed site clears the journal shortcut.")
	for cell in [FIRST_SITE, private_cell]:
		await _click(_point(cell))
	await _sleep()
	var money: int = state.money
	for cell in [FIRST_SITE, private_cell]:
		await _click(_point(cell))
	_expect(state.king_storage == 2 and state.player_inventory == 1 and state.money == money + ItemManager.get_crop("millet").sell_price,
		"Harvest on the new field credits public and private production exactly once.")
	print("WORKSITE_HARVEST day=", state.current_day, " treasury=", state.king_storage, " private=", state.player_inventory)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the worksite replay's profile."):
		tree.quit(1)
		return
	seed(982)
	capture_dir = OS.get_environment("FIEFDOM_WORKSITE_CAPTURES")
	if tree.root.size.x < 900:
		tree.root.size = Vector2i(1280, 720)
	tree.root.notify_mouse_entered()
	state = tree.root.get_node("Global")
	# Use a funded expansion save so both sites can be ordered through the normal UI.
	var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"current_day": 2, "current_rank": state.Rank.SHANG_SHI, "king_storage": 1, "reputation": 150,
		"money": 620, "food_storage": 260,
		"retainers": [{"name": "渠伯"}, {"name": "季青"}, {"name": "石墨"}],
	}))
	file.close()
	await _continue_latest()
	_expect(not ui.hud.worksite_button.visible, "The shortcut appears after commissioning a site.")
	if await _develop_sites():
		await _farm_new_field()
	tree.unload_current_scene()
	for stream in tree.root.get_node("AudioManager").get_children():
		if stream is AudioStreamPlayer:
			stream.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
