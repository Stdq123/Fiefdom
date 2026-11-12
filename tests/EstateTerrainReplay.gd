extends "res://tests/BuildingScaleReplay.gd"

var title_art := false
var capture_path := ""

func _opening() -> void:
	if not capture_path.is_empty():
		captures = capture_path
	if title_art:
		await _take_title_art()
		return
	var terrain: Node2D = world.get_node("Landscape")
	var road: PackedVector2Array = terrain.track_shapes[0].surface
	var west_visible := Geometry2D.is_point_in_polygon(Vector2(-446, -30), road)
	var east_visible := Geometry2D.is_point_in_polygon(Vector2(627, 3), road)
	_expect(west_visible != baseline and east_visible != baseline,
		"Both gate roads reach the last visible part of the camera's range in the new terrain.")
	_field_entry(terrain)
	_gate_passage(terrain, world.get_node("WestMarketGate"))
	_gate_passage(terrain, world.get_node("EastGate"))
	var tiles: TileMapLayer = world.tile_map
	var public_point := tiles.get_global_transform_with_canvas() * tiles.map_to_local(PUBLIC)
	for action in 3:
		await _click(public_point)
	var crop: Dictionary = state.active_crops.get(PUBLIC, {})
	_expect(not crop.is_empty() and crop.get("watered", false), "Sow and water the central field over the new ground.")
	state.advance_daylight(23.0)
	await _snapshot("00-first-field")
	await _walk(Vector2(-181, 54))
	await _walk(Vector2(-181, -21))
	await _walk(Vector2(-270, -21))
	await _snapshot("01-west-road")
	await _move(&"ui_left")
	if not _expect(tree.current_scene.scene_file_path == state.WEST_MARKET_SCENE,
			"The newly extended road still leads through the west gate."):
		return
	await _move(&"ui_right")
	if not await _estate():
		return
	_expect(state.active_crops.has(PUBLIC) and state.active_crops[PUBLIC].watered,
		"West market travel preserves the crop and its water.")
	await _walk(Vector2(-165, -19))
	await _walk(Vector2(-165, -289))
	var north: float = world.player.position.y
	_expect(absf(north - (Landscape.ESTATE_BOUNDS.position.y + 7.0)) < 2.0,
		"Walking north stops at the original terrain boundary underneath the stone bank.")
	await _snapshot("02-north-slope")
	await _key(KEY_M)
	_expect(ui.estate_map.modal.visible, "The extended roads are available in the estate survey.")
	await _snapshot("07-estate-survey")
	await _key(KEY_ESCAPE)
	print("TERRAIN_ROUTES baseline=", baseline, " west_continues=", west_visible, " east_continues=", east_visible,
		" north_foot=", snappedf(north, 0.1), " watered=", state.active_crops[PUBLIC].watered)

func _silk_and_gates() -> void:
	if title_art or failures > 0:
		return
	state.current_day = 6
	state.day_progress = 0.35
	state.silk_workshop.built = true
	state.max_well_fields = 2
	_expect(state.add_well_field(Vector2i(12, 5)), "Prepare a second field beside the east road.")
	var second: Dictionary = state.well_fields.back()
	second.is_unlocked = true
	second.reclamation_progress = state.RECLAMATION_NIGHTS
	state.tech_unlocked["irrigation"] = true
	state.money = 100
	var empty_channels: Dictionary[Vector2i, bool] = {}
	state.irrigation.restore(Vector2i(1, 5), empty_channels)
	var ditch: Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 5), Vector2i(3, 6), Vector2i(3, 7),
		Vector2i(3, 8), Vector2i(3, 9), Vector2i(3, 10)]
	_expect(state.build_channel_path(ditch) == Global.ChannelSite.AVAILABLE, "Build a canal across the south-east lane.")
	tree.change_scene_to_file(state.ESTATE_SCENE)
	await tree.scene_changed
	if not await _estate():
		return
	_expect(state.has_rain() and state.well_fields.size() == 2, "Render the expanded farm during the actual rain term.")
	_expect(state.irrigation.supplies(Vector2i(4, 5)) and world.irrigation_overlay.footbridges.size() == 1,
		"The rainy estate keeps the connected inlet and its footbridge visible.")
	await _walk(Vector2(158, 141))
	await _snapshot("03-rain-and-second-field")
	await _walk(Vector2(360, 4))
	await _snapshot("04-east-road")
	await _move(&"ui_right")
	if not _expect(tree.current_scene.scene_file_path == state.WILDERNESS_SCENE,
			"The east road still leads to the bamboo ravine."):
		return
	await _move(&"ui_left")
	if not await _estate():
		return
	state.current_day = 22
	state.day_progress = 0.38
	tree.change_scene_to_file(state.ESTATE_SCENE)
	await tree.scene_changed
	if not await _estate():
		return
	_expect(state.season_index() == Global.Season.WINTER and state.well_fields.size() == 2,
		"The winter version keeps the expanded field layout.")
	await _walk(Vector2(109, 147))
	await _snapshot("05-winter-fields")
	await _walk(Vector2(112, -156))
	await _snapshot("06-winter-slope")
	print("TERRAIN_SEASONS rain_day=6 fields=", state.well_fields.size(), " winter_day=", state.current_day,
		" east_gate=true west_gate=true")

func _take_title_art() -> void:
	var plants := ["wheat", "beans", "millet", "hemp", "millet", "beans", "hemp", "beans", "wheat"]
	var items := tree.root.get_node("ItemManager")
	for index in plants.size():
		var cell := PUBLIC + Vector2i(index % 3 - 1, floori(index / 3.0) - 1)
		var crop: CropData = items.get_crop(plants[index])
		state.tilled_cells[cell] = true
		state.active_crops[cell] = {"id": plants[index], "data": crop, "age": 5,
			"growth_nights": 3, "watered": false, "requires_channel": false}
	world.restore_crops_visuals()
	ui.hide()
	for hint: Label in world.find_children("*", "Label", true, false):
		hint.hide()
	var player: Player = world.player
	player.position = Vector2(82, 140)
	var camera: Camera2D = player.camera
	camera.top_level = true
	camera.global_position = Vector2(-86, 100)
	camera.zoom = Vector2(2, 2)
	camera.reset_smoothing()
	camera.force_update_scroll()
	tree.paused = true
	var lighting: CanvasModulate = world.get_node("Landscape").day_lighting
	state.day_progress = 0.07
	lighting.refresh()
	await _snapshot("estate-morning")
	state.day_progress = 0.84
	lighting.refresh()
	await _snapshot("estate-dusk")
