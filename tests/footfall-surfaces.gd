extends SceneTree

const TERRAIN_AUDIO := preload("res://scripts/TerrainAudio.gd")

var failed := false
var audio: TERRAIN_AUDIO

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		quit(1)
		return
	paused = true
	audio = root.get_node("AudioManager").terrain_audio
	var estate := root.get_node("Global")
	var before := [estate.current_day, estate.day_progress, estate.money, estate.food_storage]
	if not await _open(estate.WILDERNESS_SCENE):
		quit(1)
		return
	var landscape := current_scene.get_node("Landscape") as Node2D
	var ford := RavineLayout.FORD
	_contact(landscape, ford + Vector2(3, 0), Vector2.RIGHT, 0, TERRAIN_AUDIO.Surface.STONE)
	_contact(landscape, ford + Vector2(-26, 1), Vector2.LEFT, 1, TERRAIN_AUDIO.Surface.STONE)
	_contact(landscape, ford + Vector2(2, -8), Vector2.RIGHT, 0, TERRAIN_AUDIO.Surface.SHALLOWS)
	_contact(landscape, RavineLayout.BRIDGE, Vector2.RIGHT, 1, TERRAIN_AUDIO.Surface.PLANK)

	estate.silk_workshop.built = true
	for room: Array in [[estate.EstateRoom.HALL, "HallInterior"], [estate.EstateRoom.SILK_SHED, "SilkInterior"]]:
		estate.estate_room = room[0]
		if not await _open(estate.ESTATE_SCENE):
			quit(1)
			return
		landscape = current_scene.get_node("World/Landscape")
		var interior := current_scene.get_node("World/" + room[1]) as Node2D
		_expect(interior.visible, "The room mounts in the frozen scene.")
		var floor := landscape.to_local(interior.to_global(Vector2(0, 43)))
		var threshold := landscape.to_local(interior.to_global(Vector2(0, 54)))
		_contact(landscape, floor, Vector2.DOWN, 0, TERRAIN_AUDIO.Surface.PLANK)
		_contact(landscape, threshold, Vector2.DOWN, 1, TERRAIN_AUDIO.Surface.STONE)
	_expect(paused and before == [estate.current_day, estate.day_progress, estate.money, estate.food_storage]
		and estate.saved_games().is_empty(), "The presentation checks leave the campaign paused and create no saves.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _open(path: String) -> bool:
	if change_scene_to_file(path) != OK:
		push_error("Cannot mount the footstep presentation scene.")
		return false
	await scene_changed
	await process_frame
	await process_frame
	return true

func _contact(landscape: Node2D, point: Vector2, direction: Vector2, variant: int, material: int) -> void:
	var effects = landscape.footstep_effects
	effects.clear()
	# Work backward from a painted shoe location to the body anchor for this facing.
	var spread := direction.orthogonal() * (2.5 if variant == 1 else -2.5) * Vector2(1.0, 0.65)
	var anchor := point - Vector2(0, 5) + direction * 1.5 - spread
	audio.step_variant = variant
	landscape._play_step(landscape.to_global(anchor), direction)
	_expect(audio.footsteps.stream == TERRAIN_AUDIO.STEPS[material][variant] and audio.step_variant == variant + 1,
		"The contact selects its material and plays one step at %s." % point)
	var wet := material == TERRAIN_AUDIO.Surface.SHALLOWS
	_expect(effects._marks.size() == int(wet), "Only wet contacts produce a mark at %s." % point)
	if wet and not effects._marks.is_empty():
		_expect(effects._marks[0].position.is_equal_approx(point), "The splash is centered at the shoe.")

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
