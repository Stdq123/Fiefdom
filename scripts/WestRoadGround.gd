extends Node2D

const LAYOUT := preload("res://scripts/WestRoadLayout.gd")
const MARKET_LAYOUT := preload("res://scripts/WestMarketLayout.gd")
const LANDSCAPE := preload("res://scripts/Landscape.gd")
const TERRAIN := preload("res://scripts/EstateTerrain.gd")
const STONE_PAVING := preload("res://scripts/StonePaving.gd")
const WATER_SURFACE := preload("res://scripts/WaterSurface.gd")
const ROAD_WEATHER := preload("res://scripts/RoadWeather.gd")
const RAVINE_RELIEF := preload("res://scripts/RavineRelief.gd")
const RAVINE_BANKS := preload("res://scripts/RavineBanks.gd")
const BACKDROP := Rect2(-800, -460, 1600, 960)
const ROAD_HALF_WIDTH := 20.0
const WATER_HALF_WIDTH := 23.0
const MEADOW_HALF_WIDTH := 7.0
const MARKET_SIGN := LAYOUT.MARKET_GATE + Vector2(16, -24)
const ESTATE_SIGN := LAYOUT.ESTATE_GATE + Vector2(-17, -25)
const MEADOW_SIGN := LAYOUT.MEADOW_JUNCTION + Vector2(33, 32)
const WILLOWS := [Vector3(36, -55, 0.72), Vector3(-73, 111, 0.81)]
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
	Vector3i(-62, -86, LANDSCAPE.Prop.MOSS_STONE), Vector3i(-43, -46, LANDSCAPE.Prop.REEDS),
	Vector3i(17, -58, LANDSCAPE.Prop.REEDS), Vector3i(29, 5, LANDSCAPE.Prop.BOULDER),
	Vector3i(16, 83, LANDSCAPE.Prop.REEDS), Vector3i(-44, 95, LANDSCAPE.Prop.REEDS),
	Vector3i(-66, 137, LANDSCAPE.Prop.MOSS_STONE), Vector3i(-14, 142, LANDSCAPE.Prop.REEDS),
	Vector3i(-155, 84, LANDSCAPE.Prop.SHRUB), Vector3i(-108, -47, LANDSCAPE.Prop.FLOWERS),
	Vector3i(173, 90, LANDSCAPE.Prop.FLOWERS), Vector3i(176, -24, LANDSCAPE.Prop.SHRUB),
	Vector3i(-290, -17, LANDSCAPE.Prop.FENCE), Vector3i(-316, -17, LANDSCAPE.Prop.FENCE),
	Vector3i(-298, 87, LANDSCAPE.Prop.FENCE), Vector3i(-324, 87, LANDSCAPE.Prop.FENCE),
	Vector3i(-78, -67, LANDSCAPE.Prop.FERN), Vector3i(42, -30, LANDSCAPE.Prop.FERN),
	Vector3i(-78, 93, LANDSCAPE.Prop.BANK_GRASS), Vector3i(36, 111, LANDSCAPE.Prop.PEBBLES),
	Vector3i(207, -12, LANDSCAPE.Prop.MOSS_STONE), Vector3i(244, 78, LANDSCAPE.Prop.PEBBLES),
	Vector3i(-214, 68, LANDSCAPE.Prop.PEBBLES),
]
const PAVING_LIMIT := [
	Vector2(-520, -20), Vector2(-146, -20), Vector2(-146, 23), Vector2(-153, 23),
	Vector2(-153, 32), Vector2(-146, 32), Vector2(-146, 40), Vector2(-161, 40),
	Vector2(-161, 47), Vector2(-153, 47), Vector2(-153, 54), Vector2(-169, 54),
	Vector2(-169, 92), Vector2(-520, 92),
]
const LOOSE_STONES := [Vector3(-152, 27, 5), Vector3(-144, 29, 4), Vector3(-153, 39, 7),
	Vector3(-137, 42, 4), Vector3(-147, 49, 5), Vector3(-157, 53, 6), Vector3(-142, 55, 3)]
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
var traveled_track := _material_outline(0.0)
var shoulder := _material_outline(3.0)
var meadow_lane := EstateLayout.sample_road(PackedVector2Array(LAYOUT.MEADOW_TRACK))
var meadow_track := _ribbon(meadow_lane, MEADOW_HALF_WIDTH)
var meadow_shoulder := _ribbon(meadow_lane, MEADOW_HALF_WIDTH + 2.0)
var bank_grass := _riverbed(WATER_HALF_WIDTH + 9.0, 2.8)
var bank_rim := _riverbed(WATER_HALF_WIDTH + 3.8, 1.5)
var water := _riverbed(WATER_HALF_WIDTH)
var shelf_edges: Array[PackedVector2Array] = []
var shelf_toes: Array[PackedVector2Array] = []
var shoal_edges: Array[PackedVector2Array] = []
var exposed_water := PackedVector2Array()
var deep_water := PackedVector2Array()
var apron_poses: Array[Transform2D] = []
var bridge_aprons: Array[PackedVector2Array] = []
var pavement := Geometry2D.intersect_polygons(track, PackedVector2Array(PAVING_LIMIT))[0]
var pavement_art := STONE_PAVING.new(
	Geometry2D.intersect_polygons(_material_outline(0.0, true), PackedVector2Array(PAVING_LIMIT))[0],
	LAYOUT.MARKET_GATE.x)
var weather := ROAD_WEATHER.new(RAIN_PUDDLES, SNOW_DRIFTS)

func _ready() -> void:
	_build_creek_banks()
	for side: float in [-1.0, 1.0]:
		var deck := LAYOUT.BRIDGE
		var sill := deck.get_center() + Vector2(side * deck.size.x * 0.5, 0.0)
		var pose := Transform2D(Vector2(side, -side * 0.09), Vector2(0, deck.size.y / 24.0), sill)
		apron_poses.append(pose)
		bridge_aprons.append(pose * PackedVector2Array(RAVINE_RELIEF.BRIDGE_APRON))
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
	var surface := WATER_SURFACE.new(exposed_water, 12.0, [LAYOUT.BRIDGE.grow(4.0)], true)
	surface.name = "WaterSurface"
	add_child(surface)
	surface.set_weather(LANDSCAPE.WATER_TINTS[Global.season_index()], Global.has_rain())
	weather.name = "RoadWeather"
	add_child(weather)

func _ribbon(path: PackedVector2Array, width: float) -> PackedVector2Array:
	return Geometry2D.offset_polyline(path, width, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0]

func _material_outline(margin: float, paving_lane := false) -> PackedVector2Array:
	var far := PackedVector2Array()
	var near := PackedVector2Array()
	var market_width: float = MARKET_LAYOUT.PAVING_HALF_WIDTH if paving_lane else MARKET_LAYOUT.STREET_HALF_WIDTH
	for index in road.size():
		var point := road[index]
		var before := road[maxi(0, index - 1)]
		var after := road[mini(road.size() - 1, index + 1)]
		var normal := before.direction_to(after).orthogonal()
		var market_blend := 1.0 - smoothstep(LAYOUT.MARKET_GATE.x + 19.0, LAYOUT.MARKET_GATE.x + 106.0, point.x)
		var estate_blend := smoothstep(LAYOUT.ESTATE_GATE.x - 94.0, LAYOUT.ESTATE_GATE.x - 16.0, point.x)
		var width := lerpf(ROAD_HALF_WIDTH, market_width, market_blend)
		width = lerpf(width, EstateLayout.ROAD_WIDTHS[0] * 0.5, estate_blend) + margin
		var wear := 1.0 - maxf(market_blend, estate_blend)
		far.append(point - normal * (width + sin(index * 0.56) * 0.95 * wear))
		near.append(point + normal * (width + cos(index * 0.41 + 0.8) * 1.22 * wear))
	near.reverse()
	return far + near

func _riverbed(width: float, roughness := 0.0) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for point: Vector2 in creek:
		var bank := sin(point.y * 0.042) * 2.7 + cos(point.y * 0.078) * 1.2
		var west := width + bank + sin(point.y * 0.088) * roughness
		var east := width - bank * 0.66 + cos(point.y * 0.103) * roughness
		left.append(point - Vector2(west, 0.0))
		right.append(point + Vector2(east, 0.0))
	right.reverse()
	return left + right

func _build_creek_banks() -> void:
	# The edge shared with the water collider is the top of each cut bank.
	for inward: float in [1.0, -1.0]:
		var edge := PackedVector2Array()
		var toes := PackedVector2Array()
		for index in creek.size():
			var rim := water[index if inward > 0.0 else water.size() - 1 - index]
			var from_deck := maxf(LAYOUT.BRIDGE.position.y - rim.y, rim.y - LAYOUT.BRIDGE.end.y)
			var cut := 12.0 + sin(rim.y * 0.074 + inward) * 3.1 + cos(rim.y * 0.11) * 1.6
			var depth := lerpf(1.5, cut, smoothstep(0.0, 22.0, from_deck))
			edge.append(rim)
			toes.append(rim + Vector2(inward * (1.5 + depth * 0.66), depth * 0.58))
		shelf_edges.append(edge)
		shelf_toes.append(toes)
	var east_return := shelf_toes[1].duplicate()
	east_return.reverse()
	exposed_water = shelf_toes[0] + east_return
	var west_deep := PackedVector2Array()
	var east_deep := PackedVector2Array()
	for index in creek.size():
		var left := shelf_toes[0][index]
		var right := shelf_toes[1][index]
		var drift := sin(left.y * 0.032) * 0.066
		west_deep.append(left.lerp(right, 0.22 + drift))
		east_deep.append(left.lerp(right, 0.78 + drift))
	shoal_edges = [west_deep, east_deep]
	var deep_return := east_deep.duplicate()
	deep_return.reverse()
	deep_water = west_deep + deep_return

func bridge_apron_at(foot: Vector2) -> bool:
	return bridge_aprons.any(func(apron: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(foot, apron))

func _draw_creek_bank(edge: PackedVector2Array, toes: PackedVector2Array, stone: Color, moss: Color) -> void:
	var upper := PackedVector2Array()
	for index in edge.size():
		var lip := edge[index]
		var split := 0.57 + sin(lip.y * 0.13) * 0.15 + cos(lip.y * 0.071) * 0.09
		upper.append(lip.lerp(toes[index], split))
	var lower := toes.duplicate()
	lower.reverse()
	var upper_return := upper.duplicate()
	upper_return.reverse()
	var strata := RAVINE_BANKS.ROCK_STRATA
	TERRAIN.draw_loam(self, edge + lower, stone.lerp(Color("#253d39"), 0.55), strata)
	TERRAIN.draw_loam(self, edge + upper_return, stone, strata)
	draw_polyline(toes, Color("#273e38b0"), 1.0)
	for index in range(2, edge.size() - 5, 4):
		var high := index + posmod(floori(index * 0.25), 3)
		var low := high + 2
		if edge[high].distance_to(toes[high]) < 5.0:
			continue
		var face := PackedVector2Array([edge[high].lerp(upper[high], 0.15), edge[high + 1],
			edge[low].lerp(upper[low], 0.55), upper[low].lerp(toes[low], 0.35),
			toes[high + 1].lerp(upper[high + 1], 0.22), upper[high]])
		if not Geometry2D.triangulate_polygon(face).is_empty():
			TERRAIN.draw_loam(self, face, stone.lightened(0.10 + 0.02 * posmod(index, 7)), strata)
		var seam := edge[high].lerp(edge[high + 1], 0.84)
		var cap := edge[high]
		var outside := Vector2(signf(cap.x - toes[high].x), 0)
		var growth := PackedVector2Array([cap + Vector2(0, -2), cap + outside * (3 + index % 4),
			seam + outside * 2.0, seam, cap.lerp(upper[high], 0.23)])
		if not Geometry2D.triangulate_polygon(growth).is_empty():
			TERRAIN.draw_loam(self, growth, moss.darkened(0.14), strata)
		draw_line(cap, cap.lerp(seam, 0.58), moss.lightened(0.07), 1.0)
		draw_line(edge[high].lerp(upper[high], 0.4), seam.lerp(upper[high + 1], 0.23), stone.lightened(0.16), 1.0)
		draw_polyline(PackedVector2Array([edge[low], upper[low].lerp(upper[low + 1], 0.22),
			toes[low]]), stone.darkened(0.23), 1.0)

func _draw_creek_water(season: int, rain: bool) -> void:
	var stream: Color = LANDSCAPE.WATER_TINTS[season]
	var deep := stream.lerp(Color("#254e58"), 0.55).darkened(0.13)
	var shallow := stream.lerp(Color("#8eac8a"), 0.54 if not rain else 0.36)
	var gravel := RAVINE_BANKS.STREAMBED
	TERRAIN.draw_loam(self, water, shallow, gravel)
	draw_colored_polygon(deep_water, deep)
	for side in shelf_toes.size():
		var margin := shelf_toes[side]
		var deep_edge := shoal_edges[side]
		var lit := shallow.darkened(0.10 * side)
		TERRAIN.draw_tiled_band(self, margin, deep_edge, lit, deep.lightened(0.05), gravel)
		for index in range(1 + side, margin.size() - 1, 3):
			var near := margin[index].lerp(deep_edge[index], 0.40)
			if LAYOUT.BRIDGE.grow(6.0).has_point(near):
				continue
			var along := margin[index + 1].lerp(deep_edge[index + 1], 0.43)
			var tint := Color(lit.lightened(0.33), 0.34 if rain else 0.50)
			draw_line(near.round(), near.lerp(along, 0.64).round(), tint, 1.0)

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
	var rain := Global.has_rain()
	if rain:
		grass = grass.lerp(Color("#304b46"), 0.28)
		loam = loam.darkened(0.17)
	TERRAIN.draw_grass(self, BACKDROP, season, rain)
	for grove: Rect2 in GROVES:
		var edge := PackedVector2Array()
		for point: Vector2 in GROVE_EDGE:
			edge.append((grove.position + grove.size * point).round())
		draw_colored_polygon(edge, Color(palette[1], 0.40))
	draw_colored_polygon(bank_grass, Color(palette[1], 0.38))
	draw_colored_polygon(bank_rim, Color(grass.lerp(Color("#8a9268"), 0.24), 0.54))
	var grain: Color = LANDSCAPE.LEAF_TINTS[season]
	if rain:
		grain *= Color(0.88, 0.94, 0.99)
	grain.a = 0.32 if winter else 0.83
	var litter := LANDSCAPE.ESTATE_LEAF_LITTER
	for index in TREES.size():
		var tree: Vector2 = TREES[index]
		draw_texture_rect_region(LANDSCAPE.ESTATE_ART, Rect2(tree - Vector2(30, 20), litter.size), litter, grain)
		if index % 3 != 0:
			TERRAIN.draw_sprig(self, tree + Vector2(-12 + index % 23, 3 + index % 9), index, season, rain)
	_draw_meadow(grass, loam, season)
	TERRAIN.draw_loam(self, shoulder, loam.lerp(grass, 0.56), TERRAIN.TRACK_GRAIN)
	TERRAIN.draw_verge(self, road, ROAD_HALF_WIDTH * 2.0, season, rain)
	TERRAIN.draw_loam(self, traveled_track, loam, TERRAIN.TRACK_GRAIN)
	pavement_art.draw(self, loam, winter, rain, MARKET_LAYOUT.STREET_STONE, TERRAIN.STONE_GRAIN)
	_draw_loose_stones(loam, winter, rain)
	_draw_creek_water(season, rain)
	var moss := Color("#a7bbb0") if winter else grass.lerp(Color("#9a9e58"), 0.67)
	var rock := Color("#908977").lerp(Color("#4c635e"), 0.37 if rain else 0.0)
	for index in shelf_edges.size():
		_draw_creek_bank(shelf_edges[index], shelf_toes[index], rock.darkened(0.13 if index == 0 else 0.0), moss)
	for index in bridge_aprons.size():
		RAVINE_RELIEF.draw_bridge_apron(self, bridge_aprons[index], apron_poses[index], season, rain, RAVINE_BANKS.ROCK_STRATA)
	var contact_shade := LANDSCAPE.scenery_shade(rain)
	for index in TREES.size():
		LANDSCAPE.draw_sorted_prop_shadow(self, TREES[index], _tree_variety(index), contact_shade, rain)
	for willow: Vector3 in WILLOWS:
		LANDSCAPE.draw_sorted_prop_shadow(self, Vector2(willow.x, willow.y), LANDSCAPE.Prop.WILLOW, contact_shade, rain)
	for prop: Vector3i in BANK_PROPS:
		LANDSCAPE.draw_sorted_prop_shadow(self, Vector2(prop.x, prop.y), prop.z, contact_shade, rain)
	for foot: Vector2 in [MARKET_SIGN, ESTATE_SIGN, MEADOW_SIGN]:
		draw_colored_polygon(PackedVector2Array([foot + Vector2(-7, 1), foot + Vector2(-3, -2),
			foot + Vector2(7, -1), foot + Vector2(14, 2), foot + Vector2(8, 4), foot + Vector2(-5, 3)]), contact_shade)

func _draw_loose_stones(loam: Color, winter: bool, rain: bool) -> void:
	var stone := loam.lerp(MARKET_LAYOUT.STREET_STONE, 0.53)
	if winter or rain:
		stone = stone.lerp(Color("#8d9a8e"), 0.38)
	for chip: Vector3 in LOOSE_STONES:
		var at := Vector2(chip.x, chip.y)
		draw_rect(Rect2(at + Vector2(1, 1), Vector2(chip.z, 2)), stone.darkened(0.30))
		draw_line(at, at + Vector2(chip.z - 1, 0), stone.lightened(0.14), 1.0)

func _tree_variety(index: int) -> int:
	if index % 4 == 2:
		return LANDSCAPE.Prop.PINE
	return LANDSCAPE.Prop.BLOSSOM_TREE if index % 3 == 1 else LANDSCAPE.Prop.OAK

func _draw_meadow(grass: Color, loam: Color, season: int) -> void:
	var shade: Color = [Color("#6c784e"), Color("#7c8b50"), Color("#958353"), Color("#89998b")][season]
	var edge := PackedVector2Array(LAYOUT.MEADOW_EDGE)
	var rain := Global.has_rain()
	# Let the meadow's grass show through the cut edge of the hay plot.
	draw_colored_polygon(edge, Color(grass.lerp(shade, 0.35), 0.35))
	TERRAIN.draw_verge(self, edge, 1.5, season, rain)
	TERRAIN.draw_loam(self, meadow_shoulder, loam.lerp(grass, 0.52), TERRAIN.TRACK_GRAIN)
	TERRAIN.draw_verge(self, meadow_lane, MEADOW_HALF_WIDTH * 2.0, season, rain)
	TERRAIN.draw_loam(self, meadow_track, loam, TERRAIN.trail_texture())

func place_scenery(layer: Node2D) -> void:
	var season := Global.season_index()
	var winter := season == Global.Season.WINTER
	var tree_art := {}
	for variety in [LANDSCAPE.Prop.OAK, LANDSCAPE.Prop.BLOSSOM_TREE, LANDSCAPE.Prop.PINE]:
		tree_art[variety] = LANDSCAPE.painted_tree_texture(variety, season)
	var forked_oak := LANDSCAPE.painted_tree_texture(LANDSCAPE.Prop.OAK, season, true)
	var wet_tint := Color(0.88, 0.94, 0.99) if Global.has_rain() else Color.WHITE
	for index in TREES.size():
		var variety := _tree_variety(index)
		var texture: AtlasTexture = forked_oak if variety == LANDSCAPE.Prop.OAK and index % 2 == 1 else tree_art[variety]
		_prop(layer, TREES[index], texture).self_modulate = wet_tint
	var willow := LANDSCAPE.painted_riverside_texture(LANDSCAPE.Prop.WILLOW, season)
	var plant_tint := LANDSCAPE.riverside_tint(season, Global.has_rain())
	for placement: Vector3 in WILLOWS:
		var tree := _prop(layer, Vector2(placement.x, placement.y), willow)
		tree.scale = Vector2.ONE * placement.z
		tree.self_modulate = plant_tint
	for mark: Vector3i in BANK_PROPS:
		if winter and mark.z == LANDSCAPE.Prop.FLOWERS:
			continue
		var riverside := LANDSCAPE.ESTATE_RIVER_REGIONS.has(mark.z)
		var texture := LANDSCAPE.painted_riverside_texture(mark.z, season) if riverside \
			else LANDSCAPE.atlas_texture(LANDSCAPE.ESTATE_ART, LANDSCAPE.ESTATE_SITE_REGIONS[mark.z])
		var sprite := _prop(layer, Vector2(mark.x, mark.y), texture)
		sprite.self_modulate = plant_tint if riverside else wet_tint
		if winter and mark.z in LANDSCAPE.ROCK_PROPS:
			sprite.self_modulate *= LANDSCAPE.WINTER_ROCK_TINT
	LANDSCAPE.place_waypost(layer, MARKET_SIGN, Vector2.LEFT, "西市", true).self_modulate = wet_tint
	LANDSCAPE.place_waypost(layer, ESTATE_SIGN, Vector2.RIGHT, "封地", true).self_modulate = wet_tint
	var meadow_heading: Vector2 = LAYOUT.MEADOW_TRACK[1] - LAYOUT.MEADOW_JUNCTION
	LANDSCAPE.place_waypost(layer, MEADOW_SIGN, meadow_heading, Sheepfold.MEADOW, true).self_modulate = wet_tint

func _prop(layer: Node2D, foot: Vector2, texture: AtlasTexture) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = Vector2(-texture.get_width() * 0.5, 3.0 - texture.get_height())
	sprite.position = foot
	layer.add_child(sprite)
	return sprite
