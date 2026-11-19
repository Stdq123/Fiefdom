extends SceneTree

var failed := false

func _initialize() -> void:
	review.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)

func review() -> void:
	var state = root.get_node("Global")
	var panel = load("res://scenes/EventPanel.tscn").instantiate()
	root.add_child(panel)
	var reform: int = state.TaxReformChoice.REFORMED
	var tribute: int = state.TaxReformChoice.TRADITIONAL
	var research: int = state.TaxReformChoice.DELAYED
	var cells := {reform: 0, tribute: 1, research: 2}
	# Changing the number and order of policies must keep each illustration on its own choice.
	for order: Array in [[reform, tribute, research], [tribute, reform]]:
		var rows := []
		for choice: int in order:
			rows.append({"choice_type": choice, "text": str(choice), "levy": "", "harvest": "",
				"household": "", "heading": "", "detail": ""})
		panel.setup({"title": "", "speaker": "", "text": "", "ledger": "", "choices": rows})
		check(panel.option_buttons.size() == order.size(), "Available choices")
		for choice: int in order:
			var picture: AtlasTexture = panel.option_buttons[choice].icon
			check(picture != null and picture.atlas != null and picture.atlas.get_size() == Vector2(432, 68)
				and picture.region == Rect2(cells[choice] * 144, 0, 144, 68), "Council illustration %d" % choice)
	var original: Dictionary = state.ending_record
	for outcome: int in [state.Outcome.TRADITIONAL, state.Outcome.REFORMED]:
		var choice := tribute if outcome == state.Outcome.TRADITIONAL else reform
		state.ending_record = {"outcome": outcome, "accounts": [{"label": "国库", "value": 1}],
			"memories": [], "date": ""}
		var archive = load("res://scenes/EstateEnding.tscn").instantiate()
		root.add_child(archive)
		archive.open_archive()
		var book: AtlasTexture = archive.volume_icon.texture
		var chosen: AtlasTexture = panel.option_buttons[choice].icon
		check(book != null and book.atlas == chosen.atlas and book.region == chosen.region,
			"Archive remembers the book chosen at council")
		check(archive.estate_name.text == state.campaign_name and archive.account_title.text == "封地账目"
			and not archive.account_key.visible, "An older archive identifies its estate and uses stock totals.")
		archive.free()
	await _check_readable_record(state)
	state.ending_record = original
	var dialog = load("res://scripts/UIDialogManager.gd")
	var sealed := load(dialog.TRIBUTE_RECEIPT) as Texture2D
	var open_basket := load(dialog.PRIVATE_HARVEST) as Texture2D
	check(sealed != null and open_basket != null and sealed != open_basket
		and sealed.get_size() == Vector2(96, 96) and open_basket.get_size() == Vector2(96, 96),
		"Public and private harvest portraits")
	panel.free()
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_readable_record(state: Node) -> void:
	var preferences := root.get_node("Preferences")
	var old_name: String = state.campaign_name
	var old_size: int = preferences.reading_size
	state.campaign_name = "竹涧南路碧水西桥井田谷仓封地札记"
	preferences.reading_size = 2
	var record_date := "第 2 年 · 雨水   第 59 天 · 上士"
	state.ending_record = {"outcome": state.Outcome.REFORMED, "date": record_date,
		"accounts": [{"label": "现有铜钱", "value": 2147483647, "target": 1200}],
		"memories": ["村人沿旧渠修好木桥，又去西市把茶、米和布送到摊前。".repeat(12)],
		"farewell": {"speaker": "渠伯", "line": "明早提上旧桶，在田边见。"}}
	var ending = load("res://scenes/EstateEnding.tscn").instantiate()
	root.add_child(ending)
	ending._populate_record()
	ending._show_record()
	for frame in 10:
		await process_frame
	var viewport := root.get_visible_rect().grow(-15.0)
	var actions: Rect2 = ending.report_footer.get_global_rect()
	var title: Rect2 = ending.report_header.get_global_rect()
	var scroll: ScrollContainer = ending.report_scroll
	check(viewport.encloses(ending.report_panel.get_global_rect()) and viewport.encloses(actions)
		and viewport.encloses(title), "A large ending keeps its header and footer inside the window.")
	check(ending.estate_name.text == state.campaign_name and ending.date.text == record_date
		and ending.account_key.visible and ending.account_title.text == "路线结算",
		"The route report uses the saved date and shows the estate and totals key.")
	check(ending.memories.get_child(0).get_theme_font_size(&"font_size") == 23
		and ending.caption.get_theme_font_size(&"font_size") == 24, "Ending prose follows the reading setting.")
	check(scroll.get_v_scroll_bar().visible and ending.continue_button.has_focus(), "The long report can be read or left.")
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_PAGEDOWN
		key.pressed = pressed
		root.push_input(key, true)
	for frame in 4:
		await process_frame
	check(scroll.scroll_vertical > 0 and title == ending.report_header.get_global_rect()
		and actions == ending.report_footer.get_global_rect() and ending.continue_button.has_focus(),
		"Page Down reads the body while the heading, actions and focus stay in place.")
	ending.free()
	state.campaign_name = old_name
	preferences.reading_size = old_size
