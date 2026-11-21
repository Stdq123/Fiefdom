extends SceneTree

var failed := false

func _initialize() -> void:
	_check.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _check() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run silk-reading in an isolated profile.")
		quit(1)
		return
	paused = true
	if change_scene_to_file("res://scenes/Main.tscn") != OK:
		push_error("Load the paused estate.")
		quit(1)
		return
	await scene_changed
	var state := root.get_node("Global")
	var prefs := root.get_node("Preferences")
	var manager: Node = current_scene.get_node("UI").panel_manager
	var workshop: RefCounted = state.silk_workshop
	var actions: Dictionary = workshop.get_script().Action
	state.money = 11
	manager.show_management_panel()
	manager.management_panel_instance.show_silk()
	var panel: Control = manager.management_panel_instance.silk_panel
	_expect(panel.build_status.text == "建蚕室 · 书 1/2 级 · 铜钱 11/25"
		and panel.buttons[actions.BUILD].disabled and panel.study_button.is_visible_in_tree(),
		"Construction shows both thresholds and the study action.")
	workshop.built = true
	workshop.leaves = 1
	workshop.raw_silk = 3
	panel._refresh()
	var tray: Node2D = current_scene.get_node("World/SilkInterior/SilkwormTray")
	var loom: Node2D = current_scene.get_node("World/SilkInterior/Loom")
	tray.set_interaction_focused(true)
	loom.set_interaction_focused(true)
	_expect(panel.buttons[actions.START_BATCH].disabled and "开养缺 1 片桑叶" in panel.status_label.text
		and "缺 1 片桑叶" in tray.hint.text
		and "织绸还缺 1 份生丝" in panel.stage_notes[actions.WEAVE].text
		and "织绸还缺 1 份生丝" in loom.hint.text, "The same missing inputs appear in the workshop and at the station.")
	workshop.leaves = 2
	panel._refresh()
	_expect(not panel.buttons[actions.START_BATCH].disabled and "共用 4 片桑叶" in panel.status_label.text
		and "备齐整批还缺 2 片" in panel.mulberry_note.text,
		"Starting with the first night's feed is distinct from stocking a full batch.")
	var before := [workshop.cocoons, workshop.raw_silk, workshop.bolts, workshop.leaves, state.money, state.current_day]
	var size: int = panel.status_label.get_theme_font_size("font_size")
	_expect(prefs.set_reading_size(2) == OK and panel.status_label.get_theme_font_size("font_size") == size + 6,
		"The operation descriptions follow the reading size.")
	_expect(panel.production.get_v_scroll_bar().focus_mode == Control.FOCUS_ALL,
		"The full ledger remains readable by keyboard when the body overflows.")
	_expect(before == [workshop.cocoons, workshop.raw_silk, workshop.bolts, workshop.leaves, state.money, state.current_day]
		and state.saved_games().is_empty(), "Reading preserves workshop inputs and the save catalog.")
	var room_review = load("res://tests/SilkRoomReadingReview.gd").new()
	_expect(await room_review.run(self), "The silk shed shows the same materials and keeps its stock visible at either reading size.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
