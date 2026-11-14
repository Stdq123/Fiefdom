extends "res://tests/CouncilPrepReplay.gd"

var previous_mode := ""

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	state = tree.root.get_node("Global")
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated sowing profile."):
		tree.quit(1)
		return
	tree.root.notify_mouse_entered()
	if previous_mode != "resume":
		_write_fixture(previous_mode == "write")
	await _continue()
	match previous_mode:
		"write":
			await _save_route()
			print("SOWING_OLD_WRITE day=", state.current_day, " plans=", state.field_seed_plans.size())
		"resume":
			_expect(state.current_day == 40 and state.deferred_field_sowing.is_empty()
				and state.field_seed_plans.get(PRIVATE_WHEAT) == "rotation:hemp"
				and state.field_seed_plans.get(PRIVATE_MILLET) == "beans"
				and state.planned_field_seed(PRIVATE_WHEAT) == "hemp",
				"An old Windows save keeps its active rotation without adding a hold.")
			await _open_book()
			_expect(book.sowing_button.visible, "The older plans can be managed through the ordinary ledger.")
			await _snapshot("10-old-plans-available")
			await _button(book.close_button)
			print("SOWING_OLD_CONTINUE day=", state.current_day, " plans=", state.field_seed_plans.size())
		_:
			await _delay_and_change_one_plot()
	tree.paused = false
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func _write_fixture(previous: bool) -> void:
	var save := SNAPSHOT.duplicate(true)
	save.current_day = 40 if previous else 49
	save.current_rank = 3
	save.king_storage = 29 if previous else 31
	save.private_harvest_total = 71
	save.money = 40
	save.active_crops = {"5,5": {"id": "millet", "age": 0, "growth_nights": 2}}
	save.tilled_cells = ["5,5", "5,6", "6,5"]
	save.field_seed_plans = {"5,5": "millet", "5,6": "beans", "6,5": "rotation:hemp"}
	save.field_rotation = {"promise_day": 7, "beans_day": 10, "harvest_day": 12,
		"crop_id": "hemp", "field_number": 1, "signed_day": 13}
	if previous:
		save.retainers[0].duty = RetainerData.Duty.TEACH
	else:
		# The two real holds survive and the public and invalid entries are ignored.
		save.deferred_field_sowing = ["6,5", "5,6", "5,5", "800,800"]
	var fixture := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify(save))
	fixture.close()

func _choose_council_option(choice: int, frame: String) -> bool:
	var event := await Campaign.meet_tax_envoy(tree)
	if not _expect(event != null and tree.paused, "Walk to the envoy and open the actual council."):
		return false
	await _button(event.option_buttons[choice])
	var caption := "延期研究" if choice == state.TaxReformChoice.DELAYED else "定案"
	_expect(event.confirm_button.text == caption, "The confirmation describes the selected action.")
	await _snapshot(frame)
	await _button(event.confirm_button)
	await _continue()
	return _expect(state.tax_reform_choice == choice, "Continue to the council decision that was just chosen.")

func _delay_and_change_one_plot() -> void:
	var delay: int = state.TaxReformChoice.DELAYED
	_expect(state.deferred_field_sowing.size() == 2 and not state.deferred_field_sowing.has(PUBLIC),
		"The loader retains only the existing private plans.")
	if not await _choose_council_option(delay, "01-delay-with-held-plans"):
		return
	var worker: RetainerData = state.retainers[0]
	_expect(state.current_day == 49 and state.deferred_field_sowing.size() == 2
		and state.field_job(worker, PRIVATE_WHEAT) == state.FieldJob.NONE,
		"Research keeps the empty rotation plot on hold.")
	await _button(ui.manage_button)
	var panel: Control = ui.panel_manager.management_panel_instance
	panel.show_estate(0)
	await tree.process_frame
	var picker: OptionButton = panel.seed_plan_picker
	await _button(picker)
	var popup := picker.get_popup()
	if not _expect(popup.visible and not picker.is_item_disabled(panel.resume_sowing_index), "Open the normal seed menu in research."):
		return
	popup.set_focused_item(panel.resume_sowing_index)
	for pressed in [true, false]:
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = pressed
		Input.parse_input_event(enter)
		Input.flush_buffered_events()
		await tree.process_frame
	if not _expect(not popup.visible and panel.apply_private_plan.text == "恢复私田 · 2 格",
			"The restore mode previews both held plots. Selected %d, button %s" % [picker.selected, panel.apply_private_plan.text]):
		return
	await _snapshot("02-resume-single-plot")
	for tile: Button in panel.map_grid_container.get_children():
		if tile.grid_pos == PRIVATE_MILLET:
			await _button(tile)
			break
	_expect(not state.deferred_field_sowing.has(PRIVATE_MILLET) and state.deferred_field_sowing.has(PRIVATE_WHEAT),
		"Restore one fixed plan and leave the adjacent rotation paused.")
	await _button(panel.close_button)
	await _wait_for_workers()
	_expect(state.active_crops.get(PRIVATE_MILLET, {}).get("id") == "beans" and not state.active_crops.has(PRIVATE_WHEAT),
		"Actual field work sows one plot and skips the held rotation.")
	print("SOWING_HOLD_DELAY day=", state.current_day, " resumed=beans held=", state.deferred_field_sowing.size())
	await _sleep()
	await _sleep()
	_expect(state.current_day == 51 and state.research_choice_pending and state.deferred_field_sowing.has(PRIVATE_WHEAT),
		"Two regular nights preserve the hold until the unpaid research fee forces a decision.")
	if not await _choose_council_option(state.TaxReformChoice.REFORMED, "03-final-reform-preview"):
		return
	_expect(state.deferred_field_sowing.is_empty() and state.field_seed_plans.get(PRIVATE_WHEAT) == "rotation:hemp"
		and state.fertile_cells.has(PRIVATE_WHEAT) and not state.is_public_plot(PUBLIC),
		"The final decision resumes the original rotation and updates the public field normally.")
	await _wait_for_workers()
	var planted: String = state.active_crops.get(PRIVATE_WHEAT, {}).get("id", "")
	_expect(planted == "hemp", "The worker resumes the rotation with the stored soil fertility, planted %s." % planted)
	await _snapshot("04-rotation-sown-again")
	print("SOWING_HOLD_REFORM day=", state.current_day, " resumed_plan=", state.field_seed_plans.get(PRIVATE_WHEAT), " planted=", planted)

func _wait_for_workers() -> void:
	await _button(ui.hud.rations_button)
	var panel: Control = ui.get_node("Control/NightRationsPanel")
	if panel.wait_button.is_visible_in_tree():
		panel.scroll.ensure_control_visible(panel.wait_button)
		await _button(panel.wait_button)
	await _button(panel.close_button)
