extends "res://tests/WestMarketReplay.gd"

const SILK_TABLE_CENTER := Vector2(142, 180)
const STALLS := ["SilkStall", "FishStall", "GrainStall"]
const FRAMES := ["02-silk-apron", "03-fish-apron", "04-grain-apron"]

var variant := ""

func _fresh_market() -> Node2D:
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	var world: Node2D = tree.current_scene.get_node("World")
	var gate: Node2D = world.get_node("WestMarketArrival")
	if variant == "market-street-rain":
		state.current_day = 6
		state.day_progress = 0.32
	elif variant == "market-street-winter":
		state.current_day = 19
		state.day_progress = 0.32
	await Campaign.walk_estate_road_to(tree, world, gate.global_position)
	if not await _cross(&"ui_left", state.WEST_ROAD_SCENE):
		return null
	var road := tree.current_scene as Node2D
	await Campaign.walk_straight(tree, road.player, Vector2(-226, 36))
	await _snapshot("00-bridge-to-market")
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return null
	await tree.create_timer(0.06).timeout
	var market := tree.current_scene as Node2D
	await _snapshot("01-market-east-gate")
	return market

func _approach_stall(market: Node2D, name: String, capture: String, old: bool) -> bool:
	var stall := market.get_node("Stalls/" + name) as MarketStall
	var approach := stall.to_global(MarketStall.APPROACH)
	await Campaign.walk_market_to(tree, market, approach)
	if not _expect(market.player.global_position.distance_to(approach) < 4.0
		and market.player.interaction_target == stall and market.ground.is_on_street(approach),
		"Walk the actual lane to the open side of %s. Foot %s, target %s." \
		% [name, market.player.global_position, market.player.interaction_target]):
		return false
	await _snapshot(capture)
	var sounds: Array[String] = []
	var record := func(_point: Vector2): sounds.append(market.audio.footsteps.stream.resource_path.get_file())
	market.player.footstep.connect(record)
	for offset in [8.0, -11.0, 0.0]:
		await Campaign.walk_straight(tree, market.player, approach + Vector2(offset, 0))
	market.player.footstep.disconnect(record)
	var paved: bool = market.ground.is_on_paving(approach)
	var expects_stone := sounds.any(func(sound: String) -> bool: return sound.begins_with("stone-"))
	_expect(paved != old and not sounds.is_empty() and expects_stone != old,
		"The walkway and its audible surface agree at %s. Paved %s, steps %s." % [name, paved, sounds])
	await _key(KEY_E)
	var heading := "%s · %s" % [MarketStall.TITLES[stall.kind], MarketStall.KEEPERS[stall.kind]]
	if not _expect(market.counter.visible and market.counter.title.text == heading,
		"The approaches still open the right vendor counter at " + name):
		return false
	await _key(KEY_ESCAPE)
	print("MARKET_STREET_STALL ", name, " foot=", market.player.global_position, " paved=", paved, " steps=", sounds)
	return true

func _walk_up_to_silk_table(market: Node2D) -> void:
	await Campaign.walk_market_to(tree, market, market.market_map.places["绸摊"])
	await Campaign.walk_straight(tree, market.player, Vector2(181, 210))
	await Campaign.walk_straight(tree, market.player, Vector2(SILK_TABLE_CENTER.x, 210))
	await Campaign.walk_straight(tree, market.player, SILK_TABLE_CENTER)

func _check_silk_table(market: Node2D, old: bool) -> void:
	await _walk_up_to_silk_table(market)
	var foot: Vector2 = market.player.global_position
	if old:
		if not _expect(foot.distance_to(SILK_TABLE_CENTER) < 3.0, "Stand where the later silk table will be placed."):
			return
		await _snapshot("05-before-silk-table")
		await _key(KEY_ESCAPE)
		await _button(market.settings.save_button)
		_expect(market.settings.save_status.text == "游戏已保存", "Keep a regular checkpoint made by the previous release.")
		print("MARKET_STREET_PREVIOUS_FOOT ", foot)
		await _button(market.settings.close_button)
		return
	var table := market.get_node_or_null("Scenery/SilkTable") as StaticBody2D
	if not _expect(table != null and foot.y > table.position.y and foot.y < table.position.y + 11.0
		and absf(foot.x - SILK_TABLE_CENTER.x) < 3.0, "The visible table legs stop the player from walking through the cloth."):
		return
	await _snapshot("05-in-front-of-silk-table")
	for point in [Vector2(170, foot.y), Vector2(170, 167), Vector2(SILK_TABLE_CENTER.x, 167)]:
		await Campaign.walk_straight(tree, market.player, point)
	_expect(market.player.global_position.distance_to(Vector2(SILK_TABLE_CENTER.x, 167)) < 3.0
		and market.get_node("Scenery").y_sort_enabled, "Walk around the table and reach the other side in the sorted scene.")
	await _snapshot("06-behind-silk-table")
	print("MARKET_STREET_TABLE front=", foot, " back=", market.player.global_position)

func _continue_under_new_layout() -> void:
	var checkpoint: Dictionary = state.latest_saved_game()
	var path: String = checkpoint.get("path", "")
	var old_hash := FileAccess.get_sha256(path)
	if not _expect(checkpoint.get("location") == "西市" and not old_hash.is_empty(), "Find the old market checkpoint through the title."):
		return
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	var market := tree.current_scene as Node2D
	if not _expect(market.scene_file_path == state.WEST_MARKET_SCENE and FileAccess.get_sha256(path) == old_hash,
		"Continue the market checkpoint without rewriting it."):
		return
	var foot: Vector2 = market.player.global_position
	var feet := market.player.get_node("CollisionShape2D") as CollisionShape2D
	var footprint: Rect2 = feet.global_transform * feet.shape.get_rect()
	var blocked: Array[Rect2] = market.ground.walking_fixture_footprints()
	if not _expect(foot.distance_to(SILK_TABLE_CENTER) < 16.0
		and not blocked.any(func(fixture: Rect2) -> bool: return fixture.intersects(footprint.grow(0.4)))
		and market.player.facing_direction() == Vector2.UP,
		"Restore the old foot beside the silk table in its saved direction. Foot %s." % foot):
		return
	await tree.physics_frame
	await tree.physics_frame
	await _snapshot("01-previous-checkpoint-loaded")
	# Step clear of the apron furniture before taking the plotted lane.
	await Campaign.walk_straight(tree, market.player, Vector2(172, foot.y))
	if await _approach_stall(market, "SilkStall", "02-previous-checkpoint-at-the-silk-counter", false):
		print("MARKET_STREET_OLD_SAVE sha256=", old_hash, " day=", state.current_day, " landed=", foot,
			" stall=", market.player.global_position)

func run_street(game_tree: SceneTree, captures := "", scenario := "market-street") -> void:
	tree = game_tree
	state = tree.root.get_node("Global")
	capture_dir = captures
	variant = scenario
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated market profile."):
		tree.quit(1)
		return
	seed(467)
	tree.root.notify_mouse_entered()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	print("MARKET_STREET_DISPLAY driver=", DisplayServer.get_name(), " window=", DisplayServer.window_get_size())
	if variant == "market-street-resume":
		await _continue_under_new_layout()
	else:
		var market := await _fresh_market()
		if market != null:
			var old := variant == "market-street-before"
			print("MARKET_STREET_SEASON day=", state.current_day, " rain=", state.has_rain(), " season=", state.season_index())
			for index in STALLS.size():
				if not await _approach_stall(market, STALLS[index], FRAMES[index], old):
					break
			if not failed:
				await _check_silk_table(market, old)
	tree.unload_current_scene()
	await tree.create_timer(0.12).timeout
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
