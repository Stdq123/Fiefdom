extends RefCounted

const FIRST := Vector2i(5, 5)
const SECOND := Vector2i(9, 5)
const RICE := Vector2i(4, 5)
const MULBERRY := Vector2i(6, 6)
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

func _harvest_and_tend(cell: Vector2i, seed_key: Key, replant: bool) -> void:
	var crop: Dictionary = state.active_crops.get(cell, {})
	if not crop.is_empty() and world.field_action(cell) == world.FieldAction.HARVEST:
		world.handle_interaction(cell)
		if cell == RICE and crop["data"].is_water_crop and not state.active_crops.has(cell):
			rice_harvested = true
	if replant and not state.active_crops.has(cell):
		if not state.tilled_cells.has(cell):
			world.handle_interaction(cell)
		if world.current_seed_id != {KEY_1: "millet", KEY_3: "rice", KEY_5: "beans", KEY_6: "mulberry", KEY_7: "hemp"}[seed_key]:
			_key(seed_key)
		world.handle_interaction(cell)
	if state.active_crops.has(cell) and not state.active_crops[cell]["watered"]:
		world.handle_interaction(cell)

func _provision(target: int, expansion := false) -> void:
	if use_night_rations and not expansion and state.night_rations_plan().uncovered == 0:
		return
	var crops: int = state.player_inventory
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
	if not workshop.built or workshop.bolts > 0:
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

func run(game_tree: SceneTree, branch: String, release_required := false, capture_directory := "", delegated := false) -> void:
	tree = game_tree
	use_night_rations = delegated
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
		if state.player_stats.get_level(literacy_art) < literacy_target:
			_study()
		var expanded: bool = state.well_fields.size() >= 2
		var need_expansion: bool = not expanded and state.current_rank >= state.Rank.ZHONG_SHI and state.retainers.size() >= 3
		var rank_factor: int = state.current_rank + 1
		var expansion_cost: int = state.balance.reclamation_cost_copper * rank_factor
		var expansion_food: int = state.balance.reclamation_cost_food * rank_factor
		var available_provisions: int = state.food_storage + (state.player_inventory if use_night_rations else 0)
		_harvest_and_tend(FIRST, KEY_1 if state.fertile_cells.has(FIRST) else KEY_5, true)
		if expanded and state.well_fields[1]["is_unlocked"]:
			_harvest_and_tend(SECOND, KEY_1 if state.fertile_cells.has(SECOND) else KEY_5, true)
		for x in range(4, 7):
			for y in range(4, 7):
				var cell := Vector2i(x, y)
				if cell == FIRST:
					continue
				var grow: bool = not expanded or cell == MULBERRY or (x == 6 and available_provisions < 12)
				var seed_key := KEY_7
				if cell == MULBERRY and prepared:
					seed_key = KEY_6
				if cell == RICE and prepared and not rice_harvested:
					seed_key = KEY_3
					grow = true
				_harvest_and_tend(cell, seed_key, grow)
		if not prepared and state.money >= 58 and state.player_stats.get_level(literacy_art) >= literacy_target:
			await _prepare_workshop_and_canal()
			prepared = true
			print("CAMPAIGN_BUILD day=", state.current_day, " literacy=", state.player_stats.get_level(literacy_art))
		_make_silk()
		if (need_expansion and state.money >= expansion_cost
			and (state.food_storage + state.player_inventory < expansion_food + 10
				or (use_night_rations and state.food_storage < expansion_food + 10))):
			var affordable_food := floori(float(state.money - expansion_cost) / state.balance.market_food_price)
			_provision(mini(expansion_food + 10, state.food_storage + state.player_inventory + affordable_food), true)
		else:
			_provision(state.retainer_food_cost() + 1)
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
	if not _expect(event != null and tree.paused and state.current_rank >= state.Rank.DA_FU and state.get_current_year() >= 3,
		"Ordinary harvests and sleep reach the year, rank and contribution gates."):
		_end(true)
		return
	_expect(state.well_fields.size() == 2 and state.well_fields[1]["is_unlocked"] and rice_harvested and state.raids_defeated >= 1
		and state.silk_workshop.bolts > 0, "The campaign includes expansion, irrigated rice, silk and an actual defense.")
	print("CAMPAIGN_DECISION day=", state.current_day, " public_ratio=", state.public_contribution_ratio(), " copper=", state.money)
	if branch == "traditional":
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

	var silk_panel := _management(4).get_node("HBoxContainer/RightPanel/蚕桑")
	silk_panel.buttons[5 if branch == "traditional" else 4].pressed.emit()
	_close(ui.panel_manager.management_panel_instance)
	await tree.process_frame
	if not _expect(state.outcome == state.Outcome.RUNNING and state.route_objectives()[1]["value"] == 1, "Silk counts on the matching branch without skipping the other objectives."):
		_end(true)
		return
	await _save_return_continue()
	var last_day: int = state.current_day + 28
	while state.current_day < last_day and state.outcome == state.Outcome.RUNNING and not state.route_ready_to_present():
		_harvest_and_tend(FIRST, KEY_1 if state.fertile_cells.has(FIRST) else KEY_5, true)
		_harvest_and_tend(SECOND, KEY_1 if state.fertile_cells.has(SECOND) else KEY_5, true)
		for x in range(8, 11):
			for y in range(4, 7):
				var cell := Vector2i(x, y)
				if cell != SECOND:
					_harvest_and_tend(cell, KEY_7, branch == "reformed" or x == 8)
		_provision(state.retainer_food_cost())
		await tree.process_frame
		if state.outcome == state.Outcome.RUNNING and not state.route_ready_to_present():
			await _sleep()
	if not _expect(state.route_ready_to_present() and not tree.paused, "All goals lead to a playable handoff."):
		print("CAMPAIGN_MISSING ", state.route_objectives())
		_end(true)
		return
	if branch == "reformed":
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
	if use_night_rations:
		_expect(delegated_nights > 0 and state.night_rations.enabled,
			"Nightly rations operate through the campaign and survive its save and continue.")
	var outcome_view := tree.current_scene.get_node("CampaignHUD")
	var ending: Control = outcome_view.summary
	if not _expect(ending != null and ending.shot == ending.Shot.CEREMONY and ending.film.visible and not ui.visible
			and ending.stage.global_position == stand.global_position,
			"The film starts at the same ledger the player just presented."):
		_end(true)
		return
	if not capture_directory.is_empty():
		await tree.create_timer(2.0).timeout
		_expect(ending.shot == ending.Shot.CEREMONY, "The ceremony starts with the envoy's arrival.")
		await _capture_ending(capture_directory, "ending-" + branch + "-ceremony")
		await tree.create_timer(2.1).timeout
		_expect(ending.shot == ending.Shot.FIELD, "The film returns to the fields after the handoff.")
		await _capture_ending(capture_directory, "ending-" + branch + "-fields")
		if not ending.report.visible:
			await ending.film_finished
		await _capture_ending(capture_directory, "ending-" + branch)
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
