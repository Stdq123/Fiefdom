extends SceneTree

const FIRST := Vector2i(5, 5)
const SECOND := Vector2i(9, 5)
const DRY := Vector2i(4, 6)
const BLOCKED := Vector2i(6, 6)

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect(ok: bool, note: String) -> void:
	if not ok:
		failed = true
		push_error(note)

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the estate overview check with an isolated smoke profile.")
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	var items := root.get_node("ItemManager")
	state.current_day = 31
	state.current_rank = state.Rank.ZHONG_SHI
	state._update_max_well_fields()
	state.king_storage = 5
	state.well_fields.assign([
		{"field_id": 0, "center_pos": FIRST, "is_unlocked": true, "reclamation_progress": 4, "assigned_retainers": []},
		{"field_id": 1, "center_pos": SECOND, "is_unlocked": true, "reclamation_progress": 4, "assigned_retainers": []}])
	var channels: Dictionary[Vector2i, bool] = {Vector2i(2, 5): true, Vector2i(3, 5): true, Vector2i(3, 4): true}
	for x in range(3, 11):
		channels[Vector2i(x, 3)] = true
	state.irrigation.restore(Vector2i(1, 5), channels)
	state.active_crops[DRY] = {"id": "beans", "data": items.get_crop("beans"), "age": 1,
		"growth_nights": 3, "watered": false, "requires_channel": false}
	state.active_crops[BLOCKED] = {"id": "rice", "data": items.get_crop("rice"), "age": 1,
		"growth_nights": 3, "watered": false, "requires_channel": true}
	state.tilled_cells[DRY] = true
	state.tilled_cells[BLOCKED] = true
	if change_scene_to_file("res://scenes/Main.tscn") != OK:
		quit(1)
		return
	await scene_changed
	var ui := current_scene.get_node("UI")
	ui._show_estate_management(0)
	var panel: Control = ui.panel_manager.management_panel_instance
	var tiles: Array[Node] = panel.map_grid_container.get_children()
	var thirsty := tiles[6] as Button
	var cut_off := tiles[8] as Button
	var first_size := thirsty.get_theme_font_size(&"font_size")
	_expect(tiles.size() == 9 and thirsty.grid_pos == DRY and cut_off.grid_pos == BLOCKED
		and "待浇" in thirsty.text and "断水" in cut_off.text and thirsty.picture.crop_region.has_area(),
		"The nine plots show their real crop and distinct water states.")
	_expect(thirsty.picture.mouse_filter == Control.MOUSE_FILTER_IGNORE and thirsty._can_drop_data(Vector2.ZERO, state.retainers[0]),
		"The crop preview passes input to its existing plot and retainer target.")
	_expect(root.get_node("Preferences").set_reading_size(2) == OK and thirsty.get_theme_font_size(&"font_size") == first_size + 6,
		"Plot text follows the largest reading preference.")

	panel.show_estate(1)
	await process_frame
	await process_frame
	_expect(panel.field_summary.text == "公田 1 格 · 私田 8 格 · 接渠水 3/9 格",
		"The second field counts its own public plans and locally supplied cells.")
	state.council_tribute_rows = true
	root.get_node("GameEvents").council_tribute_rows_changed.emit()
	_expect("公田 4 格 · 私田 5 格" in panel.field_summary.text, "The field header follows the council footprint.")
	state.tax_reform_choice = state.TaxReformChoice.REFORMED
	panel._refresh_field_tiles()
	_expect("公田 0 格 · 私田 9 格" in panel.field_summary.text, "Reform uses the existing private ownership rules.")
	var grid_box: Rect2 = panel.map_grid_container.get_global_rect()
	_expect(root.get_visible_rect().encloses(grid_box) and not grid_box.intersects(panel.overview_scroll.get_global_rect())
		and root.get_visible_rect().encloses(panel.apply_private_plan.get_global_rect()), "Nine plots and the action stay outside the scrolling quotes.")
	_expect(paused and state.current_day == 31 and state.active_crops.size() == 2 and state.field_seed_plans.is_empty()
		and state.saved_games().is_empty(), "Browsing does not book a plan, move the clock or write a save.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
