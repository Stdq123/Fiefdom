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

func check_market() -> void:
	paused = true
	character_art = load("res://scripts/CharacterArt.gd")
	var scene: Node = load("res://scenes/WestMarket.tscn").instantiate()
	root.add_child(scene)
	check_keepers(scene)
	var dyer = scene.get_node("Dyer")
	var porter = scene.get_node("Porter")
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
