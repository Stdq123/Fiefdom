extends Node2D

const LAYOUT := preload("res://scripts/WestRoadLayout.gd")
const LANDSCAPE := preload("res://scripts/Landscape.gd")
const TERRAIN := preload("res://scripts/EstateTerrain.gd")
const WATER_SURFACE := preload("res://scripts/WaterSurface.gd")
const ROAD_WEATHER := preload("res://scripts/RoadWeather.gd")
const BACKDROP := Rect2(-800, -460, 1600, 960)
const ROAD_HALF_WIDTH := 20.0
const WATER_HALF_WIDTH := 23.0
const MEADOW_HALF_WIDTH := 7.0
const GROVES := [
	Rect2(-440, -174, 299, 130), Rect2(-394, 111, 277, 146),
	Rect2(47, -174, 392, 130), Rect2(76, 96, 370, 157),
]
const GROVE_EDGE := [
	Vector2(0.02, 0.27), Vector2(0.16, 0.12), Vector2(0.34, 0.19), Vector2(0.48, 0.03),
	Vector2(0.77, 0.12), Vector2(0.93, 0.21), Vector2(0.98, 0.52), Vector2(0.91, 0.69),
	Vector2(0.79, 0.72), Vector2(0.63, 0.91), Vector2(0.43, 0.85), Vector2(0.27, 0.97),
	Vector2(0.1, 0.83), Vector2(0.01, 0.59),
]
const TREES := [
	Vector2(-313, -66), Vector2(-269, -51), Vector2(-229, -73), Vector2(-178, -95),
	Vector2(-212, 127), Vector2(-147, 144), Vector2(-245, 162), Vector2(-314, 125),
	Vector2(61, -98), Vector2(119, -104), Vector2(159, -61), Vector2(209, -84),
	Vector2(269, -47), Vector2(315, -82), Vector2(73, 120), Vector2(102, 159),
	Vector2(231, 111), Vector2(269, 144), Vector2(320, 119),
]
const BANK_PROPS := [
	Vector3i(-62, -86, LANDSCAPE.Prop.ROCK), Vector3i(-43, -46, LANDSCAPE.Prop.REEDS),
	Vector3i(17, -58, LANDSCAPE.Prop.REEDS), Vector3i(29, 5, LANDSCAPE.Prop.ROCK),
	Vector3i(16, 83, LANDSCAPE.Prop.REEDS), Vector3i(-44, 95, LANDSCAPE.Prop.REEDS),
	Vector3i(-66, 137, LANDSCAPE.Prop.ROCK), Vector3i(-14, 142, LANDSCAPE.Prop.REEDS),
	Vector3i(-155, 84, LANDSCAPE.Prop.SHRUB), Vector3i(-108, -47, LANDSCAPE.Prop.FLOWERS),
	Vector3i(137, 73, LANDSCAPE.Prop.FLOWERS), Vector3i(176, -24, LANDSCAPE.Prop.SHRUB),
	Vector3i(-290, -17, LANDSCAPE.Prop.FENCE), Vector3i(-316, -17, LANDSCAPE.Prop.FENCE),
	Vector3i(-298, 87, LANDSCAPE.Prop.FENCE), Vector3i(-324, 87, LANDSCAPE.Prop.FENCE),
	Vector3i(-242, 12, LANDSCAPE.Prop.SIGNPOST), Vector3i(241, 11, LANDSCAPE.Prop.SIGNPOST),
]
const PAVING_LIMIT := [
	Vector2(-520, -20), Vector2(-146, -20), Vector2(-146, 23), Vector2(-153, 23),
	Vector2(-153, 32), Vector2(-146, 32), Vector2(-146, 40), Vector2(-161, 40),
	Vector2(-161, 47), Vector2(-153, 47), Vector2(-153, 54), Vector2(-169, 54),
	Vector2(-169, 92), Vector2(-520, 92),
]
const RAIN_PUDDLES: Array[Rect2] = [
	Rect2(68, 27, 36, 15), Rect2(-112, 36, 40, 14), Rect2(-218, 32, 31, 13),
	Rect2(118, 63, 24, 9),
]
const SNOW_DRIFTS: Array[Rect2] = [
	Rect2(66, 0, 76, 30), Rect2(85, 44, 74, 28), Rect2(185, 3, 66, 22),
	Rect2(-130, 44, 70, 26), Rect2(-193, 10, 63, 17), Rect2(-256, 44, 62, 15),
	Rect2(145, 107, 53, 17), Rect2(184, 138, 22, 10),
]

var road := EstateLayout.sample_road(PackedVector2Array(LAYOUT.ROAD))
var creek := EstateLayout.sample_road(PackedVector2Array(LAYOUT.CREEK))
var track := _ribbon(road, ROAD_HALF_WIDTH)
var shoulder := _ribbon(road, ROAD_HALF_WIDTH + 3.0)
var meadow_lane := EstateLayout.sample_road(PackedVector2Array(LAYOUT.MEADOW_TRACK))
var meadow_track := _ribbon(meadow_lane, MEADOW_HALF_WIDTH)
var meadow_shoulder := _ribbon(meadow_lane, MEADOW_HALF_WIDTH + 2.0)
var banks := _riverbed(WATER_HALF_WIDTH + 9.0)
var shallows := _riverbed(WATER_HALF_WIDTH + 4.0)
var water := _riverbed(WATER_HALF_WIDTH)
var deep_water := _riverbed(14.0)
var pavement := Geometry2D.intersect_polygons(track, PackedVector2Array(PAVING_LIMIT))[0]
var meadow := TERRAIN.new(LAYOUT.BOUNDS.position.y)
var weather := ROAD_WEATHER.new(RAIN_PUDDLES, SNOW_DRIFTS)

func _ready() -> void:
	var channel := StaticBody2D.new()
	channel.collision_mask = 0
	for pool: PackedVector2Array in Geometry2D.clip_polygons(water, EstateLayout.corners(LAYOUT.BRIDGE)):
		var collider := CollisionPolygon2D.new()
		collider.polygon = pool
		channel.add_child(collider)
	for y: float in [LAYOUT.BRIDGE.position.y, LAYOUT.BRIDGE.end.y - 1.0]:
		var rail := CollisionPolygon2D.new()
		rail.polygon = EstateLayout.corners(Rect2(LAYOUT.BRIDGE.position.x, y, LAYOUT.BRIDGE.size.x, 2.0))
		channel.add_child(rail)
	add_child(channel)
	var surface := WATER_SURFACE.new(water, 12.0, [LAYOUT.BRIDGE.grow(4.0)])
	surface.name = "WaterSurface"
	add_child(surface)
	surface.set_weather(LANDSCAPE.WATER_TINTS[Global.season_index()], Global.has_rain())
	weather.name = "RoadWeather"
	add_child(weather)

func _ribbon(path: PackedVector2Array, width: float) -> PackedVector2Array:
	return Geometry2D.offset_polyline(path, width, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0]

func _riverbed(width: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for point: Vector2 in creek:
		var bank := sin(point.y * 0.042) * 2.7 + cos(point.y * 0.078) * 1.2
		left.append(point - Vector2(width + bank, 0.0))
		right.append(point + Vector2(width - bank * 0.66, 0.0))
	right.reverse()
	return left + right

func creek_distance(foot: Vector2) -> float:
	var nearest := INF
	for index in range(1, creek.size()):
		var at := Geometry2D.get_closest_point_to_segment(foot, creek[index - 1], creek[index])
		nearest = minf(nearest, at.distance_squared_to(foot))
	return sqrt(nearest)

func _draw() -> void:
	var season := Global.season_index()
	var palette: Array = LANDSCAPE.SEASON_PALETTES[season]
	var grass: Color = palette[0]
	var loam: Color = palette[3]
	var winter := season == Global.Season.WINTER
	if Global.has_rain():
		grass = grass.lerp(Color("#304b46"), 0.28)
		loam = loam.darkened(0.15)
	draw_rect(BACKDROP, grass)
	for grove: Rect2 in GROVES:
		var edge := PackedVector2Array()
		for point: Vector2 in GROVE_EDGE:
			edge.append((grove.position + grove.size * point).round())
		draw_colored_polygon(edge, grass.lerp(palette[1], 0.67))
	meadow.draw_meadow(self, grass, winter)
	draw_texture_rect(LANDSCAPE.GRAIN, BACKDROP, true, Color(1.0, 1.0, 1.0, 0.62))
	_draw_meadow(grass, loam, season)
	meadow.draw_verge(self, road, ROAD_HALF_WIDTH * 2.0, grass, winter)
	draw_colored_polygon(shoulder, loam.lerp(grass, 0.54))
	TERRAIN.draw_loam(self, track, loam)
	TERRAIN.draw_paving(self, pavement, loam, LAYOUT.MARKET_GATE.x)
	var stream_color: Color = LANDSCAPE.WATER_TINTS[season]
	var silt := grass.lerp(Color("#a5a085"), 0.58)
	draw_colored_polygon(banks, silt.darkened(0.13))
	draw_colored_polygon(shallows, silt)
	draw_colored_polygon(water, stream_color.lerp(Color("#89a58b"), 0.41))
	draw_colored_polygon(deep_water, stream_color.darkened(0.16))
	WATER_SURFACE.draw_shore(self, water, silt, stream_color, winter, [LAYOUT.BRIDGE.grow(8.0)])

func _draw_meadow(grass: Color, loam: Color, season: int) -> void:
	var shade: Color = [Color("#6c784e"), Color("#7c8b50"), Color("#958353"), Color("#89998b")][season]
	var edge := PackedVector2Array(LAYOUT.MEADOW_EDGE)
	var winter := season == Global.Season.WINTER
	TERRAIN.draw_loam(self, edge, grass.lerp(shade, 0.35))
	meadow.draw_verge(self, edge, 1.5, grass.lerp(shade, 0.28), winter)
	meadow.draw_verge(self, meadow_lane, MEADOW_HALF_WIDTH * 2.0, grass, winter)
	draw_colored_polygon(meadow_shoulder, loam.lerp(grass, 0.52))
	TERRAIN.draw_loam(self, meadow_track, loam)

func place_scenery(layer: Node2D) -> void:
	var season := Global.season_index()
	var winter := season == Global.Season.WINTER
	for index in TREES.size():
		var frame: Vector2 = LANDSCAPE.ORCHARD_FRAMES[season] if index % 3 == 1 else Vector2(season, 0)
		if index % 4 == 2:
			var pine_sheet: Texture2D = LANDSCAPE.SEASONAL_TREES if winter else LANDSCAPE.SCENERY
			var pine_frame := Vector2(96, 48) if winter else Vector2(144, 0)
			_prop(layer, TREES[index], pine_sheet, Rect2(pine_frame, Vector2(48, 48)))
		else:
			_prop(layer, TREES[index], LANDSCAPE.SEASONAL_TREES, Rect2(frame * 48.0, Vector2(48, 48)))
	var willow_sheet: Texture2D = LANDSCAPE.WINTER_WILLOW if winter else LANDSCAPE.ACTG_SCENERY
	var willow_region: Rect2 = Rect2(Vector2.ZERO, willow_sheet.get_size()) if winter else LANDSCAPE.EXTERNAL_REGIONS[LANDSCAPE.Prop.WILLOW]
	_prop(layer, Vector2(36, -55), willow_sheet, willow_region).scale = Vector2.ONE * 0.72
	_prop(layer, Vector2(-73, 111), willow_sheet, willow_region).scale = Vector2.ONE * 0.81
	for mark: Vector3i in BANK_PROPS:
		if winter and mark.z == LANDSCAPE.Prop.FLOWERS:
			continue
		var frame := Vector2(mark.z % 8, floori(mark.z / 8.0))
		var sprite := _prop(layer, Vector2(mark.x, mark.y), LANDSCAPE.SCENERY, Rect2(frame * 48.0, Vector2(48, 48)))
		sprite.flip_h = mark.z == LANDSCAPE.Prop.SIGNPOST and mark.x < 0

func _prop(layer: Node2D, foot: Vector2, sheet: Texture2D, region: Rect2) -> Sprite2D:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = region
	texture.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = Vector2(-region.size.x * 0.5, 3.0 - region.size.y)
	sprite.position = foot
	layer.add_child(sprite)
	return sprite
