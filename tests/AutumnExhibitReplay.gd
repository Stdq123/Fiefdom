extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const SPRING_PLOTS := {
	KEY_5: [Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6)],
	KEY_1: [Vector2i(5, 4), Vector2i(5, 5), Vector2i(6, 4)],
	KEY_7: [Vector2i(6, 5)],
}
const FALL_PLOTS := [Vector2i(5, 5), Vector2i(6, 4)]
const PUBLIC_PLOT := Vector2i(5, 5)
const CHOSEN := ["millet", "beans", "sorghum"]

var tree: SceneTree
var state: Node
var world: Node2D
var ui: CanvasLayer
var capture_dir := ""
var failed := false

func _expect(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		push_error(message)
	return ok

func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		tree.root.push_input(event, true)
		await tree.process_frame

func _click(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		tree.root.push_input(event, true)
		await tree.process_frame

func _button(button: Button) -> void:
	await tree.process_frame
	if _expect(button.is_visible_in_tree() and not button.disabled
		and tree.root.get_visible_rect().encloses(button.get_global_rect()), "Use the visible control " + button.text):
		await _click(button.get_global_rect().get_center())

func _snapshot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await tree.create_timer(0.22).timeout
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Save the frame " + name)
	print("AUTUMN_FRAME ", name, " window=", tree.root.size, " image=", image.get_size())

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")

func _night() -> void:
	await _button(ui.sleep_button)
	await tree.create_timer(1.12).timeout

func _plot(cell: Vector2i) -> void:
	var tiles := world.tile_map as TileMapLayer
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))

func _grow(planting: Dictionary, nights: int) -> void:
	for key: Key in planting:
		await _key(key)
		for cell: Vector2i in planting[key]:
			if not state.tilled_cells.has(cell):
				await _plot(cell)
			await _plot(cell)
	for night in nights:
		for plots: Array in planting.values():
			for cell: Vector2i in plots:
				if world.is_crop_dry(cell):
					await _plot(cell)
		await _night()
	for plots: Array in planting.values():
		for cell: Vector2i in plots:
			if _expect(world.is_crop_ripe(cell), "Ripen the crop by tending it each day."):
				await _plot(cell)

func _walk(actor: Player, stops: Array) -> void:
	for point: Vector2 in stops:
		await Campaign.walk_to(tree, actor, point)

func _cross(action: StringName, destination: String) -> bool:
	return _expect(await Campaign.walk_through_gates(tree, action, destination, 52), "Take the west road to " + destination)

func _deliver_spring() -> bool:
	await _walk(world.player, [Vector2(-181, 60), Vector2(-181, 0), Vector2(-270, -21)])
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return false
	var market := tree.current_scene as Node2D
	await Campaign.walk_market_to(tree, market, market.market_map.places["收货牌"])
	await _key(KEY_E)
	if not _expect(market.counter.orders.is_visible_in_tree(), "Open the spring order at its market stand."):
		return false
	await _button(market.counter.orders.food_button)
	_expect(state.player_inventory == 3 and state.food_storage == 13 and state.king_storage == 1,
		"The order feeds the estate for autumn preparation and leaves three varieties in private stock.")
	await _key(KEY_ESCAPE)
	await Campaign.walk_to_market_exit(tree, market)
	if not await _cross(&"ui_right", state.ESTATE_SCENE):
		return false
	_estate()
	await _walk(world.player, [Vector2(-181, 0), Vector2(-181, 65), Vector2(31, 65), Vector2(66, 98)])
	return not failed

func _defend() -> void:
	await _walk(world.player, [Vector2(137, 121)])
	var previous: int = state.raids_defeated
	for shot in 9:
		var enemy := tree.get_first_node_in_group("estate_raiders") as Node2D
		if not enemy:
			break
		world.player.shoot_arrow(enemy.global_position)
		await tree.create_timer(0.48).timeout
	_expect(state.raids_defeated == previous + 1 and state.outcome == state.Outcome.RUNNING,
		"Defend the estate with normal arrows during seasonal preparations.")
	await _walk(world.player, [Vector2(66, 98)])

func _tend_public_plot() -> void:
	if world.is_crop_ripe(PUBLIC_PLOT):
		await _plot(PUBLIC_PLOT)
	if not state.active_crops.has(PUBLIC_PLOT) and state.current_day < 11:
		await _key(KEY_1)
		if not state.tilled_cells.has(PUBLIC_PLOT):
			await _plot(PUBLIC_PLOT)
		await _plot(PUBLIC_PLOT)
	if world.is_crop_dry(PUBLIC_PLOT):
		await _plot(PUBLIC_PLOT)

func _calendar_preview() -> void:
	await _key(KEY_C)
	var book: Control = ui.calendar
	_expect(tree.paused and book.modal.visible, "C opens the almanac and pauses the estate.")
	await _button(book.seasons.get_node("Autumn"))
	await _button(book.dates.get_child(3))
	_expect("第 16 天" in book.title.text and "三种不同的私田作物" in book.event_note.text and "稷 · 2 夜" in book.planting.text,
		"On day one the almanac gives the date, crops and place needed for the autumn event.")
	await _snapshot("01-almanac-autumn")
	await _button(book.guide)
	var approach: Marker2D = world.get_node("AutumnExhibit/Approach")
	_expect(not tree.paused and ui.directions.tracked_place == "秋社展台"
		and ui.directions.tracked_place_point == world.to_local(approach.global_position),
		"Before the festival the almanac guides players to the same clearing.")
	ui.directions.clear_tracking()

func _buy_grain_buffer() -> void:
	await _button(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	management.show_market()
	var market: Control = management.market_panel
	var grain: int = state.food_storage
	var copper: int = state.money
	var samples: int = state.player_inventory
	market.quantity.value = 5
	await _button(market.buy_button)
	_expect(state.food_storage == grain + 5 and state.money == copper - 5 * state.balance.market_food_price
		and state.player_inventory == samples, "Buy five grain rather than eating the stored samples before winter.")
	await _button(management.close_button)

func _prepare_autumn() -> void:
	var notice: Button = ui.hud.season_event_button
	_expect(notice.visible and "3 天后 秋社 · 谷样 2/3" in notice.text,
		"The stock shortage appears three nights early on the ordinary calendar.")
	await _snapshot("01d-autumn-notice")
	await _button(notice)
	var book: Control = ui.calendar
	_expect(tree.paused and book.modal.visible and "秋分" in book.title.text
		and "仓中有 黍、菽 · 还差 1 种" in book.event_note.text
		and "今日播 稷、麦" in book.event_note.text and not "可收私田" in book.event_note.text,
		"The reminder opens on the event date and includes missing crops that can ripen in time.")
	_expect(tree.root.gui_get_focus_owner() == book.close_button and ui.directions.tracked_place.is_empty(),
		"Opening the notice puts focus in the almanac without setting a route.")
	await _snapshot("01e-autumn-plan")
	await _key(KEY_ESCAPE)
	await _key(KEY_C)
	_expect(book.modal.visible and "秋分" in book.title.text, "The keyboard shortcut opens the advertised event too.")
	await _key(KEY_ESCAPE)
	print("AUTUMN_PREP day=", state.current_day, " shortage=1 sown=稷")

func _walk_to_exhibit() -> void:
	var approach := world.get_node("AutumnExhibit/Approach") as Marker2D
	await Campaign.walk_estate_road_to(tree, world, approach.global_position)

func _visit_clearing() -> void:
	await _key(KEY_M)
	var map: Control = ui.estate_map
	var south_pond: Button
	for row: Button in map.row_buttons:
		if map.row_buttons[row].title == EstateLayout.FESTIVAL_SITE_NAME:
			south_pond = row
			break
	if not _expect(south_pond != null, "The regular estate map offers the South Pond clearing before the fair."):
		return
	map.scroll.ensure_control_visible(south_pond)
	await _button(south_pond)
	_expect(map.target.point == EstateLayout.FESTIVAL_APPROACH and map.road_path.has(EstateLayout.FESTIVAL_BANK_BEND),
		"The ordinary map guides around the pond to the same stone clearing used by the fair.")
	await _key(KEY_ESCAPE)
	await _walk_to_exhibit()
	var landscape: Node2D = world.get_node("Landscape")
	_expect(world.player.position.distance_to(EstateLayout.FESTIVAL_APPROACH) < 4.0
		and ui.directions.tracked_place.is_empty() and not world.get_node("AutumnExhibit").visible
		and not world.get_node("WinterSupper").visible, "The clearing remains walkable between festivities.")
	_expect(landscape._surface_at(world.player.position) == landscape.TERRAIN_AUDIO.Surface.STONE,
		"The square returns stone footfalls even before the market stand is installed.")
	await _snapshot("01f-ordinary-clearing")
	await Campaign.walk_estate_road_to(tree, world, world.to_global(Vector2(66, 98)))

func _verify_south_route() -> void:
	var stand := world.get_node("AutumnExhibit") as Node2D
	var approach := stand.get_node("Approach") as Marker2D
	var landscape: Node2D = world.get_node("Landscape")
	await _key(KEY_M)
	var map: Control = ui.estate_map
	_expect(map.modal.visible and map.road_path.has(EstateLayout.BAMBOO_BEND)
		and map.road_path.has(EstateLayout.PAVILION_TURN) and map.road_path.has(EstateLayout.SOUTH_FORK)
		and map.road_path.has(EstateLayout.FESTIVAL_FORK) and map.road_path.has(EstateLayout.FESTIVAL_BANK_BEND)
		and map.target.point == approach.position + stand.position and map.captions.has("秋社展台"),
		"The almanac route passes the hearth and follows the west bank to the clearing.")
	await _snapshot("01a-south-road-map")
	await _key(KEY_ESCAPE)
	var origin: Vector2 = world.player.position
	var start := Engine.get_physics_frames()
	await Campaign.walk_estate_road_to(tree, world, world.to_global(EstateLayout.BAMBOO_BEND))
	_expect(world.player.position.distance_to(EstateLayout.BAMBOO_BEND) < 4.0
		and landscape._surface_at(world.player.position) == landscape.TERRAIN_AUDIO.Surface.TRACK,
		"Follow the path out of the fields to the bamboo bend.")
	var frames := Engine.get_physics_frames() - start
	await _snapshot("01aa-bamboo-lane")
	start = Engine.get_physics_frames()
	await Campaign.walk_estate_road_to(tree, world, world.to_global(EstateLayout.PAVILION_TURN))
	_expect(world.player.position.distance_to(EstateLayout.PAVILION_TURN) < 4.0,
		"The pavilion has its own arrival beyond the grove.")
	frames += Engine.get_physics_frames() - start
	print("SOUTH_PAVILION_WALK from=", origin, " seconds=", frames / float(Engine.physics_ticks_per_second))
	await _snapshot("01ab-pavilion-turn")
	await Campaign.walk_estate_road_to(tree, world, world.to_global(EstateLayout.SOUTH_FORK))
	_expect(world.player.position.distance_to(EstateLayout.SOUTH_FORK) < 4.0,
		"Continue past the pavilion to reach the unloading and pasture fork.")
	await _snapshot("01b-south-fork")
	var travelled := 0.0
	var walking_frames := 0
	for point: Vector2 in EstateLayout.HEARTH_LANE.slice(1) + EstateLayout.FESTIVAL_LANE.slice(1):
		travelled += world.player.position.distance_to(point)
		start = Engine.get_physics_frames()
		await Campaign.walk_straight(tree, world.player, point)
		walking_frames += Engine.get_physics_frames() - start
		var surface: int = landscape._surface_at(world.player.position)
		_expect(world.player.position.distance_to(point) < 3.0
			and surface in [landscape.TERRAIN_AUDIO.Surface.STONE, landscape.TERRAIN_AUDIO.Surface.TRACK],
			"The route follows dirt or stone at each turn.")
		if point == EstateLayout.FESTIVAL_BANK_BEND:
			await _snapshot("01c-south-pond")
			await Campaign.walk_straight(tree, world.player, point + Vector2(74, 0))
			var shore: Vector2 = world.player.position
			_expect(shore.x > point.x + 12.0 and shore.x < 175.0,
				"The player can reach the shore and stops at the painted waterline.")
			await Campaign.walk_straight(tree, world.player, point)
			print("SOUTH_POND_SHORE ", shore)
	_expect(travelled > 650.0 and world.player.interaction_target == stand,
		"The pond separates the festival ground from the fork, and the path reaches the table.")
	_expect(landscape._surface_at(world.player.position) == landscape.TERRAIN_AUDIO.Surface.STONE,
		"Arrival at the autumn stand uses the paved surface for footsteps.")
	print("SOUTH_FESTIVAL_WALK fork_to_stand=", roundi(travelled),
		" seconds=", walking_frames / float(Engine.physics_ticks_per_second), " arrival=", world.player.position)

func _open_and_select() -> bool:
	await _key(KEY_E)
	var panel: Control = ui.autumn_exhibit_panel
	if not _expect(tree.paused and panel.modal.visible and panel.take.disabled and panel.crop_buttons["rice"].disabled,
		"At the exhibit, E opens the chooser with only stocked varieties available."):
		return false
	for id: String in CHOSEN:
		await _button(panel.crop_buttons[id])
	return _expect(panel.selected == CHOSEN and not panel.take.disabled and not panel.share.disabled and panel.crop_buttons["hemp"].disabled,
		"Select exactly three distinct crops before committing.")

func _continue() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	_estate()

func _samples_visible(stand: Node2D) -> int:
	return stand.samples.get_children().filter(func(sample: Sprite2D): return sample.visible).size()

func _parcel_count(stand: Node2D) -> int:
	return stand.guests.get_children().filter(func(guest: Node2D): return guest.parcel.visible).size()

func _set_clock(progress: float) -> void:
	state.day_progress = progress
	tree.root.get_node("GameEvents").daylight_changed.emit()

func _follow_harvester(guest: Node2D) -> void:
	await _key(KEY_M)
	var map: Control = ui.estate_map
	await _button(map.tabs.get_node("People"))
	for row: Button in map.row_buttons:
		if map.row_buttons[row].title == guest.speaker:
			map.scroll.ensure_control_visible(row)
			await _button(row)
			break
	_expect(ui.directions.tracked_neighbor == guest.speaker and world.neighbor_actor(guest.speaker) == guest,
		"The estate map points to the festival neighbor's current location.")
	await _key(KEY_ESCAPE)
	var south: float = world.get_node("AutumnExhibit").position.y + 76.0
	await _walk(world.player, [Vector2(world.player.position.x, south), Vector2(guest.global_position.x, south),
		guest.global_position + Vector2(0, 12)])
	await _key(KEY_E)
	var dialogue := ui.get_node_or_null("Control/DialoguePanel") as Control
	if _expect(dialogue != null and dialogue.name_label.text == guest.speaker and "稷" in dialogue.text_label.text
		and "冬至" in dialogue.text_label.text and "一份菽" in dialogue.text_label.text
		and ui.directions.tracked_neighbor.is_empty(), "The marked neighbor talks about the crop they received."):
		var portrait := dialogue.portrait.texture as AtlasTexture
		_expect(guest.speaker == WinterSupper.HOST and portrait != null and portrait.atlas.resource_path == CharacterArt.TOWN_PORTRAITS
			and portrait.region == Rect2(48, 48, 48, 48), "He Bo has the same portrait at the harvest table and winter supper.")
		await _snapshot("07-harvest-dialogue")
		await _button(dialogue.options_container.get_child(0))

func _festival() -> void:
	var stand := world.get_node("AutumnExhibit") as Node2D
	var first: Node2D = stand.guests.get_child(0)
	_expect(stand.visible and "今日秋社 · 谷样 3/3" in ui.hud.season_event_button.text,
		"The table and the stocked notice appear at the Autumn Equinox.")
	_expect(not first.visible, "The first guest starts the day offsite.")
	await _button(ui.hud.season_event_button)
	await _button(ui.calendar.guide)
	_expect(ui.directions.tracked_place == "秋社展台", "The current event points to the actual approach.")
	await _verify_south_route()
	_expect(ui.directions.tracked_place.is_empty(), "The waypoint clears at the front of the table.")
	_set_clock(0.09)
	await tree.create_timer(0.1).timeout
	var road_position := first.position
	await tree.create_timer(0.6).timeout
	_expect(first.visible and first.motion.walking and first.position.x > road_position.x + 1.0,
		"The first guest walks east along the road as the game clock advances.")
	await _snapshot("00-arrival")
	_set_clock(0.30)
	await tree.create_timer(0.1).timeout
	if not _expect(state.save_game() == OK, "Save a checkpoint before choosing what to do with the samples."):
		return
	var stock: int = state.player_inventory
	var tribute: int = state.king_storage
	var reputation: int = state.reputation
	var rites: int = state.player_stats.stats["RITES"]["xp"]
	state.pin_season_order(true, true)
	if not await _open_and_select():
		return
	var panel: Control = ui.autumn_exhibit_panel
	_expect(panel.tradeoff.visible and "东岗秋粮" in panel.tradeoff.text and "稷 1、菽 1" in panel.tradeoff.text
		and "黍 1" not in panel.tradeoff.text and "冬路粮与麻" not in panel.tradeoff.text,
		"The fair previews the additional loss of autumn cargo if the samples are shared.")
	await _button(panel.crop_buttons["beans"])
	await _button(panel.crop_buttons["hemp"])
	_expect("冬路粮与麻" in panel.tradeoff.text and "麻 1" in panel.tradeoff.text and "菽 1" not in panel.tradeoff.text,
		"Replacing beans with hemp updates both the autumn and tracked winter reservations.")
	await _button(panel.crop_buttons["hemp"])
	await _button(panel.crop_buttons["beans"])
	await _snapshot("02-choose-samples")
	await _button(ui.autumn_exhibit_panel.take)
	_expect(state.player_inventory == stock and state.reputation == reputation
		and not state.winter_supper_bean_gift(22)
		and state.player_stats.stats["RITES"]["xp"] == rites + state.balance.autumn_exhibit_rites,
		"Taking samples home keeps the crops and grants rites experience without promising a winter gift.")
	_expect(_samples_visible(stand) == 3, "Taking crops home still shows the three samples.")
	await tree.create_timer(AutumnExhibit.DISPLAY_SECONDS + 0.12).timeout
	_expect(_samples_visible(stand) == 0 and _parcel_count(stand) == 0, "Only the shared crops go to neighbors.")
	print("AUTUMN_TAKE day=", state.current_day, " crops=", state.player_inventory, " rites=", state.player_stats.stats["RITES"]["xp"])
	await _continue()
	await _walk_to_exhibit()
	_set_clock(0.12)
	await tree.create_timer(0.1).timeout
	if not await _open_and_select():
		return
	await _button(ui.autumn_exhibit_panel.share)
	stand = world.get_node("AutumnExhibit")
	var receipt: Dictionary = state.autumn_exhibit_record(state.current_day)
	_expect(receipt.crops == CHOSEN and receipt.shared and state.player_inventory == stock - 3
		and state.reputation == reputation + state.balance.autumn_share_reputation and state.king_storage == tribute,
		"Sharing pays for the three samples once and leaves public tribute intact.")
	for sample: Sprite2D in stand.get_node("Samples").get_children():
		_expect(sample.visible and sample.texture != null, "The chosen crop art appears on each tray.")
	await tree.create_timer(0.35).timeout
	_expect(stand.display_time == 0.0 and _samples_visible(stand) == 3 and _parcel_count(stand) == 0,
		"Samples wait on the table when the player shares them before all neighbors arrive.")
	_set_clock(0.30)
	await tree.create_timer(0.1).timeout
	var first_guest: Node2D = stand.guests.get_child(0)
	var spot := first_guest.position
	await _snapshot("03-autumn-exhibit")
	await tree.create_timer(1.68 - stand.display_time).timeout
	_expect(first_guest.position.x > spot.x + 10.0 and _parcel_count(stand) == 1 and _samples_visible(stand) == 2,
		"The first neighbor approaches and removes one sample before the other two.")
	_expect(stand.hint.visible, "At the table's approach the exhibit remains in focus during handoff.")
	await _snapshot("05-first-handoff")
	await tree.create_timer(AutumnExhibit.HANDOFF_SECONDS - stand.display_time + 0.12).timeout
	_expect(_samples_visible(stand) == 0 and _parcel_count(stand) == 3, "All three shared crops leave the trays.")
	print("AUTUMN_SHARE day=", state.current_day, " crops=", state.player_inventory, " reputation=", state.reputation - reputation,
		" tribute=", state.king_storage)
	await _key(KEY_E)
	var book: Control = ui.autumn_exhibit_panel
	_expect(book.modal.visible and not book.crops.visible and "今年摆过" in book.selection.text
		and "阿绥一份黍，林蓼一份菽，禾伯一份稷" in book.introduction.text,
		"The exhibit ledger names each crop's recipient and offers no repeated reward.")
	await _key(KEY_ESCAPE)
	var last_guest: Node2D = stand.guests.get_child(2)
	var afternoon := last_guest.position
	_set_clock(0.88)
	await tree.create_timer(0.12).timeout
	_expect(last_guest.position.y > afternoon.y + 10.0 and stand.get_node("Lanterns").get_child(1).glow.enabled,
		"After dusk the neighbors gather by the lit mat.")
	await _snapshot("06-festival-dusk")
	await _follow_harvester(last_guest)
	_expect(state.save_game() == OK, "Save the finished exhibit.")
	await _continue()
	stand = world.get_node("AutumnExhibit")
	_expect(state.autumn_exhibit_record(state.current_day) == receipt and state.player_inventory == stock - 3,
		"Continue restores the ledger and settled stock.")
	_expect(_samples_visible(stand) == 0 and _parcel_count(stand) == 3 and state.day_progress >= 0.88,
		"Continue shows the settled handoff at the saved time.")
	print("AUTUMN_GATHERING attendees=", stand.guests.get_child_count(), " parcels=", _parcel_count(stand), " dusk=", state.day_progress)
	await _night()
	_expect(not world.get_node("AutumnExhibit").visible and not ui.hud.season_event_button.visible,
		"The stage closes after its solar term.")
	await _key(KEY_C)
	await _button(ui.calendar.dates.get_child(3))
	_expect("秋社已入簿" in ui.calendar.event_note.text and "已分给乡邻" in ui.calendar.event_note.text
		and not ui.calendar.guide.visible, "The almanac shows the past festival and its outcome.")
	await _snapshot("04-exhibit-record")
	await _button(ui.calendar.seasons.get_node("Winter"))
	await _button(ui.calendar.dates.get_child(3))
	_expect("禾伯出菽" in ui.calendar.event_note.text and state.winter_supper_bean_gift(22)
		and not state.winter_supper_bean_gift(46),
		"The almanac previews the contribution for this year's solstice alone.")
	await _key(KEY_ESCAPE)

func _play() -> void:
	await _button(tree.current_scene.new_button)
	_estate()
	_expect(not world.get_node("AutumnExhibit").visible, "No stage obstructs the path before autumn.")
	await _calendar_preview()
	await _grow(SPRING_PLOTS, 2)
	if failed or not await _deliver_spring():
		return
	await _button(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	management.show_market()
	var market: Control = management.market_panel
	market.crop_choice.select(CropStock.IDS.find("hemp") + 1)
	market.crop_choice.item_selected.emit(market.crop_choice.selected)
	await _button(market.convert_button)
	_expect(state.crop_stock.count("hemp") == 0, "Use the early hemp as a meal, leaving two autumn varieties.")
	await _button(management.close_button)
	while state.current_day < 13 and not failed:
		await _tend_public_plot()
		await _night()
		if state.current_day == state.balance.raid_first_day:
			await _defend()
	if failed:
		return
	await _prepare_autumn()
	await _visit_clearing()
	await _grow({KEY_2: FALL_PLOTS, KEY_7: [Vector2i(6, 5)]}, 2)
	_expect("明日秋社 · 谷样 3/3" in ui.hud.season_event_button.text,
		"Stock readiness updates after the new crop is harvested.")
	await _night()
	await _festival()

func _second_year() -> void:
	var checkpoint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.manual_save_path()))
	var previous_day := 16
	checkpoint.current_day = previous_day + state.SOLAR_TERMS.size() * state.balance.days_per_solar_term
	var path := "user://second-autumn.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(checkpoint))
	file.close()
	if not _expect(state.load_game(path) == OK, "Load the next Autumn Equinox using the real first-year receipt."):
		return
	await tree.scene_changed
	_estate()
	await _walk_to_exhibit()
	await _key(KEY_E)
	var panel: Control = ui.autumn_exhibit_panel
	_expect(panel.modal.visible and panel.crops.visible and "去年摆的黍、菽、稷" in panel.introduction.text
		and state.autumn_exhibit_record(state.current_day).is_empty() and state.autumn_exhibit_record(previous_day).shared,
		"The next year's event reopens and remembers the actual first-year crops.")
	_expect("去年分来的稷" in world.get_node("AutumnExhibit/Guests/禾伯").remark(),
		"The same neighbor remembers the crop from last year.")
	await _key(KEY_ESCAPE)
	print("AUTUMN_RETURN day=", state.current_day, " prior_receipt=", previous_day)

func _winter_return() -> void:
	if not _expect(state.current_day == 17 and state.night_rations.last.get("missed", []).is_empty(),
		"Continue to winter the day after the actual fair, with dinner supplied."):
		return
	await Campaign.walk_estate_road_to(tree, world, world.to_global(Vector2(66, 98)))
	await _defend()
	await _buy_grain_buffer()
	while not failed and state.current_day < 19:
		await _night()
	var notice: Button = ui.hud.season_event_button
	_expect(notice.visible and "3 天后 冬至围炉 · 缺麦" in notice.text,
		"The winter notice accounts for He Bo's beans and leaves time to sow wheat.")
	await _button(notice)
	_expect("禾伯出菽" in ui.calendar.event_note.text and "今日播私田麦，2 夜可收" in ui.calendar.event_note.text
		and "仓中 麦 0 · 菽 0" in ui.calendar.event_note.text and tree.paused,
		"The winter detail opens directly with the actual gift, missing wheat and preparation time.")
	await _snapshot("08-winter-plan")
	await _key(KEY_ESCAPE)
	await _grow({KEY_4: [FALL_PLOTS[1]]}, 2)
	_expect("明日冬至围炉 · 可备麦菽粥" in notice.text and state.crop_stock.count("wheat") == 1,
		"The wheat harvest makes the meal ready before the solstice.")
	await _snapshot("09-winter-ready")
	await _night()
	await _button(notice)
	await _button(ui.calendar.guide)
	_expect(not tree.paused and ui.directions.tracked_place == WinterSupper.PLACE,
		"The day-of notice gives a route to the winter table.")
	var approach := world.get_node("WinterSupper/Approach") as Marker2D
	await Campaign.walk_estate_road_to(tree, world, approach.global_position)
	_set_clock(0.76)
	await _key(KEY_E)
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialog != null and dialog.name_label.text == WinterSupper.HOST
		and "禾伯出菽" in dialog.text_label.text and state.crop_stock.count("beans") == 0,
		"He Bo can prepare the bean supper with wheat and no beans in the player's store."):
		return
	await _snapshot("10-he-bo-winter-gift")
	var tribute: int = state.king_storage
	await _button(dialog.options_container.get_child(0))
	var receipt: Dictionary = state.winter_supper_record()
	_expect(receipt.get("recipe") == WinterSupper.BEAN and receipt.get("he_bo_beans") == true
		and receipt.portions == state.balance.winter_bean_rations
		and state.crop_stock.count("wheat") == 0 and state.crop_stock.count("beans") == 0 and state.king_storage == tribute,
		"Cooking uses one private wheat and records He Bo's contribution without adding beans to stock.")
	_expect(state.save_game() == OK, "Save the winter supper with the contribution recorded.")
	await _continue()
	_expect(state.winter_supper_record() == receipt and "已备饭" in ui.hud.season_event_button.text,
		"The supper receipt and notice preserve the contribution on reload.")
	print("AUTUMN_WINTER_GIFT day=", state.current_day, " receipt=", state.winter_supper_record())
	await _night()
	_expect(state.night_rations.last.get("supper") == 1 and state.retainers.size() == 1,
		"One actual retainer supper replaces grain after cooking from the calendar plan.")

func run(game_tree: SceneTree, captures := "") -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated exhibit profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = captures if not captures.is_empty() else OS.get_environment("FIEFDOM_AUTUMN_CAPTURES")
	tree.root.notify_mouse_entered()
	seed(325)
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _play()
	if not failed:
		await _winter_return()
	if not failed and DisplayServer.get_name() == "headless":
		await _second_year()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
