extends SceneTree

const WALK_ART := preload("res://scripts/PlayerAttire.gd")

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		quit(1)
		return
	paused = true
	var actor = load("res://scenes/Player.tscn").instantiate()
	var seated = load("res://scripts/SeatedPose.gd")
	root.add_child(actor)
	var events: Array[Vector2i] = []
	var contacts: Array[Vector2] = []
	actor.footstep.connect(func(at: Vector2):
		events.append(actor.sprite.frame_coords)
		contacts.append(actor.footstep_contact(at) - at)
	)
	for direction: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
		events.clear()
		contacts.clear()
		actor._update_walk_sprite(Vector2.ZERO)
		for distance in range(1, 51):
			actor._update_walk_sprite(direction, direction)
			var expected := 0 if distance < 10 else floori((distance - 10) / 20.0) + 1
			_expect(events.size() == expected, "The step fires at 10, 30 and 50 pixels of travel.")
		var row: int = actor.facing_row
		_expect(events == [Vector2i(1, row), Vector2i(2, row), Vector2i(1, row)],
			"The event observes the alternating planted frames.")
		_expect(contacts.size() == 3 and contacts[0] != contacts[1] and contacts[0] == contacts[2]
			and actor.sprite.flip_h == (direction == Vector2.LEFT), "The contact follows the two painted soles.")
		if direction == Vector2.LEFT and contacts.size() == 3:
			_expect(contacts[0].x < 0 and contacts[1].x < 0, "A mirrored side pose moves both contacts to the left.")

	actor._update_walk_sprite(Vector2.ZERO)
	events.clear()
	var diagonal := Vector2(0.8, -0.6)
	for frame in 6:
		actor._update_walk_sprite(diagonal, Vector2.UP * 2)
	_expect(actor.sprite.frame_coords == Vector2i(1, actor.Facing.BACK)
		and actor.facing_direction() == Vector2.RIGHT and events.size() == 1,
		"The slide is drawn upward and preserves the requested direction for map entrances.")
	for frame in 12:
		actor._update_walk_sprite(diagonal)
	_expect(events.size() == 1 and actor.sprite.frame_coords.x == 0, "Pushing against a wall leaves the feet still.")
	actor.set_seat_pose(seated.Surface.MAT)
	actor._update_walk_sprite(Vector2.RIGHT, Vector2(20, 0))
	_expect(events.size() == 1 and actor.sprite.frame_coords.x == 0, "A seated pose does not emit walking feedback.")
	actor.set_seat_pose(seated.Surface.STANDING)

	_check_atlases(WALK_ART.ORIGINAL_PATH, 1)
	_check_atlases(WALK_ART.VARIANTS_PATH, 7)
	_expect(root.get_node("Global").saved_games().is_empty(), "The animation fixtures write no game saves.")
	actor.queue_free()
	await process_frame
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_atlases(path: String, sheets: int) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	const STRIDE := 64
	for sheet in sheets:
		for row in 3:
			for column in [1, 2]:
				var sole := WALK_ART.planted_sole(Vector2i(column, row), false)
				var frame_offset := Vector2i(column, sheet * 3 + row) * STRIDE
				var pixel := frame_offset + Vector2i(Vector2(32, 32) + sole * 2) - Vector2i(0, 1)
				_expect(image.get_pixelv(pixel).a > 0.80,
					"Find a painted sole in %s at outfit %d, row %d and column %d." % [path, sheet, row, column])

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
