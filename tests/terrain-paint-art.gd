extends SceneTree

var failed := false

func _initialize() -> void:
	review.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func review() -> void:
	var art = load("res://scripts/EstateTerrain.gd")
	var grass_prints: Array[int] = []
	for season in 4:
		var grass: Texture2D = art.meadow_texture(season)
		check(grass.get_size() == Vector2(160, 128), "Meadow material logical size")
		var fingerprint := hash(grass.get_image().get_data())
		check(fingerprint not in grass_prints, "Different grass in each season")
		grass_prints.append(fingerprint)
	check(art.TRACK_GRAIN.get_size() == Vector2(144, 112), "Packed clay scale")
	check(art.trail_texture().get_size() == Vector2(128, 96), "Woodland trail scale")
	check(art.STONE_GRAIN.get_size() == Vector2(72, 56), "Paving grain scale")
	check_sheet(load(art.VERGE), Vector2i(32, 20), Vector2i(3, 4), true)
	check_sheet(load(art.SNOWDRIFTS), Vector2i(128, 64), Vector2i(2, 2), false)

	var tiles := load("res://resources/game_tileset.tres") as TileSet
	check(tiles.tile_size == Vector2i(16, 16) and tiles.has_source(0), "Existing field grid")
	var atlas := tiles.get_source(0) as TileSetAtlasSource
	check(atlas.texture.get_size() == Vector2(64, 32) and atlas.get_tiles_count() == 8, "All field tiles fit the atlas")
	var soil := atlas.texture.get_image()
	var prints: Array[int] = []
	for row in 2:
		for column in 4:
			var cell := Vector2i(column, row)
			var data := atlas.get_tile_data(cell, 0)
			check(data.get_custom_data("is_public_field") == (column == 1), "Public/private field " + str(cell))
			var square := soil.get_region(Rect2i(cell * 16, Vector2i(16, 16)))
			var fingerprint := hash(square.get_data())
			check(fingerprint not in prints, "Distinct soil/ridge " + str(cell))
			prints.append(fingerprint)
		var gold := soil.get_pixel(16, row * 16)
		check(gold.r > 0.70 and gold.g > 0.55 and gold.g - gold.b > 0.2, "Gold public corner")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func check_sheet(texture: Texture2D, cell_size: Vector2i, grid: Vector2i, grounded: bool) -> void:
	check(texture.get_size() == Vector2(cell_size * grid), "Logical size of " + texture.resource_path)
	var sheet := texture.get_image()
	var prints: Array[int] = []
	for y in grid.y:
		for x in grid.x:
			var cell := sheet.get_region(Rect2i(Vector2i(x, y) * cell_size, cell_size))
			var art := cell.get_used_rect()
			check(art.has_area() and art.position.x > 0 and art.end.x < cell_size.x
				and art.end.y < cell_size.y, "Transparent margins in " + texture.resource_path)
			if grounded:
				check(absi(art.end.y - 17) <= 1, "Roadside plants share the same ground contact")
			var fingerprint := hash(cell.get_data())
			check(fingerprint not in prints, "Distinct illustration in " + texture.resource_path)
			prints.append(fingerprint)
