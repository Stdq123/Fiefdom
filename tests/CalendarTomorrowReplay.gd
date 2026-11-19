extends "res://tests/NightRationsReplay.gd"

const PLOT := Vector2i(6, 5)

func _continue_on(day: int) -> bool:
	var fixture := {
		"current_day": day, "king_storage": 3, "money": 12, "food_storage": 4,
		"gathering_recitals": {"6": 4} if day >= 6 else {},
		"player_inventory": 2, "crop_stock": {"millet": 2},
		"active_crops": {str(PLOT): {"id": "millet", "growth_nights": 4, "watered": true}},
	}
	var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if not _expect(file != null, "Write an isolated late-winter checkpoint."):
		return false
	file.store_string(JSON.stringify(fixture))
	file.close()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	var resume: Button = tree.current_scene.continue_button
	if not _expect(resume.is_visible_in_tree() and not resume.disabled, "Continue from the regular title."):
		return false
	await _click(resume)
	if tree.current_scene == null:
		await tree.scene_changed
	await tree.process_frame
	ui = tree.current_scene.get_node_or_null("UI")
	return _expect(ui != null and state.current_day == day, "Resume the checkpoint at the correct date.")

func _tomorrow(capture := "") -> bool:
	var panel := await _open()
	if not _expect(panel != null and panel.tomorrow_calendar.is_visible_in_tree(), "Open tomorrow from the night plan."):
		return false
	_expect(tree.root.get_visible_rect().encloses(panel.tomorrow_calendar.get_global_rect()),
		"The tomorrow button fits inside the window.")
	if not capture.is_empty():
		await _capture(capture)
	await _click(panel.tomorrow_calendar)
	await tree.process_frame
	return _expect(ui.calendar.modal.visible and tree.paused and _panel() == null,
		"The almanac takes focus and the pause from the night plan.")

func _winter_to_spring() -> void:
	if not await _continue_on(24) or not await _tomorrow("01-night-plan"):
		return
	var book: Control = ui.calendar
	_expect("第 2 年" in book.year_label.text and "今天第 24 天" in book.year_label.text
		and "立春" in book.title.text and "第 25 天" in book.title.text and book.next_year.disabled
		and "南路续种" in book.order_note.text and "第 30 天截止" in book.order_note.text
		and "明日东关有敌情" in book.forecast.text
		and book.order_button.is_visible_in_tree() and book.order_button.text == "下季备货",
		"The next morning is spring, with the second year's spring order and its deadline.")
	_expect(book.modal.get_global_rect().encloses(book.title.get_global_rect())
		and book.modal.get_global_rect().encloses(book.close_button.get_global_rect()), "The almanac fits the window.")
	await _capture("02-tomorrow-spring")
	await _click(book.previous_year)
	_expect("第 1 年" in book.year_label.text and book.previous_year.disabled and not book.order_button.visible,
		"Browse the same term in the prior year without opening a historical order for delivery.")
	await _click(book.dates.get_child(5))
	_expect("谷雨" in book.title.text and "迎客曲 4/4 · 已入曲簿" in book.event_note.text and not book.guide.visible,
		"The previous year's recital still appears on its original date.")
	await _capture("03-last-spring-record")
	await _click(book.next_year)
	_expect("第 2 年" in book.year_label.text and "第 30 天" in book.title.text and "谷雨" in book.title.text
		and "迎客曲 4/4" not in book.event_note.text, "A new year does not borrow last year's festival record.")
	await _click(book.today_button)
	_expect("第 1 年" in book.year_label.text and "大寒" in book.title.text and "第 24 天" in book.title.text,
		"Return directly to today's late-winter date.")
	await _click(book.close_button)
	if not await _tomorrow():
		return
	await _click(book.order_button)
	var management: Control = ui.panel_manager.management_panel_instance
	if not _expect(management != null and not book.modal.visible and not tree.paused, "Switch to the delivery ledger."):
		return
	var orders: Control = management.season_order_panel
	_expect(orders.is_visible_in_tree() and "南路续种" in orders.next_details.text and orders.next_plan_button.has_focus()
		and tree.root.get_visible_rect().encloses(orders.next_plan_button.get_global_rect()),
		"The focus lands on the real next-season preparation control.")
	await _capture("04-next-order")
	await _click(orders.next_plan_button)
	await _click(management.close_button)
	_expect(state.current_day == 24 and state.pinned_season_start == 25 and state.money == 12
		and state.crop_stock.count("millet") == 2 and state.active_crops[PLOT].growth_nights == 4,
		"Browsing changes neither the field nor the pantry. Explicit tracking targets the new order.")
	await _sleep()
	_expect(state.current_day == 25 and state.raid_day == 25 and state.pinned_season_order().order.id == "spring_seed_share"
		and state.active_crops[PLOT].age == 1 and state.active_crops[PLOT].growth_nights == 4
		and state.king_storage == 3 and state.crop_stock.count("millet") == 2,
		"Actual dawn advances once, keeps the existing crop duration and promotes the prepared order.")
	var panel := await _open()
	if not _expect(panel != null and panel.page_button.visible, "The night plan can show last night's settlement."):
		return
	await _click(panel.page_button)
	_expect(panel.show_previous and not panel.tomorrow_calendar.visible, "Keep the tomorrow shortcut on tonight's page.")
	await _click(panel.close_button)
	await tree.process_frame
	await _click(ui.hud.calendar_button)
	_expect(book.modal.visible and "第 2 年" in book.year_label.text and "第 25 天" in book.title.text
		and "今日轮访" in book.forecast.text and book.order_button.text == "查看交货簿",
		"Today's almanac matches dawn. Open=%s year=%s date=%s forecast=%s order=%s" % [book.modal.visible,
		book.year_label.text, book.title.text, book.forecast.text, book.order_button.text])
	await _click(book.close_button)
	print("CALENDAR_ROLLOVER day=", state.current_day, " order=", state.pinned_season_order().order.id,
		" crop_age=", state.active_crops[PLOT].age, " growth_nights=", state.active_crops[PLOT].growth_nights)

func _same_term() -> void:
	state.balance.days_per_solar_term = 2
	state.balance.days_per_year = 48
	if not await _continue_on(1) or not await _tomorrow():
		return
	var book: Control = ui.calendar
	_expect("第 1 年" in book.year_label.text and "第 2 天" in book.title.text and "立春" in book.title.text
		and "预计轮访 " + VisitorData.ROAD_KEEPER in book.forecast.text,
		"A tomorrow within the same term shows its own date and its own visitor forecast.")
	await _click(book.today_button)
	_expect("第 1 天" in book.title.text and "轮访歇日" in book.forecast.text,
		"Returning to today restores today's different visitor schedule.")
	await _click(book.close_button)
	print("CALENDAR_TERM_RANGE today=1 tomorrow=2 term=立春")

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated almanac profile."):
		_end()
		return
	state = tree.root.get_node("Global")
	tree.root.notify_mouse_entered()
	await _same_term()
	if not failed:
		state.balance.days_per_solar_term = 1
		state.balance.days_per_year = 24
		await _winter_to_spring()
	_end()
