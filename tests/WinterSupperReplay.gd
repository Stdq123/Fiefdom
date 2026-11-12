extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const PUBLIC := Vector2i(5, 5)
const BEANS := Vector2i(6, 5)
const WHEAT := Vector2i(6, 6)
const MILLET := [Vector2i(6, 4), Vector2i(4, 5), Vector2i(4, 4)]

var tree: SceneTree
var state: Node
var world: Node
var ui: Node
var captures := ""
var failed := false

func _expect(ok: bool, detail: String) -> bool:
	if not ok:
		failed = true
		push_error(detail)
	return ok

func _click(point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	tree.root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame

func _button(button: Button) -> void:
	await tree.process_frame
	if _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled
			and tree.root.get_visible_rect().encloses(button.get_global_rect()), "Use the visible button " + (button.text if button else "")):
		await _click(button.get_global_rect().get_center())

func _key_event(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	tree.root.push_input(event, true)

func _key(key: Key) -> void:
	_key_event(key, true)
	_key_event(key, false)
	await tree.process_frame

func _find_dialog_button(dialog: Control, prefix: String) -> Button:
	for choice: Button in dialog.options_container.get_children():
		if choice.text.begins_with(prefix):
			return choice
	return null

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")

func _plot(cell: Vector2i) -> void:
	var tiles: TileMapLayer = world.tile_map
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))

func _tend(cell: Vector2i, sow := true) -> void:
	if world.is_crop_ripe(cell):
		await _plot(cell)
	if sow and not state.active_crops.has(cell):
		if not state.tilled_cells.has(cell):
			await _plot(cell)
		await _plot(cell)
	if world.is_crop_dry(cell):
		await _plot(cell)

func _sleep() -> void:
	var tomorrow: int = state.current_day + 1
	await _button(ui.sleep_button)
	await tree.create_timer(1.13).timeout
	_expect(state.current_day == tomorrow and state.outcome == state.Outcome.RUNNING,
		"Reach day %d through ordinary overnights." % tomorrow)

func _walk(actor: Player, stops: Array) -> void:
	for point: Vector2 in stops:
		await Campaign.walk_to(tree, actor, point)

func _cross(action: StringName, path: String) -> bool:
	Input.action_press(action)
	for frame in 52:
		await tree.physics_frame
		if tree.root.get_node("MapTravel").active:
			break
	Input.action_release(action)
	await Campaign.wait_for_map_change(tree)
	return _expect(tree.current_scene.scene_file_path == path, "Follow the road to " + path)

func _frame(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(captures.path_join(name + ".png")) == OK, "Save winter frame " + name)
	print("WINTER_FRAME ", name, " window=", tree.root.size, " image=", image.get_size())

func _open_calendar() -> void:
	await _key(KEY_C)
	await _button(ui.calendar.seasons.get_node("Winter"))
	await _button(ui.calendar.dates.get_child(3))

func _walk_to_table() -> void:
	var approach := world.get_node("WinterSupper/Approach") as Marker2D
	await Campaign.walk_south_to(tree, world, approach.global_position)

func _recruit_and_fish() -> bool:
	var guest: Node2D = world.neighbor_actor(VisitorData.RAVINE_GUIDE)
	if not _expect(guest != null, "The herbalist visits normally before the first raid."):
		return false
	await _walk(world.player, [Vector2(116, 42), guest.global_position + Vector2(0, 18)])
	await _key(KEY_E)
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialog != null and dialog.name_label.text == VisitorData.RAVINE_GUIDE, "Speak to Pu Ning at the bamboo path."):
		return false
	await _button(_find_dialog_button(dialog, "交谈"))
	await _key(KEY_E)
	dialog = ui.get_node_or_null("Control/DialoguePanel")
	await _button(_find_dialog_button(dialog, "招募"))
	if not _expect(state.retainers.size() == 2, "Earn and spend reputation to recruit the second retainer."):
		return false
	await _walk(world.player, [Vector2(117, 4), Vector2(359, 4)])
	if not await _cross(&"ui_right", state.WILDERNESS_SCENE):
		return false
	var trail := tree.current_scene
	var angler: Player = trail.get_node("Player")
	var pool: Node2D = trail.get_node("WillowPool")
	await _walk(angler, [Vector2(103, 1), pool.global_position + Vector2(0, 12)])
	await _key(KEY_E)
	var panel := trail.get_node_or_null("FishingUI/FishingPanel")
	if not _expect(panel != null, "Open the actual willow pool fishing encounter."):
		return false
	for frame in 150:
		if panel.phase != panel.Phase.WAITING:
			break
		await tree.process_frame
	_key_event(KEY_SPACE, true)
	for frame in 420:
		if panel.phase != panel.Phase.REELING:
			break
		if panel.holding and panel.tension > 0.65:
			_key_event(KEY_SPACE, false)
		elif not panel.holding and panel.tension < 0.43:
			_key_event(KEY_SPACE, true)
		await tree.process_frame
	_key_event(KEY_SPACE, false)
	if not _expect(panel.phase == panel.Phase.DONE and panel.catch_icon.visible, "Land the ingredient by fishing and reeling."):
		return false
	await _key(KEY_ESCAPE)
	await _walk(angler, [Vector2(103, 3), Vector2(-160, 3)])
	if not await _cross(&"ui_left", state.ESTATE_SCENE):
		return false
	_estate()
	await _walk(world.player, [Vector2(116, 4), Vector2(116, 96), Vector2(66, 98)])
	return not failed

func _defend() -> void:
	await _walk(world.player, [Vector2(137, 121)])
	for shot in 12:
		var enemy := tree.get_first_node_in_group("estate_raiders") as Node2D
		if enemy == null:
			break
		await _click(enemy.get_global_transform_with_canvas().origin, MOUSE_BUTTON_RIGHT)
		await tree.create_timer(0.38).timeout
	_expect(state.raid_day == 0 and state.outcome == state.Outcome.RUNNING, "Defeat the seasonal raid with the ordinary bow input.")
	await _walk(world.player, [Vector2(66, 121), Vector2(66, 98)])

func _enable_rations() -> void:
	await _button(ui.hud.rations_button)
	var policy := ui.get_node("Control/NightRationsPanel")
	await _button(policy.delegate)
	await _button(policy.close_button)

func _assign_harvesters() -> void:
	await _button(ui.manage_button)
	var panel: Control = ui.panel_manager.management_panel_instance
	for item: Control in panel.retainer_list_container.get_children():
		var picker: OptionButton = item.duty_picker
		picker.item_selected.emit(picker.get_item_index(RetainerData.Duty.HARVEST))
	await _button(panel.get_node("CloseButton"))

func _first_year() -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.new_button)
	_estate()
	await _open_calendar()
	_expect("第 22 天" in ui.calendar.title.text and "酉时点灯" in ui.calendar.event_note.text,
		"The almanac tells a first-year player when and where to bring the ingredients.")
	await _frame("01-almanac")
	await _key(KEY_ESCAPE)
	await _enable_rations()
	while state.current_day < 22 and not failed:
		if state.raid_day > 0:
			await _defend()
		await _key(KEY_1)
		await _tend(PUBLIC)
		for cell: Vector2i in MILLET:
			await _tend(cell)
		await _key(KEY_5)
		await _tend(BEANS)
		if state.current_day >= 19:
			await _key(KEY_4)
			await _tend(WHEAT, state.current_day == 19)
		if state.current_day == 5 and not await _recruit_and_fish():
			return false
		if state.current_day == 21:
			await _assign_harvesters()
			_expect("明日冬至" in ui.hud.gathering_label.text, "The solstice eve reminds the player what to prepare.")
		await _sleep()
	print("WINTER_FIRST_YEAR day=", state.current_day, " retainers=", state.retainers.size(), " raids=", state.raids_defeated,
		" tribute=", state.king_storage, " wheat=", state.crop_stock.count("wheat"), " beans=", state.crop_stock.count("beans"),
		" grain=", state.food_storage, " fish=", state.fish_for_travel_meal())
	return _expect(not failed and state.current_day == 22 and state.retainer_food_cost() == 4 and state.raids_defeated == 2
		and state.king_storage >= 8 and state.crop_stock.count("wheat") >= 1 and state.crop_stock.count("beans") >= 1
		and not state.fish_for_travel_meal().is_empty(), "Reach the first solstice with privately grown crops, a fish and two working retainers.")

func _open_supper() -> Control:
	await _key(KEY_E)
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	if _expect(dialog != null and dialog.name_label.text == WinterSupper.HOST, "E at the table opens He Bo's supper dialogue."):
		var portrait := dialog.portrait.texture as AtlasTexture
		_expect(portrait != null and portrait.atlas.resource_path == CharacterArt.TOWN_PORTRAITS
			and portrait.region == Rect2(48, 48, 48, 48), "The supper shows the host's own bust portrait.")
		return dialog
	return null

func _to_evening() -> void:
	state.advance_daylight(maxf(0.0, 0.77 - state.day_progress) * state.balance.daylight_seconds)
	await tree.create_timer(0.12).timeout

func _show_scene() -> bool:
	var table: Node2D = world.get_node("WinterSupper")
	if not _expect(table.visible and not world.get_node("AutumnExhibit").visible, "The shared festival ground displays the winter table."):
		return false
	await _open_calendar()
	await _button(ui.calendar.guide)
	_expect(ui.directions.tracked_place == WinterSupper.PLACE, "The almanac points to the festival table.")
	await _walk_to_table()
	var guests := table.get_node("Guests")
	var first: Node2D = guests.get_child(0)
	state.advance_daylight(maxf(0.0, 0.57 - state.day_progress) * state.balance.daylight_seconds)
	await tree.create_timer(0.16).timeout
	var previous := first.position
	await tree.create_timer(0.68).timeout
	_expect(first.visible and first.position != previous, "The familiar neighbor walks in along the east track.")
	await _frame("02-arrivals")
	await _to_evening()
	_expect(state.day_watch_label() == "酉时" and guests.get_child(1).visible
		and table.get_node("Lanterns").get_child(0).glow.enabled and table.get_node("Lanterns").get_child(1).glow.enabled,
		"At the announced evening watch both lamps are lit and the neighbors have arrived.")
	await _frame("03-lanterns")
	return not failed

func _choose(recipe: String, expected_servings: int) -> bool:
	var dialog := await _open_supper()
	if dialog == null:
		return false
	_expect(dialog.text_label.get_content_height() <= dialog.text_label.size.y
		and dialog.text_label.get_global_rect().end.y < dialog.options_container.get_global_rect().position.y,
		"The three lines of recipe and ration information fit above the choices.")
	var wheat: int = state.crop_stock.count("wheat")
	var beans: int = state.crop_stock.count("beans")
	var fish: String = state.fish_for_travel_meal()
	var tribute: int = state.king_storage
	var rites: int = state.player_stats.stats["RITES"]["xp"]
	var has_fish := recipe == WinterSupper.FISH
	if has_fish:
		await _frame("04-supper-choice")
	await _button(dialog.options_container.get_child(1 if has_fish else 0))
	var record: Dictionary = state.winter_supper_record()
	var plan: Dictionary = state.night_rations_plan()
	_expect(record.get("recipe") == recipe and plan.supper == expected_servings and plan.need == 4
		and state.crop_stock.count("wheat") == wheat - 1 and state.crop_stock.count("beans") == beans - (0 if has_fish else 1)
		and state.fish_count(fish) == (0 if has_fish else 1) and state.king_storage == tribute
		and state.player_stats.stats["RITES"]["xp"] == rites + state.balance.winter_supper_rites,
		"The chosen dish charges only its private ingredients and earns rites once.")
	if has_fish:
		await _frame("04b-served-at-the-table")
	dialog = await _open_supper()
	if dialog:
		_expect(_find_dialog_button(dialog, "备") == null, "A prepared feast offers a visit and does not allow a second purchase.")
		await _key(KEY_ESCAPE)
	print("WINTER_MEAL day=", state.current_day, " recipe=", recipe, " portions=", record.get("portions"), " applied=", plan.supper)
	return not failed

func _serve(expected_servings: int, prefix: String) -> void:
	var grain: int = state.food_storage
	var planned: Dictionary = state.night_rations_plan()
	_expect(planned.uncovered == 0, "Any portions beyond the feast can be covered by the usual night plan.")
	await _button(ui.hud.rations_button)
	var panel := ui.get_node("Control/NightRationsPanel")
	_expect("围炉" in panel.forecast.text, "The normal night planner describes the prepared supper.")
	if prefix == "fish":
		await _frame("05-tonight")
	await _button(panel.close_button)
	await _sleep()
	var last: Dictionary = state.night_rations.last
	var remainder: int = planned.need - expected_servings
	_expect(last.get("supper") == expected_servings and last.served == planned.need
		and state.food_storage == grain + planned.converted + planned.bought - remainder
		and last.used == planned.used and last.bought == planned.bought and not world.get_node("WinterSupper").visible
		and state.night_rations_plan().supper == 0, "Only the confirmed night receives the supper, then the stage closes.")
	await _button(ui.hud.rations_button)
	panel = ui.get_node("Control/NightRationsPanel")
	_expect(("围炉 %d 份" % expected_servings) in panel.receipt.text, "The night ledger records the portions actually served.")
	if prefix == "fish":
		await _frame("06-morning-ledger")
	await _button(panel.close_button)
	print("WINTER_DAWN day=", state.current_day, " recipe=", prefix, " supper=", last.get("supper"),
		" conversion=", last.used, " grain=", grain, "->", state.food_storage)

func _load(path: String) -> void:
	_expect(state.load_game(path) == OK, "Load the selected winter checkpoint.")
	await tree.scene_changed
	_estate()

func _finish_supper() -> void:
	var before: String = state.latest_saved_game()["path"]
	if not await _show_scene() or not await _choose(WinterSupper.BEAN, 3):
		return
	await _serve(3, "bean")
	await _load(before)
	await _walk_to_table()
	await _to_evening()
	if not await _choose(WinterSupper.FISH, 4):
		return
	_expect(state.save_game() == OK, "Save the prepared feast before sleeping.")
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	_estate()
	_expect(state.winter_supper_record().get("recipe") == WinterSupper.FISH and state.night_rations_plan().supper == 4
		and state.fish_for_travel_meal().is_empty(), "Continue restores the spent fish and the full evening forecast.")
	await _serve(4, "fish")
	var morning: String = state.latest_saved_game()["path"]
	await _load(morning)
	_expect(state.night_rations.last.get("supper") == 4 and state.night_rations_plan().supper == 0, "Morning reload restores the ledger without serving the feast twice.")
	await _open_calendar()
	_expect("鱼麦羹" in ui.calendar.event_note.text and not ui.calendar.guide.visible, "The past solstice remains readable in the almanac.")
	await _key(KEY_ESCAPE)

func _next_winter() -> void:
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.manual_save_path()))
	saved.current_day += state.SOLAR_TERMS.size() * state.balance.days_per_solar_term
	var path := "user://next-winter.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	await _load(path)
	await _walk_to_table()
	var dialog := await _open_supper()
	if dialog:
		_expect("去年的鱼麦羹" in dialog.text_label.text and state.winter_supper_record().is_empty(),
			"The next solstice remembers the dish and opens a new supper.")
		await _key(KEY_ESCAPE)
	print("WINTER_RETURN day=", state.current_day, " earlier=", state.winter_supper_record(22).get("recipe"))

func run(host: SceneTree, capture := "") -> void:
	tree = host
	captures = capture
	state = tree.root.get_node("Global")
	tree.root.notify_mouse_entered()
	seed(325)
	if await _first_year():
		await _finish_supper()
	if not failed and DisplayServer.get_name() == "headless":
		await _next_winter()
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.process_frame
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
