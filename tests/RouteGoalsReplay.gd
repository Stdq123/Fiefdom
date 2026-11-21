extends "res://tests/TaxCouncilReplay.gd"

var legacy := false

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the route goals replay profile."):
		tree.quit(1)
		return
	seed(1979)
	tree.root.notify_mouse_entered()
	if capture_dir.is_empty():
		capture_dir = OS.get_environment("FIEFDOM_ROUTE_CAPTURES")
	state = tree.root.get_node("Global")
	if legacy:
		await _continue_previous_council()
	else:
		await _reformed()
		await _traditional()
		if failures == 0:
			await _reserve_through_season_change()
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
	await tree.process_frame
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
	_expect(_action(Global.RouteGoal.TAXED_HARVEST).text == "指路收熟田"
		and "税后 +28 铜钱" in _row(Global.RouteGoal.TAXED_HARVEST).get_node("%GoalDetail").text,
		"The taxed harvest goal previews the actual mature crops and their net income.")
	await _button(_action(Global.RouteGoal.TAXED_HARVEST))
	var chart: Control = ui.estate_map
	_expect(not ui.route_goals.modal.visible and not chart.modal.visible and not tree.paused
		and state.field_route_status == state.NightGrowth.READY and state.field_route_scope == state.FieldScope.ALL,
		"Mature taxed crops are tracked directly from the goals.")
	if not await _follow_harvests(3):
		return
	if not await _open_goals():
		return
	_expect(_count(Global.RouteGoal.TAXED_HARVEST).begins_with("4 /") and _count(Global.RouteGoal.COPPER).begins_with("115 /"),
		"Real field harvests update the taxed stock and copper totals.")
	_expect(_action(Global.RouteGoal.TAXED_HARVEST).text == "查看井田", "Without ripe crops, the route opens the field map.")
	await _button(_action(Global.RouteGoal.TAXED_HARVEST))
	_expect(chart.modal.visible and chart.category == chart.Category.FIELDS and tree.paused,
		"The fallback gives the player the usual field map.")
	await _key(KEY_ESCAPE)
	if not await _open_goals():
		return
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
	var market: Control = management.market_panel
	_expect(management.visible and management.tabs.get_current_tab_control() == market
		and market.reform_sale_button.has_focus() and market.reform_sale_button.text == "出售 6 份 · +30 铜钱",
		"The copper action opens and focuses its current sale quote in the market.")
	var money_before: int = state.money
	var old_quote: Dictionary = market.reform_quote
	await _button(market.buy_button)
	var trade: Dictionary = state.sell_crops_for_reform(old_quote)
	_expect(trade.is_empty() and state.money == money_before - state.balance.market_food_price
		and state.player_inventory == 10, "A changed quote cannot debit the current stock.")
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
		var pad = load("res://tests/GamepadReplay.gd").new()
		pad.tree = tree
		pad.pad = tree.root.get_node("GamepadInput")
		tree.root.notify_mouse_exited()
		await pad._click(_action(Global.RouteGoal.COPPER), true)
		market = ui.panel_manager.management_panel_instance.market_panel
		_expect(market.reform_sale_button.has_focus()
			and market.reform_sale_button.get_global_rect().has_point(pad.pad.cursor.position),
			"The controller pointer reaches the focused quote after the market is laid out.")
		await _capture("06-reform-sale-quote")
		await pad._tap(JOY_BUTTON_A)
		_expect(state.money == 180 and state.player_inventory == 3 and state.crop_stock.count("millet") == 1
			and not market.reform_sale.visible and "铜钱已达标" in market.receipt.text
			and market.crop_choice.has_focus() and pad.failures == 0,
			"Confirm the quote by controller, retain the spring order's millet and show the receipt.")
		await _capture("07-reform-sale-complete")
		await _key(KEY_ESCAPE)
		if await _open_goals():
			_expect("3/4" in ui.route_goals.summary.text and _count(Global.RouteGoal.COPPER).ends_with("达成"),
				"Selling the quoted surplus credits the copper target only.")
			await _key(KEY_ESCAPE)
	print("ROUTE_REFORM harvested=4 sold=1 market_spent=5 quote_copper=", state.money, " reserved_millet=", state.crop_stock.count("millet"))

func _click_plot(cell: Vector2i) -> void:
	var tiles: TileMapLayer = world.tile_map
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))

func _follow_harvests(count: int, public_only := false) -> bool:
	for index in count:
		var cell: Variant = ui.directions.tracked_plot
		if not _expect(cell != null and world.is_crop_ripe(cell) and (not public_only or state.is_public_plot(cell)),
			"The next marked plot is ripe and matches the route."):
			return false
		await _click_plot(cell)
	return _expect(ui.directions.tracked_plot == null, "The route clears after the last matching harvest.")

func _reserve_through_season_change() -> void:
	var fixture := SNAPSHOT.duplicate(true)
	fixture.merge({"current_day": 60, "tax_reform_choice": state.TaxReformChoice.REFORMED,
		"tax_reform_day": 53, "raids_defeated": 1, "money": 154, "food_storage": 1,
		"crop_stock": {"beans": 3, "sorghum": 2, "hemp": 4}, "player_inventory": 9,
		"night_rations": {"enabled": true, "copper_limit": 0}}, true)
	fixture.active_crops = {}
	if not await _load_reform_fixture(fixture):
		return
	var market: Control = await _open_reform_market()
	if not _expect(market != null and market.reform_quote.get("used") == {"beans": 2}
		and "今夜所缺口粮 3 份" in market.reform_sale_note.text and "时令与节庆用料 4 份" in market.reform_sale_note.text,
		"Reserve three portions and the four portions for the autumn order."):
		return
	var management: Control = ui.panel_manager.management_panel_instance
	var sections: Control = management.get_node("%Sections")
	_expect(sections.get_global_rect().end.y <= market.get_global_rect().position.y
		and management.get_node("Frame").get_global_rect().encloses(market.reserve_button.get_global_rect()),
		"The crowded market quote, tabs and reserve controls stay inside the management frame.")
	await _capture("08-reform-reserve-tomorrow")
	await _button(market.reform_sale_button)
	_expect(state.money == 164 and state.player_inventory == 7 and state.food_storage == 1
		and market.reform_quote.is_empty() and "铜钱已达标" not in market.receipt.text,
		"Selling the available surplus leaves exactly three meal crops, keeps the order and stops short of the target.")
	await _key(KEY_ESCAPE)
	await _sleep()
	var served: Dictionary = state.night_rations.last
	_expect(state.current_day == 61 and served.served == served.need and served.used == {"hemp": 3}
		and served.bought == 0 and state.money == 164 and state.player_inventory == 4,
		"The real season change feeds everyone with the reserved surplus and keeps the autumn delivery.")
	print("ROUTE_REFORM_RESERVE day=", state.current_day, " sold=2 meals=", served.served,
		" order_stock=", state.player_inventory, " copper=", state.money)
	if failures == 0:
		await _reserve_festival_ingredients(fixture)

func _reserve_festival_ingredients(base: Dictionary) -> void:
	var fixture := base.duplicate(true)
	fixture.merge({"current_day": 63, "food_storage": 4, "money": 175, "player_inventory": 5,
		"crop_stock": {"sorghum": 2, "beans": 1, "hemp": 1, "millet": 1},
		"legacy_order_start": 0, "night_rations": {"enabled": true, "copper_limit": 0, "festival_day": 64}}, true)
	if not await _load_reform_fixture(fixture):
		return
	var market: Control = await _open_reform_market()
	if not _expect(market != null and state.night_rations_plan().festival_pantry.get("held") == {"millet": 1}
		and not market.reform_sale.visible, "The last millet reserved for the autumn fair is excluded from the sale."):
		return
	await _key(KEY_ESCAPE)
	await _button(ui.hud.season_event_button)
	var calendar: Control = ui.calendar
	if not _expect(calendar.keep_samples.button_pressed, "The fair shows the restored reservation."):
		return
	await _button(calendar.keep_samples)
	await _button(calendar.close_button)
	market = await _open_reform_market()
	_expect(market != null and market.reform_quote.get("used") == {"millet": 1},
		"The player can release the festival reservation to include only that crop.")
	await _key(KEY_ESCAPE)
	print("ROUTE_REFORM_FESTIVAL released_millet=1 kept_order=4")

func _load_reform_fixture(fixture: Dictionary) -> bool:
	var path := "user://reform-market-fixture.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	if not _expect(state.load_game(path) == OK, "Continue a pre-existing reform estate with the current economy."):
		return false
	await tree.scene_changed
	state.balance.raid_first_day = 1000
	await _estate()
	return true

func _open_reform_market() -> Control:
	if not await _open_goals():
		return null
	await _button(_action(Global.RouteGoal.COPPER))
	return ui.panel_manager.management_panel_instance.market_panel

func _traditional() -> void:
	state.balance.raid_first_day = SNAPSHOT.current_day + 2
	if not await _choose_route(state.TaxReformChoice.TRADITIONAL, 0) or not await _open_goals():
		return
	_expect(state.reform_sale_quote().is_empty(), "Traditional estates keep their usual market.")
	_expect("守礼安邦" in ui.route_goals.heading.text and "0/3" in ui.route_goals.summary.text
		and _count(Global.RouteGoal.TRIBUTE).begins_with("0 /") and _action(Global.RouteGoal.RAIDS).text == "查看守备准备",
		"Traditional goals track new tribute and direct the player to defense.")
	await _capture("04-traditional-goals")
	await _button(_action(Global.RouteGoal.RAIDS))
	var early_plan := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(early_plan != null and early_plan.raid_plan.visible and "第 55 天卯时" in early_plan.raid_heading.text,
		"With no military retainer, the shortcut shows the next raid and personal preparations."):
		return
	await _key(KEY_ESCAPE)
	if not await _open_goals():
		return
	_expect(_action(Global.RouteGoal.TRIBUTE).text == "指路收公田"
		and "可纳贡 2 份" in _row(Global.RouteGoal.TRIBUTE).get_node("%GoalDetail").text,
		"The traditional goal previews only the mature public contribution.")
	await _button(_action(Global.RouteGoal.TRIBUTE))
	if not await _follow_harvests(2, true):
		return
	_expect(world.is_crop_ripe(PRIVATE), "The public route ends while a private crop is still ripe.")
	await _click_plot(PRIVATE)
	if not await _open_goals():
		return
	_expect(_count(Global.RouteGoal.TRIBUTE).begins_with("2 /"), "The two public plots fill only the tribute goal.")
	await _button(_action(Global.RouteGoal.OFFER_SILK))
	var management: Control = ui.panel_manager.management_panel_instance
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
