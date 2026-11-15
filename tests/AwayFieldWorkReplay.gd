extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const PUBLIC := Vector2i(5, 5)
const HEMP := Vector2i(6, 5)
const MULBERRY := Vector2i(6, 6)
const YOUNG := Vector2i(4, 5)
const RICE := Vector2i(4, 4)
const FIXTURE := "user://away-field-work-fixture.json"

var tree: SceneTree
var state: Node
var world: Node2D
var ui: CanvasLayer
var capture_dir := ""
var baseline := false
var previous_return := false
var failed := false

func _expect(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		push_error(message)
	return ok

func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		tree.root.push_input(event, true)
		await tree.process_frame

func _button(button: Button) -> void:
	await tree.process_frame
	var bounds := button.get_global_rect()
	if not _expect(button.is_visible_in_tree() and not button.disabled and tree.root.get_visible_rect().encloses(bounds),
		"Use the visible button " + button.text):
		return
	await _click(bounds.get_center())

func _click(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		tree.root.push_input(event, true)
		await tree.process_frame

func _snapshot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await tree.create_timer(0.22).timeout
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)
	print("AWAY_FRAME ", name, " window=", tree.root.size, " image=", image.get_size())

func _prepare_fixture() -> bool:
	if not _expect(state.start_new_game() == OK, "Open the estate to stage the field work fixture."):
		return false
	await tree.scene_changed
	state.current_day = 12
	state.day_progress = 0.3
	state.food_storage = 12
	state.silk_workshop.built = true
	var starter: RetainerData = state.retainers[0]
	starter.duty = RetainerData.Duty.REEL
	starter.assigned_area = PUBLIC
	var teacher := RetainerData.new("季青", "士人", RetainerData.School.CONFUCIAN)
	teacher.duty = RetainerData.Duty.TEACH
	teacher.assigned_area = YOUNG
	state.retainers.append(teacher)
	var crops := {PUBLIC: "millet", HEMP: "hemp", MULBERRY: "mulberry", YOUNG: "millet", RICE: "rice"}
	for cell: Vector2i in crops:
		var id: String = crops[cell]
		var crop: CropData = tree.root.get_node("ItemManager").get_crop(id)
		var nights: int = state.sowing_nights(crop)
		state.tilled_cells[cell] = true
		state.active_crops[cell] = {"id": id, "data": crop, "growth_nights": nights,
			"age": 0 if cell in [YOUNG, RICE] else nights, "watered": false, "requires_channel": crop.is_water_crop}
	state.fertile_cells[HEMP] = true
	if not _expect(state.save_game() == OK, "Save the isolated starting estate."):
		return false
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.manual_save_path()))
	snapshot.erase("away_field_report")
	var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot))
	file.close()
	return true

func _load_estate() -> bool:
	if not _expect(state.load_game(FIXTURE) == OK, "Open a save that predates the work report."):
		return false
	await tree.scene_changed
	_estate()
	return true

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")

func _assign_duties(caretaker := RetainerData.Duty.FIELD) -> void:
	ui.manage_button.pressed.emit()
	await tree.process_frame
	var panel: Control = ui.panel_manager.management_panel_instance
	var duties := [RetainerData.Duty.HARVEST, caretaker]
	for index in duties.size():
		var picker: OptionButton = panel.retainer_list_container.get_child(index).duty_picker
		picker.item_selected.emit(picker.get_item_index(duties[index]))
	panel.get_node("CloseButton").pressed.emit()
	await tree.process_frame

func _walk(actor: Node2D, stops: Array) -> void:
	for point: Vector2 in stops:
		await Campaign.walk_to(tree, actor, point)

func _cross(action: StringName, destination: String) -> bool:
	var crossed := await Campaign.walk_through_gates(tree, action, destination, 52)
	await tree.process_frame
	return _expect(crossed, "Walk through the gate to " + destination)

func _public_plot_untouched() -> bool:
	return state.active_crops.has(PUBLIC) and state.king_storage == 0 and not state.active_crops[YOUNG].watered

func _save_from_settings(settings: Control) -> bool:
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	return _expect(settings.save_status.text.begins_with("游戏已保存"), "Save the day's work through Settings.")

func _continue_from_title() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await tree.process_frame

func _plant(cell: Vector2i) -> bool:
	await _key(KEY_1)
	var tiles: TileMapLayer = world.tile_map
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))
	var crop: Dictionary = state.active_crops.get(cell, {})
	return _expect(crop.get("id") == "millet" and not crop.watered, "Sow in an empty plot and leave it for a field worker.")

func _market_round_trip() -> void:
	if not await _load_estate():
		return
	var stamina: int = state.current_stamina
	await _walk(world.player, [Vector2(-181, 60), Vector2(-181, 0), Vector2(-270, -21)])
	await _assign_duties()
	var road_scene := "res://scenes/WestRoad.tscn"
	var first_stop: String = road_scene if ResourceLoader.exists(road_scene) else state.WEST_MARKET_SCENE
	if not await _cross(&"ui_left", first_stop):
		return
	var first_map := tree.current_scene as Node2D
	await _key(KEY_ESCAPE)
	var time: float = state.day_progress
	await tree.create_timer(3.6).timeout
	_expect(first_map.settings.visible and state.day_progress == time and _public_plot_untouched(),
		"Settings hold the clock and keep both jobs pending.")
	await _key(KEY_ESCAPE)
	await tree.create_timer(3.3).timeout
	if not _expect(state.king_storage == 1 and not state.active_crops.has(PUBLIC)
		and state.active_crops[YOUNG].watered and state.active_crops.has(HEMP),
		"The first jobs water and harvest the assigned cells before other work."):
		return
	_expect(state.away_field_report.watered == 1 and state.away_field_report.harvested == 1,
		"The first settled jobs appear in the field record.")
	if first_stop == road_scene and not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return
	var market := tree.current_scene as Node2D
	await _key(KEY_ESCAPE)
	var completed: Dictionary = state.away_field_report.duplicate()
	if not await _save_from_settings(market.settings):
		return
	await _continue_from_title()
	market = tree.current_scene as Node2D
	if not _expect(market.scene_file_path == state.WEST_MARKET_SCENE and state.away_field_report.harvested == completed.harvested
		and state.away_field_report.watered == completed.watered and state.king_storage == 1 and state.active_crops[YOUNG].watered,
		"Continue in the market with the completed work and report."):
		return
	await Campaign.walk_market_to(tree, market, Vector2(134, 76))
	await tree.create_timer(7.0).timeout
	var report: Dictionary = state.away_field_report
	var items := tree.root.get_node("ItemManager")
	var copper: int = items.get_crop("hemp").sell_price * 2 + items.get_crop("mulberry").sell_price
	_expect(report.harvested == 3 and report.watered == 2 and report.tribute == 1 and report.stock == 3
		and report.copper == copper and report.leaves == state.balance.mulberry_leaves_per_harvest
		and state.king_storage == 1 and state.player_inventory == 3 and state.money == copper
		and state.silk_workshop.leaves == report.leaves and not state.fertile_cells.has(HEMP),
		"Harvest counts once, including rotation, private copper and perennial leaves.")
	_expect(state.current_stamina == stamina and state.active_crops.has(MULBERRY) and not state.active_crops[RICE].watered
		and market.stock.text.begins_with(str(copper) + " 铜钱"), "Market totals refresh, with stamina and rice rules intact.")
	print("AWAY_MARKET ", state.away_field_summary(), " stamina=", stamina)
	await _snapshot("01-west-market")
	await Campaign.walk_to_market_exit(tree, market)
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return
	_estate()
	var notice: Label = tree.current_scene.get_node("CampaignHUD").notice
	_expect(notice.visible and "今日外出田务" in notice.text
		and "可找渠伯谈轮作" in notice.text and ui.directions.tracked_neighbor.is_empty(),
		"Returning shows the work and keeps the rotation conversation available.")
	if not baseline:
		_expect("国库 +1" in notice.text and "私仓 +3" in notice.text, "The first return names where both harvests went.")
		var entry: Dictionary = state.first_tribute_entry
		_expect(entry.get("worker") == state.retainers[0].name and entry.get("day") == 12
			and entry.get("crop") == "millet" and entry.get("amount") == 1
			and world.get_node("Scenery/FirstTributeStand").visible,
			"The first entry records the retainer who really harvested while the player was away.")
		print("FIRST_TRIBUTE_AWAY ", state.first_tribute_note())
	await _snapshot("02-return-to-estate")
	if baseline:
		await _button(ui.settings_button)
		var settings: Control = ui.panel_manager.settings_panel_instance
		if not await _save_from_settings(settings):
			return
		var archived := "user://previous-return.json"
		_expect(DirAccess.copy_absolute(state.manual_save_path(), archived) == OK, "Keep the old save after the first return.")
		print("AWAY_PREVIOUS_RETURN path=", ProjectSettings.globalize_path(archived))
		await _button(settings.close_button)
	if await _second_outing():
		await _finish_day()

func _second_outing() -> bool:
	await _assign_duties(RetainerData.Duty.HARVEST)
	await Campaign.walk_estate_road_to(tree, world, Vector2(66, 98))
	if not await _plant(HEMP):
		return false
	await Campaign.walk_estate_road_to(tree, world, Vector2(365, 6))
	await _assign_duties()
	if not await _cross(&"ui_right", state.WILDERNESS_SCENE):
		return false
	await tree.create_timer(3.3).timeout
	if not _expect(state.away_field_report.watered == 3 and state.away_field_report.harvested == 3
		and state.active_crops[HEMP].watered, "A second outing adds one watering and leaves the recorded harvest total intact."):
		return false
	var ravine := tree.current_scene as Node2D
	await _key(KEY_ESCAPE)
	if not await _save_from_settings(ravine.settings):
		return false
	await _button(ravine.settings.close_button)
	await _continue_from_title()
	if not _expect(tree.current_scene.scene_file_path == state.WILDERNESS_SCENE, "Continue at the ravine before the second return."):
		return false
	if not await _cross(&"ui_left", state.ESTATE_SCENE):
		return false
	_estate()
	var notice: Label = tree.current_scene.get_node("CampaignHUD").notice
	if baseline:
		_expect("今日外出田务 · 浇水 3 格 · 收割 3 格" == notice.text, "The old return repeats the day's earlier jobs.")
	else:
		_expect("本趟外出田务 · 浇水 1 格" == notice.text, "The checkpoint and the second outing's unread watering survive Continue.")
	print("AWAY_SECOND_RETURN notice=", notice.text, " total=", state.away_field_summary())
	await _snapshot("03-second-return")
	if not baseline:
		await tree.create_timer(5.75).timeout
		_expect(is_zero_approx(notice.modulate.a), "The travel receipt fades while the day's account remains available.")
	return not failed

func _finish_day() -> void:
	await _assign_duties(RetainerData.Duty.HARVEST)
	await Campaign.walk_estate_road_to(tree, world, Vector2(66, 98))
	if not await _plant(PUBLIC):
		return
	await _assign_duties()
	await _button(ui.hud.rations_button)
	var rations: Control = ui.get_node("Control/NightRationsPanel")
	var notice: Label = tree.current_scene.get_node("CampaignHUD").notice
	_expect(not notice.visible and "浇水 3 格 · 收割 3 格" in rations.field_forecast.text and "私仓 +3" in rations.field_forecast.text
		and "3 份" in rations.need.text and "稻田断水" in rations.field_warning.text,
		"Tonight's plan explains the work, rice and rations without the arrival notice above it.")
	await _snapshot("04-field-work-report")
	await _button(rations.wait_button)
	if not _expect(state.field_wait_report.get("watered") == 1 and state.active_crops[PUBLIC].watered,
		"Use the plan to finish the new public plot before sleep."):
		return
	await _button(rations.get_node("%Sleep"))
	await tree.create_timer(1.16).timeout
	_expect(notice.visible and state.current_day == 13 and state.food_storage == 9 and state.active_crops[YOUNG].age == 1
		and state.active_crops[RICE].age == 0 and state.away_field_report.is_empty(),
		"Normal overnight settlement grows the watered plot once and consumes three rations.")
	await _continue_from_title()
	_estate()
	await _button(ui.hud.morning_button)
	rations = ui.get_node("Control/NightRationsPanel")
	_expect(state.current_day == 13 and state.food_storage == 9 and state.king_storage == 1 and state.player_inventory == 3
		and "睡前收工 · 浇水 1 格" in rations.field_wait_receipt.text,
		"The morning save keeps the regular field and ration results.")
	if baseline:
		_expect(not state.last_dawn.has("away_field"), "The old morning has lost the outing record.")
	else:
		var record: Dictionary = state.last_dawn.get("away_field", {})
		_expect(record.get("day") == 12 and record.get("watered") == 3 and record.get("harvested") == 3
			and record.get("tribute") == 1 and record.get("stock") == 3 and not record.has("pending")
			and "第 12 天外出田务" in rations.away_field_receipt.text and "私仓 +3" in rations.away_field_receipt.text,
			"After Continue, the morning page shows the previous day's travel and bedtime jobs without adding either twice.")
	print("AWAY_DAWN day=", state.current_day, " food=", state.food_storage, " away=", state.last_dawn.get("away_field", {}),
		" bedtime=", state.last_dawn.get("field_wait", {}))
	await _snapshot("05-morning-record")

func _ravine_round_trip() -> void:
	if not await _load_estate():
		return
	await _walk(world.player, [Vector2(66, 36), Vector2(365, 6)])
	await _assign_duties()
	if not await _cross(&"ui_right", state.WILDERNESS_SCENE):
		return
	await tree.create_timer(3.3).timeout
	_expect(state.king_storage == 1 and state.away_field_report.harvested == 1 and state.active_crops[YOUNG].watered,
		"Both jobs also progress at the bamboo ravine.")
	if await _cross(&"ui_left", state.ESTATE_SCENE):
		_expect(not state.away_field_report.pending and state.active_crops[YOUNG].watered,
			"The eastern route restores the same estate and acknowledges the report.")
		print("AWAY_RAVINE ", state.away_field_summary())

func _resume_previous_return() -> void:
	await _continue_from_title()
	if tree.current_scene.scene_file_path == state.WILDERNESS_SCENE:
		if not await _cross(&"ui_left", state.ESTATE_SCENE):
			return
		_estate()
		var notice: Label = tree.current_scene.get_node("CampaignHUD").notice
		_expect(not state.away_field_report.pending and "今日外出田务 · 浇水 3 格 · 收割 3 格" in notice.text,
			"A pending old save without a checkpoint shows its known day totals.")
		print("AWAY_PREVIOUS_UNREAD ", notice.text.replace("\n", " / "))
		await _snapshot("03-previous-unread")
		await _finish_day()
		return
	_estate()
	var notice: Label = tree.current_scene.get_node("CampaignHUD").notice
	_expect(not state.away_field_report.pending and notice.text.is_empty(), "An already seen old report stays quiet on Continue.")
	if await _second_outing():
		await _finish_day()

func run(game_tree: SceneTree, captures := "") -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated field work profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = captures if not captures.is_empty() else OS.get_environment("FIEFDOM_AWAY_CAPTURES")
	tree.root.notify_mouse_entered()
	seed(1112)
	if previous_return:
		await _resume_previous_return()
	elif await _prepare_fixture():
		await _market_round_trip()
		if not failed and not baseline and DisplayServer.get_name() == "headless":
			await _ravine_round_trip()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
