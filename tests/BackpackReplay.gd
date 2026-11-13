extends RefCounted

var tree: SceneTree
var captures: String
var failures := 0

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		push_error(message)
	return condition

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame
	await tree.process_frame

func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	tree.root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame
	await tree.process_frame

func _capture(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(captures.path_join(name + ".png")) == OK, "Capture " + name)

func _quit() -> void:
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)

func run(host: SceneTree, directory := "") -> void:
	tree = host
	captures = directory
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated backpack profile."):
		_quit()
		return
	tree.change_scene_to_file(Global.TITLE_SCENE)
	await tree.scene_changed
	tree.root.notify_mouse_entered()
	await tree.process_frame
	await _click(tree.current_scene.new_button.get_global_rect().get_center())
	if tree.current_scene == null:
		await tree.scene_changed
	var hud := tree.current_scene.get_node("CampaignHUD")
	var estate_ui := tree.current_scene.get_node("UI")
	await _click(hud.backpack_button.get_global_rect().get_center())
	if not _expect(tree.paused and hud.backpack != null and hud.backpack.items.get_child_count() == 0,
		"The visible estate shortcut opens an empty backpack and pauses the scene."):
		_quit()
		return
	await _capture("01-empty-backpack")
	var paused_watch := Global.day_progress
	await tree.create_timer(0.25).timeout
	_expect(Global.day_progress == paused_watch, "Reading inventory leaves the world clock paused.")
	await _key(KEY_ESCAPE)
	_expect(not tree.paused and hud.backpack == null and not estate_ui.panel_manager.settings_panel_instance.visible,
		"Escape closes only the backpack and restores play.")
	await _key(KEY_M)
	await _key(KEY_I)
	_expect(tree.paused and (estate_ui.estate_map.modal.visible or estate_ui.estate_map.region_map.modal.visible)
		and hud.backpack == null,
		"An already open map keeps focus when the backpack key is pressed.")
	await _key(KEY_ESCAPE)

	# Seed a saved mid-campaign stock to cover the separate stores through one panel.
	Global.crop_stock.add("millet", 3)
	Global.crop_stock.add(CropStock.MIXED, 2)
	Global.king_storage = 8
	Global.money = 27
	Global.fish_collection["carp"] = {"first_day": 1, "first_site": CreekFish.Site.SHOAL, "stock": 2}
	Global.fish_collection["crucian"] = {"first_day": 1, "first_site": CreekFish.Site.POOL, "stock": 0}
	Global.silk_workshop.bolts = 1
	Global.silk_workshop.leaves = 4
	Global.sheepfold.bought_day = Global.current_day
	Global.sheepfold.wool = 3
	Global.travel_meal = TravelMeal.WHEAT_CAKE
	Global.current_stamina = Global.max_stamina - 30
	_expect(Global.save_game() == OK, "Write the current inventory using the standard save format.")
	tree.change_scene_to_file(Global.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _click(tree.current_scene.continue_button.get_global_rect().get_center())
	if tree.current_scene == null:
		await tree.scene_changed
	hud = tree.current_scene.get_node("CampaignHUD")
	await _key(KEY_I)
	var bag: Control = hud.backpack
	if not _expect(is_instance_valid(bag), "I opens the backpack after Continue."):
		_quit()
		return
	_expect(bag.items.has_node("millet") and bag.items.has_node("mixed") and bag.items.get_child_count() == 2
		and "27" in bag.wallet.text and "麦饼" in bag.meal_name.text,
		"The loaded backpack shows private lots, older mixed grain, money and a packed meal.")
	_expect(bag.items.get_node("millet").find_child("Quantity", true, false).text == "3 份",
		"The private crop's stack shows the exact quantity.")
	await _capture("02-private-crops")
	await _click(bag.fish_tab.get_global_rect().get_center())
	_expect(bag.items.has_node("carp") and bag.items.get_child_count() == 1,
		"The fish page shows what remains in stock, including no entry for an already spent fish.")
	await _capture("03-fish")
	await _click(bag.craft_tab.get_global_rect().get_center())
	_expect(bag.items.has_node("wool") and bag.items.get_child_count() == 3, "Silk and wool share the workshop stock page.")
	await _capture("04-materials")
	var stamina_before := Global.current_stamina
	await _click(bag.eat_button.get_global_rect().get_center())
	_expect(Global.travel_meal.is_empty() and Global.current_stamina == stamina_before + Global.balance.wheat_cake_stamina
		and not bag.eat_button.visible, "Eating uses the existing road meal and immediately clears the slot.")
	await _key(KEY_I)
	_expect(not tree.paused and hud.backpack == null, "I also closes the backpack.")

	for scene in [Global.WEST_ROAD_SCENE, Global.WEST_MARKET_SCENE, Global.WILDERNESS_SCENE]:
		tree.change_scene_to_file(scene)
		await tree.scene_changed
		hud = tree.current_scene.get_node("CampaignHUD")
		if scene == Global.WEST_MARKET_SCENE:
			var map_button: Button = tree.current_scene.market_map.open_button
			_expect(not hud.backpack_button.get_global_rect().intersects(map_button.get_global_rect()),
				"The backpack and market map both have unobstructed buttons.")
		await _click(hud.backpack_button.get_global_rect().get_center())
		if _expect(hud.backpack != null and tree.paused, "The backpack is available on " + scene):
			if scene == Global.WILDERNESS_SCENE:
				for step in 5:
					await _key(KEY_TAB)
					_expect(hud.backpack.is_ancestor_of(tree.root.gui_get_focus_owner()),
						"Tab stays inside the backpack above the ravine settings and map controls.")
			await _key(KEY_ESCAPE)
			_expect(hud.backpack == null and not tree.paused and not tree.current_scene.settings.visible,
				"Escape closes the backpack without opening the local settings.")
	print("BACKPACK_STOCK crop=", Global.crop_stock.count("millet"), " fish=", Global.fish_count("carp"),
		" wool=", Global.sheepfold.wool, " meal_used=", Global.travel_meal.is_empty())
	_quit()
