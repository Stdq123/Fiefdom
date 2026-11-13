extends SceneTree

const Campaign := preload("res://tests/CampaignReplay.gd")
const CEREAL := [Vector2i(5, 5), Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 4), Vector2i(5, 6)]
const MULBERRY := [Vector2i(6, 5), Vector2i(6, 6)]

var failed := false
var state: Node
var world: Node
var ui: Node
var first_portrait: Rect2

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _refresh_estate() -> void:
	world = current_scene.get_node("World")
	ui = current_scene.get_node("UI")

func _management(tab: int) -> Control:
	ui.manage_button.pressed.emit()
	var panel: Control = ui.panel_manager.management_panel_instance
	panel.get_node("HBoxContainer/RightPanel").current_tab = tab
	return panel

func _close(panel: Control) -> void:
	panel.get_node("CloseButton").pressed.emit()

func _tend(cells: Array, seed_id: String) -> void:
	world.select_seed(seed_id)
	for cell in cells:
		var crop: Dictionary = state.active_crops.get(cell, {})
		if not crop.is_empty() and crop.age >= crop.growth_nights:
			world.handle_interaction(cell)
		if not state.active_crops.has(cell):
			if not state.tilled_cells.has(cell):
				world.handle_interaction(cell)
			world.handle_interaction(cell)
		if world.is_crop_dry(cell):
			world.handle_interaction(cell)

func _rest() -> void:
	var panel := _management(1)
	if not panel.market_panel.reserve_button.disabled:
		panel.market_panel.reserve_button.pressed.emit()
	_close(panel)
	var day: int = state.current_day
	ui.sleep_button.pressed.emit()
	for frame in range(180):
		if state.current_day == day + 1 and ui.fader.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return
		await process_frame
	_expect(false, "Sleeping must advance one day and release the fader.")

func _approach(actor: Node2D) -> Control:
	await Campaign.walk_to(self, world.player, actor.global_position + Vector2(0, 23))
	return await _open_dialog()

func _open_dialog() -> Control:
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	key.pressed = true
	root.push_input(key, true)
	await process_frame
	return ui.get_node_or_null("Control/DialoguePanel")

func _option(dialog: Control, prefix: String) -> Button:
	for button: Button in dialog.options_container.get_children():
		if button.text.begins_with(prefix):
			return button
	return null

func _choose(dialog: Control, prefix: String) -> void:
	var button := _option(dialog, prefix)
	if button == null or button.disabled:
		_expect(false, "Unavailable conversation choice: " + prefix)
		return
	button.pressed.emit()
	await process_frame

func _meet_merchant() -> bool:
	var dialog := await _approach(world.active_visitors.front())
	if dialog == null:
		_expect(false, "Tao Xin must be reachable at the west court.")
		return false
	_expect(dialog.name_label.text == "陶辛" and "西廊" in dialog.context_label.text and _option(dialog, "交样绸") == null,
		"The first meeting introduces the merchant before opening the order.")
	first_portrait = dialog.portrait.texture.region
	await _choose(dialog, "交谈")
	dialog = await _open_dialog()
	if dialog == null:
		_expect(false, "The merchant can be approached again after meeting.")
		return false
	var sample := _option(dialog, "交样绸")
	_expect(state.silk_sample_requested() and sample != null and sample.disabled and "西廊" in ui.hud.visitor_label.text,
		"The meeting opens the order and the empty stock disables delivery.")
	await _choose(dialog, "离开")
	return true

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run taoxin-story with an isolated save.")
		quit(1)
		return
	seed(341)
	change_scene_to_file("res://scenes/Title.tscn")
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	state = root.get_node("Global")
	_refresh_estate()

	for date in range(1, 10):
		_tend(CEREAL, "millet")
		_tend(MULBERRY, "mulberry")
		if date <= 2:
			var study := _management(2)
			study.read_button.pressed.emit()
			_close(study)
		if date == 3:
			var management := _management(4)
			management.get_node("HBoxContainer/RightPanel/蚕桑").buttons[0].pressed.emit()
			_close(management)
			_expect(state.silk_workshop.built, "Private cereal harvest funds the workshop.")
		if date == 4 and not await _meet_merchant():
			quit(1)
			return
		if date == 6:
			var management := _management(4)
			management.retainer_list_container.get_child(0).duty_picker.item_selected.emit(1)
			var workshop := management.get_node("HBoxContainer/RightPanel/蚕桑")
			workshop.buttons[1].pressed.emit()
			workshop.night_reeling_button.button_pressed = true
			_close(management)
			_expect(state.silk_workshop.nights_left == 2 and state.silk_workshop.night_reeling,
				"The harvest supplies an actual batch and Qubo takes the night order.")
		if date == 8:
			_expect(state.silk_workshop.cocoons == 1 and state.silk_workshop.raw_silk == 3 and state.silk_workshop.last_reeled == 1,
				"The first cocoon is reeled on the night it becomes available.")
		if date < 9:
			await _rest()

	var management := _management(4)
	await process_frame
	var silk := management.get_node("HBoxContainer/RightPanel/蚕桑")
	var notice: Label = current_scene.get_node("CampaignHUD").notice
	_expect(state.raid_day == state.current_day and not notice.visible,
		"The active raid's map notice clears the workshop controls while management is open.")
	_expect(state.silk_workshop.raw_silk == 6 and "昨夜 · 缫 1 茧得 3 生丝" in silk.night_status.text,
		"The morning receipt shows the work that made the bolt possible.")
	silk.buttons[3].pressed.emit()
	_expect(state.silk_workshop.bolts == 1 and "已备好" in silk.sample_status.text, "The woven sample is ready for delivery.")
	_close(management)
	_expect(notice.visible and ui.hud.raid_alert.is_visible_in_tree() and "来袭" in ui.hud.raid_alert.text,
		"Leaving management restores map notices and the active raid alert.")
	var dialog := await _approach(world.active_visitors.front())
	if dialog == null:
		_expect(false, "Tao Xin must return for the sample.")
		quit(1)
		return
	_expect(dialog.name_label.text == "陶辛" and "可到西廊交付" in ui.hud.visitor_label.text,
		"The returning merchant and journal point to the same delivery location.")
	var before: int = state.money
	await _choose(dialog, "交样绸")
	_expect(state.money == before + state.silk_sample_price() and state.silk_workshop.bolts == 0
		and state.silk_bolts_sold == 1 and state.silk_sample_day == 9 and not state.deliver_silk_sample(),
		"The sample pays exactly once and counts as one ordinary sale for the campaign.")
	dialog = await _open_dialog()
	if dialog == null:
		quit(1)
		return
	_expect("西廊" in dialog.text_label.text and dialog.portrait.texture.region != first_portrait and _option(dialog, "交样绸") == null,
		"The completed order changes the portrait, dialogue and options.")
	await _choose(dialog, "招募")
	_expect(state.retainers.back().name == "陶辛", "The merchant may become a resident after delivery.")
	await _rest()
	_expect(state.save_game() == OK and state.load_game() == OK, "The delivered sample and assignment can be saved.")
	await scene_changed
	_refresh_estate()
	_expect(state.silk_sample_day == 9 and state.silk_bolts_sold == 1 and state.silk_workshop.night_reeling,
		"Loading preserves the sample date, actual sale and night order.")
	dialog = await _approach(world.retainer_instances[state.retainers.back()])
	if dialog == null:
		quit(1)
		return
	_expect("门客" in dialog.context_label.text and "绸样还在" in dialog.text_label.text and _option(dialog, "交样绸") == null,
		"The recruited merchant remembers the sample on a later day after reloading.")
	await _choose(dialog, "离开")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
