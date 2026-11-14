extends "res://tests/MarketOrderReplay.gd"

const PUBLIC := Vector2i(5, 5)
const PRIVATE := Vector2i(5, 6)

var use_gamepad := false
var from_older_save := false
var write_old_checkpoint := false
var world: Node2D
var ui: CanvasLayer

func _bind_estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")

func _overnight() -> void:
	var tomorrow: int = state.current_day + 1
	await _button(ui.sleep_button)
	await tree.create_timer(1.12).timeout
	_expect(state.current_day == tomorrow, "Take the normal sleep action to advance a night.")

func _harvest_first_crops() -> void:
	var tiles := world.tile_map as TileMapLayer
	for cell in [PUBLIC, PRIVATE]:
		await _plot(tiles, cell)
		await _plot(tiles, cell)
	for night in 2:
		for cell in [PUBLIC, PRIVATE]:
			await _plot(tiles, cell)
		await _overnight()
	await _plot(tiles, PUBLIC)
	await _plot(tiles, PRIVATE)

func _open_first_order() -> Control:
	if from_older_save:
		await _button(ui.manage_button)
		var management: Control = ui.panel_manager.management_panel_instance
		var section: int = management.tabs.get_tab_idx_from_control(management.season_order_panel)
		await _button(management.section_buttons[section])
		return management.season_order_panel
	await _button(ui.hud.opening_action)
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialog != null and dialog.name_label.text == "首茬收成", "Open the first harvest from the journal."):
		return null
	await _button(dialog.choices[0])
	var panel: Control = ui.panel_manager.management_panel_instance
	return panel.season_order_panel

func _start_field_work(book: Control) -> bool:
	if not _expect(book.is_visible_in_tree() and book.field_work_button.is_visible_in_tree()
		and "换菽种" in book.field_work_button.text and "菽 缺 2 份" in book.status.text
		and tree.root.get_visible_rect().encloses(book.field_work_button.get_global_rect()),
		"The spring book gives a visible way to plant the missing beans."):
		return false
	await _snapshot("01-first-order-beans")
	var tilled: Dictionary = state.tilled_cells.duplicate()
	var seed_plans: Dictionary = state.field_seed_plans.duplicate()
	if use_gamepad:
		var gamepad = load("res://tests/GamepadReplay.gd").new()
		gamepad.tree = tree
		gamepad.pad = tree.root.get_node("GamepadInput")
		await gamepad._click(book.field_work_button)
		_expect(gamepad.failures == 0 and gamepad.pad.active, "Confirm the new action with the gamepad pointer and A.")
	else:
		await _button(book.field_work_button)
	return _expect(not ui.panel_manager.management_panel_instance.visible and world.current_seed_id == "beans"
		and not state.pinned_season_order().is_empty() and ui.directions.tracked_plot != null
		and state.field_route_status == state.OrderFieldRoute.PREPARE and state.tilled_cells == tilled
		and state.active_crops.is_empty() and state.field_seed_plans == seed_plans,
		"Start the order route and select beans without changing any field.")

func _follow_field_work() -> bool:
	var turned_over := 0
	var sowings := 0
	var waters := 0
	var harvests := 0
	var resumed := false
	var tiles := world.tile_map as TileMapLayer
	await _snapshot("02-marked-empty-private-plot")
	await _key(KEY_4)
	if not _expect(world.current_seed_id == "wheat"
		and "换菽种" in ui.directions.destination().title, "A player can still select another seed while tracking."):
		return false
	await _button(ui.hud.pinned_order)
	if not _expect(world.current_seed_id == "beans", "Use the tracker to select the required seed again."):
		return false
	for action in 22:
		await tree.process_frame
		if state.can_deliver_season_order(state.season_order()):
			break
		var work: Dictionary = ui.directions.order_work
		if not _expect(not work.is_empty() and work.crop_id == "beans"
			and work.cell == ui.directions.tracked_plot and not state.is_public_plot(work.cell),
			"Every recommended step stays with a needed crop in a private plot."):
			return false
		var cell: Vector2i = work.cell
		match work.action:
			state.OrderWork.SOW:
				if not state.tilled_cells.has(cell):
					turned_over += 1
				else:
					sowings += 1
				await _plot(tiles, cell)
			state.OrderWork.WATER:
				if waters == 0:
					await _snapshot("03-marked-thirsty-beans")
				waters += 1
				await _plot(tiles, cell)
			state.OrderWork.WAIT:
				if not resumed:
					if not await _continue(state.ESTATE_SCENE):
						return false
					_bind_estate()
					tiles = world.tile_map
					if not _expect(ui.directions.tracked_plot == cell and state.field_route_status == state.OrderFieldRoute.PREPARE
						and world.current_seed_id == "beans", "Continue restores the prepared plot, stock and seed."):
						return false
					resumed = true
				await _overnight()
				if state.current_day == 4:
					_expect(ui.directions.order_work.action == state.OrderWork.WATER, "Dawn points to the beans that need water.")
					await _snapshot("04-dawn-beans")
			state.OrderWork.HARVEST:
				if harvests == 0:
					await _snapshot("05-beans-ready")
				harvests += 1
				await _plot(tiles, cell)
	print("OPENING_ORDER_ACTIONS turned=", turned_over, " sowings=", sowings, " waters=", waters,
		" harvests=", harvests, " day=", state.current_day, " plot=", ui.directions.tracked_plot)
	if not _expect(resumed and turned_over == 1 and sowings == 2 and waters == 4 and harvests == 2
		and state.current_day == 5 and state.king_storage == 1 and state.crop_stock.count("millet") == 1
		and state.crop_stock.count("beans") == 2 and state.can_deliver_season_order(state.season_order())
		and ui.directions.tracked_plot == null and "去西市交货" in ui.hud.pinned_order.text,
		"Harvest on day five, preserve the tribute, and point to the delivery."):
		return false
	print("OPENING_ORDER_READY day=", state.current_day, " beans=", state.crop_stock.count("beans"),
		" millet=", state.crop_stock.count("millet"), " tribute=", state.king_storage, " resume=", resumed)
	await _snapshot("06-ready-to-deliver")
	await _button(ui.hud.pinned_order)
	return _expect(state.market_trip_target == state.MARKET_ORDERS, "Follow the prepared order to the real board.")

func _deliver_opening_order() -> void:
	if not await _to_market() or not await _open_cart():
		return
	var book: Control = tree.current_scene.counter.orders
	var rewards: Dictionary = state.season_order_rewards(state.season_order())
	var before_food: int = state.food_storage
	var before_money: int = state.money
	await _button(book.food_button)
	_expect(state.season_order_delivered_at(state.season_order()) == 5 and state.food_storage == before_food + rewards.food
		and state.money == before_money and state.king_storage == 1 and state.player_inventory == 0
		and state.field_route_status != state.OrderFieldRoute.PREPARE and state.pinned_season_order().is_empty(),
		"The actual cart gives the selected reward and spends only the private cargo.")
	print("OPENING_ORDER_DELIVERED day=", state.current_day, " food_reward=", rewards.food, " tribute=", state.king_storage)
	await _snapshot("07-spring-receipt")

func _check_route_boundaries() -> void:
	var order: Dictionary = state.season_order()
	# Use an empty second-year estate to check the plan without planting or issuing a new order.
	state.current_day = order.start + 4 * (order.end - order.start + 1)
	order = state.season_order()
	state.current_day = order.end
	_expect(state.season_order_work(order).is_empty(), "The final day cannot promise newly sown crops.")
	state.current_day = order.start
	for field: Dictionary in state.well_fields:
		for y in [-1, 0, 1]:
			for x in [-1, 0, 1]:
				var cell: Vector2i = field.center_pos + Vector2i(x, y)
				if cell != PUBLIC:
					state.field_seed_plans[cell] = "hemp"
	_expect(state.season_order_work(order).is_empty(), "Do not recommend the public field or replace incompatible sowing plans.")
	state.field_seed_plans.clear()
	state.current_day = order.end + 1
	_expect(state.season_order_work(state.season_order()).is_empty(), "An unwatered estate cannot be told to sow summer rice.")
	print("OPENING_ORDER_BOUNDARIES late_sow=false public=false planned=false dry_rice=false")

func _play() -> void:
	if from_older_save:
		await _button(tree.current_scene.continue_button)
		if tree.current_scene == null:
			await tree.scene_changed
	else:
		await _button(tree.current_scene.new_button)
		if tree.current_scene == null:
			await tree.scene_changed
		_bind_estate()
		await _harvest_first_crops()
	_bind_estate()
	if not _expect(state.current_day == 3 and state.king_storage == 1 and state.crop_stock.count("millet") == 1,
		"The spring errand begins with the public and private harvest on day three."):
		return
	var book := await _open_first_order()
	if book == null:
		return
	if write_old_checkpoint:
		_expect(book.get_node_or_null("Current/Content/FieldWork") == null,
			"The previous release describes the shortage without an action for the empty field.")
		await _snapshot("01-first-order-before")
		await _key(KEY_ESCAPE)
		_expect(state.save_game() == OK, "Write a genuine old day-three save.")
		return
	if from_older_save:
		_expect(state.first_harvest_reviewed and state.field_route_status != state.OrderFieldRoute.PREPARE,
			"An older estate has its saved review and no unsolicited plot route.")
	if await _start_field_work(book) and await _follow_field_work():
		await _deliver_opening_order()

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	tree.root.notify_mouse_entered()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _play()
	if not failed and not write_old_checkpoint and not from_older_save:
		await _check_route_boundaries()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
