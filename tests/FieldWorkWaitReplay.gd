extends RefCounted

const PUBLIC := Vector2i(5, 5)
const PRIVATE := Vector2i(6, 5)
const RICE := Vector2i(4, 5)
const FALLOW := Vector2i(6, 6)
const SECOND := Vector2i(9, 5)
const SECOND_DRY := Vector2i(10, 5)

var tree: SceneTree
var world: Node2D
var ui: CanvasLayer
var failed := false
var capture_dir: String

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failed = true
		push_error(message)
	return condition

func _click(button: BaseButton) -> void:
	if not _expect(button.is_visible_in_tree() and not button.disabled
			and tree.root.get_visible_rect().encloses(button.get_global_rect()), "Use the visible button " + button.text):
		return
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		tree.root.push_input(event, true)
		await tree.process_frame

func _frame(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Save " + name)
	print("FIELD_WAIT_FRAME ", name, " window=", tree.root.size, " image=", image.get_size())

func _crop(cell: Vector2i, id: String, ripe := false) -> void:
	var data := ItemManager.get_crop(id)
	var nights := Global.sowing_nights(data)
	Global.tilled_cells[cell] = true
	Global.active_crops[cell] = {"id": id, "data": data, "age": nights if ripe else nights - 1,
		"growth_nights": nights, "requires_channel": data.is_water_crop, "watered": false}

func _worker(name: String, duty: RetainerData.Duty, priority: Vector2i, efficiency: float) -> void:
	var worker := RetainerData.new(name, "农夫")
	worker.assigned_area = priority
	worker.duty = duty
	worker.efficiency = efficiency
	Global.retainers.append(worker)

func _fixture(after_first_tribute := false) -> bool:
	tree.change_scene_to_file(Global.TITLE_SCENE)
	await tree.scene_changed
	tree.current_scene.new_button.pressed.emit()
	await tree.scene_changed
	Global.current_day = 8
	Global.day_progress = 0.2
	Global.current_rank = Global.Rank.ZHONG_SHI
	Global._update_max_well_fields()
	Global.balance.raid_first_day = 10000
	Global.food_storage = 1
	Global.set_night_rations(true, 0, false)
	if not _expect(Global.add_well_field(SECOND), "Stage a second field through the regular field state."):
		return false
	for night in Global.RECLAMATION_NIGHTS:
		Global.advance_reclamation(1)
	_crop(PUBLIC, "millet", true)
	_crop(PRIVATE, "hemp", true)
	_crop(RICE, "rice")
	_crop(SECOND, "millet", true)
	_crop(SECOND_DRY, "millet")
	Global.tilled_cells[FALLOW] = true
	Global.set_field_seed_plan(FALLOW, "millet")
	Global.set_field_seed_plan(PUBLIC, "millet")
	Global.fertile_cells[PRIVATE] = true
	Global.retainers.clear()
	_worker("渠伯", RetainerData.Duty.STEWARD, PUBLIC, 1.0)
	_worker("季青", RetainerData.Duty.HARVEST, PRIVATE, 0.5)
	_worker("石墨", RetainerData.Duty.FIELD, FALLOW, 2.0)
	if after_first_tribute:
		Global.king_storage = 1
	return await _reload()

func _reload() -> bool:
	if not _expect(Global.save_game() == OK and Global.load_game() == OK, "Save and reopen through the estate loader."):
		return false
	await tree.scene_changed
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	# Freeze walking so the replay can measure just the actions booked by the button.
	for worker: Retainer in world.retainer_instances.values():
		worker.set_physics_process(false)
	await tree.process_frame
	return true

func _open_plan() -> Control:
	await _click(ui.hud.rations_button)
	return ui.get_node_or_null("Control/NightRationsPanel") as Control

func _wait(panel: Control) -> void:
	panel.scroll.ensure_control_visible(panel.wait_button)
	await tree.process_frame
	await _click(panel.wait_button)

func _pad_wait(panel: Control) -> void:
	await _pad(JOY_BUTTON_DPAD_UP)
	panel.scroll.ensure_control_visible(panel.wait_button)
	panel.wait_button.grab_focus()
	GamepadInput.snap_pointer_to_focus()
	await tree.process_frame
	await _pad(JOY_BUTTON_A)
	_expect(GamepadInput.active and tree.root.gui_get_focus_owner() == panel.find_child("Sleep", true, false),
		"The controller confirms waiting and focus moves to the separate sleep button.")
	await _frame("04-gamepad-wait")

func _pad(button: JoyButton) -> void:
	for down in [true, false]:
		var press := InputEventJoypadButton.new()
		press.button_index = button
		press.pressed = down
		Input.parse_input_event(press)
		Input.flush_buffered_events()
		await tree.process_frame
	await tree.process_frame

func _settle_work() -> void:
	var panel := await _open_plan()
	if not _expect(panel != null and panel.wait_button.is_visible_in_tree()
			and "可接手 5 格" in panel.field_wait_note.text and "断水" in panel.field_warning.text,
			"Tonight's sheet counts distinct reachable jobs and reports blocked rice separately."):
		return
	Global.set_wait_for_fields_before_sleep(true)
	_expect(not panel.wait_before_sleep.visible and not Global.wait_for_fields_before_sleep,
		"Before the first tribute, review the work manually and keep the sleep shortcut off.")
	await _frame("01-wait-offer")
	var start := Global.day_progress
	var stamina := Global.current_stamina
	var meal_need := Global.retainer_food_cost()
	var work_seconds := Global.balance.away_field_work_seconds
	await _wait(panel)
	var applied := (Global.day_progress - start) * Global.balance.daylight_seconds
	var report := Global.field_wait_report.duplicate()
	_expect(Global.current_day == 8 and is_equal_approx(applied, 4.0 * work_seconds)
		and Global.current_stamina == stamina and Global.food_storage == 1 and Global.retainer_food_cost() == meal_need,
		"The two harvesters and caretaker work concurrently, with no sleep or ration debit.")
	_expect(report.watered == 3 and report.harvested == 3 and report.sown == 2
		and report.tribute == 2 and report.stock == 2 and Global.king_storage == 2 and Global.player_inventory == 2
		and Global.away_field_report.is_empty() and not Global.fertile_cells.has(PRIVATE),
		"Each job is counted once with public tribute, the private rotation bonus and a separate report.")
	_expect(Global.active_crops[PUBLIC].age == 0 and Global.active_crops[PUBLIC].watered
		and Global.active_crops[FALLOW].age == 0 and Global.active_crops[FALLOW].watered
		and Global.active_crops[SECOND_DRY].watered and not Global.active_crops[RICE].watered,
		"Sowing may expose new watering work while disconnected rice remains dry.")
	_expect(not Global.active_crops.has(SECOND) and world.crops_layer.get_cell_source_id(SECOND) == -1
		and world.crops_layer.get_cell_source_id(FALLOW) >= 0 and world.crops_layer.get_cell_source_id(PUBLIC) >= 0,
		"Harvested crops disappear and replacement seedlings render in the loaded scene.")
	_expect(not panel.wait_button.is_visible_in_tree() and "国库 +2" in panel.field_wait_note.text
		and "私仓 +2" in panel.field_wait_note.text and "约 5 刻钟" in panel.field_wait_note.text
		and "今夜预计 3 格生长" in panel.field_forecast.text and "转用 麻" in panel.night_offer.text,
		"The wait button gives way to the receipt and refreshes both tonight's growth and provisioning offer.")
	print("FIELD_WAIT_SETTLED seconds=", applied, " minutes=", report.minutes, " watered=", report.watered,
		" harvested=", report.harvested, " sown=", report.sown, " tribute=", report.tribute, " stock=", report.stock)
	await _frame("02-wait-completed")
	await _click(panel.close_button)
	if not await _reload():
		return
	panel = await _open_plan()
	if not _expect(panel != null and Global.field_wait_report == report and "等待结果" in panel.field_wait_note.text,
			"Reloading keeps the closed receipt for the same day."):
		return
	await _click(panel.close_button)
	await _click(ui.sleep_button)
	var warning := ui.get_node_or_null("Control/DialoguePanel") as Control
	if warning != null and warning.choices.back().text == "仍然过夜":
		await _click(warning.choices.back())
	await tree.create_timer(1.1).timeout
	_expect(Global.current_day == 9 and Global.active_crops[PUBLIC].age == 1 and Global.active_crops[FALLOW].age == 1
		and Global.field_crop_is_ripe(SECOND_DRY) and Global.last_field_night.blocked == 1
		and Global.night_rations.last.need == meal_need and Global.field_wait_report.is_empty(),
		"Only sleep consumes the ordinary meal allowance, clears the wait receipt and advances growth.")

func _late_day_limit() -> void:
	Global.retainers.resize(1)
	var steward := Global.retainers[0]
	steward.duty = RetainerData.Duty.STEWARD
	Global.day_progress = 1.0 - (Global.balance.away_field_work_seconds * 1.5) / Global.balance.daylight_seconds
	_crop(PUBLIC, "millet", true)
	_crop(PRIVATE, "hemp", true)
	if not await _reload():
		return
	var panel := await _open_plan()
	if not _expect(panel != null and panel.wait_button.is_visible_in_tree(), "One short job fits before the day ends."):
		return
	Global.raid_day = Global.current_day
	GameEvents.raid_started.emit()
	_expect(not panel.wait_button.is_visible_in_tree() and "来敌" in panel.field_wait_note.text
		and Global.wait_for_field_work().is_empty(), "An active raid prevents the skip in both the plan and the model.")
	Global.raid_day = 0
	GameEvents.raid_defeated.emit()
	Global.tax_council_invited = true
	_expect(Global.wait_for_field_work().is_empty(), "A waiting council prevents the skip as well.")
	Global.tax_council_invited = false
	await _pad_wait(panel)
	_expect(Global.current_day == 9 and Global.day_progress < 1.0 and not Global.active_crops.has(PUBLIC)
		and Global.active_crops.has(PRIVATE) and not panel.wait_button.is_visible_in_tree()
		and "时辰已晚" in panel.field_wait_note.text and panel.find_ready_plot.is_visible_in_tree(),
		"Only the assigned public harvest fits. The remaining ripe field keeps its manual shortcut.")
	_expect(Global.wait_for_field_work().is_empty(), "A repeated click cannot overrun the same day's remaining time.")
	print("FIELD_WAIT_LIMIT day=", Global.current_day, " progress=", Global.day_progress,
		" harvested=", Global.field_wait_report.get("harvested", 0), " remaining=", Global.field_wait_offer().plots)
	await _frame("03-wait-day-limit")
	await _click(panel.close_button)

func _settle_at_bedtime() -> void:
	var panel := await _open_plan()
	if not _expect(panel != null and panel.wait_before_sleep.visible and not panel.wait_before_sleep.button_pressed,
		"A new campaign offers the policy unchecked after the first tribute."):
		return
	panel.scroll.ensure_control_visible(panel.wait_before_sleep)
	await tree.process_frame
	var time := Global.day_progress
	await _click(panel.wait_before_sleep)
	_expect(Global.wait_for_fields_before_sleep and Global.field_wait_report.is_empty() and Global.day_progress == time,
		"Opting in schedules later work and leaves the estate as it is.")
	await _frame("05-sleep-field-policy")
	await _click(panel.close_button)
	if not await _reload():
		return
	_expect(Global.wait_for_fields_before_sleep and "先收工" in ui.sleep_button.tooltip_text,
		"Continue restores the policy and the sleep tooltip.")
	# The covering harvest pays for the otherwise uncovered meals.
	var need := Global.retainer_food_cost()
	Global.set_ration_priority(Global.retainers[2])
	Global.food_storage = need - 1
	Global.retainers[1].loyalty = 0.0
	_expect("季青" in Global.night_rations_plan().departing, "Before the work, the last specialist would leave.")
	var start := Global.day_progress
	await _click(ui.sleep_button)
	_expect(Global.current_day == 8 and Global.king_storage == 3 and Global.day_progress > start
		and ui.get_node_or_null("Control/DialoguePanel") == null and Global.night_rations_plan().uncovered == 0,
		"One sleep command advances normal work before checking meals and avoids the now unnecessary warning.")
	await tree.create_timer(1.12).timeout
	var report: Dictionary = Global.last_dawn.get("field_wait", {})
	print("FIELD_BEDTIME day=", Global.current_day, " work=", report, " growth=", Global.last_field_night,
		" served=", Global.night_rations.last.get("served", 0), "/", need)
	if not _expect(Global.current_day == 9 and Global.field_wait_report.is_empty() and report.get("harvested") == 3
		and report.get("sown") == 2 and report.get("watered") == 3 and report.get("tribute") == 2 and report.get("stock") == 2
		and Global.last_field_night.blocked == 1 and Global.night_rations.last.served == need
		and Global.retainers.size() == 3 and Global.active_crops[PUBLIC].age == 1,
		"The usual harvest, growth, water and meals settle once and reach the morning ledger."):
		return
	if not await _continue_from_title():
		return
	await _click(ui.hud.morning_button)
	panel = ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(panel != null and Global.wait_for_fields_before_sleep and Global.last_dawn.get("field_wait") == report
		and panel.show_previous and panel.field_wait_receipt.is_visible_in_tree()
		and "国库 +2" in panel.field_wait_receipt.text and "私仓 +2" in panel.field_wait_receipt.text,
		"The dawn save reloads the opt-in and the actual yield into yesterday's ledger."):
		return
	await _frame("06-sleep-field-receipt")
	await _click(panel.close_button)

func _continue_from_title() -> bool:
	tree.change_scene_to_file(Global.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	var title := tree.current_scene
	if not _expect(title.continue_button.visible, "The morning save is offered on the title screen."):
		return false
	await _click(title.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.scene_file_path == Global.ESTATE_SCENE, "Continue returns to the estate."):
		return false
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	for worker: Retainer in world.retainer_instances.values():
		worker.set_physics_process(false)
	return true

func _bedtime_boundaries() -> void:
	# A second day with no supplies tests the warning after a real work result.
	Global.food_storage = 0
	Global.set_night_rations(false, 0)
	Global.retainers[1].loyalty = 0.0
	Global.day_progress = 0.3
	_crop(PUBLIC, "millet", true)
	_crop(PRIVATE, "hemp", true)
	await _click(ui.sleep_button)
	var warning := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(warning != null and Global.current_day == 9 and not Global.field_wait_report.is_empty(),
		"Remaining shortages still interrupt sleep after paid work."):
		return
	_expect(warning.choices[0].has_focus() and warning.choices[0].text == "查看今夜安排"
		and "门客已收工" in warning.text_label.text,
		"The default action still gives access to the meal plan.")
	await _frame("07-planned-work-ration-warning")
	var done := Global.field_wait_report.duplicate()
	await _click(warning.choices[0])
	await tree.process_frame
	var panel := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(panel != null and Global.current_day == 9 and Global.field_wait_report == done,
		"Returning to the ledger keeps the day's work without eating or advancing."):
		return
	await _click(panel.close_button)
	Global.tax_council_invited = true
	_crop(PUBLIC, "millet", true)
	await _click(ui.sleep_button)
	_expect(Global.current_day == 9 and Global.field_crop_is_ripe(PUBLIC)
		and Global.field_wait_report == done, "The awaiting envoy takes precedence over bedtime work.")
	Global.tax_council_invited = false
	Global.raid_day = Global.current_day
	await _click(ui.sleep_button)
	_expect(Global.current_day == 9 and Global.field_crop_is_ripe(PUBLIC)
		and Global.field_wait_report == done, "A raid suspends the automatic wait and preserves the meal warning.")
	warning = ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(warning != null, "The usual warning is still available during the raid."):
		return
	await _click(warning.choices[0])
	await tree.process_frame
	panel = ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(panel != null and not panel.wait_button.visible and "来敌" in panel.field_wait_note.text,
		"Tonight's sheet explains why the field work is paused."):
		return
	panel.scroll.ensure_control_visible(panel.wait_before_sleep)
	await tree.process_frame
	await _pad(JOY_BUTTON_DPAD_UP)
	panel.wait_before_sleep.grab_focus()
	GamepadInput.snap_pointer_to_focus()
	await _pad(JOY_BUTTON_A)
	_expect(not Global.wait_for_fields_before_sleep and not panel.wait_before_sleep.button_pressed,
		"A controller can turn the policy off.")
	await _click(panel.close_button)
	Global.raid_day = 0
	Global.food_storage = Global.retainer_food_cost()
	await _click(ui.sleep_button)
	await tree.create_timer(1.12).timeout
	_expect(Global.current_day == 10 and Global.field_crop_is_ripe(PUBLIC) and Global.last_dawn.field_wait == done,
		"Opting out restores ordinary sleep and carries the already completed work to dawn.")
	print("FIELD_BEDTIME_BOUNDARIES warning=kept council=blocked raid=blocked opt_out=true")

func run(game_tree: SceneTree, captures := "") -> void:
	tree = game_tree
	capture_dir = captures
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated player profile."):
		tree.quit(1)
		return
	tree.root.notify_mouse_entered()
	if await _fixture():
		await _settle_work()
		if not failed:
			await _late_day_limit()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func run_bedtime(game_tree: SceneTree, captures := "") -> void:
	tree = game_tree
	capture_dir = captures
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated player profile."):
		tree.quit(1)
		return
	tree.root.notify_mouse_entered()
	if await _fixture(true):
		await _settle_at_bedtime()
		if not failed:
			await _bedtime_boundaries()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
