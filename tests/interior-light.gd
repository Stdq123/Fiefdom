extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error(detail)

func _check_clothes_rack(hall: Node2D, actor: Node2D) -> void:
	var rack := hall.get_node("ClothesRack/Sprite") as Sprite2D
	var occlusion := hall.get_node("SceneryOcclusion")
	var original := actor.global_position
	actor.global_position = hall.to_global(Vector2(-54, 14))
	occlusion._process(1.0 / 60.0)
	_expect(rack.modulate.a < 1.0 and rack.modulate.a > 0.76, "The clothes rack begins fading behind its foot.")
	occlusion._process(0.4)
	_expect(is_equal_approx(rack.modulate.a, 0.76), "The rack lets the covered torso show without losing its shape.")
	actor.global_position = hall.to_global(Vector2(-60, 43))
	occlusion._process(0.4)
	_expect(is_equal_approx(rack.modulate.a, 1.0), "The rack returns to solid when the player is in front.")
	actor.global_position = original

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the interior-light check with an isolated smoke profile.")
		quit(1)
		return
	var shader := load("res://resources/interior-window.gdshader") as Shader
	var uniforms := shader.get_shader_uniform_list()
	for parameter in [&"room_origin", &"beam_origin", &"beam_depth", &"direct_light"]:
		_expect(uniforms.any(func(entry: Dictionary) -> bool: return entry.name == parameter),
			"The window shader exposes %s." % parameter)

	var state := root.get_node("Global")
	paused = true
	state.current_day = 1
	state.day_progress = 0.14
	state.estate_room = state.EstateRoom.HALL
	state.silk_workshop.built = true
	if change_scene_to_file("res://scenes/Main.tscn") != OK:
		quit(1)
		return
	await scene_changed
	await process_frame

	var hall := current_scene.get_node("World/HallInterior") as Node2D
	var silk := current_scene.get_node("World/SilkInterior") as Node2D
	var room_light := current_scene.get_node("World/Landscape/DayLighting") as CanvasModulate
	var hall_projection: ShaderMaterial = hall.window_projection
	var silk_projection: ShaderMaterial = silk.window_projection
	_expect(hall.visible and root.get_camera_2d() == hall.room_camera and not silk.visible and not silk.is_processing(),
		"The saved room uses its own camera and updates only its own light.")
	_expect(hall_projection == hall.get_node("Decor/Mat").material and hall_projection != silk_projection
		and hall_projection.get_shader_parameter("room_origin") == hall.global_position
		and silk_projection.get_shader_parameter("room_origin") == silk.global_position,
		"Each room owns its projection with the hall floor and mat sharing the same coordinates.")
	_check_clothes_rack(hall, current_scene.get_node("World/Player"))

	var morning: Vector2 = hall_projection.get_shader_parameter("beam_origin")
	var morning_depth: float = hall_projection.get_shader_parameter("beam_depth")
	var food: int = state.food_storage
	var money: int = state.money
	var fields := hash(state.well_fields)
	state.day_progress = 0.40
	hall._process(0.0)
	room_light.refresh()
	var noon: Vector2 = hall_projection.get_shader_parameter("beam_origin")
	var noon_depth: float = hall_projection.get_shader_parameter("beam_depth")
	var noon_ambient := room_light.color
	_expect(noon.x > morning.x and noon.y < morning.y and noon_depth < morning_depth
		and hall_projection.get_shader_parameter("direct_light") > 0.9,
		"The same source window casts a shorter and shifted outline at noon.")

	state.current_day = 6
	hall._process(0.0)
	room_light.refresh()
	_expect(state.has_rain() and hall_projection.get_shader_parameter("direct_light") == 0.0
		and hall.window_light.energy > 0.2 and room_light.color.r < noon_ambient.r,
		"Rain hides the sharp patch while keeping diffuse light from the window.")

	state.day_progress = 0.94
	hall._process(0.0)
	room_light.refresh()
	var still_lamp: float = hall.lamp.energy
	hall._process(0.39)
	_expect(hall_projection.get_shader_parameter("direct_light") == 0.0 and hall.window_light.energy < 0.05
		and still_lamp > 0.8 and not is_equal_approx(still_lamp, hall.lamp.energy),
		"At night the lamp provides flickering local light.")
	_expect(paused and state.current_day == 6 and is_equal_approx(state.day_progress, 0.94)
		and state.money == money and state.food_storage == food and hash(state.well_fields) == fields
		and state.saved_games().is_empty(), "The lighting sample leaves the paused estate record intact.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
