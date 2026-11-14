extends RefCounted

var tree: SceneTree
var state: Node
var ui: Node
var capture_dir := ""
var failed := false

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failed = true
		push_error(detail)
	return condition

func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	tree.root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		tree.root.push_input(event, true)
		await tree.process_frame

func _key(code: Key, unicode := 0) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	tree.root.push_input(event, true)

func _enter_budget(panel: Control, amount: int) -> void:
	var edit: LineEdit = panel.budget.get_line_edit()
	await _click(edit)
	edit.select_all()
	var digits := str(amount)
	for index in digits.length():
		var digit := digits.unicode_at(index)
		_key(digit as Key, digit)
		await tree.process_frame
	_key(KEY_ENTER)
	await tree.process_frame

func _panel() -> Control:
	return ui.get_node_or_null("Control/NightRationsPanel") as Control

func _open() -> Control:
	await _click(ui.hud.rations_button)
	return _panel()

func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Could not capture " + name)
	print("RATIONS_FRAME ", name, " ", image.get_size())

func _sleep(dawn_capture := "") -> void:
	await _click(ui.sleep_button)
	await tree.create_timer(0.58).timeout
	if not dawn_capture.is_empty():
		await _capture(dawn_capture)
	await tree.create_timer(0.59).timeout

func _end() -> void:
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func _sell_surplus_silk(panel: Control) -> void:
	_expect(not panel.sell_silk.visible and panel.view_silk.visible and state.silk_workshop.bolts == 1,
		"Keep the only bolt for the council even when tonight's pantry is short.")
	panel.scroll.ensure_control_visible(panel.view_silk)
	await tree.process_frame
	await _click(panel.view_silk)
	var management: Control = ui.panel_manager.management_panel_instance
	if not _expect(management != null and management.silk_panel.is_visible_in_tree(), "The ration shortcut opens the existing silk workshop."):
		return
	await _click(management.silk_panel.buttons[SilkWorkshop.Action.WEAVE])
	await _click(management.close_button)
	panel = await _open()
	if not _expect(panel.sell_silk.visible and "余 1 匹" in panel.silk_offer.text and "10 铜钱" in panel.silk_offer.text
		and state.money == 2 and state.food_storage == 1 and state.silk_workshop.bolts == 2,
		"The surplus offer quotes actual food purchases and preserves the council bolt before any trade."):
		return
	panel.scroll.ensure_control_visible(panel.sell_silk)
	await tree.process_frame
	await _capture("07-surplus-silk-quote")
	await _click(panel.sell_silk)
	_expect(state.silk_workshop.bolts == 1 and state.money == 37 and state.food_storage == 1
		and state.silk_bolts_sold == 1 and panel.accept_offer.has_focus() and not panel.sell_silk.visible
		and "铜钱 +35" in panel.silk_sale_receipt.text,
		"The sale books one bolt and transfers focus to the funded ration quote. Bolts: %s, copper: %s, focus: %s" % [
			state.silk_workshop.bolts, state.money, tree.root.gui_get_focus_owner()])
	await _capture("08-sale-and-funded-rations")
	panel.scroll.ensure_control_visible(panel.accept_offer)
	await tree.process_frame
	await _click(panel.accept_offer)
	_expect(state.night_rations.copper_limit == 10 and state.money == 37 and "补足 3 份" in panel.forecast.text,
		"Accepting the financed quote changes only the purchase limit.")
	await _click(panel.close_button)
	await _sleep()
	var meal: Dictionary = state.night_rations.last
	_expect(state.current_day == 9 and meal.served == 4 and meal.copper == 10 and meal.bought == 2
		and state.money == 27 and state.silk_workshop.bolts == 1 and state.king_storage == 3
		and state.crop_stock.count("rice") == 2,
		"The nightly settlement spends the quoted amount and leaves the public stores, silk and reserved rice intact.")
	tree.change_scene_to_file("res://scenes/Title.tscn")
	await tree.scene_changed
	tree.current_scene.continue_button.pressed.emit()
	await tree.scene_changed
	await tree.process_frame
	_expect(state.current_day == 9 and state.money == 27 and state.silk_workshop.bolts == 1
		and state.night_rations.last == meal, "Continue restores the actual silk stock, remaining copper and ration settlement.")
	print("RATIONS_SILK day=", state.current_day, " bolts=", state.silk_workshop.bolts, " purchased=", meal.bought,
		" copper=", state.money, " fed=", meal.served, "/", meal.need)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated nightly rations profile."):
		_end()
		return
	seed(784)
	if capture_dir.is_empty():
		capture_dir = OS.get_environment("FIEFDOM_RATIONS_CAPTURES")
	state = tree.root.get_node("Global")
	# Start with two specialist retainers and a small, precisely accounted pantry.
	var fixture := {
		"current_day": 5, "food_storage": 1, "money": 12, "king_storage": 3,
		"player_inventory": 5, "crop_stock": {"beans": 2, "millet": 1, "hemp": 2},
		"retainers": [{"name": "渠伯", "school": 2, "duty": 1}, {"name": "季青", "school": 1, "duty": 2}],
		"silk_workshop": {"built": true, "cocoons": 3, "bolts": 1, "night_reeling": true},
	}
	var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	tree.change_scene_to_file("res://scenes/Title.tscn")
	await tree.scene_changed
	tree.current_scene.continue_button.pressed.emit()
	await tree.scene_changed
	await tree.process_frame
	ui = tree.current_scene.get_node("UI")
	var panel := await _open()
	if not _expect(panel != null, "The HUD opens the nightly ration ledger."):
		_end()
		return
	_expect(not state.night_rations.enabled and not panel.budget.editable and "缺 3 份" in panel.forecast.text
		and ui.hud.rations_button.text.ends_with("缺粮 3"),
		"An old save starts in manual mode and shows the specialist meal shortage.")
	_expect(panel.accept_offer.visible and "麻 2" in panel.night_offer.text and "5 铜钱" in panel.night_offer.text,
		"The shortage offers the exact surplus and minimum copper cap.")
	await _capture("01-before-delegation")
	panel.scroll.ensure_control_visible(panel.accept_offer)
	await tree.process_frame
	await _click(panel.accept_offer)
	_expect(state.night_rations.enabled and state.night_rations.copper_limit == 5 and state.money == 12,
		"Accepting the initial quote enables the policy without spending copper yet.")
	panel.scroll.ensure_control_visible(panel.delegate)
	await tree.process_frame
	await _click(panel.delegate)
	await _click(panel.delegate)
	await _enter_budget(panel, 0)
	_expect(state.night_rations.enabled and panel.budget.editable and "还差 1 份" in panel.forecast.text,
		"With a zero cap, reserved spring grain stays out of the plan.")
	await _enter_budget(panel, 4)
	_expect(state.night_rations.copper_limit == 4 and "还差 1 份" in panel.forecast.text,
		"A cap below the price of one ration cannot buy it.")
	_expect(panel.accept_offer.visible, "The quote can restore a sufficient cap.")
	panel.scroll.ensure_control_visible(panel.accept_offer)
	await tree.process_frame
	await _click(panel.accept_offer)
	_expect(state.night_rations.copper_limit == 5 and state.money == 12 and state.food_storage == 1,
		"Accepting the quote sets only the cap until bedtime.")
	await _enter_budget(panel, 5)
	_expect(state.night_rations.copper_limit == 5 and "麻 2" in panel.forecast.text and "5 铜钱" in panel.forecast.text
		and "亭前备种" in panel.keep.text and state.money == 12 and state.food_storage == 1 and state.player_inventory == 5,
		"The live preview shows exact surplus, capped copper and held crops before touching inventory.")
	await _capture("02-tonights-plan")
	await _click(panel.get_node("%Market"))
	var management: Control = ui.panel_manager.management_panel_instance
	var market: Control = management.market_panel
	_expect(market.visible and "自动补 3 份" in market.food_label.text, "The ledger opens the normal manual market and shares its forecast.")
	await _click(market.get_node("MarketHeader/NightRations"))
	panel = _panel()
	if not _expect(panel != null and panel.delegate.button_pressed, "The market returns to the same policy."):
		_end()
		return
	await _click(panel.close_button)
	await _click(management.get_node("CloseButton"))
	_expect("可补足" in ui.hud.rations_button.text, "The HUD shows the safe meal plan before bed.")
	var reputation: int = state.reputation
	await _sleep("03-dawn-settlement")
	var last: Dictionary = state.night_rations.last
	_expect(state.current_day == 6 and state.king_storage == 3 and state.food_storage == 0 and state.money == 7
		and last.day == 5 and last.need == 4 and last.served == 4 and last.used.get("hemp", 0) == 2 and last.bought == 1
		and state.crop_stock.count("beans") == 2 and state.crop_stock.count("millet") == 1,
		"Exactly one evening exchange precedes the usual meal without using the spring order or public stock.")
	_expect(state.silk_workshop.last_reeled == 1 and state.reputation == reputation + state.balance.confucian_teaching_reputation,
		"The successfully fed artisans and teachers work that night.")
	if not _expect(state.save_game() == OK and state.load_game() == OK, "The policy and first receipt save."):
		_end()
		return
	await tree.scene_changed
	await tree.process_frame
	ui = tree.current_scene.get_node("UI")
	last = state.night_rations.last
	_expect(state.night_rations.enabled and state.night_rations.copper_limit == 5 and last.copper == 5
		and last.used.get("hemp", 0) == 2 and last.day == 5, "Continue restores the budget and the actual meal receipt.")
	state.crop_stock.add("rice", 2)
	tree.root.get_node("GameEvents").inventory_changed.emit(state.player_inventory)
	panel = await _open()
	_expect(panel != null and "第 5 夜" in panel.receipt.text and "明日「新稻到亭」" in panel.keep.text
		and "稻 2" in panel.keep.text and "菽 2" in panel.forecast.text,
		"On the final spring evening, the next order's rice is held and expired spring crops can be used.")
	await _capture("04-saved-receipt-and-next-order")
	await _click(panel.close_button)
	await _sleep()
	last = state.night_rations.last
	_expect(state.current_day == 7 and state.money == 2 and state.crop_stock.count("rice") == 2
		and last.used.get("beans", 0) == 2 and last.used.get("millet", 0) == 1 and last.bought == 1,
		"The executed rollover plan uses the exact lots shown before bed.")
	state.food_storage = 1
	state.crop_stock.add("hemp", 1)
	var events := tree.root.get_node("GameEvents")
	events.food_changed.emit(state.food_storage)
	events.inventory_changed.emit(state.player_inventory)
	panel = await _open()
	_expect(panel != null and "还差 2 份" in panel.forecast.text and "稻 2" in panel.keep.text,
		"The forecast uses available copper as well as the cap and shows the uncovered amount.")
	await _capture("05-uncovered-shortage")
	panel.scroll.ensure_control_visible(panel.delegate)
	await tree.process_frame
	await _click(panel.delegate)
	_expect(not panel.accept_offer.visible and not panel.night_offer.visible,
		"An unfillable full-table plan offers no zero-ration delegation.")
	await _click(panel.delegate)
	await _click(panel.close_button)
	reputation = state.reputation
	await _sleep()
	last = state.night_rations.last
	_expect(state.current_day == 8 and state.money == 2 and state.crop_stock.count("hemp") == 1
		and state.crop_stock.count("rice") == 2 and last.used.is_empty() and last.bought == 0
		and last.served == 0 and last.need == 4 and state.food_storage == 1,
		"The unfillable plan spends no crops or copper and one ration stays in the granary when both portions cost two.")
	_expect(state.silk_workshop.last_reeled == 0 and state.reputation == reputation,
		"An incomplete meal cannot start nighttime specialist work.")
	panel = await _open()
	_expect(panel != null and "缺 4 份" in panel.receipt.text and "渠伯、季青" in panel.receipt.text,
		"The receipt records the actual portions and the two missed meals.")
	await _capture("06-actual-shortage-receipt")
	print("RATIONS_REPLAY protected_rice=", state.crop_stock.count("rice"), " spent=10 last_meal=", last.served, "/", last.need)
	await _sell_surplus_silk(panel)
	tree.change_scene_to_file("res://scenes/Title.tscn")
	await tree.scene_changed
	tree.root.get_node("AudioManager").bgm_player.stop()
	await tree.create_timer(0.35).timeout
	_end()
