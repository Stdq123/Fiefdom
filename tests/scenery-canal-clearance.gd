extends SceneTree

const SPRING := Vector2i(1, 5)
const DRY_DITCH := Vector2i(-13, -8)

var failed := false
var state: Node
var landscape: Node2D
var tiles: TileMapLayer

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		push_error("Run the scenery check with an isolated smoke profile.")
		quit(1)
		return
	paused = true
	state = root.get_node("Global")
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var world := current_scene.get_node("World")
	landscape = world.get_node("Landscape")
	tiles = world.tile_map
	_check_ground()
	_check_crossings()
	_expect(state.saved_games().is_empty(), "The fixed map check must leave the save catalog empty.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_ground() -> void:
	var network: Irrigation = state.irrigation
	var ditch: Vector2 = landscape._tile_point(DRY_DITCH)
	var over_ditch := Rect2(ditch, Vector2.ONE)
	var over_spring := Rect2(landscape._tile_point(SPRING), Vector2.ONE)
	var over_field := Rect2(landscape._tile_point(state.FIRST_FIELD_CENTER), Vector2.ONE)
	var channels: Dictionary[Vector2i, bool] = {}
	network.restore(SPRING, channels)
	_expect(landscape._ground_clear(over_ditch), "Ground is clear before the ditch is present.")
	_expect(not landscape._ground_clear(over_spring) and not landscape._ground_clear(over_field),
		"The spring and the original field still clear scenery without canals.")
	channels[DRY_DITCH] = true
	network.restore(SPRING, channels)
	_expect(not landscape._ground_clear(over_ditch) and not network.is_channel_wet(DRY_DITCH),
		"A single dry ditch still clears its ground.")
	for y in range(-7, -1):
		for x in range(-6, 13):
			channels[Vector2i(x, y)] = true
	network.restore(SPRING, channels)
	var left := Rect2(ditch + Vector2(8, -2), Vector2(5, 4))
	var right := Rect2(ditch - Vector2(13, 2), Vector2(5, 4))
	var bottom := Rect2(ditch - Vector2(2, 12), Vector2(4, 4))
	_expect(not landscape._ground_clear(left) and landscape._ground_clear(right) and landscape._ground_clear(bottom),
		"A negative canal cell respects the inclusive start and exclusive end of the scenery box.")
	_compare_ground_queries("square grid")
	var original_transform := tiles.transform
	tiles.position += Vector2(11.5, -19.25)
	tiles.rotation = 0.37
	tiles.scale = Vector2(1.15, 0.8)
	_compare_ground_queries("rotated and scaled grid")
	var moved := Rect2(landscape._tile_point(DRY_DITCH), Vector2.ONE)
	_expect(not landscape._ground_clear(moved), "The moved ditch still hides the scenery at its center.")
	network.remove_channel(DRY_DITCH)
	_expect(landscape._ground_clear(moved), "Removing the ditch immediately clears the same query.")
	tiles.transform = original_transform

func _compare_ground_queries(label: String) -> void:
	for y in range(-170, 183, 13):
		for x in range(-275, 322, 19):
			for size: Vector2 in [Vector2.ONE, Vector2(27, 12)]:
				var box := Rect2(Vector2(x, y), size)
				if landscape._ground_clear(box) != _original_ground_clear(box):
					_expect(false, "%s scenery differs at %s." % [label, box])
					return
	var broad := Rect2(-730, -650, 780, 650)
	_expect(landscape._ground_clear(broad) == _original_ground_clear(broad), "A wide query also agrees.")

func _original_ground_clear(artwork: Rect2) -> bool:
	if not landscape._fields_clear(artwork):
		return false
	var expanded := artwork.grow(tiles.tile_set.tile_size.x * 0.5)
	for cell: Vector2i in state.irrigation.channels:
		if expanded.has_point(landscape._tile_point(cell)):
			return false
	return not expanded.has_point(landscape._tile_point(state.irrigation.source_cell))

func _check_crossings() -> void:
	var bounds: Rect2i = state.RECLAMATION_BOUNDS
	var hits := 0
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			var start: Vector2 = landscape._tile_point(cell)
			for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var finish: Vector2 = landscape._tile_point(cell + step)
				var expected: Variant = _original_crossing(start, finish)
				if landscape.track_crossing(start, finish) != expected:
					_expect(false, "Road crossing differs from %s to %s." % [cell, cell + step])
					return
				hits += int(expected != null)
	_expect(hits > 0, "The estate crossing check included actual road intersections.")
	var roads: Array = [[Vector2(0, 4), Vector2(24, 4)], [Vector2.ZERO, Vector2(24, 0)]]
	var widths: Array[float] = [8.0, 8.0]
	landscape._build_track_shapes(roads, widths)
	var edge := Vector2(0, 4)
	_expect(landscape.track_crossing(Vector2(0, -8), edge) == edge,
		"A crossing on a shared endpoint keeps the first matching road.")
	print("SCENERY_CROSSINGS hits=", hits, " grid=", bounds.size)

func _original_crossing(start: Vector2, finish: Vector2) -> Variant:
	var direction := start.direction_to(finish)
	for track: Dictionary in landscape.track_shapes:
		var line: PackedVector2Array = track.gravel_path
		for index in range(1, line.size()):
			var from := line[index - 1]
			var to := line[index]
			if absf(direction.dot(from.direction_to(to))) > 0.60:
				continue
			var crossing: Variant = Geometry2D.segment_intersects_segment(start, finish, from, to)
			if crossing != null:
				return crossing
	return null

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
