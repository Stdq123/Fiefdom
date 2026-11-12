extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const PUBLIC := Vector2i(5, 5)

var tree: SceneTree
var state: Node
var world: Node
var ui: Node
var visitor_data: GDScript
var cast_names: Array
var capture_dir := ""
var film_dir := ""
var failed := false

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failed = true
		push_error(detail)
	return condition

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame

func _key(code: Key) -> void:
	var input := InputEventKey.new()
	input.pressed = true
	input.keycode = code
	input.physical_keycode = code
	tree.root.push_input(input, true)

func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	tree.root.push_input(motion, true)
	for pressed in [true, false]:
		var input := InputEventMouseButton.new()
		input.pressed = pressed
		input.button_index = MOUSE_BUTTON_LEFT
		input.position = at
		input.global_position = at
		tree.root.push_input(input, true)
		await tree.process_frame

func _click_cell(cell: Vector2i) -> void:
	var tiles: TileMapLayer = world.tile_map
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))

func _walk(at: Vector2) -> void:
	await Campaign.walk_to(tree, world.player, at)
	await tree.physics_frame
	await tree.process_frame

func _talk() -> Control:
	_key(KEY_E)
	await tree.process_frame
	return ui.get_node_or_null("Control/DialoguePanel") as Control

func _choose(dialog: Control, text: String) -> void:
	if _expect(dialog != null, "A nearby character opens the dialogue."):
		for button: Button in dialog.options_container.get_children():
			if button.text.begins_with(text):
				if _expect(not button.disabled, "Expected an available dialogue option " + text):
					await _click(button.get_global_rect().get_center())
				return
		_expect(false, "Could not find the dialogue option " + text)

func _sleep() -> void:
	await _click(ui.sleep_button.get_global_rect().get_center())
	await tree.create_timer(1.15).timeout

func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Could not capture " + name)
	print("CAST_FRAME ", name, " ", image.get_size())

func _use_near_view() -> void:
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = tree.root.get_visible_rect().get_center()
	tree.root.push_input(wheel, true)
	await tree.process_frame

func _watch_water(keeper: Node2D) -> void:
	var sheet = keeper.sprite
	var clip: AudioEffectRecord
	var bus := AudioServer.get_bus_index("SFX")
	var effect := AudioServer.get_bus_effect_count(bus)
	if not film_dir.is_empty():
		clip = AudioEffectRecord.new()
		AudioServer.add_bus_effect(bus, clip)
		clip.set_recording_active(true)
	var steps: Dictionary[int, bool] = {}
	var faced_field := false
	var saw_pail := false
	var saw_pour := false
	var spatial_water := false
	var first_water_tick := -1
	var sample_frame := 0
	for tick in 212:
		await tree.physics_frame
		if sheet.walking:
			steps[sheet.frame_coords.x] = true
			faced_field = faced_field or sheet.facing == sheet.Facing.BACK
		if not saw_pail and sheet.walking and keeper.tool_gesture.carrying and sheet.frame_coords.x > 0:
			saw_pail = true
			await _capture("01-carrying-the-pail")
		if not saw_pour and keeper.current_state == keeper.State.WORK and keeper.work_left < 0.07 and keeper.tool_gesture.visible:
			saw_pour = true
			await _capture("02-watering-the-field")
			if not capture_dir.is_empty():
				var cursor := world.tile_map.get_node("FieldCursor") as Node2D
				var position_y := cursor.get_global_transform_with_canvas().origin.y
				var caption_y: float = cursor.caption.get_global_transform_with_canvas().origin.y
				_expect(cursor.visible and caption_y > position_y, "The field caption leaves the watering retainer's face visible.")
		if first_water_tick < 0 and state.active_crops[PUBLIC]["watered"]:
			first_water_tick = tick
		for child in world.get_children():
			if child is AudioStreamPlayer2D and child.stream and child.stream.resource_path.ends_with("retainer-water.wav"):
				spatial_water = spatial_water or (child.max_distance == 190.0 and child.volume_db == -9.0
					and child.global_position.distance_to(world.get_crop_world_pos(PUBLIC)) < 10.0)
		if clip and tick % 5 == 0:
			await RenderingServer.frame_post_draw
			var frame := tree.root.get_texture().get_image()
			_expect(frame.save_png(film_dir.path_join("frame-%03d.png" % sample_frame)) == OK, "Could not save a gait sample.")
			sample_frame += 1
		if first_water_tick >= 0 and tick - first_water_tick >= 35:
			break
	_expect(steps.has(1) and steps.has(2) and faced_field and saw_pail and saw_pour and first_water_tick >= 0,
		"A retainer actually walks north with alternating steps and waters the crop at the end of the gesture.")
	if DisplayServer.get_name() != "headless":
		_expect(spatial_water, "A successful pour starts the localized watering recording next to the plot.")
	if clip:
		clip.set_recording_active(false)
		var sound := clip.get_recording()
		_expect(sound != null and sound.save_to_wav(film_dir.path_join("watering.wav")) == OK,
			"The watering sound can be recorded from the live effects bus.")
		AudioServer.remove_bus_effect(bus, effect)
	print("CAST_WATER steps=", steps.keys(), " work=", saw_pour, " wet_tick=", first_water_tick, " positional_sound=", spatial_water)

func _show_cast_study() -> void:
	if capture_dir.is_empty():
		return
	var scene := load("res://scenes/Visitor.tscn") as PackedScene
	# Arrange the released art at the estate's near zoom for a single reference shot.
	for index in cast_names.size():
		var person := scene.instantiate() as CharacterBody2D
		var data: Resource = visitor_data.new()
		data.name = cast_names[index]
		person.data = data
		person.position = Vector2(-108 + index * 40, -94)
		person.collision_layer = 0
		person.collision_mask = 0
		world.add_child(person)
		person.remove_from_group("interactable")
	world.player.position = Vector2(12, -96)
	world.player.hide()
	world.player.camera.force_update_scroll()
	await _capture("06-seven-neighbors-study")

func _end() -> void:
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated character replay profile."):
		_end()
		return
	seed(3508)
	capture_dir = OS.get_environment("FIEFDOM_CAST_CAPTURES")
	film_dir = OS.get_environment("FIEFDOM_CAST_FILM")
	state = tree.root.get_node("Global")
	tree.change_scene_to_file("res://scenes/Title.tscn")
	await tree.scene_changed
	tree.current_scene.new_button.pressed.emit()
	await tree.scene_changed
	await _estate()
	await _use_near_view()
	visitor_data = load("res://scripts/VisitorData.gd")
	cast_names = visitor_data.get_script_constant_map()["NEIGHBORS"]
	var regions: Dictionary[Rect2, bool] = {}
	for name: String in cast_names:
		var actor: Resource = visitor_data.new()
		actor.name = name
		var icon := actor.get_appearance_texture() as AtlasTexture
		_expect(icon != null and icon.atlas.resource_path.ends_with("neighbor-motion.svg") and icon.region.size == Vector2(32, 32),
			"Each named neighbor has a 32-pixel identity on the map and list.")
		regions[icon.region] = true
	var unnamed: Resource = visitor_data.new()
	_expect(regions.size() == 7 and unnamed.get_appearance_texture().atlas.resource_path.ends_with("cast.svg"),
		"The seven identities use distinct artwork and ordinary travelers have a fallback.")
	var keeper: Node2D = world.retainer_instances[state.retainers.front()]
	_expect(keeper.sprite.directional and keeper.sprite.hframes == 4 and keeper.sprite.vframes == 3,
		"The resident has a directional atlas before the first sowing.")
	await _click_cell(PUBLIC)
	await _click_cell(PUBLIC)
	if not _expect(state.active_crops.has(PUBLIC) and not state.active_crops[PUBLIC]["watered"], "A dry public crop starts the work route."):
		_end()
		return
	await _watch_water(keeper)
	await _sleep()
	var visitor: Node2D = world.active_visitors.front()
	_expect(visitor.data.name == "季青" and visitor.sprite.directional, "The day-two visitor uses his own map art.")
	await _walk(visitor.global_position + Vector2(-21, 4))
	_expect(visitor.sprite.facing == visitor.sprite.Facing.PROFILE and visitor.sprite.flip_h,
		"A visitor follows a player approaching from the west with a left-facing profile.")
	await _walk(visitor.global_position + Vector2(2, -19))
	_expect(visitor.sprite.facing == visitor.sprite.Facing.BACK and not visitor.sprite.flip_h,
		"Walking around the same visitor updates the back view without changing target.")
	var dialogue := await _talk()
	_expect(world.player.facing_row == world.player.Facing.FRONT and dialogue != null and dialogue.name_label.text == "季青",
		"Pressing E faces the player toward the visitor and opens the usual dialogue.")
	await _capture("03-conversation-facing")
	await _choose(dialogue, "交谈")
	await _walk(Vector2(57, 103))
	if world.field_action(PUBLIC) == world.FieldAction.WATER:
		await _click_cell(PUBLIC)
	await _sleep()
	await _click_cell(PUBLIC)
	_expect(state.king_storage == 1, "Working animation preserves ordinary crop growth and tribute.")
	visitor = world.active_visitors.front()
	_expect(visitor.data.name == "石墨", "The water-source visitor arrives on day three.")
	var before: Rect2 = visitor.sprite.texture.region
	await _walk(visitor.global_position + Vector2(18, 6))
	dialogue = await _talk()
	await _capture("04-shi-mo-at-the-water-source")
	await _choose(dialogue, "交谈")
	await _choose(await _talk(), "招募")
	var recruited: Resource = state.retainers.back()
	_expect(recruited.name == "石墨" and world.retainer_instances[recruited].sprite.texture.region == before,
		"Recruitment preserves the same character artwork and gait frames.")
	await _click(ui.manage_button.get_global_rect().get_center())
	var panel: Control = ui.panel_manager.management_panel_instance
	var icon := panel.retainer_list_container.get_child(1).icon.texture as AtlasTexture
	_expect(icon.atlas.resource_path.ends_with("neighbor-motion.svg") and icon.region.position.y == before.position.y,
		"The retainer list uses the front-facing icon for the same person.")
	await _capture("05-recruited-list")
	await _click(panel.get_node("CloseButton").get_global_rect().get_center())
	if not _expect(state.save_game() == OK and state.load_game() == OK, "The recruited neighbor saves and reloads normally."):
		_end()
		return
	await tree.scene_changed
	await _estate()
	recruited = state.retainers.back()
	_expect(recruited.name == "石墨" and world.retainer_instances[recruited].sprite.texture.region == before,
		"A reload derives the same identity from the saved neighbor name.")
	await _show_cast_study()
	tree.change_scene_to_file("res://scenes/Title.tscn")
	await tree.scene_changed
	tree.root.get_node("AudioManager").bgm_player.stop()
	await tree.create_timer(0.4).timeout
	_end()
