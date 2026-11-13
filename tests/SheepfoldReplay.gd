extends "res://tests/WestMarketReplay.gd"

const PRIVATE_WHEAT := Vector2i(6, 5)

var world: Node2D
var ui: CanvasLayer
var meadow_only := false

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")

func _advance_night() -> void:
	var tomorrow: int = state.current_day + 1
	await _button(ui.sleep_button)
	await tree.create_timer(1.12).timeout
	_expect(state.current_day == tomorrow, "Overnight care advances exactly one day.")

func _watch(progress: float) -> void:
	state.day_progress = progress
	tree.root.get_node("GameEvents").daylight_changed.emit()

func _continue() -> void:
	await _resume()
	_estate()

func _resume() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed

func _open_sheep_trade() -> Control:
	if world.player.position.y >= EstateLayout.FIELD_LANE_TURN.y:
		await Campaign.walk_estate_road_to(tree, world, world.to_global(Vector2(66, 98)))
	if not await _enter_market(world, ui):
		return null
	var market := tree.current_scene
	await Campaign.walk_market_to(tree, market, market.market_map.places["绸摊"])
	await _key(KEY_E)
	var counter: Control = market.counter
	if not _expect(counter.silk.is_visible_in_tree(), "E at the textile stall opens Cai Niang's counter."):
		return null
	await _button(counter.get_node("%SheepTrade"))
	return counter.sheep

func _return_from_market() -> bool:
	var market := tree.current_scene
	await _key(KEY_ESCAPE)
	await Campaign.walk_to_market_exit(tree, market)
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return false
	_estate()
	return true

func _buy_sheep(buy_feed: bool) -> bool:
	var trade := await _open_sheep_trade()
	if trade == null:
		return false
	_expect(trade.buy_sheep.visible and not trade.buy_sheep.disabled and not trade.sell_wool.is_visible_in_tree(),
		"The trade page quotes the sheep before purchase.")
	await _snapshot("01-market-offer")
	var purchase_day: int = state.current_day
	var copper: int = state.money
	await _button(trade.buy_sheep)
	_expect(state.sheepfold.bought_day == purchase_day and state.money == copper - state.balance.sheep_price
		and not trade.buy_sheep.visible, "Cai Niang places one sheep and charges the quoted price.")
	if buy_feed:
		await _button(trade.buy_fodder)
		_expect(state.sheepfold.fodder == 3 and state.money == copper - state.balance.sheep_price - state.balance.sheep_fodder_price,
			"The fodder bundle reaches the pen as a separate stock.")
	print("SHEEP_PURCHASE day=", state.current_day, " copper=", copper, "->", state.money, " fodder=", state.sheepfold.fodder)
	return true

func _guide_pen() -> void:
	await _key(KEY_M)
	var map: Control = ui.estate_map
	for row: Button in map.row_buttons:
		if map.row_buttons[row].title == Sheepfold.PLACE:
			map.scroll.ensure_control_visible(row)
			await _button(row)
			break
	_expect(ui.directions.tracked_place == Sheepfold.PLACE, "The estate map offers directions to the gate.")
	await _key(KEY_ESCAPE)

func _walk_to_pen() -> void:
	var gate: Vector2 = world.get_node("SheepfoldPen").global_position
	await Campaign.walk_estate_road_to(tree, world, gate)

func _open_pen() -> Control:
	await _key(KEY_E)
	var panel: Control = ui.sheepfold_panel
	return panel if _expect(panel.modal.visible and tree.paused,
		"E at the gate opens the sheepfold at %s." % world.player.global_position) else null

func _test_pasture() -> void:
	await _guide_pen()
	await _walk_to_pen()
	var pen: Node2D = world.get_node("SheepfoldPen")
	var gate := pen.global_position
	await _walk(world.player, [gate + Vector2(-32, 0), gate + Vector2(-32, -25)])
	_expect(world.player.global_position.y > gate.y - 13.0, "The front rail blocks entry at %s." % world.player.global_position)
	await _walk(world.player, [gate + Vector2(-32, 0), gate, gate + Vector2(0, -22)])
	_expect(world.player.global_position.y < gate.y - 14.0, "The visible gate is wide enough to enter.")
	await _walk(world.player, [gate])
	_watch(0.34)
	await tree.create_timer(0.15).timeout
	_expect(pen.visible and pen.animal.position.y > 24.0 and pen.hay.visible, "On a dry day the sheep moves out to pasture.")
	await _snapshot("02-pasture")
	_watch(0.88)
	await tree.create_timer(0.15).timeout
	_expect(pen.animal.position.distance_to(Vector2(-12, 7)) < 1.0, "At dusk the sheep is back under cover.")
	await _advance_night()
	_expect(state.current_day == 19 and state.sheepfold.wool_nights == 1 and state.sheepfold.fodder == 3
		and state.sheepfold.last_feed == Sheepfold.Feed.PASTURE, "The final autumn day used pasture before winter begins.")
	_watch(0.34)
	await tree.create_timer(0.15).timeout
	_expect(pen.animal.position.distance_to(Vector2(-12, 7)) < 1.0, "In winter the sheep stays by the shelter.")

func _plot(cell: Vector2i) -> void:
	var tiles: TileMapLayer = world.tile_map
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))

func _winter_wheat() -> void:
	await Campaign.walk_estate_road_to(tree, world, world.to_global(Vector2(66, 98)))
	await tree.create_timer(0.28).timeout
	await _key(KEY_4)
	for cell: Vector2i in [PUBLIC, PRIVATE_WHEAT]:
		await _plot(cell)
		await _plot(cell)
	var nights: int = state.sowing_nights(tree.root.get_node("ItemManager").get_crop("wheat"))
	for night in nights:
		for cell: Vector2i in [PUBLIC, PRIVATE_WHEAT]:
			await _plot(cell)
		await _advance_night()
	var tribute: int = state.king_storage
	for cell: Vector2i in [PUBLIC, PRIVATE_WHEAT]:
		await _plot(cell)
	_expect(state.king_storage == tribute + 1 and state.crop_stock.count("wheat") == 1,
		"The public wheat enters tribute and only the private harvest becomes fodder material.")

func _winter_feed() -> bool:
	await _winter_wheat()
	while state.current_day < 22 and not failed:
		await _advance_night()
	if not _expect(state.sheepfold.fodder == 0 and state.sheepfold.wool_nights == 4
		and state.sheepfold.last_feed == Sheepfold.Feed.FODDER, "Three winter nights used the three bought portions."):
		return false
	await _button(ui.hud.rations_button)
	var plan := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(plan != null and plan.sheep_note.visible and "缺草" in plan.sheep_note.text,
		"The bedtime forecast identifies the coming shortage."):
		return false
	await _snapshot("03-winter-forecast")
	await _button(plan.close_button)
	await _advance_night()
	_expect(state.sheepfold.wool_nights == 4 and state.sheepfold.last_feed == Sheepfold.Feed.SHORTAGE,
		"One unfed night pauses growth.")
	await _walk_to_pen()
	var panel := await _open_pen()
	if panel == null:
		return false
	var tribute: int = state.king_storage
	var rations: int = state.food_storage
	var copper: int = state.money
	await _button(panel.mix_fodder)
	_expect(state.crop_stock.count("wheat") == 0 and state.sheepfold.fodder == 3 and state.king_storage == tribute
		and state.food_storage == rations and state.money == copper and panel.shear.disabled,
		"Mixing fodder spends one private wheat and leaves the king's grain, rations and copper in place.")
	await _snapshot("04-fodder-mixed")
	await _key(KEY_ESCAPE)
	_watch(0.34)
	await _snapshot("04b-winter-sheep")
	await _advance_night()
	_expect(state.current_day == 24 and state.sheepfold.wool_nights == 5 and state.sheepfold.fodder == 2,
		"A fed night resumes growth and spends one portion.")
	var record: Dictionary = state.sheepfold.save_record()
	if not _expect(state.save_game() == OK, "Save the winter feed checkpoint."):
		return false
	await _continue()
	_expect(state.sheepfold.save_record() == record and world.get_node("SheepfoldPen/Paddock/Trough/Fodder").is_visible_in_tree(),
		"Continue restores both the feed record and the full trough.")
	print("SHEEP_WINTER day=", state.current_day, " wool_nights=", state.sheepfold.wool_nights, " fodder=", state.sheepfold.fodder)
	return not failed

func _grow_and_shear(capture: bool) -> bool:
	while state.sheepfold.wool_nights < state.balance.sheep_wool_nights and not failed:
		if not _expect(state.sheep_feed(state.sheepfold.fodder) != Sheepfold.Feed.SHORTAGE, "This clip has enough pasture or fodder."):
			return false
		var rainy: bool = state.has_rain()
		var fodder: int = state.sheepfold.fodder
		await _advance_night()
		if rainy:
			_expect(state.sheepfold.last_feed == Sheepfold.Feed.FODDER and state.sheepfold.fodder == fodder - 1,
				"The spring rain uses the remaining fodder instead of pasture.")
	await _walk_to_pen()
	var pen: Node2D = world.get_node("SheepfoldPen")
	_watch(0.35)
	await tree.create_timer(0.15).timeout
	var grown_texture: Texture2D = pen.animal.texture
	if capture:
		await _snapshot("05-wool-ready")
	var panel := await _open_pen()
	if panel == null:
		return false
	var wool: int = state.sheepfold.wool
	await _button(panel.shear)
	_expect(state.sheepfold.wool == wool + 1 and state.sheepfold.wool_nights == 0
		and panel.shear.disabled and pen.animal.texture != grown_texture and not pen.get_node("Paddock/Wool").visible,
		"Shearing takes exactly one full coat and starts regrowth.")
	if DisplayServer.get_name() != "headless":
		var bleat: bool = pen.animal.get_parent().get_children().any(func(node: Node): return node is AudioStreamPlayer2D and node.stream == pen.BLEAT)
		_expect(bleat, "Shearing starts the recorded sheep sound.")
	await _key(KEY_ESCAPE)
	if capture:
		await _snapshot("06-after-shear")
	print("SHEEP_SHEAR day=", state.current_day, " wool=", state.sheepfold.wool)
	return not failed

func _sell_then_continue() -> bool:
	var copper: int = state.money
	if not _expect(state.save_game() == OK, "Save the first clip before deciding how to use it."):
		return false
	var trade := await _open_sheep_trade()
	if trade == null:
		return false
	await _button(trade.sell_wool)
	_expect(state.sheepfold.wool == 0 and state.money == copper + state.balance.sheep_wool_price
		and not state.can_wear_attire(PlayerAttire.WOOL), "Selling the first clip pays the listed price.")
	print("SHEEP_SOLD day=", state.current_day, " copper=", copper, "->", state.money)
	await _key(KEY_ESCAPE)
	await _continue()
	return _expect(state.sheepfold.wool == 1 and state.money == copper, "Continue can take the keep-wool branch.")

func _wear_coat() -> void:
	var trade := await _open_sheep_trade()
	if trade == null:
		return
	var copper: int = state.money
	await _button(trade.weave_coat)
	_expect(state.sheepfold.wool == 0 and state.money == copper and state.can_wear_attire(PlayerAttire.WOOL),
		"Two saved clips unlock the wool coat.")
	await _snapshot("07-coat-order")
	if not await _return_from_market():
		return
	var yard: Marker2D = world.get_node("HallRest/Yard")
	await _walk(world.player, [Vector2(-181, 15), Vector2(-181, 48), Vector2(-96, 48), yard.global_position])
	if not await _cross(&"ui_up", state.ESTATE_SCENE):
		return
	if not _expect(state.estate_room == state.EstateRoom.HALL, "Walk through the hall doorway to the wardrobe."):
		return
	var room: Node2D = world.get_node("HallInterior")
	await _walk(world.player, [room.to_global(Vector2(0, 33)), room.to_global(Vector2(-52, 33))])
	await _key(KEY_E)
	var wardrobe := ui.get_node("Control/WardrobePanel") as Control
	if not _expect(wardrobe.modal.visible, "E at the clothes rack opens the wardrobe."):
		return
	await _button(wardrobe.rows[PlayerAttire.WOOL])
	await _snapshot("08-wardrobe")
	await _button(wardrobe.apply_button)
	_expect(state.attire_id == PlayerAttire.WOOL and world.player.sprite.texture.region == Rect2(0, 576, 96, 96),
		"The player wears the commissioned coat.")
	await _snapshot("09-wearing-wool")
	_expect(state.save_game() == OK, "Save while wearing the coat.")
	await _continue()
	_expect(state.estate_room == state.EstateRoom.HALL and state.attire_id == PlayerAttire.WOOL
		and state.sheepfold.coat and state.king_storage == 2, "Continue preserves the coat, flock, and two public harvests.")
	print("SHEEP_COAT day=", state.current_day, " attire=", state.attire_id, " tribute=", state.king_storage)

func _walk_to_meadow(road: Node2D) -> void:
	var route: PackedVector2Array = road.network.route_between(road.player.position, road.ground.LAYOUT.MEADOW)
	_expect(route.has(road.ground.LAYOUT.MEADOW_JUNCTION), "The grass clearing connects to the road at its own junction.")
	for point: Vector2 in route.slice(1):
		await Campaign.walk_straight(tree, road.player, point)
	var spot := road.get_node("FodderMeadow") as Node2D
	_expect(road.player.position.distance_to(spot.position) < 3.0 and road.player.interaction_target == spot,
		"Walk down the spur and reach the actual cutting site.")

func _back_from_meadow(road: Node2D) -> bool:
	var arrival := road.get_node("EstateArrival") as Marker2D
	var route: PackedVector2Array = road.network.route_between(road.player.position, arrival.position)
	for point: Vector2 in route.slice(1):
		await Campaign.walk_straight(tree, road.player, point)
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return false
	_estate()
	return true

func _cut_summer_meadow(portions: int) -> bool:
	var market := tree.current_scene
	await _key(KEY_ESCAPE)
	await _key(KEY_M)
	var chart: Control = market.market_map
	await _button(chart.get_node("%RegionMap"))
	var overview: Control = chart.region_map
	await _button(overview.region_buttons.get_node("WestRoad"))
	await _button(overview.destination_buttons[Sheepfold.MEADOW])
	_expect(overview.route_label.text == "西市 → 溪桥道" and overview.place_detail.text == "可割草料 %d 份" % portions,
		"The market chart previews the bridge and the current harvest.")
	await _button(overview.route_button)
	_expect(chart._current_stop() == state.MARKET_RETURN and chart._destination_label(state.MARKET_RETURN) == Sheepfold.MEADOW,
		"The local market route points to the gate and names the meadow.")
	await Campaign.walk_to_market_exit(tree, market)
	if not await _cross(&"ui_right", state.WEST_ROAD_SCENE):
		return false
	var road := tree.current_scene as Node2D
	_expect(road.route.has(road.ground.LAYOUT.MEADOW_JUNCTION), "The market route continues across the bridge to the spur.")
	await _walk_to_meadow(road)
	var rain_term: String = state.balance.rain_solar_term
	state.balance.rain_solar_term = state.get_current_solar_term()
	await _key(KEY_E)
	_expect(state.meadow_status() == "等晴天再割草" and state.sheepfold.fodder == 0 and state.sheepfold.last_meadow_cut == 0,
		"Interacting in summer rain leaves the grass uncut.")
	state.balance.rain_solar_term = rain_term
	await _key(KEY_E)
	_expect(state.sheepfold.fodder == portions and state.sheepfold.last_meadow_cut == 12,
		"The dry summer harvest supplies the first feed without buying any.")
	print("MEADOW_SUMMER cut_day=", state.sheepfold.last_meadow_cut, " stock=", state.sheepfold.fodder)
	return await _back_from_meadow(road)

func _verify_meadow_seasons() -> void:
	var portions: int = state.balance.sheep_meadow_yield
	var tribute: int = state.king_storage
	var stock: int = state.player_inventory
	var money: int = state.money
	if not await _cut_summer_meadow(portions):
		return
	await _advance_night()
	_watch(0.34)
	var cut_day: int = state.current_day
	_expect(cut_day == 13 and state.meadow_has_grass() and state.sheepfold.last_feed == Sheepfold.Feed.PASTURE,
		"Grass regrows across the summer to autumn boundary.")
	await _guide_pen()
	await _walk_to_pen()
	var pen_panel := await _open_pen()
	if pen_panel == null:
		return
	_expect(pen_panel.meadow_status.text == "可割草料 %d 份" % portions,
		"The pen names the current meadow harvest before leaving.")
	await _snapshot("10-meadow-pen")
	await _button(pen_panel.meadow)
	_expect(state.market_trip_target == Sheepfold.MEADOW and ui.directions.tracked_place == Sheepfold.MEADOW
		and not pen_panel.modal.visible, "Follow directions from the sheepfold to the west gate.")
	await Campaign.walk_estate_road_to(tree, world, world.get_node("WestMarketArrival").global_position)
	if not await _cross(&"ui_left", state.WEST_ROAD_SCENE):
		return
	var road := tree.current_scene as Node2D
	await tree.process_frame
	_expect(road.route.has(road.ground.LAYOUT.MEADOW_JUNCTION) and road.route[-1] == road.ground.LAYOUT.MEADOW,
		"Crossing the gate continues to the grass rather than through the market.")
	await _key(KEY_M)
	var overview: Control = road.region_map
	_expect(overview.selected_place == Sheepfold.MEADOW and overview.place_detail.text == "可割草料 %d 份" % portions,
		"The active regional waypoint displays the harvest status.")
	await _snapshot("11-meadow-map")
	await _key(KEY_M)
	_expect(state.save_game() == OK, "Save the uncut meadow's active route on the bridge road.")
	await _resume()
	road = tree.current_scene
	if not _expect(road.scene_file_path == state.WEST_ROAD_SCENE and state.market_trip_target == Sheepfold.MEADOW,
		"Continuing at the bridge road restores the meadow route."):
		return
	await _walk_to_meadow(road)
	await _snapshot("12-uncut-autumn-grass")
	await _key(KEY_E)
	_expect(state.sheepfold.fodder == portions * 2 and state.sheepfold.last_meadow_cut == cut_day
		and state.market_trip_target.is_empty() and state.last_forage_day != cut_day,
		"Cutting adds the quoted feed once, clears the route, and leaves the ravine forage allowance.")
	await _snapshot("13-cut-grass")
	await _key(KEY_E)
	_expect(state.sheepfold.fodder == portions * 2 and state.player_inventory == stock
		and state.money == money and state.king_storage == tribute, "Cut grass spends no wheat, tribute or copper.")
	_expect(state.save_game() == OK, "Save after cutting grass while still on the bridge road.")
	await _resume()
	road = tree.current_scene
	if not _expect(road.scene_file_path == state.WEST_ROAD_SCENE and state.sheepfold.fodder == portions * 2
		and state.sheepfold.last_meadow_cut == cut_day, "Continue preserves the feed and the cut meadow."):
		return
	await _walk_to_meadow(road)
	await _key(KEY_E)
	_expect(state.sheepfold.fodder == portions * 2 and "本季已收" in road.get_node("FodderMeadow/Hint").text,
		"Reentering the meadow does not refill it in the same season.")
	if not await _back_from_meadow(road):
		return
	while state.current_day < 19 and not failed:
		await _advance_night()
	_expect(state.sheepfold.last_feed == Sheepfold.Feed.PASTURE, "The final autumn evening still uses pasture.")
	await _advance_night()
	_expect(state.current_day == 20 and state.sheepfold.fodder == portions * 2 - 1
		and state.sheepfold.last_feed == Sheepfold.Feed.FODDER, "The first winter evening uses one portion of the meadow grass.")
	await _walk_to_pen()
	pen_panel = await _open_pen()
	if pen_panel:
		_expect(not state.meadow_has_grass() and pen_panel.meadow_status.text == "夏秋可割草"
			and "昨夜  用草料 1 份" in pen_panel.forecast.text, "The pen shows winter dormancy and last night's feed.")
		await _snapshot("14-meadow-winter-feed")
		await _key(KEY_ESCAPE)
	print("MEADOW_WINTER cut_day=", state.sheepfold.last_meadow_cut, " fed_day=", state.current_day - 1,
		" stock=", state.sheepfold.fodder, " tribute=", state.king_storage)

func _play() -> void:
	await _button(tree.current_scene.new_button)
	_estate()
	_expect(not world.get_node("SheepfoldPen").visible and not state.sheepfold.owned(), "The pasture is empty in a fresh campaign.")
	await _harvest(world, ui)
	state.current_day = 12 if meadow_only else 18
	state.money = 134
	state.food_storage = 64
	state.reputation = 140
	state.balance.raid_first_day = 1000
	tree.root.get_node("GameEvents").day_advanced.emit(state.current_day)
	if meadow_only:
		_expect(state.meadow_has_grass() and not state.can_cut_meadow_grass(), "Harvest requires a sheep even in summer.")
	if not await _buy_sheep(not meadow_only):
		return
	if meadow_only:
		await _verify_meadow_seasons()
		return
	if not await _return_from_market():
		return
	await _test_pasture()
	if await _winter_feed() and await _grow_and_shear(true) and await _sell_then_continue() and await _grow_and_shear(false):
		await _wear_coat()

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated sheepfold profile."):
		tree.quit(1)
		return
	capture_dir = OS.get_environment("FIEFDOM_SHEEP_CAPTURES")
	state = tree.root.get_node("Global")
	tree.root.notify_mouse_entered()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _play()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
