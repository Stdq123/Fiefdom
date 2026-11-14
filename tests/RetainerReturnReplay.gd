extends "res://tests/NightRationsReplay.gd"

const Campaign := preload("res://tests/CampaignReplay.gd")
const TITLE := "res://scenes/Title.tscn"
const KEEPER := "渠伯"
const TEACHER := "季青"
const REELER := "石墨"

var world: Node
var legacy := false

func _write_fixture(snapshot: Dictionary) -> void:
	var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot))
	file.close()

func _continue() -> void:
	tree.change_scene_to_file(TITLE)
	await tree.scene_changed
	tree.current_scene.continue_button.pressed.emit()
	await tree.scene_changed
	await _estate()

func _estate() -> void:
	await tree.process_frame
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")

func _buy_grain(portions: int) -> void:
	var plan := await _open()
	await _click(plan.get_node("%Market"))
	var management: Control = ui.panel_manager.management_panel_instance
	var market: Control = management.market_panel
	market.quantity.value = portions
	await _click(market.buy_button)
	await _click(management.get_node("CloseButton"))

func _option(dialog: Control, prefix: String) -> Button:
	for button: Button in dialog.options_container.get_children():
		if button.text.begins_with(prefix):
			return button
	return null

func _talk_to(speaker: String) -> Control:
	var visitor: Node2D = world.neighbor_actor(speaker)
	if not _expect(visitor != null, speaker + " returns on the scheduled morning."):
		return null
	await Campaign.walk_estate_road_to(tree, world, visitor.global_position + Vector2(0, 16))
	_key(KEY_E)
	await tree.process_frame
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	return dialog if _expect(dialog != null and dialog.name_label.text == speaker, "Speak to " + speaker) else null

func _journal() -> Control:
	await _click(ui.hud.neighbors_button)
	return ui.panel_manager.management_panel_instance.neighbor_journal

func _reach_keeper_visit() -> void:
	_write_fixture({
		"current_day": 49, "food_storage": 2, "money": 40, "king_storage": 3, "reputation": 70,
		"retainers": [
			{"name": KEEPER, "school": 2, "duty": 0, "loyalty": 20},
			{"name": TEACHER, "school": 1, "duty": 2, "loyalty": 80},
			{"name": REELER, "school": 2, "duty": 1, "loyalty": 18},
		],
		"neighbor_met_days": {KEEPER: 1, TEACHER: 2, REELER: 3},
		"night_rations": {"priority": 1},
		"silk_workshop": {"built": true},
		"well_fields": [{"center_pos": "5,5", "is_unlocked": true, "reclamation_progress": 4}],
		"field_rotation": {"promise_day": 3, "beans_day": 7, "harvest_day": 10,
			"field_number": 1, "crop_id": "wheat", "signed_day": 10},
	})
	await _continue()
	await _sleep()
	_expect(state.current_day == 50 and state.retainers.size() == 1 and state.retainers[0].name == TEACHER
		and state.night_rations.last.departed == PackedStringArray([KEEPER, REELER]),
		"The shortage sends the unfed keeper and reeler away while the teacher stays.")
	await _buy_grain(2)
	await _sleep()
	_expect(state.current_day == 51 and state.food_storage == 0 and state.field_rotation.signed_day == 10,
		"A normally fed night reaches the scheduled keeper visit with the signed book intact.")

func _invite_keeper(dialog: Control) -> void:
	var invitation := _option(dialog, "请回来")
	if not _expect(invitation != null and not invitation.disabled, "The keeper can return with enough food."):
		return
	var visitor: String = world.current_visitor().name
	var reputation: int = state.reputation
	await _click(invitation)
	var keeper: RetainerData = state.retainers.back()
	_expect(keeper.name == KEEPER and keeper.school == RetainerData.School.MOHIST and keeper.duty == RetainerData.Duty.FIELD
		and world.retainer_instances.has(keeper) and world.field_guest == null,
		"The keeper becomes a field worker, replacing the visiting actor.")
	_expect(world.current_visitor().name == visitor and state.food_storage == 3 and state.king_storage == 3
		and state.reputation == reputation - state.balance.recruit_reputation_requirement,
		"The scheduled guest remains. Inviting the keeper uses reputation and reserves the three portions for supper.")
	print("RETAINER_RETURN_KEEPER day=", state.current_day, " duty=", keeper.duty_name(), " grain=", state.food_storage, " guest=", visitor)

func _play_keeper_return() -> void:
	await _reach_keeper_visit()
	await _continue()
	var journal := await _journal()
	_expect("第 49 天夜 · 缺餐后离任" in journal.memory.text and "井田西南" in journal.where.text
		and "轮作簿" in journal.memory.text and "粮仓 0 / 3" in journal.where.text,
		"The morning save keeps the departure after the later meal receipt replaced it.")
	await _capture("01-keeper-journal")
	await _click(journal.locate_button)
	_expect(not ui.panel_manager.management_panel_instance.visible, "The journal can guide the player back to the keeper.")
	await _buy_grain(2)
	var dialog := await _talk_to(KEEPER)
	if not _expect(dialog != null, "Speak to the keeper beside the fields."):
		return
	var invitation := _option(dialog, "请回来")
	_expect(invitation != null and invitation.disabled and "那夜没分到饭" in dialog.text_label.text
		and "现有 2 / 3" in dialog.text_label.text, "The keeper remembers the missed meal and asks for one more portion.")
	await _capture("02-one-portion-short")
	await _click(_option(dialog, "离开"))
	await _buy_grain(1)
	dialog = await _talk_to(KEEPER)
	if not _expect(dialog != null and "现有 3 / 3" in dialog.text_label.text, "The dialogue reflects the grain purchase."):
		return
	await _capture("03-ready-to-return")
	await _invite_keeper(dialog)
	_expect(state.save_game() == OK, "Save the keeper's return.")
	await _continue()
	journal = await _journal()
	_expect("第 49 天夜 · 缺餐后离任" in journal.memory.text and "第 51 天 · 应邀回来照料田地" in journal.memory.text
		and "留任门客" in journal.where.text and world.current_visitor().name == "弋戎",
		"The returning worker, older story, and other visitor survive continue.")
	await _capture("04-keeper-back-at-work")
	await _click(ui.panel_manager.management_panel_instance.get_node("CloseButton"))
	await _sleep()
	_expect(state.current_day == 52 and state.night_rations.last.served == 3 and state.night_rations.last.need == 3
		and state.food_storage == 0 and state.king_storage == 3 and state.retainers.size() == 2,
		"Only the ordinary dinner consumes the reserved grain.")
	await _buy_grain(3)
	await _sleep()
	dialog = await _talk_to(REELER)
	if dialog:
		invitation = _option(dialog, "请回来")
		_expect(invitation != null and invitation.disabled and "磨坊" in dialog.text_label.text
			and "现有 0 / 4" in dialog.text_label.text, "Another former worker remembers their departure and checks the new roster's needs.")
		await _click(_option(dialog, "离开"))

func _play_reform_return() -> void:
	_write_fixture({
		"current_day": 56, "current_rank": 3, "king_storage": 12, "food_storage": 1,
		"reputation": 90, "tax_council_invited": true, "neighbor_met_days": {TEACHER: 2},
		"retainers": [{"name": KEEPER, "school": 2}, {"name": TEACHER, "school": 1, "loyalty": 35, "duty": 2}],
	})
	if not _expect(state.load_game(state.SAVE_PATH) == OK, "Load a council with an undecided reform."):
		return
	await tree.scene_changed
	await _estate()
	state.balance.raid_first_day = 100
	var council := await Campaign.meet_tax_envoy(tree)
	if not _expect(council != null, "Meet the envoy through the usual council entry."):
		return
	await _click(council.option_buttons[state.TaxReformChoice.REFORMED])
	await _click(council.confirm_button)
	_expect(state.pending_neighbor_return(TEACHER).get("reason") == state.DepartureReason.REFORM and state.retainers.size() == 1,
		"The policy causes a departure for a different reason.")
	await _sleep()
	await _continue()
	var dialog := await _talk_to(TEACHER)
	if not _expect(dialog != null, "The former teacher comes back on the visitor rotation."):
		return
	var invitation := _option(dialog, "请回来")
	if not _expect(invitation != null and not invitation.disabled and state.food_storage == 0
		and "议税那天" in dialog.text_label.text and "现有" not in dialog.text_label.text,
		"Reform dialogue recalls the council and retains the usual recruitment cost."):
		return
	await _capture("05-reform-reunion")
	await _click(invitation)
	var journal := await _journal()
	await _click(journal.roster.get_node(TEACHER))
	_expect(state.retainers.size() == 2 and state.tax_reform_choice == state.TaxReformChoice.REFORMED
		and "第 56 天 · 议税后离任" in journal.memory.text and "第 57 天 · 应邀回来" in journal.memory.text,
		"The journal keeps both events and the chosen reform remains in force.")
	print("RETAINER_RETURN_REFORM day=", state.current_day, " grain=", state.food_storage, " guest=", TEACHER)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_RETURN_CAPTURES")
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated profile."):
		_end()
		return
	if legacy:
		await _continue()
		_expect(state.current_day == 51 and state.neighbor_departures.is_empty() and state.field_rotation.signed_day == 10,
			"The prior packaged save loads without guessing the reason for an earlier departure.")
		var dialog := await _talk_to(KEEPER)
		if _expect(dialog != null and "现有 3 / 3" in dialog.text_label.text, "The legacy visit now offers a return."):
			await _invite_keeper(dialog)
			_expect(state.neighbor_departures[KEEPER].day == 0 and state.neighbor_departures[KEEPER].returned_day == 51,
				"Only the return date is recorded for the legacy visit.")
			print("RETAINER_RETURN_OLD_SAVE day=", state.current_day, " returned=", KEEPER)
	else:
		await _play_keeper_return()
		await _play_reform_return()
	_end()
