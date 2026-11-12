extends RefCounted

const PUBLIC := Vector2i(5, 5)
const EARLY_PRIVATE := Vector2i(6, 5)
const LATE_PRIVATE := Vector2i(4, 5)

var tree: SceneTree
var state: Node
var world: Node
var ui: Node
var failures := 0
var capture_dir := ""

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failures += 1
		push_error(detail)
	return condition

func _click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame

func _button(button: Control) -> void:
	await _click(button.get_global_rect().get_center())
	await tree.process_frame

func _plot(cell: Vector2i, clicks := 1) -> void:
	var tiles: TileMapLayer = world.tile_map
	var point := tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)
	for action in clicks:
		await _click(point)

func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for frame in frames:
		await tree.physics_frame
	Input.action_release(action)
	await tree.process_frame

func _use_estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame

func _open_plan() -> Control:
	await _button(ui.hud.rations_button)
	await tree.process_frame
	return ui.get_node_or_null("Control/NightRationsPanel") as Control

func _open_previous_night() -> Control:
	await _button(ui.hud.morning_button)
	return ui.get_node_or_null("Control/NightRationsPanel") as Control

func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Save the rendered morning frame " + name)

func _sleep() -> String:
	await _button(ui.sleep_button)
	await tree.create_timer(0.60).timeout
	var caption: String = ui.dawn_caption.text
	await tree.create_timer(0.51).timeout
	return caption

func _first_night() -> bool:
	# Measure missed watering with the starting retainer still at his post.
	world.retainer_instances[state.retainers.front()].set_physics_process(false)
	await _plot(PUBLIC, 2)
	await _plot(EARLY_PRIVATE, 3)
	await _plot(LATE_PRIVATE, 2)
	if not _expect(state.active_crops.size() == 3, "Plant a public and two private millet plots through the map."):
		return false
	_expect("2 格缺水" in ui.hud.rations_button.text and "2 格作物缺水" in ui.sleep_button.tooltip_text,
		"The farm alert is readable next to sleep before opening the plan.")
	await _move(&"ui_down", 139)
	var plan := await _open_plan()
	if not _expect(plan != null, "The HUD opens tonight's work and rations."):
		return false
	_expect("今夜预计 1 格生长" in plan.field_forecast.text and "2 格待浇" in plan.field_warning.text and plan.find_plot.visible,
		"The plan distinguishes the watered crop from the two dry crops.")
	await _button(plan.find_plot)
	_expect(ui.directions.tracked_plot == PUBLIC and ui.directions.mark == ui.directions.Mark.EDGE and ui.directions.visible,
		"The shortcut favors the dry public plot and points back toward the farm from the southern path.")
	print("FIELD_NIGHT_LOCATE cell=", ui.directions.tracked_plot, " mark=", ui.directions.mark, " player=", world.player.position)
	await _move(&"ui_up", 139)
	await _sleep()
	_expect(state.current_day == 2 and state.active_crops[PUBLIC].age == 0 and state.active_crops[EARLY_PRIVATE].age == 1
		and state.active_crops[LATE_PRIVATE].age == 0 and state.food_storage == 9 and world.current_visitor().name == VisitorData.ROAD_KEEPER,
		"The first night advances only the wet crop, serves one ration, and brings Ji Qing to the estate.")
	plan = await _open_previous_night()
	if not _expect(plan != null and plan.show_previous and not plan.find_harvest.visible, "Open the first night's record while no crops are ripe."):
		return false
	_expect("第 1 夜田务" in plan.field_receipt.text and "2 格漏浇停长" in plan.field_receipt.text
		and "1 格长了一阶" in plan.field_receipt.text and "用粮 1/1" in plan.receipt.text,
		"The crop and meal entries describe the same night.")
	print("FIELD_NIGHT_MISSED ", plan.field_receipt.text)
	await _button(plan.page_button)
	_expect(not plan.show_previous and plan.plan_body.visible and plan.footer.visible,
		"Tonight's forecast stays one click away from the record.")
	await _button(plan.close_button)
	return true

func _tend_and_harvest() -> bool:
	await _plot(PUBLIC)
	_expect(ui.directions.tracked_plot == null and not ui.hud.cancel_directions.visible,
		"Watering the selected plot clears the optional route.")
	ui.panel_manager.show_management_panel()
	var management: Control = ui.panel_manager.management_panel_instance
	management.show_market()
	await tree.process_frame
	await _button(management.market_panel.get_node("MarketHeader/NightRations"))
	var plan: Control = ui.get_node_or_null("Control/NightRationsPanel")
	if not _expect(plan != null and plan.find_plot.visible, "The market opens the same plan with the remaining dry private crops."):
		return false
	await _button(plan.find_plot)
	_expect(not management.visible and ui.directions.tracked_plot != null and ui.directions.tracked_plot != PUBLIC,
		"Finding a private plot from the market returns to the map.")
	await _plot(EARLY_PRIVATE)
	await _plot(LATE_PRIVATE)
	await _sleep()
	_expect(state.last_field_night.private_ripe == 1 and state.last_field_night.growing == 2 and state.current_day == 3,
		"The second night ripens the earlier private crop and grows the other two.")
	await _plot(PUBLIC)
	await _plot(LATE_PRIVATE)
	plan = await _open_plan()
	if not _expect(plan != null, "Reopen the plan before both crops ripen."):
		return false
	_expect("已有 1 格可收" in plan.field_forecast.text and "公田 1 格、私田 1 格" in plan.field_forecast.text
		and not plan.find_plot.visible, "An existing ripe crop stays separate from the forecast of newly mature public and private crops.")
	var original_size := tree.root.size
	for resolution in [Vector2i(1280, 720), Vector2i(1024, 768)]:
		tree.root.size = resolution
		await tree.process_frame
		await tree.process_frame
		var panel: Control = plan.get_node("Center/Window")
		_expect(tree.root.get_visible_rect().encloses(panel.get_global_rect())
			and panel.get_global_rect().encloses(plan.field_receipt.get_global_rect()),
			"The plan and previous night's field receipt fit at %s." % resolution)
		print("FIELD_NIGHT_LAYOUT window=", tree.root.size, " plan=", panel.size)
	tree.root.size = original_size
	await _button(plan.close_button)
	var caption := await _sleep()
	_expect(state.current_day == 4 and "新熟 2 格" in caption and state.last_field_night.public_ripe == 1
		and state.last_field_night.private_ripe == 1 and state.last_field_night.ready == 1 and state.food_storage == 7,
		"Dawn counts only the two crops newly ready, while food still settles each night.")
	await tree.create_timer(0.65).timeout
	_expect(not ui.dawn_caption.visible and ui.hud.morning_button.visible and "新熟 2 格" in ui.hud.morning_button.text,
		"The farm HUD retains the new crop count after the dawn fade clears.")
	await _capture("01-morning-hud")
	var last_fields: Dictionary = state.last_field_night.duplicate()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	tree.current_scene.continue_button.pressed.emit()
	await tree.scene_changed
	await _use_estate()
	world.retainer_instances[state.retainers.front()].set_physics_process(false)
	plan = await _open_previous_night()
	if not _expect(plan != null and plan.show_previous and state.last_field_night == last_fields,
		"Continue restores a direct route to the morning checkpoint's receipt."):
		return false
	_expect("新熟 公田 1 格、私田 1 格" in plan.field_receipt.text and "第 3 夜" in plan.receipt.text,
		"The saved record opens with field and meal results together.")
	var panel: Control = plan.get_node("Center/Window")
	_expect(plan.find_harvest.visible and not plan.plan_body.visible and not plan.footer.visible
		and panel.get_global_rect().encloses(plan.find_harvest.get_global_rect())
		and tree.root.get_visible_rect().encloses(panel.get_global_rect()), "The morning page fits and can lead directly to harvest.")
	print("FIELD_NIGHT_CONTINUE ", plan.field_receipt.text, " / ", plan.receipt.text)
	await _capture("02-last-night-record")
	await _button(plan.find_harvest)
	_expect(ui.get_node_or_null("Control/NightRationsPanel") == null and ui.directions.tracked_plot == PUBLIC,
		"The record closes and guides the player to the ripe public plot.")
	await _capture("03-harvest-route")
	await _plot(PUBLIC)
	await _plot(LATE_PRIVATE)
	_expect(state.king_storage == 1 and state.player_inventory == 1 and state.money == ItemManager.get_crop("millet").sell_price,
		"The two harvests credit the treasury, private stores, and copper once each.")
	await _plot(EARLY_PRIVATE)
	plan = await _open_previous_night()
	if not _expect(plan != null and not plan.find_harvest.visible and ui.directions.tracked_plot == null,
		"Collecting all ripe crops clears the route and leaves the historical receipt readable."):
		return false
	await _button(plan.close_button)
	print("MORNING_HARVEST day=", state.current_day, " public=", state.king_storage, " private=", state.player_inventory)
	return true

func _rain_and_rice() -> void:
	# Load a legacy save with a disconnected rice plot and a rain-fed former public plot.
	var path := "user://field-night-legacy.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"current_day": 6, "king_storage": 1, "tax_reform_choice": state.TaxReformChoice.REFORMED,
		"active_crops": {
			"5,5": {"id": "millet", "age": 1, "growth_nights": 2},
			"4,5": {"id": "rice", "age": 0, "growth_nights": 2, "requires_channel": true},
		},
	}))
	file.close()
	if not _expect(state.load_game(path) == OK, "Load a save predating the field receipt."):
		return
	await tree.scene_changed
	await _use_estate()
	var plan := await _open_plan()
	if not _expect(plan != null and state.last_field_night.is_empty() and not ui.hud.morning_button.visible,
		"The legacy save opens without a fabricated previous night."):
		return
	_expect(state.has_rain() and "公田 0 格、私田 1 格" in plan.field_forecast.text and "1 格稻田断水" in plan.field_warning.text
		and not plan.find_plot.visible and not plan.field_receipt.visible,
		"Today's rain ripens the reform-era private center while the blocked rice still needs a canal.")
	await _button(plan.close_button)
	await _sleep()
	_expect(state.current_day == 7 and not state.has_rain() and state.active_crops[PUBLIC].age == 2
		and state.active_crops[LATE_PRIVATE].age == 0 and state.last_field_night.blocked == 1 and state.last_field_night.private_ripe == 1,
		"The crop changes match the forecast even when tomorrow is dry.")
	plan = await _open_plan()
	if _expect(plan != null and "1 格稻田断水停长" in plan.field_receipt.text, "The receipt distinguishes interrupted rice from missed hand watering."):
		print("FIELD_NIGHT_RAIN ", plan.field_receipt.text)
		await _button(plan.close_button)

func run(game_tree: SceneTree, capture := "") -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the nightly field replay's profile."):
		tree.quit(1)
		return
	seed(213)
	capture_dir = capture
	if capture_dir.is_empty():
		tree.root.size = Vector2i(1280, 720)
	tree.root.notify_mouse_entered()
	state = tree.root.get_node("Global")
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	tree.current_scene.new_button.pressed.emit()
	await tree.scene_changed
	await _use_estate()
	if await _first_night() and await _tend_and_harvest():
		await _rain_and_rice()
	tree.unload_current_scene()
	for stream in tree.root.get_node("AudioManager").get_children():
		if stream is AudioStreamPlayer:
			stream.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
