extends SceneTree

const TEACHER := "蒲宁"

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the fish ledger check with an isolated profile.")
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	var events := root.get_node("GameEvents")
	state.current_day = 5
	state.day_progress = 0.35
	state.current_stamina = state.balance.fishing_stamina_cost
	if change_scene_to_file("res://scenes/Main.tscn") != OK:
		quit(1)
		return
	await scene_changed
	var world := current_scene.get_node("World")
	var ui := current_scene.get_node("UI")
	ui.panel_manager.show_management_panel()
	var panel: Control = ui.panel_manager.management_panel_instance
	panel.show_fish_ledger()
	var book: Control = panel.fish_ledger
	var pool: Dictionary = book.sites[CreekFish.Site.POOL]
	var pond: Dictionary = book.sites[CreekFish.Site.POND]
	var position: Vector2 = world.player.position
	_expect(not pool.route.visible and not pond.route.visible and book.teacher_route.visible,
		"The teacher and the separate pond opening explain a new ledger.")
	book.teacher_route.pressed.emit()
	_expect(not panel.visible and ui.directions.tracked_neighbor == TEACHER, "The teacher button follows the actual visitor.")
	ui.panel_manager.show_management_panel()

	state.current_day = 6
	state.visitor_encounters[TEACHER] = 5
	events.ravine_journal_changed.emit()
	_expect(pool.note.text == "鲤鱼" and "雨天" in book.readiness.text and not pool.route.disabled,
		"The wet-season forecast uses today's species.")
	pool.route.pressed.emit()
	_expect(not panel.visible and state.ravine_trip_target == "柳湾", "The forecast uses the existing route to the exact creek stop.")
	ui.panel_manager.show_management_panel()

	state.current_day = 8
	state.visitor_encounters.clear()
	state.season_order_receipts["summer"] = {"day": 7, "dispatch_day": 7, "paid_in_food": false}
	events.pond_landing_opened.emit()
	_expect(pond.note.text == "鲫鱼" and pond.route.visible and not pond.route.disabled and not pool.route.visible,
		"The delivered rice opens the estate pond independently.")
	pond.route.pressed.emit()
	_expect(not panel.visible and ui.directions.tracked_place == state.POND_LANDING and state.market_trip_target == state.POND_LANDING,
		"The pond uses the local landing marker.")
	ui.panel_manager.show_management_panel()

	state.current_day = 31
	state.visitor_encounters[TEACHER] = 5
	state.fish_collection["crucian"] = {"first_day": 8, "first_site": CreekFish.Site.POND, "stock": 0}
	state.fish_collection["minnow"] = {"first_day": 9, "first_site": CreekFish.Site.POOL, "stock": 1}
	state.current_stamina = int(state.balance.fishing_stamina_cost) - 1
	events.stamina_changed.emit(state.current_stamina)
	_expect("体力不足" in book.readiness.text and pool.route.disabled and pond.route.disabled and pool.note.text == "白鲦",
		"The reason disables departures while leaving the forecast readable.")
	_expect(book.readiness.get_theme_color(&"font_color").srgb_to_linear().get_luminance() > 0.55,
		"The fishing requirements use light text on the dark forecast frame.")
	var record: Dictionary = book.rows["minnow"]
	_expect("渔生留鱼" in record.commitment.text and "柳湾夏鲜" in record.commitment.text and not record.sell.disabled,
		"The last fish names both uses beside the exchange buttons.")
	state.fish_collection["minnow"].stock = 2
	events.fish_changed.emit()
	_expect("各需一尾" in record.commitment.text and record.commitment.visible, "Two fish can cover both orders before an exchange.")
	state.fish_collection["minnow"].stock = 3
	events.fish_changed.emit()
	_expect(not record.commitment.visible, "An extra fish leaves both orders covered.")
	state.fish_collection["minnow"].stock = 1
	events.fish_changed.emit()
	_expect("第 8 天" in book.rows["crucian"].history.text and "南池钓台" in book.rows["crucian"].history.text
		and book.rows["crucian"].sell.disabled, "An empty basket still retains the first-catch entry.")
	var standard: int = record.history.get_theme_font_size(&"font_size")
	_expect(root.get_node("Preferences").set_reading_size(2) == OK and record.history.get_theme_font_size(&"font_size") == standard + 6,
		"The reading size also applies to fish entries in the estate.")
	state.last_fishing_day = 31
	state.creek_trap = {"site": CreekFish.Site.SHOAL, "bait": "beans", "set_day": 31}
	events.creek_trap_changed.emit()
	_expect("今日垂钓机会已用" in book.readiness.text and book.trap_card.route.visible
		and "第 33 天可收" in book.trap_card.note.text, "The trap keeps its own schedule when the daily rod has been used.")
	book.trap_card.route.pressed.emit()
	_expect(not panel.visible and state.ravine_trip_target == "砾滩竹笼" and world.player.position == position,
		"The route ends at the trap and leaves the player in place.")

	if change_scene_to_file("res://scenes/WestMarket.tscn") != OK:
		quit(1)
		return
	await scene_changed
	var counter: Control = current_scene.counter
	var stall := load("res://scripts/MarketStall.gd") as GDScript
	counter.open_for(stall.Kind.FISH)
	book = counter.fish
	_expect(counter.scroll.visible and not book.reading.visible and book.market_offer.copper_button.visible
		and book.rows["minnow"].commitment.visible, "The market uses the same catch record and trade note in a single scroll.")
	for frame in 5:
		await process_frame
	var pane: ScrollContainer = counter.scroll
	var layout: Control = counter.counter_layout
	_expect(layout.size.x >= pane.size.x - pane.get_v_scroll_bar().size.x
		and book.rows["minnow"].history.size.x > book.rows["minnow"].history.get_theme_font_size(&"font_size"),
		"The market uses the available width for wrapped fish records.")
	_expect(paused and state.current_day == 31 and is_equal_approx(state.day_progress, 0.35)
		and state.fish_count("minnow") == 1 and state.fish_order_receipt.is_empty()
		and state.creek_trap.get("set_day") == 31 and state.saved_games().is_empty(),
		"Reading and marking never changed fish, the trap, trade, or saves.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
