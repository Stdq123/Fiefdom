extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		push_error(detail)
		failed = true

func _sleep(ui: Node) -> void:
	ui.sleep_button.pressed.emit()
	await create_timer(1.1).timeout

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run season-rotation with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	seed(511)
	change_scene_to_file("res://scenes/Main.tscn")
	await scene_changed
	var state := root.get_node("Global")
	var world := current_scene.get_node("World")
	var ui := current_scene.get_node("UI")
	var rotated := Vector2i(6, 5)
	var ordinary := Vector2i(6, 6)

	world.current_seed_id = "beans"
	world.handle_interaction(rotated)
	world.handle_interaction(rotated)
	for night in range(2):
		world.handle_interaction(rotated)
		await _sleep(ui)
	world.handle_interaction(rotated)
	_expect(state.fertile_cells.has(rotated) and state.player_inventory == 1, "Harvesting beans prepares the plot for rotation.")
	_expect(state.save_game() == OK and state.load_game() == OK, "Fertile soil can be saved and reloaded.")
	await scene_changed
	world = current_scene.get_node("World")
	ui = current_scene.get_node("UI")
	_expect(state.fertile_cells.has(rotated), "The fertilizer charge survives reloading.")

	world.select_seed("millet")
	world.handle_interaction(ordinary)
	for cell in [rotated, ordinary]:
		world.handle_interaction(cell)
	for night in range(2):
		for cell in [rotated, ordinary]:
			world.handle_interaction(cell)
		await _sleep(ui)
	for cell in [rotated, ordinary]:
		world.handle_interaction(cell)
	_expect(state.money == 19 and state.player_inventory == 4, "The rotated harvest gains one unit and the ordinary harvest pays its usual amount.")
	_expect(not state.fertile_cells.has(rotated), "Harvest consumes the rotation benefit once.")

	_expect("谷雨" in ui.hud.calendar_button.tooltip_text and "雨润旱田" in ui.hud.calendar_button.tooltip_text,
		"The almanac shortcut gives tomorrow's rain forecast before it begins.")
	await _sleep(ui)
	_expect(state.get_current_solar_term() == "谷雨" and ui.hud.calendar_label.text.ends_with("· 雨")
		and ui.hud.weather_icon.texture == ui.hud.sky_icons[1], "The calendar displays both rain text and the rain icon on that day.")
	world.handle_interaction(ordinary)
	_expect(state.active_crops.has(ordinary) and not state.active_crops[ordinary]["watered"], "The rain scenario starts with no manual watering.")
	await _sleep(ui)
	_expect(state.active_crops[ordinary]["age"] == 1 and not state.has_rain(), "Rain from the day just ended advances an unwatered crop once.")

	var crops := root.get_node("ItemManager")
	_expect(state.sowing_nights(crops.get_crop("mulberry"), 1) == 4
		and state.sowing_nights(crops.get_crop("rice"), 7) == 3
		and state.sowing_nights(crops.get_crop("sorghum"), 13) == 2
		and state.sowing_nights(crops.get_crop("wheat"), 19) == 2, "Each season offers a distinct faster crop.")
	_expect(ui.hud.seed_buttons["rice"].get_node("SeasonMark").visible, "The seed belt highlights summer rice on the first summer day.")
	state.balance.raid_first_day = 10000
	state.food_storage += 10
	state.tech_unlocked["irrigation"] = true
	var rice := Vector2i(4, 5)
	_expect(state.build_channel(Vector2i(2, 5)) == state.ChannelSite.AVAILABLE
		and state.build_channel(Vector2i(3, 5)) == state.ChannelSite.AVAILABLE, "The remaining copper builds a connected test canal.")
	while state.current_day < 12:
		await _sleep(ui)
	world.select_seed("rice")
	world.handle_interaction(rice)
	world.handle_interaction(rice)
	_expect(state.active_crops.has(rice) and state.active_crops[rice]["growth_nights"] == 3,
		"Rice sown on the last summer day needs three irrigated nights.")
	if not state.active_crops.has(rice):
		quit(1)
		return
	_expect(state.save_game() == OK and state.load_game() == OK, "An in-season planting can be saved.")
	await scene_changed
	world = current_scene.get_node("World")
	ui = current_scene.get_node("UI")
	await _sleep(ui)
	_expect(state.current_day == 13 and state.active_crops[rice]["age"] == 1
		and state.active_crops[rice]["growth_nights"] == 3 and state.sowing_nights(crops.get_crop("rice")) == 4,
		"The planted rice keeps its earlier schedule when new autumn sowing reverts to four nights.")
	_expect(ui.hud.seed_buttons["sorghum"].get_node("SeasonMark").visible and not ui.hud.seed_buttons["rice"].get_node("SeasonMark").visible,
		"The visible seasonal recommendation changes when autumn begins.")
	for night in range(2):
		await _sleep(ui)
	_expect(world.field_action(rice) == world.FieldAction.HARVEST, "The canal matures the summer-sown rice at its saved threshold.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
