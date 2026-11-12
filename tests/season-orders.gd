extends SceneTree

const Campaign := preload("res://tests/CampaignReplay.gd")
const PUBLIC := Vector2i(5, 5)
const WEST_TOP := Vector2i(4, 4)
const WEST_MIDDLE := Vector2i(4, 5)
const WEST_BOTTOM := Vector2i(4, 6)
const EAST_TOP := Vector2i(6, 4)
const EAST_MIDDLE := Vector2i(6, 5)

var failed := false
var state: Node
var world: Node
var ui: Node

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _estate() -> void:
	world = current_scene.get_node("World")
	ui = current_scene.get_node("UI")

func _click(control: Control) -> void:
	await _click_at(control.get_global_rect().get_center())

func _click_at(position: Vector2) -> void:
	var pointer := InputEventMouseMotion.new()
	pointer.position = position
	pointer.global_position = position
	root.push_input(pointer, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		root.push_input(event, true)
		await process_frame

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	await process_frame

func _open_board() -> Control:
	var approach := world.get_node("SeasonBoard/Approach") as Marker2D
	await Campaign.walk_estate_road_to(self, world, approach.global_position)
	await _key(KEY_E)
	var panel: Control = ui.panel_manager.management_panel_instance
	_expect(panel != null and panel.season_order_panel.is_visible_in_tree(), "E at the unloading yard opens the delivery book.")
	return panel

func _manage(tab: int) -> Control:
	await _click(ui.manage_button)
	var panel: Control = ui.panel_manager.management_panel_instance
	panel.tabs.current_tab = tab
	await process_frame
	return panel

func _close(panel: Control) -> void:
	await _click(panel.get_node("CloseButton"))

func _sow(cell: Vector2i, crop: String) -> void:
	world.select_seed(crop)
	if world.field_action(cell) == world.FieldAction.TILL:
		world.handle_interaction(cell)
	_expect(world.field_action(cell) == world.FieldAction.SOW, "The specified plot can grow " + crop)
	world.handle_interaction(cell)

func _night() -> void:
	if world.field_action(PUBLIC) == world.FieldAction.HARVEST:
		world.handle_interaction(PUBLIC)
	if not state.active_crops.has(PUBLIC):
		_sow(PUBLIC, "millet")
	for cell in state.active_crops.keys():
		if world.field_action(cell) == world.FieldAction.WATER:
			world.handle_interaction(cell)
	if state.current_day <= 5:
		var panel := await _manage(2)
		await _click(panel.read_button)
		if state.current_day == 5:
			panel.tabs.current_tab = 3
			await process_frame
			await _click(panel.irrigation_button)
		await _close(panel)
	if state.food_storage < state.retainer_food_cost():
		var panel := await _manage(1)
		_expect(not panel.market_panel.reserve_button.disabled, "The harvest earnings can cover the household's food.")
		await _click(panel.market_panel.reserve_button)
		await _close(panel)
	var tomorrow: int = state.current_day + 1
	await _click(ui.sleep_button)
	for frame in range(240):
		if state.current_day == tomorrow and ui.fader.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return
		await process_frame
	_expect(false, "The next day must arrive before the seasonal deadline.")

func _advance_to(day: int) -> void:
	while state.current_day < day and not failed:
		await _night()

func _grow(plots: Dictionary) -> void:
	await Campaign.walk_to(self, world.player, Vector2(42, 98))
	var ripe_day: int = state.current_day
	for cell in plots:
		_sow(cell, plots[cell])
		ripe_day = maxi(ripe_day, state.current_day + state.active_crops[cell]["growth_nights"])
	await _advance_to(ripe_day)
	for cell in plots:
		_expect(world.field_action(cell) == world.FieldAction.HARVEST, "Enough watered nights ripen " + plots[cell])
		world.handle_interaction(cell)

func _connect_rice() -> void:
	_expect(state.tech_unlocked["irrigation"], "Ordinary study can unlock rice irrigation before summer.")
	await _click(ui.channel_button)
	var tiles: TileMapLayer = world.tile_map
	for cell in [Vector2i(2, 5), Vector2i(3, 5), Vector2i(3, 4)]:
		await _click_at(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))
	await _key(KEY_ESCAPE)
	_expect(state.irrigation.supplies(WEST_TOP) and state.irrigation.supplies(WEST_MIDDLE),
		"The canal really reaches both plots needed for the summer delivery.")

func _fulfil(start: int, paid_in_food: bool, amount: int) -> void:
	var panel := await _open_board()
	var book: Control = panel.season_order_panel
	var money: int = state.money
	var food: int = state.food_storage
	var reputation: int = state.reputation
	var tribute: int = state.king_storage
	var date: int = state.current_day
	var stock_before: Dictionary = state.crop_stock.lots.duplicate()
	var requested: Dictionary = state.season_order().order.need
	var button: Button = book.food_button if paid_in_food else book.copper_button
	_expect(not button.disabled and book.start_day == start and str(amount) in button.text, "The board previews the exact available reward.")
	await _click(button)
	_expect(state.money == money + (0 if paid_in_food else amount) and state.food_storage == food + (amount if paid_in_food else 0)
		and state.reputation == reputation + 5 and state.king_storage == tribute,
		"Delivery spends private stock, gives the chosen reward and honors public tribute.")
	_expect(state.season_order_delivered_at(state.season_order()) == date and book.copper_button.disabled
		and world.get_node("SeasonBoard").delivered, "The receipt and physical seal update together.")
	for row in book.cargo.get_children():
		_expect("已交" in row.get_child(1).text, "The receipt labels shipped quantities as delivered.")
	for id in stock_before:
		_expect(state.crop_stock.count(id) == stock_before[id] - requested.get(id, 0),
			"Delivery takes only the listed amount of each crop and leaves surplus in stock.")
	_expect(not state.deliver_season_order(start, not paid_in_food), "A second submission cannot take the other reward.")
	print("SEASON_DELIVERY day=", date, " order=", state.season_order().order.id, " paid=", "food" if paid_in_food else "copper", " amount=", amount)
	await _close(panel)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run season-orders with an isolated save.")
		quit(1)
		return
	state = root.get_node("Global")
	change_scene_to_file("res://scenes/Title.tscn")
	await scene_changed
	await process_frame
	await _click(current_scene.new_button)
	if current_scene == null or current_scene.name != "Main":
		await scene_changed
	_estate()
	# Focus this replay on the calendar and economy; combat has its own default-rules replay.
	state.balance.raid_first_day = 10000
	var panel := await _open_board()
	var book: Control = panel.season_order_panel
	_expect("亭前备种" in book.order_title.text and "余 6 天" in book.deadline.text and "稻 2" in book.next_details.text and book.food_button.disabled,
		"A new estate can plan spring beans and see the summer rice requirement before planting.")
	var spring_money: int = state.money
	book.copper_button.pressed.emit()
	_expect(state.money == spring_money and state.season_order_receipts.is_empty(), "An incomplete order pays nothing.")
	await _close(panel)
	await _grow({WEST_TOP: "beans", WEST_MIDDLE: "beans", WEST_BOTTOM: "millet", EAST_TOP: "wheat", EAST_MIDDLE: "hemp"})
	_expect(state.crop_stock.count("beans") == 2 and state.crop_stock.count("millet") == 1 and state.king_storage == 1
		and state.player_inventory == 5, "Crop identity survives harvest, and the public millet stays in the treasury.")
	_expect(not state.sell_crops(3, "beans") and state.player_inventory == 5, "A typed sale checks that crop, not the aggregate.")
	panel = await _manage(1)
	var market: Control = panel.market_panel
	market.quantity.value = 1
	_expect("麦 1" in market.debit_plan.text and not "黍" in market.debit_plan.text,
		"Mixed sale keeps the order's beans and millet while there is surplus wheat.")
	await _click(market.sell_button)
	var hemp_choice: int = CropStock.IDS.find("hemp") + 1
	market.crop_choice.select(hemp_choice)
	market.crop_choice.item_selected.emit(hemp_choice)
	await _click(market.convert_button)
	_expect(state.player_inventory == 3 and state.crop_stock.count("beans") == 2 and state.crop_stock.count("hemp") == 0,
		"A selected conversion takes only the named crop and keeps the order complete.")
	await _close(panel)
	await _fulfil(1, true, 5)
	_expect(state.player_inventory == 0, "The delivery consumes exactly the named ingredients.")
	_expect(state.save_game() == OK and state.load_game() == OK, "A delivery receipt can be saved and loaded.")
	await scene_changed
	_estate()
	panel = await _open_board()
	book = panel.season_order_panel
	_expect("已领口粮" in book.status.text and not state.deliver_season_order(1, false), "The restored receipt prevents a second payout.")
	await _close(panel)

	await _advance_to(7)
	await Campaign.walk_to(self, world.player, Vector2(42, 98))
	await _connect_rice()
	await _grow({WEST_TOP: "rice", WEST_MIDDLE: "rice"})
	await _fulfil(7, false, 16)
	await _advance_to(13)
	await _grow({WEST_TOP: "sorghum", WEST_MIDDLE: "sorghum", WEST_BOTTOM: "beans"})
	await _fulfil(13, true, 5)
	await _advance_to(19)
	await _grow({WEST_TOP: "wheat", WEST_MIDDLE: "wheat", WEST_BOTTOM: "hemp"})
	await _fulfil(19, false, 21)
	await _advance_to(25)
	_expect(state.season_order().start == 25 and state.season_order_delivered_at(state.season_order()) == 0
		and not state.deliver_season_order(19, true), "The winter window closes and a new spring order becomes available.")
	var legacy := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	legacy.store_string('{"current_day":4,"player_inventory":3,"money":0,"food_storage":3}')
	legacy.close()
	_expect(state.load_game(state.SAVE_PATH) == OK, "An old aggregate-only save can still start.")
	await scene_changed
	_estate()
	_expect(state.player_inventory == 3 and state.crop_stock.count(CropStock.MIXED) == 3
		and not state.can_deliver_season_order(state.season_order()), "Old stock remains useful without falsely gaining a crop identity.")
	_expect(state.sell_crops(1, CropStock.MIXED) and state.player_inventory == 2 and state.money == 5,
		"The market can still sell old mixed stock.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
