extends Node2D

const LANDSCAPE := preload("res://scripts/Landscape.gd")
const STREET := [
	Vector2(-183, 12), Vector2(-170, -11), Vector2(-148, -22), Vector2(-91, -19),
	Vector2(-51, -23), Vector2(26, -25), Vector2(74, -18), Vector2(138, -20),
	Vector2(169, -2), Vector2(196, 12), Vector2(231, 17), Vector2(422, 17),
	Vector2(422, 50), Vector2(226, 49), Vector2(190, 55), Vector2(145, 68),
	Vector2(87, 76), Vector2(5, 79), Vector2(-59, 76), Vector2(-82, 84),
	Vector2(-122, 85), Vector2(-145, 73),
	Vector2(-167, 54), Vector2(-188, 32),
]
const PAVEMENT := [
	Vector2(-170, 33), Vector2(-156, 20), Vector2(-124, 12), Vector2(-71, 10),
	Vector2(56, 11), Vector2(113, 13), Vector2(155, 19), Vector2(194, 23),
	Vector2(422, 23), Vector2(422, 45), Vector2(210, 45), Vector2(175, 52),
	Vector2(127, 60), Vector2(55, 63), Vector2(-38, 65), Vector2(-104, 62),
	Vector2(-144, 54), Vector2(-164, 43),
]
const GROVES := [
	Rect2(-320, -141, 154, 188), Rect2(-167, -156, 125, 81), Rect2(-26, -159, 155, 77),
	Rect2(139, -147, 194, 130), Rect2(-285, 82, 185, 113), Rect2(102, 101, 217, 99),
]
const GROVE_EDGE := [
	Vector2(0.02, 0.37), Vector2(0.13, 0.13), Vector2(0.32, 0.04), Vector2(0.56, 0.12),
	Vector2(0.75, 0.03), Vector2(0.91, 0.19), Vector2(1, 0.43), Vector2(0.94, 0.72),
	Vector2(0.81, 0.89), Vector2(0.60, 0.95), Vector2(0.36, 0.85), Vector2(0.15, 0.96),
	Vector2(0.05, 0.77), Vector2(0, 0.56),
]
const TREE_FEET := [
	Vector2(-229, -88), Vector2(-191, -49), Vector2(-168, -91), Vector2(-124, -87),
	Vector2(-72, -103), Vector2(-30, -82), Vector2(24, -96), Vector2(65, -81),
	Vector2(104, -101), Vector2(152, -71), Vector2(195, -49), Vector2(244, -37),
	Vector2(-241, 9), Vector2(-211, 56), Vector2(-156, 104), Vector2(-214, 129),
	Vector2(-116, 145), Vector2(-48, 156), Vector2(88, 146), Vector2(144, 112),
	Vector2(205, 106), Vector2(260, 76), Vector2(268, 135),
]
const STORAGE := [
	Vector3i(-161, 0, 0), Vector3i(-151, 4, 1), Vector3i(-168, 9, 0),
	Vector3i(-50, 2, 3), Vector3i(48, 1, 2), Vector3i(153, 13, 3),
	Vector3i(162, 18, 2), Vector3i(-91, 104, 3),
]
const STORAGE_PROPS := [LANDSCAPE.Prop.GRAIN_SACK, LANDSCAPE.Prop.OPEN_SACK, LANDSCAPE.Prop.JAR, LANDSCAPE.Prop.LIDDED_JAR]
const FENCE_FEET := [Vector2(-192, -23), Vector2(-177, 71), Vector2(183, -18), Vector2(241, 65)]
const PROP_DETAILS := [
	Vector3i(-124, 98, LANDSCAPE.Prop.LOGS), Vector3i(122, 96, LANDSCAPE.Prop.LOGS),
	Vector3i(-171, 83, LANDSCAPE.Prop.FLOWERS), Vector3i(97, 90, LANDSCAPE.Prop.FLOWERS),
	Vector3i(169, 88, LANDSCAPE.Prop.SHRUB), Vector3i(-208, -21, LANDSCAPE.Prop.ROCK),
]
const BACKDROP := Rect2(-1600, -1300, 3200, 2600)

var street := PackedVector2Array(STREET)
var paving := PackedVector2Array(PAVEMENT)

func is_on_street(foot: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(foot), street)

func is_on_paving(foot: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(foot), paving)

func _draw() -> void:
	var palette: Array = LANDSCAPE.SEASON_PALETTES[Global.season_index()]
	var meadow: Color = palette[0]
	var shade: Color = palette[1]
	var dirt: Color = palette[3]
	if Global.has_rain():
		meadow = meadow.lerp(Color("#344c4c"), 0.30)
		dirt = dirt.darkened(0.16)
	draw_rect(BACKDROP, meadow)
	for grove: Rect2 in GROVES:
		var edge := PackedVector2Array()
		for point: Vector2 in GROVE_EDGE:
			edge.append((grove.position + grove.size * point).round())
		draw_colored_polygon(edge, meadow.lerp(shade, 0.48))
	draw_texture_rect(LANDSCAPE.GRAIN, BACKDROP, true, Color(1.0, 1.0, 1.0, 0.75))
	for foot: Vector2 in TREE_FEET:
		draw_rect(Rect2(foot - Vector2(14, 1), Vector2(30, 4)), meadow.lerp(shade, 0.72))
	draw_set_transform(Vector2(0, 3))
	draw_colored_polygon(street, dirt.lerp(meadow, 0.48))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(street, dirt)
	_draw_paving(dirt)

func _draw_paving(dirt: Color) -> void:
	var grout := dirt.lerp(Color("#606357"), 0.58)
	draw_colored_polygon(paving, grout)
	for row in 7:
		for column in 41:
			var x := -175 + column * 15 + (row % 2) * 7
			var y := 10 + row * 8
			var grain := posmod(column * 7 + row * 17, 13)
			var slab := Rect2(x, y, 13 + grain % 2, 6)
			var corners := [slab.position, Vector2(slab.end.x, slab.position.y),
				slab.end, Vector2(slab.position.x, slab.end.y)]
			if not corners.all(func(corner: Vector2) -> bool: return Geometry2D.is_point_in_polygon(corner, paving)):
				continue
			var stone := grout.lerp(Color("#a6a48a"), 0.37 + 0.025 * grain)
			draw_rect(slab, stone.darkened(0.14))
			draw_rect(Rect2(slab.position, slab.size - Vector2(1, 2)), stone)
			draw_rect(Rect2(slab.position + Vector2(1, 1), Vector2(4 + grain % 5, 1)), stone.lightened(0.13))
	for mark in 73:
		var foot := Vector2(-198 + posmod(mark * 97, 491), -16 + posmod(mark * 37, 96))
		if Geometry2D.is_point_in_polygon(foot, street) and not Geometry2D.is_point_in_polygon(foot, paving):
			draw_rect(Rect2(foot, Vector2(1 + mark % 4, 1)), dirt.lightened(0.16) if mark % 2 == 0 else dirt.darkened(0.10))

func place_scenery(layer: Node2D) -> void:
	var season := Global.season_index()
	var pine_sheet := LANDSCAPE.SEASONAL_TREES if season == Global.Season.WINTER else LANDSCAPE.SCENERY
	var pine_region := Rect2(96, 48, 48, 48) if season == Global.Season.WINTER else Rect2(144, 0, 48, 48)
	for index in TREE_FEET.size():
		var frame: Vector2 = LANDSCAPE.ORCHARD_FRAMES[season] if index % 4 == 1 else Vector2(season, 0)
		if index % 4 == 2:
			_prop(layer, TREE_FEET[index], pine_sheet, pine_region, 45.0)
		else:
			_prop(layer, TREE_FEET[index], LANDSCAPE.SEASONAL_TREES, Rect2(frame * 48.0, Vector2(48, 48)), 45.0)
	for foot: Vector2 in FENCE_FEET:
		_prop(layer, foot, LANDSCAPE.SCENERY, Rect2(336, 48, 48, 48), 45.0)
	for detail: Vector3i in PROP_DETAILS:
		var frame := Vector2i(detail.z % 8, floori(float(detail.z) / 8.0))
		_prop(layer, Vector2(detail.x, detail.y), LANDSCAPE.SCENERY, Rect2(Vector2(frame * 48), Vector2(48, 48)), 45.0)
	for jar: Vector3i in STORAGE:
		var tint: Color = LANDSCAPE.STORAGE_TINTS[STORAGE_PROPS[jar.z]]
		_prop(layer, Vector2(jar.x, jar.y), LANDSCAPE.ESTATE_STORAGE, Rect2(jar.z * 16, 0, 16, 16), 14.0, tint)
	_prop(layer, Vector2(230, 11), LANDSCAPE.ESTATE_BUILDINGS, LANDSCAPE.BUILDING_REGIONS[LANDSCAPE.Prop.GATE_FAR], 44.0)
	_prop(layer, Vector2(207, 57), LANDSCAPE.ESTATE_BUILDINGS, LANDSCAPE.BUILDING_REGIONS[LANDSCAPE.Prop.GATE], 44.0)

func _prop(layer: Node2D, foot: Vector2, sheet: Texture2D, region: Rect2, baseline: float, tint := Color.WHITE) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = region
	texture.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.position = foot
	sprite.offset = Vector2(-region.size.x * 0.5, -baseline)
	sprite.self_modulate = tint
	layer.add_child(sprite)
