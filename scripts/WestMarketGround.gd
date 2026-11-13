extends Node2D

const LANDSCAPE := preload("res://scripts/Landscape.gd")
const LAYOUT := preload("res://scripts/WestMarketLayout.gd")
const TERRAIN := preload("res://scripts/EstateTerrain.gd")
const WATER_SURFACE := preload("res://scripts/WaterSurface.gd")
const ROAD_WEATHER := preload("res://scripts/RoadWeather.gd")
const BACKDROP := Rect2(-1600, -1300, 3200, 2600)
const GRAIN_YARD := [
	Vector2(-395, 116), Vector2(-364, 103), Vector2(-309, 108), Vector2(-260, 121),
	Vector2(-205, 117), Vector2(-196, 153), Vector2(-207, 188), Vector2(-248, 200),
	Vector2(-311, 195), Vector2(-364, 183), Vector2(-389, 163),
]
const FISH_YARD := [
	Vector2(-263, -134), Vector2(-239, -158), Vector2(-179, -154), Vector2(-145, -131),
	Vector2(-111, -97), Vector2(-137, -82), Vector2(-187, -89), Vector2(-229, -94), Vector2(-261, -110),
]
const SILK_YARD := [
	Vector2(126, 165), Vector2(152, 148), Vector2(208, 148), Vector2(250, 155), Vector2(265, 176),
	Vector2(245, 194), Vector2(180, 200), Vector2(140, 190),
]
const GROVES := [
	Rect2(-505, -225, 166, 457), Rect2(-349, -233, 283, 65), Rect2(-48, -238, 244, 126),
	Rect2(264, -222, 238, 205), Rect2(-327, -65, 206, 148), Rect2(-3, -62, 151, 100),
	Rect2(-494, 211, 610, 78), Rect2(28, 133, 239, 130), Rect2(274, 85, 230, 150),
]
const GROVE_EDGE := [
	Vector2(0.02, 0.37), Vector2(0.13, 0.13), Vector2(0.32, 0.04), Vector2(0.56, 0.12),
	Vector2(0.75, 0.03), Vector2(0.91, 0.19), Vector2(1, 0.43), Vector2(0.94, 0.72),
	Vector2(0.81, 0.89), Vector2(0.60, 0.95), Vector2(0.36, 0.85), Vector2(0.15, 0.96),
	Vector2(0.05, 0.77), Vector2(0, 0.56),
]
const TREE_FEET := [
	Vector2(-436, -153), Vector2(-382, -137), Vector2(-410, -94), Vector2(-371, -45),
	Vector2(-443, -24), Vector2(-412, 29), Vector2(-442, 76), Vector2(-411, 124), Vector2(-445, 171),
	Vector2(-371, -173), Vector2(-309, -153), Vector2(-283, -173), Vector2(-221, -173), Vector2(-157, -177),
	Vector2(-95, -147), Vector2(-40, -156), Vector2(12, -129), Vector2(70, -162), Vector2(129, -143),
	Vector2(205, -151), Vector2(260, -148), Vector2(287, -113), Vector2(341, -135),
	Vector2(390, -103), Vector2(442, -119), Vector2(421, -58), Vector2(345, -45), Vector2(303, -25),
	Vector2(-327, -27), Vector2(-282, -11), Vector2(-244, -33), Vector2(-195, -8), Vector2(-165, 20),
	Vector2(7, -25), Vector2(49, -38), Vector2(86, -10), Vector2(36, 15),
	Vector2(-400, 215), Vector2(-346, 226), Vector2(-295, 235), Vector2(-198, 222), Vector2(-151, 202),
	Vector2(-99, 228), Vector2(-57, 197), Vector2(-12, 219), Vector2(44, 176), Vector2(106, 191),
	Vector2(108, 140), Vector2(185, 220), Vector2(258, 220), Vector2(299, 132),
	Vector2(348, 164), Vector2(383, 116), Vector2(426, 144), Vector2(448, 91),
]
const STORAGE := [
	Vector3i(-381, 97, 0), Vector3i(-370, 103, 1), Vector3i(-390, 108, 0), Vector3i(-218, 194, 3),
	Vector3i(-178, -101, 2), Vector3i(-267, -112, 2), Vector3i(-259, -103, 3),
	Vector3i(130, 154, 3), Vector3i(133, 165, 2), Vector3i(256, 175, 3),
]
const STORAGE_PROPS := [LANDSCAPE.Prop.GRAIN_SACK, LANDSCAPE.Prop.OPEN_SACK, LANDSCAPE.Prop.JAR, LANDSCAPE.Prop.LIDDED_JAR]
const FENCE_FEET := [
	Vector2(-384, 164), Vector2(-353, 184), Vector2(-319, 195), Vector2(-243, -153),
	Vector2(137, 145), Vector2(217, 149), Vector2(333, -5), Vector2(429, 67),
]
const PROP_DETAILS := [
	Vector3i(-377, 190, LANDSCAPE.Prop.LOGS), Vector3i(-211, 98, LANDSCAPE.Prop.LOGS),
	Vector3i(-147, 114, LANDSCAPE.Prop.FLOWERS), Vector3i(-143, -39, LANDSCAPE.Prop.FLOWERS),
	Vector3i(-255, -152, LANDSCAPE.Prop.REEDS), Vector3i(-190, -150, LANDSCAPE.Prop.REEDS),
	Vector3i(77, -28, LANDSCAPE.Prop.SHRUB), Vector3i(84, 37, LANDSCAPE.Prop.FLOWERS),
	Vector3i(206, 108, LANDSCAPE.Prop.ROCK), Vector3i(290, 77, LANDSCAPE.Prop.FLOWERS),
	Vector3i(324, -14, LANDSCAPE.Prop.SHRUB), Vector3i(369, 80, LANDSCAPE.Prop.ROCK),
]
const RAIN_PUDDLES: Array[Rect2] = [
	Rect2(278, 29, 38, 14), Rect2(-56, 53, 34, 15), Rect2(-159, -112, 42, 20),
	Rect2(232, 126, 23, 14), Rect2(-252, 149, 38, 12),
]
const SNOW_DRIFTS: Array[Rect2] = [
	Rect2(277, 45, 64, 24), Rect2(304, -1, 63, 24), Rect2(144, 86, 57, 25),
	Rect2(-2, 82, 71, 22), Rect2(-176, -104, 54, 20), Rect2(-261, -99, 57, 19),
	Rect2(-109, -74, 45, 26), Rect2(-370, 158, 73, 22), Rect2(-255, 175, 38, 15),
	Rect2(218, 177, 43, 19), Rect2(230, 117, 29, 21),
]

var street: Array[PackedVector2Array] = []
var street_shoulders: Array[PackedVector2Array] = []
var paving: PackedVector2Array
var main_path: PackedVector2Array
var verge_art := TERRAIN.new(LAYOUT.BOUNDS.position.y)
var weather := ROAD_WEATHER.new(RAIN_PUDDLES, SNOW_DRIFTS)

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	main_path = EstateLayout.sample_road(PackedVector2Array(LAYOUT.MAIN_ROAD + [LAYOUT.EAST_OUTSIDE]))
	paving = _road_outline(main_path, 12.0)
	street.append(_road_outline(main_path, 22.0))
	for lane: Array in [LAYOUT.FISH_LANE, LAYOUT.SILK_LANE, LAYOUT.CART_DRIVE]:
		street.append(_road_outline(EstateLayout.sample_road(PackedVector2Array(lane)), 14.0))
	for yard: Array in [GRAIN_YARD, FISH_YARD, SILK_YARD]:
		street.append(PackedVector2Array(yard))
	for surface in street:
		street_shoulders.append(Geometry2D.offset_polygon(surface, 2.0)[0])

	var basin := StaticBody2D.new()
	basin.position = LAYOUT.BASIN.get_center()
	basin.collision_mask = 0
	var collider := CollisionShape2D.new()
	var rim := RectangleShape2D.new()
	rim.size = LAYOUT.BASIN.size
	collider.shape = rim
	basin.add_child(collider)
	add_child(basin)
	var surface := WATER_SURFACE.new(EstateLayout.corners(LAYOUT.BASIN.grow(-5.0)), 0.0)
	surface.name = "BasinWater"
	add_child(surface)
	surface.set_weather(Color("#527d79"), Global.has_rain())
	weather.name = "RoadWeather"
	add_child(weather)

func _road_outline(points: PackedVector2Array, radius: float) -> PackedVector2Array:
	return Geometry2D.offset_polyline(points, radius, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0]

func is_on_street(foot: Vector2) -> bool:
	var at := to_local(foot)
	for surface in street:
		if Geometry2D.is_point_in_polygon(at, surface):
			return true
	return false

func is_on_paving(foot: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(foot), paving)

func distance_to_trees(foot: Vector2) -> float:
	var at := to_local(foot)
	var nearest := INF
	for tree: Vector2 in TREE_FEET:
		nearest = minf(nearest, at.distance_squared_to(tree))
	return sqrt(nearest)

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
	verge_art.draw_verge(self, main_path, 44.0, meadow, Global.season_index() == Global.Season.WINTER)
	for shoulder in street_shoulders:
		draw_colored_polygon(shoulder, dirt.lerp(meadow, 0.52))
	for surface in street:
		TERRAIN.draw_loam(self, surface, dirt)
	TERRAIN.draw_paving(self, paving, dirt, LAYOUT.EAST_GATE.x)
	_draw_basin()

func _draw_basin() -> void:
	var rim := LAYOUT.BASIN
	draw_rect(Rect2(rim.position + Vector2(1, 3), rim.size + Vector2(1, 1)), Color("#5a5949"))
	draw_rect(rim, Color("#9d9b80"))
	draw_rect(rim.grow(-3.0), Color("#414f49"))
	var water := rim.grow(-5.0)
	draw_rect(water, Color("#527d79"))
	draw_rect(Rect2(water.position, Vector2(water.size.x, 5)), Color("#476663"))
	for step in 5:
		var x := rim.position.x + 5 + step * 10
		draw_rect(Rect2(x, rim.end.y - 2, 8, 1), Color("#c3bfa4"))

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
	_prop(layer, LAYOUT.EAST_GATE + Vector2(9, -23), LANDSCAPE.ESTATE_BUILDINGS, LANDSCAPE.BUILDING_REGIONS[LANDSCAPE.Prop.GATE_FAR], 44.0)
	_prop(layer, LAYOUT.EAST_GATE + Vector2(-14, 23), LANDSCAPE.ESTATE_BUILDINGS, LANDSCAPE.BUILDING_REGIONS[LANDSCAPE.Prop.GATE], 44.0)

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
