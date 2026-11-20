extends SceneTree

var failed := false

func _initialize() -> void:
	_check.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _check() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		push_error("Run the night book check with an isolated profile.")
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	var items := root.get_node("ItemManager")
	var cell := Vector2i(5, 5)
	state.well_fields.assign([{"field_id":0, "center_pos":cell, "is_unlocked":true, "reclamation_progress":4}])
	var scene := load("res://scenes/NightRationsPanel.tscn") as PackedScene
	var plan = scene.instantiate()
	root.add_child(plan)
	plan._show_page(true)
	_expect(not plan.show_previous and not plan.page_button.visible and plan.plan_index.visible
		and plan.page_art.region.position.x == 0,
		"The first evening has no previous page.")
	_expect(plan.tribute_plot.visible and not plan.tribute_plot.crop_region.has_area(),
		"The suggested seed must not appear as a plant on an empty public plot.")
	var before := [state.current_day, state.day_progress, state.money, state.food_storage, state.current_stamina]
	for id: String in items.crops:
		var crop: CropData = items.get_crop(id)
		for stage in 3:
			state.active_crops[cell] = {"data":crop, "id":id, "age":stage, "growth_nights":2,
				"watered":false, "requires_channel":crop.is_water_crop}
			var field: Dictionary = state.tribute_field_plan()
			plan.tribute_plot.show_plot(field)
			var expected := Vector2i(stage, CropData.IDS.find(id))
			_expect(plan.tribute_plot.crop_region == items.crop_atlas.get_tile_texture_region(expected)
				and plan.tribute_plot.status == field.status, "Incorrect field picture for %s stage %d." % [id, stage])
	_expect(before == [state.current_day, state.day_progress, state.money, state.food_storage, state.current_stamina],
		"Opening a field picture changed the estate.")
	state.current_day = 2
	state.night_rations.last = {"day":1, "need":1, "served":1, "used":{}, "bought":0, "copper":0}
	var morning = scene.instantiate()
	morning.show_previous = true
	root.add_child(morning)
	_expect(morning.page_art.region.position.x == 64 and plan.page_art.region.position.x == 0,
		"The two open books must not share a mutable atlas region.")
	_expect(morning.page_date.text.begins_with("第 1 夜") and not morning.plan_index.visible
		and morning.get_node("%RecordedMeal").visible
		and not morning.get_node("%ReceiptDivider").visible and not morning.get_node("%RecordedFields").visible,
		"A meal-only record must use its saved night and a single column.")
	morning._show_page(false)
	_expect(morning.page_date.text.begins_with("第 2 夜") and morning.record_heading.is_visible_in_tree()
		and morning.record_heading.text.ends_with("第 1 夜"), "Tonight and the inline receipt need separate dates.")
	state.night_rations.last = {}
	state.last_dawn = {"day":1}
	morning._refresh()
	morning._show_page(true)
	_expect(morning.get_node("%EmptyRecord").is_visible_in_tree() and not morning.get_node("%Entries").visible,
		"A saved night with no entries should open a readable record.")
	morning.free()
	plan.free()
	await _check_index(state, scene, cell)
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_index(state: Node, scene: PackedScene, cell: Vector2i) -> void:
	var items := root.get_node("ItemManager")
	state.days_without_contribution = state.balance.no_contribution_threshold - 1
	state.food_storage = 1
	state.money = 3 * state.balance.market_food_price
	var retainer_data: GDScript = state.retainers[0].get_script()
	for person in ["石墨", "季青", "蒲宁"]:
		var worker: Resource = retainer_data.new(person)
		worker.loyalty = 20.0
		state.retainers.append(worker)
	state.active_crops[cell] = {"data": items.get_crop("millet"), "id": "millet", "age": 1,
		"growth_nights": 2, "watered": false, "requires_channel": false}
	var before := [state.current_day, state.money, state.food_storage, state.night_rations.enabled]
	var book = scene.instantiate()
	book.focus_shortage = true
	root.add_child(book)
	await _settle()
	var prefs := root.get_node("Preferences")
	var targets: Array[Node] = [book.title, book.tribute_section, book.tribute_details, book.accept_offer,
		book.receipt, book.budget.get_line_edit(), book.priority_picker.get_popup()]
	var standard := targets.map(func(target: Node) -> int: return target.get_theme_font_size("font_size"))
	for reading_size in [1, 2]:
		_expect(prefs.set_reading_size(reading_size) == OK, "Update the isolated reading size.")
		await _settle()
		for index in targets.size():
			_expect(targets[index].get_theme_font_size("font_size") == standard[index] + 3 * reading_size,
				"The night book's headings, details, actions, editor and popup use the selected size.")
		_expect(book.accept_offer.has_focus()
			and book.scroll.get_global_rect().encloses(book.accept_offer.get_global_rect()),
			"The focused offer stays in the scroller after resizing the text.")
	var viewport := root.get_visible_rect()
	var strip: Rect2 = book.plan_index.get_global_rect()
	_expect(book.tribute_section.text == "首贡 · 今夜到期" and book.field_section.text == "田务 · 1 格缺水"
		and book.rations_section.text == "口粮 · 缺 3 份" and viewport.encloses(strip),
		"Tonight's index shows all three urgent summaries in the window.")
	_expect(viewport.encloses(book.window.get_global_rect()) and viewport.encloses(book.get_node("%Sleep").get_global_rect()),
		"The largest reading size keeps the whole sheet and footer in the viewport.")
	_expect(book.accept_offer.has_focus()
		and book.scroll.get_global_rect().encloses(book.accept_offer.get_global_rect()),
		"Opening from a shortage focuses the available offer in view.")
	book.tribute_section.pressed.emit()
	await _settle()
	_expect(book.find_tribute.has_focus()
		and book.scroll.get_global_rect().encloses(book.tribute_plan.get_global_rect()),
		"The tribute jump returns to the due date and focuses the plot directions.")
	book.field_section.pressed.emit()
	await _settle()
	_expect(book.find_plot.has_focus()
		and book.scroll.get_global_rect().encloses(book.field_warning.get_global_rect()),
		"The field jump presents the water warning and focuses the nearby action.")
	book.rations_section.pressed.emit()
	await _settle()
	_expect(book.accept_offer.has_focus() and strip == book.plan_index.get_global_rect(),
		"The ration jump returns to the offer and the three summaries stay in place.")
	_expect(before == [state.current_day, state.money, state.food_storage, state.night_rations.enabled],
		"Changing sections does not carry out any night action.")
	book.free()

func _settle() -> void:
	for frame in 5:
		await process_frame
