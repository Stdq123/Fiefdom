extends SceneTree

const VIEWS := [
	["Main", "World/", 1, Vector2(173, -23), Vector2(165, -24), 0.48],
	["Wilderness", "", 6, Vector2(-174, 35), Vector2(-197, 34), 0.48],
	["WestRoad", "", 19, Vector2(29, 5), Vector2(27, 4), 0.30],
	["WestMarket", "", 6, Vector2(137, 145), Vector2(121, 140), 0.30],
]

var failed := false

func _initialize() -> void:
	_check.call_deferred()

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error(detail)

func _check() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	for view: Array in VIEWS:
		state.current_day = view[2]
		state.day_progress = 0.40
		await _check_view(view[0], view[1], view[3], view[4], view[5])
	_expect(paused and state.saved_games().is_empty(), "Fixed cover checks do not play or save the campaign.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_view(map: String, prefix: String, origin: Vector2, foot: Vector2, faded_alpha: float) -> void:
	if change_scene_to_file("res://scenes/" + map + ".tscn") != OK:
		_expect(false, "Mount the real map " + map)
		return
	await scene_changed
	await process_frame
	var actor := current_scene.get_node(prefix + "Player") as Node2D
	var terrain := current_scene.get_node_or_null(prefix + "Landscape")
	var cover := (terrain if terrain else current_scene).get_node("SceneryOcclusion")
	var prop: Sprite2D
	for child in current_scene.get_node(prefix + "Scenery").get_children():
		if child is Sprite2D and child.global_position == origin and child.texture is AtlasTexture:
			prop = child
			break
	if prop == null:
		_expect(false, "Find the real foreground prop in " + map)
		return
	var original := prop.modulate
	actor.global_position = foot
	actor._face(Vector2.DOWN)
	actor._update_walk_sprite(Vector2.ZERO, 0.0)
	cover._process(1.0 / 60.0)
	_expect(prop.modulate.a > faded_alpha and prop.modulate.a < original.a, "The fade starts gradually in " + map)
	cover._process(0.4)
	_expect(is_equal_approx(prop.modulate.a, faded_alpha) and Color(prop.modulate, original.a).is_equal_approx(original),
		"Opaque cover fades according to the painted shape without changing tint in " + map)
	actor.global_position = origin + Vector2(0, 25)
	cover._process(0.4)
	_expect(prop.modulate.is_equal_approx(original), "The prop returns to its original appearance in " + map)
