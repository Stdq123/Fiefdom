extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const PUBLIC := Vector2i(5, 5)
const PLOTS := [PUBLIC, Vector2i(4, 4), Vector2i(4, 5)]

var tree: SceneTree
var state: Node
var capture_dir := ""
var failed := false

func _expect(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		push_error(message)
	return ok

func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame

func _button(button: Button) -> void:
	await tree.process_frame
	if _expect(button.is_visible_in_tree() and not button.disabled
			and tree.root.get_visible_rect().encloses(button.get_global_rect()), "The button is usable: " + button.text):
		await _click(button.get_global_rect().get_center())

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)
	await tree.process_frame

func _walk(actor: Player, points: Array) -> void:
	for point: Vector2 in points:
		await Campaign.walk_to(tree, actor, point)

func _cross(action: StringName, path: String) -> bool:
	Input.action_press(action)
	for frame in 48:
		await tree.physics_frame
		if tree.root.get_node("MapTravel").active:
			break
	Input.action_release(action)
	await Campaign.wait_for_map_change(tree)
	return _expect(tree.current_scene.scene_file_path == path, "Walking along the road opens " + path)

func _snapshot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await tree.create_timer(0.24).timeout
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(capture_dir.path_join(name + ".png")) == OK, "Save market frame " + name)
	print("MARKET_FRAME ", name, " window=", tree.root.size, " image=", frame.get_size())

func _harvest(world: Node2D, ui: CanvasLayer) -> void:
	var tiles := world.tile_map as TileMapLayer
	var points: Array[Vector2] = []
	for cell: Vector2i in PLOTS:
		points.append(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))
	for point in points:
		await _click(point)
		await _click(point)
	for night in 2:
		for point in points:
			await _click(point)
		await _button(ui.sleep_button)
		await tree.create_timer(1.12).timeout
	for point in points:
		await _click(point)
	_expect(state.current_day == 3 and state.king_storage == 1 and state.player_inventory == 2,
		"Grow and harvest two private crops and one public crop through the farm controls.")
	await _key(KEY_5)

func _enter_market(world: Node2D, ui: CanvasLayer) -> bool:
	await _button(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	management.show_market()
	await tree.process_frame
	await _button(management.market_panel.get_node("MarketHeader/MarketDirections"))
	_expect(ui.directions.tracked_place == "西市 · 粮摊" and state.market_trip_target == "粮摊" and not management.visible,
		"The market shortcut marks the west road and the grain stall.")
	await _walk(world.player, [Vector2(-181, 54), Vector2(-181, 0), Vector2(-270, -21)])
	return await _cross(&"ui_left", state.WEST_MARKET_SCENE)

func _walk_street(market: Node2D) -> void:
	var porter: Node2D = market.get_node("Porter")
	var grain := market.get_node("Stalls/GrainStall") as MarketStall
	_expect(porter.visible and porter.position.distance_to(Vector2(-162, 36)) < 3.0,
		"The porter is at the grain end when the player reaches the morning market.")
	for x in [-125, -20, 90, 176, 221]:
		_expect(market.ground.is_on_paving(Vector2(x, 34)), "Paving follows the street through the return gate.")
	var bus := AudioServer.get_bus_index("Ambience")
	var slot := AudioServer.get_bus_effect_count(bus)
	var recorder: AudioEffectRecord
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		recorder = AudioEffectRecord.new()
		recorder.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(bus, recorder)
		recorder.set_recording_active(true)
	await _walk(market.player, [Vector2(84, 34)])
	var stone: String = market.audio.footsteps.stream.resource_path.get_file()
	await _walk(market.player, [Vector2(84, 70), Vector2(14, 70)])
	var dirt: String = market.audio.footsteps.stream.resource_path.get_file()
	_expect(stone.begins_with("stone-") and dirt.begins_with("track-"),
		"Walking on the paving and the apron chooses different sounds.")
	if recorder:
		await tree.create_timer(0.20).timeout
		recorder.set_recording_active(false)
		var mix := recorder.get_recording()
		AudioServer.remove_bus_effect(bus, slot)
		_expect(mix != null and mix.get_length() > 1.2 and mix.save_to_wav(capture_dir.path_join("stone-and-dirt")) == OK,
			"Save the live stone and dirt footsteps.")
	print("MARKET_SURFACES stone=", stone, " dirt=", dirt)
	for frame in 400:
		if grain.keeper.frame == MarketStall.KeeperPose.TEND and grain.pose_time < 0.65:
			break
		await tree.physics_frame
	_expect(grain.keeper.frame == MarketStall.KeeperPose.TEND, "The unoccupied grain keeper tends goods between customers.")
	await _snapshot("00-market-morning")

func _time_at(progress: float) -> void:
	state.day_progress = progress
	tree.root.get_node("GameEvents").daylight_changed.emit()
	await tree.process_frame
	await tree.physics_frame

func _dusk(market: Node2D) -> void:
	await _time_at(0.700)
	var porter: Node2D = market.get_node("Porter")
	var from := porter.position
	await tree.create_timer(0.36).timeout
	_expect(porter.visible and porter.position.x > from.x + 4.0 and porter.body.walking,
		"At dusk the porter walks east down the paved street.")
	print("MARKET_PORTER_DUSK ", from, " -> ", porter.position)
	await _snapshot("06-porter-at-dusk")

func _night(market: Node2D) -> bool:
	await _time_at(0.915)
	var porter: Node2D = market.get_node("Porter")
	_expect(not porter.visible and market.lighting.lamps[2].glow.enabled and market.lighting.color != Color.WHITE,
		"The porter has gone through the gate and the silk stall lamp lights the late market.")
	await _walk(market.player, [Vector2(52, 48)])
	await _snapshot("07-market-lanterns")
	if not await _stall(market, "SilkStall", ""):
		return false
	await _key(KEY_ESCAPE)
	await _walk(market.player, [Vector2(176, 34)])
	return true

func _stall(market: Node2D, stall_name: String, capture: String) -> bool:
	var stall := market.get_node("Stalls/" + stall_name) as MarketStall
	await _walk(market.player, [Vector2(stall.position.x, 28)])
	if not capture.is_empty():
		await _snapshot(capture)
	_expect(stall.focused and stall.keeper.frame != MarketStall.KeeperPose.TEND,
		"The keeper looks up when the counter is in reach.")
	await _key(KEY_E)
	return _expect(market.counter.visible and market.player.conversation_open,
		"Press E on foot at " + stall_name)

func _shop(market: Node2D, fish_id: String) -> bool:
	var counter: Control = market.counter
	if not await _stall(market, "GrainStall", "01-west-market"):
		return false
	var before_money: int = state.money
	var before_food: int = state.food_storage
	await _button(counter.grain.sell_button)
	await _button(counter.grain.convert_button)
	await _button(counter.grain.buy_button)
	_expect(state.player_inventory == 0 and state.king_storage == 1 and state.food_storage == before_food + 2
		and state.money == before_money + state.balance.market_crop_price - state.balance.market_food_price,
		"Sell, convert and buy at the grain stall at the existing prices.")
	await _snapshot("02-grain-counter")
	var reserve: OptionButton = counter.grain.reserve_kind
	reserve.select(counter.grain.ReserveKind.RECLAMATION)
	reserve.item_selected.emit(counter.grain.ReserveKind.RECLAMATION)
	_expect("立桩用粮 60" in counter.grain.reserve_label.text and counter.grain.reserve_button.disabled
		and not counter.grain.survey_button.visible, "The grain stall can quote the same future field without an estate survey to return to.")
	await _snapshot("05-stall-provisions")
	await _key(KEY_ESCAPE)
	if not await _stall(market, "FishStall", ""):
		return false
	before_money = state.money
	await _button(counter.fish.rows[fish_id].sell)
	_expect(state.fish_count(fish_id) == 0 and state.fish_collection.has(fish_id)
		and state.money == before_money + CreekFish.SPECIES[fish_id].copper, "Selling the fish preserves its first-catch entry.")
	await _snapshot("03-fish-counter")
	await _button(counter.close_button)
	if not await _stall(market, "SilkStall", ""):
		return false
	before_money = state.money
	await _button(counter.sell_silk)
	_expect(state.silk_workshop.bolts == 0 and state.silk_bolts_sold == 1 and counter.sell_silk.disabled
		and state.money == before_money + state.balance.silk_sell_price, "The silk stall credits the established price and campaign sale count.")
	await _snapshot("04-silk-counter")
	await _key(KEY_ESCAPE)
	return true

func _continue_from_market(market: Node2D, fish_id: String) -> void:
	await _button(market.get_node("UI/Control/Wallet/SettingsButton"))
	var paused: float = state.day_progress
	var porter_position: Vector2 = market.get_node("Porter").position
	await tree.create_timer(0.30).timeout
	_expect(state.day_progress == paused and market.get_node("Porter").position == porter_position,
		"The market clock and porter's trip pause in settings.")
	for button: Button in market.settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	var saved_money: int = state.money
	var saved_food: int = state.food_storage
	var progress: float = state.day_progress
	print("MARKET_SAVED copper=", saved_money, " grain=", saved_food)
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	var title := tree.current_scene as Control
	_expect("西市" in title.status.text, "The title identifies the west market save.")
	print("MARKET_TITLE ", title.status.text)
	await _button(title.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	market = tree.current_scene
	if not _expect(market.scene_file_path == state.WEST_MARKET_SCENE, "Continue restores the market scene."):
		return
	print("MARKET_CONTINUED at=", market.player.position)
	_expect(market.player.position == market.get_node("EstateRoadArrival").position
		and absf(state.day_progress - progress) < 0.03 and state.money == saved_money and state.food_storage == saved_food
		and state.fish_count(fish_id) == 0 and state.silk_bolts_sold == 1, "The market checkpoint keeps the clock and receipts.")
	_expect(market.get_node("Porter").position.distance_to(porter_position) < 5.0,
		"Continue restores the porter on the same part of the route.")
	print("MARKET_PORTER_RESTORED ", market.get_node("Porter").position, " clock=", state.day_progress)
	if not await _night(market):
		return
	if await _cross(&"ui_right", state.ESTATE_SCENE):
		var world := tree.current_scene.get_node("World") as Node2D
		_expect(world.player.position.distance_to(world.get_node("WestMarketArrival").position) < 4.0
			and state.current_day == 3 and state.king_storage == 1 and world.current_seed_id == "beans",
			"Return by the west road with the estate and selected seed intact.")
		print("MARKET_RETURN day=", state.current_day, " copper=", state.money, " grain=", state.food_storage,
			" tribute=", state.king_storage, " seed=", world.current_seed_id)

func _play() -> void:
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	var world := tree.current_scene.get_node("World") as Node2D
	var ui := tree.current_scene.get_node("UI") as CanvasLayer
	await _harvest(world, ui)
	# The fishing and silk replays cover earning these two lots.
	state.talk_to_visitor(VisitorData.RAVINE_GUIDE)
	var fish_id: String = state.land_creek_fish(CreekFish.Site.POOL, state.current_day)
	state.silk_workshop.built = true
	state.silk_workshop.bolts = 1
	if await _enter_market(world, ui):
		var market := tree.current_scene as Node2D
		await _walk_street(market)
		if await _shop(market, fish_id):
			await _dusk(market)
			await _continue_from_market(market, fish_id)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated market profile."):
		tree.quit(1)
		return
	capture_dir = OS.get_environment("FIEFDOM_MARKET_CAPTURES")
	state = tree.root.get_node("Global")
	tree.root.notify_mouse_entered()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _play()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
