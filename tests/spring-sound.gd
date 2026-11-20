extends SceneTree

const ORIGIN := Vector2i(1, 5)
const INLET := Vector2i(3, 5)
const GATE := Vector2i(5, 5)
const DRY := Vector2i(10, 10)

var failed := false
var state: Node
var tile_map: TileMapLayer
var overlay: Node2D
var source: Node2D
var listener: Node2D

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
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
	listener = world.player
	tile_map = world.tile_map
	overlay = tile_map.get_node("IrrigationOverlay")
	source = world.get_node("WaterSource")
	var trickle: AudioStreamPlayer2D = source.trickle
	var before := _state()
	_expect(trickle.bus == &"Ambience" and trickle.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
		and trickle.stream.get_length() >= 10.0, "A single local sound uses the ambience bus and loops.")
	_fixture(false)
	listener.global_position = source.global_position + Vector2(11, 10)
	_settle()
	var clear: float = trickle.volume_linear
	_expect(clear > 0.40 and trickle.global_position.is_equal_approx(source.to_global(source.SPRING_WATER))
		and source.outlets.is_empty(), "The spring is audible even before a channel connects.")
	_fixture(true)
	_expect(source.outlets == [Vector2i.RIGHT], "The visible mouth follows the connected first segment.")
	listener.global_position = _world_at(GATE + Vector2i.RIGHT) + Vector2(9, 11)
	_settle()
	_expect(overlay._nearest_open_water(listener.global_position).is_equal_approx(_world_at(GATE + Vector2i.RIGHT))
		and is_equal_approx(trickle.volume_linear, 0.29) and absf(trickle.pitch_scale - 0.92) < 0.001,
		"The far end of the open field gate carries its own quieter water.")
	_fixture(false)
	var audible := trickle.volume_linear
	overlay._process(1.0 / 60.0)
	_expect(trickle.volume_linear < audible and trickle.volume_linear > 0.0, "Cutting the feeder fades out the sound.")
	_settle()
	var closest: Vector2 = overlay._nearest_open_water(listener.global_position)
	_expect(trickle.volume_linear == 0.0 and not closest.is_finite(),
		"The disconnected gate stays quiet, got gain %f and water at %s." % [trickle.volume_linear, closest])
	listener.global_position = _world_at(DRY)
	_settle()
	_expect(trickle.volume_linear == 0.0, "An isolated ditch is silent.")
	listener.global_position = source.global_position + Vector2(11, 10)
	var day: int = state.current_day
	state.current_day = state.SOLAR_TERMS.find(state.balance.rain_solar_term) * state.balance.days_per_solar_term + 1
	_settle()
	_expect(absf(trickle.volume_linear - clear * 0.55) < 0.001, "Rain gently lowers the nearby spring.")
	state.current_day = state.SOLAR_TERMS.find("小雪") * state.balance.days_per_solar_term + 1
	_settle()
	_expect(absf(trickle.volume_linear - clear * 0.82) < 0.001, "Winter keeps a quieter trickle in the basin.")
	state.current_day = day
	state.estate_room = state.EstateRoom.HALL
	_settle()
	_expect(trickle.volume_linear == 0.0, "Indoors the outdoor sound fades.")
	state.estate_room = state.EstateRoom.OUTDOORS
	_expect(_state() == before and state.saved_games().is_empty(), "The fixed water presentation changes no campaign resources.")
	current_scene.queue_free()
	await process_frame
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _fixture(connected: bool) -> void:
	var channels: Dictionary[Vector2i, bool] = {INLET: true, DRY: true}
	if connected:
		channels[ORIGIN + Vector2i.RIGHT] = true
	var gates: Dictionary[Vector2i, Vector2i] = {GATE: INLET}
	state.irrigation.restore(ORIGIN, channels, gates)
	root.get_node("GameEvents").channels_changed.emit()

func _world_at(cell: Vector2i) -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(cell))

func _settle() -> void:
	for frame in 90:
		overlay._process(1.0 / 60.0)

func _state() -> Array:
	return [state.current_day, state.day_progress, state.food_storage, state.money, state.current_stamina, hash(state.active_crops)]

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
