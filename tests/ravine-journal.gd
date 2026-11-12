extends "res://tests/trail-route.gd"

const FORD := 1
const BRIDGE := 0
const LOOKOUT := 2

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run ravine-journal with an isolated save.")
		quit(1)
		return
	seed(862)
	state = root.get_node("Global")
	change_scene_to_file(state.TITLE_SCENE)
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	walker = current_scene.get_node("World/Player")
	_expect(not current_scene.get_node("World/HerbGarden").visible and state.ravine_site_today() == -1,
		"The new estate has neither an active survey nor a garden.")

	for night in range(4):
		_tend_tribute()
		await _sleep_one_night()
	_tend_tribute()
	var dialog := await _visit_guide()
	if dialog == null:
		quit(1)
		return
	_expect("三处水迹" in dialog.text_label.text, "The guide introduces the three sites in person.")
	var first_portrait: Rect2 = dialog.portrait.texture.region
	await _choose(dialog, "交谈")
	_expect(state.ravine_site_today() == FORD, "The dry Qingming route starts at the ford.")
	var food_before: int = state.food_storage

	if not await _depart():
		return
	await _walk_trail(RavineLayout.FRUIT + Vector2(-7, 18))
	await _gather()
	_expect(state.food_storage == food_before + state.balance.wild_food_yield, "The old west-bank food stop still works.")
	await _walk_trail(RavineLayout.FORD_JOURNAL + Vector2(12, 9))
	await _record(FORD)
	await _gather()
	_expect(state.ravine_journal.count() == 1 and state.last_forage_day == 5,
		"Surveying is separate from foraging and repeating the interaction adds no page.")
	if not await _return_home() or not await _reload():
		return
	_expect(state.ravine_journal.recorded_days[FORD] == 5 and state.ravine_site_today() == -1,
		"The written page and one-per-day limit survive a same-day reload.")

	await _sleep_one_night()
	_expect(state.has_rain() and state.ravine_site_today() == BRIDGE, "Guyu rain directs the next trip to the bridge.")
	if not await _depart():
		return
	await _walk_trail(RavineLayout.BRIDGE_JOURNAL + Vector2(-10, 9))
	await _record(BRIDGE)
	if not await _return_home():
		return
	await _sleep_one_night()
	_expect(state.ravine_site_today() == LOOKOUT, "The last unrecorded site is the lookout.")

	if not await _depart():
		return
	await _walk_trail(RavineLayout.LOOKOUT_JOURNAL + Vector2(-8, 11))
	await _record(LOOKOUT)
	_expect(state.ravine_handoff_ready() and not state.ravine_shortcut_open(),
		"Three different dates complete the survey. The gate waits for the handoff.")
	if not await _return_home():
		return
	var estate := current_scene.get_node("World")
	_expect(estate.neighbor_actor("蒲宁") != null and estate.current_visitor().name == "季青",
		"The guide returns for the handoff alongside the usual visitor.")

	var ui := current_scene.get_node("UI")
	ui.manage_button.pressed.emit()
	var management: Control = ui.panel_manager.management_panel_instance
	var tabs := management.get_node("HBoxContainer/RightPanel") as TabContainer
	tabs.current_tab = 5
	await process_frame
	var book := tabs.get_node("溪行手记")
	_expect("3/3" in book.progress.text and "谷雨" in book.headings[BRIDGE].text and "雨水沿桥柱" in book.notes[BRIDGE].text,
		"The journal shows the recorded date, season and rainy observation.")
	management.get_node("CloseButton").pressed.emit()

	dialog = await _visit_guide()
	if dialog == null:
		quit(1)
		return
	await _choose(dialog, "交溪行手记")
	var garden := current_scene.get_node("World/HerbGarden") as Node2D
	_expect(garden.visible and state.ravine_journal.garden_day == 7 and state.ravine_shortcut_open()
		and not state.deliver_ravine_journal(), "The handoff opens the gate and establishes one visible garden.")
	dialog = await _visit_guide()
	if dialog == null:
		quit(1)
		return
	_expect("药圃" in dialog.text_label.text and dialog.portrait.texture.region != first_portrait,
		"The guide's portrait and dialogue reflect the finished garden.")
	await _choose(dialog, "离开")
	await _walk(garden.global_position + Vector2(0, 18))
	await _gather()
	_expect(state.ravine_journal.garden_harvest_day == 0, "Full health leaves the mature leaves on the bed.")
	state.hurt_player(30)
	var wounded: int = state.health
	await _gather()
	_expect(state.health == wounded + state.balance.wild_herb_healing and state.ravine_journal.garden_harvest_day == 7
		and state.last_forage_day == 5, "The garden heals separately from wilderness gathering.")
	var healed: int = state.health
	await _gather()
	_expect(state.health == healed and state.herb_garden_wait() == 3, "The same-day interaction cannot harvest the leaves twice.")
	if not await _reload():
		return
	_expect(state.herb_garden_wait() == 3 and state.ravine_journal.garden_day == 7 and state.ravine_journal.count() == 3,
		"The completed survey, garden and regrowth date survive reload.")

	garden = current_scene.get_node("World/HerbGarden")
	await _walk(garden.global_position + Vector2(0, 18))
	for night in range(3):
		await _sleep_one_night()
	_expect(state.herb_garden_wait() == 0 and state.current_day == 10, "The leaves grow back after three nights.")
	state.hurt_player(24)
	wounded = state.health
	var raid_notice: Label = current_scene.get_node("CampaignHUD").notice
	var notice_before := raid_notice.text
	await _gather()
	_expect(state.health == wounded + state.balance.wild_herb_healing and state.ravine_journal.garden_harvest_day == 10,
		"The garden can actually be picked again after regrowing.")
	_expect(raid_notice.text == notice_before, "Local garden feedback leaves the current estate alert in place.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _tend_tribute() -> void:
	var cell := Vector2i(5, 5)
	var world := current_scene.get_node("World")
	var crop: Dictionary = state.active_crops.get(cell, {})
	if not crop.is_empty() and crop.age >= crop.growth_nights:
		world.handle_interaction(cell)
	if not state.active_crops.has(cell):
		if not state.tilled_cells.has(cell):
			world.handle_interaction(cell)
		world.handle_interaction(cell)
	if world.is_crop_dry(cell):
		world.handle_interaction(cell)

func _sleep_one_night() -> void:
	var ui := current_scene.get_node("UI")
	var day: int = state.current_day
	ui.sleep_button.pressed.emit()
	for frame in range(180):
		if state.current_day == day + 1 and ui.fader.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return
		await process_frame
	_expect(false, "Sleeping advances one day and releases input.")

func _visit_guide() -> Control:
	var world := current_scene.get_node("World")
	for actor in world.active_visitors:
		if actor.data.name == "蒲宁":
			if walker.position.x > 116.0:
				await _walk(Vector2(116, 42))
			await _walk(actor.global_position + Vector2(0, 24))
			await _gather()
			var dialog := current_scene.get_node_or_null("UI/Control/DialoguePanel") as Control
			if dialog and dialog.name_label.text == "蒲宁":
				return dialog
	_expect(false, "The guide must be reachable through the estate's normal talk input.")
	return null

func _choose(dialog: Control, prefix: String) -> void:
	for button: Button in dialog.options_container.get_children():
		if button.text.begins_with(prefix) and not button.disabled:
			button.pressed.emit()
			await process_frame
			return
	_expect(false, "The conversation choice must be usable: " + prefix)

func _depart() -> bool:
	await _walk(Vector2(42, 98) if walker.position.x < 100 else Vector2(360, 4))
	return await _enter_trail()

func _record(site: int) -> void:
	var marker := current_scene.get_node("RavineMarker") as Node2D
	_expect(marker.visible and marker.site == site and "E" in marker.hint.text, "The scheduled marker can be reached on foot.")
	await _gather()
	_expect(state.ravine_journal.recorded_days[site] == state.current_day and not marker.visible,
		"The reachable site writes its page once and removes the active marker.")

func _reload() -> bool:
	if state.save_game() != OK or state.load_game() != OK:
		_expect(false, "The active estate can save and reload.")
		quit(1)
		return false
	await scene_changed
	walker = current_scene.get_node("World/Player")
	return true
