extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const Landscape := preload("res://scripts/Landscape.gd")
const TerrainAudio := preload("res://scripts/TerrainAudio.gd")
const PUBLIC := Vector2i(5, 5)

var tree: SceneTree
var state: Node
var world: Node2D
var ui: CanvasLayer
var failures := 0
var baseline := false
var captures := ""

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failures += 1
		push_error(detail)
	return condition

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)
	await tree.process_frame
	await tree.process_frame

func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame

func _snapshot(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless":
		return
	await tree.create_timer(0.26).timeout
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(captures.path_join(name + ".png")) == OK, "Capture " + name)
	print("SCALE_FRAME ", name, " window=", tree.root.size, " image=", frame.get_size())

func _estate() -> bool:
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.scene_file_path == state.ESTATE_SCENE, "Use the actual estate scene."):
		return false
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame
	return true

func _walk(to: Vector2) -> void:
	await Campaign.walk_to(tree, world.player, world.to_global(to))

func _scene_prop_size(terrain: Node2D, prop: int) -> Vector2:
	for sprite: Sprite2D in terrain.scenery:
		if terrain.scenery[sprite] == prop and sprite.visible:
			return sprite.texture.get_size()
	return Vector2.ZERO

func _measure_player() -> void:
	var actor: Player = world.player
	var grid: Vector2i = world.tile_map.tile_set.tile_size
	var cell := actor.sprite.texture.get_size() / Vector2(actor.sprite.hframes, actor.sprite.vframes)
	_expect(grid == Vector2i(16, 16) and cell == Vector2(32, 32), "The town is measured against its field and actor frames.")
	var pixels := actor.sprite.texture.get_image()
	var top := 32
	var bottom := -1
	var left := 32
	var right := -1
	if pixels and not pixels.is_empty():
		for y in 32:
			for x in 32:
				if pixels.get_pixel(x, y).a > 0.85:
					top = mini(top, y)
					bottom = maxi(bottom, y)
					left = mini(left, x)
					right = maxi(right, x)
		_expect(bottom - top + 1 == 27, "The opaque standing sprite is 27 world pixels tall.")
	var feet := actor.get_node("CollisionShape2D").shape as RectangleShape2D
	print("SCALE_ACTOR grid=", grid, " cell=", cell, " standing=", Vector2i(right - left + 1, bottom - top + 1),
		" feet=", feet.size, " zoom=", actor.camera.zoom)

func _field_entry(terrain: Node2D) -> void:
	var field: Rect2 = terrain._field_bounds(state.FIRST_FIELD_CENTER)
	var approach: Dictionary = terrain.track_shapes[Landscape.ESTATE_TRACKS.size()]
	var width := WellFieldMarker.ENTRANCE_WIDTH
	var entry := Vector2(field.get_center().x, field.end.y)
	_expect(field.size == Vector2(48, 48) and approach.width == 16.0 and approach.width == width,
		"A full tile of track joins the actual 3 × 3 field.")
	var marker := world.get_node("TileMapLayer/WellFieldMarker/WellField1/Boundary") as Line2D
	_expect(marker.points[-1] - marker.points[0] == Vector2(width, 0.0),
		"The visible bank leaves the same opening as the track.")
	for x in [-7.0, 7.0]:
		_expect(Geometry2D.is_point_in_polygon(entry + Vector2(x, 2.0), approach.surface),
			"The player's feet fit across the painted approach.")
	print("SCALE_FIELD bounds=", field.size, " approach=", approach.width)

func _gate_passage(terrain: Node2D, gate: Area2D) -> void:
	var near_base := Rect2()
	var far_base := Rect2()
	for sprite: Sprite2D in terrain.gate_bases:
		if absf(sprite.position.x - gate.position.x) > 32.0:
			continue
		var shape: CollisionShape2D = terrain.gate_bases[sprite]
		var size: Vector2 = shape.shape.size
		var base := Rect2(shape.position - size * 0.5, size)
		_expect(sprite.visible and not shape.disabled, "A visible pier has its own collision at its footing.")
		if terrain.scenery[sprite] == Landscape.Prop.GATE:
			near_base = base
		else:
			far_base = base
	var gap := near_base.position.y - far_base.end.y
	var trigger: Vector2 = gate.get_node("CollisionShape2D").shape.size
	_expect(gap >= 32.0 and far_base.end.y < gate.position.y and gate.position.y < near_base.position.y
		and trigger.x == 8.0 and trigger.y + 14.0 <= gap,
		"The gateway spans the road with room for feet on either side of its trigger.")
	for y in [-7.0, 0.0, 7.0]:
		_expect(terrain._surface_at(gate.position + Vector2(0.0, y)) == TerrainAudio.Surface.TRACK,
			"The road continues beneath the gateway across the player's foot span.")
	print("SCALE_GATE map=", tree.current_scene.name, " gap=", gap, " trigger=", trigger)

func _opening() -> void:
	var terrain := world.get_node("Landscape") as Node2D
	var hall := world.get_node("HallRest") as Node2D
	var hall_size := _scene_prop_size(terrain, Landscape.Prop.HALL)
	var pavilion_size := _scene_prop_size(terrain, Landscape.SCENE_LANDMARK)
	var gate_size := _scene_prop_size(terrain, Landscape.Prop.GATE)
	var widths: Array = terrain.estate_track_widths.slice(0, 3)
	var hall_expected := Vector2(48, 48) if baseline else Vector2(128, 88)
	var pavilion_expected := Vector2(48, 40) if baseline else Vector2(72, 60)
	var gate_expected := Vector2(48, 48) if baseline else Vector2(32, 48)
	var road_expected := [25.0, 18.0, 14.0] if baseline else [32.0, 22.0, 18.0]
	_expect(hall_size == hall_expected and pavilion_size == pavilion_expected and gate_size == gate_expected
		and widths == road_expected, "The live props and tracks use the expected proportions.")
	print("SCALE_WORLD hall=", hall_size, " pavilion=", pavilion_size, " gate=", gate_size, " dirt_widths=", widths)
	_measure_player()
	if not baseline:
		_field_entry(terrain)
		_gate_passage(terrain, world.get_node("EastGate"))
	var tiles: TileMapLayer = world.tile_map
	var cell := tiles.get_global_transform_with_canvas() * tiles.map_to_local(PUBLIC)
	for action in 3:
		await _click(cell)
	state.advance_daylight(24.0)
	if not baseline:
		var journal := ui.get_node("Control/EstateHUD/Journal") as Control
		var hall_rect: Rect2 = terrain._prop_bounds(Vector2(Landscape.HALL_FOOT), Landscape.Prop.HALL)
		var hall_on_screen := terrain.get_global_transform_with_canvas() * hall_rect
		_expect(not journal.get_global_rect().intersects(hall_on_screen),
			"The opening journal clears the hall from the first field.")
	await _snapshot("01-field-and-hall")
	await _walk(Vector2(-32, 54))
	await _snapshot("02-hall-door")
	if not baseline:
		var landing := hall.position + Vector2(0, -8)
		for at: Vector2 in [hall.position + Vector2(0, 10), landing,
			EstateLayout.PAVILION_APPROACH[1], EstateLayout.SOUTH_PAVILION + Vector2(0, 13)]:
			_expect(terrain._surface_at(at) == TerrainAudio.Surface.TRACK,
				"The hall and pavilion approaches connect their entrances to walkable paths at %s." % at)
		await _walk(landing)
		_expect(world.player.position.distance_to(landing) < 5.0, "The player can stand at the hall steps.")
		await _snapshot("02b-hall-landing")
	await _key(KEY_E)
	var plan := ui.get_node_or_null("Control/NightRationsPanel") as Control
	_expect(plan != null and plan.visible, "The front approach still opens the hall's real night plan.")
	await _key(KEY_ESCAPE)
	await _walk(Landscape.SOUTH_PAVILION + Vector2(31, 15))
	await _snapshot("03-pavilion")
	if not baseline:
		var board := world.get_node("SeasonBoard") as Node2D
		_expect(board.get_node("Hint").global_position.y > board.global_position.y,
			"The delivery label stays below its own board and clear of the pavilion entrance.")

func _silk_and_gates() -> void:
	var path := "user://building-scale-workshop.json"
	var save := FileAccess.open(path, FileAccess.WRITE)
	if not _expect(save != null, "Use the isolated workshop fixture."):
		return
	save.store_string(JSON.stringify({"current_day": 3, "day_progress": 0.31, "silk_workshop": {"built": true}}))
	save.close()
	if not _expect(state.load_game(path) == OK, "Continue a saved estate with a silk shed."):
		return
	await tree.scene_changed
	if not await _estate():
		return
	var terrain := world.get_node("Landscape") as Node2D
	var shed := _scene_prop_size(terrain, Landscape.Prop.SILK_SHED)
	_expect(shed == (Vector2(48, 48) if baseline else Vector2(80, 64)), "The opened workshop has the expected footprint in view.")
	if not baseline:
		var shed_node := world.get_node("SilkShed") as Node2D
		var left_wall := shed_node.get_node("Walls/Left") as CollisionShape2D
		var right_wall := shed_node.get_node("Walls/Right") as CollisionShape2D
		var left_jamb: float = left_wall.global_position.x + left_wall.shape.size.x * 0.5
		var right_jamb: float = right_wall.global_position.x - right_wall.shape.size.x * 0.5
		var artwork: Rect2 = terrain._prop_bounds(Landscape.SILK_SHED_FOOT, Landscape.Prop.SILK_SHED)
		_expect(Vector2(left_jamb, right_jamb) == Vector2(37, 59) + Vector2.ONE * artwork.position.x
			and is_equal_approx((left_jamb + right_jamb) * 0.5, shed_node.global_position.x),
			"The shed's painted 22-pixel opening lines up with the wall collision and entrance.")
	print("SCALE_WORKSHOP shed=", shed)
	var shed_front := Landscape.SILK_SHED_FOOT + Vector2(12, 31)
	if baseline:
		await _walk(shed_front)
	else:
		await Campaign.walk_estate_road_to(tree, world, shed_front)
	_expect(world.player.position.distance_to(shed_front) < 4.0,
		"The workshop facade is reached on foot from the west lane.")
	await _snapshot("04-silk-shed")
	if baseline:
		await _walk(Vector2(360, 4))
	else:
		await Campaign.walk_estate_road_to(tree, world, world.get_node("EastArrival").global_position)
	await _snapshot("05-east-gate")
	await _move(&"ui_right")
	if not _expect(tree.current_scene.scene_file_path == state.WILDERNESS_SCENE, "Walk through East Gate into the ravine."):
		return
	terrain = tree.current_scene.get_node("Landscape") as Node2D
	_expect(_scene_prop_size(terrain, Landscape.Prop.GATE) == (Vector2(48, 48) if baseline else Vector2(32, 48)),
		"The far side of the gate uses the same proportions.")
	if not baseline:
		_gate_passage(terrain, tree.current_scene.get_node("ExitArea"))
	await _snapshot("06-ravine-gate")
	await _move(&"ui_left")
	_expect(await _estate(), "The return gate is reachable.")

func _move(action: StringName) -> void:
	Input.action_press(action)
	for tick in 35:
		await tree.physics_frame
	Input.action_release(action)
	await Campaign.wait_for_map_change(tree)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated scale profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	baseline = OS.get_environment("FIEFDOM_SCALE_BASELINE") == "1"
	captures = OS.get_environment("FIEFDOM_SCALE_CAPTURES")
	tree.root.notify_mouse_entered()
	seed(1107)
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _click(tree.current_scene.new_button.get_global_rect().get_center())
	if await _estate():
		await _opening()
		await _silk_and_gates()
	tree.paused = false
	tree.unload_current_scene()
	for node in tree.root.get_node("AudioManager").get_children():
		if node is AudioStreamPlayer:
			node.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
