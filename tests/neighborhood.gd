extends SceneTree

const Campaign := preload("res://tests/CampaignReplay.gd")
const PUBLIC := Vector2i(5, 5)
const PRIVATE := [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(4, 5),
	Vector2i(6, 5), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6)]

var failed := false
var state: Node
var world: Node
var ui: Node

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failed = true
		push_error(detail)
	return condition

func _estate() -> void:
	world = current_scene.get_node("World")
	ui = current_scene.get_node("UI")

func _night() -> void:
	ui.sleep_button.pressed.emit()
	await create_timer(1.1).timeout

func _open_at(target: Node2D, offset := Vector2(0, 18)) -> Control:
	await Campaign.walk_estate_road_to(self, world, target.global_position + offset)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	root.push_input(key, true)
	await process_frame
	return ui.get_node_or_null("Control/DialoguePanel") as Control

func _option(dialog: Control, prefix: String) -> Button:
	if dialog:
		for button: Button in dialog.options_container.get_children():
			if button.text.begins_with(prefix):
				return button
	return null

func _choose(dialog: Control, prefix: String) -> void:
	var button := _option(dialog, prefix)
	if _expect(button != null and not button.disabled, "The dialogue must offer " + prefix):
		button.pressed.emit()
	await process_frame

func _journal(speaker: String) -> Control:
	ui.hud.neighbors_button.pressed.emit()
	await process_frame
	var management: Control = ui.panel_manager.management_panel_instance
	var journal: Control = management.neighbor_journal
	var entry := journal.roster.get_node(speaker) as Button
	_expect(journal.is_visible_in_tree() and entry.is_visible_in_tree(), "The HUD opens the neighborhood journal at a known person.")
	entry.pressed.emit()
	await process_frame
	return journal

func _close_journal() -> void:
	ui.panel_manager.management_panel_instance.get_node("CloseButton").pressed.emit()
	await process_frame

func _save_and_load() -> bool:
	if not _expect(state.save_game() == OK and state.load_game() == OK, "The current state must save and reload."):
		return false
	await scene_changed
	_estate()
	return true

func _tend_public() -> void:
	if world.field_action(PUBLIC) == world.FieldAction.HARVEST:
		world.handle_interaction(PUBLIC)
	if world.field_action(PUBLIC) == world.FieldAction.SOW:
		world.handle_interaction(PUBLIC)
	if world.field_action(PUBLIC) == world.FieldAction.WATER:
		world.handle_interaction(PUBLIC)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run neighborhood with Test-GodotSmoke.ps1 to isolate its saves.")
		quit(1)
		return
	seed(1087)
	state = root.get_node("Global")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	_estate()
	# Keep combat out of this run so the same estate can be inspected through day ten.
	state.balance.raid_first_day = 10000
	var journal := await _journal("渠伯")
	_expect(journal.known_count.text.contains("1 / 7") and not journal.roster.get_node("季青").visible and "田边" in journal.where.text,
		"The starting neighbor is listed, and unfamiliar neighbors are revealed by meeting them.")
	await _close_journal()
	for cell in [PUBLIC] + PRIVATE:
		for action in range(3):
			world.handle_interaction(cell)
	await _night()
	var guest: Node2D = world.active_visitors.front()
	var dialogue := await _open_at(guest)
	_expect(dialogue != null and dialogue.name_label.text == "季青" and not state.visitor_encounters.has("季青"),
		"Opening the introduction records a meeting before any daily talk reward.")
	await _choose(dialogue, "离开")
	journal = await _journal("季青")
	_expect("第 2 天相识" in journal.first_meeting.text and "南路亭 · 今日来访" in journal.where.text,
		"The journal shows the actual first visit date and today's location.")
	await _close_journal()
	await _choose(await _open_at(guest), "交谈")
	for cell in [PUBLIC] + PRIVATE:
		if world.field_action(cell) == world.FieldAction.WATER:
			world.handle_interaction(cell)
	await _night()
	var mohist := await _open_at(world.active_visitors.front(), Vector2(-18, -10))
	_expect(mohist != null and mohist.name_label.text == "石墨", "Walk to Stone Ink at the source on day three.")
	await _choose(mohist, "离开")
	world.handle_interaction(PRIVATE[0])
	while state.current_day < 7:
		_tend_public()
		await _night()
		if state.current_day < 7:
			var meeting := await _open_at(world.active_visitors.front())
			_expect(meeting != null and meeting.name_label.text == world.current_visitor().name,
				"Walk to the named visitor on day %d." % state.current_day)
			await _choose(meeting, "离开")
		if state.current_day == 6:
			await _choose(await _open_at(world.get_node("SpringGathering/Guests/商音")), "离开")
	_tend_public()
	_expect(state.first_tribute_delivered() and state.player_inventory == 1 and state.money < state.balance.road_rest_cost,
		"Tribute and one private harvest let Ji Qing offer the initial road food favor.")
	guest = world.active_visitors.front()
	await _choose(await _open_at(guest), "送路粮")
	dialogue = await _open_at(guest)
	_expect(state.road_provisions_day == 7 and _option(dialogue, "修歇脚处") == null and not state.fund_road_rest(),
		"The follow-up waits until another day after the road food handoff.")
	await _choose(dialogue, "招募")
	var resident: Resource = state.retainers.back()
	_expect(resident.name == "季青", "Ji Qing can stay in the estate before the second favor.")
	ui.manage_button.pressed.emit()
	await process_frame
	var management: Control = ui.panel_manager.management_panel_instance
	management.tabs.current_tab = 0
	management.retainer_list_container.get_child(1).duty_picker.item_selected.emit(2)
	await _close_journal()
	await create_timer(2.6).timeout
	await _night()
	var actor: Node2D = world.retainer_instances[resident]
	dialogue = await _open_at(actor)
	if not _expect(dialogue != null and dialogue.name_label.text == "季青", "Ji Qing must be reachable at the teaching courtyard."):
		quit(1)
		return
	var fund := _option(dialogue, "修歇脚处")
	_expect(fund != null and fund.disabled and "长凳" in dialogue.text_label.text and not state.fund_road_rest(),
		"The recruited neighbor remembers the favor, and an unaffordable project cannot spend funds.")
	await _choose(dialogue, "离开")
	for cell in PRIVATE.slice(1):
		world.handle_interaction(cell)
	_expect(state.prepare_food_reserve(2), "The private harvest can feed both retainers while the bench is built.")
	var copper: int = state.money
	var road_rest := world.get_node("RoadRest") as Node2D
	_expect(not road_rest.visible, "The bench is absent before funding.")
	await _choose(await _open_at(actor), "修歇脚处")
	_expect(state.money == copper - state.balance.road_rest_cost and state.road_rest_paid_day == 8 and road_rest.visible
		and not road_rest.is_in_group("interactable") and not state.fund_road_rest(), "Funding is charged once and puts materials on site until morning.")
	journal = await _journal("季青")
	print("NEIGHBOR_LEDGER ", state.neighbor_met_days, " ", journal.known_count.text, " ", journal.where.text,
		" / ", journal.first_meeting.text, " / ", journal.memory.text, " / ", journal.next_step.text)
	_expect(journal.known_count.text.contains("7 / 7") and "第 2 天相识" in journal.first_meeting.text
		and "堂前" in journal.where.text and "礼仪教习" in journal.where.text
		and "第 7 天" in journal.memory.text and "第 8 天" in journal.memory.text and "过一夜" in journal.next_step.text,
		"The neighbor page preserves first acquaintance, changed role, and the two dated favors.")
	await _close_journal()
	if not await _save_and_load():
		quit(1)
		return
	road_rest = world.get_node("RoadRest")
	_expect(road_rest.visible and not road_rest.is_in_group("interactable") and state.road_rest_paid_day == 8,
		"Reloading a paid afternoon restores construction without advancing it.")
	await _night()
	_expect(road_rest.is_in_group("interactable") and state.road_rest_built(), "The physical rest spot opens on the next morning.")
	dialogue = await _open_at(road_rest)
	var rest := _option(dialogue, "歇一歇")
	_expect(rest != null and rest.disabled and not state.use_road_rest(), "Resting while full does not consume the daily visit.")
	await _choose(dialogue, "离开")
	for cell in PRIVATE:
		world.handle_interaction(cell)
		world.handle_interaction(cell)
	var tired: int = state.current_stamina
	await _choose(await _open_at(road_rest), "歇一歇")
	_expect(state.current_stamina == mini(tired + state.balance.road_rest_stamina, state.max_stamina)
		and state.road_rest_used_day == state.current_day and not state.use_road_rest(), "Rest restores the advertised capped amount once.")
	if not await _save_and_load():
		quit(1)
		return
	road_rest = world.get_node("RoadRest")
	dialogue = await _open_at(road_rest)
	rest = _option(dialogue, "歇一歇")
	_expect(rest != null and rest.disabled and "今天已经" in dialogue.text_label.text, "Same-day reload preserves the spent rest and its feedback.")
	await _choose(dialogue, "离开")
	await _night()
	_tend_public()
	_expect(state.road_rest_recovery() > 0, "The bench is usable again the next day after working.")
	var legacy := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	legacy.store_string('{"current_day":12,"money":12,"king_storage":1,"visitor_encounters":["季青"],"road_provisions_delivered":true}')
	legacy.close()
	if not _expect(state.load_game(state.SAVE_PATH) == OK, "The old road food save loads."):
		quit(1)
		return
	await scene_changed
	_estate()
	journal = await _journal("季青")
	_expect("旧日相识" in journal.first_meeting.text and "木匣" in journal.memory.text and "修歇脚处" in journal.next_step.text,
		"The journal recovers an old acquaintance and completed favor without inventing a first meeting date.")
	await _close_journal()
	await _choose(await _open_at(world.active_visitors.front()), "修歇脚处")
	_expect(state.road_rest_paid_day == 12 and state.money == 0, "A returning nonresident can start the follow-up from an old save.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
