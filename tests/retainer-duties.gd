extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		push_error(detail)
		failed = true

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run retainer-duties with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	var save := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	save.store_string('{"current_day":2,"food_storage":9,"reputation":20,"retainers":[{"name":"渠伯","school":2},{"name":"季青","school":1}],"silk_workshop":{"built":true,"cocoons":2},"well_fields":[{"center_pos":"5,5","is_unlocked":true,"reclamation_progress":4}]}')
	save.close()
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	current_scene.continue_button.pressed.emit()
	await scene_changed
	var state := root.get_node("Global")
	_expect(not state.silk_workshop.night_reeling, "An older workshop save defaults to manual reeling.")
	var ui := current_scene.get_node("UI")
	ui.manage_button.pressed.emit()
	await process_frame
	var management = ui.panel_manager.management_panel_instance
	var artisan = management.retainer_list_container.get_child(0)
	var scholar = management.retainer_list_container.get_child(1)
	_expect(artisan.duty_picker.is_item_disabled(2) and scholar.duty_picker.is_item_disabled(1), "The roster limits each assignment to the correct school.")
	artisan.duty_picker.item_selected.emit(1)
	scholar.duty_picker.item_selected.emit(2)
	await process_frame
	_expect("每夜耗粮 4" in management.food_label.text, "Two specialists show their combined food cost.")
	var silk = management.get_node("HBoxContainer/RightPanel/蚕桑")
	_expect("3 生丝" in silk.buttons[2].text, "The workshop displays the actual output with a Mohist specialist.")
	silk.buttons[2].pressed.emit()
	_expect(state.silk_workshop.raw_silk == 3 and state.silk_workshop.cocoons == 1, "The Mohist assignment increases thread from a cocoon.")
	management.get_node("CloseButton").pressed.emit()
	ui.sleep_button.pressed.emit()
	await create_timer(1.1).timeout
	_expect(state.food_storage == 5 and state.reputation == 26 and state.player_stats.stats["RITES"]["xp"] == 5,
		"Feeding two specialists enables a Confucian lesson at night.")
	_expect(state.silk_workshop.cocoons == 1 and state.silk_workshop.raw_silk == 3, "Manual mode leaves the remaining cocoon alone overnight.")
	ui.manage_button.pressed.emit()
	await process_frame
	silk.night_reeling_button.button_pressed = true
	management.get_node("CloseButton").pressed.emit()
	ui.sleep_button.pressed.emit()
	await create_timer(1.1).timeout
	_expect(state.food_storage == 1 and state.silk_workshop.cocoons == 0 and state.silk_workshop.raw_silk == 6
		and state.silk_workshop.last_reeled == 1 and state.silk_workshop.last_reel_thread == 3,
		"A fed specialist processes one cocoon and reports the silk produced.")
	_expect(state.save_game() == OK and state.load_game() == OK, "Assignments are included in the save.")
	await scene_changed
	ui = current_scene.get_node("UI")
	_expect(state.retainers[0].duty == 1 and state.retainers[1].duty == 2 and state.silk_thread_yield() == 3,
		"Both specialist duties are restored with their effects.")
	_expect(state.silk_workshop.night_reeling and state.silk_workshop.last_reeled == 1 and state.silk_workshop.raw_silk == 6,
		"The night order and its completed work survive reload.")
	state.food_storage = 0
	state.silk_workshop.cocoons = 1
	for retainer in state.retainers:
		retainer.loyalty = 10
	ui.sleep_button.pressed.emit()
	await create_timer(1.1).timeout
	_expect(state.retainers.is_empty() and state.silk_thread_yield() == 2, "When unfed retainers leave, their work bonuses stop.")
	_expect(state.silk_workshop.cocoons == 1 and state.silk_workshop.raw_silk == 6 and state.silk_workshop.last_reeled == 0,
		"Unfed specialists leave both cocoon and thread stocks as they were.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
