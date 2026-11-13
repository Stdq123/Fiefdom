extends Node

const TITLE := "res://scenes/Title.tscn"
const ESTATE := "res://scenes/Main.tscn"
const CROP := Vector2i(6, 5)

var state: Node
var capture_directory := ""

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if OS.is_debug_build() or not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("ReleaseReplay requires a non-debug export and an isolated player profile.")
		get_tree().quit(1)
		return
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		_fail("A release replay name is required.")
		return
	if arguments.size() > 1:
		capture_directory = arguments[1]
	var tree := get_tree()
	tree.current_scene = null # Keep this driver alive while the game changes scenes.
	state = tree.root.get_node("Global")
	match arguments[0]:
		"traditional", "reformed":
			var replay = load("res://tests/CampaignReplay.gd").new()
			await replay.run(tree, arguments[0], true, capture_directory)
		"traditional-rations", "reformed-rations":
			var replay = load("res://tests/CampaignReplay.gd").new()
			await replay.run(tree, arguments[0].trim_suffix("-rations"), true, capture_directory, true)
		"ending-film":
			var replay = load("res://tests/EndingFilmReplay.gd").new()
			await replay.run(tree, capture_directory)
		"night-rations":
			var replay = load("res://tests/NightRationsReplay.gd").new()
			await replay.run(tree)
		"research-rations", "research-rations-legacy":
			var replay = load("res://tests/ResearchRationsReplay.gd").new()
			replay.legacy = arguments[0] == "research-rations-legacy"
			await replay.run_research_rations(tree, false, capture_directory)
		"ration-priority", "ration-priority-legacy":
			var replay = load("res://tests/RationPriorityReplay.gd").new()
			replay.legacy = arguments[0] == "ration-priority-legacy"
			await replay.run(tree)
		"retainer-return", "retainer-return-legacy":
			var replay = load("res://tests/RetainerReturnReplay.gd").new()
			replay.legacy = arguments[0] == "retainer-return-legacy"
			await replay.run(tree)
		"gamepad":
			var replay = load("res://tests/GamepadReplay.gd").new()
			await replay.run(tree, capture_directory)
		"management-navigation":
			var replay = load("res://tests/ManagementNavigationReplay.gd").new()
			replay.capture_dir = capture_directory
			await replay.run(tree)
		"six-arts", "six-arts-legacy":
			var replay = load("res://tests/SixArtsReplay.gd").new()
			replay.legacy = arguments[0] == "six-arts-legacy"
			await replay.run(tree)
		"bow-aim":
			var replay = load("res://tests/BowAimReplay.gd").new()
			await replay.run(tree, capture_directory)
		"winter-supper":
			var replay = load("res://tests/WinterSupperReplay.gd").new()
			await replay.run(tree, capture_directory)
		"summer-raft":
			var replay = load("res://tests/SummerRaftReplay.gd").new()
			await replay.run(tree, capture_directory)
		"title-presentation":
			var replay = load("res://tests/TitlePresentationReplay.gd").new()
			await replay.run(tree, capture_directory)
		"hall-decor", "hall-decor-legacy":
			var replay = load("res://tests/HallDecorReplay.gd").new()
			replay.legacy = arguments[0] == "hall-decor-legacy"
			await replay.run(tree)
		"route-goals", "route-goals-legacy":
			var replay = load("res://tests/RouteGoalsReplay.gd").new()
			replay.legacy = arguments[0] == "route-goals-legacy"
			await replay.run(tree)
		"council-prep", "council-prep-legacy", "council-petition":
			var replay = load("res://tests/CouncilPrepReplay.gd").new()
			replay.legacy = arguments[0] == "council-prep-legacy"
			replay.petition = arguments[0] == "council-petition"
			await replay.run(tree)
		"council-silk":
			var replay = load("res://tests/CouncilSilkReplay.gd").new()
			replay.capture_dir = capture_directory
			await replay.run(tree)
		"estate-directions", "estate-directions-legacy":
			var replay = load("res://tests/EstateDirectionsReplay.gd").new()
			replay.legacy = arguments[0] == "estate-directions-legacy"
			await replay.run(tree)
		"tribute-plan", "tribute-plan-baseline", "tribute-plan-legacy":
			var replay = load("res://tests/TributePlanReplay.gd").new()
			replay.baseline = arguments[0] == "tribute-plan-baseline"
			replay.legacy = arguments[0] == "tribute-plan-legacy"
			await replay.run_tribute(tree, capture_directory)
		"field-steward":
			var replay = load("res://tests/FieldSeedPlanReplay.gd").new()
			replay.steward_story = true
			await replay.run(tree)
		"field-planning", "field-planning-legacy":
			var replay = load("res://tests/FieldPlanningReplay.gd").new()
			replay.legacy = arguments[0] == "field-planning-legacy"
			await replay.run(tree)
		"field-rotation-plans", "field-rotation-plans-legacy":
			var replay = load("res://tests/FieldRotationPlanReplay.gd").new()
			replay.legacy = arguments[0] == "field-rotation-plans-legacy"
			replay.capture_path = capture_directory
			await replay.run(tree)
		"silk-batches", "silk-batches-legacy":
			var replay = load("res://tests/SilkBatchReplay.gd").new()
			replay.legacy = arguments[0] == "silk-batches-legacy"
			await replay.run(tree)
		"silk-market", "silk-market-legacy":
			var replay = load("res://tests/SilkMarketReplay.gd").new()
			replay.legacy = arguments[0] == "silk-market-legacy"
			replay.capture_path = capture_directory
			await replay.run(tree)
		"silk-interior":
			OS.set_environment("FIEFDOM_SILK_CAPTURES", capture_directory)
			await load("res://tests/SilkInteriorReplay.gd").new().run(tree)
		"neighbor-handoff", "neighbor-handoff-legacy":
			var replay = load("res://tests/NeighborHandoffReplay.gd").new()
			replay.legacy = arguments[0] == "neighbor-handoff-legacy"
			replay.capture_path = capture_directory
			await replay.run(tree)
		"ambience-travel":
			var replay = load("res://tests/AmbienceTravelReplay.gd").new()
			replay.capture_path = capture_directory
			await replay.run(tree)
		"estate-terrain", "estate-terrain-art":
			var replay = load("res://tests/EstateTerrainReplay.gd").new()
			replay.title_art = arguments[0] == "estate-terrain-art"
			replay.capture_path = capture_directory
			await replay.run(tree)
		"canal-flow":
			var replay = load("res://tests/CanalFlowReplay.gd").new()
			await replay.run(tree, false, capture_directory)
		"canal-doors", "canal-doors-legacy":
			var replay = load("res://tests/CanalDoorReplay.gd").new()
			replay.legacy = arguments[0] == "canal-doors-legacy"
			await replay.run_doors(tree, false, capture_directory)
		"irrigation-flow", "irrigation-flow-baseline", "irrigation-flow-legacy":
			var replay = load("res://tests/IrrigationFlowReplay.gd").new()
			replay.baseline = arguments[0] == "irrigation-flow-baseline"
			replay.legacy = arguments[0] == "irrigation-flow-legacy"
			await replay.run_irrigation(tree, capture_directory)
		"estate-progress":
			var replay = load("res://tests/EstateProgressReplay.gd").new()
			await replay.run(tree)
		"recruitment-ledger", "recruitment-ledger-legacy":
			var replay = load("res://tests/RecruitmentLedgerReplay.gd").new()
			replay.legacy = arguments[0] == "recruitment-ledger-legacy"
			replay.capture_path = capture_directory
			await replay.run(tree)
		"field-worksites", "field-worksites-legacy":
			var replay = load("res://tests/FieldWorksiteReplay.gd").new()
			replay.legacy = arguments[0] == "field-worksites-legacy"
			await replay.run(tree, capture_directory)
		"field-stroke", "field-stroke-legacy":
			var replay = load("res://tests/FieldStrokeReplay.gd").new()
			replay.legacy = arguments[0] == "field-stroke-legacy"
			await replay.run_field_stroke(tree, false, capture_directory)
		"field-routes", "field-routes-legacy":
			var replay = load("res://tests/FieldRoutesReplay.gd").new()
			replay.legacy = arguments[0] == "field-routes-legacy"
			replay.capture_path = capture_directory
			await replay.run(tree)
		"field-nights":
			var replay = load("res://tests/FieldNightReplay.gd").new()
			await replay.run(tree, capture_directory)
		"pavilion-evening", "pavilion-evening-legacy":
			var replay = load("res://tests/PavilionEveningReplay.gd").new()
			replay.legacy = arguments[0] == "pavilion-evening-legacy"
			replay.capture_path = capture_directory
			await replay.run(tree)
		"market-orders", "summer-rice":
			var replay = load("res://tests/MarketOrderReplay.gd").new()
			replay.summer = arguments[0] == "summer-rice"
			await replay.run(tree)
		"order-preparation", "order-preparation-baseline", "order-preparation-old-save":
			var replay = load("res://tests/OrderPreparationReplay.gd").new()
			replay.baseline = arguments[0] == "order-preparation-baseline"
			replay.from_older_save = arguments[0] == "order-preparation-old-save"
			replay.capture_path = capture_directory
			await replay.run(tree)
		"watch-relief", "watch-relief-baseline", "watch-relief-old-save":
			var replay = load("res://tests/WatchReliefReplay.gd").new()
			replay.baseline = arguments[0] == "watch-relief-baseline"
			replay.from_older_save = arguments[0] == "watch-relief-old-save"
			replay.capture_path = capture_directory
			await replay.run(tree)
		"seed-garden":
			var replay = load("res://tests/SeedGardenReplay.gd").new()
			await replay.run(tree)
		"autumn-exhibit":
			var replay = load("res://tests/AutumnExhibitReplay.gd").new()
			await replay.run(tree)
		"sheepfold", "meadow-fodder":
			var replay = load("res://tests/SheepfoldReplay.gd").new()
			replay.meadow_only = arguments[0] == "meadow-fodder"
			await replay.run(tree)
		"fish-market-orders", "fish-market-orders-legacy":
			var replay = load("res://tests/FishMarketReplay.gd").new()
			replay.legacy = arguments[0] == "fish-market-orders-legacy"
			replay.capture_path = capture_directory
			await replay.run(tree)
		"fishing-journey", "fishing-journey-legacy":
			var replay = load("res://tests/FishingJourneyReplay.gd").new()
			replay.legacy = arguments[0] == "fishing-journey-legacy"
			await replay.run(tree)
		"ravine-map":
			var replay = load("res://tests/RavineMapReplay.gd").new()
			replay.map_capture_dir = capture_directory
			await replay.run(tree)
		"ravine-shortcut", "ravine-shortcut-legacy", "ravine-shortcut-baseline":
			var replay = load("res://tests/RavineShortcutReplay.gd").new()
			replay.legacy = arguments[0] == "ravine-shortcut-legacy"
			replay.baseline = arguments[0] == "ravine-shortcut-baseline"
			replay.capture_path = capture_directory
			await replay.run(tree)
		"creek-traps":
			var replay = load("res://tests/CreekTrapReplay.gd").new()
			await replay.run(tree)
		"west-market":
			var replay = load("res://tests/WestMarketReplay.gd").new()
			await replay.run(tree)
		"west-road", "west-road-baseline", "west-road-older-save":
			var replay = load("res://tests/WestRoadReplay.gd").new()
			replay.baseline = arguments[0] == "west-road-baseline"
			replay.from_older_save = arguments[0] == "west-road-older-save"
			replay.capture_path = capture_directory
			await replay.run(tree)
		"market-wayfinding", "market-wayfinding-legacy", "market-wayfinding-old-save":
			var replay = load("res://tests/MarketWayfindingReplay.gd").new()
			replay.legacy = arguments[0] == "market-wayfinding-legacy"
			replay.from_older_save = arguments[0] == "market-wayfinding-old-save"
			replay.capture_path = capture_directory
			await replay.run(tree)
		"key-bindings", "key-bindings-reload":
			var replay = load("res://tests/KeyBindingsReplay.gd").new()
			await replay.run(tree, capture_directory, arguments[0] == "key-bindings-reload")
		"defeat":
			await _defeat()
		"research":
			await _research()
		"legacy-create":
			await _legacy_create()
		"legacy-continue":
			await _legacy_continue()
		"visual":
			await _visual()
		"soak":
			await _soak()
		_:
			_fail("Unknown release replay " + arguments[0])

func _start_fresh() -> void:
	var tree := get_tree()
	tree.change_scene_to_file(TITLE)
	await tree.scene_changed
	tree.current_scene.new_button.pressed.emit()
	await tree.scene_changed

func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for frame in range(frames):
		await get_tree().physics_frame
	Input.action_release(action)
	await load("res://tests/CampaignReplay.gd").wait_for_map_change(get_tree())

func _capture(name: String) -> void:
	if capture_directory.is_empty():
		return
	await get_tree().process_frame
	RenderingServer.viewport_set_update_mode(get_tree().root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	var image := get_tree().root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(capture_directory.path_join(name + ".png")) != OK:
		push_error("Could not save the rendered " + name + " frame.")
		return
	print("RELEASE_FRAME ", name, " window=", get_tree().root.size, " image=", image.get_size())

func _find_button(node: Node, text: String) -> Button:
	for button in node.find_children("*", "Button", true, false):
		if button.text.begins_with(text):
			return button
	return null

func _defeat() -> void:
	seed(17)
	var tree := get_tree()
	await _start_fresh()
	var world := tree.current_scene.get_node("World")
	world.handle_interaction(CROP)
	world.handle_interaction(CROP)
	world.handle_interaction(CROP)
	var ui := tree.current_scene.get_node("UI")
	ui.sleep_button.pressed.emit()
	await tree.create_timer(1.12).timeout
	var checkpoint: Dictionary = state.latest_saved_game()
	if state.current_day != 2 or checkpoint.get("day") != 2 or FileAccess.file_exists(state.manual_save_path()):
		_fail("One normal night must create a checkpoint without any manual save.")
		return
	await _move(&"ui_up", 48)
	await _move(&"ui_right", 213)
	if tree.current_scene.name != "Wilderness":
		_fail("The estate gate must lead to the wilderness.")
		return
	await _capture("wilderness")
	var trail_player := tree.current_scene.get_node("Player") as Node2D
	var trail_replay := load("res://tests/CampaignReplay.gd")
	await trail_replay.walk_to(tree, trail_player, Vector2(107, 36))
	await _move(&"ui_right", 86)
	# Follow the east bank south into the scout's patrol before waiting for damage.
	await trail_replay.walk_to(tree, trail_player, Vector2(262, 166))
	var showed_injury := false
	for frame in range(1500):
		if tree.paused:
			break
		if not showed_injury and state.health < state.balance.player_max_health:
			await _capture("injury")
			showed_injury = true
		await tree.physics_frame
	if state.outcome != state.Outcome.DEFEAT_COMBAT or state.health != 0 or not tree.paused:
		_fail("The player must be able to lose a fight to enemies using the default balance.")
		return
	await _capture("defeat")
	var hud := tree.current_scene.get_node("CampaignHUD")
	hud.summary.find_child("RestoreCampaign", true, false).pressed.emit()
	await tree.scene_changed
	var restored_crop: Dictionary = state.active_crops.get(CROP, {})
	if (tree.paused or state.outcome != state.Outcome.RUNNING or state.health != state.balance.player_max_health
			or state.current_day != 2 or restored_crop.get("age") != 1 or state.food_storage != 9):
		_fail("The checkpoint must restore the healthy player and planted crop.")
		return
	print("RELEASE_DEFEAT restored_health=", state.health, " day=", state.current_day)
	_pass()

func _legacy_create() -> void:
	var tree := get_tree()
	tree.change_scene_to_file(ESTATE)
	await tree.scene_changed
	var world := tree.current_scene.get_node("World")
	var ui := tree.current_scene.get_node("UI")
	for cell in [Vector2i(5, 5), CROP]:
		world.handle_interaction(cell)
		world.handle_interaction(cell)
	for night in range(2):
		for cell in [Vector2i(5, 5), CROP]:
			world.handle_interaction(cell)
		ui.sleep_button.pressed.emit()
		await tree.create_timer(1.1).timeout
	world.handle_interaction(Vector2i(5, 5))
	world.handle_interaction(CROP)
	world.handle_interaction(CROP)
	world.handle_interaction(CROP)
	if state.king_storage != 1 or state.money != 5 or not state.active_crops.has(CROP) or state.save_game() != OK:
		_fail("Could not create a real 0.1.1 save with tribute and a planted crop.")
		return
	print("LEGACY_SAVE version=", ProjectSettings.get_setting("application/config/version"), " day=", state.current_day)
	_pass()

func _research() -> void:
	var tree := get_tree()
	await _start_fresh()
	var ui := tree.current_scene.get_node("UI")
	# Isolate the funded deadline from the full campaign's ordinary low-funds route.
	state.current_day = 3 * state.balance.days_per_year
	state.current_rank = state.Rank.DA_FU
	state.king_storage = 20
	state.reputation = state.balance.grandee_rank_reputation
	state.money = 1500
	state.balance.raid_first_day = 10000
	ui.sleep_button.pressed.emit()
	await tree.create_timer(1.1).timeout
	var campaign := load("res://tests/CampaignReplay.gd")
	var panel: Control = await campaign.meet_tax_envoy(tree)
	if panel == null:
		_fail("Research fixture must reach the initial choice.")
		return
	_find_button(panel, "暂缓").pressed.emit()
	panel.confirm_button.pressed.emit()
	var first_day: int = state.current_day
	var duration: int = state.balance.days_per_year
	var interval: int = state.research_payment_interval()
	var initial_money: int = state.money
	while state.current_day < first_day + duration and not tree.paused:
		ui.sleep_button.pressed.emit()
		await tree.create_timer(1.1).timeout
		if state.current_day == first_day + interval:
			var paid: int = state.money
			if paid != initial_money - state.balance.research_monthly_cost or state.save_game() != OK or state.load_game() != OK:
				_fail("Research should charge on schedule and save its remaining term.")
				return
			await tree.scene_changed
			ui = tree.current_scene.get_node("UI")
			if state.money != paid or state.research_days_remaining() != duration - interval:
				_fail("Reloading must preserve the deadline and never repeat a fee.")
				return
	panel = await campaign.meet_tax_envoy(tree)
	var total_fees := floori(float(duration) / interval) * int(state.balance.research_monthly_cost)
	if not tree.paused or panel == null or _find_button(panel, "暂缓") != null or state.money != initial_money - total_fees:
		_fail("A funded year of research must reach the final decision and charge each fee once.")
		return
	print("RELEASE_RESEARCH days=", duration, " fees=", total_fees)
	_pass()

func _legacy_continue() -> void:
	var latest: Dictionary = state.latest_saved_game()
	if latest.is_empty():
		_fail("The previous build must supply a readable save.")
		return
	var saved_path: String = latest.path
	var legacy_text := FileAccess.get_file_as_string(saved_path)
	var legacy_save = JSON.parse_string(legacy_text)
	if not legacy_save is Dictionary or legacy_save.get("retainers", []).is_empty():
		_fail("The old build must supply an actual save and retainer record.")
		return
	var tree := get_tree()
	tree.change_scene_to_file(TITLE)
	await tree.scene_changed
	if tree.current_scene.continue_button.disabled:
		_fail("The old save must be available at the title.")
		return
	tree.current_scene.continue_button.pressed.emit()
	await tree.scene_changed
	for key in ["current_day", "current_rank", "king_storage", "money", "player_inventory", "food_storage", "reputation"]:
		if state.get(key) != int(legacy_save[key]):
			_fail("Loading the old save changed " + key + ".")
			return
	var original_retainer: Dictionary = legacy_save["retainers"][0]
	var original_crop: Dictionary = legacy_save["active_crops"]["6,5"]
	var restored_crop: Dictionary = state.active_crops.get(CROP, {})
	var new_systems_ready: bool = state.irrigation.channels.is_empty() and not state.silk_workshop.built
	if not new_systems_ready or not state.tilled_cells.has(CROP) or restored_crop.get("id") != original_crop["id"] or restored_crop.get("watered") != original_crop["watered"] or restored_crop.get("age") != int(original_crop["age"]):
		_fail("Loading the old save must restore the planted crop and initialize the new systems.")
		return
	if state.retainers.size() != legacy_save["retainers"].size() or state.retainers[0].name != original_retainer["name"] or state.retainers[0].school != int(original_retainer["school"]):
		_fail("Loading the old save must preserve the retainer identity and school.")
		return
	var ui := tree.current_scene.get_node("UI")
	ui.sleep_button.pressed.emit()
	await tree.create_timer(1.1).timeout
	if state.active_crops[CROP]["age"] != 1 or state.save_game() != OK:
		_fail("A crop from the old save must continue growing and save again.")
		return
	if not FileAccess.file_exists(state.manual_save_path()):
		_fail("Continuing a previous estate must save to its own directory.")
		return
	if saved_path == state.SAVE_PATH and FileAccess.get_file_as_string(saved_path) != legacy_text:
		_fail("Continuing a legacy estate must preserve the old root file.")
		return
	print("LEGACY_CONTINUE day=", state.current_day, " crop_age=", state.active_crops[CROP]["age"], " copper=", state.money, " retainer=", state.retainers[0].name)
	_pass()

func _visual() -> void:
	var tree := get_tree()
	tree.change_scene_to_file(TITLE)
	await tree.scene_changed
	var audio := tree.root.get_node("AudioManager")
	if not audio.bgm_player.playing or audio.field_sounds.size() != audio.FIELD_SOUND_PATHS.size():
		_fail("The rendered release must start its score and load action sounds.")
		return
	await _capture("title")
	tree.current_scene.get_node("Center/Menu/Settings").pressed.emit()
	var settings: Panel = tree.current_scene.settings_panel
	var volume := settings.find_child("MasterVolume", true, false) as HSlider
	volume.value = 0
	if not AudioServer.is_bus_mute(0):
		_fail("The master volume control must mute the rendered release.")
		return
	await _capture("settings")
	volume.value = 0.75
	_find_button(settings, "关闭").pressed.emit()
	tree.current_scene.new_button.pressed.emit()
	await tree.scene_changed
	await _capture("estate")
	var ui := tree.current_scene.get_node("UI")
	var tile_map := tree.current_scene.get_node("World/TileMapLayer") as TileMapLayer
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = tile_map.get_global_transform_with_canvas() * tile_map.map_to_local(CROP)
	click.global_position = click.position
	for attempt in range(2):
		for pressed in [true, false]:
			click.pressed = pressed
			tree.root.push_input(click, true)
			await tree.process_frame
	if not state.active_crops.has(CROP):
		_fail("The rendered estate must receive a map click to till and plant at either size.")
		return
	await _capture("farming")
	ui.manage_button.pressed.emit()
	await _capture("management")
	var management: Control = ui.panel_manager.management_panel_instance
	management.get_node("HBoxContainer/RightPanel").current_tab = 2
	management.music_button.pressed.emit()
	var practice := management.get_node("MusicPractice")
	while practice.elapsed < practice.BEAT_SECONDS - practice.HIT_WINDOW / 2.0:
		await tree.process_frame
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	tree.root.push_input(event, true)
	if practice.hits != 1:
		_fail("The rendered rhythm panel must accept a timed key press.")
		return
	await _capture("music")
	_find_button(practice, "结束练习").pressed.emit()
	await tree.process_frame
	management.get_node("CloseButton").pressed.emit()
	ui.sleep_button.pressed.emit()
	await tree.create_timer(1.1).timeout
	var world := tree.current_scene.get_node("World")
	var visitor: Node2D = world.current_visitor_actor()
	await load("res://tests/CampaignReplay.gd").walk_estate_road_to(tree, world, visitor.global_position + Vector2(-8, -16))
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	tree.root.push_input(event, true)
	if not ui.has_node("Control/DialoguePanel"):
		_fail("A new player must be able to see a named visitor and portrait.")
		return
	await _capture("visitor")
	print("RELEASE_RENDER ", RenderingServer.get_video_adapter_name(), " / ", RenderingServer.get_video_adapter_api_version())
	_pass()

func _soak() -> void:
	var tree := get_tree()
	await _start_fresh()
	var world := tree.current_scene.get_node("World")
	var ui := tree.current_scene.get_node("UI")
	var start_ms := Time.get_ticks_msec()
	var start_frame := Engine.get_process_frames()
	var cycles := 0
	var cells := [Vector2i(5, 5), CROP]
	for cell in cells:
		world.handle_interaction(cell)
	while Time.get_ticks_msec() - start_ms < 90_000:
		for cell in cells:
			var crop: Dictionary = state.active_crops.get(cell, {})
			if not crop.is_empty() and world.field_action(cell) == world.FieldAction.HARVEST:
				world.handle_interaction(cell)
			if not state.active_crops.has(cell):
				world.handle_interaction(cell)
			if not state.active_crops[cell]["watered"]:
				world.handle_interaction(cell)
		if Time.get_ticks_msec() - start_ms >= state.current_day * 12_000:
			ui.sleep_button.pressed.emit()
			await tree.create_timer(1.1).timeout
			if state.latest_saved_game().get("day") != state.current_day:
				_fail("Every completed night in the continuous run must be recoverable.")
				return
		ui.manage_button.pressed.emit()
		await tree.process_frame
		ui.panel_manager.management_panel_instance.get_node("CloseButton").pressed.emit()
		await _move(&"ui_right" if cycles % 2 == 0 else &"ui_left", 10)
		await tree.create_timer(2.4).timeout
		cycles += 1
	if state.outcome != state.Outcome.RUNNING or state.king_storage < 3 or cycles < 10:
		_fail("The estate must keep responding and producing through the 90-second run.")
		return
	await _capture("soak-estate")
	var latest: Dictionary = state.latest_saved_game()
	var catalog: Array[Dictionary] = state.saved_games()
	if catalog.size() != 3 or FileAccess.file_exists(state.manual_save_path()):
		_fail("A long run must rotate the three automatic saves without creating a manual one.")
		return
	print("RELEASE_SOAK seconds=", (Time.get_ticks_msec() - start_ms) / 1000.0, " frames=", Engine.get_process_frames() - start_frame,
		" ui_cycles=", cycles, " day=", state.current_day, " public=", state.king_storage,
		" autosaves=", catalog.size(), " saved_day=", latest["day"])
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.create_timer(0.25).timeout
	_pass()

func _pass() -> void:
	print("SCENARIO_OK")
	get_tree().quit()

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
