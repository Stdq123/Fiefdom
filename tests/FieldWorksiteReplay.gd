extends RefCounted

const FIRST_SITE := Vector2i(12, 5)
const SECOND_SITE := Vector2i(8, 11)
const OLD_ROAD_SITE := Vector2i(1, 11)

var tree: SceneTree
var state: Node
var world: Node
var ui: Node
var tiles: TileMapLayer
var markers: Node
var failures := 0
var capture_dir := ""
var legacy := false

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

func _check_obstructed_sites() -> void:
	var money: int = state.money
	var food: int = state.food_storage
	var south_lane := Vector2i(1, 8)
	await _button(ui.reclaim_button)
	var panel: Control = ui.get_node("Control/ReclamationPanel")
	await _click(_point(south_lane))
	_expect(panel.selected_cell == south_lane and panel.reclaim_button.disabled
		and panel.preview_site == Global.ReclamationSite.ROAD and "路肩" in panel.validity_label.text,
		"Selecting a field across the south lane shows the road conflict.")
	await _capture("00-road-conflict")
	_expect(state.reclaim_well_field(south_lane).is_empty() and state.reclaim_well_field(OLD_ROAD_SITE).is_empty()
		and state.well_fields.size() == 1
		and state.money == money and state.food_storage == food, "The order also checks the road before charging.")
	_expect(state.reclamation_site(Vector2i(12, 6)) == Global.ReclamationSite.ROAD,
		"A field reaching the east shoulder is unavailable even when its center is off the road.")
	_expect(state.reclamation_site(Vector2i(-3, -1)) == Global.ReclamationSite.LANDMARK
		and state.reclamation_site(OLD_ROAD_SITE) == Global.ReclamationSite.ROAD,
		"Reserve the hall and the south lane after moving the parking area.")
	var driving_cell := tiles.local_to_map(tiles.to_local(world.to_global(EstateLayout.DRIVING_START)))
	_expect(state.reclamation_site(Vector2i(16, 5)) == Global.ReclamationSite.OPEN
		and state.reclamation_site(driving_cell) == Global.ReclamationSite.EDGE,
		"The new driving yard is beyond the fields and the old cart bay can be reclaimed.")
	var pavilion_cell := tiles.local_to_map(tiles.to_local(world.to_global(EstateLayout.SOUTH_PAVILION)))
	_expect(state.reclamation_site(pavilion_cell) == Global.ReclamationSite.EDGE,
		"The pavilion stands south of the cultivable land.")
	var shed_cell := tiles.local_to_map(tiles.to_local(world.to_global(EstateLayout.SILK_SHED_FOOT)))
	_expect(state.reclamation_site(Vector2i(-4, 5)) == Global.ReclamationSite.OPEN
		and state.reclamation_site(shed_cell) == Global.ReclamationSite.EDGE,
		"The former silk shed site is reclaimable and the new workshop stands west of the surveyed fields.")
	await _button(panel.get_node("Panel/CloseButton"))

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
	var landscape: Node2D = world.get_node("Landscape")
	var area: Rect2 = landscape._field_bounds(field.center_pos)
	var center := tiles.to_global(tiles.map_to_local(field.center_pos))
	var normal: Vector2 = landscape.field_entrance(field_id)
	var expected := Vector2.DOWN if field_id == 1 else Vector2.UP
	_expect(center == area.get_center() and normal == expected,
		"The field uses the live grid and opens on the side facing the nearest clear lane.")
	var boundary := marker.get_node("Boundary") as Line2D
	var mouth := center + normal * 24.0
	_expect(boundary.to_global((boundary.points[0] + boundary.points[-1]) * 0.5) == mouth
		and boundary.points[0].distance_to(boundary.points[-1]) == 16.0, "The cut in the field edge is one tile wide.")
	var path: Dictionary = landscape.track_shapes[landscape.ESTATE_TRACKS.size() + field_id]
	for offset in [-6.0, 6.0]:
		_expect(Geometry2D.is_point_in_polygon(mouth + normal * 2.0 + normal.orthogonal() * offset, path.surface),
			"The track reaches both sides of the opening.")
	_expect(Geometry2D.is_point_in_polygon(path.gravel_path[0], landscape.track_shapes[2].surface),
		"The spur begins inside the east lane.")
	print("FIELD_ACCESS_ENTRY field=", field_id + 1, " mouth=", mouth, " side=", normal)

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
	await _continue_latest()
	_check_completed(1)
	_check_completed(2)
	await _move(&"ui_down", 40)
	await tree.create_timer(0.35).timeout
	await _capture("06-field-entrances-reloaded")
	await _button(ui.hud.map_button)
	_expect(ui.estate_map.modal.visible, "The survey opens with both completed field approaches.")
	await _capture("07-estate-field-approaches")

func _harvest_legacy_site() -> void:
	var old_field: Dictionary = state.get_well_field(2)
	var private_cell := OLD_ROAD_SITE + Vector2i.RIGHT
	if not _expect(old_field.get("center_pos") == OLD_ROAD_SITE and old_field.is_unlocked
		and state.active_crops.has(OLD_ROAD_SITE) and state.active_crops.has(private_cell),
		"Continue the actual prior release's paid field and mature crops at the original coordinates."):
		return
	var treasury: int = state.king_storage
	var inventory: int = state.player_inventory
	var money: int = state.money
	await _capture("08-old-road-field-reloaded")
	for cell in [OLD_ROAD_SITE, private_cell]:
		await _click(_point(cell))
	_expect(state.king_storage == treasury + 1 and state.player_inventory == inventory + 1
		and state.money == money + ItemManager.get_crop("millet").sell_price,
		"Both harvest destinations still receive the crops grown on the legacy road field.")
	print("FIELD_ACCESS_LEGACY day=", state.current_day, " site=", OLD_ROAD_SITE,
		" tribute=", state.king_storage - treasury, " private=", state.player_inventory - inventory)

func run(game_tree: SceneTree, captures := "") -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the worksite replay's profile."):
		tree.quit(1)
		return
	seed(982)
	capture_dir = captures if not captures.is_empty() else OS.get_environment("FIEFDOM_WORKSITE_CAPTURES")
	if tree.root.size.x < 900:
		tree.root.size = Vector2i(1280, 720)
	tree.root.notify_mouse_entered()
	state = tree.root.get_node("Global")
	if not legacy:
		# Fund two expansions to exercise both sites through the regular survey.
		var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({
			"current_day": 2, "current_rank": state.Rank.SHANG_SHI, "king_storage": 1, "reputation": 150,
			"money": 620, "food_storage": 260,
			"retainers": [{"name": "渠伯"}, {"name": "季青"}, {"name": "石墨"}],
		}))
		file.close()
	await _continue_latest()
	if legacy:
		await _harvest_legacy_site()
	else:
		_expect(not ui.hud.worksite_button.visible, "The shortcut appears after commissioning a site.")
		await _check_obstructed_sites()
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
