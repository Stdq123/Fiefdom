extends RefCounted

const FIRST := Vector2i(5, 5)
const SECOND := Vector2i(9, 5)
const RICE := Vector2i(4, 5)
const MULBERRY := Vector2i(6, 6)
const SECOND_MULBERRY := Vector2i(5, 4)
const ROTATION_PLOT := Vector2i(6, 4)
const ROTATION_CASH_PLOTS := [Vector2i(4, 4), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 5)]
const FIRST_STEWARD := "渠伯"
const PUBLIC_ROTATION := "rotation:millet"
const SPRING_ORDER_PLOTS := {Vector2i(4, 4): KEY_5, Vector2i(4, 5): KEY_4,
	Vector2i(5, 4): KEY_5, Vector2i(6, 4): KEY_1, Vector2i(6, 5): KEY_1}
const AUTUMN_ORDER_PLOTS := {Vector2i(4, 4): KEY_5, Vector2i(4, 6): KEY_2,
	Vector2i(5, 6): KEY_2, Vector2i(6, 4): KEY_7}
const ESTATE := "res://scenes/Main.tscn"
const TITLE := "res://scenes/Title.tscn"

var tree: SceneTree
var state: Node
var world: Node
var ui: Node
var failures := 0
var rice_harvested := false
var converted_batches := 0
var converted_units := 0
var purchased_batches := 0
var delegated_nights := 0
var nights_short := 0
var use_night_rations := false
var use_field_steward := false
var use_season_orders := false
var use_rotation_steward := false
var order_capture_directory := ""
var petition_day := 0
var deliveries := 0
var steward_name := ""
var steward_day := 0
var managed_harvests := 0
var manual_field_actions := 0
var second_field_actions := 0
var first_field_actions_at_handoff := 0
var rotation_steward_captures := ""
var paused_private_sowing := false
var ration_silk_sales := 0
var ration_forage_trips := 0

static func confirm_optional_tribute_warning(ui: Node) -> void:
	var warning := ui.get_node_or_null("Control/DialoguePanel") as Control
	if warning != null and warning.name_label.text == "过夜前" and warning.choices.back().text == "仍然过夜":
		warning.choices.back().pressed.emit()

static func walk_to(tree: SceneTree, actor: Node2D, destination: Vector2) -> void:
	var speed: float = actor.SPEED
	for axis in [Vector2.RIGHT, Vector2.DOWN]:
		var distance: float = (destination - actor.global_position).dot(axis)
		var action := &"ui_right" if distance > 0.0 else &"ui_left"
		if axis == Vector2.DOWN:
			action = &"ui_down" if distance > 0.0 else &"ui_up"
		var frames := mini(300, roundi(absf(distance) * Engine.physics_ticks_per_second / speed))
		Input.action_press(action)
		for step in frames:
			await tree.physics_frame
		Input.action_release(action)
	await tree.process_frame

static func walk_straight(tree: SceneTree, actor: Node2D, destination: Vector2) -> void:
	var distance := destination - actor.global_position
	var speed: float = actor.SPEED
	var frames := roundi(distance.length() * Engine.physics_ticks_per_second / speed)
	var direction := distance.normalized()
	var horizontal := &"ui_left" if direction.x < 0.0 else &"ui_right"
	var vertical := &"ui_up" if direction.y < 0.0 else &"ui_down"
	Input.action_press(horizontal, absf(direction.x))
	Input.action_press(vertical, absf(direction.y))
	for frame in frames:
		await tree.physics_frame
	Input.action_release(horizontal)
	Input.action_release(vertical)
	await tree.process_frame

static func walk_market_to(tree: SceneTree, market: Node2D, destination: Vector2) -> void:
	var ground: Node2D = market.ground
	var route: PackedVector2Array = market.market_map.network.route_between(
		ground.to_local(market.player.global_position), ground.to_local(destination))
	for point in route.slice(1):
		await walk_straight(tree, market.player, ground.to_global(point))

static func walk_to_market_exit(tree: SceneTree, market: Node2D) -> void:
	await walk_market_to(tree, market, market.get_node("EstateRoadArrival").global_position)

static func walk_estate_road_to(tree: SceneTree, world: Node2D, destination: Vector2) -> void:
	var guide: Control = tree.current_scene.get_node("UI").directions
	var origin := world.to_local(world.player.global_position)
	var route: PackedVector2Array = guide.road_network.route_between(origin, world.to_local(destination))
	for foot in route.slice(1):
		await walk_straight(tree, world.player, world.to_global(foot))

static func walk_ravine_to(tree: SceneTree, ravine: Node2D, destination: Vector2) -> void:
	var guide := ravine.get_node("RavineDirections") as Node2D
	var walker := ravine.get_node("Player") as Node2D
	var route: PackedVector2Array = guide.network.route_between(
		guide.to_local(walker.global_position), guide.to_local(destination))
	for foot in route.slice(1):
		await walk_straight(tree, walker, guide.to_global(foot))

static func walk_to_ravine_exit(tree: SceneTree, ravine: Node2D) -> void:
	await walk_ravine_to(tree, ravine, ravine.get_node("WestArrival").global_position)

static func wait_for_map_change(tree: SceneTree) -> void:
	await tree.process_frame
	var travel := tree.root.get_node_or_null("MapTravel")
	if travel and travel.active:
		await travel.finished
	elif tree.current_scene == null:
		await tree.scene_changed

static func walk_through_gate(tree: SceneTree, action: StringName, frames: int) -> void:
	var travel := tree.root.get_node("MapTravel")
	Input.action_press(action)
	for frame in frames:
		await tree.physics_frame
		if travel.active:
			break
	Input.action_release(action)
	await wait_for_map_change(tree)

static func walk_through_gates(tree: SceneTree, action: StringName, destination: String, frames := 48) -> bool:
	await walk_through_gate(tree, action, frames)
	var scene := tree.current_scene
	if scene.scene_file_path == "res://scenes/WestRoad.tscn" and scene.scene_file_path != destination:
		await walk_through_gate(tree, action, 340)
	return tree.current_scene.scene_file_path == destination

static func meet_tax_envoy(tree: SceneTree) -> Control:
	var estate := tree.current_scene
	var world := estate.get_node("World")
	var envoy: Node2D = world.tax_envoy
	var player: Node2D = world.player
	if not envoy.visible:
		return null
	await walk_to(tree, player, world.to_global(envoy.waiting_place + Vector2(24, 22)))
	for frame in 100:
		if player.interaction_target == envoy:
			var event := InputEventKey.new()
			event.keycode = KEY_E
			event.physical_keycode = KEY_E
			event.pressed = true
			tree.root.push_input(event, true)
			await tree.process_frame
			return estate.get_node_or_null("UI/Control/EventPanel") as Control
		await tree.physics_frame
	return null

static func present_ledger(tree: SceneTree) -> void:
	var estate := tree.current_scene
	var world := estate.get_node("World")
	var stand: Sprite2D = world.get_node("Scenery/EndingRecord")
	var approach := stand.global_position + Vector2(0, 12)
	await walk_estate_road_to(tree, world, approach)
	if world.player.interaction_target == stand:
		var event := InputEventKey.new()
		event.keycode = KEY_E
		event.physical_keycode = KEY_E
		event.pressed = true
		tree.root.push_input(event, true)
		await tree.process_frame
		await tree.process_frame

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		push_error(message)
	return condition

func _refresh_estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.physical_keycode = code
	tree.root.push_input(event, true)

func _click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		tree.root.push_input(event, true)
		await tree.process_frame

func _click_cell(cell: Vector2i) -> void:
	var tile_map: TileMapLayer = world.tile_map
	await _click(tile_map.get_global_transform_with_canvas() * tile_map.map_to_local(cell))

func _sleep() -> void:
	var evening: int = state.current_day
	ui.sleep_button.pressed.emit()
	await tree.create_timer(1.08).timeout
	var meal: Dictionary = state.night_rations.last
	if meal.get("day", 0) == evening:
		if not meal.used.is_empty() or meal.bought > 0:
			delegated_nights += 1
		if meal.served < meal.need:
			nights_short += 1
			print("CAMPAIGN_SHORT evening=", evening, " served=", meal.served, "/", meal.need, " copper=", state.money)

func _management(tab: int) -> Control:
	ui.manage_button.pressed.emit()
	var panel: Control = ui.panel_manager.management_panel_instance
	panel.get_node("HBoxContainer/RightPanel").current_tab = tab
	return panel

func _close(panel: Control) -> void:
	panel.get_node("CloseButton").pressed.emit()

func _find_button(node: Node, prefix: String) -> Button:
	for button in node.find_children("*", "Button", true, false):
		if button.text.begins_with(prefix):
			return button
	return null

func _farm_action(cell: Vector2i) -> void:
	manual_field_actions += 1
	if Rect2i(SECOND - Vector2i.ONE, Vector2i(3, 3)).has_point(cell):
		second_field_actions += 1
	world.handle_interaction(cell)

func _harvest_and_tend(cell: Vector2i, seed_key: Key, replant: bool) -> void:
	var crop: Dictionary = state.active_crops.get(cell, {})
	if not crop.is_empty() and world.field_action(cell) == world.FieldAction.HARVEST:
		_farm_action(cell)
		if cell == RICE and crop["data"].is_water_crop and not state.active_crops.has(cell):
			rice_harvested = true
	if replant and not state.active_crops.has(cell):
		if not state.tilled_cells.has(cell):
			_farm_action(cell)
		if world.current_seed_id != {KEY_1: "millet", KEY_2: "sorghum", KEY_3: "rice", KEY_4: "wheat",
				KEY_5: "beans", KEY_6: "mulberry", KEY_7: "hemp"}[seed_key]:
			_key(seed_key)
		_farm_action(cell)
	if world.field_action(cell) == world.FieldAction.WATER:
		_farm_action(cell)
	elif state.active_crops.has(cell) and not state.active_crops[cell]["watered"]:
		world.handle_interaction(cell)

func _provision(target: int, expansion := false) -> void:
	if use_night_rations and not expansion and state.night_rations_plan().uncovered == 0:
		return
	var crops: int = state.player_inventory
	if use_season_orders:
		var reserved: Dictionary = state.season_order_crops_to_keep()
		for id in reserved:
			crops -= mini(state.crop_stock.count(id), int(reserved[id]))
	if crops == 0 and state.food_storage >= target:
		return
	var panel := _management(1)
	var market: Control = panel.market_panel
	if crops > 0:
		market.quantity.value = crops
		market.convert_button.pressed.emit()
		converted_batches += 1
		converted_units += crops - state.player_inventory
	var purchase := mini(maxi(0, target - state.food_storage), state.affordable_market_food())
	if purchase > 0:
		market.quantity.value = purchase
		market.buy_button.pressed.emit()
		purchased_batches += 1
	_close(panel)

func _enable_night_rations() -> void:
	await _click(ui.hud.rations_button.get_global_rect().get_center())
	var policy := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(policy != null, "The campaign can open the ration policy from the HUD."):
		return
	await _click(policy.delegate.get_global_rect().get_center())
	policy.budget.value = state.balance.market_food_price * 5
	_expect(state.night_rations.enabled, "The alternate campaign has opted in to nightly rations.")
	await _click(policy.close_button.get_global_rect().get_center())

func _recruit() -> void:
	if state.current_day < 6 or state.retainers.size() >= 3 or world.active_visitors.is_empty():
		return
	await walk_to(tree, world.player, world.active_visitors.front().global_position)
	_key(KEY_E)
	var dialog := ui.get_node_or_null("Control/DialoguePanel")
	if dialog == null:
		return
	var recruit := _find_button(dialog, "招募")
	if recruit and not recruit.disabled and (state.retainers.size() == 2 or dialog.name_label.text == "弋戎"):
		recruit.pressed.emit()
	else:
		_find_button(dialog, "离开").pressed.emit()
	await tree.process_frame
	if state.retainers.size() == 2 and state.retainers.back().name == "弋戎":
		var panel := _management(0)
		panel.retainer_list_container.get_child(1).duty_picker.item_selected.emit(3)
		_close(panel)

func _study() -> void:
	var panel := _management(2)
	panel.read_button.pressed.emit()
	_close(panel)

func _prepare_workshop_and_canal() -> void:
	var panel := _management(3)
	var tabs := panel.get_node("HBoxContainer/RightPanel") as TabContainer
	panel.irrigation_button.pressed.emit()
	tabs.current_tab = 4
	var silk: VBoxContainer = tabs.get_node("蚕桑")
	silk.buttons[0].pressed.emit()
	_close(panel)
	ui.channel_button.pressed.emit()
	await _click_cell(Vector2i(2, 5))
	await _click_cell(Vector2i(3, 5))
	_key(KEY_ESCAPE)
	_expect(state.irrigation.supplies(RICE), "The canal supplies the plot selected for rice.")
	_expect(state.silk_workshop.built, "Copper from harvests builds the workshop.")

func _make_silk() -> void:
	var workshop = state.silk_workshop
	if not workshop.built or (not use_field_steward and not use_rotation_steward and workshop.bolts > 0):
		return
	var panel := _management(4)
	var silk := panel.get_node("HBoxContainer/RightPanel/蚕桑")
	while not silk.buttons[2].disabled:
		silk.buttons[2].pressed.emit()
	if not silk.buttons[3].disabled:
		silk.buttons[3].pressed.emit()
	elif not silk.buttons[1].disabled:
		silk.buttons[1].pressed.emit()
	_close(panel)

func _expand() -> void:
	ui.reclaim_button.pressed.emit()
	await tree.process_frame
	var panel := ui.get_node("Control/ReclamationPanel")
	await _click_cell(SECOND)
	await _click(panel.get_node("Panel/ReclaimButton").get_global_rect().get_center())
	await _click(panel.get_node("Panel/CloseButton").get_global_rect().get_center())
	_expect(state.well_fields.size() == 2, "Ordinary reclamation creates the second field.")

func _order_plots() -> Dictionary:
	if not use_season_orders or state.get_current_year() != state.TAX_COUNCIL_YEAR - 1:
		return {}
	var schedule: Dictionary = state.season_order()
	if state.season_order_delivered_at(schedule) != 0:
		return {}
	match schedule.order.id:
		"spring_seed_share": return SPRING_ORDER_PLOTS
		"autumn_watch_relief": return AUTUMN_ORDER_PLOTS
	return {}

func _seek_petition() -> bool:
	return (use_season_orders and state.tax_council_petition_order_count() >= state.TAX_COUNCIL_PETITION_ORDERS
		and state.current_day < state.tax_council_start_day())

func _deliver_order() -> void:
	if not use_season_orders or state.tax_council_waiting():
		return
	var order: Dictionary = state.season_order()
	if order.order.id not in ["spring_seed_share", "autumn_watch_relief"] or state.get_current_year() != state.TAX_COUNCIL_YEAR - 1:
		return
	if not state.can_deliver_season_order(order):
		return
	var panel := _management(0)
	panel.show_season_orders()
	var book: Control = panel.season_order_panel
	book.pin_button.button_pressed = true
	_close(panel)
	await tree.process_frame
	await _click(ui.hud.pinned_order.get_global_rect().get_center())
	if not _expect(state.market_trip_target == state.MARKET_ORDERS, "The ready order offers a trail to the market cart."):
		return
	await walk_estate_road_to(tree, world, Vector2(-270, -21))
	if not _expect(await walk_through_gates(tree, &"ui_left", state.WEST_MARKET_SCENE), "Walk from the estate through the bridge to the market."):
		return
	var market := tree.current_scene
	await walk_market_to(tree, market, market.market_map.places[state.MARKET_ORDERS])
	_key(KEY_E)
	await tree.process_frame
	if not _expect(market.counter.visible and market.counter.orders.is_visible_in_tree(), "Talk to the west-market order cart."):
		return
	book = market.counter.orders
	var reward: Button = book.food_button if deliveries % 2 == 0 else book.copper_button
	await _click(reward.get_global_rect().get_center())
	_expect(state.season_order_delivered_at(order) == state.current_day, "The cart records a real delivery for this season.")
	deliveries += 1
	print("CAMPAIGN_ORDER day=", state.current_day, " order=", order.order.id,
		" reward=", reward.text, " petition_receipts=", state.tax_council_petition_order_count())
	if not _expect(book.get("freight_route") != null and book.freight_route.is_visible_in_tree(),
		"The paid receipt provides directions to the unloading yard."):
		return
	await _click(book.freight_route.get_global_rect().get_center())
	_expect(state.market_trip_target == state.FREIGHT_YARD and not market.counter.visible,
		"Start the return journey from the receipt.")
	await walk_to_market_exit(tree, market)
	if _expect(await walk_through_gates(tree, &"ui_right", state.ESTATE_SCENE), "Return from the market through the bridge."):
		_refresh_estate()
		_expect(ui.directions.destination().title == state.FREIGHT_YARD,
			"The return guide reaches the destination in the estate.")
		if deliveries == 1:
			await _meet_freight_driver()
		await walk_estate_road_to(tree, world, Vector2(82, 115))

func _meet_freight_driver() -> void:
	var target: Vector2 = ui.directions.destination().point
	await walk_estate_road_to(tree, world, world.to_global(target))
	var wagon: Node2D = world.get_node("Freight")
	# Wait on the estate clock, with normal resident and cart updates running.
	var started_at := Time.get_ticks_msec()
	var remaining: float = state.balance.daylight_seconds * (1.0 - state.day_progress)
	while not wagon.arrived and remaining > 0.0:
		await tree.create_timer(1.0).timeout
		remaining -= 1.0
	await tree.process_frame
	if not _expect(wagon.arrived and world.player.interaction_target == wagon,
		"The afternoon wagon arrives where the receipt directed the player."):
		return
	_key(KEY_E)
	await tree.process_frame
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialog != null and dialog.name_label.text == "申禾" and state.market_trip_target.is_empty(),
		"Speaking to the arriving driver completes the tracked shipment."):
		return
	if not order_capture_directory.is_empty():
		await _capture_ending(order_capture_directory, "orders-meet-the-driver")
	print("CAMPAIGN_FREIGHT day=", state.current_day, " watch=", state.day_watch_label(),
		" elapsed_ms=", Time.get_ticks_msec() - started_at)
	var garden_choice := _find_button(dialog, "指路去亭西种圃")
	if not _expect(garden_choice != null, "The delivery names the seed garden and offers directions."):
		return
	await _click(garden_choice.get_global_rect().get_center())
	await tree.process_frame
	var destination: Dictionary = ui.directions.destination()
	if not _expect(destination.get("title") == "亭西种圃", "The next leg moves from the wagon to the growing beds."):
		return
	await walk_estate_road_to(tree, world, world.to_global(destination.point))
	var garden: Node2D = world.get_node("Scenery/SeedGarden")
	while state.seed_garden_day() == 0 and state.day_progress < 1.0:
		await tree.create_timer(1.0).timeout
	await tree.process_frame
	if not _expect(state.seed_garden_day() == state.current_day and world.player.interaction_target == garden,
		"The unloaded seed reaches the garden while the estate clock advances."):
		return
	_key(KEY_E)
	await tree.process_frame
	dialog = ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialog != null and dialog.name_label.text in ["林蓼", "亭西种圃"] and "菽和黍" in dialog.text_label.text,
		"The garden identifies the delivered seed and its new home."):
		return
	if not order_capture_directory.is_empty():
		await _capture_ending(order_capture_directory, "orders-seed-garden")
	print("CAMPAIGN_SEED_GARDEN day=", state.current_day, " planted=", state.seed_garden_day(), " speaker=", dialog.name_label.text)
	await _click(dialog.choices.back().get_global_rect().get_center())

func _petition_early() -> void:
	if not _seek_petition():
		return
	var ready: bool = state.can_petition_tax_council()
	var opening_today: bool = state.current_day == state.tax_council_petition_day()
	if not ready and not opening_today:
		return
	await _click(ui.hud.council_prep_button.get_global_rect().get_center())
	var book: Control = ui.council_preparation
	if not ready:
		var gap: int = state.tax_council_public_gap()
		_expect(book.modal.visible and not book.petition_button.visible and "回执已齐" in book.petition_detail.text
			and ("还差 %d 份纳贡" % gap) in book.petition_detail.text,
			"The first petition day explains the outstanding public contribution after two delivered orders.")
		print("CAMPAIGN_PETITION_GAP day=", state.current_day, " missing=", gap)
		if not order_capture_directory.is_empty():
			await _capture_ending(order_capture_directory, "orders-petition-missing-tribute")
		await _click(book.close_button.get_global_rect().get_center())
		return
	if not _expect(book.modal.visible and book.petition_button.is_visible_in_tree(), "Two delivered orders lead to an actionable early council."):
		return
	if not order_capture_directory.is_empty():
		await _capture_ending(order_capture_directory, "orders-petition-ready")
	await _click(book.petition_button.get_global_rect().get_center())
	if _expect(not tree.paused and state.tax_council_waiting(), "The petition summons the envoy before the regular council."):
		petition_day = state.current_day
		print("CAMPAIGN_PETITION day=", petition_day, " regular=", state.tax_council_start_day(),
			" orders=", state.tax_council_petition_order_count(), " ratio=", state.public_contribution_ratio())

func _handoff_field() -> void:
	var public: int = state.king_storage
	var private_yield: int = state.private_harvest_total
	await _click(ui.hud.morning_button.get_global_rect().get_center())
	var record := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(record != null and record.plan_field.is_visible_in_tree(), "The new field opens from its morning record."):
		return
	await _click(record.plan_field.get_global_rect().get_center())
	await tree.process_frame
	var panel: Control = ui.panel_manager.management_panel_instance
	if not _expect(panel.visible and panel.well_field_selector.get_selected_id() == 1, "The completion action selects the second field."):
		return
	var picker: OptionButton = panel.steward_picker
	var keeper_index := 1
	for index in range(1, picker.item_count):
		var worker = picker.get_item_metadata(index)
		if worker.name == "渠伯":
			keeper_index = index
			break
	picker.select(keeper_index)
	picker.item_selected.emit(keeper_index)
	var keeper = picker.get_selected_metadata()
	var before: int = state.retainer_food_cost()
	await _click(panel.apply_steward.get_global_rect().get_center())
	await _click(panel.close_button.get_global_rect().get_center())
	if not _expect(state.stewarded_field(keeper).field_id == 1 and state.field_seed_plans.has(SECOND)
		and state.king_storage == public and state.private_harvest_total == private_yield,
		"Appoint a steward and plan the second field without booking a harvest."):
		return
	steward_name = keeper.name
	steward_day = state.current_day
	print("CAMPAIGN_STEWARD day=", steward_day, " name=", steward_name, " ration=", before, "->", state.retainer_food_cost())

func _prepare_second_field() -> void:
	for cell in [SECOND, SECOND + Vector2i.DOWN, SECOND + Vector2i.DOWN + Vector2i.RIGHT]:
		if world.field_action(cell) == world.FieldAction.TILL:
			_farm_action(cell)
	await _handoff_field()

func _steward_workday() -> void:
	var start_tribute: int = state.king_storage
	var start_private: int = state.private_harvest_total
	# Let the steward tend the field while the player is free to walk or work elsewhere.
	await tree.create_timer(6.0).timeout
	managed_harvests += state.king_storage - start_tribute + state.private_harvest_total - start_private

func _rotation_choice(actor: Node2D, choice: String, frame := "") -> bool:
	if not _expect(is_instance_valid(actor), "The rotation interaction can be reached in the estate."):
		return false
	await walk_straight(tree, world.player, actor.global_position + Vector2(0, 16))
	_key(KEY_E)
	await tree.process_frame
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	var button := _find_button(dialog, choice) if dialog else null
	if not _expect(button != null, "The rotation conversation offers " + choice):
		return false
	if not rotation_steward_captures.is_empty() and not frame.is_empty():
		await _capture_ending(rotation_steward_captures, frame)
	await _click(button.get_global_rect().get_center())
	await tree.process_frame
	return true

func _show_first_field_plan(panel: Control, cell: Vector2i, id: String, rotating := false) -> void:
	var picker: OptionButton = panel.seed_plan_picker
	for index in range(1, picker.item_count):
		if picker.get_item_metadata(index) == id:
			picker.select(index)
			picker.item_selected.emit(index)
			break
	panel.rotate_seed.set_pressed_no_signal(rotating)
	for tile: Button in panel.map_grid_container.get_children():
		if tile.grid_pos == cell:
			await _click(tile.get_global_rect().get_center())
			return

func _appoint_first_field_steward() -> void:
	var keeper: Node2D = world.neighbor_actor(FIRST_STEWARD)
	if not _expect(keeper != null and state.well_fields.size() == 1 and not state.field_steward_unlocked(),
		"The new estate can earn a first-field handoff by working with Qu Bo."):
		return
	if not await _rotation_choice(keeper, "一起记进轮作簿"):
		return
	if not _expect(ui.hud.opening_action.visible and ui.hud.opening_action.text == "找轮作簿",
		"The estate journal points to the signed book."):
		return
	await _click(ui.hud.opening_action.get_global_rect().get_center())
	_expect(ui.directions.destination().title == "轮作簿", "The opening action marks the book in the estate.")
	if not await _rotation_choice(world.get_node("FieldRotationBook"), "安排轮作与管事", "first-steward-rotation-book"):
		return
	var panel: Control = ui.panel_manager.management_panel_instance
	if not _expect(panel.visible and panel.well_field_selector.get_selected_id() == 0 and panel.steward_picker.has_focus(),
		"The real field book opens its own field with focus on the steward picker."):
		return
	var public: int = state.king_storage
	var private_yield: int = state.private_harvest_total
	var before: int = state.retainer_food_cost()
	await _show_first_field_plan(panel, FIRST, "millet", true)
	await _show_first_field_plan(panel, RICE, "rice")
	for cell in ROTATION_CASH_PLOTS:
		await _show_first_field_plan(panel, cell, "hemp")
	for cell in [MULBERRY, SECOND_MULBERRY]:
		await _show_first_field_plan(panel, cell, "mulberry")
	var picker: OptionButton = panel.steward_picker
	picker.select(1)
	picker.item_selected.emit(1)
	var worker = picker.get_selected_metadata()
	await tree.process_frame
	if not _expect(panel.fill_steward_plans.visible and panel.fill_steward_plans.button_pressed
		and "私田 1 格" in panel.steward_preview.text, "The only unplanned annual plot is quoted for optional reseeding."):
		return
	await _click(panel.fill_steward_plans.get_global_rect().get_center())
	await tree.process_frame
	_expect(not panel.fill_steward_plans.button_pressed and "沿用当前" in panel.steward_preview.text,
		"Before the handoff the player can leave established sowing plans in place: %s pressed=%s." % [
			panel.steward_preview.text, panel.fill_steward_plans.button_pressed])
	if not rotation_steward_captures.is_empty():
		await _capture_ending(rotation_steward_captures, "first-steward-handoff")
	var apply: Button = panel.apply_steward
	if not _expect(apply.is_visible_in_tree() and not apply.disabled and state.can_assign_duty(worker, worker.Duty.STEWARD),
		"The handoff button is available for the selected worker."):
		return
	await _click(apply.get_global_rect().get_center())
	await tree.process_frame
	if not _expect(worker.name == FIRST_STEWARD and worker.duty == worker.Duty.STEWARD
		and state.stewarded_field(worker).field_id == 0 and state.retainer_food_cost() == before + 1
		and state.field_seed_plans[FIRST] == PUBLIC_ROTATION and not state.field_seed_plans.has(ROTATION_PLOT)
		and state.king_storage == public and state.private_harvest_total == private_yield,
		"Qu Bo takes the first field for the quoted ration before any harvest."):
		return
	steward_name = worker.name
	steward_day = state.current_day
	first_field_actions_at_handoff = manual_field_actions
	await _click(panel.close_button.get_global_rect().get_center())
	print("CAMPAIGN_FIRST_STEWARD day=", steward_day, " ration=", before, "->", state.retainer_food_cost(),
		" manual_actions_to_handoff=", first_field_actions_at_handoff)
	await _save_return_continue()
	worker = state.retainers.front()
	_expect(state.well_fields.size() == 1 and worker.name == FIRST_STEWARD and worker.duty == worker.Duty.STEWARD
		and worker.assigned_area == FIRST and state.retainer_food_cost() == before + 1
		and state.field_seed_plans[FIRST] == PUBLIC_ROTATION and not state.field_seed_plans.has(ROTATION_PLOT),
		"Continue keeps the earned one-field stewardship, meal cost and selected sowing plans.")

func _rotation_workday() -> void:
	var worker = state.retainers.front()
	if not _expect(worker.name == steward_name and worker.duty == worker.Duty.STEWARD,
		"The first-field steward remains at work."):
		return
	var start: int = state.king_storage + state.private_harvest_total
	for tick in 60:
		var pending: bool = state.tilled_cells.keys().any(func(cell: Vector2i) -> bool:
			return state.field_job(worker, cell) != state.FieldJob.NONE)
		if not pending:
			break
		await tree.create_timer(0.45).timeout
	managed_harvests += state.king_storage + state.private_harvest_total - start
	rice_harvested = rice_harvested or state.crop_stock.count("rice") > 0

func _stop_rotation_cash_plots() -> void:
	var panel := _management(0)
	panel.show_estate(0)
	panel.focus_sowing_plans()
	await tree.process_frame
	if not _expect(not panel.apply_private_plan.disabled, "Plan to stop private sowing while the public rotation continues."):
		return
	await _click(panel.apply_private_plan.get_global_rect().get_center())
	await tree.process_frame
	await _click(panel.close_button.get_global_rect().get_center())
	paused_private_sowing = true
	_expect(state.field_seed_plans.get(FIRST) == PUBLIC_ROTATION and state.field_seed_plans.size() == 1,
		"Pausing clears private sowing and leaves the public rotation scheduled.")
	print("CAMPAIGN_FIRST_STEWARD_SOWING day=", state.current_day, " gap=", state.tax_council_public_gap())

func _resume_rotation_cash_plots() -> void:
	var panel := _management(0)
	panel.show_estate(0)
	for cell in ROTATION_CASH_PLOTS:
		await _show_first_field_plan(panel, cell, "hemp")
	await _click(panel.close_button.get_global_rect().get_center())

func _pause_private_sowing() -> void:
	var gap: int = state.tax_council_public_gap()
	var readiness_day: int = state.tax_council_start_day() - floori(float(state.balance.days_per_year) / 2.0)
	if paused_private_sowing or gap <= 0 or state.current_rank < state.Rank.DA_FU or state.current_day < readiness_day:
		return
	await _click(ui.hud.council_prep_button.get_global_rect().get_center())
	var ledger: Control = ui.council_preparation
	if not _expect(ledger.modal.visible and ledger.sowing_button.is_visible_in_tree(), "The council ledger offers to adjust active private sowing."):
		return
	await _click(ledger.sowing_button.get_global_rect().get_center())
	var panel: Control = ui.panel_manager.management_panel_instance
	if not _expect(panel.visible and panel.well_field_selector.get_selected_id() == 1 and panel.apply_private_plan.has_focus()
		and panel.apply_private_plan.text.begins_with("取消私田"), "The ledger opens the two private plots at the cancel preview."):
		return
	var public_plan: String = state.field_seed_plans[SECOND]
	await _click(panel.apply_private_plan.get_global_rect().get_center())
	await _click(panel.close_button.get_global_rect().get_center())
	paused_private_sowing = true
	_expect(state.field_seed_plans.get(SECOND) == public_plan and not state.field_seed_plans.has(SECOND + Vector2i.DOWN)
		and not state.field_seed_plans.has(SECOND + Vector2i.DOWN + Vector2i.RIGHT), "Pause the next private sowing while the tribute plot continues.")
	print("CAMPAIGN_SOWING day=", state.current_day, " gap=", gap, " public_plan=", public_plan)

func _fund_rations_with_silk() -> void:
	if (not use_field_steward and not use_rotation_steward) or state.night_rations_plan().uncovered == 0:
		return
	await _click(ui.hud.rations_button.get_global_rect().get_center())
	var panel := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(panel != null, "Open the ration ledger when the steward cannot provision tonight."):
		return
	if panel.sell_silk.is_visible_in_tree():
		var stock: int = state.silk_workshop.bolts
		panel.scroll.ensure_control_visible(panel.sell_silk)
		await tree.process_frame
		await _click(panel.sell_silk.get_global_rect().get_center())
		if _expect(state.silk_workshop.bolts == stock - 1, "The campaign sells one bolt through the ration quote."):
			ration_silk_sales += 1
			print("CAMPAIGN_RATION_SILK day=", state.current_day, " bolts=", state.silk_workshop.bolts, " copper=", state.money)
	if panel.accept_offer.is_visible_in_tree():
		panel.scroll.ensure_control_visible(panel.accept_offer)
		await tree.process_frame
		await _click(panel.accept_offer.get_global_rect().get_center())
	await _click(panel.close_button.get_global_rect().get_center())

func _forage_for_rations() -> void:
	if (not use_season_orders and not use_rotation_steward) or state.night_rations_plan().uncovered == 0:
		return
	await _click(ui.hud.rations_button.get_global_rect().get_center())
	var panel := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(panel != null and panel.find_fruit.is_visible_in_tree(), "An unfunded meal points to the berry grove."):
		return
	panel.scroll.ensure_control_visible(panel.find_fruit)
	await tree.process_frame
	var capture_trip := ration_forage_trips == 0 and not order_capture_directory.is_empty()
	if capture_trip:
		await _capture_ending(order_capture_directory, "orders-rations-fruit-option")
	var grain: int = state.food_storage
	var copper: int = state.money
	var evening: int = state.current_day
	await _click(panel.find_fruit.get_global_rect().get_center())
	await tree.process_frame
	if not _expect(not is_instance_valid(panel) and state.ravine_trip_target == "野果坳"
		and state.food_storage == grain and state.money == copper, "The ledger starts the trip without charging or granting food."):
		return
	await walk_estate_road_to(tree, world, world.get_node("EastArrival").global_position)
	if not _expect(await walk_through_gates(tree, &"ui_right", state.WILDERNESS_SCENE), "Take the east gate into the ravine."):
		return
	await tree.process_frame
	var ravine := tree.current_scene as Node2D
	var fruit := ravine.get_node("WildFruit") as Node2D
	if not _expect(ravine.active_waypoint() == "野果坳" and state.ravine_trip_target == "野果坳",
		"The ravine resumes the directions from the ledger."):
		return
	if capture_trip:
		await _capture_ending(order_capture_directory, "orders-rations-ravine-route")
	await walk_ravine_to(tree, ravine, fruit.global_position + Vector2(0, 16))
	if not _expect(ravine.get_node("Player").interaction_target == fruit, "The road reaches the actual fruit bush."):
		return
	if capture_trip:
		await _capture_ending(order_capture_directory, "orders-rations-berry-grove")
	_key(KEY_E)
	await tree.process_frame
	_expect(state.food_storage == grain + state.balance.wild_food_yield and state.last_forage_day == evening,
		"Picking the fruit adds the quoted food and spends today's gathering.")
	await walk_to_ravine_exit(tree, ravine)
	if not _expect(await walk_through_gates(tree, &"ui_left", state.ESTATE_SCENE), "Take the west gate back to the estate."):
		return
	_refresh_estate()
	await walk_estate_road_to(tree, world, Vector2(82, 115))
	_expect(state.current_day == evening and state.night_rations_plan().uncovered == 0,
		"Returning with the fruit covers this evening's meal.")
	ration_forage_trips += 1
	print("CAMPAIGN_RATION_FRUIT evening=", evening, " grain=", grain, "->", state.food_storage, " copper=", state.money)

func _resume_private_sowing() -> void:
	if not paused_private_sowing:
		return
	var panel := _management(0)
	panel.show_estate(1)
	await tree.process_frame
	var picker: OptionButton = panel.seed_plan_picker
	for index in picker.item_count:
		if picker.get_item_metadata(index) == "seasonal":
			picker.select(index)
			picker.item_selected.emit(index)
			break
	await tree.process_frame
	if not _expect(panel.apply_private_plan.is_visible_in_tree() and not panel.apply_private_plan.disabled
		and panel.apply_private_plan.text.begins_with("安排私田"), "Seasonal sowing previews the prepared private plots."):
		return
	await _click(panel.apply_private_plan.get_global_rect().get_center())
	await _click(panel.close_button.get_global_rect().get_center())
	_expect(state.field_seed_plans.get(SECOND + Vector2i.DOWN) == "seasonal"
		and state.field_seed_plans.get(SECOND + Vector2i.DOWN + Vector2i.RIGHT) == "seasonal",
		"Seasonal sowing can be restored after the council decision. Plans: %s" % state.field_seed_plans)

func _save_return_continue() -> void:
	var date: int = state.current_day
	var progress: Array[Dictionary] = state.route_objectives()
	ui.settings_button.pressed.emit()
	var settings: Panel = ui.panel_manager.settings_panel_instance
	_find_button(settings, "保存").pressed.emit()
	_find_button(settings, "返回标题").pressed.emit()
	settings.get_node("TitleConfirmation").confirmed.emit()
	await tree.scene_changed
	tree.current_scene.continue_button.pressed.emit()
	await tree.scene_changed
	_refresh_estate()
	_expect(state.current_day == date and state.route_objectives() == progress, "Continue restores the route progress.")

func _end(failed := false) -> void:
	if not failed and failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failed or failures else 0)

func _capture_ending(directory: String, name: String) -> void:
	await tree.process_frame
	RenderingServer.viewport_set_update_mode(tree.root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	var frame := tree.root.get_texture().get_image()
	_expect(frame != null and not frame.is_empty() and frame.save_png(directory.path_join(name + ".png")) == OK,
		"The ending frame can be captured.")

func run(game_tree: SceneTree, branch: String, release_required := false, capture_directory := "", delegated := false,
		stewarded := false, ordering := false, rotation_steward := false) -> void:
	tree = game_tree
	use_night_rations = delegated
	use_field_steward = stewarded
	use_season_orders = ordering
	use_rotation_steward = rotation_steward
	if rotation_steward:
		rotation_steward_captures = capture_directory
	if ordering:
		order_capture_directory = capture_directory
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated replay profile."):
		_end(true)
		return
	if release_required and not _expect(not OS.is_debug_build(), "Release replay requires the non-debug Windows template."):
		_end(true)
		return
	print("CAMPAIGN_START branch=", branch, " debug=", OS.is_debug_build())
	if capture_directory.is_empty():
		tree.root.size = Vector2i(1280, 720)
	seed(325)
	tree.change_scene_to_file(TITLE)
	await tree.scene_changed
	if not _expect(tree.current_scene.continue_button.disabled, "Replay starts at the title with an empty slot."):
		_end(true)
		return
	tree.current_scene.new_button.pressed.emit()
	await tree.scene_changed
	_refresh_estate()
	state = tree.root.get_node("Global")
	if use_night_rations:
		await _enable_night_rations()
	Input.action_press("ui_down")
	for frame in range(56):
		await tree.physics_frame
	Input.action_release("ui_down")

	var prepared := false
	var literacy_art: int = state.player_stats.Art.LITERACY
	var literacy_target: int = state.irrigation.UNLOCK_LITERACY_LEVEL
	while state.current_day < 100 and not tree.paused and not state.tax_council_waiting() and state.outcome == state.Outcome.RUNNING:
		await _recruit()
		if use_rotation_steward and steward_day == 0:
			var keeper: Node2D = world.neighbor_actor(FIRST_STEWARD)
			if state.rotation_offer_ready():
				if not await _rotation_choice(keeper, "约定试一回轮作"):
					_end(true)
					return
			elif state.field_rotation.ready_to_sign():
				await _appoint_first_field_steward()
				if failures > 0:
					_end(true)
					return
		if state.player_stats.get_level(literacy_art) < literacy_target:
			_study()
		var expanded: bool = state.well_fields.size() >= 2
		var field_ready: bool = expanded and state.well_fields[1]["is_unlocked"]
		if use_field_steward and field_ready and steward_day == 0:
			await _prepare_second_field()
		if use_field_steward and steward_day > 0:
			await _pause_private_sowing()
			await _steward_workday()
			if state.tax_council_waiting():
				break
		var first_managed := use_rotation_steward and steward_day > 0
		if first_managed and not paused_private_sowing and state.current_day >= 27:
			await _stop_rotation_cash_plots()
			if failures > 0:
				_end(true)
				return
		var need_expansion: bool = (not use_rotation_steward and not expanded
			and state.current_rank >= state.Rank.ZHONG_SHI and state.retainers.size() >= 3)
		var rank_factor: int = state.current_rank + 1
		var expansion_cost: int = state.balance.reclamation_cost_copper * rank_factor
		var expansion_food: int = state.balance.reclamation_cost_food * rank_factor
		var available_provisions: int = state.food_storage + (state.player_inventory if use_night_rations else 0)
		var prioritize_tribute := _seek_petition()
		var order_plots := _order_plots()
		var in_second_year: bool = use_season_orders and state.get_current_year() == state.TAX_COUNCIL_YEAR - 1
		if not first_managed:
			_harvest_and_tend(FIRST, KEY_1 if state.fertile_cells.has(FIRST) else KEY_5, true)
		if field_ready and not use_field_steward:
			_harvest_and_tend(SECOND, KEY_1 if state.fertile_cells.has(SECOND) else KEY_5, true)
		if first_managed:
			await _rotation_workday()
		else:
			for x in range(4, 7):
				for y in range(4, 7):
					var cell := Vector2i(x, y)
					if cell == FIRST:
						continue
					var grow: bool = not expanded or cell == MULBERRY or (x == 6 and available_provisions < 12)
					var silk_plot := cell == MULBERRY or ((use_field_steward or use_rotation_steward) and cell == SECOND_MULBERRY)
					if (paused_private_sowing or prioritize_tribute) and not silk_plot:
						continue
					var seed_key := KEY_7
					if silk_plot and prepared:
						seed_key = KEY_6
						grow = true
					if cell == RICE and prepared and not rice_harvested:
						seed_key = KEY_3
						grow = true
					if use_rotation_steward and cell == ROTATION_PLOT and state.field_rotation.beans_day == 0:
						seed_key = KEY_5
					if in_second_year and not silk_plot and seed_key != KEY_3:
						grow = order_plots.has(cell)
						seed_key = order_plots.get(cell, seed_key)
					_harvest_and_tend(cell, seed_key, grow)
		if not prepared and state.money >= 58 and state.player_stats.get_level(literacy_art) >= literacy_target:
			await _prepare_workshop_and_canal()
			prepared = true
			print("CAMPAIGN_BUILD day=", state.current_day, " literacy=", state.player_stats.get_level(literacy_art))
		_make_silk()
		await _deliver_order()
		if failures > 0:
			_end(true)
			return
		await _petition_early()
		if state.tax_council_waiting():
			break
		await _fund_rations_with_silk()
		if (need_expansion and state.money >= expansion_cost
			and (state.food_storage + state.player_inventory < expansion_food + 10
				or (use_night_rations and state.food_storage < expansion_food + 10))):
			var affordable_food := floori(float(state.money - expansion_cost) / state.balance.market_food_price)
			_provision(mini(expansion_food + 10, state.food_storage + state.player_inventory + affordable_food), true)
		else:
			_provision(state.retainer_food_cost() + 1)
		await _forage_for_rations()
		if failures > 0:
			_end(true)
			return
		if need_expansion and state.money >= expansion_cost and state.food_storage >= expansion_food + 10:
			await _expand()
		if state.current_day % 8 == 1:
			print("CAMPAIGN_DAY day=", state.current_day, " rank=", state.current_rank, " rep=", state.reputation, " food=", state.food_storage,
				" copper=", state.money, " fields=", state.well_fields.size(), " public=", state.king_storage, " private=", state.private_harvest_total,
				" guard=", state.raids_defeated, " silk=", state.silk_workshop.bolts)
		await tree.process_frame
		if tree.paused or state.tax_council_waiting():
			break
		await _sleep()

	var event := await meet_tax_envoy(tree)
	if not _expect(event != null and tree.paused and state.current_rank >= state.Rank.DA_FU
		and (state.get_current_year() >= 3 or petition_day > 0),
		"Ordinary harvests and sleep reach the year, rank and contribution gates."):
		_end(true)
		return
	var expected_fields := 1 if use_rotation_steward else 2
	_expect(state.well_fields.size() == expected_fields and state.well_fields.back().is_unlocked and rice_harvested
		and state.raids_defeated >= 1 and state.silk_workshop.bolts > 0,
		"The campaign has the planned field count, irrigated rice, silk and an actual defense.")
	print("CAMPAIGN_DECISION day=", state.current_day, " public_ratio=", state.public_contribution_ratio(), " copper=", state.money)
	if branch == "traditional":
		if not use_field_steward and not use_season_orders:
			_find_button(event, "暂缓").pressed.emit()
			event.confirm_button.pressed.emit()
			await tree.process_frame
			var before: int = state.money
			var paid := false
			while not state.tax_council_waiting() and not tree.paused:
				await _sleep()
				paid = paid or state.money < before
			event = await meet_tax_envoy(tree)
			if not _expect(event != null and _find_button(event, "暂缓") == null and (paid or before < state.balance.research_monthly_cost),
				"Research charges the normal cost and eventually presents a forced choice."):
				_end(true)
				return
			print("CAMPAIGN_RESEARCH day=", state.current_day, " paid=", before - state.money, " days_remaining=", state.research_days_remaining())
		_find_button(event, "坚守传统").pressed.emit()
	else:
		_find_button(event, "支持改革").pressed.emit()
	event.confirm_button.pressed.emit()
	await tree.process_frame
	_expect(state.outcome == state.Outcome.RUNNING and state.route_objectives()[0]["value"] == 0, "Pre-choice harvest cannot satisfy the ending.")
	if use_field_steward:
		await _resume_private_sowing()
	elif use_rotation_steward:
		await _resume_rotation_cash_plots()

	var silk_panel := _management(4).get_node("HBoxContainer/RightPanel/蚕桑")
	silk_panel.buttons[5 if branch == "traditional" else 4].pressed.emit()
	_close(ui.panel_manager.management_panel_instance)
	await tree.process_frame
	if not _expect(state.outcome == state.Outcome.RUNNING and state.route_objectives()[1]["value"] == 1, "Silk counts on the matching branch without skipping the other objectives."):
		_end(true)
		return
	if (use_field_steward or use_rotation_steward) and branch == "reformed":
		var panel := _management(4)
		var sell: Button = panel.silk_panel.buttons[4]
		var cash_target: int = state.balance.ending_reformed_wealth + 3 * state.retainer_food_cost() * state.balance.market_food_price
		while state.money < cash_target and not sell.disabled:
			sell.pressed.emit()
		_close(panel)
	await _save_return_continue()
	var last_day: int = state.current_day + 28
	while state.current_day < last_day and state.outcome == state.Outcome.RUNNING and not state.route_ready_to_present():
		if use_rotation_steward:
			await _rotation_workday()
		else:
			_harvest_and_tend(FIRST, KEY_1 if state.fertile_cells.has(FIRST) else KEY_5, true)
		if use_field_steward:
			await _steward_workday()
			for x in range(4, 7):
				for y in range(4, 7):
					var cell := Vector2i(x, y)
					if cell != FIRST and cell != MULBERRY:
						_harvest_and_tend(cell, KEY_7, branch == "reformed" or x == 6)
		elif not use_rotation_steward:
			_harvest_and_tend(SECOND, KEY_1 if state.fertile_cells.has(SECOND) else KEY_5, true)
			for x in range(8, 11):
				for y in range(4, 7):
					var cell := Vector2i(x, y)
					if cell != SECOND:
						_harvest_and_tend(cell, KEY_7, branch == "reformed" or x == 8)
		await _fund_rations_with_silk()
		_provision(state.retainer_food_cost())
		await _forage_for_rations()
		if failures > 0:
			_end(true)
			return
		await tree.process_frame
		if state.outcome == state.Outcome.RUNNING and not state.route_ready_to_present():
			await _sleep()
	if not _expect(state.route_ready_to_present() and not tree.paused, "All goals lead to a playable handoff."):
		print("CAMPAIGN_MISSING ", state.route_objectives())
		_end(true)
		return
	if branch == "reformed" and not use_season_orders and not use_rotation_steward:
		var earned: int = state.money
		ui.hud.route_progress.pressed.emit()
		state.money = state.balance.ending_reformed_wealth - 1
		var events := tree.root.get_node("GameEvents")
		events.money_changed.emit(state.money)
		_expect(not state.route_ready_to_present() and ui.directions.tracked_place.is_empty(),
			"Dropping below the copper target closes the handoff and clears its directions.")
		state.money = earned
		events.money_changed.emit(state.money)
	await _save_return_continue()
	var stand: Sprite2D = world.get_node("Scenery/EndingRecord")
	_expect(stand.visible and stand.ready_to_present and not stand.archived
		and ui.hud.route_progress.text.begins_with("指路呈交"), "Continue restores the pending handoff and its directions.")
	ui.hud.route_progress.pressed.emit()
	_expect(ui.directions.tracked_place_point == world.to_local(stand.global_position), "The journal marks the route's actual ledger.")
	await present_ledger(tree)
	var expected: int = state.Outcome.TRADITIONAL if branch == "traditional" else state.Outcome.REFORMED
	await tree.process_frame
	if not _expect(state.outcome == expected and tree.paused, "Presenting the ledger opens the earned ending."):
		print("CAMPAIGN_MISSING ", state.route_objectives())
		_end(true)
		return
	print("CAMPAIGN_END branch=", branch, " day=", state.current_day, " rank=", state.current_rank, " fields=", state.well_fields.size(),
		" public=", state.king_storage, " private=", state.private_harvest_total, " copper=", state.money,
		" raids=", state.raids_defeated, " goals=", state.route_objectives())
	print("CAMPAIGN_MARKET branch=", branch, " conversion_clicks=", converted_batches, " converted_units=", converted_units)
	print("CAMPAIGN_RATIONS branch=", branch, " delegated=", use_night_rations, " manual_conversions=", converted_batches,
		" manual_purchases=", purchased_batches, " delegated_nights=", delegated_nights, " short_nights=", nights_short)
	print("CAMPAIGN_FARM branch=", branch, " steward=", steward_name, " manual_actions=", manual_field_actions,
		" second_field_actions=", second_field_actions, " workday_yield=", managed_harvests)
	if use_field_steward:
		_expect(steward_day > 0 and managed_harvests >= 12 and second_field_actions == 3
			and paused_private_sowing and state.field_seed_plans.has(SECOND),
			"The steward farms the second field across the campaign and keeps its saved sowing plan.")
		_expect(ration_silk_sales > 0 and nights_short == 0,
			"The campaign uses the quoted silk proceeds and covers every meal through the ending.")
	if use_night_rations:
		_expect(delegated_nights > 0 and state.night_rations.enabled,
			"Nightly rations operate through the campaign and survive its save and continue.")
	if use_rotation_steward:
		var worker = state.retainers.front()
		var first_field_actions := manual_field_actions - second_field_actions
		_expect(steward_day == state.field_rotation.signed_day and state.stewarded_field(worker).field_id == 0
			and worker.duty == worker.Duty.STEWARD and paused_private_sowing and nights_short == 0
			and first_field_actions == first_field_actions_at_handoff and managed_harvests > 30,
			"The earned steward works the original field through the ending and survives reloads.")
		print("CAMPAIGN_FIRST_STEWARD_SETTLED day=", state.current_day, " first_actions=", first_field_actions,
			" first_after_handoff=", first_field_actions - first_field_actions_at_handoff, " managed_yield=", managed_harvests)
	if use_season_orders:
		_expect(petition_day > 0 and petition_day < state.tax_council_start_day() and deliveries >= 2,
			"Deliver season orders and petition before the regular council in an ordinary new game.")
		_expect(ration_forage_trips > 0 and nights_short == 0,
			"The order campaign follows the berry route and feeds everyone through to its ending.")
	var outcome_view := tree.current_scene.get_node("CampaignHUD")
	var ending: Control = outcome_view.summary
	var ending_capture := ("first-steward-" if use_rotation_steward else "") + "ending-" + branch
	if not _expect(ending != null and ending.shot == ending.Shot.CEREMONY and ending.film.visible and not ui.visible
			and ending.stage.global_position == stand.global_position,
			"The film starts at the same ledger the player just presented."):
		_end(true)
		return
	if not capture_directory.is_empty():
		await tree.create_timer(2.0).timeout
		_expect(ending.shot == ending.Shot.CEREMONY, "The ceremony starts with the envoy's arrival.")
		await _capture_ending(capture_directory, ending_capture + "-ceremony")
		await tree.create_timer(2.1).timeout
		_expect(ending.shot == ending.Shot.FIELD, "The film returns to the fields after the handoff.")
		await _capture_ending(capture_directory, ending_capture + "-fields")
		if not ending.report.visible:
			await ending.film_finished
		await _capture_ending(capture_directory, ending_capture)
	else:
		ending.skip_button.pressed.emit()
	var final_goals: Array[Dictionary] = state.route_objectives()
	_expect(ending.report.visible and ending.has_route_totals and ending.results.get_child_count() == final_goals.size(),
		"The ledger shows every route result.")
	for index in final_goals.size():
		var row: HBoxContainer = ending.results.get_child(index)
		_expect(row.get_child(0).text == final_goals[index]["label"]
			and row.get_child(1).text.begins_with("%d / %d" % [final_goals[index]["value"], final_goals[index]["target"]]),
			"The displayed ledger agrees with the goals earned in play.")
	var saved_victory: Dictionary = state.latest_saved_game()
	var recovery: Dictionary = state.latest_saved_game(true)
	_expect(saved_victory.get("source") == "结局自动存档" and saved_victory.get("outcome") == expected
		and saved_victory.get("campaign") == state.campaign_id and recovery.get("running", false)
		and recovery.get("campaign") == state.campaign_id and outcome_view.status.text == "结局已自动保存。"
		and not ending.restore_button.disabled,
		"Presenting the ledger saves the victory and keeps a playable checkpoint.")
	ending.restore_button.pressed.emit()
	await tree.process_frame
	_expect(ending.restore_confirmation.visible and state.saved_game_caption(recovery) in ending.restore_detail.text
		and ending.stay_button.has_focus() and state.outcome == expected,
		"Reading a pre-victory save shows its actual destination and focuses staying at the ending.")
	if not capture_directory.is_empty():
		await _capture_ending(capture_directory, ending_capture + "-restore")
	_key(KEY_ESCAPE)
	await tree.process_frame
	_expect(not ending.restore_confirmation.visible and ending.restore_button.has_focus() and state.outcome == expected,
		"Cancel returns to the same ledger and restores focus.")
	ending.title_button.pressed.emit()
	await tree.scene_changed
	_expect(tree.current_scene.scene_file_path == TITLE and not tree.paused, "The ending can return to the normal title.")
	tree.current_scene.continue_button.pressed.emit()
	await tree.scene_changed
	await tree.process_frame
	ending = tree.current_scene.get_node("CampaignHUD").summary
	var reloaded_victory: Dictionary = state.latest_saved_game()
	_expect(state.outcome == expected and tree.paused and ending.report.visible and not ending.score.playing
		and saved_victory.get("sequence") == reloaded_victory.get("sequence"),
		"Continuing without a manual save opens the same ledger directly.")
	ending.replay_button.pressed.emit()
	_expect(ending.shot == ending.Shot.FIELD and ending.film.visible, "The saved ending can replay its film.")
	ending.skip_button.pressed.emit()
	_expect(ending.report.visible and state.route_objectives() == final_goals,
		"Replaying a film leaves the recorded campaign results intact.")
	var victory_day: int = state.current_day
	var estate_id: String = state.campaign_id
	var victory_date: String = ending.date.text
	ending.continue_button.pressed.emit()
	await tree.scene_changed
	_refresh_estate()
	_expect(state.outcome == state.Outcome.RUNNING and state.current_day == victory_day and not tree.paused,
		"Continue returns to the same day's estate.")
	_provision(state.retainer_food_cost())
	await _sleep()
	_expect(state.current_day == victory_day + 1 and state.outcome == state.Outcome.RUNNING
		and tree.current_scene.get_node("CampaignHUD").summary == null, "The estate can finish another day without repeating the ending.")
	tree.change_scene_to_file(TITLE)
	await tree.scene_changed
	tree.current_scene.continue_button.pressed.emit()
	await tree.scene_changed
	await tree.process_frame
	var latest: Dictionary = state.latest_saved_game()
	_expect(state.campaign_id == estate_id and state.current_day == victory_day + 1 and state.outcome == state.Outcome.RUNNING
		and latest["running"] and latest["completed_route"] == expected and state.ending_record.get("date") == victory_date
		and tree.current_scene.get_node("World/Scenery/EndingRecord").visible and not tree.paused,
		"The next day's save continues play and retains the completed route record.")
	print("CAMPAIGN_POST_END branch=", branch, " victory_day=", victory_day, " continued_day=", state.current_day)
	tree.paused = false
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.create_timer(0.25).timeout
	_end()
