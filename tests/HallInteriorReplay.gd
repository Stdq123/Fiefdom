extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const PUBLIC := Vector2i(5, 5)
const PRIVATE := Vector2i(6, 5)

var tree: SceneTree
var state: Node
var world: Node2D
var ui: CanvasLayer
var room: Node2D
var hall: Node2D
var player: Player
var failures := 0
var captures := ""

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failures += 1
		push_error(detail)
	return condition

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)
	await tree.process_frame
	await tree.process_frame

func _click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = at
		event.global_position = at
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame

func _press(button: Button) -> void:
	await _click(button.get_global_rect().get_center())

func _crop_click(cell: Vector2i) -> void:
	var tiles: TileMapLayer = world.tile_map
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))

func _snapshot(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless":
		return
	await tree.create_timer(0.24).timeout
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(captures.path_join(name + ".png")) == OK, "Capture " + name)
	print("HALL_FRAME ", name, " window=", tree.root.size, " image=", frame.get_size())

func _estate() -> bool:
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE, "Continue in the real estate."):
		return false
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	player = world.player
	room = world.get_node("HallInterior")
	hall = world.get_node("HallRest")
	await tree.process_frame
	await tree.physics_frame
	return true

func _walk_in_room(to: Vector2) -> void:
	await Campaign.walk_to(tree, player, room.to_global(to))

func _cross_door(action: StringName, inside: bool) -> bool:
	var travel := tree.root.get_node("MapTravel")
	var estate := tree.current_scene
	var daylight: float = state.day_progress
	Input.action_press(action)
	for step in 35:
		await tree.physics_frame
		if travel.active:
			break
	Input.action_release(action)
	if not _expect(travel.active, "The doorway starts a fade while walking %s at %s." % [action, player.global_position]):
		return false
	await travel.finished
	await tree.physics_frame
	await tree.process_frame
	await tree.process_frame
	return _expect((state.estate_room == state.EstateRoom.HALL) == inside and room.visible == inside and tree.current_scene == estate
		and not tree.paused and tree.current_scene.process_mode == Node.PROCESS_MODE_INHERIT
		and absf(state.day_progress - daylight) < 0.02, "The doorway preserves the estate, clock and live input.")

func _enter() -> bool:
	await Campaign.walk_to(tree, player, hall.get_node("Yard").global_position)
	if not await _cross_door(&"ui_up", true):
		return false
	return _expect(room.room_camera.is_current() and player.global_position.distance_to(room.get_node("Entry").global_position) < 3.0
		and ui.hud.get_node("RoomLocation").visible and not ui.hud.get_node("SeedBelt").visible,
		"The entry brings up the room camera and clears field controls.")

func _leave() -> bool:
	await _walk_in_room(Vector2(0, 40))
	if not await _cross_door(&"ui_down", false):
		return false
	return _expect(player.camera.is_current() and player.global_position.distance_to(hall.get_node("Yard").global_position) < 3.0
		and ui.hud.get_node("SeedBelt").visible, "The exit returns to the path and restores field controls.")

func _read_desk() -> bool:
	await _walk_in_room(Vector2(0, -50))
	var floor_position := room.to_local(player.global_position)
	var terrain := world.get_node("Landscape").terrain_audio as Node
	_expect(floor_position.y > -23.0 and floor_position.y < -19.0
		and terrain.footsteps.stream.resource_path.get_file().begins_with("plank-"),
		"The back wall is solid and indoor movement sounds like wood.")
	await _walk_in_room(Vector2(0, 16))
	await _walk_in_room(Vector2(-54, 12))
	var before: int = state.player_stats.get_stat(PlayerStats.Art.LITERACY).xp
	var reward: int = state.balance.literacy_study_xp
	if not _expect(player.interaction_target == room.get_node("StudyDesk"), "The desk is reached on foot."):
		return false
	await _key(KEY_E)
	_expect(state.player_stats.get_stat(PlayerStats.Art.LITERACY).xp == before + reward
		and ui.hud.practice_label.text.contains("+%d" % reward), "Reading at the desk grants the existing literacy reward.")
	await _snapshot("03-desk-study")
	await _key(KEY_E)
	_expect(state.player_stats.get_stat(PlayerStats.Art.LITERACY).xp == before + reward,
		"Reading twice in the room respects the daily limit.")
	await _press(ui.manage_button)
	var management: Control = ui.panel_manager.management_panel_instance
	if not _expect(is_instance_valid(management) and management.visible, "The management panel remains accessible indoors."):
		return false
	_expect(management.read_button.disabled, "The study action in management uses the same daily allowance.")
	await _press(management.get_node("CloseButton"))
	print("HALL_STUDY day=", state.current_day, " xp=", before, "->", before + reward, " shared=true")
	return true

func _save_and_restore() -> bool:
	await _press(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	var saved := false
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _press(button)
			saved = settings.save_status.text == "游戏已保存"
			break
	if not _expect(saved, "Save using the real settings panel from inside the room."):
		return false
	if not _expect(state.load_game() == OK, "The indoor manual save reloads."):
		return false
	if not await _estate():
		return false
	return _expect(state.estate_room == state.EstateRoom.HALL and room.room_camera.is_current()
		and player.global_position.is_equal_approx(room.get_node("Wake").global_position)
		and not state.can_practice_today(PlayerStats.Art.LITERACY)
		and state.active_crops[PUBLIC].watered and not state.active_crops[PRIVATE].watered,
		"The manual save retains the room, practice and both plots.")

func _bed_plan() -> Control:
	await _walk_in_room(Vector2(55, 35))
	if not _expect(player.interaction_target == room.get_node("Bed"), "Reach the bed's foot on the floor."):
		return null
	await _key(KEY_E)
	var plan := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if not _expect(plan != null and plan.visible and player.conversation_open, "E at the bed opens the normal night plan."):
		return null
	return plan

func _dry_plot_and_sleep() -> bool:
	var plan := await _bed_plan()
	if plan == null:
		return false
	_expect(plan.find_plot.visible, "The night plan sees the dry private plot outside.")
	await _press(plan.find_plot)
	_expect(ui.directions.tracked_plot == PRIVATE and not ui.directions.visible
		and ui.hud.practice_label.text.contains("南门"), "Field guidance waits until the player leaves the room.")
	if not await _leave():
		return false
	_expect(ui.directions.visible and ui.hud.practice_label.text.is_empty(),
		"The dry plot guidance resumes at the hall entrance and replaces the indoor notice.")
	await Campaign.walk_to(tree, player, world.to_global(Vector2(66, 98)))
	await _crop_click(PRIVATE)
	_expect(state.active_crops[PRIVATE].watered, "The private plot can be watered on return.")
	state.assign_duty(state.retainers.front(), RetainerData.Duty.FIELD)
	if not await _enter():
		return false
	plan = await _bed_plan()
	if plan == null:
		return false
	await _snapshot("04-bed-plan")
	var grain: int = state.food_storage
	var needed: int = state.night_rations_plan().need
	await _press(plan.get_node("%Sleep"))
	await tree.create_timer(1.24).timeout
	var growth: bool = state.active_crops[PUBLIC].age == 1 and state.active_crops[PRIVATE].age == 1
	_expect(state.current_day == 2 and state.estate_room == state.EstateRoom.HALL and room.room_camera.is_current() and growth
		and state.food_storage == grain - needed and not state.active_crops[PUBLIC].watered
		and not state.active_crops[PRIVATE].watered and state.can_practice_today(PlayerStats.Art.LITERACY),
		"Indoor sleep grows both watered plots, settles one meal and opens a new study day.")
	var record: Dictionary = state.latest_saved_game()
	_expect(record.get("day") == 2 and record.get("watch") == "卯时", "Indoor sleep makes a new dawn checkpoint.")
	print("HALL_DAWN day=", state.current_day, " public=", state.active_crops[PUBLIC].age,
		" private=", state.active_crops[PRIVATE].age, " grain=", grain, "->", state.food_storage)
	return true

func _resume_dawn() -> bool:
	if not _expect(tree.change_scene_to_file(state.TITLE_SCENE) == OK, "Return to title for normal continuation."):
		return false
	await tree.scene_changed
	await tree.process_frame
	await _press(tree.current_scene.continue_button)
	if not await _estate():
		return false
	_expect(state.current_day == 2 and state.estate_room == state.EstateRoom.HALL and room.room_camera.is_current()
		and player.global_position.is_equal_approx(room.get_node("Wake").global_position)
		and state.day_watch_label() == "卯时" and state.active_crops[PRIVATE].age == 1,
		"Title Continue wakes beside the bed with the dawn crop state.")
	await _snapshot("05-morning-inside")
	world.retainer_instances[state.retainers.front()].set_physics_process(false)
	if not await _mark_public_plot_from_bed():
		return false
	if not await _leave():
		return false
	_expect(player.camera.zoom.is_equal_approx(Vector2(3, 3)) and ui.directions.visible
		and ui.directions.tracked_plot == PUBLIC and ui.hud.practice_label.text.is_empty(),
		"Leaving restores the preferred zoom and shows the marked public field.")
	print("HALL_RESTORE day=", state.current_day, " exterior=", player.global_position, " zoom=", player.camera.zoom)
	return true

func _mark_public_plot_from_bed() -> bool:
	var plan := await _bed_plan()
	if plan == null:
		return false
	var grain: int = state.food_storage
	await _press(plan.get_node("%Sleep"))
	await tree.process_frame
	var warning := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(not is_instance_valid(plan) and warning != null and "公田待浇" in warning.text_label.text
		and player.conversation_open, "Sleeping from the bed replaces the night plan with the first-tribute warning."):
		return false
	await _snapshot("05a-bedtime-warning")
	await _press(warning.choices.front())
	return _expect(not player.conversation_open and state.current_day == 2 and state.food_storage == grain
		and ui.directions.tracked_plot == PUBLIC and not ui.directions.visible
		and "从南门回田边" in ui.hud.practice_label.text, "Marking the public plot stays in the room and points out the exit.")

func _harvest() -> void:
	await Campaign.walk_to(tree, player, world.to_global(Vector2(66, 98)))
	for cell in [PUBLIC, PRIVATE]:
		if world.is_crop_dry(cell):
			await _crop_click(cell)
	await _press(ui.sleep_button)
	await tree.create_timer(1.24).timeout
	await Campaign.walk_to(tree, player, world.to_global(Vector2(66, 98)))
	var public_before: int = state.king_storage
	var private_before: int = state.player_inventory
	await _crop_click(PUBLIC)
	await _crop_click(PRIVATE)
	_expect(state.king_storage > public_before and state.player_inventory > private_before
		and not state.active_crops.has(PUBLIC) and not state.active_crops.has(PRIVATE),
		"The harvest goes to the proper public and private stores after the indoor night.")
	print("HALL_HARVEST public=", public_before, "->", state.king_storage,
		" private=", private_before, "->", state.player_inventory)

func _rain() -> void:
	while not state.has_rain() and state.current_day < 10:
		await _press(ui.sleep_button)
		await tree.create_timer(1.18).timeout
	if not _expect(state.has_rain(), "The default calendar reaches a rainy day."):
		return
	var landscape := world.get_node("Landscape")
	var weather := landscape.get_node("Rain") as Node2D
	var rain := landscape.terrain_audio.rain as AudioStreamPlayer
	if not await _enter():
		return
	await tree.create_timer(0.38).timeout
	_expect(not weather.visible and is_equal_approx(rain.volume_linear, 0.12), "Rain is sheltered indoors.")
	await _snapshot("06-room-in-rain")
	if not await _leave():
		return
	await tree.create_timer(0.38).timeout
	_expect(weather.visible and is_equal_approx(rain.volume_linear, 0.39), "Leaving restores the outdoor rain.")
	await _snapshot("07-yard-in-rain")
	print("HALL_RAIN day=", state.current_day, " term=", state.get_current_solar_term(), " outdoors=", rain.volume_linear)

func _play() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _press(tree.current_scene.new_button)
	if not await _estate():
		return
	_expect(state.estate_room == state.EstateRoom.OUTDOORS and not room.visible and player.camera.is_current(), "A new game begins in the estate.")
	# Let the private plot stay dry until the night plan guides the player back to it.
	state.assign_duty(state.retainers.front(), RetainerData.Duty.HARVEST)
	for step in 3:
		await _crop_click(PUBLIC)
	for step in 2:
		await _crop_click(PRIVATE)
	if not _expect(state.active_crops.has(PUBLIC) and state.active_crops.has(PRIVATE), "Plant the two fields with real clicks."):
		return
	state.advance_daylight(state.balance.daylight_seconds * 0.83)
	await Campaign.walk_to(tree, player, hall.global_position + Vector2(-33, -36))
	_expect(player.global_position.y > 33.0 and state.estate_room == state.EstateRoom.OUTDOORS,
		"The wall beside the entrance stops the player.")
	await Campaign.walk_to(tree, player, hall.get_node("Yard").global_position)
	await _snapshot("01-outdoor-door")
	if not await _enter():
		return
	var prefs := tree.root.get_node("Preferences")
	await _key(KEY_2)
	await _click(Vector2(660, 356), MOUSE_BUTTON_RIGHT)
	_expect(state.selected_seed_id == "millet" and not world.has_node("Arrow"),
		"Indoor input keeps the selected seed and never fires an arrow.")
	await _key(KEY_M)
	_expect(ui.estate_map.modal.visible and ui.estate_map._player_point().is_equal_approx(hall.get_node("Yard").position + hall.position),
		"The estate chart places the player at the hall.")
	await _key(KEY_M)
	await _snapshot("02-room-at-dusk")
	if not await _read_desk() or not await _save_and_restore():
		return
	prefs.map_zoom = 3.0
	player._apply_camera_zoom()
	if await _dry_plot_and_sleep() and await _resume_dawn():
		await _harvest()
		await _rain()

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated indoor replay profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	captures = OS.get_environment("FIEFDOM_HALL_CAPTURES")
	tree.root.notify_mouse_entered()
	seed(1109)
	await _play()
	tree.paused = false
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(0 if failures == 0 else 1)
