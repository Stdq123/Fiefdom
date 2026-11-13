extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const GamepadReplay := preload("res://tests/GamepadReplay.gd")
const SCOUT_CAP := Vector2(0.5, -10.5)
const TRANSPARENT_CORNER := Vector2(-13.5, -13.5)

var tree: SceneTree
var capture_dir := ""
var failed := false

func run(host: SceneTree, capture := "") -> void:
	tree = host
	capture_dir = capture
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated profile for the bow replay."):
		tree.quit(1)
		return
	seed(17)
	tree.root.notify_mouse_entered()
	tree.change_scene_to_file("res://scenes/Title.tscn")
	await tree.scene_changed
	tree.current_scene.new_button.pressed.emit()
	await tree.scene_changed
	await _walk(&"ui_up", 48)
	await _walk(&"ui_right", 213)
	if _expect(tree.current_scene.name == "Wilderness", "Reach the scout through the estate's east gate."):
		await _aim_at_scout(tree.current_scene)
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func _aim_at_scout(trail: Node) -> void:
	var player := trail.get_node("Player") as Player
	var scout := trail.get_node("Enemy2") as Node2D
	var art := scout.get_node("Sprite2D") as Sprite2D
	var target := player.get_node("BowTarget") as Node2D
	# Place a stationary scout at the same height as the player to compare the hat and ground trajectories.
	trail.get_node("Enemy").set_physics_process(false)
	scout.set_physics_process(false)
	scout.global_position = player.global_position + Vector2(74, 0)
	await tree.physics_frame
	_expect(art.is_pixel_opaque(SCOUT_CAP) and not art.is_pixel_opaque(TRANSPARENT_CORNER),
		"The two pointer locations sample a visible hat pixel and transparent sprite padding.")
	var head := art.get_global_transform_with_canvas() * SCOUT_CAP
	await _point_at(head)
	_expect(target.visible and target.global_position.is_equal_approx(scout.global_position),
		"Hovering over the scout's hat marks the ground position where the arrow will aim.")
	await _capture("01-scout-target")
	_fire(head)
	await _wait_for_hit(scout, 20)
	await _capture("02-scout-hit")

	var corner := art.get_global_transform_with_canvas() * TRANSPARENT_CORNER
	await _point_at(corner)
	_expect(not target.visible, "Transparent padding does not select the scout.")
	_fire(corner)
	await tree.create_timer(0.35).timeout
	_expect(scout.health == 20, "A shot into empty space flies straight past the scout.")

	await _point_at(head)
	_fire(head)
	var original_position := scout.global_position
	scout.global_position += Vector2(0, 32)
	await tree.create_timer(0.35).timeout
	_expect(scout.health == 20 and not target.visible, "A scout that moves aside after release can evade the arrow.")
	scout.global_position = original_position
	art.flip_h = true
	_mouse_button(head, MOUSE_BUTTON_WHEEL_UP, true)
	await tree.process_frame
	_expect(player.camera.zoom.x == 3.0, "Test the controller after zooming in.")

	tree.root.notify_mouse_exited()
	var controller := GamepadReplay.new()
	controller.tree = tree
	controller.pad = tree.root.get_node("GamepadInput")
	await controller._aim(art.get_global_transform_with_canvas() * SCOUT_CAP)
	_expect(controller.failures == 0 and controller.pad.active and target.visible,
		"The right stick highlights the scout at the new zoom.")
	await _capture("03-controller-target")
	controller._axis(JOY_AXIS_TRIGGER_RIGHT, 0.85)
	await _wait_for_hit(scout, 10)
	controller._axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	print("BOW_AIM_SCOUT health=", scout.health, " zoom=", player.camera.zoom.x, " controller=", controller.pad.active)

func _expect(ok: bool, detail: String) -> bool:
	if not ok:
		failed = true
		push_error(detail)
	return ok

func _walk(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for frame in frames:
		await tree.physics_frame
	Input.action_release(action)
	await Campaign.wait_for_map_change(tree)

func _point_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	tree.root.push_input(motion, true)
	await tree.process_frame
	await tree.process_frame

func _mouse_button(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = point
	event.global_position = point
	event.pressed = pressed
	tree.root.push_input(event, true)

func _fire(point: Vector2) -> void:
	_mouse_button(point, MOUSE_BUTTON_RIGHT, true)
	_mouse_button(point, MOUSE_BUTTON_RIGHT, false)

func _wait_for_hit(scout: Node, expected_health: int) -> void:
	for frame in 40:
		if scout.health == expected_health:
			return
		await tree.physics_frame
	_expect(false, "Expected the real arrow to reduce scout health to %d, got %d." % [expected_health, scout.health])

func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(capture_dir.path_join(name + ".png")) == OK, "Save bow frame " + name)
	print("BOW_AIM_FRAME ", name, " window=", tree.root.size, " image=", frame.get_size())
