extends SceneTree

var failed := false

func _initialize() -> void:
	review.call_deferred()

func expect(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		push_error(description)

func check_sheet(path: String, count: int, cell: int) -> void:
	var texture := load(path) as Texture2D
	var logical := Vector2(count * cell, cell)
	expect(texture.get_size() == logical, path + " logical frame size")
	expect("pixels" in texture and texture.get("pixels").get_size() == logical * 2.0, path + " artwork density")
	var pixels := Image.new()
	expect(pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK, path + " original pixels")
	var frames := {}
	for i in count:
		var region := pixels.get_region(Rect2i(i * cell * 2, 0, cell * 2, cell * 2))
		expect(region.get_used_rect().has_area(), path + " visible cell " + str(i))
		frames[hash(region.get_data())] = true
	expect(frames.size() == count, path + " distinct drawings")

func review() -> void:
	var state := root.get_node("Global")
	var events := root.get_node("GameEvents")
	var initial: Array = [state.current_day, state.day_progress, state.current_stamina, state.health,
		state.money, state.food_storage, hash(state.crop_stock.lots)]
	check_sheet("res://assets/ui/hud-symbols.png", 23, 16)
	check_sheet("res://assets/ui/watch-dial.png", 1, 48)
	check_sheet("res://assets/inventory/estate-goods.png", 7, 32)
	check_sheet("res://assets/inventory/crop-harvests.png", CropData.IDS.size(), 32)
	check_sheet("res://assets/world/creek-fish.png", 4, 16)
	check_sheet("res://assets/world/travel-meals.png", 3, 32)

	var icons = load("res://scripts/HUDIcons.gd")
	var bag = load("res://scenes/Backpack.tscn").instantiate()
	root.add_child(bag)
	for index in CropData.IDS.size():
		var crop: String = CropData.IDS[index]
		var symbol: int = icons.CROPS[crop]
		var slot: AtlasTexture = icons.icon(symbol)
		var harvest: AtlasTexture = bag._stored_crop_icon(index)
		expect(slot.region == Rect2(16 * symbol, 0, 16, 16), "Seed belt frame " + crop)
		expect(harvest.atlas.resource_path == "res://assets/inventory/crop-harvests.png"
			and harvest.region == Rect2(index * 32, 0, 32, 32) and harvest.filter_clip, "Harvest sprite " + crop)
	expect(bag._stored_crop_icon(CropData.IDS.size()).atlas == load("res://assets/inventory/estate-goods.png"), "Older mixed grain still has a sack")
	var fish = load("res://scripts/CreekFish.gd")
	for i in fish.IDS.size():
		expect(fish.portrait(fish.IDS[i]).region == Rect2(16 * i, 0, 16, 16), "Fish frame " + fish.IDS[i])
	var meals = load("res://scripts/TravelMeal.gd")
	for meal: String in meals.RECIPES:
		expect(meals.icon(meal).region == Rect2(32 * meals.RECIPES[meal].frame, 0, 32, 32), "Dish " + meal)
	var starting_stock: Dictionary = state.crop_stock.lots.duplicate()
	state.crop_stock.lots.clear()
	bag._refresh_items()
	for frame in 3:
		await process_frame
	var empty_slots: Array[Node] = bag.items.get_children()
	expect(empty_slots.size() == CropStock.IDS.size(), "All stock positions have exactly one pocket")
	var empty_bounds: Array[Rect2] = []
	for slot: Control in empty_slots:
		empty_bounds.append(slot.get_global_rect())
	state.crop_stock.add("millet", 3)
	state.crop_stock.add(CropStock.MIXED, 17850)
	bag._refresh_items()
	for frame in 3:
		await process_frame
	var first := bag.items.get_node_or_null("millet") as Control
	var legacy := bag.items.get_node_or_null(CropStock.MIXED) as Control
	expect(first != null and legacy != null and first.get_index() == 0
		and legacy.get_index() == empty_slots.size() - 1, "Private crops follow seed order with a pocket for older mixed grain")
	for index in empty_bounds.size():
		var slot := bag.items.get_child(index) as Control
		expect(slot == empty_slots[index] and slot.get_global_rect() == empty_bounds[index], "Stock changes keep pocket position %d" % index)
	if legacy != null:
		var amount := legacy.find_child("Quantity", true, false) as Label
		expect(amount.is_visible_in_tree() and amount.text == "17850 份"
			and amount.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Large quantities are right aligned and fully shown")
	state.crop_stock.lots.erase("millet")
	bag._refresh_items()
	for frame in 3:
		await process_frame
	expect(not bag.items.has_node("millet") and empty_slots[0].get_global_rect() == empty_bounds[0],
		"The pocket returns to empty without changing its footprint")
	state.crop_stock.lots.assign(starting_stock)
	bag.free()

	var meters = load("res://scenes/HUDVitals.tscn").instantiate()
	root.add_child(meters)
	await process_frame
	var width: float = meters.size.x
	var maximum: int = state.balance.player_max_health
	events.health_changed.emit(maximum)
	expect(not meters.get_node("%HealthWarning").visible and meters.health_bar.value == maximum, "Full health")
	events.health_changed.emit(1)
	expect(meters.get_node("%HealthWarning").visible and meters.get_node("%HealthWarning").text == "偏低"
		and meters.health_bar.value == 1 and is_equal_approx(meters.health_bar._trace, 1.0),
		"The actual health and the short previous-fill trace are distinct.")
	meters.health_bar._motion.custom_step(1.0)
	expect(is_equal_approx(meters.health_bar._trace, meters.health_bar.ratio), "The loss trace settles to the real value.")
	events.health_changed.emit(maximum)
	expect(meters.health_bar.value == maximum and meters.health_bar._trace < meters.health_bar.ratio,
		"Recovery shows the new value immediately and highlights the portion regained.")
	events.stamina_changed.emit(0)
	expect(meters.get_node("%StaminaWarning").text == "已尽" and meters.stamina_bar.value == 0, "Empty stamina")
	await process_frame
	expect(is_equal_approx(meters.size.x, width), "Warnings do not move the gauge ends.")
	events.stamina_changed.emit(state.max_stamina)
	expect(not meters.get_node("%StaminaWarning").visible and meters.stamina_bar.value == state.max_stamina, "Recovered reading")
	meters.free()

	var heading = load("res://scenes/TravelHeading.tscn").instantiate()
	heading.place_name = "溪桥道"
	root.add_child(heading)
	var dial = heading.get_node("WatchDial")
	expect(heading.get_node("Place").text == "溪桥道" and dial.compact, "Travelling dial belongs to its place")
	for i in state.DAY_WATCHES.size():
		dial.show_watch(state.DAY_WATCHES[i] + "时")
		expect(dial.watch == i, "Watch position " + str(i))
	state.day_progress = 0.84
	events.daylight_changed.emit()
	expect(dial.watch == state.DAY_WATCHES.find(state.day_watch_label().left(1)), "Clock reacts to the same daylight signal")
	expect(heading.get_node("%WeatherIcon").texture == icons.icon(icons.SKY[icons.sky_index()]), "Weather and time match")
	state.day_progress = initial[1]
	heading.free()
	expect(initial == [state.current_day, state.day_progress, state.current_stamina, state.health, state.money,
		state.food_storage, hash(state.crop_stock.lots)], "HUD readings leave the estate intact")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
