extends SceneTree

const FIELD := Vector2i(9, 5)
const ROAD := Vector2i(1, 8)

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the reclamation ledger check with an isolated smoke profile.")
		quit(1)
		return
	paused = true
	if change_scene_to_file("res://scenes/Main.tscn") != OK:
		push_error("Could not open the paused estate.")
		quit(1)
		return
	await scene_changed
	var state := root.get_node("Global")
	var prefs := root.get_node("Preferences")
	var ui := current_scene.get_node("UI")
	ui._on_reclaim_pressed()
	var panel := ui.get_node("Control/ReclamationPanel") as Control
	var note_size: int = panel.info_label.get_theme_font_size(&"font_size")
	_expect(panel.reclaim_button.disabled and panel.validity_label.text.is_empty()
		and not panel.site_diagram.is_visible_in_tree() and "按中士田额估算费用" in panel.subtitle.text,
		"The locked ledger explains the next rank's estimate.")
	_expect(prefs.set_reading_size(2) == OK and panel.info_label.get_theme_font_size(&"font_size") == note_size + 6,
		"The open ledger follows the reading preference.")

	state.current_rank = state.Rank.ZHONG_SHI
	state._update_max_well_fields()
	var person := load("res://scripts/RetainerData.gd") as GDScript
	state.retainers.append(person.new("田庚", "农夫"))
	state.retainers.append(person.new("丁禾", "农夫"))
	var channels: Dictionary[Vector2i, bool] = {Vector2i(2, 5): true, Vector2i(3, 5): true, Vector2i(3, 4): true}
	for x in range(3, 11):
		channels[Vector2i(x, 3)] = true
	state.irrigation.restore(Vector2i(1, 5), channels)
	var quote: Dictionary = state.reclamation_plan()
	state.money = quote.copper - 3
	state.food_storage = quote.grain - 2
	panel._refresh()
	panel._select_site(FIELD)
	_expect(panel.reclaim_button.disabled and "差 3" in panel.copper_label.text and "差 2" in panel.grain_label.text,
		"Both shortfalls for staking are named.")
	state.money = quote.copper
	state.food_storage = quote.grain + 5
	panel._refresh()
	var watered: Array[Vector2i] = [Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4)]
	_expect(panel.preview_watered == watered and panel.site_diagram.is_visible_in_tree()
		and "3/9" in panel.validity_label.text, "The diagram uses the surveyed plot's actual supplied row.")
	_expect("立桩后 5/" in panel.crew_label.text and "差 %d" % (quote.crew_food - 5) in panel.crew_label.text
		and panel.market_button.visible and not panel.reclaim_button.disabled,
		"The crew food forecast leaves the existing stake conditions and reserve link intact.")
	var body := panel.get_node("%Scroll") as ScrollContainer
	await process_frame
	await process_frame
	var diagram_box: Rect2 = panel.site_diagram.get_global_rect()
	_expect(panel.get_node("Panel").get_global_rect().encloses(diagram_box)
		and not body.get_global_rect().intersects(diagram_box),
		"The survey stays below the scrolling ledger at the largest reading size.")
	panel._select_site(ROAD)
	_expect("路肩" in panel.validity_label.text and panel.preview_watered.is_empty() and panel.reclaim_button.disabled,
		"The road conflict clears the water preview and disables the stake button.")

	state.food_storage = quote.grain + int(quote.crew_food)
	panel._refresh()
	panel._select_site(FIELD)
	await process_frame
	await process_frame
	var close_box: Rect2 = panel.close_button.get_global_rect()
	_expect(panel.get_node("Panel").get_global_rect().encloses(close_box)
		and not body.get_global_rect().intersects(close_box), "The return action stays outside the reading area.")
	_expect(not panel.market_button.visible and not panel.reclaim_button.disabled and "差" not in panel.crew_label.text,
		"Funding the whole estimate clears the shortage.")
	_expect(paused and state.current_day == 1 and state.well_fields.size() == 1 and state.money == quote.copper
		and state.food_storage == quote.grain + int(quote.crew_food) and state.saved_games().is_empty(),
		"Previewing has no effect on the day, stock or saves.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
