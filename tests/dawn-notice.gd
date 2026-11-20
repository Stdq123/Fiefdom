extends SceneTree

var tree: SceneTree
var screen: Window
var failed := false
var capture_directory := ""

func _initialize() -> void:
	_review.call_deferred(self)

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _frames(count: int) -> void:
	for frame in count:
		await tree.process_frame

func _capture(view: String) -> void:
	if capture_directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := screen.get_texture().get_image()
	_expect(image.save_png(capture_directory.path_join(view + ".png")) == OK, "Save " + view)
	print("DAWN_NOTICE_FRAME ", view, " window=", screen.size, " pixels=", image.get_size())
	await tree.process_frame

func _estate_snapshot(state: Node, actor: Node) -> Array:
	return [state.current_day, state.day_progress, state.money, state.food_storage, state.current_stamina,
		state.reputation, state.active_crops.duplicate(true), state.crop_stock.lots.duplicate(true),
		state.last_dawn.duplicate(true), state.last_field_night.duplicate(true),
		state.night_rations.last.duplicate(true), actor.global_position, state.saved_games().size()]

func _layout(ui: Node, check_focus := false) -> void:
	var hud: Control = ui.hud
	var notice: Control = hud.dawn_notice
	var outer := notice.get_global_rect()
	_expect(screen.get_visible_rect().encloses(outer) and absf(outer.get_center().x - screen.get_visible_rect().get_center().x) < 1.0,
		"The announcement fits and is centered.")
	for boundary: Control in [hud.get_node("Journal"), hud.get_node("Calendar"), hud.get_node("Tools"), ui.campaign_hud.notice]:
		_expect(not outer.intersects(boundary.get_global_rect()), "Keep the announcement away from " + String(boundary.name))
	for control: Control in notice.find_children("*", "Control", true, false):
		_expect(control.mouse_filter == Control.MOUSE_FILTER_IGNORE and control.focus_mode == Control.FOCUS_NONE,
			"The announcement never captures focus or pointer clicks.")
		if control.is_visible_in_tree():
			_expect(outer.encloses(control.get_global_rect()), "The full text and icon fit in the announcement.")
	_expect(not hud.map_space_clear(outer) and notice.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Scene prompts avoid the visible announcement while its background passes clicks.")
	if check_focus:
		_expect(hud.morning_button.has_focus(), "The announcement leaves the selected HUD control focused.")

func _review_reveal(ui: Node, state: Node, actor: Node) -> void:
	var notice: Control = ui.hud.dawn_notice
	var before := _estate_snapshot(state, actor)
	ui.hud.refresh_morning_record()
	ui.hud.morning_button.grab_focus()
	# Start the presentation at the closed curtain. This path only reads the supplied receipt.
	actor.resting = true
	ui.fader.color.a = 1.0
	ui.fader.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.sleep_tween = ui.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var started := Engine.get_process_frames()
	ui._queue_dawn_reveal()
	await _frames(12)
	_expect(notice.visible and notice.modulate.a == 1.0 and ui.fader.color.a > 0.0 and ui.fader.color.a < 1.0
		and actor.resting, "The date rises together with the scene behind the curtain.")
	await _capture("01-rain-reveal")
	await ui.sleep_tween.finished
	var reveal_frames := Engine.get_process_frames() - started
	_expect(reveal_frames >= 29 and reveal_frames <= 32 and ui.fader.color.a == 0.0
		and ui.fader.mouse_filter == Control.MOUSE_FILTER_IGNORE and not actor.resting, "Control returns after the original half-second reveal.")
	_expect(notice.date_label.text == "第 %d 天 · %s · 卯时" % [state.current_day, state.get_current_solar_term()]
		and notice.sky.texture.region.position.x == 6 * 16.0, "Show the spring rain and dawn watch.")
	_expect(notice.result_label.text == "欠贡 · 声望 −8" and ui.hud.morning_button.text == "昨夜结算 · 欠贡 · 声望 −8",
		"Late tribute keeps the same readable consequence in the notice and the receipt button.")
	await _frames(146)
	_expect(notice.is_visible_in_tree() and notice.modulate.a == 1.0, "The result is still fully readable over two seconds after the reveal.")
	_layout(ui, true)
	await _capture("02-missed-tribute")
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		screen.push_input(key, true)
	var book := ui.get_node_or_null("Control/NightRationsPanel") as Control
	await _frames(6)
	_expect(book != null and book.show_previous and "第 %d 夜" % (state.current_day - 1) in book.page_date.text
		and "欠贡 · 声望 −8" in book.milestones.text
		and not notice.visible, "Enter opens the existing dated receipt and gives it the screen.")
	if book != null:
		await _capture("03-reopen-receipt")
		book.queue_free()
	await _frames(4)
	_expect(ui.hud.morning_button.has_focus() and before == _estate_snapshot(state, actor),
		"Reading the receipt returns focus and keeps the recorded estate intact.")
	print("DAWN_NOTICE_REVEAL frames=", reveal_frames, " fade_removed=true read_after_frames=146")

func _review_results(ui: Node, state: Node, actor: Node) -> void:
	var notice: Control = ui.hud.dawn_notice
	state.last_dawn = {"day": state.current_day - 1}
	state.night_rations.last = {}
	var previous: Dictionary = state.last_field_night.duplicate()
	var snapshot := _estate_snapshot(state, actor)
	ui.hud.show_dawn_notice()
	await _frames(6)
	_expect(notice.result_label.text == "公田新熟 1 格 · 私田新熟 4 格", "Keep both kinds of newly ripe plots distinct.")
	_layout(ui)
	await _capture("04-newly-ripe")
	await _frames(302)
	_expect(notice.visible and notice.modulate.a > 0.0 and notice.modulate.a < 1.0, "The five-second result fades independently of the curtain.")
	await _frames(23)
	_expect(not notice.visible and ui.hud.map_space_clear(notice.get_global_rect()) and ui.campaign_hud.notice.offset_top == 112.0,
		"The completed fade releases the reserved space and restores the usual notice position.")
	_expect(snapshot == _estate_snapshot(state, actor), "The complete clock and fade leave the estate intact.")

	state.last_field_night = {}
	ui.hud.show_dawn_notice()
	await _frames(6)
	_expect(not notice.result_label.visible, "A quiet morning shows the date without a filler row.")
	_layout(ui)
	await _capture("05-date-only")

	state.last_dawn.research_gap = 104
	ui.hud.show_dawn_notice()
	await _frames(6)
	_expect(notice.result_label.text == "研究经费未缴 · 缺 104 铜钱 · 召简回堂前催议", "An unpaid research installment shows the gap and the envoy's location.")
	_layout(ui)
	await _capture("06-research-warning")

	state.raid_day = state.current_day
	state.raid_kind = 0
	state.last_dawn.tribute_penalty = 8
	ui.hud.show_dawn_notice()
	await _frames(6)
	_expect(notice.result_label.text.begins_with("东路来敌 · 野狗\n")
		and "研究经费未缴 · 缺 104 铜钱" in notice.result_label.text and "欠贡 · 声望 −8" in notice.result_label.text,
		"A live raid is listed first while the overnight results remain readable.")
	_layout(ui)
	await _capture("07-raider-warning")
	screen.get_node("GameEvents").map_departing.emit()
	_expect(not notice.visible, "The morning notice also clears before travel.")
	state.raid_day = 0
	state.last_dawn = {"day": state.current_day - 1, "completed_fields": [2, 3]}
	state.last_field_night = previous
	ui.hud.show_dawn_notice()
	await _frames(6)
	_expect(notice.result_label.text == "井田 2、3 已完工 · 可耕种", "A completed field keeps its numbers in view.")
	_layout(ui)
	await _capture("08-fieldwork")
	print("DAWN_NOTICE_HOLD result_seconds=5 fade_seconds=0.34 positions_clear=true")

func _review_world_notice(ui: Node) -> void:
	var campaign: CanvasLayer = ui.campaign_hud
	var notice: Label = campaign.notice
	var receipt := ("今日外出田务 · 翻地 12 格 · 浇水 18 格 · 收割 12 格 · 补播 10 格\n"
		+ "国库 +1 · 私仓 +11 · 铜钱 +96 · 桑叶 +18\n首份纳贡已入库 · 堂前可翻账 · 可找渠伯谈轮作")
	campaign.show_world_notice(receipt, 5.0)
	await _frames(6)
	var bounds := notice.get_global_rect()
	_expect(notice.visible and notice.get_theme_font_size(&"font_size") == 22 and notice.text == receipt
		and notice.get_line_count() > 3 and notice.get_visible_line_count() == notice.get_line_count(),
		"The larger return receipt wraps without dropping any text.")
	_expect(screen.get_visible_rect().encloses(bounds) and ui.hud.map_space_clear(bounds)
		and notice.is_in_group(&"interaction_prompt_obstacle") and notice.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"The notice fits between the HUD panels and leaves input to the map.")
	var events := screen.get_node("GameEvents")
	events.modal_visibility_changed.emit(true)
	events.settings_visibility_changed.emit(true)
	_expect(not notice.visible, "A modal hides the active notice.")
	await _frames(350)
	events.modal_visibility_changed.emit(false)
	_expect(not notice.visible, "Settings still covers the notice after the other panel closes.")
	events.settings_visibility_changed.emit(false)
	_expect(notice.visible and notice.text == receipt and notice.modulate.a == 1.0,
		"A five-second receipt remains readable after more than five seconds in a panel.")
	await _frames(286)
	_expect(notice.visible and notice.modulate.a == 1.0, "The remaining reading time is available after closing the panels.")
	await _frames(43)
	_expect(not notice.visible and is_zero_approx(notice.modulate.a), "Fading frees the notice's reserved area.")

	events.management_visibility_changed.emit(true)
	campaign.show_world_notice("今日已采集", 0.05)
	const SHORT_NOTICE := "草料 +2 · 已送回羊棚"
	campaign.show_world_notice(SHORT_NOTICE, 0.05)
	await _frames(40)
	_expect(not notice.visible, "A notice sent during management waits for the world view.")
	events.management_visibility_changed.emit(false)
	_expect(notice.visible and notice.text == SHORT_NOTICE and notice.modulate.a == 1.0,
		"The latest notice starts at full opacity even if it was posted in a panel.")
	await _frames(6)
	_expect(notice.size.y < bounds.size.y and notice.size.x < bounds.size.x,
		"A short message uses a compact panel after the long receipt.")
	var fade_alpha := notice.modulate.a
	events.modal_visibility_changed.emit(true)
	await _frames(40)
	events.modal_visibility_changed.emit(false)
	_expect(notice.visible and fade_alpha > 0.0 and fade_alpha < 1.0 and notice.modulate.a == fade_alpha,
		"A partially faded notice resumes without restarting.")
	events.modal_visibility_changed.emit(true)
	events.world_notice.emit("")
	events.modal_visibility_changed.emit(false)
	_expect(not notice.visible, "An empty notice leaves no panel behind.")

func _review_save_notice(ui: Node, state: Node, actor: Node) -> void:
	var before := _estate_snapshot(state, actor)
	var events := screen.get_node("GameEvents")
	var notice: Label = ui.hud.save_notice
	ui.hud.show_dawn_notice()
	ui.campaign_hud.show_world_notice("井田 · 今早可收公田和私田", 5.0)
	events.save_finished.emit(ERR_ALREADY_IN_USE, true)
	await _frames(6)
	var bounds := notice.get_global_rect()
	print("SAVE_NOTICE_DRAW window=", screen.size, " viewport=", screen.get_visible_rect(),
		" bounds=", bounds, " lines=", notice.get_visible_line_count(), "/", notice.get_line_count())
	_expect(notice.visible and screen.get_visible_rect().grow(-8.0).encloses(bounds)
		and notice.get_theme_font_size(&"font_size") == 20 and notice.get_line_count() > 1
		and notice.get_visible_line_count() == notice.get_line_count(),
		"The full autosave warning wraps inside the safe area at the largest reading size.")
	for path in ["Calendar", "DawnNotice", "SeedBelt", "RationsButton", "Actions"]:
		var neighbor: Control = ui.hud.get_node(path)
		_expect(not bounds.intersects(neighbor.get_global_rect()), "The save warning clears " + path)
	_expect(ui.hud.dawn_notice.visible and ui.campaign_hud.notice.visible
		and not bounds.intersects(ui.campaign_hud.notice.get_global_rect())
		and not ui.hud.map_space_clear(bounds) and notice.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"The save warning adds to the HUD reservations and leaves the other messages readable.")
	var settings: Panel = ui.panel_manager.settings_panel_instance
	_expect(settings.save_button.text == "另存为封地副本" and "存档已更新" in settings.save_status.text,
		"The autosave warning makes the proposed copy action immediately available in Settings.")
	var conflict_text := notice.text
	await _capture("10-save-conflict")
	events.settings_visibility_changed.emit(true)
	events.modal_visibility_changed.emit(true)
	_expect(not notice.visible, "An open overlay covers the save notice.")
	events.settings_visibility_changed.emit(false)
	_expect(not notice.visible, "The save notice waits for both overlays to close.")
	events.modal_visibility_changed.emit(false)
	_expect(notice.visible and notice.text == conflict_text, "The same warning remains available on returning.")
	await _capture("11-save-conflict-return")
	var preferences := screen.get_node("Preferences")
	_expect(preferences.set_reading_size(0) == OK, "Change the live reading size.")
	await _frames(5)
	_expect(notice.get_theme_font_size(&"font_size") == 14
		and notice.get_global_rect().end == bounds.end and notice.text == conflict_text,
		"The existing warning fits the new reading size without moving its lower corner.")
	_expect(preferences.set_reading_size(2) == OK, "Restore the largest reading size.")

	events.save_finished.emit(ERR_FILE_UNRECOGNIZED, true)
	await _frames(5)
	_expect("自动档含新版记录" in notice.text and notice.get_visible_line_count() == notice.get_line_count()
		and screen.get_visible_rect().grow(-8.0).encloses(notice.get_global_rect()),
		"A protected newer format keeps the recovery action readable.")
	await _capture("12-save-protected")
	events.save_finished.emit(OK, false)
	await _frames(5)
	_expect("已手动保存" in notice.text and notice.visible and notice.size.x < bounds.size.x
		and notice.size.y < bounds.size.y, "A successful save replaces the warning with a compact confirmation.")
	await _capture("13-save-confirmation")
	events.settings_visibility_changed.emit(true)
	await _frames(190)
	events.settings_visibility_changed.emit(false)
	_expect(notice.visible and "已手动保存" in notice.text, "A confirmation gets its reading time after closing Settings.")
	await _frames(190)
	_expect(not notice.visible and before == _estate_snapshot(state, actor),
		"Only the confirmation times out and all game state is kept.")

func _review_combined_record(ui: Node, state: Node, actor: Node) -> void:
	var night: int = state.current_day - 1
	var work := {"day": night, "tilled": 12, "watered": 16, "harvested": 13, "sown": 11,
		"tribute": 1, "stock": 18, "copper": 102, "leaves": 9, "minutes": 96}
	state.last_dawn = {"day": night, "research_gap": 48, "tribute_penalty": 8,
		"rank_change": -1, "completed_fields": [2], "field_wait": work, "away_field": work}
	state.last_field_night = {"day": night, "public_ripe": 1, "private_ripe": 4,
		"ready": 0, "growing": 5, "dry": 3, "blocked": 2}
	state.night_rations.last = {"day": night, "need": 8, "served": 3, "used": {"millet": 1}, "bought": 2, "copper": 12,
		"missed": PackedStringArray(["渠伯", "石墨", "弋戎", "蒲宁", "季青"]), "departed": PackedStringArray(["石墨"])}
	state.raid_day = state.current_day
	var before := _estate_snapshot(state, actor)
	var notice: Control = ui.hud.dawn_notice
	ui.hud.refresh_morning_record()
	ui.hud.show_dawn_notice()
	await _frames(6)
	var result: String = notice.result_label.text
	print("COMBINED_DAWN ", result.replace("\n", " / "))
	_expect("东路来敌" in result and "研究经费未缴 · 缺 48 铜钱" in result and "欠贡 · 声望 −8" in result
		and "缺粮 5 份" in result and "1 人离任" in result,
		"An arriving threat does not hide the unpaid research, tribute, shortage or departure.")
	_expect("3 项" in ui.hud.morning_button.text and "缺粮 5 份" in ui.hud.morning_button.tooltip_text,
		"The persistent button identifies all three recorded warnings.")
	_layout(ui)
	await _capture("14-combined-dawn")

	ui.hud.morning_button.grab_focus()
	ui.hud.morning_button.pressed.emit()
	var book := ui.get_node_or_null("Control/NightRationsPanel") as Control
	await _frames(6)
	_expect(book != null and book.show_previous and book.close_button.has_focus(), "Open the complete dated receipt.")
	if not book:
		return
	print("COMBINED_MEAL ", book.receipt.text.replace("\n", " / "))
	_expect("缺 5 份" in book.receipt.text and "购粮 2 份" in book.receipt.text and "已离任 · 石墨" in book.receipt.text,
		"Buying some grain still leaves an explicit shortage beside the actual disbursements.")
	var overview := book.get_node_or_null("%RecordSummaryText") as Label
	_expect(overview != null and overview.is_visible_in_tree(), "The previous page has a fixed summary above its editable area.")
	if overview:
		var bounds := overview.get_global_rect()
		_expect("欠贡" in overview.text and "缺粮 5 份" in overview.text and "公田 1 格、私田 4 格" in overview.text
			and screen.get_visible_rect().encloses(book.window.get_global_rect())
			and overview.get_visible_line_count() == overview.get_line_count() and not book.plan_index.visible,
			"All warnings and newly ripe plots fit with the latest night record at the largest reading size.")
		await _capture("15-combined-record")
		var bar: VScrollBar = book.scroll.get_v_scroll_bar()
		_expect(bar.visible, "A long receipt remains scrollable.")
		bar.value = bar.max_value
		await _frames(6)
		_expect(book.scroll.scroll_vertical > 0 and overview.get_global_rect() == bounds,
			"The summary stays put while reading details at the bottom.")
		await _capture("16-combined-record-bottom")
		book.page_button.pressed.emit()
		await _frames(5)
		_expect(not overview.is_visible_in_tree() and book.plan_index.visible,
			"Tonight retains its own forecast and controls.")
	book.close_button.pressed.emit()
	await _frames(5)
	_expect(before == _estate_snapshot(state, actor) and ui.hud.morning_button.has_focus(),
		"Reading both pages returns to the same button with the campaign state intact.")
	state.raid_day = 0
	state.night_rations.last.day = night - 1
	ui.hud.refresh_morning_record()
	_expect("2 项" in ui.hud.morning_button.text and "缺粮" not in ui.hud.morning_button.tooltip_text,
		"An older ration receipt does not count toward last night's warnings.")
	ui.hud.morning_button.pressed.emit()
	var older := ui.get_node_or_null("Control/NightRationsPanel") as Control
	await _frames(5)
	_expect(older != null and "第 %d 夜" % (night - 1) in older.receipt.text and "缺 5 份" in older.receipt.text,
		"The older ration receipt remains readable with its own date.")
	if older:
		older.close_button.pressed.emit()
		await _frames(5)

func _review_hall(state: Node, prefs: Node) -> void:
	state.estate_room = state.EstateRoom.HALL
	state.last_dawn = {"day": state.current_day - 1}
	state.last_field_night = {}
	state.night_rations.last = {}
	_expect(prefs.set_reading_size(0) == OK, "Use the standard reading size indoors.")
	if tree.change_scene_to_file(state.ESTATE_SCENE) != OK:
		_expect(false, "Mount the paused hall.")
		return
	await tree.scene_changed
	var ui := tree.current_scene.get_node("UI")
	var room := tree.current_scene.get_node("World/HallInterior") as Node2D
	var actor: Node = ui.world.player
	await _frames(7)
	var snapshot := _estate_snapshot(state, actor)
	ui.hud.show_dawn_notice()
	await _frames(6)
	var notice: Control = ui.hud.dawn_notice
	_expect(room.visible and screen.get_camera_2d() == room.get_node("RoomCamera")
		and notice.date_label.get_theme_font_size("font_size") == 22 and not notice.result_label.visible,
		"The quiet date plaque fits the normal hall view at standard size.")
	_layout(ui)
	await _capture("09-hall")
	_expect(snapshot == _estate_snapshot(state, actor), "Opening the indoor announcement is read-only.")

func _review(scenario: SceneTree) -> void:
	tree = scenario
	screen = tree.root
	var profile := OS.get_user_data_dir()
	if not ("fiefdom-smoke-" in profile or "fiefdom-dawn-notice-" in profile):
		push_error("Use an isolated profile for the dawn announcement check.")
		tree.quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		capture_directory = args[0]
	tree.paused = true
	AudioServer.set_bus_mute(0, true)
	var state := screen.get_node("Global")
	var prefs := screen.get_node("Preferences")
	state.current_day = 1 + state.SOLAR_TERMS.find(state.balance.rain_solar_term) * state.balance.days_per_solar_term
	state.day_progress = 0.0
	state.last_dawn = {"day": state.current_day - 1, "tribute_penalty": 8}
	state.last_field_night = {"day": state.current_day - 1, "public_ripe": 1, "private_ripe": 4,
		"ready": 0, "growing": 0, "dry": 0, "blocked": 0}
	_expect(prefs.set_reading_size(2) == OK, "Use the largest reading size.")
	if tree.change_scene_to_file(state.ESTATE_SCENE) != OK:
		tree.quit(1)
		return
	await tree.scene_changed
	var ui := tree.current_scene.get_node("UI")
	var actor := tree.current_scene.get_node("World").player as Node
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	await _frames(7)
	_expect(ui.hud.dawn_notice.date_label.get_theme_font_size("font_size") == 28
		and ui.hud.dawn_notice.result_label.get_theme_font_size("font_size") == 23, "Both text lines scale with the reading setting.")
	await _review_reveal(ui, state, actor)
	await _review_results(ui, state, actor)
	await _review_world_notice(ui)
	await _review_save_notice(ui, state, actor)
	await _review_combined_record(ui, state, actor)
	await _review_hall(state, prefs)
	_expect(tree.paused and state.saved_games().is_empty() and state.day_progress == 0.0,
		"Presentation checks keep the world paused and write no game saves.")
	if not failed:
		print("DAWN_NOTICE_VIEWS_OK paused=true saves=0 window=", screen.size)
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
