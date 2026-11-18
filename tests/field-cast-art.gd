extends SceneTree

var failed := false
var art
var gait

func _initialize() -> void:
	check_cast.call_deferred()

func expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func check_sheet(path: String, people: int, columns: int, worker: bool) -> void:
	var texture = load(path)
	var logical := Vector2i(columns * 32, people * 3 * 32)
	expect(texture.get_size() == Vector2(logical), "Logical atlas size " + path)
	var image := Image.new()
	expect(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK, "Source image " + path)
	expect(image.get_size() == logical * 2 and image.detect_alpha() != Image.ALPHA_NONE, "Source density " + path)
	expect(texture.pixels.get_size() == Vector2(logical * 2), "Imported density " + path)
	var walk := [0, 1, 2, art.PASS_COLUMN, art.PASS_COLUMN + 1] if worker else [
		0, 1, 2, PlayerAttire.PASS_COLUMN, PlayerAttire.PASS_COLUMN + 1]
	for look in people:
		for facing in 3:
			var steps := {}
			var poses: Array[int] = []
			for column in columns:
				var cell := image.get_region(Rect2i(column * 64, (look * 3 + facing) * 64, 64, 64))
				var ink := cell.get_used_rect()
				var label := "%s look %d, facing %d, column %d" % [path, look, facing, column]
				expect(ink.size.x >= 15 and ink.size.y >= 44 and ink.position.x > 0 and ink.end.x < 64
					and ink.end.y >= 57 and ink.end.y < 64, "Figure and ground shadow " + label)
				var fingerprint := hash(cell.get_data())
				poses.append(fingerprint)
				if column in walk:
					steps[fingerprint] = true
			expect(steps.size() == 5, "A planted stance and four different walking poses in " + path)
			if worker:
				expect((poses[0] == poses[3]) == (facing == gait.Facing.BACK), "Blink is visible only with a visible face")
				for phase in 2:
					expect(poses[art.WORK_COLUMN + phase] != poses[art.ERRAND_COLUMN + phase],
						"Hands on a tool and empty hands need different silhouettes")

func check_cast() -> void:
	paused = true
	art = load("res://scripts/CharacterArt.gd")
	gait = load("res://scripts/NeighborMotion.gd")
	var visitors = load("res://scripts/VisitorData.gd")
	check_sheet(PlayerAttire.ORIGINAL_PATH, 1, 7, false)
	check_sheet(PlayerAttire.VARIANTS_PATH, PlayerAttire.CATALOG.size() - 1, 7, false)
	check_sheet(art.RETAINER_MOTION, 18, art.WORKER_COLUMNS, true)
	var motion = gait.new()
	root.add_child(motion)
	for speaker: String in visitors.NEIGHBORS:
		motion.set_art(speaker, null)
		expect(motion.get_rect().size == Vector2(32, 32), "World footprint " + speaker)
		for column: int in [1, art.PASS_COLUMN, 2, art.PASS_COLUMN + 1]:
			motion.walk(Vector2.RIGHT * (0.5 if column == 1 else motion.step_length))
			expect(motion.frame_coords == Vector2i(column, gait.Facing.PROFILE), "Walking phase " + speaker)
		motion.face(Vector2.LEFT)
		motion.stand(Vector2.ZERO, 1)
		expect(motion.flip_h and motion.frame_coords.x == art.WORK_COLUMN + 1, "Working to the left")
		motion.stand(Vector2.ZERO, 1, true)
		expect(motion.frame_coords.x == art.ERRAND_COLUMN + 1, "Tending a stall")
	var four_columns := AtlasTexture.new()
	four_columns.atlas = art.festival_guest_motion(0).atlas
	four_columns.region = Rect2(0, 0, 128, 96)
	motion.set_motion_sheet(four_columns)
	for column: int in [1, 0, 2, 0]:
		motion.walk(Vector2.DOWN * (0.5 if column == 1 else motion.step_length))
		expect(motion.frame_coords.x == column, "Four-column guest atlas")
	motion.free()
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
