extends RefCounted

const PUBLIC := Vector2i(5, 5)
const EXPANSION := Vector2i(9, 5)
const EXPANSION_PRIVATE := EXPANSION + Vector2i.DOWN
const HOME := Vector2(42, 98)
const MOVEMENT := [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]

var tree: SceneTree
var state: Node
var world: Node2D
var ui: CanvasLayer
var capture_dir := ""
var failures := 0
var promoted_day := 0
var commissioned_day := 0
var checked_shortage := false
var used_promotion_action := false
var used_market_shortcut := false
var construction_provision_clicks := 0
var used_construction_reserve := false

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		push_error(message)
	return condition

func _key(code: Key, character := 0, control := false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.pressed = down
		event.keycode = code
		event.physical_keycode = code
		event.unicode = character
		event.ctrl_pressed = control
		tree.root.push_input(event, true)

func _click(point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	tree.root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = down
		tree.root.push_input(event, true)
	await tree.process_frame

func _button(button: Control) -> void:
	await _click(button.get_global_rect().get_center())
	await tree.process_frame
	await tree.process_frame

func _find_button(panel: Node, prefix: String) -> Button:
	for button: Button in panel.find_children("*", "Button", true, false):
		if button.text.begins_with(prefix):
			return button
	return null

func _cell_point(cell: Vector2i) -> Vector2:
	var tiles: TileMapLayer = world.tile_map
	return tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)

func _walk_to(destination: Vector2) -> void:
	var player: Player = world.player
	for frame in range(210):
		if player.position.distance_to(destination) <= 4.0:
			break
		var step := player.position.direction_to(destination)
		var strength := Vector4(-step.x, step.x, -step.y, step.y)
		for index in MOVEMENT.size():
			if strength[index] > 0.0:
				Input.action_press(MOVEMENT[index], strength[index])
			else:
				Input.action_release(MOVEMENT[index])
		await tree.physics_frame
	for action in MOVEMENT:
		Input.action_release(action)
	await tree.process_frame

func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)
	print("ESTATE_PROGRESS_FRAME ", name, " ", image.get_size())

func _load_title(continue_game: bool) -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	var button: Button = tree.current_scene.continue_button if continue_game else tree.current_scene.new_button
	await _button(button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.name == "Main", "Enter the estate through the title menu."):
		return false
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame
	return true

func _open_survey() -> Control:
	await _button(ui.reclaim_button)
	return ui.get_node_or_null("Control/ReclamationPanel")

func _check_opening() -> bool:
	var sheet := await _open_survey()
	if not _expect(sheet != null, "Open the same reclamation ledger available to the player."):
		return false
	_expect("下士 · 1/1" in sheet.rank_label.text and "1/3" in sheet.workers_label.text and "声望 0/100" in sheet.info_label.text,
		"The blocked survey shows the starting rank, labor and promotion thresholds.")
	_expect("中士" in sheet.subtitle.text and sheet.plan.copper == state.balance.reclamation_cost_copper * 2
		and sheet.plan.grain == state.balance.reclamation_cost_food * 2, "The estimate uses the rank that can add the second field.")
	var panel := sheet.get_node("Panel") as Control
	_expect(tree.root.get_visible_rect().encloses(panel.get_global_rect())
		and not panel.get_global_rect().has_point(_cell_point(EXPANSION)), "The ledger leaves the field visible.")
	await _click(_cell_point(EXPANSION))
	_expect(sheet.reclaim_button.disabled and not sheet.has_selection and sheet.validity_label.text.is_empty(),
		"A full rank allowance explains promotion before surveying any tile.")
	await _click(_cell_point(PUBLIC))
	_expect(not ui.sleep_button.is_visible_in_tree() and not state.tilled_cells.has(PUBLIC),
		"The survey owns map clicks and hides the regular action buttons.")
	await _capture("01-preparation")
	_key(KEY_ESCAPE)
	await tree.process_frame
	_expect(not is_instance_valid(sheet) and ui.sleep_button.is_visible_in_tree() and ui.hud.guide.heading.text == "第一次纳贡",
		"Esc restores the farm controls and the opening guide.")
	return true

func _visit() -> void:
	var visitor = world.current_visitor()
	if visitor == null:
		return
	var actor: Node2D = world.neighbor_actor(visitor.name)
	var speaker: String = visitor.name
	if state.current_day == 2:
		var sheet := await _open_survey()
		if not _expect(sheet != null and sheet.visitor_button.visible and "季青" in sheet.visitor_button.text,
			"The preparation ledger offers directions to the actual day-two visitor."):
			return
		await _button(sheet.visitor_button)
		_expect(not is_instance_valid(sheet) and ui.directions.tracked_neighbor == speaker, "Follow the visitor from the ledger.")
	await _walk_to(actor.position + Vector2(0, -14))
	_key(KEY_E)
	await tree.process_frame
	var dialog := ui.get_node_or_null("Control/DialoguePanel")
	if not _expect(dialog != null and dialog.name_label.text == speaker, "Meet %s by walking up and pressing E." % speaker):
		return
	await _button(_find_button(dialog, "交谈"))
	if state.current_rank >= state.Rank.ZHONG_SHI and state.retainers.size() < state.RECLAMATION_RETAINERS:
		_key(KEY_E)
		await tree.process_frame
		dialog = ui.get_node_or_null("Control/DialoguePanel")
		if not _expect(dialog != null, "Open the ordinary recruitment dialogue."):
			return
		var recruit := _find_button(dialog, "招募")
		if not recruit.disabled:
			var before: int = state.reputation
			var count: int = state.retainers.size()
			await _button(recruit)
			_expect(state.reputation == before - state.balance.recruit_reputation_requirement and state.retainers.size() == count + 1,
				"Recruiting pays the displayed reputation cost once.")
			print("ESTATE_PROGRESS_RECRUIT day=", state.current_day, " name=", speaker, " reputation=", before, "->", state.reputation)
		else:
			await _button(_find_button(dialog, "离开"))

func _tend(cell: Vector2i) -> void:
	if world.field_action(cell) == world.FieldAction.HARVEST:
		await _click(_cell_point(cell))
	if world.field_action(cell) == world.FieldAction.TILL:
		await _click(_cell_point(cell))
	if world.field_action(cell) == world.FieldAction.SOW:
		await _click(_cell_point(cell))
	if world.field_action(cell) == world.FieldAction.WATER:
		await _click(_cell_point(cell))

func _farm() -> void:
	await _walk_to(HOME)
	_key(KEY_1)
	await _tend(PUBLIC)
	_key(KEY_7)
	for y in range(4, 7):
		for x in range(4, 7):
			var cell := Vector2i(x, y)
			if cell != PUBLIC:
				await _tend(cell)

func _defend() -> void:
	if state.raid_day == 0:
		return
	for volley in range(20):
		var raider := tree.get_first_node_in_group("estate_raiders") as Node2D
		if not is_instance_valid(raider):
			break
		var shot := world.get_global_transform_with_canvas() * world.to_local(raider.global_position)
		await _click(shot, MOUSE_BUTTON_RIGHT)
		for frame in range(10):
			await tree.physics_frame
	_expect(state.raid_day == 0 and state.outcome == state.Outcome.RUNNING, "Defend the estate with the default bow and enemy.")

func _provision() -> void:
	var plan: Dictionary = state.reclamation_plan()
	var ration: int = state.retainer_food_cost()
	var expansion_ready: bool = plan.has_space and plan.workers_needed == 0
	var target: int = int(plan.grain) + ration * state.RECLAMATION_NIGHTS if expansion_ready else ration * 2
	if state.food_storage >= target:
		return
	var spare: int = maxi(0, state.money - int(plan.copper)) if expansion_ready else 0
	var buy: int = mini(floori(float(spare) / state.balance.market_food_price), target - state.food_storage)
	if state.player_inventory == 0 and buy == 0:
		return
	var using_construction_plan := expansion_ready and state.has_method("reclamation_food_plan")
	if using_construction_plan or not used_market_shortcut:
		var sheet := await _open_survey()
		if not _expect(sheet != null and sheet.market_button.visible, "The reclamation ledger offers a market shortcut for missing funds."):
			return
		if using_construction_plan:
			await _click(_cell_point(EXPANSION))
		await _button(sheet.market_button)
		used_market_shortcut = true
	else:
		await _button(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	var market: Control = management.market_panel
	if not _expect(market.is_visible_in_tree(), "The market opens directly from the shortage."):
		return
	if expansion_ready:
		print("ESTATE_PROVISIONS day=", state.current_day, " target=", target, " food=", state.food_storage,
			" crops=", state.player_inventory, " copper=", state.money)
	if using_construction_plan and not market.reserve_button.disabled:
		await _use_construction_reserve(market)
		return
	if state.player_inventory > 0:
		await _button(market.all_crops)
		await _button(market.convert_button)
		if expansion_ready:
			construction_provision_clicks += 2
	buy = mini(buy, target - state.food_storage)
	if buy > 0:
		await _button(market.quantity.get_line_edit())
		_key(KEY_A, 0, true)
		for digit in str(buy):
			_key((KEY_0 + int(digit)) as Key, digit.unicode_at(0))
		_key(KEY_ENTER)
		await tree.process_frame
		_expect(int(market.quantity.value) == buy, "Enter the grain quantity through the market control.")
		await _button(market.buy_button)
		if expansion_ready:
			construction_provision_clicks += 2
	await _button(management.get_node("CloseButton"))

func _use_construction_reserve(market: Control) -> void:
	var plan: Dictionary = state.reclamation_food_plan()
	var crops: int = state.player_inventory
	var copper: int = state.money
	var notice: Label = tree.current_scene.get_node("CampaignHUD").notice
	_expect(market.reserve_kind.text == "开垦备粮" and market.survey_button.is_visible_in_tree()
		and "共 %d 份" % plan.target in market.reserve_label.text and "%d 铜钱" % plan.stake_copper in market.reserve_label.text,
		"The selected survey opens a quote that includes both its stake and its crew rations.")
	_expect(not notice.visible, "The world notice clears the market tabs while the quote is open.")
	await _capture("06-construction-provisions")
	await _button(market.reserve_button)
	construction_provision_clicks += 1
	_expect(state.food_storage == plan.target and state.player_inventory == crops - plan.crops
		and state.money == copper - plan.copper and state.money >= plan.stake_copper and market.reserve_button.disabled,
		"One order stocks exactly the displayed grain and leaves the stake money available.")
	_expect("实付 %d 铜钱" % plan.copper in market.receipt.text and "粮已备齐" in market.reserve_label.text,
		"The grain exchange reports its actual cost and completes the quote.")
	await _capture("07-provisions-receipt")
	await _button(market.survey_button)
	var sheet: Control = ui.get_node_or_null("Control/ReclamationPanel")
	_expect(sheet != null and sheet.has_selection and sheet.selected_cell == EXPANSION and not sheet.reclaim_button.disabled,
		"Returning to the survey preserves the selected field and makes its stake order available.")
	_expect(notice.visible, "The world notice returns when the management screen closes.")
	used_construction_reserve = true

func _night() -> void:
	var yesterday: int = state.current_day
	var rank: int = state.current_rank
	var action: Button = ui.hud.opening_action
	if rank == state.Rank.XIA_SHI and state.eligible_for_promotion():
		if not _expect(action.visible and action.text == "查看今夜安排", "The first promotion has a shortcut to the night's plan."):
			return
		await _capture("02a-promotion-action")
		await _button(action)
		var night := ui.get_node_or_null("Control/NightRationsPanel") as Control
		if not _expect(night != null and not night.show_previous, "The promotion action opens the current plan before advancing."):
			return
		await _button(night.get_node("%Sleep"))
		used_promotion_action = true
	else:
		await _button(ui.sleep_button)
	await tree.create_timer(0.56).timeout
	var caption: String = ui.dawn_caption.text
	var promoted: bool = promoted_day == 0 and rank < state.current_rank
	if promoted:
		promoted_day = state.current_day
		_expect("晋升中士" in caption and "井田上限 2 块" in caption, "Dawn presents the earned rank and the new allowance.")
		print("ESTATE_PROGRESS_PROMOTION day=", promoted_day, " tribute=", state.king_storage, " reputation=", state.reputation)
		await _capture("02-promotion-dawn")
	await tree.create_timer(0.54).timeout
	_expect(state.current_day == yesterday + 1 and state.night_rations.last.served == state.night_rations.last.need,
		"Ordinary sleep advances one day and the prepared ration feeds the household.")
	if promoted:
		_expect("晋升中士" in ui.hud.morning_button.text, "The calendar signals a new rank.")
		await _button(ui.hud.morning_button)
		var record: Control = ui.get_node_or_null("Control/NightRationsPanel")
		if _expect(record != null and "晋升中士" in record.milestones.text and "井田上限 2 块" in record.milestones.text,
			"The new title and field allowance remain readable after the fade."):
			await _button(record.close_button)

func _check_shortage() -> void:
	var action: Button = ui.hud.opening_action
	if not _expect(action.visible and action.text == "查看开垦筹备", "The promoted estate's journal links to the new survey."):
		return
	await _capture("02b-first-expansion-action")
	await _button(action)
	var sheet := ui.get_node_or_null("Control/ReclamationPanel") as Control
	if not _expect(sheet != null, "Open the survey from the journal after a natural promotion."):
		return
	await _click(_cell_point(EXPANSION))
	_expect(sheet.plan.has_space and sheet.has_selection and sheet.reclaim_button.disabled and "0/9" in sheet.validity_label.text,
		"An eligible site can be surveyed while household requirements are still missing.")
	_key(KEY_ESCAPE)
	await tree.process_frame
	checked_shortage = true

func _commission() -> bool:
	var sheet: Control = ui.get_node_or_null("Control/ReclamationPanel")
	if sheet == null:
		sheet = await _open_survey()
	if not _expect(sheet != null, "Open the funded survey through its HUD button."):
		return false
	if not sheet.has_selection:
		await _click(_cell_point(PUBLIC))
		_expect("已有井田太近" in sheet.validity_label.text and sheet.reclaim_button.disabled,
			"The occupied spot explains why the new field cannot go there.")
		await _click(_cell_point(EXPANSION))
	if not _expect(sheet.selected_cell == EXPANSION and not sheet.reclaim_button.disabled and "已选田址" in sheet.validity_label.text,
		"Choosing an open site enables the stake order."):
		return false
	if not capture_dir.is_empty():
		await tree.create_timer(1.0).timeout
	await _capture("03-selected-site")
	var money: int = state.money
	var food: int = state.food_storage
	var cost: Dictionary = state.reclamation_plan()
	await _button(sheet.reclaim_button)
	await _button(sheet.reclaim_button)
	if not _expect(state.well_fields.size() == 2 and state.money == money - cost.copper and state.food_storage == food - cost.grain
		and sheet.worksite_button.visible, "Staking charges one order and leaves directions to the worksite."):
		return false
	_expect("已扣 %d 枚" % cost.copper in sheet.copper_label.text and "已扣 %d 份" % cost.grain in sheet.grain_label.text,
		"The receipt states what was just paid for this worksite.")
	commissioned_day = state.current_day
	print("ESTATE_PROGRESS_COMMISSION day=", commissioned_day, " copper=", cost.copper, " grain=", cost.grain, " workers=", state.retainers.size())
	print("ESTATE_PROVISIONS_RESULT clicks=", construction_provision_clicks, " food_after_staking=", state.food_storage)
	await _capture("04-staked")
	await _button(sheet.worksite_button)
	_expect(ui.directions.tracked_site == 1, "Find the commissioned worksite from the receipt.")
	return true

func _complete_expansion() -> void:
	for day in range(state.RECLAMATION_NIGHTS):
		await _defend()
		await _night()
	if not _expect(state.get_well_field(1).is_unlocked and state.current_day == commissioned_day + state.RECLAMATION_NIGHTS,
		"Ordinary sleep opens the new well field on its fourth dawn."):
		return
	var day: int = state.current_day
	if not await _load_title(true):
		return
	var tiles: TileMapLayer = world.tile_map
	_expect(state.current_day == day and state.get_well_field(1).is_unlocked
		and tiles.get_cell_tile_data(EXPANSION).get_custom_data("is_public_field"), "The dawn checkpoint restores the finished field.")
	_expect(not ui.hud.opening_action.visible, "The opening shortcut clears after the second well is established.")
	_expect("井田完工" in ui.hud.morning_button.text, "The calendar signals the opened field after Continue.")
	await _button(ui.hud.morning_button)
	var record: Control = ui.get_node_or_null("Control/NightRationsPanel")
	if not _expect(record != null and "井田 2 已完工" in record.milestones.text, "The finished field stays in the morning record after Continue."):
		return
	await _capture("08-morning-field-handover")
	await _button(record.plan_field)
	var management: Control = ui.panel_manager.management_panel_instance
	if not _expect(not is_instance_valid(record) and is_instance_valid(management) and management.visible and not world.player.conversation_open
		and management.well_field_selector.get_selected_id() == 1 and management.steward_picker.has_focus()
		and "先翻田" in management.steward_preview.text, "The morning record opens the new field with clear instructions and selector focus."):
		return
	await _button(management.close_button)
	_key(KEY_1)
	await _tend(EXPANSION)
	await _click(_cell_point(EXPANSION_PRIVATE))
	_expect(state.active_crops.has(EXPANSION), "The completed field can be cultivated after reloading.")
	await _capture("05-first-crop-on-the-new-field")
	print("ESTATE_PROGRESS_FINISHED day=", day, " raids_defeated=", state.raids_defeated, " tribute=", state.king_storage)
	await _try_stewardship()

func _try_stewardship() -> void:
	await _button(ui.hud.farm_status)
	var map: Control = ui.estate_map
	var field_row: Button
	for row: Button in map.row_buttons:
		if map.row_buttons[row].get("field_id") == 1:
			field_row = row
			break
	if not _expect(map.modal.visible and field_row != null, "Find the finished field in the normal map."):
		return
	await _button(field_row)
	if not _expect(map.manage_field.is_visible_in_tree(), "The selected field offers a management action."):
		return
	await _capture("08b-map-field-handover")
	await _button(map.manage_field)
	var panel: Control = ui.panel_manager.management_panel_instance
	if not _expect(panel.visible and not tree.paused and not map.modal.visible
		and panel.well_field_selector.get_selected_id() == 1, "The map opens the same field after the morning record."):
		return
	var keeper = state.retainers.front()
	var before_need: int = state.retainer_food_cost()
	var after_need: int = before_need + state.balance.specialist_food_per_night
	await _button(panel.steward_picker)
	var popup: PopupMenu = panel.steward_picker.get_popup()
	if not _expect(popup.visible, "Open the ordinary steward selection menu."):
		return
	_key(KEY_DOWN)
	await tree.process_frame
	if popup.get_focused_item() == 0:
		_key(KEY_DOWN)
		await tree.process_frame
	_key(KEY_ENTER)
	await tree.process_frame
	if not _expect(panel.steward_picker.get_selected_metadata() == keeper and not popup.visible
		and "全员每夜用粮 %d → %d 份" % [before_need, after_need] in panel.steward_preview.text
		and "粮仓 0 份" in panel.steward_preview.text and "公田 1 格" in panel.steward_preview.text
		and "私田 1 格" in panel.steward_preview.text and not state.field_seed_plans.has(EXPANSION_PRIVATE),
		"Caretaker quote after keyboard selection (index %d, open %s): %s" % [
			panel.steward_picker.selected, popup.visible, panel.steward_preview.text]):
		return
	await _capture("09-steward-quote")
	var public_plan: String = state.tribute_seed()
	await _button(panel.apply_steward)
	_expect(state.field_seed_plans.get(EXPANSION) == public_plan and state.field_seed_plans.get(EXPANSION_PRIVATE) == "seasonal"
		and state.retainer_food_cost() == after_need and state.stewarded_field(keeper).field_id == 1,
		"Applying keeps the standing public crop and sets only the two prepared plots to be resown.")
	await _button(panel.close_button)
	await _defend()
	await _walk_to(HOME)
	for y in range(4, 7):
		for x in range(4, 7):
			var cell := Vector2i(x, y)
			if cell != PUBLIC and world.field_action(cell) == world.FieldAction.HARVEST:
				await _click(_cell_point(cell))
	await _button(ui.hud.rations_button)
	var night: Control = ui.get_node_or_null("Control/NightRationsPanel")
	if not _expect(night != null and "缺 %d 份" % after_need in night.forecast.text,
		"Today's night forecast shows the full household shortage after appointment."):
		return
	await _button(night.get_node("%Market"))
	var market: Control = panel.market_panel
	var reserve: Dictionary = state.food_reserve_plan(3)
	if not _expect(market.is_visible_in_tree() and reserve.copper <= state.money and not market.reserve_button.disabled,
		"Three-night reserve (visible %s, food %d, copper %d/%d, mode %d): %s" % [
			market.is_visible_in_tree(), reserve.food, reserve.copper, state.money, market.reserve_kind.selected, market.reserve_label.text]):
		return
	await _button(market.reserve_button)
	await _button(panel.close_button)
	var tribute: int = state.king_storage
	var private_yield: int = state.private_harvest_total
	var day: int = state.current_day
	for _night_index in 3:
		await tree.create_timer(8.0).timeout
		await _defend()
		await _night()
	await _button(ui.hud.farm_status)
	map = ui.estate_map
	_expect(map.modal.visible and "管事 " + keeper.name in map.fields[1].needs,
		"The field page names the appointed caretaker after the growing trial.")
	await _button(map.close_button)
	if not await _load_title(true):
		return
	keeper = state.retainers.front()
	_expect(state.current_day == day + 3 and state.king_storage > tribute and state.private_harvest_total > private_yield
		and state.stewarded_field(keeper).field_id == 1 and state.field_seed_plans.has(EXPANSION_PRIVATE)
		and state.night_rations.last.served == after_need and state.food_storage == 0,
		"Three ordinary nights produce both kinds of harvest with no player field clicks and preserve the appointment on Continue.")
	print("ESTATE_PROGRESS_STEWARD day=", state.current_day, " tribute=", state.king_storage - tribute,
		" private=", state.private_harvest_total - private_yield, " ration=", after_need, " manual_field_clicks=0")

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	if capture_dir.is_empty():
		capture_dir = OS.get_environment("FIEFDOM_RECLAMATION_CAPTURES")
	seed(520)
	if tree.root.size.x < 900:
		tree.root.size = Vector2i(1280, 720)
	tree.root.notify_mouse_entered()
	if await _load_title(false) and await _check_opening():
		while state.current_day < 36 and failures == 0:
			await _defend()
			if state.retainers.size() < state.RECLAMATION_RETAINERS:
				await _visit()
			await _farm()
			var action: Button = ui.hud.opening_action
			if action.visible and action.text == "首茬收成 · 安排去处":
				await _button(action)
				var harvest := ui.get_node_or_null("Control/DialoguePanel") as Control
				if not _expect(harvest != null, "The natural first private harvest offers its storage choice."):
					break
				await _button(_find_button(harvest, "用 1 份"))
			var plan: Dictionary = state.reclamation_plan()
			if plan.has_space and not plan.ready and not checked_shortage:
				await _check_shortage()
			await _provision()
			plan = state.reclamation_plan()
			if plan.ready and state.food_storage >= int(plan.grain) + state.retainer_food_cost() * state.RECLAMATION_NIGHTS:
				if await _commission():
					await _complete_expansion()
				break
			await _night()
	_expect(promoted_day > 0 and used_promotion_action and commissioned_day > promoted_day and checked_shortage and used_market_shortcut,
		"Complete promotion, recruiting, provisioning and the first expansion from the original new game.")
	if state.has_method("reclamation_food_plan"):
		_expect(used_construction_reserve and construction_provision_clicks == 1,
			"Reserve construction provisions in one market action during the natural first expansion.")
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
