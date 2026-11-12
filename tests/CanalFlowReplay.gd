extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const JOIN := Vector2i(2, 5)
const FORK := Vector2i(3, 6)
const FIRST_RICE := Vector2i(4, 5)
const SECOND_RICE := Vector2i(9, 10)
const SECOND_CENTER := Vector2i(10, 10)
const DRY_CHANNELS := ["3,5", "2,6", "3,6", "3,7", "3,8", "3,9", "3,10",
	"4,10", "5,10", "6,10", "7,10", "8,10", "8,9", "8,11"]

var tree: SceneTree
var state: Node
var world: Node
var ui: Node
var captures := ""
var failed := false

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failed = true
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

func _pointer(point: Vector2, shift := false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.shift_pressed = shift
	tree.root.push_input(motion, true)
	await tree.process_frame

func _click(point: Vector2, shift := false) -> void:
	await _pointer(point, shift)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.shift_pressed = shift
		event.position = point
		event.global_position = point
		tree.root.push_input(event, true)
		await tree.process_frame
	await tree.process_frame

func _button(button: Button) -> void:
	await _click(button.get_global_rect().get_center())

func _point(cell: Vector2i) -> Vector2:
	var tiles: TileMapLayer = world.tile_map
	return tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame
	await tree.process_frame

func _fixture() -> bool:
	var fields := [
		{"center_pos": "5,5", "is_unlocked": true, "reclamation_progress": 4},
		{"center_pos": "10,10", "is_unlocked": true, "reclamation_progress": 4},
	]
	var rice := {"id": "rice", "age": 0, "growth_nights": 3, "requires_channel": true}
	var save := FileAccess.open(state.SAVE_PATH, FileAccess.WRITE)
	if not _expect(save != null, "Write the isolated two-field save."):
		return false
	save.store_string(JSON.stringify({
		"save_version": 2, "current_day": 9, "current_rank": state.Rank.ZHONG_SHI, "money": 70,
		"king_storage": 1, "well_fields": fields, "retainers": [], "tech_unlocked": {"irrigation": true},
		"irrigation_channels": DRY_CHANNELS, "channel_survey_day": 6,
		"tilled_cells": ["4,5", "9,10"], "active_crops": {"4,5": rice, "9,10": rice},
	}))
	save.close()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await _estate()
	return _expect(state.current_day == 9 and state.well_fields.size() == 2 and state.irrigation.channels.size() == DRY_CHANNELS.size(),
		"The ordinary title loads the two fields with disconnected ditches.")

func _capture(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(captures.path_join(name + ".png")) == OK, "Capture " + name)

func _look_at_fields() -> void:
	await Campaign.walk_to(tree, world.player, Vector2(120, 144))
	await _pointer(Vector2(624, 369))
	var zoom := InputEventMouseButton.new()
	zoom.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom.pressed = true
	zoom.position = Vector2(624, 369)
	zoom.global_position = zoom.position
	tree.root.push_input(zoom, true)
	await tree.create_timer(0.22).timeout

func _has_supply() -> bool:
	return state.irrigation.supplies(FIRST_RICE) and state.irrigation.supplies(SECOND_RICE)

func _connect_ditch() -> void:
	await _button(ui.channel_button)
	await _click(_point(JOIN))
	await _key(KEY_ESCAPE)
	await _pointer(Vector2(645, 8))

func _cross_planks() -> void:
	var overlay: Node2D = world.irrigation_overlay
	if not _expect(overlay.footbridges.size() == 1, "The transverse ditch has one deck on the road centreline."):
		return
	var deck: Rect2 = overlay.footbridges[0]
	var crossing := overlay.to_global(deck.get_center())
	_expect(absf(crossing.x - 72.0) < 1.0 and crossing.y > 152.0 and crossing.y < 170.0,
		"The deck follows the actual south-east road crossing.")
	var landscape := world.get_node("Landscape")
	var audio = landscape.terrain_audio
	var plank_steps: Array[Vector2] = []
	var record := func(point: Vector2):
		if overlay.footbridge_at(point) and audio.footsteps.stream in audio.STEPS[audio.Surface.PLANK]:
			plank_steps.append(point)
	var player: Player = world.player
	player.footstep.connect(record)
	await Campaign.walk_to(tree, player, crossing - Vector2(0, 14))
	await Campaign.walk_to(tree, player, crossing + Vector2(0, 20))
	await Campaign.walk_to(tree, player, crossing - Vector2(0, 14))
	player.footstep.disconnect(record)
	_expect(not plank_steps.is_empty(), "Walking over the deck plays an actual plank footstep.")
	print("CANAL_DECK center=", crossing, " plank_steps=", plank_steps.size())

func _record_ripples() -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless":
		return
	var overlay: Node2D = world.irrigation_overlay
	DirAccess.make_dir_recursive_absolute(captures.path_join("flow"))
	var source: Vector2 = overlay.get_global_transform_with_canvas() * overlay.tile_map.map_to_local(state.irrigation.source_cell)
	var far_bank := _point(SECOND_CENTER)
	var area := Rect2(source - Vector2(31, 28), far_bank - source + Vector2(112, 85))
	for index in 23:
		await tree.create_timer(1.0 / overlay.RIPPLE_SPEED).timeout
		await RenderingServer.frame_post_draw
		var frame := tree.root.get_texture().get_image()
		var scale := Vector2(frame.get_size()) / tree.root.get_visible_rect().size
		var region := Rect2i(area.position * scale, area.size * scale)
		_expect(frame.get_region(region).save_png(captures.path_join("flow/frame-%02d.png" % index)) == OK,
			"Capture the moving water at game speed.")

func _check_cutoff() -> void:
	await _button(ui.channel_button)
	await _pointer(_point(JOIN), true)
	_expect(world.irrigation_overlay.affected_fields.get(FIRST_RICE) == false
		and world.irrigation_overlay.affected_fields.get(SECOND_RICE) == false
		and "2 格稻暂停" in ui.hud.canal_preview.text,
		"The fill preview names both affected rice plots.")
	await _capture("04-preview-cutoff")
	await _click(_point(JOIN), true)
	await _key(KEY_ESCAPE)
	await _pointer(Vector2(645, 8))
	_expect(not _has_supply() and state.irrigation.flow_distance(FORK) == -1,
		"Filling the join dries the downstream fork and plots.")
	_expect(world.irrigation_overlay.footbridges.size() == 1, "The deck still spans the empty ditch.")
	await _capture("05-line-dry-again")
	await _button(ui.sleep_button)
	await tree.create_timer(1.12).timeout
	if not _expect(state.active_crops[FIRST_RICE].age == 0 and state.active_crops[SECOND_RICE].age == 0
		and state.save_game() == OK and state.load_game() == OK, "Both rice plots stall for the dry night and save."):
		return
	await tree.scene_changed
	await _estate()
	_expect(state.irrigation.flow_distance(FORK) == -1 and world.irrigation_overlay.footbridges.size() == 1,
		"The restored dry network has its original crossing.")
	await _connect_ditch()
	await _button(ui.sleep_button)
	await tree.create_timer(1.12).timeout
	_expect(_has_supply() and state.active_crops[FIRST_RICE].age == 1 and state.active_crops[SECOND_RICE].age == 1,
		"Reopening the join resumes both rice plots on the next night.")
	print("CANAL_GROWTH day=", state.current_day, " first=", state.active_crops[FIRST_RICE].age, " second=", state.active_crops[SECOND_RICE].age)

func run(game_tree: SceneTree, baseline := false) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the canal replay's profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	state.balance.raid_first_day = 10000
	captures = OS.get_environment("FIEFDOM_CANAL_CAPTURES")
	tree.root.notify_mouse_entered()
	if await _fixture():
		await _look_at_fields()
		_expect(not _has_supply(), "The dry route cannot water either crop.")
		await _capture("01-dry-line")
		await _connect_ditch()
		_expect(_has_supply() and state.money == 70 - state.channel_cost(), "One construction click connects both fields and charges once.")
		await _capture("02-connected")
		if baseline:
			print("CANAL_BASELINE directional_flow=", state.irrigation.has_method("flow_distance"),
				" wood_crossing=", world.irrigation_overlay.has_method("footbridge_at"))
		else:
			_expect(state.irrigation.flow_distance(JOIN) == 1 and state.irrigation.flow_distance(FORK) == 3
				and state.irrigation.flow_distance(Vector2i(8, 10)) == 12,
				"The pulse distance follows the shortest connected route through the loop to both fields.")
			var first_frame: int = world.irrigation_overlay.water_frame
			await tree.create_timer(0.18).timeout
			_expect(world.irrigation_overlay.water_frame != first_frame, "The water layer advances while the field is idle.")
			await _capture("03-water-in-motion")
			await _record_ripples()
			await _cross_planks()
			await _check_cutoff()
	tree.unload_current_scene()
	await tree.process_frame
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
