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
	check_sheet("res://assets/world/creek-fish.png", 4, 16)
	check_sheet("res://assets/world/travel-meals.png", 3, 32)

	var icons = load("res://scripts/HUDIcons.gd")
	var bag = load("res://scenes/Backpack.tscn").instantiate()
	root.add_child(bag)
	for crop: String in icons.CROPS:
		var symbol: int = icons.CROPS[crop]
		var slot: AtlasTexture = icons.icon(symbol)
		expect(slot == bag._stored_crop_icon(crop) and slot.region == Rect2(16 * symbol, 0, 16, 16),
			"The bag and seed belt show the same " + crop)
	expect(bag._stored_crop_icon("mixed").atlas == bag.goods_art, "Older mixed grain still has a sack")
	var fish = load("res://scripts/CreekFish.gd")
	for i in fish.IDS.size():
		expect(fish.portrait(fish.IDS[i]).region == Rect2(16 * i, 0, 16, 16), "Fish frame " + fish.IDS[i])
	var meals = load("res://scripts/TravelMeal.gd")
	for meal: String in meals.RECIPES:
		expect(meals.icon(meal).region == Rect2(32 * meals.RECIPES[meal].frame, 0, 32, 32), "Dish " + meal)
	bag.free()

	var meters = load("res://scenes/HUDVitals.tscn").instantiate()
	root.add_child(meters)
	var maximum: int = state.balance.player_max_health
	events.health_changed.emit(maximum)
	expect(not meters.get_node("%HealthWarning").visible and meters.health_bar.value == maximum, "Full health")
	events.health_changed.emit(1)
	expect(meters.get_node("%HealthWarning").visible and meters.get_node("%HealthWarning").text == "偏低", "Low health")
	events.stamina_changed.emit(0)
	expect(meters.get_node("%StaminaWarning").text == "已尽" and meters.stamina_bar.value == 0, "Empty stamina")
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
