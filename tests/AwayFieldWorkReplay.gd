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
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = bounds.get_center()
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

func _assign_at_gate() -> void:
	ui.manage_button.pressed.emit()
	await tree.process_frame
	var panel: Control = ui.panel_manager.management_panel_instance
	var duties := [RetainerData.Duty.HARVEST, RetainerData.Duty.FIELD]
	for index in duties.size():
		var picker: OptionButton = panel.retainer_list_container.get_child(index).duty_picker
		picker.item_selected.emit(picker.get_item_index(duties[index]))
	panel.get_node("CloseButton").pressed.emit()
	await tree.process_frame

func _walk(actor: Node2D, stops: Array) -> void:
	for point: Vector2 in stops:
		await Campaign.walk_to(tree, actor, point)

func _cross(action: StringName, destination: String) -> bool:
	Input.action_press(action)
	for frame in 52:
		await tree.physics_frame
		if tree.root.get_node("MapTravel").active:
			break
	Input.action_release(action)
	await Campaign.wait_for_map_change(tree)
	await tree.process_frame
	return _expect(tree.current_scene.scene_file_path == destination, "Walk through the gate to " + destination)

func _public_plot_untouched() -> bool:
	return state.active_crops.has(PUBLIC) and state.king_storage == 0 and not state.active_crops[YOUNG].watered

func _market_round_trip() -> void:
	if not await _load_estate():
		return
	var stamina: int = state.current_stamina
	await _walk(world.player, [Vector2(-181, 60), Vector2(-181, 0), Vector2(-270, -21)])
	await _assign_at_gate()
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return
	var market := tree.current_scene as Node2D
	await _key(KEY_ESCAPE)
	var time: float = state.day_progress
	await tree.create_timer(3.6).timeout
	_expect(market.settings.visible and state.day_progress == time and _public_plot_untouched(),
		"Settings hold the clock and keep both jobs pending.")
	await _key(KEY_ESCAPE)
	await tree.create_timer(3.3).timeout
	if not state.has_method("away_field_summary"):
		_expect(_public_plot_untouched(), "The old package leaves both jobs pending after an active market visit.")
		print("AWAY_BASELINE tribute=", state.king_storage, " watered=", state.active_crops[YOUNG].watered)
		return
	if not _expect(state.king_storage == 1 and not state.active_crops.has(PUBLIC)
		and state.active_crops[YOUNG].watered and state.active_crops.has(HEMP),
		"The first jobs water and harvest the assigned cells before other work."):
		return
	_expect(state.away_field_report.watered == 1 and state.away_field_report.harvested == 1,
		"The first settled jobs appear in the field record.")
	await _key(KEY_ESCAPE)
	for button: Button in market.settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	if not _expect(market.settings.save_status.text == "游戏已保存", "Save from the market settings."):
		return
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	market = tree.current_scene as Node2D
	if not _expect(market.scene_file_path == state.WEST_MARKET_SCENE and state.away_field_report.harvested == 1
		and state.away_field_report.watered == 1 and state.king_storage == 1 and state.active_crops[YOUNG].watered,
		"Continue in the market with the completed work and report."):
		return
	await _walk(market.player, [Vector2(62, 34)])
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
	await _walk(market.player, [Vector2(176, 34)])
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return
	_estate()
	var notice: Label = tree.current_scene.get_node("CampaignHUD").notice
	_expect(notice.visible and "今日外出田务" in notice.text
		and ui.directions.tracked_neighbor == "渠伯", "Returning shows the work and restores first tribute directions.")
	await _snapshot("02-return-to-estate")
	await _walk(world.player, [Vector2(-181, 0), Vector2(-181, 65), Vector2(31, 65), Vector2(66, 98)])
	await _button(ui.hud.rations_button)
	var rations: Control = ui.get_node("Control/NightRationsPanel")
	_expect(not notice.visible and "外出田务" in rations.field_forecast.text and "私仓 +3" in rations.field_forecast.text
		and "3 份" in rations.need.text and "稻田断水" in rations.field_warning.text,
		"Tonight's plan explains the work, rice and rations without the arrival notice above it.")
	await _snapshot("03-field-work-report")
	await _button(rations.get_node("%Sleep"))
	await tree.create_timer(1.16).timeout
	_expect(notice.visible and state.current_day == 13 and state.food_storage == 9 and state.active_crops[YOUNG].age == 1
		and state.active_crops[RICE].age == 0 and state.away_field_report.is_empty(),
		"Normal overnight settlement grows the watered plot once and consumes three rations.")
	print("AWAY_DAWN day=", state.current_day, " food=", state.food_storage, " watered_age=", state.active_crops[YOUNG].age)

func _ravine_round_trip() -> void:
	if not await _load_estate():
		return
	await _walk(world.player, [Vector2(66, 36), Vector2(365, 6)])
	await _assign_at_gate()
	if not await _cross(&"ui_right", state.WILDERNESS_SCENE):
		return
	await tree.create_timer(3.3).timeout
	_expect(state.king_storage == 1 and state.away_field_report.harvested == 1 and state.active_crops[YOUNG].watered,
		"Both jobs also progress at the bamboo ravine.")
	if await _cross(&"ui_left", state.ESTATE_SCENE):
		_expect(not state.away_field_report.pending and state.active_crops[YOUNG].watered,
			"The eastern route restores the same estate and acknowledges the report.")
		print("AWAY_RAVINE ", state.away_field_summary())

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated field work profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_AWAY_CAPTURES")
	tree.root.notify_mouse_entered()
	seed(1112)
	if await _prepare_fixture():
		await _market_round_trip()
		if not failed and state.has_method("away_field_summary") and DisplayServer.get_name() == "headless":
			await _ravine_round_trip()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
