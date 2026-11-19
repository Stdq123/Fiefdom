extends SceneTree

var tree: SceneTree
var screen: Window
var failed := false
var captures := ""
var seat_art: GDScript

func _initialize() -> void:
	_review.call_deferred(self)

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _pose(body: Sprite2D, surface: int, label: String) -> void:
	var art := body.get_node_or_null("SeatedPose") as Node2D
	_expect(art != null and art.visible and art.surface == surface and is_zero_approx(body.self_modulate.a)
		and (art.position + body.position).is_zero_approx(), label + " uses the seated art on the original ground anchor.")

func _standing(body: Sprite2D, label: String) -> void:
	var art := body.get_node_or_null("SeatedPose") as Node2D
	_expect(art != null and not art.visible and art.surface == 0 and body.self_modulate.a > 0.9,
		label + " restores its own standing atlas.")

func _snapshot(state: Node) -> Array:
	return [state.current_day, state.day_progress, state.current_stamina, state.money,
		state.food_storage, state.player_inventory, state.active_crops.duplicate(true),
		state.retainers.map(func(member: Resource): return member.duty)]

func _capture(tag: String, viewport: Viewport) -> void:
	if captures.is_empty():
		return
	for frame in 4:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var raster := viewport.get_texture().get_image()
	_expect(raster.save_png(captures.path_join(tag + ".png")) == OK, "Save an isolated pose frame.")
	print("SEATED_CAST_FRAME ", tag, " window=", screen.size, " pixels=", raster.get_size())
	await tree.process_frame

func _focus_camera(player: Node, center: Vector2) -> void:
	player.camera.position_smoothing_enabled = false
	player.camera.zoom = Vector2.ONE * 3.0
	player.camera.global_position = center
	player.camera.force_update_scroll()

func _check_settle() -> void:
	var actor := Node2D.new()
	actor.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.add_child(actor)
	var body := Sprite2D.new()
	body.texture = load("res://assets/characters/player.png")
	body.hframes = 7
	body.vframes = 3
	body.position.y = -6
	body.self_modulate.a = 0.75
	actor.add_child(body)
	var pose: Node2D = seat_art.new(body)
	body.add_child(pose)
	pose.present(1, Color("#82766d"))
	_expect(is_equal_approx(pose._lift, 1.5) and pose.global_position == actor.global_position,
		"The seated torso starts its short settling motion at the existing anchor.")
	await tree.create_timer(0.22).timeout
	_expect(is_zero_approx(pose._lift) and pose.visible and pose.global_position == actor.global_position,
		"The settling tween completes without moving the seat.")
	pose.restore_standing()
	_expect(is_equal_approx(body.self_modulate.a, 0.75) and not pose.visible,
		"Rising restores the actor's previous opacity.")
	actor.queue_free()

func _pavilion(state: Node, rain: bool) -> void:
	var rain_term: int = state.SOLAR_TERMS.find(state.balance.rain_solar_term)
	state.current_day = rain_term * state.balance.days_per_solar_term + 1 if rain else 1
	state.day_progress = 0.92
	tree.change_scene_to_file(state.ESTATE_SCENE)
	await tree.scene_changed
	var world := tree.current_scene.get_node("World") as Node2D
	var ui := tree.current_scene.get_node("UI")
	var player: Node = world.player
	var table: Node2D = world.pavilion_rest
	var wait: Control = ui.freight_wait
	var worker: Node = world.retainer_instances[state.retainers[0]]
	var before := _snapshot(state)
	_expect(state.has_rain() == rain and table.is_evening_open(), "The static evening fixture can draw its seats.")
	worker.restore_evening()
	var worker_at: Vector2 = worker.global_position
	_pose(worker.sprite, 1, "The retainer waiting on the mat")

	var visitors := load("res://scripts/VisitorData.gd")
	var data: Resource = visitors.new()
	data.name = visitors.SILK_MERCHANT
	data.school = visitors.School.MERCHANT
	var guest: Node2D = load("res://scenes/Visitor.tscn").instantiate()
	guest.data = data
	world.add_child(guest)
	world.active_visitors.append(guest)
	world.scheduled_visitor = data
	var guest_at: Vector2 = table.guest_seat()
	guest.go_to_activity(visitors.VisitActivity.PAVILION_REST, PackedVector2Array([guest_at]), table.gathering_center(), false)
	_pose(guest.sprite, 1, "The guest placed directly at an evening stop")
	_expect(guest.position == guest_at and table.tabletop.global_position.y < guest.global_position.y,
		"The nearer guest sorts in front of the tabletop from the same seat.")
	_expect(world.y_sort_enabled and table.y_sort_enabled and table.tabletop.get_parent() == table,
		"The table has its own draw origin within the world Y-sort.")

	table.appointment_id = "presentation"
	table.mats.queue_redraw()
	var seat: Vector2 = table.global_position
	wait.wait_for_pavilion(player, table, table.appointment_id)
	_pose(player.sprite, 1, "The player waiting for the evening gathering")
	_expect(player.resting and player.seated and player.global_position == seat and player.facing_direction() == Vector2.UP,
		"The player sits at the existing approach and faces the table.")
	_focus_camera(player, table.tabletop.global_position + Vector2(0, 8))
	await _capture("rain-shelter-seated" if rain else "pavilion-seated", screen)
	wait.stand.pressed.emit()
	_standing(player.sprite, "The player rising from the mat")
	_expect(player.global_position == seat and not wait.visible and not player.resting and not player.seated,
		"Rising from the mat retains the ground anchor and frees the player.")

	worker.sprite.walk(Vector2.LEFT * 2.0)
	_standing(worker.sprite, "The retainer leaving the mat")
	_expect(worker.global_position == worker_at and worker.sprite.flip_h and worker.sprite.frame_coords.x == 1,
		"Starting the walk animation uses the normal leading foot and flip.")
	guest.go_to_activity(visitors.VisitActivity.NONE, PackedVector2Array([guest_at]), table.gathering_center(), false)
	_standing(guest.sprite, "A guest who changes to another stop")

	if not rain:
		var bench: Node2D = ui.freight_bench
		var bench_at := bench.to_global(bench.get_script().SEAT_OFFSET)
		wait.wait_for(player, state.day_progress + 0.04, state.day_watch_label(), bench_at)
		_pose(player.sprite, 2, "The player waiting on the freight bench")
		_expect(player.global_position == bench_at and player.facing_direction() == Vector2.DOWN,
			"The original freight seat and its outward facing stay usable.")
		_focus_camera(player, bench_at + Vector2(4, -2))
		await _capture("bench-seated", screen)
		wait.stand.pressed.emit()
		_standing(player.sprite, "The player getting up from the bench")
		_focus_camera(player, bench_at + Vector2(4, -2))
		await _capture("bench-standing", screen)
	_expect(tree.paused and before == _snapshot(state) and state.saved_games().is_empty(),
		"Seat presentation must leave the estate clock, supplies, work and saves untouched.")

func _figures(workers: bool, bench: bool) -> void:
	if captures.is_empty():
		return
	var textures: Array[Texture2D] = []
	var clothes: Array[Color] = []
	var columns := 7
	if workers:
		var art := load("res://scripts/CharacterArt.gd")
		var visitors := load("res://scripts/VisitorData.gd")
		columns = art.WORKER_COLUMNS
		for speaker: String in visitors.NEIGHBORS:
			textures.append(art.retainer_motion(speaker, 0, -1))
			clothes.append(art.retainer_sleeve(speaker, 0, -1))
		for school in art.RETAINER_SCHOOLS:
			textures.append(art.retainer_motion("", school, -1))
			clothes.append(art.retainer_sleeve("", school, -1))
		for school in visitors.School.size():
			textures.append(art.retainer_motion("", 0, school))
			clothes.append(art.retainer_sleeve("", 0, school))
	else:
		var attire := load("res://scripts/PlayerAttire.gd")
		for outfit: String in attire.CATALOG:
			textures.append(attire.texture(outfit))
			clothes.append(attire.CATALOG[outfit].sleeve)

	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.size = Vector2i(640, 80 * textures.size())
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen.add_child(viewport)
	for index in textures.size():
		for column in 8:
			var actor := Node2D.new()
			actor.position = Vector2(column * 80 + 40, index * 80 + 54)
			actor.scale = Vector2.ONE * 2.0
			viewport.add_child(actor)
			var body := Sprite2D.new()
			body.texture = textures[index]
			body.hframes = columns
			body.vframes = 3
			body.position.y = -6
			body.frame_coords = Vector2i(0, mini(column % 4, 2))
			body.flip_h = column % 4 == 3
			body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			actor.add_child(body)
			if column >= 4:
				var art: Node2D = seat_art.new(body)
				body.add_child(art)
				art.present(2 if bench else 1, clothes[index])
	await _capture("cast-mats" if workers else ("wardrobe-bench" if bench else "wardrobe-mats"), viewport)
	viewport.queue_free()

func _review(scenario: SceneTree) -> void:
	tree = scenario
	screen = tree.root
	var profile := OS.get_user_data_dir()
	if not ("fiefdom-smoke-" in profile or "fiefdom-seated-cast-" in profile):
		push_error("Use an isolated profile to mount the seated cast.")
		tree.quit(1)
		return
	tree.paused = true
	AudioServer.set_bus_mute(0, true)
	seat_art = load("res://scripts/SeatedPose.gd")
	if DisplayServer.get_name() != "headless":
		var args := OS.get_cmdline_user_args()
		captures = args[0]
		var size_pair := args[1].split("x")
		_expect(screen.size == Vector2i(size_pair[0].to_int(), size_pair[1].to_int()), "Requested window size.")
	var state := screen.get_node("Global")
	await _check_settle()
	await _pavilion(state, false)
	await _pavilion(state, true)
	await _figures(false, false)
	await _figures(false, true)
	await _figures(true, false)
	if not failed:
		print("SEATED_CAST_VIEWS_OK saves=0 paused=true window=", screen.size)
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
