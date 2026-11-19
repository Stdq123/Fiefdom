extends "res://tests/NightRationsReplay.gd"

func _save_fixture(path: String, day: int, crops: Dictionary, order_receipts: Dictionary) -> void:
	var fixture := {
		"current_day": day, "food_storage": 0, "money": 10, "king_storage": 3, "reputation": 60,
		"player_inventory": NightRations.stock_count(crops), "crop_stock": crops,
		"retainers": [{"name": "渠伯", "school": 2, "duty": RetainerData.Duty.FIELD, "loyalty": 80}],
		"season_order_receipts": order_receipts,
		"night_rations": {"enabled": true, "copper_limit": 0},
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()

func _continue_from_title() -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	var button: Button = tree.current_scene.continue_button
	if not _expect(button.is_visible_in_tree() and not button.disabled, "The title recognizes the pantry checkpoint."):
		return false
	await _click(button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.has_node("UI"), "Continue opens the estate from the title."):
		return false
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame
	return true

func _load(path: String) -> bool:
	if not _expect(state.load_game(path) == OK, "Load the pantry comparison checkpoint."):
		return false
	await tree.scene_changed
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame
	return true

func _autumn() -> void:
	_save_fixture("user://savegame.json", 15, {"millet": 1, "sorghum": 2, "beans": 1}, {})
	if not await _continue_from_title():
		return
	var original: Dictionary = state.night_rations_plan()
	_expect(original.used == {"millet": 1} and original.festival_pantry.is_empty()
		and not state.can_set_festival_pantry(22), "An older save uses the last millet unless the player opts in during the notice.")
	await _click(ui.hud.season_event_button)
	var book: Control = ui.calendar
	if not _expect(book.keep_samples.is_visible_in_tree() and book.keep_samples.text == "夜里留谷样"
		and not book.keep_samples.button_pressed and "谷样已齐" in book.event_note.text,
		"The real autumn notice offers reservation with three varieties in the pantry."):
		return
	await _click(book.keep_samples)
	var kept: Dictionary = state.night_rations_plan()
	_expect(book.keep_samples.button_pressed and book.pantry_note.visible
		and "另留 黍 1" in book.pantry_note.text and "与时令单共用 稷 1、菽 1" in book.pantry_note.text
		and kept.festival_pantry.held == {"millet": 1} and kept.festival_pantry.shared == {"sorghum": 1, "beans": 1}
		and kept.current_reserved == {"sorghum": 2, "beans": 1} and kept.upcoming_reserved.is_empty()
		and kept.uncovered == 1 and state.money == 10 and state.player_inventory == 4,
		"The fair reserves only the extra millet, notes order overlap, and exposes the zero-budget shortage without spending.")
	await _capture("01-autumn-pantry")
	await _click(book.close_button)
	var panel := await _open()
	if not _expect(panel != null, "Open the ordinary night ledger for the protected pantry."):
		return
	_expect(panel.festival_pantry.visible and "秋社留用" in panel.festival_reserve.text
		and "还差 1 份" in panel.forecast.text and "5 铜钱" in panel.night_offer.text,
		"The ledger exposes the new shortage and a funded alternative to releasing the crops.")
	panel.scroll.ensure_control_visible(panel.accept_offer)
	await tree.process_frame
	await _capture("02-pantry-shortage")
	await _click(panel.accept_offer)
	_expect(state.night_rations.copper_limit == 5 and state.money == 10 and state.night_rations_plan().bought == 1,
		"Accepting the revised quote changes the cap without buying grain yet.")
	await _click(panel.close_button)
	if not _expect(state.save_game() == OK, "Save the opted-in evening before comparing the two overnights."):
		return
	var checkpoint: String = state.manual_save_path()
	if not await _continue_from_title():
		return
	_expect(state.night_rations.festival_day == 16 and state.night_rations_plan().bought == 1,
		"The title's Continue restores the dated hold and the same purchase forecast.")
	panel = await _open()
	panel.scroll.ensure_control_visible(panel.release_festival_reserve)
	await tree.process_frame
	await _click(panel.release_festival_reserve)
	_expect(not panel.festival_pantry.visible and panel.delegate.has_focus() and "转用 黍 1" in panel.forecast.text
		and state.night_rations_plan().used == {"millet": 1} and state.king_storage == 3,
		"Releasing the hold from bedtime immediately restores millet conversion and moves focus to a visible control.")
	await _click(panel.close_button)
	await _sleep()
	var released: Dictionary = state.night_rations.last
	_expect(state.current_day == 16 and released.get("used") == {"millet": 1} and released.get("bought") == 0
		and state.money == 10 and "谷样 2/3" in ui.hud.season_event_button.text,
		"With the hold released, actual bedtime uses the last millet and the fair falls one variety short.")
	if not await _load(checkpoint):
		return
	await _sleep()
	var served: Dictionary = state.night_rations.last
	_expect(state.current_day == 16 and served.get("used") == {} and served.get("copper") == 5
		and served.get("bought") == 1 and served.get("served") == 1 and state.money == 5
		and state.player_inventory == 4 and state.king_storage == 3 and "谷样 3/3" in ui.hud.season_event_button.text
		and state.night_rations.festival_day == 0 and state.night_rations_plan().festival_pantry.is_empty(),
		"The same saved evening with the hold buys one ration, keeps three samples, and releases the plan on the last playable day.")
	await _capture("03-autumn-still-ready")
	print("RATIONS_AUTUMN_PANTRY released=", released.get("used"), " protected=", served.get("used"),
		" bought=", served.get("bought"), " actual_copper=", served.get("copper"), " varieties=", AutumnExhibit.stocked_crops(state.crop_stock).size())

func _winter() -> void:
	var path := "user://winter-pantry.json"
	_save_fixture(path, 21, {"wheat": 1, "beans": 1}, {"winter": {"day": 20}})
	if not await _load(path):
		return
	_expect(state.night_rations_plan().used == {"wheat": 1}, "After the winter order is delivered, ordinary rations can use the last wheat.")
	state.set_night_rations(true, 5)
	await _click(ui.hud.season_event_button)
	var book: Control = ui.calendar
	await _click(book.keep_porridge)
	var porridge: Dictionary = state.night_rations_plan()
	_expect(porridge.festival_pantry.get("held") == {"wheat": 1, "beans": 1} and porridge.bought == 1
		and book.keep_porridge.button_pressed and "麦菽粥留用 · 另留 麦 1、菽 1" in book.pantry_note.text,
		"Porridge protects both crops before winter supper.")
	await _click(book.keep_soup)
	var soup: Dictionary = state.night_rations_plan()
	_expect(soup.festival_pantry.get("held") == {"wheat": 1} and soup.used == {"beans": 1} and soup.bought == 0
		and book.keep_soup.button_pressed and not book.keep_porridge.button_pressed and "鱼麦羹留用 · 另留 麦 1" in book.pantry_note.text,
		"Fish soup holds wheat and frees the bean for tonight's table.")
	await _capture("04-winter-recipe")
	await _click(book.close_button)
	await _sleep()
	var served: Dictionary = state.night_rations.last
	_expect(state.current_day == 22 and served.get("used") == {"beans": 1} and served.get("bought") == 0
		and state.crop_stock.count("wheat") == 1 and state.crop_stock.count("beans") == 0 and state.king_storage == 3
		and not state.can_set_festival_pantry(22), "The fish-soup choice is applied overnight, and expires by the one-day feast.")
	print("RATIONS_WINTER_PANTRY meal=", served.get("used"), " supper_wheat=", state.crop_stock.count("wheat"))

func _resume_after_ending() -> void:
	var path := "user://ending-pantry.json"
	_save_fixture(path, 21, {"wheat": 3, "hemp": 1}, {})
	var finished: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	finished.outcome = state.Outcome.TRADITIONAL
	finished.night_rations.festival_day = 22
	finished.night_rations.festival_recipe = WinterSupper.FISH
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(finished))
	file.close()
	if not await _load(path):
		return
	if not _expect(state.outcome == state.Outcome.TRADITIONAL and state.night_rations.festival_day == 22,
		"Loading the ending preserves the next day's valid reservation."):
		return
	var ending := tree.current_scene.get_node("CampaignHUD").summary as Control
	await _click(ending.continue_button)
	var restored: Dictionary = state.night_rations_plan()
	_expect(state.outcome == state.Outcome.RUNNING and restored.festival_pantry.get("held") == {"wheat": 1}
		and restored.current_reserved == {"hemp": 1, "wheat": 2} and restored.uncovered == 1,
		"Continuing after victory keeps a separate third wheat for the feast alongside the winter order.")
	print("RATIONS_PANTRY_CONTINUE day=", state.current_day, " held=", restored.festival_pantry.get("held"),
		" order=", restored.current_reserved)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated festival pantry profile."):
		_end()
		return
	if capture_dir.is_empty():
		capture_dir = OS.get_environment("FIEFDOM_PANTRY_CAPTURES")
	state = tree.root.get_node("Global")
	tree.root.notify_mouse_entered()
	seed(615)
	await _autumn()
	if not failed:
		await _winter()
	if not failed:
		await _resume_after_ending()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	tree.root.get_node("AudioManager").bgm_player.stop()
	await tree.create_timer(0.35).timeout
	_end()
