extends SceneTree

const Campaign := preload("res://tests/CampaignReplay.gd")
const CONNECTOR := Vector2i(2, 5)
const OLD_CANAL := Vector2i(3, 5)
const FIRST_RICE := Vector2i(4, 5)
const END_OF_PLAN := Vector2i(10, 3)
const SECOND_FIELD := Vector2i(9, 5)
const SECOND_RICE := Vector2i(8, 4)

var failed := false
var state: Node
var world: Node
var ui: Node

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error(detail)

func _estate() -> void:
	world = current_scene.get_node("World")
	ui = current_scene.get_node("UI")

func _screen(cell: Vector2i) -> Vector2:
	var tiles: TileMapLayer = world.tile_map
	return tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)

func _move_pointer(point: Vector2, shift := false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.shift_pressed = shift
	root.push_input(motion, true)
	await process_frame

func _click(point: Vector2, shift := false) -> void:
	await _move_pointer(point, shift)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.shift_pressed = shift
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame

func _button(button: Button) -> void:
	await _click(button.get_global_rect().get_center())

func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)
	await process_frame

func _sleep() -> void:
	var next: int = state.current_day + 1
	await _button(ui.sleep_button)
	for frame in range(240):
		if state.current_day == next and ui.fader.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return
		await process_frame
	_expect(false, "The night must finish before the next action.")

func _study(unlock := false) -> void:
	await _button(ui.manage_button)
	var panel: Control = ui.panel_manager.management_panel_instance
	var tabs: TabContainer = panel.get_node("HBoxContainer/RightPanel")
	tabs.current_tab = 2
	await process_frame
	await _button(panel.read_button)
	if unlock:
		tabs.current_tab = 3
		await process_frame
		await _button(panel.irrigation_button)
	await _button(panel.get_node("CloseButton"))

func _talk(actor: Node2D) -> Control:
	await Campaign.walk_to(self, world.player, actor.global_position)
	await _key(KEY_E)
	return ui.get_node_or_null("Control/DialoguePanel")

func _choose(dialog: Control, prefix: String) -> bool:
	if dialog:
		for option in dialog.options_container.get_children():
			if option.text.begins_with(prefix) and not option.disabled:
				await _button(option)
				return true
	_expect(false, "The dialogue must offer " + prefix)
	return false

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run waterworks with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	seed(127)
	state = root.get_node("Global")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	await process_frame
	await _button(current_scene.new_button)
	if current_scene == null or current_scene.name != "Main":
		await scene_changed
	_estate()
	var grain := [Vector2i(6, 4), Vector2i(6, 5), Vector2i(6, 6)]
	for cell in grain:
		await _click(_screen(cell))
		await _click(_screen(cell))
	for night in range(2):
		for cell in grain:
			await _click(_screen(cell))
		await _study()
		await _sleep()
	for cell in grain:
		await _click(_screen(cell))
	_expect(state.money == 15, "Three private harvests pay for the first canal.")

	var dialog := await _talk(world.active_visitors.front())
	_expect(dialog != null and dialog.name_label.text == "石墨", "The player meets Shi Mo on his normal visit.")
	if not await _choose(dialog, "交谈"):
		quit(1)
		return
	for night in range(2):
		await _study()
		await _sleep()
	await _study(true)
	_expect(state.tech_unlocked["irrigation"], "Ordinary study unlocks the first canal.")

	await _button(ui.channel_button)
	await _click(_screen(OLD_CANAL))
	await _move_pointer(_screen(OLD_CANAL))
	_expect(CONNECTOR in world.irrigation_overlay.repair_cells and "补接" in ui.hud.canal_preview.text,
		"The detached section identifies a single-cell repair.")
	await _move_pointer(_screen(CONNECTOR))
	_expect(world.irrigation_overlay.affected_fields.get(FIRST_RICE) == true and not state.irrigation.supplies(FIRST_RICE)
		and state.money == 11, "The live preview shows the field that will gain water without spending copper.")
	await _click(_screen(CONNECTOR))
	await _key(KEY_ESCAPE)
	_expect(state.irrigation.supplies(FIRST_RICE) and state.money == 7, "The actual connection matches its preview and price.")
	await _key(KEY_3)
	await _click(_screen(FIRST_RICE))
	await _click(_screen(FIRST_RICE))
	await _sleep()
	_expect(state.first_channel_growth_day == 6 and state.water_review_ready() and state.active_crops[FIRST_RICE]["age"] == 1
		and ui.hud.survey_button.disabled, "An actual night of canal growth opens the story before the survey tool.")
	_expect(state.save_game() == OK and state.load_game() == OK, "The pending water review is saved.")
	await scene_changed
	await process_frame
	_estate()
	dialog = await _talk(world.active_visitors.front())
	_expect(dialog != null and dialog.name_label.text == "石墨" and "第 6 天" in dialog.text_label.text,
		"The return visit recognizes the real growth date after reload.")
	if not await _choose(dialog, "随石墨勘渠"):
		quit(1)
		return
	_expect(state.channel_survey_day == 6 and not ui.hud.survey_button.disabled
		and "量水尺" in world.irrigation_overlay.source_label.text, "Reviewing the work adds the gauge and enables surveying.")

	await _button(ui.channel_button)
	await _button(ui.hud.survey_button)
	await _click(_screen(OLD_CANAL))
	await _move_pointer(_screen(END_OF_PLAN))
	_expect(world.irrigation_overlay.preview_site == state.ChannelSite.BLOCKED, "The first bend would cut through a field.")
	await _click(_screen(END_OF_PLAN))
	_expect(state.money == 7 and state.irrigation.channels.size() == 2, "A blocked route cannot dig a partial segment.")
	await _key(KEY_R)
	_expect(world.irrigation_overlay.preview_site == state.ChannelSite.NO_FUNDS and "36 铜钱" in ui.hud.canal_preview.text,
		"The other bend avoids the field and shows the whole route cost.")
	await _click(_screen(END_OF_PLAN))
	_expect(state.money == 7 and state.irrigation.channels.size() == 2, "A route beyond the budget leaves money and channels untouched.")
	await _key(KEY_ESCAPE)
	_expect(world.channel_mode and not world.irrigation_overlay.survey_mode, "Canceling the survey returns to tile-by-tile construction.")

	# Advance the economy to the expansion eligibility already covered by estate-flow.
	state.current_rank = state.Rank.ZHONG_SHI
	state._update_max_well_fields()
	state.balance.raid_first_day = 10000
	state.money = 180
	state.food_storage = 100
	state.reputation = 150
	await _key(KEY_ESCAPE)
	dialog = await _talk(world.active_visitors.front())
	if not await _choose(dialog, "招募"):
		quit(1)
		return
	var retainer_data: GDScript = load("res://scripts/RetainerData.gd")
	var retainer: Resource = retainer_data.new("田庚", "农夫", retainer_data.School.AGRARIAN)
	state.retainers.append(retainer)
	root.get_node("GameEvents").retainer_recruited.emit(retainer)
	await _button(ui.channel_button)
	await _button(ui.hud.survey_button)
	await _click(_screen(OLD_CANAL))
	await _key(KEY_R)
	await _move_pointer(_screen(END_OF_PLAN))
	_expect("供水 +3 格" in ui.hud.canal_preview.text, "The chosen bend previews the three new fields.")
	await _click(_screen(END_OF_PLAN))
	_expect(state.irrigation.channels.size() == 11 and state.money == 144
		and state.irrigation.watered_footprint(SECOND_FIELD).size() == 3, "A valid plan digs nine new cells, charging only once per new cell.")

	await _button(ui.reclaim_button)
	await _click(_screen(SECOND_FIELD))
	var panel := ui.get_node("Control/ReclamationPanel")
	_expect("3/9" in panel.validity_label.text and panel.preview_watered.size() == 3, "The reclamation footprint previews its actual future supply.")
	await _button(panel.reclaim_button)
	await _button(panel.get_node("Panel/CloseButton"))
	for night in range(4):
		await _sleep()
	_expect(state.well_fields.size() == 2 and state.well_fields[1]["is_unlocked"] and state.irrigated_well_fields() == 2,
		"The second field opens to the water shown during selection.")
	await _key(KEY_3)
	await _click(_screen(SECOND_RICE))
	await _click(_screen(SECOND_RICE))
	await _button(ui.channel_button)
	await _move_pointer(_screen(CONNECTOR), true)
	_expect(world.irrigation_overlay.affected_fields.size() == 7 and "1 格稻暂停" in ui.hud.canal_preview.text
		and state.irrigation.supplies(SECOND_RICE), "The fill preview warns both fields and only counts growing rice.")
	await _click(_screen(CONNECTOR), true)
	await _key(KEY_ESCAPE)
	await _sleep()
	_expect(state.active_crops[SECOND_RICE]["age"] == 0 and state.save_game() == OK and state.load_game() == OK,
		"The second crop stalls during the interrupted night and the interruption can be saved.")
	await scene_changed
	await process_frame
	_estate()
	_expect(not state.irrigation.supplies(SECOND_RICE) and "断水 1" in ui.hud.farm_status.text and not ui.hud.survey_button.disabled,
		"Reload restores both the interrupted canal and the learned survey tool.")
	await _button(ui.channel_button)
	await _move_pointer(_screen(END_OF_PLAN))
	_expect(CONNECTOR in world.irrigation_overlay.repair_cells, "A downstream segment leads back to the broken join.")
	await _click(_screen(CONNECTOR))
	await _key(KEY_ESCAPE)
	await _sleep()
	_expect(state.active_crops[SECOND_RICE]["age"] == 1 and state.irrigated_well_fields() == 2,
		"Repair resumes growth and restores both fields.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
