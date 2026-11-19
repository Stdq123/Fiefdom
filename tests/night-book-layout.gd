extends SceneTree

var failed := false

func _initialize() -> void:
	_check.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _check() -> void:
	paused = true
	var state := root.get_node("Global")
	var items := root.get_node("ItemManager")
	var cell := Vector2i(5, 5)
	state.well_fields.assign([{"field_id":0, "center_pos":cell, "is_unlocked":true, "reclamation_progress":4}])
	var scene := load("res://scenes/NightRationsPanel.tscn") as PackedScene
	var plan = scene.instantiate()
	root.add_child(plan)
	plan._show_page(true)
	_expect(not plan.show_previous and not plan.page_button.visible and plan.page_art.region.position.x == 0,
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
	_expect(morning.page_date.text.begins_with("第 1 夜") and morning.get_node("%RecordedMeal").visible
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
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
