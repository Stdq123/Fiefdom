extends "res://tests/SilkMarketReplay.gd"

const FIXTURE := "user://recruitment-ledger-replay.json"

func _load_fixture(data: Dictionary) -> bool:
	var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	if not _expect(state.load_game(FIXTURE) == OK, "Load the isolated recruitment fixture."):
		return false
	await tree.scene_changed
	_estate()
	await tree.process_frame
	return true

func _ledger() -> Control:
	await _button(ui.reclaim_button)
	return ui.get_node("Control/ReclamationPanel")

func _option(dialog: Control, prefix: String) -> Button:
	for button: Button in dialog.options_container.get_children():
		if button.text.begins_with(prefix):
			return button
	return null

func _talk_on_estate(speaker: String) -> Control:
	await _key(KEY_E)
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	return dialog if _expect(dialog != null and dialog.name_label.text == speaker, "Speak to " + speaker) else null

func _recruit_at_market() -> bool:
	var sheet := await _ledger()
	if not legacy:
		_expect("正沿西路去西市" in sheet.info_label.text, "The open ledger starts with the westbound trip.")
		await _time_at(0.4)
	var detail := "招募需 20 声望" if legacy else "还差 4 声望，今日交谈可得 5"
	if not _expect(sheet.visitor_button.visible and sheet.visitor_button.text == "去找陶辛"
		and "西市绸摊" in sheet.info_label.text and detail in sheet.info_label.text,
		"The ledger follows Tao Xin's actual stop while it is open."):
		return false
	await _snapshot("01-merchant-at-market")
	await _button(sheet.visitor_button)
	_expect(ui.directions.tracked_neighbor == TAO and state.market_trip_target == TAO
		and ui.directions.destination().point == world.get_node("WestMarketGate").position,
		"The invitation route begins at the west gate.")
	if not await _road_to_market():
		return false
	var market := tree.current_scene
	var chart: Control = market.market_map
	await tree.process_frame
	await tree.process_frame
	_expect(chart.pin.visible and market.silk_guest != null
		and chart.pin.global_position.distance_to(market.silk_guest.position) < 3.0,
		"The same route follows Tao Xin across the map boundary.")
	await _approach_tao(market)
	if not legacy:
		await _key(KEY_E)
		var dialog := market.get_node("UI/Control/DialoguePanel") as Control
		var invitation := _option(dialog, "招募")
		_expect(invitation != null and invitation.disabled and "还差 4 声望" in invitation.text,
			"The disabled invitation explains the missing reputation.")
		await _snapshot("02a-reputation-needed")
		await _button(_option(dialog, "交谈"))
		_expect(state.reputation == 21, "The ordinary conversation covers the stated gap.")
	var reputation: int = state.reputation
	if not await _talk(market, "招募", "02-invite-at-market"):
		return false
	_expect(state.retainers.size() == 2 and state.retainers.back().name == TAO
		and state.reputation == reputation - state.balance.recruit_reputation_requirement,
		"The ordinary market conversation recruits once at the quoted cost.")
	await Campaign.walk_to_market_exit(tree, market)
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return false
	_estate()
	sheet = await _ledger()
	_expect(not sheet.visitor_button.visible and "今日已留一位门客" in sheet.info_label.text
		and "第 11 天 · 弋戎 · 东路岗" in sheet.info_label.text,
		"The same-day limit and next appointment are shown after returning from the market.")
	await _snapshot("03-next-visitor")
	await _key(KEY_ESCAPE)
	await _sleep_through(10)
	sheet = await _ledger()
	_expect(not sheet.visitor_button.visible and "第 11 天 · 弋戎" in sheet.info_label.text,
		"A rest day forecasts the next actual visitor.")
	await _key(KEY_ESCAPE)
	await _sleep_through(11)
	sheet = await _ledger()
	_expect(sheet.visitor_button.visible and sheet.visitor_name == VisitorData.EAST_WATCHER,
		"The predicted visitor is available on the stated date.")
	await _key(KEY_ESCAPE)
	print("RECRUITMENT_MARKET day=", state.current_day, " retained=", state.retainers.back().name,
		" cost=", state.balance.recruit_reputation_requirement, " next=", VisitorData.EAST_WATCHER)
	return not failed

func _invite_after_shortage() -> void:
	if not await _load_fixture({
		"current_day": 21, "current_rank": state.Rank.ZHONG_SHI, "king_storage": 3, "reputation": 60,
		"money": 45, "food_storage": 1,
		"retainers": [{"name": VisitorData.ROAD_KEEPER, "school": 1, "loyalty": 80}],
		"neighbor_departures": {VisitorData.FIELD_KEEPER: {"day": 19, "reason": state.DepartureReason.HUNGER, "returned_day": 0}},
	}):
		return
	var sheet := await _ledger()
	var keeper: Node2D = world.neighbor_actor(VisitorData.FIELD_KEEPER)
	if not _expect(world.current_visitor() == null and keeper != null and sheet.visitor_button.visible
		and "渠伯在井田西南" in sheet.info_label.text and "还差 1 份口粮" in sheet.info_label.text,
		"The returning field keeper is listed on a rest day with the exact food shortfall."):
		return
	await _snapshot("04-keeper-needs-grain")
	await _button(sheet.visitor_button)
	await _walk(world.player, [Vector2(16, 159), keeper.global_position + Vector2(0, 16)])
	var dialog := await _talk_on_estate(VisitorData.FIELD_KEEPER)
	if dialog == null:
		return
	var invite := _option(dialog, "请回来")
	_expect(invite != null and invite.disabled and "还差 1 份口粮" in invite.text
		and "每夜用粮 1 → 2 份 · 粮仓 1 份" in dialog.context_label.text,
		"The dialogue gives the same food reason and forecasts the returning worker's ration.")
	await _snapshot("05-return-dialogue")
	await _key(KEY_ESCAPE)
	await _button(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	await _button(management.sections.get_node("市场"))
	await _button(management.market_panel.buy_button)
	await _button(management.close_button)
	dialog = await _talk_on_estate(VisitorData.FIELD_KEEPER)
	if dialog == null:
		return
	invite = _option(dialog, "请回来")
	if _expect(invite != null and not invite.disabled, "Buying the missing portion enables the invitation."):
		await _button(invite)
	_expect(state.food_storage == 2 and state.retainers.size() == 2
		and state.retainers.back().name == VisitorData.FIELD_KEEPER,
		"The returning worker joins with one night's grain still available.")
	print("RECRUITMENT_RETURN day=", state.current_day, " grain=", state.food_storage, " retained=", state.retainers.size())

func _check_promotion_tradeoff() -> void:
	if not await _load_fixture({
		"current_day": 2, "king_storage": 3, "reputation": 100, "food_storage": 12,
	}):
		return
	var visitor: Node2D = world.neighbor_actor(VisitorData.ROAD_KEEPER)
	await _walk(world.player, [visitor.global_position + Vector2(0, 16)])
	var dialog := await _talk_on_estate(VisitorData.ROAD_KEEPER)
	if dialog == null:
		return
	var invite := _option(dialog, "招募")
	_expect(invite != null and not invite.disabled and "80/100" in dialog.context_label.text and "晋升中士" in dialog.context_label.text
		and "每夜用粮 1 → 2 份 · 粮仓 12 份" in dialog.context_label.text,
		"Recruiting at the first promotion threshold shows the reputation and food tradeoffs before confirmation.")
	await _snapshot("06-promotion-tradeoff")
	await _button(invite)
	await _sleep_through(3)
	_expect(state.current_rank == state.Rank.XIA_SHI and state.reputation == 80 and state.retainers.size() == 2,
		"The player can still recruit immediately and promotion follows the resulting reputation.")
	print("RECRUITMENT_PROMOTION day=", state.current_day, " rank=", state.current_rank, " reputation=", state.reputation)

func _provision_after_hiring() -> void:
	if not await _load_fixture({
		"save_version": 2, "current_day": 2, "current_rank": state.Rank.ZHONG_SHI, "king_storage": 1,
		"reputation": 35, "food_storage": 2, "money": 45, "private_harvest_total": 1, "first_harvest_reviewed": true,
		"retainers": [{"name": VisitorData.FIELD_KEEPER, "school": 2, "duty": RetainerData.Duty.HARVEST}],
	}):
		return
	var visitor: Node2D = world.neighbor_actor(VisitorData.ROAD_KEEPER)
	await _walk(world.player, [visitor.global_position + Vector2(0, 16)])
	var dialog := await _talk_on_estate(VisitorData.ROAD_KEEPER)
	if dialog == null:
		return
	var invite := _option(dialog, "招募")
	if not _expect(invite != null and not invite.disabled and "每夜用粮 2 → 3 份 · 粮仓 2 份" in dialog.context_label.text,
		"The forecast includes the current specialist's extra ration and leaves an ordinary hire available."):
		return
	await _snapshot("07-hiring-ration-preview")
	await _button(invite)
	var action: Button = ui.hud.opening_action
	if not _expect(state.retainers.size() == 2 and state.food_storage == 2 and action.visible and action.text == "为新门客备粮",
		"After hiring (retainers %d, grain %d), expected a visible provisioning shortcut, got '%s' (visible %s)." % [
			state.retainers.size(), state.food_storage, action.text, action.visible]):
		return
	await _snapshot("08-provision-new-retainer")
	await _button(action)
	var night := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(night != null and "今夜缺 1 份" in night.forecast.text, "The action opens the ordinary night forecast with the same shortage."):
		return
	await _button(night.get_node("%Market"))
	var management: Control = ui.panel_manager.management_panel_instance
	await _button(management.market_panel.buy_button)
	await _button(management.close_button)
	_expect(state.food_storage == 3 and action.text == "查看开垦筹备", "Buying one ration restores the survey shortcut.")
	await _sleep_through(3)
	_expect(state.night_rations.last.need == 3 and state.night_rations.last.served == 3,
		"Ordinary sleep consumes the predicted rations and feeds both retainers.")
	print("RECRUITMENT_PROVISION served=", state.night_rations.last.served, " retained=", state.retainers.size())

func _play() -> void:
	if not capture_path.is_empty():
		capture_dir = capture_path
	if legacy:
		await _button(tree.current_scene.continue_button)
		if tree.current_scene == null:
			await tree.scene_changed
		_estate()
		_expect(state.current_day == 9 and state.king_storage == 3 and state.active_crops.size() == 2
			and state.retainers.size() == 1 and state.silk_sample_day == 4, "Continue the actual previous package save.")
	elif not await _load_fixture({
		"current_day": 9, "day_progress": VisitorData.SILK_MARKET_ARRIVE - 0.025, "current_rank": state.Rank.ZHONG_SHI,
		"king_storage": 3, "food_storage": 12, "money": 55, "reputation": 16,
		"silk_sample_day": 4, "silk_workshop": {"built": true},
	}):
		return
	if await _recruit_at_market() and not legacy:
		await _invite_after_shortage()
		await _check_promotion_tradeoff()
		await _provision_after_hiring()
	tree.unload_current_scene()
	await tree.process_frame
