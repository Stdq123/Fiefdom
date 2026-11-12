extends "res://tests/RavineMapReplay.gd"

const POOL := CreekFish.Site.POOL
const SHOAL := CreekFish.Site.SHOAL

var captures := ""

func _capture(name: String) -> void:
	if captures.is_empty():
		return
	await tree.create_timer(0.20).timeout
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(captures.path_join(name + ".png")) == OK, "Capture " + name)
	print("TRAP_FRAME ", name, " window=", tree.root.size, " image=", frame.get_size())

func _enter_ravine() -> bool:
	var farmer := tree.current_scene.get_node("World/Player") as Node2D
	await Campaign.walk_to(tree, farmer, Vector2(359, 4))
	await _move(&"ui_right", 36)
	return _bind_ravine()

func _go_to(place: String) -> bool:
	if not await _select_place(place):
		return false
	await _key(KEY_ESCAPE)
	return await _walk_route()

func _home() -> bool:
	if not await _select_place("西门回封地"):
		return false
	await _key(KEY_ESCAPE)
	return await _walk_route(true)

func _line(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = pressed
	tree.root.push_input(event, true)

func _first_fish() -> bool:
	if not await _go_to("柳湾"):
		return false
	await _key(KEY_E)
	var rod := ravine.get_node_or_null("FishingUI/FishingPanel") as Control
	if not _expect(rod != null and tree.paused, "Use the actual fishing rod before either basket opens."):
		return false
	while rod.phase == rod.Phase.WAITING:
		await tree.process_frame
	_line(true)
	for frame in 360:
		await tree.process_frame
		if rod.phase != rod.Phase.REELING:
			break
		if rod.holding and rod.tension > 0.62:
			_line(false)
		elif not rod.holding and rod.tension < 0.43:
			_line(true)
	_line(false)
	var landed := _expect(state.fish_count("minnow") == 1 and state.last_forage_day == 35 and state.creek_traps_unlocked(),
		"A real second-year catch opens both bank stakes.")
	await _key(KEY_ESCAPE)
	return landed

func _at_stake(site: int) -> Control:
	await _key(KEY_E)
	await tree.process_frame
	var panel := ravine.get_node("FishingUI/CreekTrapPanel") as Control
	if not _expect(panel.modal.visible and panel.site == site and tree.paused,
		"E at %s opens its own basket." % CreekTrap.PLACES[site]):
		return null
	return panel

func _set_summer_trap() -> bool:
	await _key(KEY_M)
	await tree.process_frame
	_expect(_layout_fits(), "Both basket pins fit beside the fishing markers at this window size.")
	await _click(map.markers[CreekTrap.PLACES[SHOAL]])
	var stand := ravine.get_node("ShoalTrap") as Node2D
	if not _expect(guide.destination == stand.position and stand.can_interact_from(stand.to_global(stand.stake_offset)),
		"The chart guides to the dry approach, and the stake can also be used in reach."):
		return false
	await _key(KEY_ESCAPE)
	if not await _walk_route():
		return false
	var panel := await _at_stake(SHOAL)
	if panel == null:
		return false
	_expect(panel.baits.millet.forecast.text.contains("36 天 · 鲤鱼 1 尾") and panel.baits.beans.forecast.text.contains("37 天 · 鳜鱼 2 尾"),
		"The two baits forecast different results across the summer-to-autumn boundary.")
	await _capture("01-bait-forecast")
	var stamina: int = state.current_stamina
	await _click(panel.baits.beans.button)
	if not _expect(state.creek_trap_site() == SHOAL and state.crop_stock.count("beans") == 0 and state.crop_stock.count("millet") == 1
		and state.current_stamina == stamina and panel.take_button.disabled,
		"Setting the basket spends exactly one bean, leaves stamina alone and requires two nights."):
		return false
	await _key(KEY_ESCAPE)
	await _capture("02-shoal-basket")
	print("TRAP_SET day=", state.current_day, " due=", state.creek_trap_catch().day, " bait=beans")
	return await _home()

func _save_and_sleep() -> bool:
	var ui := tree.current_scene.get_node("UI")
	var estate_map: Control = ui.estate_map
	await _key(KEY_M)
	await _click(estate_map.tabs.get_node("Ravine"))
	var row: Button
	for button in estate_map.row_buttons:
		if estate_map.row_buttons[button].title == CreekTrap.PLACES[SHOAL]:
			row = button
	if not _expect(row != null and row.tooltip_text.contains("37 天可收"), "The estate map shows when the shoal basket can be retrieved."):
		return false
	estate_map.scroll.ensure_control_visible(row)
	await tree.process_frame
	await _click(row)
	await _key(KEY_ESCAPE)
	if not _expect(state.ravine_trip_target == CreekTrap.PLACES[SHOAL] and state.save_game() == OK, "Save the planned trip and soaking basket together."):
		return false
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _click(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	ui = tree.current_scene.get_node("UI")
	_expect(state.creek_trap_site() == SHOAL and state.crop_stock.count("beans") == 0
		and state.ravine_trip_target == CreekTrap.PLACES[SHOAL], "Resume the same basket, spent bait and route.")
	await _night()
	_expect(state.current_day == 36 and state.take_creek_trap(SHOAL).is_empty(), "One night is too early for bean bait.")
	await _night()
	return _expect(state.current_day == 37 and state.creek_trap_catch().fish == "perch", "The same basket is ready as autumn starts.")

func _night() -> void:
	await _click(tree.current_scene.get_node("UI").sleep_button)
	await tree.create_timer(1.18).timeout

func _collect_after_fruit() -> bool:
	if not await _enter_ravine():
		return false
	_expect(guide.destination_name == CreekTrap.PLACES[SHOAL], "The gate continues the estate's saved basket route.")
	if not await _go_to("野果坳"):
		return false
	var food: int = state.food_storage
	await _key(KEY_E)
	_expect(state.last_forage_day == 37 and state.food_storage == food + state.balance.wild_food_yield, "Gather the actual wild fruit first.")
	if not await _go_to(CreekTrap.PLACES[POOL]):
		return false
	var remote := await _at_stake(POOL)
	if not _expect(remote != null and not remote.options.visible and remote.guide_button.visible,
		"The west stake directs the player to the existing east basket."):
		return false
	await _click(remote.guide_button)
	await _key(KEY_M)
	_expect(map.trap_button.visible and map.trap_button.text.contains("可收") and guide.destination == ravine.get_node("ShoalTrap").position,
		"The local map highlights the ready basket and its actual shoreline route.")
	await _capture("03-ready-on-map")
	await _key(KEY_ESCAPE)
	if not await _walk_route():
		return false
	var panel := await _at_stake(SHOAL)
	if panel == null:
		return false
	await _capture("04-ready-to-collect")
	await _click(panel.take_button)
	if not _expect(panel.receipt.visible and panel.baits.beans.button.disabled and state.fish_count("perch") == 2 and state.last_forage_day == 37
		and state.creek_trap_site() == -1 and state.take_creek_trap(SHOAL).is_empty(),
		"The catch is paid once, even after that day's fruit is gathered."):
		return false
	await _capture("05-perch-collected")
	await _key(KEY_ESCAPE)
	print("TRAP_COLLECT day=", state.current_day, " perch=", state.fish_count("perch"), " forage_day=", state.last_forage_day)
	return true

func _try_other_bank() -> void:
	if not await _go_to(CreekTrap.PLACES[POOL]):
		return
	var panel := await _at_stake(POOL)
	if panel == null:
		return
	await _click(panel.baits.millet.button)
	_expect(state.creek_trap_site() == POOL and state.creek_trap_catch().day == 38 and state.crop_stock.count("millet") == 0,
		"Reuse the same basket with millet at the west bank for one night.")
	await _key(KEY_ESCAPE)
	if not await _home():
		return
	await _night()
	if not await _enter_ravine() or not await _go_to(CreekTrap.PLACES[POOL]):
		return
	panel = await _at_stake(POOL)
	if panel == null:
		return
	await _click(panel.take_button)
	_expect(state.current_day == 38 and state.fish_count("crucian") == 1 and state.last_forage_day == 37,
		"One night of millet bait yields one fish without taking the new day's forage slot.")
	print("TRAP_REUSE day=", state.current_day, " crucian=", state.fish_count("crucian"), " forage_day=", state.last_forage_day)
	await _key(KEY_ESCAPE)
	if await _home():
		await _serve_caught_fish()

func _serve_caught_fish() -> void:
	var ui := tree.current_scene.get_node("UI")
	await _click(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	management.tabs.current_tab = 1
	await tree.process_frame
	await _click(management.market_panel.fish_book_button)
	var ledger: Control = management.fish_ledger
	var food: int = state.food_storage
	var perch: Dictionary = ledger.rows.perch
	await _click(perch.food)
	_expect(state.food_storage == food + CreekFish.SPECIES.perch.food and state.fish_count("perch") == 1,
		"The basket's fish can be turned into provisions through the real fish ledger.")
	await _capture("06-fish-to-rations")
	print("TRAP_RATIONS day=", state.current_day, " food_added=", state.food_storage - food)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated profile for the basket replay."):
		tree.quit(1)
		return
	seed(650)
	tree.root.notify_mouse_entered()
	captures = OS.get_environment("FIEFDOM_TRAP_CAPTURES")
	state = tree.root.get_node("Global")
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _click(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await tree.process_frame
	# Stage the seasonal date, Pu Ning introduction and two private crops for bait.
	state.current_day = 35
	state.talk_to_visitor(VisitorData.RAVINE_GUIDE)
	state.crop_stock.add("millet", 1)
	state.crop_stock.add("beans", 1)
	if await _enter_ravine():
		_expect(not ravine.get_node("PoolTrap").visible, "The stake is hidden before the first fish.")
		if await _first_fish() and await _set_summer_trap() and await _save_and_sleep() and await _collect_after_fruit():
			await _try_other_bank()
	tree.paused = false
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
