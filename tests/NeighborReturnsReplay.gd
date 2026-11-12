extends RefCounted

var tree: SceneTree
var state: Node
var world: Node
var ui: Node
var failed := false

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failed = true
		push_error(message)
	return condition

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")

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
	await tree.process_frame

func _talk(speaker: String) -> Control:
	var actor: Node2D = world.neighbor_actor(speaker)
	if not _expect(actor != null, "The estate must contain " + speaker):
		return null
	actor.interact()
	await tree.process_frame
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	_expect(dialog != null and dialog.name_label.text == speaker and world.player.conversation_open,
		"The actor opens its own normal conversation.")
	return dialog

func _journal(speaker: String) -> Control:
	ui.hud.neighbors_button.pressed.emit()
	await tree.process_frame
	var management: Control = ui.panel_manager.management_panel_instance
	var journal: Control = management.neighbor_journal
	journal.roster.get_node(speaker).pressed.emit()
	await tree.process_frame
	_expect(journal.is_visible_in_tree() and journal.selected == speaker, "Read the selected neighbor's journal page.")
	return journal

func _close_journal() -> void:
	ui.panel_manager.management_panel_instance.get_node("CloseButton").pressed.emit()
	await tree.process_frame

func _night() -> void:
	ui.sleep_button.pressed.emit()
	await tree.create_timer(1.1).timeout

func _reload_at(day: int) -> bool:
	state.current_day = day
	if not _expect(state.save_game() == OK and state.load_game() == OK, "The neighbor fixture must save and continue."):
		return false
	await tree.scene_changed
	_estate()
	return true

func _check_returns() -> bool:
	await _night()
	await _choose(await _talk("季青"), "交谈")
	await _night()
	await _choose(await _talk("石墨"), "交谈")
	var journal := await _journal("季青")
	var promised: int = state.next_visitor_day("季青")
	_expect(promised == 7 and "第 7 天" in journal.where.text and "南路亭" in journal.where.text
		and not journal.locate_button.visible, "A known absent neighbor has an actual upcoming visit, and no map marker.")
	await _close_journal()
	while state.current_day < promised:
		await _night()
		var visitor: VisitorData = world.current_visitor()
		if visitor:
			await _choose(await _talk(visitor.name), "交谈")
	if not _expect(world.current_visitor().name == "季青", "Sleeping to the promised date brings the promised guest."):
		return false
	await _choose(await _talk("季青"), "招募")
	_expect(world.current_visitor() == null and state.next_visitor_day("季青") == 0,
		"Recruitment removes the resident from future visitor slots.")
	journal = await _journal("季青")
	_expect("留任门客" in journal.where.text and journal.locate_button.visible, "The recruited guest is located at his resident post.")
	await _close_journal()
	print("NEIGHBOR_PROMISE speaker=季青 forecast=", promised, " arrived=", state.current_day)

	state.tech_unlocked["irrigation"] = true
	state.first_channel_growth_day = 9
	if not await _reload_at(9):
		return false
	_expect(world.current_visitor().name == "石墨", "The first irrigated night takes priority over the normal visitor.")
	await _choose(await _talk("石墨"), "随石墨勘渠")
	if not await _reload_at(9):
		return false
	_expect(state.channel_survey_day == 9 and world.current_visitor().name == "石墨",
		"Finishing the water review keeps the same visitor after a same-day save and continue.")
	print("NEIGHBOR_RELOAD water=", world.current_visitor().name, " day=", state.current_day)

	state.last_defense = {"day": 9, "kind": 0, "losses": 0, "guard": ""}
	state.raids_defeated = 1
	if not await _reload_at(10):
		return false
	_expect(world.current_visitor().name == "弋戎", "A known defender arrives after the defense, including a normal rest day.")
	await _choose(await _talk("弋戎"), "复盘守备")
	if not await _reload_at(10):
		return false
	_expect(state.east_watch_day == 10 and world.current_visitor().name == "弋戎",
		"Finishing the defense review keeps the guest after a same-day save and continue.")
	print("NEIGHBOR_RELOAD defense=", world.current_visitor().name, " day=", state.current_day)

	state.ravine_journal.recorded_days.assign([4, 5, 6])
	state.channel_survey_day = 0
	state.first_channel_growth_day = 11
	if not await _reload_at(11):
		return false
	_expect(world.current_visitor().name == "蒲宁" and state.next_visitor_day("陶辛") == 0,
		"The unfinished ravine handoff takes priority without promising a displaced visit.")
	journal = await _journal("陶辛")
	_expect("交接后" in journal.where.text and "蒲宁" in journal.where.text,
		"The journal explains what currently delays the other visits.")
	await _close_journal()
	await _choose(await _talk("蒲宁"), "交溪行手记")
	if not await _reload_at(11):
		return false
	_expect(world.current_visitor().name == "蒲宁" and state.next_visitor_day("石墨") == 12,
		"The guide stays on handoff day, and normal visits resume the next morning.")
	await _night()
	_expect(world.current_visitor().name == "石墨", "The rescheduled water visitor actually arrives after handoff.")
	print("NEIGHBOR_RESUME handoff=11 next=", state.current_day, " speaker=", world.current_visitor().name)
	return not failed

func _complete_stories() -> void:
	# Restore a late second-year estate to inspect all post-story conversations.
	state.current_day = 25
	state.money = 1000
	state.king_storage = 10
	state.road_provisions_delivered = true
	state.road_provisions_day = 7
	state.road_rest_paid_day = 8
	state.road_rest_used_day = 0
	state.silk_sample_day = 9
	state.silk_bolts_sold = 1
	state.silk_workshop.built = true
	state.channel_survey_day = 11
	state.ravine_journal.garden_day = 11
	state.ravine_journal.garden_harvest_day = 0
	state.east_watch_day = 10
	for cell in [Vector2i(2, 5), Vector2i(3, 5)]:
		_expect(state.build_channel(cell) == state.ChannelSite.AVAILABLE, "Supply an actual well field for the water dialogue.")
	_expect(state.irrigated_well_fields() == 1, "The restored estate has one supplied field.")

func _set_resident(persona: Dictionary) -> void:
	state.retainers.clear()
	state.retainers.append(RetainerData.new(VisitorData.FIELD_KEEPER, "农夫", RetainerData.School.MOHIST))
	var school := RetainerData.School.NONE
	match persona.school:
		VisitorData.School.CONFUCIAN: school = RetainerData.School.CONFUCIAN
		VisitorData.School.MOHIST: school = RetainerData.School.MOHIST
		VisitorData.School.MILITARY: school = RetainerData.School.MILITARY
	state.retainers.append(RetainerData.new(persona.name, "门客", school))

func _check_seasons() -> bool:
	var seen := {}
	for persona in VisitorData.PERSONAS:
		seen[persona.name] = []
	var conversations := 0
	for day in [26, 27, 30, 32, 33, 38, 39, 44, 45]:
		for persona in VisitorData.PERSONAS:
			_set_resident(persona)
			if not await _reload_at(day):
				return false
			var resources := Vector3i(state.money, state.player_inventory, state.reputation)
			var dialog := await _talk(persona.name)
			if dialog == null:
				return false
			var speech: String = dialog.text_label.text
			_expect(not speech.is_empty() and speech not in seen[persona.name],
				"Completed stories have different conversations across each season and rain.")
			_expect(dialog.text_label.get_content_height() > 0
				and dialog.text_label.get_content_height() <= dialog.text_label.size.y,
				"The post-story speech fits in the existing dialogue text area.")
			seen[persona.name].append(speech)
			await _choose(dialog, "离开")
			_expect(resources == Vector3i(state.money, state.player_inventory, state.reputation),
				"Reading a familiar neighbor's news leaves trade and daily talk rewards unchanged.")
			conversations += 1
	print("NEIGHBOR_CONVERSATIONS count=", conversations, " speakers=", seen.size(), " seasonal=40 rain=5")
	return not failed

func _check_old_save() -> bool:
	var before := await _talk("弋戎")
	var speech: String = before.text_label.text
	await _choose(before, "离开")
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.manual_save_path()))
	record.erase("neighbor_met_days")
	record.erase("visitor_talk_days")
	var file := FileAccess.open(state.manual_save_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(record))
	file.close()
	if not _expect(state.load_game() == OK, "Continue an old-format neighbor record."):
		return false
	await tree.scene_changed
	_estate()
	var after := await _talk("弋戎")
	_expect(after.text_label.text == speech, "The same saved day preserves its conversation without new save fields.")
	await _choose(after, "离开")
	var journal := await _journal("陶辛")
	_expect("旧日相识" in journal.first_meeting.text and "下一次轮访" in journal.where.text,
		"An old completed favor still reveals the familiar neighbor and his next visit.")
	await _close_journal()
	return not failed

func _check_current_work() -> void:
	_set_resident(VisitorData.RAVINE_PERSONA)
	state.ravine_journal.garden_harvest_day = 30
	if not await _reload_at(30):
		return
	var dialog := await _talk("蒲宁")
	_expect("还要 3 夜" in dialog.text_label.text, "The garden conversation uses its actual remaining growth nights.")
	await _choose(dialog, "离开")
	_set_resident(VisitorData.WATER_PERSONA)
	for cell: Vector2i in state.irrigation.channels.keys():
		state.fill_channel(cell)
	if not await _reload_at(30):
		return
	dialog = await _talk("石墨")
	_expect("田里却干着" in dialog.text_label.text, "A broken water supply keeps its practical repair advice.")
	await _choose(dialog, "离开")
	_set_resident(VisitorData.EAST_PERSONA)
	state.raid_day = 30
	state.raid_kind = 0
	state.raid_health = 1
	if not await _reload_at(30):
		return
	dialog = await _talk("弋戎")
	_expect("东路还有" in dialog.text_label.text, "An active raid takes precedence over quiet seasonal news.")
	await _choose(dialog, "离开")

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the neighbor return replay's saves."):
		tree.quit(1)
		return
	tree.root.size = Vector2i(1280, 720)
	state = tree.root.get_node("Global")
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	tree.current_scene.new_button.pressed.emit()
	await tree.scene_changed
	_estate()
	# Food and quiet roads isolate the appointment and dialogue checks.
	state.food_storage = 1000
	state.reputation = 1000
	state.balance.raid_first_day = 10000
	if await _check_returns():
		_complete_stories()
		if await _check_seasons() and await _check_old_save():
			await _check_current_work()
	tree.paused = false
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.create_timer(0.25).timeout
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
