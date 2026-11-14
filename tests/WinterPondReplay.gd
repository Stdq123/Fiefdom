extends "res://tests/WinterSupperReplay.gd"

func _stage_solstice() -> bool:
	var checkpoint := {
		"current_day": 22, "food_storage": 0, "money": 12, "king_storage": 4, "reputation": 60,
		"player_inventory": 1, "crop_stock": {"wheat": 1},
		"retainers": [{"name": "渠伯", "duty": RetainerData.Duty.FIELD}],
		"season_order_receipts": {"summer": {"day": 10, "dispatch_day": 10}},
	}
	var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(checkpoint))
	file.close()
	await _continue_from_title()
	return _expect(state.current_day == 22 and state.pond_landing_day() == 10 and not state.knows_ravine_journal(),
		"An old season receipt opens the pond even if the player has never learned to fish in the ravine.")

func _continue_from_title() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	_estate()
	await tree.process_frame

func _pond_route() -> bool:
	var notice: Button = ui.hud.season_event_button
	await _button(notice)
	if not _expect(ui.calendar.fish_guide.is_visible_in_tree() and ui.calendar.fish_guide.text == "指路去南池钓台",
		"The almanac offers the unlocked pond from the real solstice notice."):
		return false
	await _frame("winter-pond-01-almanac")
	await _button(ui.calendar.fish_guide)
	if not _expect(ui.directions.tracked_place == state.POND_LANDING and state.ravine_trip_target.is_empty(),
		"The first route goes to the pond on the estate."):
		return false
	if not _expect(state.save_game() == OK, "Save the actual dock route before following it."):
		return false
	await _continue_from_title()
	_expect(ui.directions.tracked_place == state.POND_LANDING and state.market_trip_target == state.POND_LANDING,
		"The title restores the active route to the open landing.")
	await _walk_to_table()
	var dialog := await _open_supper()
	if dialog == null:
		return false
	var dock_route := _find_dialog_button(dialog, "指路去南池钓台")
	if not _expect(dock_route != null and dialog.options_container.get_child(1).disabled,
		"He Bo points to the same landing when fish soup is missing its fish."):
		return false
	await _frame("winter-pond-02-host-directions")
	await _button(dock_route)
	var landing := world.get_node("Scenery/PondLanding") as Node2D
	await Campaign.walk_estate_road_to(tree, world, landing.global_position)
	return _expect(world.player.interaction_target == landing and EstateLayout.POND_DECK.has_point(world.player.position),
		"The return path from the table reaches a working fishing position on the wooden boards.")

func _land_pond_fish() -> bool:
	await _key(KEY_E)
	var panel := ui.get_node_or_null("Control/FishingPanel") as Control
	if not _expect(panel != null, "Interact on the wooden platform to begin fishing."):
		return false
	for frame in 150:
		if panel.phase != panel.Phase.WAITING:
			break
		await tree.process_frame
	_key_event(KEY_SPACE, true)
	for frame in 300:
		if panel.phase != panel.Phase.REELING:
			break
		if panel.holding and panel.tension > 0.65:
			_key_event(KEY_SPACE, false)
		elif not panel.holding and panel.tension < 0.43:
			_key_event(KEY_SPACE, true)
		await tree.process_frame
	_key_event(KEY_SPACE, false)
	var go := panel.find_child("WinterSupperRoute", true, false) as Button
	if not _expect(panel.phase == panel.Phase.DONE and panel.catch_icon.visible and go != null
		and "今日冬至围炉" in panel.detail.text and state.fish_count("crucian") == 1
		and state.fish_collection.crucian.first_site == CreekFish.Site.POND
		and panel.find_child("HearthRoute", true, false) != null and panel.find_child("FishDelivery", true, false) != null,
		"A new pond catch offers the feast, hearth and winter fish delivery as usable choices."):
		return false
	await tree.process_frame
	var viewport := tree.root.get_visible_rect()
	var bounds := panel.get_global_rect()
	_expect(viewport.encloses(bounds) and viewport.end.y - bounds.end.y >= 14.0
		and bounds.encloses(panel.actions.get_global_rect()),
		"The complete catch result and close button fit above the bottom margin.")
	await _frame("winter-pond-03-catch-and-return")
	await _button(go)
	return _expect(ui.directions.tracked_place == WinterSupper.PLACE and not tree.paused,
		"The result starts the walking route to the table.")

func _cook_and_serve() -> void:
	var tribute: int = state.king_storage
	if not _expect(state.save_game() == OK, "Save the catch and the route back to the table."):
		return
	await _continue_from_title()
	_expect(ui.directions.tracked_place == WinterSupper.PLACE and state.fish_count("crucian") == 1,
		"Continue restores the fish and the guide to the winter table.")
	await _walk_to_table()
	var dialog := await _open_supper()
	if dialog == null:
		return
	await _button(dialog.options_container.get_child(1))
	_expect(state.winter_supper_record().get("recipe") == WinterSupper.FISH and state.crop_stock.count("wheat") == 0
		and state.fish_count("crucian") == 0 and state.king_storage == tribute,
		"The feast takes one private wheat and the actual pond fish while leaving tribute alone.")
	await _frame("winter-pond-04-supper")
	await Campaign.walk_estate_road_to(tree, world, EstateLayout.FESTIVAL_BANK_BEND)
	await _button(ui.hud.season_event_button)
	_expect(not ui.calendar.fish_guide.visible and "已入簿" in ui.calendar.event_note.text,
		"A cooked supper never offers the fishing action again.")
	await _button(ui.calendar.guide)
	_expect(ui.directions.tracked_place == WinterSupper.PLACE, "The road to the table remains active from the pond bank before bed.")
	_expect(state.fishing_block_reason(false, CreekFish.Site.POND) == "今日垂钓机会已用",
		"Cooking the fish does not grant a second catch that day.")
	await _sleep()
	_expect(state.night_rations.last.get("supper") == 1 and state.night_rations.last.get("served") == 1
		and state.retainers.size() == 1 and state.king_storage == tribute and state.current_day == 23
		and ui.directions.tracked_place.is_empty(),
		"The next morning records the complete portion and closes any route to the festival.")
	print("WINTER_POND_SERVED day=", state.current_day, " catch_site=", state.fish_collection.crucian.first_site,
		" supper=", state.night_rations.last.get("supper"), " public=", state.king_storage)

func _south_trail() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.manual_save_path()))
	data.location = "ravine"
	data.ravine_journal = {"recorded_days": [5, 6, 7], "garden_day": 8}
	data.ravine_waypoint = RavineLayout.SOUTH_TRAIL_NAME
	data.ravine_south_arrival = true
	var path := "user://winter-south-trail.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	if not _expect(state.load_game(path) == OK, "Load a solstice return through an already opened ravine shortcut."):
		return
	await tree.scene_changed
	await tree.process_frame
	var ravine := tree.current_scene as Node2D
	if not _expect(ravine.active_waypoint() == RavineLayout.SOUTH_TRAIL_NAME
		and state.market_trip_target == WinterSupper.PLACE,
		"The route resumes through the open shortcut and still points to the winter table."):
		return
	await Campaign.walk_ravine_to(tree, ravine, ravine.get_node("SouthTrailArrival").global_position)
	if not await _cross(&"ui_down", state.ESTATE_SCENE):
		return
	_estate()
	await tree.process_frame
	_expect(ui.directions.tracked_place == WinterSupper.PLACE and state.market_trip_target == WinterSupper.PLACE
		and world.player.position.distance_to(world.get_node("RavineTrailArrival").position) < 15.0,
		"The south gate leads to the same winter table on the estate without detouring through the east gate.")
	print("WINTER_POND_SHORTCUT day=", state.current_day, " target=", ui.directions.tracked_place)

func run(host: SceneTree, capture := "") -> void:
	tree = host
	captures = capture
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the pond replay save."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	tree.root.notify_mouse_entered()
	seed(325)
	if await _stage_solstice() and await _pond_route() and await _land_pond_fish():
		await _cook_and_serve()
	if not failed:
		await _south_trail()
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.process_frame
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
