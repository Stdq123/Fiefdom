extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const TITLE := "res://scenes/Title.tscn"
const PUBLIC := Vector2i(5, 5)

var tree: SceneTree
var state: Node
var ui: Node
var world: Node
var captures := ""
var failed := false

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failed = true
		push_error(detail)
	return condition

func _button(parent: Node, prefix: String) -> Button:
	for button: Button in parent.find_children("*", "Button", true, false):
		if button.text.begins_with(prefix):
			return button
	return null

func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	tree.root.push_input(move, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame
	await tree.process_frame

func _press(button: Button) -> void:
	if _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "The requested button is usable."):
		await _click(button.get_global_rect().get_center())

func _open_title() -> void:
	tree.paused = false
	tree.change_scene_to_file(TITLE)
	await tree.scene_changed
	await tree.process_frame

func _estate() -> void:
	if tree.current_scene == null:
		await tree.scene_changed
	ui = tree.current_scene.get_node("UI")
	world = tree.current_scene.get_node("World")
	await tree.process_frame
	await tree.process_frame

func _new_game(estate_name := "") -> void:
	var title := tree.current_scene
	await _press(title.new_button)
	if tree.current_scene == title and title.new_confirmation.visible:
		if not estate_name.is_empty():
			title.new_name.text = estate_name
			var hint: Label = title.new_confirmation.get_node("Form/SaveHint")
			_expect(not hint.get_global_rect().intersects(title.new_name.get_global_rect()),
				"The save hint and name input have separate rows.")
			await _capture("09-name-new-estate")
		title.new_name.text_submitted.emit(title.new_name.text)
	await _estate()

func _settings() -> Panel:
	await _press(ui.settings_button)
	return ui.panel_manager.settings_panel_instance

func _return_to_title() -> void:
	var panel := await _settings()
	await _press(_button(panel, "返回标题"))
	var confirmation := panel.get_node("TitleConfirmation") as ConfirmationDialog
	_expect(confirmation.visible, "Returning uses the normal confirmation.")
	confirmation.confirmed.emit()
	await tree.scene_changed
	await tree.process_frame

func _continue() -> void:
	await _press(tree.current_scene.continue_button)
	await _estate()

func _farm() -> void:
	var tiles: TileMapLayer = world.tile_map
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(PUBLIC))

func _night(warning_text := "") -> void:
	await _press(ui.sleep_button)
	if not warning_text.is_empty():
		var warning := ui.get_node_or_null("Control/DialoguePanel") as Control
		if not _expect(warning != null and warning_text in warning.text_label.text,
			"The first-tribute warning precedes an intentional missed harvest or watering."):
			return
		await _press(warning.choices.back())
	await tree.create_timer(1.12).timeout

func _capture(name: String) -> void:
	if captures.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(captures.path_join(name + ".png")) == OK, "Could not capture " + name)
	print("DAWN_FRAME ", name, " ", image.get_size())

func _fresh_morning() -> void:
	await _new_game()
	for action in 3:
		await _farm()
	await _night()
	var latest: Dictionary = state.latest_saved_game()
	_expect(state.current_day == 2 and latest.get("day") == 2 and latest.get("source") == "晨间自动存档"
		and not FileAccess.file_exists(state.manual_save_path()), "One normal sleep writes a dawn checkpoint without a manual save.")
	_expect(ui.hud.save_notice.visible and "已自动保存" in ui.hud.save_notice.text,
		"The calendar confirms the successful write.")
	await _capture("01-morning-saved")
	print("DAWN_WRITTEN day=", state.current_day, " crop_age=", state.active_crops[PUBLIC]["age"], " food=", state.food_storage)

func _resume_morning() -> void:
	var title := tree.current_scene
	_expect("晨间自动存档" in title.status.text and "第 2 天" in title.status.text, "The title describes the dawn save.")
	await _capture("02-continue-at-dawn")
	await _continue()
	_expect(state.current_day == 2 and state.food_storage == 9 and state.active_crops[PUBLIC]["age"] == 1
		and not state.active_crops[PUBLIC]["watered"] and state.night_rations.last["day"] == 1
		and not FileAccess.file_exists(state.manual_save_path()), "Loading dawn restores growth and food without applying the night twice.")
	print("DAWN_RESUMED day=", state.current_day, " crop_age=", state.active_crops[PUBLIC]["age"], " food=", state.food_storage)

func _history_and_fallback() -> void:
	var panel := await _settings()
	await _press(_button(panel, "保存游戏"))
	_expect(panel.save_status.text == "游戏已保存" and "已手动保存" in ui.hud.save_notice.text,
		"The manual slot still writes from Settings and reports success.")
	var manual_path: String = state.manual_save_path()
	var manual := FileAccess.get_file_as_string(manual_path)
	await _press(_button(panel, "关闭"))
	if world.field_action(PUBLIC) == world.FieldAction.WATER:
		await _farm()
	await _night()
	await _farm()
	await _night()
	await _night()
	var catalog: Array[Dictionary] = state.saved_games()
	var days: Array = catalog.map(func(entry: Dictionary) -> int: return entry["day"])
	_expect(days == [5, 4, 3, 2] and FileAccess.get_file_as_string(manual_path) == manual,
		"Automatic checkpoints rotate to three entries and preserve the manual file byte for byte.")
	print("DAWN_HISTORY days=", days)
	await _return_to_title()
	await _press(tree.current_scene.archive_button)
	var archive := tree.current_scene.get_node("SaveArchive")
	_expect(tree.paused and archive.records.get_child_count() == 4, "The archive presents three dawns and one manual save.")
	await _capture("03-save-history")
	await _press(archive.close_button)
	await _continue()

	var oldest: Dictionary = catalog[2]
	var pending := "%s.%d.tmp" % [oldest["path"], OS.get_process_id()]
	_expect(DirAccess.make_dir_absolute(pending) == OK, "Install the isolated write-failure fixture.")
	var existing := FileAccess.get_file_as_string(oldest["path"])
	await _night()
	_expect(state.current_day == 6 and "自动保存失败" in ui.hud.save_notice.text
		and FileAccess.get_file_as_string(oldest["path"]) == existing and state.saved_games() == catalog,
		"A failed replacement leaves all four saves and reports the failure.")
	_expect(DirAccess.remove_absolute(pending) == OK, "Remove the empty write-failure fixture.")
	await _capture("04-save-failed")

	var corrupt := FileAccess.open(catalog[0]["path"], FileAccess.WRITE)
	corrupt.store_string("{")
	corrupt.close()
	await _return_to_title()
	_expect("第 4 天" in tree.current_scene.status.text, "The title offers the newest readable file when the latest JSON is damaged.")
	await _continue()
	_expect(state.current_day == 4 and state.king_storage == 1 and "部分存档无法读取" in ui.hud.save_notice.text,
		"Continue reports the damaged save and restores the next morning.")
	await _capture("05-recovered-from-damaged-save")
	print("DAWN_FALLBACK day=", state.current_day, " tribute=", state.king_storage)
	panel = await _settings()
	await _press(_button(panel, "读取游戏"))
	archive = ui.get_node("Control/SaveArchive")
	var damaged := _button(archive.records, "晨间自动存档 · 无法读取")
	_expect(is_instance_valid(damaged) and damaged.disabled, "The archive marks an unreadable file.")
	await _press(_button(archive.records, "手动存档"))
	await _estate()
	_expect(state.current_day == 2 and state.king_storage == 0 and FileAccess.get_file_as_string(manual_path) == manual,
		"Choosing the manual entry returns to its original day and resources.")

func _preference_and_defeat() -> void:
	var panel := await _settings()
	var checkbox := panel.find_child("Autosave", true, false) as CheckButton
	await _press(checkbox)
	var file := ConfigFile.new()
	_expect(not checkbox.button_pressed and file.load("user://settings.cfg") == OK
		and file.get_value("game", "autosave", true) == false, "The autosave preference is stored from Settings.")
	await _capture("06-autosave-setting")
	await _press(_button(panel, "关闭"))
	var catalog: Array[Dictionary] = state.saved_games()
	await _night("待浇")
	_expect(state.current_day == 3 and state.saved_games() == catalog, "Turning autosave off still allows a normal night.")
	state.hurt_player(state.health)
	await tree.process_frame
	await tree.process_frame
	var hud := tree.current_scene.get_node("CampaignHUD")
	_expect(tree.paused and state.outcome == state.Outcome.DEFEAT_COMBAT and "第 2 天" in hud.status.text,
		"Defeat after loading an earlier slot offers that checkpoint, without jumping to the abandoned future.")
	await _capture("07-defeat-restore")
	await _press(hud.find_child("RestoreCampaign", true, false) as Button)
	await _estate()
	_expect(state.current_day == 2 and state.health == state.balance.player_max_health and state.saved_games() == catalog,
		"Combat recovery does not overwrite any existing save.")
	print("DAWN_RESTORED day=", state.current_day, " health=", state.health)
	panel = await _settings()
	await _press(panel.find_child("Autosave", true, false) as Button)
	await _press(_button(panel, "关闭"))
	state.days_without_contribution = state.balance.no_contribution_threshold - 1
	state.reputation = state.balance.rank_strip_threshold + state.balance.no_contribution_penalty
	await _night("声望")
	_expect(state.outcome == state.Outcome.DEFEAT_ESTATE and state.saved_games() == catalog,
		"The night that loses the estate never replaces the recovery points.")
	hud = tree.current_scene.get_node("CampaignHUD")
	await _press(hud.find_child("RestoreCampaign", true, false) as Button)
	await _estate()

func _council() -> void:
	# Stage the first mandatory research payment without replaying two years.
	state.current_day = 2 * state.balance.days_per_year
	state.current_rank = state.Rank.DA_FU
	state.king_storage = 20
	state.reputation = state.balance.grandee_rank_reputation
	state.balance.raid_first_day = 10000
	await _night()
	var panel := await Campaign.meet_tax_envoy(tree)
	if not _expect(panel != null, "Walk to the envoy to open the initial decision."):
		return
	await _press(_button(panel, "暂缓"))
	await _press(panel.confirm_button)
	var delayed: Dictionary = state.latest_saved_game()
	_expect(delayed.get("source") == "初税亩自动存档", "Choosing to research creates an immediate checkpoint.")
	state.current_day = state.tax_reform_day + state.research_payment_interval() - 1
	await _night()
	var due_day: int = state.current_day
	_expect(state.research_choice_pending and world.tax_envoy.visible and not tree.paused,
		"An unpaid research fee summons the envoy for a final decision.")
	await _return_to_title()
	await _continue()
	panel = await Campaign.meet_tax_envoy(tree)
	if not _expect(panel != null, "The unpaid appointment survives the dawn checkpoint."):
		return
	_expect(state.current_day == due_day and state.money == 0 and tree.paused
		and _button(panel, "暂缓") == null, "The checkpoint reopens the same mandatory choice without a duplicate fee.")
	await _press(_button(panel, "支持改革"))
	await _press(panel.confirm_button)
	var decided: Dictionary = state.latest_saved_game()
	_expect(state.tax_reform_choice == state.TaxReformChoice.REFORMED and not state.research_choice_pending
		and decided.get("source") == "初税亩自动存档" and decided.get("day") == due_day,
		"The confirmed reform writes its resolved state as the latest checkpoint.")
	await _capture("08-council-saved")
	await _return_to_title()
	await _continue()
	_expect(not tree.paused and not ui.has_node("Control/EventPanel")
		and not world.tax_envoy.visible and state.tax_reform_choice == state.TaxReformChoice.REFORMED,
		"Continuing after the decision keeps the selected route and dismisses the appointment.")
	print("DAWN_COUNCIL day=", due_day, " resolved=", state.tax_reform_choice)

func _new_campaign_isolation() -> void:
	var catalog: Array[Dictionary] = state.saved_games()
	var first: Dictionary = state.latest_saved_game()
	var first_name: String = state.campaign_name
	var old_files := {}
	for entry in catalog:
		old_files[entry.path] = FileAccess.get_file_as_bytes(entry.path)
	await _return_to_title()
	await _new_game("柳湾封地")
	_expect(state.current_day == 1 and state.saved_games() == catalog, "A new game preserves the old saves until a write.")
	for action in 3:
		await _farm()
	await _night()
	await _farm()
	await _night()
	await _farm()
	var panel := await _settings()
	await _press(_button(panel, "保存游戏"))
	_expect(panel.save_status.text == "游戏已保存", "Save the second estate through Settings.")
	await _press(_button(panel, "关闭"))
	await _night()
	await _night()
	var second: Dictionary = state.latest_saved_game()
	_expect(second.campaign != first.campaign and second.campaign_name == "柳湾封地" and second.day == 5
		and state.king_storage == 1, "The second estate writes its own dawns after its first tribute.")
	for path: String in old_files:
		_expect(FileAccess.get_file_as_bytes(path) == old_files[path], "Saving the second estate leaves each first-estate file intact.")
	_expect(state.saved_games().size() == catalog.size() + 4, "Each estate retains its own manual slot and three dawns.")
	print("ESTATE_SAVES first=", catalog.size(), " second=", state.saved_games().size() - catalog.size(),
		" latest=", second.campaign_name, " day=", second.day)

	await _return_to_title()
	_expect("柳湾封地" in tree.current_scene.status.text and "第 5 天" in tree.current_scene.status.text,
		"Continue identifies the latest estate by name and save date.")
	await _press(tree.current_scene.archive_button)
	var archive := tree.current_scene.get_node("SaveArchive")
	_expect(archive.estates.get_child_count() == 2 and archive.records.get_child_count() == 4
		and "柳湾封地" in archive.records_heading.text, "The archive selects the latest estate and shows its four files.")
	await _capture("10-second-estate")
	await _press(_button(archive.estates, first_name))
	_expect(first_name in archive.records_heading.text and archive.records.get_child_count() == catalog.size(),
		"Selecting the first estate reveals its original history.")
	await _capture("11-first-estate")
	await _press(archive.records.get_child(0))
	await _estate()
	_expect(state.campaign_id == first.campaign and state.current_day == first.day
		and state.tax_reform_choice == state.TaxReformChoice.REFORMED, "Load the first estate back into its established reform route.")
	panel = await _settings()
	await _press(_button(panel, "读取游戏"))
	archive = ui.get_node("Control/SaveArchive")
	_expect(first_name in archive.records_heading.text, "From Settings the archive opens on the current estate.")
	await _press(archive.close_button)
	await _press(_button(panel, "关闭"))

	await _return_to_title()
	await _new_game()
	state.hurt_player(state.health)
	await tree.process_frame
	await tree.process_frame
	var hud := tree.current_scene.get_node("CampaignHUD")
	_expect(hud.find_child("RestoreCampaign", true, false).disabled, "An unsaved new campaign cannot silently recover another campaign.")

func _resume_independent_estates() -> void:
	_expect("柳湾封地" in tree.current_scene.status.text, "A fresh process finds the second estate on disk.")
	await _continue()
	_expect(state.campaign_name == "柳湾封地" and state.current_day == 5 and state.king_storage == 1,
		"Continue in a fresh process restores the second estate's morning and tribute.")
	await _return_to_title()
	await _press(tree.current_scene.archive_button)
	var archive := tree.current_scene.get_node("SaveArchive")
	await _press(_button(archive.estates, "封地 1"))
	await _press(archive.records.get_child(0))
	await _estate()
	_expect(state.campaign_name == "封地 1" and state.current_day == 51
		and state.tax_reform_choice == state.TaxReformChoice.REFORMED,
		"The same fresh process restores the first estate and its selected route.")
	print("ESTATE_SAVES_RESTART first=", state.campaign_name, " day=", state.current_day)

func _finish() -> void:
	tree.paused = false
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	# The windowed mixer releases stream playbacks after its next mix.
	await tree.create_timer(0.25).timeout
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func run(game_tree: SceneTree, phase := "") -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the replay's saves."):
		await _finish()
		return
	captures = OS.get_environment("FIEFDOM_DAWN_CAPTURES")
	tree.root.notify_mouse_entered()
	state = tree.root.get_node("Global")
	await _open_title()
	match phase:
		"prepare":
			await _fresh_morning()
		"resume":
			await _resume_morning()
		"resume-campaigns":
			await _resume_independent_estates()
		_:
			await _fresh_morning()
			await _return_to_title()
			await _resume_morning()
			await _history_and_fallback()
			await _preference_and_defeat()
			await _council()
			await _new_campaign_isolation()
	await _finish()
