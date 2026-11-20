extends SceneTree

const SPRING := Vector2i(1, 5)
const GATE := Vector2i(5, 5)
const INLET := Vector2i(3, 5)
const WEST_RICE := Vector2i(4, 5)
const NORTH_RICE := Vector2i(5, 4)
const MILLET := Vector2i(6, 5)

var failed := false
var state: Node
var overlay: Node2D

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		push_error("Run the field water check with an isolated smoke profile.")
		quit(1)
		return
	paused = true
	state = root.get_node("Global")
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	var tile_map: TileMapLayer = current_scene.get_node("World").tile_map
	overlay = tile_map.get_node("IrrigationOverlay")
	var items := root.get_node("ItemManager")
	var rice: CropData = items.get_crop("rice")
	for cell: Vector2i in [WEST_RICE, GATE, NORTH_RICE]:
		state.active_crops[cell] = {"data": rice, "age": 1, "growth_nights": 4,
			"requires_channel": true, "watered": false}
	state.active_crops[MILLET] = {"data": items.get_crop("millet"), "age": 1,
		"growth_nights": 4, "requires_channel": false, "watered": true}
	var before := _snapshot()
	var channels: Dictionary[Vector2i, bool] = {Vector2i(2, 5): true, INLET: true,
		Vector2i(2, 4): true, Vector2i(2, 3): true, Vector2i(3, 3): true,
		Vector2i(4, 3): true, Vector2i(5, 3): true}
	var gates: Dictionary[Vector2i, Vector2i] = {GATE: INLET}
	_restore(channels, gates)
	_expect_inflow(WEST_RICE, Vector2.RIGHT, 40.0)
	_expect_inflow(GATE, Vector2.RIGHT, 56.0)
	_expect_inflow(NORTH_RICE, Vector2.DOWN, 104.0)
	_expect(not overlay._paddy_inflows.has(MILLET) and not overlay.flooded_rice.has(MILLET),
		"Moistened millet has no paddy reflection.")
	var disconnected := channels.duplicate()
	disconnected.erase(Vector2i(2, 5))
	_restore(disconnected, gates)
	_expect(overlay._paddy_inflows.is_empty() and overlay.flooded_rice.is_empty()
		and state.crop_water(WEST_RICE, state.active_crops[WEST_RICE]) == state.CropWater.BLOCKED,
		"Disconnected channels and the gate drop the cached reflections together.")
	_restore(channels, gates)
	_expect_inflow(WEST_RICE, Vector2.RIGHT, 40.0)
	_expect_inflow(NORTH_RICE, Vector2.DOWN, 104.0)
	var covered := Vector2i(1, 0)
	var entry := Vector2i(1, 1)
	var exit_cell := Vector2i(2, 0)
	_restore({Vector2i(1, 4): true, Vector2i(1, 3): true, Vector2i(1, 2): true,
		entry: true, covered: true, exit_cell: true}, {})
	_expect(overlay.culverts.has(covered) and not overlay.culverts.has(entry)
		and not overlay.culverts.has(exit_cell), "The saved channel passes beneath the hall foundation.")
	_expect(overlay._visible_flow_limits(entry, covered, 16.0) == Vector2(0.0, 6.5)
		and overlay._visible_flow_limits(covered, exit_cell, 16.0) == Vector2(9.5, 16.0),
		"The exposed halves leave room for the entire glint at the culvert edge.")
	_expect(before == _snapshot() and state.saved_games().is_empty(),
		"Staging the water views preserves the crop records, time and player resources.")
	current_scene.queue_free()
	await process_frame
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _restore(channels: Dictionary[Vector2i, bool], gates: Dictionary[Vector2i, Vector2i]) -> void:
	state.irrigation.restore(SPRING, channels, gates)
	root.get_node("GameEvents").channels_changed.emit()

func _expect_inflow(cell: Vector2i, direction: Vector2, distance: float) -> void:
	var inflow: Variant = overlay._paddy_inflows.get(cell)
	_expect(inflow != null and inflow.direction == direction and is_equal_approx(inflow.distance, distance),
		"Paddy %s takes water from %s at distance %.1f." % [cell, direction, distance])

func _snapshot() -> Array:
	return [state.current_day, state.day_progress, state.current_stamina, state.money,
		state.food_storage, hash(state.active_crops), hash(state.tilled_cells)]

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
