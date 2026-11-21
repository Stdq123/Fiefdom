extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _key(code: Key, backward := false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = backward
		event.pressed = down
		root.push_input(event, true)
	await process_frame

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run council-reading in an isolated profile.")
		quit(1)
		return
	var state := root.get_node("Global")
	var prefs := root.get_node("Preferences")
	var options: Array[Dictionary] = []
	for route in [state.TaxReformChoice.REFORMED, state.TaxReformChoice.TRADITIONAL, state.TaxReformChoice.DELAYED]:
		options.append({"text": "议税方案", "choice_type": route, "levy": "按户查看公私田。",
			"harvest": "国库 +1 · 私仓 +5", "household": "每夜用粮 3 份",
			"heading": "门槛与所需", "detail": ("议税当日可查各项入账，按门槛查进度。\n").repeat(12)})
	var underneath := Button.new()
	underneath.text = "HUD"
	root.add_child(underneath)
	var council = load("res://scenes/EventPanel.tscn").instantiate()
	root.add_child(council)
	council.setup({"title": "初税亩", "speaker": "召简", "text": "请看这份收成账。",
		"ledger": "国库 11 份 · 私仓 5 份", "choices": options})
	council.choice_selected.connect(func(_route: int): _expect(false, "Comparing must not settle the choice."))
	_expect(council.confirm_button.disabled, "Confirm starts disabled.")
	var standard: int = council.text_label.get_theme_font_size("font_size")
	_expect(prefs.set_reading_size(2) == OK, "Set the largest reading size.")
	for frame in 7:
		await process_frame
	_expect(council.text_label.get_theme_font_size("font_size") == standard + 6
		and council.scroll.get_v_scroll_bar().visible, "Larger comparison prose scrolls.")
	var sheet: Control = council.sheet
	_expect(root.get_visible_rect().encloses(sheet.get_global_rect())
		and sheet.get_global_rect().encloses(council.confirm_button.get_global_rect()),
		"The confirm button and entire sheet stay visible.")
	var reform: Button = council.option_buttons[state.TaxReformChoice.REFORMED]
	reform.grab_focus()
	await _key(KEY_PAGEDOWN)
	_expect(council.scroll.scroll_vertical > 0 and reform.has_focus(), "Keyboard scroll keeps the selected heading visible.")
	for backwards in [false, true]:
		for step in 12:
			await _key(KEY_TAB, backwards)
			var focus := root.gui_get_focus_owner()
			_expect(focus != null and council.is_ancestor_of(focus), "Tab stays in the council.")
	reform.pressed.emit()
	_expect(not council.confirm_button.disabled, "Preview enables confirm.")
	await _key(KEY_ESCAPE)
	_expect(council.confirm_button.disabled and council.selected_choice == state.TaxReformChoice.NONE,
		"Escape clears the preview without confirming it.")
	council.free()
	underneath.free()
	await _check_invitation(state)
	_expect(state.saved_games().is_empty(), "The isolated save catalog stays empty.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_invitation(state: Node) -> void:
	paused = true
	state.current_day = state.tax_council_start_day()
	state.day_progress = 0.45
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		_expect(false, "Mount the estate for the council invitation.")
		return
	await scene_changed
	var ui := current_scene.get_node("UI")
	var world := current_scene.get_node("World")
	var before: Vector2 = world.player.position
	var events := root.get_node("GameEvents")
	var icons := load("res://scripts/HUDIcons.gd") as GDScript
	ui.directions.follow_place("西市", world.to_local(world.get_node("WestMarketGate").global_position))
	state.tax_council_invited = true
	events.tax_reform_triggered.emit()
	_expect(ui.directions.tracked_place == "西市" and ui.hud.opening_action.visible
		and "去见召简" in ui.hud.opening_action.text, "An existing destination must leave the envoy action available.")
	_expect(ui.hud.sleep_button.text == "去见召简" and ui.hud.sleep_button.icon == icons.icon(icons.Symbol.MAP),
		"When the council is waiting, the night action identifies the envoy and shows a map icon.")
	ui.hud.opening_action.pressed.emit()
	_expect(ui.directions.tracked_neighbor == state.TAX_ENVOY and not ui.hud.opening_action.visible,
		"Selecting the envoy changes the route and hides the now redundant invitation button.")
	ui.directions.clear_tracking()
	ui.hud.rations_button.pressed.emit()
	var book := ui.get_node("Control/NightRationsPanel")
	var night_action: Button = book.get_node("%Sleep")
	var notice := book.get_node_or_null("%CouncilNotice") as Label
	_expect(night_action.text == "去见召简" and notice != null and notice.is_visible_in_tree(),
		"The night plan states the actual action and why the day has to wait.")
	night_action.pressed.emit()
	for frame in 5:
		await process_frame
	_expect(not is_instance_valid(book) and ui.directions.tracked_neighbor == state.TAX_ENVOY,
		"The night plan closes and guides the player to the envoy.")
	_expect(state.current_day == state.tax_council_start_day() and is_equal_approx(state.day_progress, 0.45)
		and world.player.position == before and not world.player.resting, "The guidance leaves the fixed day and player in place.")
	state.tax_reform_choice = state.TaxReformChoice.DELAYED
	state.tax_reform_day = state.current_day
	state.research_choice_pending = true
	ui.hud.guide.refresh()
	_expect("研究费未缴" in ui.hud.guide.heading.text, "The journal explains a return visit for unpaid research.")
	state.research_choice_pending = false
	state.current_day += state.balance.days_per_year
	ui.hud.guide.refresh()
	_expect("研究期满" in ui.hud.guide.heading.text, "The journal distinguishes the end of the research term.")
	state.tax_reform_choice = state.TaxReformChoice.TRADITIONAL
	events.tax_reform_choice_made.emit(state.tax_reform_choice)
	_expect(ui.hud.sleep_button.text == "睡觉" and ui.hud.sleep_button.icon == icons.icon(icons.Symbol.MOON),
		"After a decision the normal bedtime action returns.")
