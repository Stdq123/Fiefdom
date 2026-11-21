extends SceneTree

const GUIDE := "蒲宁"

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect(ok: bool, note: String) -> void:
	if not ok:
		failed = true
		push_error(note)

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the ravine journal reading check with an isolated smoke profile.")
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	var events := root.get_node("GameEvents")
	state.current_day = 4
	state.day_progress = 0.36
	if change_scene_to_file("res://scenes/Main.tscn") != OK:
		quit(1)
		return
	await scene_changed
	var ui := current_scene.get_node("UI")
	var world := current_scene.get_node("World")
	ui.panel_manager.show_management_panel()
	var panel: Control = ui.panel_manager.management_panel_instance
	var book: Control = panel.tabs.get_node("溪行手记")
	panel.tabs.current_tab = 5
	await process_frame
	var rail: PanelContainer = book.get_node("RouteRail")
	var journal_theme := preload("res://resources/estate_hud_theme.tres")
	_expect(rail.get_theme_stylebox(&"panel") == journal_theme.get_stylebox(&"panel", &"HudLacquerTray"),
		"The route uses the same lacquer frame as the other estate journals.")
	for label: Label in [book.next_step, book.visitor_where, book.get_node("%FruitName"), book.get_node("%HerbName")]:
		_expect(label.get_theme_color(&"font_color").srgb_to_linear().get_luminance() > 0.55,
			"%s uses light text on its dark card." % label.name)

	_expect(book.is_visible_in_tree() and not panel.retainer_panel.visible and not book.pages.visible,
		"The unopened journal has its own page and keeps unrecorded notes out of view.")
	_expect("第 5 天来访" in book.visitor_where.text and not book.next_route.visible,
		"The page previews the guide's next visit when he is away.")
	state.current_day = 5
	world._refresh_visitor()
	_expect(book.next_route.visible and book.next_route.text == "找蒲宁", "The guide becomes a real direction option.")
	book.next_route.pressed.emit()
	_expect(not panel.visible and ui.directions.tracked_neighbor == GUIDE,
		"The introduction routes to the person in the estate.")
	ui.panel_manager.show_management_panel()

	state.visitor_encounters[GUIDE] = 5
	events.ravine_journal_changed.emit()
	_expect("浅滩东岸" in book.progress.text and "今日可记" in book.headings[RavineJournal.Site.FORD].text,
		"The dry day highlights its own trace location.")
	var earlier_size: int = book.notes[0].get_theme_font_size(&"font_size")
	_expect(root.get_node("Preferences").set_reading_size(2) == OK
		and book.notes[0].get_theme_font_size(&"font_size") == earlier_size + 6, "The open journal responds to the reading preference.")
	book.next_route.pressed.emit()
	_expect(not panel.visible and ui.directions.tracked_place == "东关"
		and ui.directions.tracked_place_point == world.to_local(world.get_node("EastGate").global_position),
		"Heading out to a water trace marks the existing east gate.")
	ui.panel_manager.show_management_panel()

	state.current_day = 6
	events.ravine_journal_changed.emit()
	_expect("雨天" in book.today.text and "木桥西端" in book.progress.text, "Rain changes the active location to the bridge.")
	state.ravine_journal.recorded_days[RavineJournal.Site.BRIDGE] = 6
	events.ravine_journal_changed.emit()
	_expect(not book.next_route.visible and "今日已记" in book.progress.text and not book.forage_routes[0].disabled,
		"Recording a trace still leaves an outing available.")
	state.current_day = 7
	state.last_forage_day = 7
	events.forage_taken.emit()
	_expect("今日记" in book.progress.text and "今日采集已用" in book.outing_status.text and book.forage_routes[1].disabled,
		"Taking the outing still leaves the day's trace available.")
	_expect("晴天" in book.today.text and "谷雨" in book.headings[0].text and "雨天" in book.headings[0].text
		and "雨水沿桥柱" in book.notes[0].text, "The bridge note keeps the day, term and weather on which it was written.")

	state.ravine_journal.recorded_days.assign([6, 7, 8])
	state.current_day = 9
	events.ravine_journal_changed.emit()
	_expect("3/3" in book.progress.text and "交给蒲宁" in book.next_step.text and book.next_route.visible,
		"The completed pages show the handoff and the returning guide.")
	state.ravine_journal.garden_day = 9
	events.ravine_journal_changed.emit()
	var herbs: TextureRect = book.get_node("%GardenArt")
	var grown := herbs.texture
	_expect(book.garden_card.visible and "留到受伤时" in book.garden.text and book.next_route.text == "指路去药圃",
		"The completed handoff opens the herb bed reading.")
	state.health = state.balance.player_max_health - 2
	events.health_changed.emit(state.health)
	_expect("气血 +2" in book.garden.text and "气血 +2" in book.forage_notes[1].text, "Both remedy quotes use current health.")
	state.ravine_journal.garden_harvest_day = 9
	events.ravine_journal_changed.emit()
	_expect("新叶还需" in book.garden.text and grown != herbs.texture, "Regrowth shows the actual waiting time and illustration.")
	var position: Vector2 = world.player.position
	var health: int = state.health
	var food: int = state.food_storage
	book.next_route.pressed.emit()
	_expect(not panel.visible and ui.directions.tracked_place == "药圃"
		and ui.directions.tracked_place_point == world.to_local(world.get_node("HerbGarden").global_position),
		"The garden route points to the usable herb bed.")
	ui.panel_manager.show_management_panel()
	book.forage_routes[0].pressed.emit()
	_expect(not panel.visible and state.ravine_trip_target == "野果坳", "The outing reuses the existing regional route.")
	_expect(paused and world.player.position == position and state.current_day == 9 and is_equal_approx(state.day_progress, 0.36)
		and state.last_forage_day == 7 and state.health == health and state.food_storage == food
		and state.ravine_journal.recorded_days == [6, 7, 8] and state.ravine_journal.garden_harvest_day == 9
		and state.saved_games().is_empty(), "Browsing and marking directions leave the fixture's progress in place.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
