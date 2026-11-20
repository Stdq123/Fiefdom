extends SceneTree

var failed := false
var character_art

func _initialize() -> void:
	check_market.call_deferred()

func expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func check_density(texture: Texture2D, logical: Vector2i) -> void:
	expect(texture.get_size() == Vector2(logical), "World-space size of " + texture.resource_path)
	expect("pixels" in texture and texture.get("pixels").get_size() == Vector2(logical * 2),
		"Two source pixels per world unit in " + texture.resource_path)

func check_keepers(market: Node) -> void:
	var source := Image.new()
	var stalls := market.get_node("Stalls")
	var shelf = stalls.get_child(0)
	check_density(shelf.counter_back.texture.atlas, Vector2i(312, 192))
	check_density(shelf.keeper.texture.atlas, Vector2i(200, 96))
	expect(source.load_png_from_buffer(FileAccess.get_file_as_bytes(shelf.KEEPER_PATH)) == OK, "Keeper poses")
	for stall in stalls.get_children():
		expect(stall.keeper.get_rect().size == Vector2(40, 32), "Keeper fits below the canopy")
		var art_row: Rect2 = stall.keeper.texture.region
		expect(art_row == Rect2(0, 32 * stall.kind, 200, 32), "Shop uses its own keeper")
		expect(stall.counter_back.get_index() < stall.keeper.get_index()
			and stall.keeper.get_index() < stall.counter_front.get_index(), "Hands between back wall and counter")
		var seen := {}
		for phase in stall.keeper.hframes:
			var cell := source.get_region(Rect2i(phase * 80, stall.kind * 64, 80, 64))
			expect(cell.get_used_rect().has_area(), "Visible keeper")
			seen[hash(cell.get_data())] = true
		expect(seen.size() == 5, "Five different poses for " + stall.KEEPERS[stall.kind])
		var times: Vector3 = stall.WORK_TIMES[stall.kind]
		var poses = stall.KeeperPose
		stall.set_interaction_focused(false)
		for beat in [[0.0, poses.REACH], [times.x, poses.TEND], [times.y, poses.SET_DOWN],
				[times.z, poses.REST], [stall.WORK_CYCLE - 0.03, poses.BLINK]]:
			stall.pose_time = beat[0]
			stall._update_keeper()
			expect(stall.keeper.frame == beat[1], "Timed work pose at " + stall.KEEPERS[stall.kind])
		stall.pose_time = times.x
		stall.set_interaction_focused(true)
		expect(stall.keeper.frame == poses.REST, "Looks up to greet the visitor")
		stall.interact()
		var portrait: AtlasTexture = market.counter.keeper_portrait.texture
		expect(portrait.region == character_art.TOWN_REGIONS[stall.KEEPERS[stall.kind]], "Matching shop portrait")
		market.counter.hide()
		stall.set_interaction_focused(false)

func check_walker(body, load_sprite: Sprite2D, hang: float) -> void:
	check_density(body.texture, Vector2i(192, 96))
	expect(body.get_rect().size == Vector2(32, 32), "Walker world footprint")
	body.stand()
	for column: int in [1, 4, 2, 5]:
		body.walk(Vector2.RIGHT * (0.5 if column == 1 else body.step_length))
		expect(body.frame_coords == Vector2i(column, body.Facing.PROFILE), "Four different walking frames")
		body.carry_at(load_sprite, hang)
		expect(load_sprite.position.x > 0 and not load_sprite.show_behind_parent, "Right-hand carry")
		expect(body.position.y == -13 and body.offset == Vector2.ZERO, "Foot stays level with the stone street")
	body.stand()
	body.face(Vector2.LEFT)
	body.carry_at(load_sprite, hang)
	expect(load_sprite.position.x < 0 and not load_sprite.show_behind_parent, "Mirrored carrying hand")
	body.face(Vector2.UP)
	body.carry_at(load_sprite, hang)
	expect(load_sprite.show_behind_parent, "Load passes behind the walker when facing away")

func check_cloth_delivery(scene: Node) -> void:
	var state := root.get_node("Global")
	var former_day: int = state.current_day
	var former_clock: float = state.day_progress
	var dyer := scene.get_node("Dyer") as Node2D
	var cloth := scene.get_node("Stalls/SilkStall/CounterFront/DeliveryCloth") as Sprite2D
	var lands := cloth.global_position
	var before := [state.money, state.food_storage, state.silk_workshop.bolts, state.silk_sample_day]
	state.current_day = 1
	for watch in [0.22, 0.281, dyer.COUNTER_REACH, dyer.SET_DOWN_AT - 0.00001]:
		state.day_progress = watch
		dyer._follow_clock(false)
		expect(dyer.bundle.visible and not cloth.visible, "Only the bundle in her hands is visible before putting it down.")
	expect(dyer.position.is_equal_approx(dyer.COUNTER_FOOT) and dyer.bundle.global_position.distance_to(lands) < 0.1,
		"The delivery puts her hand at the actual counter surface.")
	state.day_progress = dyer.SET_DOWN_AT
	dyer._follow_clock(false)
	expect(not dyer.bundle.visible and cloth.visible and cloth.global_position == lands,
		"The placed cloth takes over at the hand's last position.")
	state.day_progress = 0.32
	dyer._follow_clock(false)
	expect(dyer.position.is_equal_approx(dyer.LAYOUT.DYE_DELIVERY) and cloth.visible,
		"The dyer clears the counter and the cloth stays on the tabletop.")
	state.day_progress = dyer.STOW_CLOTH.y - 0.002
	dyer._follow_clock(false)
	expect(cloth.visible and cloth.modulate.a < 0.7 and cloth.global_position.y < lands.y,
		"The cloth slips back under the awning as the stand closes.")
	state.day_progress = 0.73
	dyer._follow_clock(false)
	expect(not cloth.visible and not dyer.bundle.visible, "Closing the stand clears both cloth poses.")
	state.current_day = state.SOLAR_TERMS.find(state.balance.rain_solar_term) * state.balance.days_per_solar_term + 1
	state.day_progress = 0.32
	dyer._follow_clock(false)
	expect(state.has_rain() and not cloth.visible and not dyer.bundle.visible and dyer.position == dyer.LAYOUT.DYE_EAVE,
		"The cloth stays under cover in the rain.")
	state.current_day = former_day
	state.day_progress = former_clock
	dyer._follow_clock(false)
	expect(before == [state.money, state.food_storage, state.silk_workshop.bolts, state.silk_sample_day],
		"The market presentation keeps the cloth stock and commission record intact.")

func check_market() -> void:
	paused = true
	character_art = load("res://scripts/CharacterArt.gd")
	var scene: Node = load("res://scenes/WestMarket.tscn").instantiate()
	root.add_child(scene)
	check_keepers(scene)
	var dyer = scene.get_node("Dyer")
	var porter = scene.get_node("Porter")
	check_cloth_delivery(scene)
	check_density(dyer.bundle.texture, Vector2i(18, 12))
	check_walker(dyer.body, dyer.bundle, 0.0)
	check_walker(porter.body, porter.creel, 2.5)
	expect(dyer.portrait.region == character_art.TOWN_REGIONS["阿苓"], "Dyer portrait")
	var source: Texture2D = porter.creel.texture
	var crop: Rect2 = porter.creel.region_rect
	expect(porter.creel.region_enabled and Rect2(Vector2.ZERO, source.get_size()).encloses(crop),
		"Porter's creel fits the fishing tackle sheet")
	scene.free()
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
