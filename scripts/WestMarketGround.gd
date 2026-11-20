extends Node2D

const LANDSCAPE := preload("res://scripts/Landscape.gd")
const LAYOUT := preload("res://scripts/WestMarketLayout.gd")
const TERRAIN := preload("res://scripts/EstateTerrain.gd")
const STONE_PAVING := preload("res://scripts/StonePaving.gd")
const YARD_DISPLAY := preload("res://scripts/MarketYardDisplay.gd")
const DYE_VAT := preload("res://scripts/MarketDyeVat.gd")
const WATER_SURFACE := preload("res://scripts/WaterSurface.gd")
const ROAD_WEATHER := preload("res://scripts/RoadWeather.gd")
const FOLIAGE_WIND := preload("res://scripts/FoliageWind.gd")
const FIXTURE_ART := preload("res://assets/world/west-market-fixtures.png")
const BACKDROP := Rect2(-1600, -1300, 3200, 2600)
const BASIN_INNER := Rect2(LAYOUT.BASIN.position + Vector2(6, 6), LAYOUT.BASIN.size - Vector2(12, 12))
const BASIN_ART := "res://assets/world/stillwater-stone.png"
const SWIMMERS := "res://assets/world/market-pool-fish.png"
const FISH_CELL := 16
const TAIL_FRAMES := 8
const BASIN_DRAW := Rect2(LAYOUT.BASIN.position - Vector2(5, 4), Vector2(70, 46))
const BASIN_BACK := Rect2(37, 1, 70, 32)
const BASIN_FRONT := Rect2(37, 33, 70, 14)
const BASIN_MASK := Rect2(110, 1, 70, 46)
const CRATES := Rect2(32, 64, 30, 28)
const CRATE_FEET := [Vector2(-306, 99), Vector2(343, -3)]
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
const DYE_YARD := [
	Vector2(213, -22), Vector2(253, -27), Vector2(301, -26), Vector2(340, -16),
	Vector2(355, -3), Vector2(351, 13), Vector2(324, 23), Vector2(284, 27),
	Vector2(249, 21), Vector2(223, 17), Vector2(210, 4),
]
const DYE_APRON := [
	Vector2(218, -21), Vector2(241, -24), Vector2(284, -24), Vector2(315, -17),
	Vector2(340, -13), Vector2(349, -5), Vector2(349, 6), Vector2(337, 17), Vector2(310, 22),
	Vector2(286, 23), Vector2(255, 17), Vector2(231, 16), Vector2(216, 7), Vector2(214, -6),
]
const STALL_PAVING := [
	[Vector2(-43, -26), Vector2(31, -26), Vector2(37, -18), Vector2(37, 2),
		Vector2(21, 10), Vector2(-21, 13), Vector2(-44, 8), Vector2(-50, 0), Vector2(-48, -15)],
	[Vector2(-38, -22), Vector2(28, -23), Vector2(34, -9), Vector2(27, 11),
		Vector2(-18, 16), Vector2(-46, 26), Vector2(-99, 30), Vector2(-118, 25),
		Vector2(-121, 15), Vector2(-113, 0), Vector2(-89, -6), Vector2(-58, -1), Vector2(-47, -13)],
	[Vector2(-45, -25), Vector2(39, -25), Vector2(48, -11), Vector2(46, 2),
		Vector2(29, 9), Vector2(-9, 15), Vector2(-39, 14), Vector2(-50, 7), Vector2(-54, -10)],
]
const STALL_STONE := [Color("#b3a07d"), Color("#96a89d"), Color("#b5a498")]
const DISPLAY_OFFSETS := [Vector2(-42, 9), Vector2(-103, 22), Vector2(-39, 9)]
const DISPLAY_NAMES := [&"GrainBaskets", &"FishTray", &"SilkTable"]
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
	Vector2(390, -103), Vector2(442, -119), Vector2(421, -58), Vector2(356, -63), Vector2(199, -46),
	Vector2(-327, -27), Vector2(-282, -11), Vector2(-244, -33), Vector2(-195, -8), Vector2(-165, 20),
	Vector2(7, -25), Vector2(49, -38), Vector2(86, -10), Vector2(36, 15),
	Vector2(-400, 215), Vector2(-346, 226), Vector2(-295, 235), Vector2(-198, 222), Vector2(-151, 202),
	Vector2(-99, 228), Vector2(-57, 197), Vector2(-12, 219), Vector2(44, 176), Vector2(106, 191),
	Vector2(108, 140), Vector2(185, 220), Vector2(258, 220), Vector2(299, 132),
	Vector2(348, 164), Vector2(383, 116), Vector2(426, 144), Vector2(448, 91),
]
const STORAGE := [
	Vector3i(-381, 97, 0), Vector3i(-370, 103, 1), Vector3i(-218, 194, 3),
	Vector3i(-178, -101, 2), Vector3i(-267, -112, 2),
	Vector3i(256, 175, 3),
]
const STORAGE_PROPS := [LANDSCAPE.Prop.GRAIN_SACK, LANDSCAPE.Prop.OPEN_SACK, LANDSCAPE.Prop.JAR, LANDSCAPE.Prop.LIDDED_JAR]
const FENCE_FEET := [
	Vector2(-384, 164), Vector2(-353, 184), Vector2(-319, 195), Vector2(-243, -153),
	Vector2(137, 145), Vector2(217, 149), Vector2(360, -5), Vector2(429, 67),
]
const TREE_PATTERN := [LANDSCAPE.Prop.OAK, LANDSCAPE.Prop.BLOSSOM_TREE, LANDSCAPE.Prop.PINE, LANDSCAPE.Prop.OAK]
const PROP_DETAILS := [
	Vector3i(-377, 190, LANDSCAPE.Prop.LOGS), Vector3i(-211, 98, LANDSCAPE.Prop.LOGS),
	Vector3i(-147, 114, LANDSCAPE.Prop.FLOWERS), Vector3i(-143, -39, LANDSCAPE.Prop.FLOWERS),
	Vector3i(-255, -152, LANDSCAPE.Prop.REEDS), Vector3i(-190, -150, LANDSCAPE.Prop.REEDS),
	Vector3i(77, -28, LANDSCAPE.Prop.SHRUB), Vector3i(84, 37, LANDSCAPE.Prop.FLOWERS),
	Vector3i(206, 108, LANDSCAPE.Prop.ROCK), Vector3i(290, 77, LANDSCAPE.Prop.FLOWERS),
	Vector3i(351, -27, LANDSCAPE.Prop.SHRUB), Vector3i(369, 80, LANDSCAPE.Prop.ROCK),
]
const RAIN_PUDDLES: Array[Rect2] = [
	Rect2(278, 29, 38, 14), Rect2(261, 5, 16, 7), Rect2(-56, 53, 34, 15), Rect2(-159, -112, 42, 20),
	Rect2(232, 126, 23, 14), Rect2(-252, 149, 38, 12),
]
const SNOW_DRIFTS: Array[Rect2] = [
	Rect2(277, 45, 64, 24), Rect2(304, -1, 63, 24), Rect2(232, -12, 23, 8), Rect2(144, 86, 57, 25),
	Rect2(-2, 82, 71, 22), Rect2(-176, -104, 54, 20), Rect2(-261, -99, 57, 19),
	Rect2(-109, -74, 45, 26), Rect2(-370, 158, 73, 22), Rect2(-255, 175, 38, 15),
	Rect2(218, 177, 43, 19), Rect2(230, 117, 29, 21),
]

var street: Array[PackedVector2Array] = []
var street_shoulders: Array[PackedVector2Array] = []
var paving: PackedVector2Array
var dye_paving: PackedVector2Array
var stall_paving: Dictionary[int, STONE_PAVING] = {}
var _paving_art: STONE_PAVING
var _dye_paving_art: STONE_PAVING
var _cart_path: PackedVector2Array
var _lane_surfaces: Array[PackedVector2Array] = []
var _stall_lanes: Array[PackedVector2Array] = []
var _displays: Array[YARD_DISPLAY] = []
var _stall_feet: Array[Vector2] = []
var _dye_vats: Array[DYE_VAT] = []
var main_path: PackedVector2Array
var swimming_frame := AtlasTexture.new()
var fish_swim := 0.0
var basin_art: Texture2D = load(BASIN_ART)

@onready var weather := ROAD_WEATHER.new(RAIN_PUDDLES, SNOW_DRIFTS)
@onready var held_fish := Sprite2D.new()
@onready var fish_shadow := Sprite2D.new()

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	main_path = EstateLayout.sample_road(PackedVector2Array(LAYOUT.MAIN_ROAD + [LAYOUT.EAST_OUTSIDE]))
	paving = _road_outline(main_path, LAYOUT.PAVING_HALF_WIDTH)
	street.append(_road_outline(main_path, LAYOUT.STREET_HALF_WIDTH))
	var dye_path := EstateLayout.sample_road(PackedVector2Array(LAYOUT.DYE_LANE))
	dye_paving = Geometry2D.merge_polygons(_road_outline(dye_path, 6.0), PackedVector2Array(DYE_APRON))[0]
	_lane_surfaces.append(_road_outline(dye_path, 11.0))
	for lane: Array in [LAYOUT.FISH_LANE, LAYOUT.SILK_LANE]:
		var centerline := EstateLayout.sample_road(PackedVector2Array(lane))
		_stall_lanes.append(centerline)
		_lane_surfaces.append(_road_outline(centerline, 14.0))
	_cart_path = EstateLayout.sample_road(PackedVector2Array(LAYOUT.CART_DRIVE))
	_lane_surfaces.append(_road_outline(_cart_path, 14.0))
	street.append_array(_lane_surfaces)
	for yard: Array in [GRAIN_YARD, FISH_YARD, SILK_YARD, DYE_YARD]:
		street.append(PackedVector2Array(yard))
	for surface in street:
		street_shoulders.append(Geometry2D.offset_polygon(surface, 2.0)[0])
	_paving_art = STONE_PAVING.new(paving, LAYOUT.EAST_GATE.x, _lane_surfaces)
	_dye_paving_art = STONE_PAVING.new(dye_paving, LAYOUT.DYE_JUNCTION.x, [paving], 13.0, Vector2(0.8, 4.0))

	var basin := StaticBody2D.new()
	basin.name = "BasinBody"
	basin.position = LAYOUT.BASIN.get_center()
	basin.collision_mask = 0
	var collider := CollisionShape2D.new()
	var rim := RectangleShape2D.new()
	rim.size = LAYOUT.BASIN.size
	collider.shape = rim
	basin.add_child(collider)
	add_child(basin)
	var surface := WATER_SURFACE.new(EstateLayout.corners(BASIN_DRAW), 0.0)
	surface.name = "BasinWater"
	surface.mask_to_water(basin_art, BASIN_MASK, BASIN_DRAW)
	swimming_frame.atlas = load(SWIMMERS)
	swimming_frame.filter_clip = true
	swimming_frame.region = Rect2(0, 0, FISH_CELL, FISH_CELL)
	fish_shadow.name = "FishShadow"
	fish_shadow.texture = swimming_frame
	fish_shadow.self_modulate = Color("#17383243")
	fish_shadow.hide()
	add_child(fish_shadow)
	held_fish.name = "HeldFish"
	held_fish.texture_filter = TEXTURE_FILTER_NEAREST
	held_fish.texture = swimming_frame
	held_fish.self_modulate = Color("#b7d7c6e5")
	held_fish.hide()
	add_child(held_fish)
	# The swimmer and its bed shadow sit below the water reflections.
	add_child(surface)
	surface.set_weather(Color("#4b7772"), Global.has_rain())
	set_process(false)
	weather.name = "RoadWeather"
	add_child(weather)

func show_held_fish(species: String) -> void:
	var column := CreekFish.IDS.find(species)
	held_fish.visible = column >= 0
	fish_shadow.visible = held_fish.visible
	set_process(held_fish.visible)
	if held_fish.visible:
		swimming_frame.region.position.x = column * FISH_CELL
		_move_fish()

func _process(delta: float) -> void:
	fish_swim = fposmod(fish_swim + delta * 1.6, TAU)
	_move_fish()

func _move_fish() -> void:
	var along := Vector2(12.0 * cos(fish_swim), -5.0 * sin(fish_swim))
	held_fish.position = (LAYOUT.BASIN.get_center() + Vector2(12.0 * sin(fish_swim), 5.0 * cos(fish_swim))).snappedf(0.5)
	held_fish.rotation = along.angle()
	var beat := posmod(floori(fish_swim * (6.0 * TAIL_FRAMES / TAU)), TAIL_FRAMES)
	swimming_frame.region.position.y = beat * FISH_CELL
	fish_shadow.position = held_fish.position + Vector2(1.5, 2)
	fish_shadow.rotation = held_fish.rotation

func _road_outline(points: PackedVector2Array, radius: float) -> PackedVector2Array:
	return Geometry2D.offset_polyline(points, radius, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)[0]

func is_on_street(foot: Vector2) -> bool:
	var at := to_local(foot)
	for surface in street:
		if Geometry2D.is_point_in_polygon(at, surface):
			return true
	return _stall_paving_at(at)

func is_on_paving(foot: Vector2) -> bool:
	var location := to_local(foot)
	return Geometry2D.is_point_in_polygon(location, paving) or Geometry2D.is_point_in_polygon(location, dye_paving) \
		or _stall_paving_at(location)

func _stall_paving_at(location: Vector2) -> bool:
	for apron: STONE_PAVING in stall_paving.values():
		if Geometry2D.is_point_in_polygon(location, apron.outline):
			return true
	return false

func add_stall_yard(kind: MarketStall.Kind, approach: Vector2, layer: Node2D) -> void:
	var outline := PackedVector2Array()
	for point: Vector2 in STALL_PAVING[kind]:
		outline.append(approach + point)
	var joins := _lane_surfaces.duplicate()
	joins.append(paving)
	stall_paving[kind] = STONE_PAVING.new(outline, approach.x, joins, 18.0)
	var foot: Vector2 = approach + DISPLAY_OFFSETS[kind]
	var display := YARD_DISPLAY.new(kind, Global.has_rain())
	display.name = DISPLAY_NAMES[kind]
	display.position = foot
	layer.add_child(display)
	_displays.append(display)
	_stall_feet.append(approach - MarketStall.APPROACH)
	queue_redraw()

func walking_fixture_footprints() -> Array[Rect2]:
	var footprints: Array[Rect2] = []
	for display in _displays:
		footprints.append(display.global_transform * YARD_DISPLAY.FOOTPRINT)
	for vat in _dye_vats:
		footprints.append(vat.global_transform * DYE_VAT.FOOTPRINT)
	return footprints

func cover_dye_vats(covered: bool) -> void:
	for vat in _dye_vats:
		vat.set_covered(covered)

func distance_to_trees(foot: Vector2) -> float:
	var at := to_local(foot)
	var nearest := INF
	for tree: Vector2 in TREE_FEET:
		nearest = minf(nearest, at.distance_squared_to(tree))
	return sqrt(nearest)

func _draw() -> void:
	var season := Global.season_index()
	var palette: Array = LANDSCAPE.SEASON_PALETTES[season]
	var meadow: Color = palette[0]
	var shade: Color = palette[1]
	var dirt: Color = palette[3]
	var raining := Global.has_rain()
	var winter := season == Global.Season.WINTER
	if raining:
		meadow = meadow.lerp(Color("#344c4c"), 0.30)
		dirt = dirt.darkened(0.16)
	TERRAIN.draw_grass(self, BACKDROP, season, raining)
	for grove: Rect2 in GROVES:
		var edge := PackedVector2Array()
		for point: Vector2 in GROVE_EDGE:
			edge.append((grove.position + grove.size * point).round())
		draw_colored_polygon(edge, Color(shade, 0.36))
	var leaf_tint: Color = LANDSCAPE.LEAF_TINTS[season]
	if raining:
		leaf_tint *= Color(0.88, 0.94, 0.99)
	leaf_tint.a = 0.32 if winter else 0.82
	var litter := LANDSCAPE.ESTATE_LEAF_LITTER
	for index in TREE_FEET.size():
		var foot: Vector2 = TREE_FEET[index]
		draw_texture_rect_region(LANDSCAPE.ESTATE_ART, Rect2(foot - Vector2(30, 20), litter.size), litter, leaf_tint)
		if index % 3 != 0:
			TERRAIN.draw_sprig(self, foot + Vector2(-13 + index % 26, 2 + index % 9), index, season, raining)
	for shoulder in street_shoulders:
		TERRAIN.draw_loam(self, shoulder, dirt.lerp(meadow, 0.57), TERRAIN.TRACK_GRAIN)
	TERRAIN.draw_verge(self, main_path, LAYOUT.STREET_HALF_WIDTH * 2.0, season, raining)
	for lane in _stall_lanes:
		TERRAIN.draw_verge(self, lane, 28.0, season, raining)
	for surface in street:
		TERRAIN.draw_loam(self, surface, dirt, TERRAIN.TRACK_GRAIN)
	_draw_cart_ruts(dirt)
	_dye_paving_art.draw(self, dirt, winter, raining, Color("#a3ada4"), TERRAIN.STONE_GRAIN)
	_paving_art.draw(self, dirt, winter, raining, LAYOUT.STREET_STONE, TERRAIN.STONE_GRAIN)
	for kind: int in stall_paving:
		stall_paving[kind].draw(self, dirt, winter, raining, STALL_STONE[kind], TERRAIN.STONE_GRAIN)
	_draw_scene_shadows(raining)
	_draw_basin_piece(self, BASIN_DRAW.position, BASIN_BACK)

func _draw_cart_ruts(dirt: Color) -> void:
	for offset: float in [-4.0, 5.0]:
		var groove := PackedVector2Array()
		for index in _cart_path.size():
			var previous := _cart_path[maxi(index - 1, 0)]
			var next := _cart_path[mini(index + 1, _cart_path.size() - 1)]
			var normal := previous.direction_to(next).orthogonal()
			groove.append((_cart_path[index] + normal * offset).snapped(Vector2(0.5, 0.5)))
		draw_polyline(groove, Color(dirt.darkened(0.30), 0.52), 0.8)
		draw_set_transform(Vector2(0, 1))
		draw_polyline(groove, Color(dirt.lightened(0.25), 0.42), 0.7)
		draw_set_transform(Vector2.ZERO)

func _draw_scene_shadows(raining: bool) -> void:
	var contact_shade := LANDSCAPE.scenery_shade(raining)
	for foot in _stall_feet:
		_draw_shadow(foot, [Vector2(-41, -7), Vector2(31, -9), Vector2(48, -15), Vector2(64, -9),
			Vector2(55, 2), Vector2(29, 8), Vector2(-36, 5)], contact_shade)
	for display in _displays:
		YARD_DISPLAY.draw_shadow(self, to_local(display.global_position), contact_shade)
	for vat in _dye_vats:
		DYE_VAT.draw_shadow(self, to_local(vat.global_position), vat.scale.x, contact_shade)
	_draw_shadow(LAYOUT.DYE_HOUSE, [
		Vector2(-46, -8), Vector2(36, -8), Vector2(61, -18), Vector2(73, -9), Vector2(56, 5),
		Vector2(24, 11), Vector2(-36, 7), Vector2(-50, 1)], contact_shade)
	_draw_shadow(LAYOUT.BASIN.end, [Vector2(-61, -2), Vector2(1, -3), Vector2(9, -9),
		Vector2(13, -4), Vector2(8, 4), Vector2(-54, 6), Vector2(-63, 4)], contact_shade)
	for foot: Vector2 in CRATE_FEET:
		_draw_shadow(foot, [Vector2(-13, -5), Vector2(11, -7), Vector2(20, -2),
			Vector2(16, 4), Vector2(-10, 3)], contact_shade)
	for index in TREE_FEET.size():
		LANDSCAPE.draw_sorted_prop_shadow(self, TREE_FEET[index], TREE_PATTERN[index % TREE_PATTERN.size()], contact_shade, raining)
	for detail: Vector3i in PROP_DETAILS:
		LANDSCAPE.draw_sorted_prop_shadow(self, Vector2(detail.x, detail.y), detail.z, contact_shade, raining)
	for jar: Vector3i in STORAGE:
		LANDSCAPE.draw_scenery_shadow(self, Vector2(jar.x, jar.y), STORAGE_PROPS[jar.z], contact_shade)

func _draw_shadow(foot: Vector2, profile: Array[Vector2], shade: Color) -> void:
	var outline := PackedVector2Array()
	for point in profile:
		outline.append(foot + point)
	draw_colored_polygon(outline, shade)

func _draw_basin_front(rim: Node2D) -> void:
	var top := BASIN_DRAW.position + Vector2(0, BASIN_BACK.size.y) - rim.position
	_draw_basin_piece(rim, top, BASIN_FRONT)

func _draw_basin_piece(canvas: CanvasItem, at: Vector2, region: Rect2) -> void:
	if Global.season_index() == Global.Season.WINTER:
		region.position.y += 49
	var tint := Color("#c2cfd1") if Global.has_rain() else Color.WHITE
	canvas.draw_texture_rect_region(basin_art, Rect2(at, region.size), region, tint)

func place_scenery(layer: Node2D, occlusion: LANDSCAPE.SCENERY_OCCLUSION) -> void:
	var wind := FOLIAGE_WIND.new()
	add_child(wind)
	var shadows := LANDSCAPE.TREE_SHADOWS.new()
	add_child(shadows)
	var rim := Node2D.new()
	rim.name = "BasinFront"
	rim.position = Vector2(LAYOUT.BASIN.position.x, LAYOUT.BASIN.end.y)
	rim.draw.connect(_draw_basin_front.bind(rim))
	layer.add_child(rim)
	var season := Global.season_index()
	var tree_art: Array[AtlasTexture] = [
		LANDSCAPE.painted_tree_texture(LANDSCAPE.Prop.OAK, season),
		LANDSCAPE.painted_tree_texture(LANDSCAPE.Prop.BLOSSOM_TREE, season),
		LANDSCAPE.painted_tree_texture(LANDSCAPE.Prop.PINE, season),
		LANDSCAPE.painted_tree_texture(LANDSCAPE.Prop.OAK, season, true),
	]
	var wet_tint := Color(0.88, 0.94, 0.99) if Global.has_rain() else Color.WHITE
	for index in TREE_FEET.size():
		var variant := index % tree_art.size()
		var tree := _prop(layer, TREE_FEET[index], tree_art[variant], 45.0, wet_tint)
		LANDSCAPE.attach_prop_wind(wind, tree, TREE_PATTERN[variant])
		shadows.track(tree)
		occlusion.watch(tree)
	var fence := LANDSCAPE.atlas_texture(LANDSCAPE.ESTATE_ART, LANDSCAPE.ESTATE_SITE_REGIONS[LANDSCAPE.Prop.FENCE])
	for foot: Vector2 in FENCE_FEET:
		occlusion.watch_prop(_prop(layer, foot, fence, 45.0, wet_tint))
	var reedbed := LANDSCAPE.painted_riverside_texture(LANDSCAPE.Prop.REEDS, season)
	var plant_tint := LANDSCAPE.riverside_tint(season, Global.has_rain())
	for detail: Vector3i in PROP_DETAILS:
		var foot := Vector2(detail.x, detail.y)
		var sprite: Sprite2D
		if detail.z == LANDSCAPE.Prop.REEDS:
			sprite = _prop(layer, foot, reedbed, 26.0, plant_tint)
			wind.attach(sprite, FOLIAGE_WIND.STEM)
		else:
			var prop := LANDSCAPE.Prop.BOULDER if detail.z == LANDSCAPE.Prop.ROCK else detail.z
			var texture := LANDSCAPE.atlas_texture(LANDSCAPE.ESTATE_ART, LANDSCAPE.ESTATE_SITE_REGIONS[prop])
			sprite = _prop(layer, foot, texture, 45.0, wet_tint)
		occlusion.watch_prop(sprite)
	for jar: Vector3i in STORAGE:
		var texture := LANDSCAPE.atlas_texture(LANDSCAPE.ESTATE_VESSELS, LANDSCAPE.EXTERNAL_REGIONS[STORAGE_PROPS[jar.z]])
		_prop(layer, Vector2(jar.x, jar.y), texture, 14.0, wet_tint)
	var cargo := LANDSCAPE.atlas_texture(FIXTURE_ART, CRATES)
	for foot: Vector2 in CRATE_FEET:
		_prop(layer, foot, cargo, 26.0, wet_tint)
	_place_dye_vat(layer, &"MadderVat", Vector2(226, -7), 0.80, DYE_VAT.Dye.MADDER)
	_place_dye_vat(layer, &"IndigoVat", LAYOUT.DYE_INDIGO_VAT, 1.0, DYE_VAT.Dye.INDIGO)
	var north_gate := LANDSCAPE.atlas_texture(LANDSCAPE.ESTATE_ART, LANDSCAPE.ESTATE_SITE_REGIONS[LANDSCAPE.Prop.GATE_FAR])
	var south_gate := LANDSCAPE.atlas_texture(LANDSCAPE.ESTATE_ART, LANDSCAPE.ESTATE_SITE_REGIONS[LANDSCAPE.Prop.GATE])
	occlusion.watch(_prop(layer, LAYOUT.EAST_GATE + Vector2(9, -23), north_gate, 44.0, wet_tint))
	occlusion.watch(_prop(layer, LAYOUT.EAST_GATE + Vector2(-14, 23), south_gate, 44.0, wet_tint))
	var return_sign := VillageInscription.place(layer, LAYOUT.EAST_GATE + Vector2(-29, -9),
		VillageInscription.Form.STONE, "封地", Vector2.RIGHT)
	return_sign.modulate = wet_tint
	occlusion.watch_prop(return_sign)

func _place_dye_vat(layer: Node2D, vat_name: StringName, foot: Vector2, vat_scale: float, dye: DYE_VAT.Dye) -> void:
	var vat := DYE_VAT.new(dye)
	vat.name = vat_name
	vat.position = foot
	vat.scale = Vector2.ONE * vat_scale
	layer.add_child(vat)
	_dye_vats.append(vat)

func _prop(layer: Node2D, foot: Vector2, texture: AtlasTexture, baseline: float, tint: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.position = foot
	sprite.offset = Vector2(-texture.get_width() * 0.5, -baseline)
	sprite.self_modulate = tint
	layer.add_child(sprite)
	return sprite
