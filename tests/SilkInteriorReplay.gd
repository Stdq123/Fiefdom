extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const MILLET := [Vector2i(5, 5), Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 4), Vector2i(5, 6)]
const MULBERRY := [Vector2i(6, 5), Vector2i(6, 6)]

var tree: SceneTree
var state: Node
var world: Node2D
var ui: CanvasLayer
var player: Player
var shed: Node2D
var room: Node2D
var captures := ""
var failures := 0

func _expect(ok: bool, detail: String) -> bool:
	if not ok:
		failures += 1
		push_error(detail)
	return ok

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)
	await tree.process_frame
	await tree.process_frame

func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame

func _press(button: Button) -> void:
	await _click(button.get_global_rect().get_center())

func _snapshot(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless":
		return
	await tree.create_timer(0.22).timeout
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(captures.path_join(name + ".png")) == OK, "Capture " + name)
	print("SILK_FRAME ", name, " window=", tree.root.size, " image=", frame.get_size())

func _estate() -> bool:
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE, "Enter the estate through the real scene."):
		return false
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	player = world.player
	shed = world.get_node("SilkShed")
	room = world.get_node("SilkInterior")
	await tree.process_frame
	await tree.physics_frame
	return true

func _walk(at: Vector2) -> void:
	await Campaign.walk_to(tree, player, at)

func _step_through(action: StringName, room_kind: int) -> bool:
	var travel := tree.root.get_node("MapTravel")
	var scene := tree.current_scene
	Input.action_press(action)
	for frame in 35:
		await tree.physics_frame
		if travel.active:
			break
	Input.action_release(action)
	if not _expect(travel.active, "A physical doorway starts fading from %s." % player.global_position):
		return false
	await travel.finished
	await tree.process_frame
	await tree.process_frame
	return _expect(state.estate_room == room_kind and tree.current_scene == scene and not tree.paused,
		"The same estate stays alive across the doorway.")

func _enter_shed(take_photo := false) -> bool:
	await _walk(Vector2(45, 135))
	await _walk(shed.get_node("Yard").global_position)
	if take_photo:
		await _snapshot("01-workshop-door")
	if not await _step_through(&"ui_up", state.EstateRoom.SILK_SHED):
		return false
	return _expect(room.visible and room.room_camera.is_current() and not world.get_node("HallInterior").visible
		and ui.hud.get_node("WorkshopStatus").visible and ui.hud.get_node("RoomLocation").text == "蚕棚",
		"The workshop camera and real stock ledger appear.")

func _leave(interior: Node2D) -> bool:
	await _walk(interior.to_global(Vector2(0, 40)))
	if not await _step_through(&"ui_down", state.EstateRoom.OUTDOORS):
		return false
	return _expect(player.camera.is_current() and not ui.hud.get_node("WorkshopStatus").visible, "Outside controls return.")

func _station(name: String) -> bool:
	var station := room.get_node(name) as Node2D
	await _walk(room.to_global(Vector2(room.to_local(player.global_position).x, 20)))
	await _walk(station.global_position + Vector2(0, 20.0 - station.position.y))
	await tree.physics_frame
	if not _expect(player.interaction_target == station, "Reach and face the %s on foot." % name):
		return false
	await _key(KEY_E)
	return true

func _crop(cell: Vector2i) -> void:
	var tiles := world.tile_map as TileMapLayer
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))

func _tend(cells: Array, seed_key: Key) -> void:
	await _key(seed_key)
	for cell: Vector2i in cells:
		var crop: Dictionary = state.active_crops.get(cell, {})
		if not crop.is_empty() and crop.age >= crop.growth_nights:
			await _crop(cell)
		if not state.active_crops.has(cell):
			if not state.tilled_cells.has(cell):
				await _crop(cell)
			await _crop(cell)
		if world.is_crop_dry(cell):
			await _crop(cell)

func _management(tab: int) -> Control:
	await _press(ui.manage_button)
	var panel: Control = ui.panel_manager.management_panel_instance
	panel.tabs.current_tab = tab
	await tree.process_frame
	await tree.process_frame
	return panel

func _study() -> void:
	var panel := await _management(2)
	await _press(panel.read_button)
	await _press(panel.get_node("CloseButton"))

func _build_shed() -> bool:
	var panel := await _management(4)
	var silk: VBoxContainer = panel.tabs.get_node("蚕桑")
	var purse: int = state.money
	await _press(silk.buttons[SilkWorkshop.Action.BUILD])
	if not _expect(shed.visible and state.silk_workshop.built and state.money == purse - state.balance.silk_workshop_cost
		and silk.visit_button.visible, "Normal farming and study fund the physical workshop."):
		return false
	await _press(silk.visit_button)
	_expect(not panel.visible and ui.directions.tracked_place == "蚕棚", "The silk page points to the real entrance.")
	if not await _enter_shed(true):
		return false
	await _key(KEY_M)
	_expect(ui.estate_map.modal.visible and world.estate_player_point().is_equal_approx(world.to_local(shed.get_node("Yard").global_position)),
		"The estate map marks the shed while the player is inside.")
	await _key(KEY_M)
	if not await _station("SilkwormTray"):
		return false
	_expect(state.silk_workshop.nights_left == 0 and ui.hud.practice_label.text.contains("缺"),
		"An empty tray explains the need for mulberry leaves.")
	print("SILK_BUILT day=", state.current_day, " copper=", purse, "->", state.money)
	return await _leave(room)

func _merchant(deliver: bool) -> bool:
	var actor: Node2D = world.neighbor_actor(VisitorData.SILK_MERCHANT)
	if not _expect(is_instance_valid(actor), "Tao Xin visits the west court."):
		return false
	await _walk(Vector2(-84, 137))
	await _walk(Vector2(-84, 84))
	await _walk(actor.global_position + Vector2(0, 17))
	await _key(KEY_E)
	var dialogue: Control = ui.get_node_or_null("Control/DialoguePanel")
	if not _expect(dialogue != null and dialogue.name_label.text == "陶辛", "Talk to Tao Xin in person."):
		return false
	var before: int = state.money
	var option := "交样绸" if deliver else "交谈"
	for button: Button in dialogue.options_container.get_children():
		if button.text.begins_with(option) and not button.disabled:
			await _press(button)
			if deliver:
				_expect(state.silk_sample_day == state.current_day and state.silk_workshop.bolts == 0
					and state.silk_bolts_sold == 1 and state.money == before + state.silk_sample_price(),
					"Tao Xin takes the physically woven sample exactly once.")
				await _snapshot("05-sample-delivered")
				print("SILK_DELIVERED day=", state.current_day, " price=", state.money - before)
			return true
	return _expect(false, "The conversation offers %s." % option)

func _wear_sample_in_hall() -> void:
	await _walk(Vector2(-84, 41))
	await _walk(world.get_node("HallRest/Yard").global_position)
	if not await _step_through(&"ui_up", state.EstateRoom.HALL):
		return
	var hall := world.get_node("HallInterior") as Node2D
	await _walk(hall.to_global(Vector2(0, 33)))
	await _walk(hall.to_global(Vector2(-52, 33)))
	await _key(KEY_E)
	var panel := ui.get_node("Control/WardrobePanel") as Control
	if not _expect(panel.modal.visible and state.can_wear_attire(PlayerAttire.SAMPLE), "The woven sample opens Tao Xin's garment at the rack."):
		return
	await _press(panel.rows[PlayerAttire.SAMPLE])
	await _snapshot("06-sample-garment")
	await _press(panel.apply_button)
	_expect(not tree.paused and state.attire_id == PlayerAttire.SAMPLE
		and player.tool_gesture.sleeve == PlayerAttire.CATALOG[PlayerAttire.SAMPLE].sleeve,
		"The delivered sample's garment can be worn in the actual estate.")
	await _snapshot("07-sample-garment-worn")
	print("WARDROBE_SAMPLE day=", state.current_day, " garment=", state.attire_id)

func _save_batch_inside() -> bool:
	await _press(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	var saved := false
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _press(button)
			saved = settings.save_status.text == "游戏已保存"
			break
	if not _expect(saved and state.load_game() == OK, "Save and reload at the silkworm trays."):
		return false
	if not await _estate():
		return false
	return _expect(state.estate_room == state.EstateRoom.SILK_SHED and room.room_camera.is_current()
		and player.global_position.is_equal_approx(room.get_node("Entry").global_position)
		and state.silk_workshop.nights_left == state.balance.silk_batch_nights, "Reload restores the active batch and workshop.")

func _begin_batch() -> bool:
	if not await _enter_shed() or not await _station("SilkwormTray"):
		return false
	var leaves: int = state.silk_workshop.leaves
	_expect(leaves >= 2 * state.balance.silk_leaves_per_night
		and state.silk_workshop.nights_left == state.balance.silk_batch_nights, "Harvested leaves start a two-night batch.")
	await _snapshot("02-trays-fed")
	await _key(KEY_E)
	_expect(state.silk_workshop.nights_left == 2 and state.silk_workshop.leaves == leaves
		and ui.hud.practice_label.text.contains("还需"), "Repeating the action leaves the current batch intact.")
	print("SILK_FEED day=", state.current_day, " leaves=", leaves, " nights=", state.silk_workshop.nights_left)
	return await _save_batch_inside() and await _leave(room)

func _night_in_hall() -> bool:
	await _walk(Vector2(55, 135))
	await _walk(Vector2(55, 41))
	await _walk(world.get_node("HallRest/Yard").global_position)
	if not await _step_through(&"ui_up", state.EstateRoom.HALL):
		return false
	var hall := world.get_node("HallInterior") as Node2D
	await _walk(hall.to_global(Vector2(55, 35)))
	await _key(KEY_E)
	var plan: Control = ui.get_node_or_null("Control/NightRationsPanel")
	if not _expect(plan != null and not room.visible, "The hall bed remains usable after leaving the workshop."):
		return false
	await _press(plan.get_node("%Sleep"))
	await tree.create_timer(1.18).timeout
	_expect(state.silk_workshop.nights_left == 1, "The batch progresses while sleeping in the hall.")
	return await _leave(hall)

func _craft_sample() -> bool:
	if not await _enter_shed() or not await _station("Loom"):
		return false
	_expect(state.silk_workshop.bolts == 0 and ui.hud.practice_label.text.contains("生丝"),
		"The loom explains its material cost when empty.")
	if not await _station("Reel"):
		return false
	var thread: int = state.silk_thread_yield()
	_expect(state.silk_workshop.cocoons == 1 and state.silk_workshop.raw_silk == thread
		and room.get_node("Reel").movement.is_running(), "A cocoon is reeled with visible wheel motion.")
	if DisplayServer.get_name() != "headless":
		var reels := room.get_children().filter(func(node: Node): return node is AudioStreamPlayer2D and node.stream.resource_path.ends_with("/reel.wav"))
		_expect(not reels.is_empty(), "The reel plays its own local sound.")
	await _snapshot("03-reeling")
	await _key(KEY_E)
	if not await _station("Loom"):
		return false
	_expect(state.silk_workshop.cocoons == 0 and state.silk_workshop.raw_silk == 0 and state.silk_workshop.bolts == 1
		and ui.hud.get_node("%WorkshopStock").text.contains("丝绸 1"), "The loom uses the right thread and the room shows the bolt.")
	await _snapshot("04-first-bolt")
	print("SILK_WOVEN day=", state.current_day, " thread_per_cocoon=", thread, " cloth=", state.silk_workshop.bolts)
	return await _leave(room)

func _play() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _press(tree.current_scene.new_button)
	if not await _estate():
		return
	_expect(not shed.visible and not room.visible, "The workshop starts unbuilt.")
	for date in range(1, 10):
		await _walk(Vector2(66, 98))
		await _tend(MILLET, KEY_1)
		await _tend(MULBERRY, KEY_6)
		match date:
			1, 2: await _study()
			3:
				if not await _build_shed():
					return
			4:
				if not await _merchant(false):
					return
			5:
				if not await _begin_batch() or not await _night_in_hall():
					return
				continue
			7:
				if not await _craft_sample():
					return
			9:
				if await _merchant(true):
					await _wear_sample_in_hall()
				return
		await _press(ui.sleep_button)
		await tree.create_timer(1.18).timeout
		if not _expect(state.current_day == date + 1, "One night advances one day."):
			return

func _location_compatibility() -> void:
	var legacy := OS.get_environment("FIEFDOM_LEGACY_HALL_SAVE")
	if legacy.is_empty():
		legacy = "user://previous-hall.json"
		var file := FileAccess.open(legacy, FileAccess.WRITE)
		file.store_string(JSON.stringify({"current_day": 4, "inside_hall": true}))
		file.close()
	if not _expect(state.load_game(legacy) == OK, "Load a save using the previous hall flag."):
		return
	if not await _estate():
		return
	var hall := world.get_node("HallInterior") as Node2D
	_expect(state.estate_room == state.EstateRoom.HALL and hall.room_camera.is_current()
		and player.global_position.is_equal_approx(hall.get_node("Wake").global_position),
		"The previous hall save still resumes by its bed.")
	print("SILK_LEGACY_HALL day=", state.current_day, " position=", player.global_position)
	var conflict := "user://shed-footprint-save.json"
	var file := FileAccess.open(conflict, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"current_day": 7, "estate_room": state.EstateRoom.SILK_SHED,
		"silk_workshop": {"built": true, "leaves": 8},
		"well_fields": [{"center_pos": "-3,5", "is_unlocked": true, "reclamation_progress": 4}]
	}))
	file.close()
	if not _expect(state.load_game(conflict) == OK, "Load an established field covering the shed's base."):
		return
	if not await _estate():
		return
	_expect(state.estate_room == state.EstateRoom.OUTDOORS and not shed.visible and player.camera.is_current()
		and shed.get_node("Walls/Back").disabled and state.can_use_workshop(SilkWorkshop.Action.START_BATCH),
		"The field stays usable and workshop management remains available when the doorway is covered.")

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use a temporary profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	captures = OS.get_environment("FIEFDOM_SILK_CAPTURES")
	tree.root.notify_mouse_entered()
	seed(341)
	await _play()
	if failures == 0:
		await _location_compatibility()
	tree.paused = false
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
