extends "res://tests/PavilionVisitReplay.gd"

var controller: RefCounted

func _day_of_the_gift() -> bool:
	await _tend_for_story()
	if not _expect(state.current_day == 7 and state.king_storage >= 1 and state.player_inventory >= 1,
			"Reach day seven with the first tribute and a crop for Ji Qing through ordinary field work."):
		return false
	await _meet(world.current_visitor_actor(), Vector2(0, -15))
	return await _choose_dialogue("送路粮")

func _record_previous_release() -> void:
	await _button(ui.hud.rations_button)
	var panel := ui.get_node_or_null("Control/NightRationsPanel") as Control
	_expect(panel != null and not panel.pavilion_story.visible and not world.pavilion_rest.visible,
		"The previous release gives no daytime invitation or way to wait at the table.")
	if panel:
		await _capture("00-before-daytime-plan")
		await _button(panel.close_button)
	await _save()
	_expect(FileAccess.file_exists(state.manual_save_path()), "Write the ordinary day-seven checkpoint through Settings.")
	print("PAVILION_APPOINTMENT_BEFORE day=", state.current_day, " watch=", state.day_watch_label(),
		" progress=", state.day_progress, " food=", state.food_storage, " stamina=", state.current_stamina)

func _press(control: Button) -> void:
	if controller:
		await controller._click(control)
	else:
		await _button(control)

func _interact_at_table() -> void:
	if controller:
		await controller._tap(JOY_BUTTON_X)
	else:
		await _key(KEY_E)

func _choose_dialogue(label: String) -> bool:
	if not controller:
		return await super._choose_dialogue(label)
	var dialogue := ui.get_node_or_null("Control/DialoguePanel") as Control
	if dialogue:
		for choice: Button in dialogue.choices:
			if choice.text.begins_with(label) and not choice.disabled:
				await _press(choice)
				return true
	return _expect(false, "A controller can select " + label)

func _guide_before_the_watch(id: String, watch: String) -> bool:
	var table: PavilionRest = world.pavilion_rest
	var story: Dictionary = PavilionStories.STORIES[id]
	var time: float = state.day_progress
	if not _expect(table.get("appointment_id") == id and world.pavilion_story_id().is_empty(),
			"An upcoming pair appears before either speaker is required to have arrived."):
		return false
	await _press(ui.hud.rations_button)
	var panel := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(panel != null and panel.pavilion_story.is_visible_in_tree() and story.title in panel.pavilion_title.text
			and watch in panel.pavilion_people.text and table.gathering_name() in panel.pavilion_people.text
			and not "已入席" in panel.pavilion_people.text and panel.find_pavilion.text == "指路去候席",
			"The sheet lists the topic, two names, the watch and the right place before arrival."):
		return false
	for speaker: String in story.speakers:
		_expect(speaker in panel.pavilion_people.text, "Name the scheduled neighbor " + speaker)
	_expect(panel.scroll.get_global_rect().encloses(panel.find_pavilion.get_global_rect()), "Keep the directions control in view.")
	await _capture("01-tonight-before-arrival")
	await _press(panel.find_pavilion)
	if not _expect(ui.directions.tracked_place == "亭边候席" and ui.directions.tracked_place_point == table.gathering_approach()
			and state.day_progress < time + 0.02 and world.pavilion_story_id().is_empty(),
			"Directions go to the real approach without changing the current watch or marking the talk heard."):
		return false
	await _capture("02-directions")
	var approach := world.to_global(table.gathering_approach())
	await Campaign.walk_estate_road_to(tree, world, approach)
	return _expect(table.can_interact_from(world.player.global_position), "Walk to the marked waiting place.")

func _take_a_seat() -> bool:
	await _interact_at_table()
	if not await _choose_dialogue("坐下候席"):
		return false
	return _expect(ui.freight_wait.visible and world.player.seated and world.player.resting,
		"Sitting down opens the wait controls and holds the player at the seat.")

func _wait_and_listen(id: String, check_cancel: bool) -> void:
	var table: PavilionRest = world.pavilion_rest
	var watch := "申时" if table.is_rain_shelter() else "酉时"
	if not await _guide_before_the_watch(id, watch):
		return
	var day: int = state.current_day
	var stamina: int = state.current_stamina
	var food: int = state.food_storage
	var before: float = state.day_progress
	if not await _take_a_seat():
		return
	await _capture("03-seated-wait")
	if check_cancel:
		await tree.create_timer(0.34).timeout
		if controller:
			await controller._tap(JOY_BUTTON_B)
		else:
			await _key(KEY_ESCAPE)
		_expect(not ui.freight_wait.visible and not world.player.resting and not world.player.seated
			and state.day_progress > before and state.day_progress < PavilionRest.rest_start() and state.current_day == day,
			"Cancel early, release the player and keep only the elapsed portion of the day.")
		await _capture("04-stood-up-early")
		if not await _take_a_seat():
			return
	var waiting_frames := 0
	for frame in 1150:
		if not ui.freight_wait.visible:
			break
		await tree.physics_frame
		waiting_frames += 1
	var wait_seconds := float(waiting_frames) / Engine.physics_ticks_per_second
	if not _expect(not ui.freight_wait.visible and not world.player.resting and not world.player.seated
			and world.pavilion_story_id() == id and state.current_day == day and state.day_progress >= PavilionRest.rest_start()
			and state.current_stamina == stamina and state.food_storage == food and state.pavilion_stories_heard.is_empty(),
			"Stop when both actors really sit. Keep today's food, stamina, and unread status."):
		return
	for speaker: String in PavilionStories.speakers(id):
		var actor: Node2D = world.neighbor_actor(speaker)
		_expect(actor != null and actor.resting_at_pavilion(), "The actor has physically reached the table: " + speaker)
	await _capture("05-both-seated")
	await _interact_at_table()
	if await _choose_dialogue("坐下听"):
		await _hear_story_lines(id, "06-listening")
	print("PAVILION_APPOINTMENT id=", id, " day=", state.current_day, " watch=", watch, " place=", table.gathering_name(),
		" start=", before, " end=", state.day_progress, " waiting_seconds=", wait_seconds,
		" food=", food, " stamina=", stamina, " controller=", controller != null)

func _alternate_appointment(variant: String) -> void:
	var rain := variant == "pavilion-appointment-rain"
	var resident := VisitorData.EAST_WATCHER if rain else VisitorData.ROAD_KEEPER
	var data := {
		"current_day": 30 if rain else 9,
		"day_progress": 0.31 if rain else 0.44,
		"king_storage": 12, "food_storage": 12,
		"retainers": [{"name": resident, "school": RetainerData.School.MILITARY if rain else RetainerData.School.CONFUCIAN}],
	}
	data["east_watch_day" if rain else "silk_sample_day"] = 7
	if rain:
		data["last_defense"] = {"day": 6, "kind": 0, "losses": 0, "guard": ""}
		data.retainers[0]["duty"] = RetainerData.Duty.GUARD
		if not await _load_fixture(data):
			return
		_expect(world.pavilion_rest.get("appointment_id") == "" and not world.pavilion_rest.visible,
			"The sheet does not promise the eastern guard's company while he is on watch.")
		data.retainers[0]["duty"] = RetainerData.Duty.FIELD
	if not await _load_fixture(data):
		return
	if rain:
		_expect(world.pavilion_rest.is_rain_shelter(), "Use the wet-day seat and schedule.")
	else:
		_expect(world.neighbor_actor(VisitorData.SILK_MERCHANT) == null, "Forecast the merchant's return while he is off the estate.")
	await _wait_and_listen("watch_lantern" if rain else "market_cloth", false)

func run_appointment(host: SceneTree, frames: String, variant: String) -> void:
	tree = host
	state = tree.root.get_node("Global")
	capture_dir = frames
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the pavilion appointment profile."):
		tree.quit(1)
		return
	seed(425)
	tree.root.notify_mouse_entered()
	var continuing: bool = not state.latest_saved_game().is_empty()
	if await _title(continuing):
		if variant in ["pavilion-appointment-rain", "pavilion-appointment-market"]:
			await _alternate_appointment(variant)
		elif continuing or await _day_of_the_gift():
			if variant == "pavilion-appointment-before":
				await _record_previous_release()
			else:
				if variant == "pavilion-appointment-pad":
					controller = load("res://tests/GamepadReplay.gd").new()
					controller.tree = tree
					controller.pad = GamepadInput
				var original_hash := FileAccess.get_sha256(state.manual_save_path()) if continuing else ""
				await _wait_and_listen("road_grain", true)
				if continuing:
					var retained_hash := FileAccess.get_sha256(state.manual_save_path())
					_expect(not original_hash.is_empty() and original_hash == retained_hash, "Waiting and listening leave the source manual save readable until the player saves again.")
					print("PAVILION_APPOINTMENT_OLD_SAVE prior=", original_hash, " after_wait=", retained_hash)
				if controller:
					_expect(controller.failures == 0, "The controller found every waiting control.")
				await _save()
				if await _title(true):
					_expect(state.pavilion_stories_heard.get("road_grain", 0) == 7
						and world.pavilion_rest.get("appointment_id") == "", "The old profile records the new talk and offers it only once.")
					await _capture("07-remembered")
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
