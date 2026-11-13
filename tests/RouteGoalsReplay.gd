extends "res://tests/TaxCouncilReplay.gd"

var legacy := false

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the route goals replay profile."):
		tree.quit(1)
		return
	seed(1979)
	tree.root.notify_mouse_entered()
	capture_dir = OS.get_environment("FIEFDOM_ROUTE_CAPTURES")
	state = tree.root.get_node("Global")
	if legacy:
		await _continue_previous_council()
	else:
		await _reformed()
		await _traditional()
	tree.paused = false
	tree.unload_current_scene()
	for stream in tree.root.get_node("AudioManager").get_children():
		if stream is AudioStreamPlayer:
			stream.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(0 if failures == 0 else 1)

func _choose_route(choice: int, raids_defeated: int) -> bool:
	# Mature plots and a bolt in storage let this replay focus on the period after the council.
	var fixture := SNAPSHOT.duplicate(true)
	fixture.raids_defeated = raids_defeated
	fixture.silk_workshop = {"built": true, "bolts": 1}
	var path := "user://route-goals-fixture.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	if not _expect(state.load_game(path) == OK, "Load an eligible third-year estate."):
		return false
	await tree.scene_changed
	await _estate()
	_expect(not ui.hud.route_progress.visible, "The goals button stays hidden before a decision.")
	var panel := await Campaign.meet_tax_envoy(tree)
	if not _expect(panel != null and tree.paused, "Reach the real council by walking to the envoy."):
		return false
	await _button(panel.option_buttons[choice])
	await _button(panel.confirm_button)
	return _expect(state.tax_reform_choice == choice and ui.hud.route_progress.visible and not tree.paused,
		"The journal shows the goals as soon as the player confirms a route.")

func _open_goals() -> bool:
	await _button(ui.hud.route_progress)
	var book: Control = ui.route_goals
	if not _expect(book.modal.visible and tree.paused, "Clicking the journal opens the paused goals panel."):
		return false
	var bounds: Rect2 = book.modal.get_node("Center/Ledger").get_global_rect()
	_expect(tree.root.get_visible_rect().encloses(bounds), "The full goals panel fits in the game viewport.")
	return _expect(book.rows.get_child_count() == state.route_objectives().size(), "The panel lists exactly the current route goals.")

func _row(kind: Global.RouteGoal) -> PanelContainer:
	var goals: Array[Dictionary] = state.route_objectives()
	for index in goals.size():
		if goals[index].kind == kind:
			return ui.route_goals.rows.get_child(index)
	return null

func _action(kind: Global.RouteGoal) -> Button:
	return _row(kind).get_node("%GoalAction")

func _count(kind: Global.RouteGoal) -> String:
	return _row(kind).get_node("%GoalCount").text

func _reformed() -> void:
	if not await _choose_route(state.TaxReformChoice.REFORMED, 1):
		return
	await _capture("01-reform-journal")
	if not await _open_goals():
		return
	_expect("1/4" in ui.route_goals.summary.text and "第 53 天定案" in ui.route_goals.summary.text
		and _count(Global.RouteGoal.TAXED_HARVEST).begins_with("0 /")
		and _count(Global.RouteGoal.COPPER).begins_with("87 /")
		and not _action(Global.RouteGoal.RAIDS).visible, "Earlier harvest starts at zero, current copper and earlier defense are counted.")
	await _capture("02-reform-goals")
	await _button(_action(Global.RouteGoal.TAXED_HARVEST))
	var chart: Control = ui.estate_map
	_expect(not ui.route_goals.modal.visible and chart.modal.visible and chart.category == chart.Category.FIELDS and tree.paused,
		"The harvest action hands off the pause to the field map.")
	await _key(KEY_ESCAPE)
	_expect(not tree.paused and not chart.modal.visible, "Closing the chart returns control.")
	await _harvest()
	if not await _open_goals():
		return
	_expect(_count(Global.RouteGoal.TAXED_HARVEST).begins_with("4 /") and _count(Global.RouteGoal.COPPER).begins_with("115 /"),
		"Real field harvests update the taxed stock and copper totals.")
	await _button(_action(Global.RouteGoal.SELL_SILK))
	var management: Control = ui.panel_manager.management_panel_instance
	if not _expect(management.visible and not tree.paused and management.tabs.get_current_tab_control() == management.silk_panel,
		"The silk action opens the existing workshop controls."):
		return
	await _button(management.silk_panel.buttons[SilkWorkshop.Action.SELL])
	await _key(KEY_ESCAPE)
	if not await _open_goals():
		return
	_expect(_count(Global.RouteGoal.SELL_SILK).ends_with("达成") and _count(Global.RouteGoal.COPPER).begins_with("150 /")
		and "2/4" in ui.hud.route_progress.text, "Selling stored silk completes its goal and increases the current copper.")
	await _capture("03-silk-sold")
	await _button(_action(Global.RouteGoal.COPPER))
	_expect(management.visible and management.tabs.get_current_tab_control() == management.market_panel,
		"The copper action opens the normal market.")
	var money_before: int = state.money
	await _button(management.market_panel.buy_button)
	await _key(KEY_ESCAPE)
	if not await _open_goals():
		return
	_expect(state.money < money_before and _count(Global.RouteGoal.COPPER).begins_with("%d /" % state.money),
		"Spending copper is reflected in the target progress.")
	await _key(KEY_ESCAPE)
	var totals: Array[Dictionary] = state.route_objectives()
	_expect(state.save_game() == OK, "Save the current progress.")
	await _title()
	await _button(tree.current_scene.continue_button)
	await _estate()
	if await _open_goals():
		_expect(state.route_objectives() == totals and "2/4" in ui.route_goals.summary.text, "Continue rebuilds the goals from the saved accounts.")
		await _key(KEY_ESCAPE)
	print("ROUTE_REFORM harvested=4 sold=1 market_spent=", money_before - state.money, " resumed=true")

func _traditional() -> void:
	state.balance.raid_first_day = SNAPSHOT.current_day + 2
	if not await _choose_route(state.TaxReformChoice.TRADITIONAL, 0) or not await _open_goals():
		return
	_expect("守礼安邦" in ui.route_goals.heading.text and "0/3" in ui.route_goals.summary.text
		and _count(Global.RouteGoal.TRIBUTE).begins_with("0 /") and _action(Global.RouteGoal.RAIDS).text == "分派守卫",
		"Traditional goals track new tribute and direct the player to defense.")
	await _capture("04-traditional-goals")
	await _button(_action(Global.RouteGoal.RAIDS))
	var management: Control = ui.panel_manager.management_panel_instance
	if not _expect(management.visible and management.tabs.get_current_tab_control() == management.map_grid_container.get_parent(),
		"Before the raid forecast, the shortcut opens the estate overview and retainer list."):
		return
	await _key(KEY_ESCAPE)
	await _harvest()
	if not await _open_goals():
		return
	_expect(_count(Global.RouteGoal.TRIBUTE).begins_with("2 /"), "The two public plots fill only the tribute goal.")
	await _button(_action(Global.RouteGoal.OFFER_SILK))
	await _button(management.silk_panel.buttons[SilkWorkshop.Action.OFFER])
	await _key(KEY_ESCAPE)
	await _sleep()
	if not await _open_goals():
		return
	_expect(_action(Global.RouteGoal.RAIDS).text == "查看明日守备", "The shortcut changes when a raid is due tomorrow.")
	await _button(_action(Global.RouteGoal.RAIDS))
	var plan := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(plan != null and plan.raid_plan.visible and not tree.paused, "The next raid links to the actual night plan."):
		return
	await _capture("05-raid-plan")
	await _key(KEY_ESCAPE)
	await _sleep()
	if not _expect(state.raid_day == state.current_day, "Dawn starts the scheduled raid.") or not await _open_goals():
		return
	_expect(_count(Global.RouteGoal.OFFER_SILK).ends_with("达成") and _action(Global.RouteGoal.RAIDS).text == "标出来敌",
		"The offering counts and the defense action changes when enemies arrive.")
	await _button(_action(Global.RouteGoal.RAIDS))
	_expect(ui.directions.following_raid and not tree.paused, "The raid shortcut tracks the real enemy.")
	print("ROUTE_TRADITION tribute=2 offered=1 raid_day=", state.raid_day, " tracked=", ui.directions.following_raid)

func _continue_previous_council() -> void:
	await _title()
	if not _expect(tree.current_scene.continue_button.visible, "Use a council save written by the previous package."):
		return
	await _button(tree.current_scene.continue_button)
	await _estate()
	if await _open_goals():
		_expect("1/4" in ui.route_goals.summary.text and _count(Global.RouteGoal.COPPER).begins_with("87 /"),
			"The previous package's chosen route shows the right counts on resume.")
		await _key(KEY_ESCAPE)
	print("ROUTE_LEGACY day=", state.current_day, " choice=", state.tax_reform_choice, " copper=", state.money)
