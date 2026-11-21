extends SceneTree

const KEEPER := "渠伯"
const ROAD_KEEPER := "季青"
const WATER_GUIDE := "石墨"

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _status(book: Control, speaker: String) -> Label:
	return book.roster.get_node(speaker).get_node("Inset/Row/Caption/Status") as Label

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the neighbor journal reading check with an isolated profile.")
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	var events := root.get_node("GameEvents")
	var residents := load("res://scripts/RetainerData.gd") as GDScript
	var keeper: RefCounted = residents.new(KEEPER, "井田管事")
	state.retainers.assign([keeper])
	state.current_day = 2
	state.day_progress = 0.35
	state.king_storage = 3
	state.food_storage = 1
	state.road_provisions_delivered = true
	state.road_provisions_day = 2
	state.neighbor_met_days.merge({KEEPER: 1, ROAD_KEEPER: 2, WATER_GUIDE: 1})
	state.neighbor_departures[WATER_GUIDE] = {"day": 1, "reason": state.DepartureReason.HUNGER, "returned_day": 0}
	if change_scene_to_file("res://scenes/Main.tscn") != OK:
		quit(1)
		return
	await scene_changed
	var world := current_scene.get_node("World")
	var ui := current_scene.get_node("UI")
	ui.panel_manager.show_management_panel()
	var panel: Control = ui.panel_manager.management_panel_instance
	panel.show_neighbors()
	var book: Control = panel.neighbor_journal
	await process_frame
	for label: Label in [book.where, book.appointment_note, book.memory, book.get_node("%Empty")]:
		_expect(label.get_theme_color(&"font_color").srgb_to_linear().get_luminance() > 0.55,
			"%s uses light text on its dark card." % label.name)
	_expect(_status(book, KEEPER).text == "留任门客" and _status(book, ROAD_KEEPER).text == "今日来访",
		"The roster distinguishes a resident and a visitor.")
	_expect(_status(book, WATER_GUIDE).text == "第 %d 天轮访" % state.next_visitor_day(WATER_GUIDE)
		and not book.roster.get_node("陶辛").visible, "The roster shows actual return dates and only familiar faces.")
	var visitor := book.roster.get_node(ROAD_KEEPER) as Button
	_expect(visitor.get_node(visitor.focus_neighbor_bottom).name == WATER_GUIDE,
		"The roster follows the visible order and skips unfamiliar people.")

	book.roster.get_node(WATER_GUIDE).pressed.emit()
	var gap: int = state.recruitment_food_requirement(WATER_GUIDE) - state.food_storage
	_expect(not book.locate_button.visible and not book.pavilion_card.visible and "还差 %d 份" % gap in book.where.text,
		"An absent neighbor gives a pantry shortage and only the future visit.")
	book.roster.get_node(ROAD_KEEPER).pressed.emit()
	_expect(book.locate_button.visible and book.pavilion_card.visible and "路粮匣" in book.appointment_title.text
		and "酉时" in book.appointment_note.text and "亭前晚坐" in book.appointment_note.text,
		"The related journal shows the available evening invitation.")
	var standard := _status(book, ROAD_KEEPER).get_theme_font_size(&"font_size")
	_expect(root.get_node("Preferences").set_reading_size(2) == OK
		and _status(book, ROAD_KEEPER).get_theme_font_size(&"font_size") == standard + 6, "Roster status follows reading size.")
	var position: Vector2 = world.player.position
	book.pavilion_route.pressed.emit()
	_expect(not panel.visible and ui.directions.tracked_place == "亭边候席"
		and ui.directions.tracked_place_point == world.pavilion_rest.gathering_approach()
		and world.player.position == position and is_equal_approx(state.day_progress, 0.35), "The journal uses the same waiting place as the pavilion.")

	state.current_day = 6
	state.day_progress = 0.35
	var host: RefCounted = residents.new(ROAD_KEEPER, "南路行客")
	state.retainers.append(host)
	world.spawn_retainer(host, true)
	world._refresh_visitor()
	events.daylight_changed.emit()
	ui.panel_manager.show_management_panel()
	_expect("申时" in book.appointment_note.text and "亭东雨棚" in book.appointment_note.text,
		"The same story follows the rainy day's time and place.")
	state.day_progress = 0.76
	for resident in [keeper, host]:
		var actor: Node2D = world.retainer_instances[resident]
		actor.evening_seat = world.pavilion_rest.seat_for(resident)
		actor.current_state = actor.State.IDLE
	world.pavilion_rest.refresh_table()
	_expect("已入席" in book.appointment_note.text and book.pavilion_route.text == "指路去席案",
		"The journal changes from the appointment to the ready conversation.")
	book.pavilion_route.pressed.emit()
	_expect(ui.directions.tracked_place == "灯下小谈" and not panel.visible, "The second stage marks the actual table.")
	_expect(paused and state.current_day == 6 and is_equal_approx(state.day_progress, 0.76)
		and world.player.position == position and state.food_storage == 1 and state.king_storage == 3
		and state.pavilion_stories_heard.is_empty() and state.saved_games().is_empty(),
		"Reading and routing preserve the fixture, the pantry and the unread story.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
