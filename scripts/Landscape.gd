extends Node2D

enum Prop {
	HALL, SILK_SHED, OAK, PINE, ROCK, GATE, BAMBOO, BOULDER, FLOWERS, REEDS, SUPPLIES, SIGNPOST, LOGS, SHRUB, BRIDGE, FENCE,
	GROVE_TREE, GROVE_CLUSTER, MOSS_STONE, FERN, STUMP, JAR, PEBBLES, WILLOW, BANK_GRASS, TALL_BAMBOO,
	GRAIN_SACK, OPEN_SACK, LIDDED_JAR, RAVINE_ROCK, RAVINE_SHOOT, RAVINE_RUSH, WHITE_BLOOM, PINK_BLOOM,
	BLOSSOM_TREE, GATE_FAR
}

const SCENERY := preload("res://assets/world/scenery.svg")
const ESTATE_BUILDINGS := preload("res://assets/world/estate-buildings.svg")
const SEASONAL_TREES := preload("res://assets/world/seasonal-trees.svg")
const SEASONAL_GROUND := preload("res://scripts/SeasonalGround.gd")
const ESTATE_TERRAIN := preload("res://scripts/EstateTerrain.gd")
const ESTATE_ART := ESTATE_TERRAIN.SITE_ART
const ESTATE_VESSELS := preload("res://assets/world/estate-vessels.png")
const WATER_SURFACE := preload("res://scripts/WaterSurface.gd")
const SOUTH_POND := preload("res://scripts/SouthPond.gd")
const FOOTSTEP_EFFECTS := preload("res://scripts/FootstepEffects.gd")
const SILK_SAMPLE := preload("res://assets/world/west-court-sample.svg")
const SILK_SAMPLE_BOUNDS := Rect2(EstateLayout.WEST_COURT + Vector2(-37, -4), Vector2(28, 24))
const RAVINE_ART := preload("res://assets/world/ravine-art.png")
const RAIN_VEIL := preload("res://scripts/RainVeil.gd")
const FOLIAGE_WIND := preload("res://scripts/FoliageWind.gd")
const SCENERY_OCCLUSION := preload("res://scripts/SceneryOcclusion.gd")
const TERRAIN_AUDIO := preload("res://scripts/TerrainAudio.gd")
const DAY_LIGHTING := preload("res://scripts/DayLighting.gd")
const TREE_SHADOWS := preload("res://scripts/TreeShadows.gd")
const NINJA_SCENERY := preload("res://assets/world/ninja-adventure/tileset_village_abandoned.png")
const ESTATE_STORAGE := preload("res://assets/world/estate-storage.svg")
const RIVERSIDE_PLANTS := preload("res://assets/world/riverside-plants.png")
const BAMBOO_ART_PATH := "res://assets/world/river-bamboo.png"
const BAMBOO_FRAMES := {Prop.TALL_BAMBOO: Rect2(0, 0, 40, 48), Prop.BAMBOO: Rect2(41, 0, 30, 32)}
const INSCRIPTION := preload("res://scripts/VillageInscription.gd")
const WOODLAND := preload("res://assets/world/ravine-woodland.svg")
const RAVINE_BANKS := preload("res://scripts/RavineBanks.gd")
const RAVINE_RELIEF := preload("res://scripts/RavineRelief.gd")
const FIELD_BANK_DEPTH: Array[float] = [2.0, 4.5, 6.0, 2.0]
const RIVERSIDE_REGIONS := {
	Prop.WILLOW: Rect2(0, 0, 80, 92),
	Prop.TALL_BAMBOO: Rect2(88, 0, 40, 48),
	Prop.BAMBOO: Rect2(134, 0, 30, 32),
	Prop.REEDS: Rect2(170, 0, 30, 28),
	Prop.RAVINE_RUSH: Rect2(206, 0, 26, 20),
	Prop.BANK_GRASS: Rect2(88, 54, 32, 25),
	Prop.FERN: Rect2(126, 54, 27, 21),
	Prop.RAVINE_SHOOT: Rect2(160, 54, 14, 18),
}
const RIVERSIDE_WINTER_ROW := 96
const WOODLAND_REGIONS := {
	Prop.GROVE_TREE: Rect2(0, 0, 32, 32),
	Prop.GROVE_CLUSTER: Rect2(36, 0, 64, 48),
	Prop.PINE: Rect2(104, 0, 48, 48),
}
const SCENERY_SHADOW_SIZES := {
	Prop.OAK: Vector2(19, 7),
	Prop.BLOSSOM_TREE: Vector2(19, 7),
	Prop.GROVE_TREE: Vector2(15, 5),
	Prop.GROVE_CLUSTER: Vector2(30, 9),
	Prop.PINE: Vector2(20, 7),
	Prop.TALL_BAMBOO: Vector2(13, 5),
	Prop.BAMBOO: Vector2(9, 4),
	Prop.SHRUB: Vector2(16, 5),
	Prop.GRAIN_SACK: Vector2(6, 2.5),
	Prop.OPEN_SACK: Vector2(6, 2.5),
	Prop.JAR: Vector2(6, 2.5),
	Prop.LIDDED_JAR: Vector2(6, 2.5),
}
const SCENERY_SHADOW_PROFILE := [Vector2(-0.78, -0.14), Vector2(-0.52, -0.78), Vector2(0.06, -0.97),
	Vector2(0.65, -0.68), Vector2(1.16, -0.2), Vector2(1.45, 0.26), Vector2(1.14, 0.72),
	Vector2(0.57, 0.95), Vector2(0.05, 0.76), Vector2(-0.4, 0.52), Vector2(-0.81, 0.21)]
const ROCK_PROPS := [Prop.ROCK, Prop.BOULDER, Prop.MOSS_STONE, Prop.RAVINE_ROCK]
const STONE_REGIONS := {
	Prop.MOSS_STONE: Rect2(0, 96, 32, 32),
	Prop.RAVINE_ROCK: Rect2(48, 96, 36, 22),
	Prop.PEBBLES: Rect2(96, 96, 16, 16),
}
const MEADOW_FLOWERS := {
	Prop.WHITE_BLOOM: preload("res://assets/world/mini-meadow/flower_white.png"),
	Prop.PINK_BLOOM: preload("res://assets/world/mini-meadow/flower_pink.png"),
}
const STORAGE_TINTS := {
	Prop.GRAIN_SACK: Color(0.88, 0.83, 0.68),
	Prop.OPEN_SACK: Color(0.84, 0.79, 0.64),
	Prop.JAR: Color(0.73, 0.53, 0.53),
	Prop.LIDDED_JAR: Color(0.64, 0.54, 0.60),
}
const EXTERNAL_REGIONS := {
	Prop.GROVE_TREE: Rect2(64, 144, 32, 32),
	Prop.GROVE_CLUSTER: Rect2(0, 144, 64, 48),
	Prop.STUMP: Rect2(96, 128, 16, 16),
	Prop.GRAIN_SACK: Rect2(0, 0, 16, 16),
	Prop.OPEN_SACK: Rect2(16, 0, 16, 16),
	Prop.JAR: Rect2(32, 0, 16, 16),
	Prop.LIDDED_JAR: Rect2(48, 0, 16, 16),
	Prop.WHITE_BLOOM: Rect2(0, 0, 16, 16),
	Prop.PINK_BLOOM: Rect2(0, 0, 16, 16),
}
const NINJA_TINT := Color(0.79, 0.79, 0.92)
const PROP_SIZE := Vector2(48, 48)
const PROP_ANCHOR := Vector2(24, 45)
const PROP_COLUMNS := 8
const BUILDING_REGIONS := {
	Prop.HALL: Rect2(0, 0, 128, 88),
	Prop.SILK_SHED: Rect2(128, 0, 80, 64),
	Prop.GATE: Rect2(312, 0, 32, 48),
	Prop.GATE_FAR: Rect2(280, 0, 32, 48),
}
const PAVILION_REGION := Rect2(Vector2(80, 0), EstateLayout.PAVILION_SIZE)
const BUILDING_FOOTPRINTS := {
	Prop.HALL: EstateLayout.HALL_BASE,
	Prop.SILK_SHED: EstateLayout.SILK_SHED_BASE,
	Prop.GATE: Rect2(-12, -5, 24, 7),
	Prop.GATE_FAR: Rect2(-12, -5, 24, 7),
}
# The hall yard uses the regular sprite sizes and foot anchors. Seasonal tiles run across each tree row.
const HALL_YARD_AREA := Rect2(-145, -67, 369, 247)
const HALL_YARD_REGIONS := {
	Prop.HALL: Rect2(0, 0, 128, 88),
	Prop.ROCK: Rect2(128, 0, 48, 48),
	Prop.OAK: Rect2(0, 96, 48, 48),
	Prop.BLOSSOM_TREE: Rect2(0, 144, 48, 48),
	Prop.PINE: Rect2(0, 192, 48, 48),
	Prop.GROVE_TREE: Rect2(0, 240, 32, 32),
}
const HALL_YARD_GROUND := Rect2(224, 0, 432, 272)
const HALL_YARD_GROUND_AT := Vector2(-177, -94)
const HALL_YARD_CANOPY_SHADOW := Rect2(288, 276, 64, 31)
const HALL_YARD_STONE_SHADOW := Rect2(352, 276, 36, 16)
const ESTATE_SITE_REGIONS := {
	Prop.SILK_SHED: Rect2(0, 0, 80, 64),
	Prop.GATE: Rect2(152, 0, 32, 48),
	Prop.GATE_FAR: Rect2(184, 0, 32, 48),
	Prop.BOULDER: Rect2(0, 64, 48, 48),
	Prop.MOSS_STONE: Rect2(48, 64, 32, 32),
	Prop.RAVINE_ROCK: Rect2(80, 64, 36, 22),
	Prop.PEBBLES: Rect2(116, 64, 16, 16),
	Prop.FENCE: Rect2(132, 64, 48, 48),
	Prop.LOGS: Rect2(180, 64, 48, 48),
	Prop.SHRUB: Rect2(324, 64, 48, 48),
	Prop.FLOWERS: Rect2(372, 64, 48, 48),
	Prop.WHITE_BLOOM: Rect2(420, 64, 16, 16),
	Prop.PINK_BLOOM: Rect2(436, 64, 16, 16),
}
const ESTATE_RIVER_REGIONS := {
	Prop.WILLOW: Rect2(0, 300, 80, 92),
	Prop.TALL_BAMBOO: Rect2(80, 300, 40, 48),
	Prop.BAMBOO: Rect2(120, 300, 30, 32),
	Prop.REEDS: Rect2(150, 300, 30, 28),
	Prop.BANK_GRASS: Rect2(180, 300, 32, 25),
	Prop.FERN: Rect2(212, 300, 27, 21),
	Prop.RAVINE_RUSH: Rect2(240, 300, 26, 20),
}
const CANOPY_SHADOW_SCALE := {
	Prop.OAK: 1.0, Prop.BLOSSOM_TREE: 1.0, Prop.PINE: 0.82,
	Prop.GROVE_TREE: 0.64, Prop.GROVE_CLUSTER: 1.24, Prop.WILLOW: 1.54,
}
const ESTATE_LEAF_LITTER := Rect2(0, 252, 64, 40)
const ORCHARD_FRAMES := [Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(3, 1)]
const MAP_BACKDROP := Rect2(-1650, -1400, 3350, 2800)
const ESTATE_BOUNDS := EstateLayout.BOUNDS
const WILD_BOUNDS := RavineLayout.BOUNDS
const HALL_FOOT := EstateLayout.HALL_FOOT
const HALL_LANDING := EstateLayout.HALL_LANDING
# Openings measured from each facade sprite's foot.
const HALL_DOOR := Rect2(-12, -38, 24, 27)
const SHED_DOOR := Rect2(4, -27, 20, 21)
const HALL_WINDOWS := [Rect2(-39, -31, 17, 9), Rect2(21, -31, 11, 9)]
const HALL_WINDOW_RAIL := -28.0
const SHED_WINDOW := Rect2(-20, -22, 14, 7)
const SOUTH_PAVILION := EstateLayout.SOUTH_PAVILION
const PAVILION_TURN := EstateLayout.PAVILION_TURN
const SILK_SHED_FOOT := EstateLayout.SILK_SHED_FOOT
const SCENE_LANDMARK := -1
const SCENE_WEST_COURT := -2
const BUILDING_SHADOWS := {
	Prop.HALL: [Vector2(-51, -10), Vector2(46, -10), Vector2(59, -19), Vector2(70, -8),
		Vector2(59, 3), Vector2(26, 8), Vector2(-49, 6), Vector2(-55, 1)],
	Prop.SILK_SHED: [Vector2(-30, -8), Vector2(27, -8), Vector2(36, -16), Vector2(45, -8),
		Vector2(34, 4), Vector2(8, 6), Vector2(-28, 4), Vector2(-35, 0)],
	SCENE_LANDMARK: [Vector2(-29, -13), Vector2(24, -13), Vector2(34, -23), Vector2(42, -15),
		Vector2(34, -3), Vector2(17, 4), Vector2(-27, 4), Vector2(-33, 0)],
}
# Meadow, shade, sunny patches, and road for spring through winter.
const SEASON_PALETTES := [
	[Color("#4c6549"), Color("#3b563f"), Color("#57704c"), Color("#a08c65")],
	[Color("#3f6347"), Color("#304e3d"), Color("#54734a"), Color("#9b865e")],
	[Color("#64674a"), Color("#46513d"), Color("#777251"), Color("#a58c62")],
	[Color("#596b65"), Color("#465952"), Color("#6d7c72"), Color("#a39176")],
]
const LEAF_TINTS := [Color(1.04, 1.05, 0.98), Color(0.94, 1.06, 0.98),
	Color(1.44, 0.88, 0.63), Color(0.82, 0.86, 1.12)]
const WATER_TINTS := [Color("#477f81"), Color("#48847f"), Color("#52797b"), Color("#658888")]
const ROADSIDE_PROPS := [Prop.SIGNPOST, Prop.FENCE, Prop.LOGS]
const SORTED_PROPS := [Prop.HALL, Prop.SILK_SHED, Prop.OAK, Prop.BLOSSOM_TREE, Prop.PINE, Prop.GATE, Prop.GATE_FAR, Prop.BAMBOO,
	Prop.GROVE_TREE, Prop.GROVE_CLUSTER, Prop.WILLOW, Prop.TALL_BAMBOO,
	Prop.GRAIN_SACK, Prop.OPEN_SACK, Prop.JAR, Prop.LIDDED_JAR] + ROCK_PROPS + ROADSIDE_PROPS
const WIND_FLEXIBILITY := {
	Prop.OAK: FOLIAGE_WIND.CROWN, Prop.BLOSSOM_TREE: FOLIAGE_WIND.CROWN,
	Prop.GROVE_TREE: FOLIAGE_WIND.CROWN, Prop.GROVE_CLUSTER: FOLIAGE_WIND.CROWN,
	Prop.PINE: FOLIAGE_WIND.NEEDLES, Prop.WILLOW: FOLIAGE_WIND.WILLOW,
	Prop.BAMBOO: FOLIAGE_WIND.STEM, Prop.TALL_BAMBOO: FOLIAGE_WIND.STEM,
}
const DRIFT_CROWNS := {
	Prop.BLOSSOM_TREE: FOLIAGE_WIND.Crown.FLOWERING,
	Prop.OAK: FOLIAGE_WIND.Crown.DECIDUOUS, Prop.WILLOW: FOLIAGE_WIND.Crown.DECIDUOUS,
	Prop.GROVE_TREE: FOLIAGE_WIND.Crown.DECIDUOUS, Prop.GROVE_CLUSTER: FOLIAGE_WIND.Crown.DECIDUOUS,
}
const LEAFY_PROPS := [Prop.OAK, Prop.BLOSSOM_TREE, Prop.GROVE_TREE, Prop.GROVE_CLUSTER, Prop.SHRUB, Prop.FERN,
	Prop.FLOWERS, Prop.WILLOW, Prop.BANK_GRASS, Prop.TALL_BAMBOO, Prop.RAVINE_SHOOT, Prop.RAVINE_RUSH,
	Prop.WHITE_BLOOM, Prop.PINK_BLOOM]
const DORMANT_PROPS := [Prop.FLOWERS, Prop.FERN, Prop.RAVINE_SHOOT, Prop.WHITE_BLOOM, Prop.PINK_BLOOM]
const BERRY_GROVE := RavineLayout.FRUIT + Vector2(-17, 8)
const HALL_BIRD_TREE := Vector2(52, -17)
const PAVILION_BIRD_TREE := Vector2(196, 373)
const BRIDGE := RavineLayout.BRIDGE
const BRIDGE_DECK := RavineLayout.BRIDGE_DECK
const FORD := RavineLayout.FORD
const FORD_AREA := Rect2(FORD - Vector2(35, 17), Vector2(70, 34))
const CROSSING_HALF_DEPTH := 16.0
const WATER_HALF_WIDTH := 17.0
const RAVINE_JUNCTIONS := [
	[Vector2(-174, 35), RavineLayout.BERRY_LANE, "野果坳"],
	[Vector2(-62, 14), RavineLayout.FORD_TRAIL, "浅滩"],
	[Vector2(355, 33), RavineLayout.RIDGE_LANE, "望溪台"],
	[Vector2(150, 214), RavineLayout.SOUTH_TRAIL, RavineLayout.SOUTH_TRAIL_NAME],
]
const ESTATE_WAYPOSTS := [
	[Vector2(-75, 65), Vector2.LEFT, "西市"],
	[Vector2(-239, 10), EstateLayout.WEST_LANE[1] - EstateLayout.WEST_FORK, "西廊"],
	[Vector2(120, 54), Vector2.RIGHT, "东关"],
	[Vector2(286, 46), Vector2.RIGHT, "竹涧"],
	[Vector2(351, 57), EstateLayout.DRIVING_APPROACH[1] - EstateLayout.DRIVING_FORK, "驾御场"],
	[Vector2(23, 209), EstateLayout.FIELD_LANE_TURN - EstateLayout.SOUTH_LANE[6], "南路亭"],
	[Vector2(0, 527), EstateLayout.SHEEP_LANE[1] - EstateLayout.SOUTH_FORK, "西坡"],
	[Vector2(50, 511), EstateLayout.HEARTH_LANE[1] - EstateLayout.SOUTH_FORK, "灶台"],
	[Vector2(226, 605), EstateLayout.FESTIVAL_LANE[1] - EstateLayout.FESTIVAL_FORK, "南池"],
	[Vector2(278, 553), EstateLayout.RAVINE_TRAIL[1] - EstateLayout.FESTIVAL_FORK, EstateLayout.RAVINE_TRAIL_NAME],
]
const WINTER_ROCK_TINT := Color(0.92, 0.99, 1.08)
const EAST_LANE_JUNCTION := EstateLayout.EAST_LANE_JUNCTION
const ESTATE_SOUTH_LANE := EstateLayout.SOUTH_LANE
const ESTATE_EAST_LANE := EstateLayout.EAST_LANE
const ESTATE_TRACKS := EstateLayout.ROADS + EstateLayout.SOUTH_ROADS + [
	[EstateLayout.FREIGHT_STOP + Vector2(-21, 0), EstateLayout.FREIGHT_STOP + Vector2(32, 0)],
	[EstateLayout.HEARTH_APPROACH + Vector2(-13, 0), EstateLayout.HEARTH_APPROACH + Vector2(23, 4)],
] + EstateLayout.DRIVING_ROADS
const WILD_TRACKS := RavineLayout.TRACKS
const ESTATE_TRACK_WIDTHS: Array[float] = EstateLayout.ROAD_WIDTHS + [
	18.0, 13.0, 17.0, 14.0, 17.0, 15.0, 13.0, 16.0, 14.0, 41.0, 30.0, 19.0, 34.0,
]
const GARDEN_TRACK := [EstateLayout.PAVILION_TURN, Vector2(39, 396), Vector2(58, 402), Vector2(78, 407), Vector2(101, 408)]
const ROTATION_BOOK_TRACK := [EstateLayout.FIELD_LANE_TURN, Vector2(22, 236), Vector2(0, 233), Vector2(-21, 234), Vector2(-43, 238)]
const WILD_TRACK_WIDTHS := RavineLayout.TRACK_WIDTHS
const CREEK := RavineLayout.CREEK
const ESTATE_PROPS := [
	Vector3i(-407, -273, Prop.OAK), Vector3i(-365, -286, Prop.PINE),
	Vector3i(-313, -280, Prop.PINE), Vector3i(-254, -292, Prop.OAK),
	Vector3i(-209, -286, Prop.PINE), Vector3i(-156, -273, Prop.OAK),
	Vector3i(-111, -276, Prop.TALL_BAMBOO), Vector3i(-71, -278, Prop.PINE),
	Vector3i(-13, -285, Prop.OAK), Vector3i(33, -273, Prop.PINE),
	Vector3i(82, -288, Prop.OAK), Vector3i(125, -276, Prop.PINE),
	Vector3i(177, -283, Prop.OAK), Vector3i(223, -273, Prop.PINE),
	Vector3i(275, -276, Prop.OAK), Vector3i(326, -280, Prop.PINE),
	Vector3i(370, -283, Prop.OAK), Vector3i(428, -273, Prop.PINE), Vector3i(481, -277, Prop.OAK),
	Vector3i(-360, -234, Prop.PINE), Vector3i(-324, -242, Prop.OAK),
	Vector3i(-297, -231, Prop.PINE), Vector3i(-269, -248, Prop.GROVE_CLUSTER),
	Vector3i(-228, -245, Prop.TALL_BAMBOO), Vector3i(-197, -230, Prop.OAK),
	Vector3i(-161, -234, Prop.PINE), Vector3i(-120, -225, Prop.GROVE_TREE),
	Vector3i(-82, -228, Prop.OAK), Vector3i(-35, -236, Prop.TALL_BAMBOO),
	Vector3i(8, -242, Prop.PINE), Vector3i(41, -238, Prop.OAK),
	Vector3i(83, -249, Prop.TALL_BAMBOO), Vector3i(118, -250, Prop.GROVE_CLUSTER),
	Vector3i(151, -239, Prop.PINE), Vector3i(195, -230, Prop.OAK),
	Vector3i(232, -224, Prop.PINE), Vector3i(268, -231, Prop.GROVE_TREE),
	Vector3i(312, -232, Prop.TALL_BAMBOO), Vector3i(339, -233, Prop.OAK),
	Vector3i(374, -245, Prop.PINE), Vector3i(405, -241, Prop.OAK),
	Vector3i(445, -232, Prop.GROVE_CLUSTER), Vector3i(487, -231, Prop.PINE), Vector3i(534, -231, Prop.OAK),
	Vector3i(-305, -198, Prop.RAVINE_ROCK), Vector3i(-169, -196, Prop.RAVINE_ROCK),
	Vector3i(-48, -201, Prop.RAVINE_ROCK), Vector3i(123, -196, Prop.RAVINE_ROCK),
	Vector3i(300, -200, Prop.RAVINE_ROCK), Vector3i(433, -199, Prop.RAVINE_ROCK),
	# The woods continue past the western boundary, with an opening at the market road.
	Vector3i(-469, -117, Prop.PINE), Vector3i(-413, -115, Prop.OAK), Vector3i(-355, -91, Prop.TALL_BAMBOO),
	Vector3i(-453, 27, Prop.OAK), Vector3i(-404, 43, Prop.GROVE_TREE), Vector3i(-358, 40, Prop.PINE),
	Vector3i(-469, 97, Prop.GROVE_CLUSTER), Vector3i(-425, 109, Prop.TALL_BAMBOO), Vector3i(-365, 89, Prop.OAK),
	Vector3i(-438, 169, Prop.PINE), Vector3i(-394, 163, Prop.OAK), Vector3i(-351, 152, Prop.GROVE_TREE),
	Vector3i(-474, 228, Prop.OAK), Vector3i(-411, 233, Prop.GROVE_TREE), Vector3i(-365, 221, Prop.TALL_BAMBOO),
	Vector3i(-448, 285, Prop.GROVE_CLUSTER), Vector3i(-393, 290, Prop.PINE), Vector3i(-350, 267, Prop.OAK),
	Vector3i(-467, 354, Prop.PINE), Vector3i(-415, 340, Prop.OAK), Vector3i(-361, 329, Prop.GROVE_TREE),
	Vector3i(-442, 417, Prop.OAK), Vector3i(-384, 413, Prop.TALL_BAMBOO), Vector3i(-348, 392, Prop.PINE),
	Vector3i(-278, -166, Prop.RAVINE_ROCK), Vector3i(-245, -143, Prop.TALL_BAMBOO),
	Vector3i(-194, -142, Prop.OAK), Vector3i(-176, -166, Prop.FERN),
	Vector3i(-124, -117, Prop.PINE), Vector3i(-102, -114, Prop.FERN),
	Vector3i(48, -124, Prop.GROVE_TREE), Vector3i(70, -107, Prop.FERN),
	Vector3i(227, -123, Prop.TALL_BAMBOO), Vector3i(258, -91, Prop.OAK),
	Vector3i(283, -91, Prop.SHRUB), Vector3i(307, -143, Prop.PINE),
	Vector3i(-295, -47, Prop.GATE_FAR), Vector3i(-321, 0, Prop.GATE),
	Vector3i(-255, -58, Prop.GROVE_TREE), Vector3i(-282, 32, Prop.OAK),
	Vector3i(-211, 36, Prop.FLOWERS), Vector3i(-164, -13, Prop.PEBBLES),
	Vector3i(-112, -17, Prop.OAK), Vector3i(-66, -50, Prop.TALL_BAMBOO), Vector3i(HALL_FOOT.x, HALL_FOOT.y, Prop.HALL),
	Vector3i(-97, 27, Prop.FENCE), Vector3i(-24, 67, Prop.FLOWERS),
	Vector3i(-54, 39, Prop.GRAIN_SACK), Vector3i(-45, 43, Prop.OPEN_SACK), Vector3i(-58, 46, Prop.GRAIN_SACK),
	Vector3i(15, 35, Prop.JAR), Vector3i(29, 33, Prop.LIDDED_JAR),
	Vector3i(52, -17, Prop.BLOSSOM_TREE), Vector3i(85, -20, Prop.PINE), Vector3i(115, -42, Prop.GROVE_TREE),
	Vector3i(126, -25, Prop.SHRUB), Vector3i(173, -23, Prop.ROCK), Vector3i(204, -35, Prop.PINE),
	Vector3i(233, -21, Prop.OAK), Vector3i(267, -41, Prop.BAMBOO), Vector3i(306, -27, Prop.MOSS_STONE),
	Vector3i(-320, 94, Prop.FENCE), Vector3i(-290, 99, Prop.OPEN_SACK),
	Vector3i(-311, 116, Prop.TALL_BAMBOO), Vector3i(-284, 124, Prop.PINE), Vector3i(-231, 101, Prop.TALL_BAMBOO),
	Vector3i(-211, 115, Prop.SHRUB), Vector3i(-317, 188, Prop.LIDDED_JAR), Vector3i(-311, 195, Prop.JAR),
	Vector3i(-319, 227, Prop.SHRUB), Vector3i(-283, 236, Prop.OAK), Vector3i(-244, 207, Prop.FLOWERS),
	Vector3i(-204, 148, Prop.OAK), Vector3i(-221, 153, Prop.FERN), Vector3i(-166, 150, Prop.RAVINE_ROCK),
	Vector3i(-146, 160, Prop.FERN), Vector3i(-184, 221, Prop.TALL_BAMBOO), Vector3i(-148, 245, Prop.PINE),
	Vector3i(-118, 253, Prop.SHRUB), Vector3i(-96, 254, Prop.FERN),
	Vector3i(-78, 143, Prop.TALL_BAMBOO), Vector3i(-45, 173, Prop.OAK), Vector3i(-7, 186, Prop.FLOWERS),
	Vector3i(7, 164, Prop.ROCK), Vector3i(159, 139, Prop.FLOWERS), Vector3i(182, 114, Prop.SHRUB),
	Vector3i(176, 185, Prop.FERN), Vector3i(225, 126, Prop.FLOWERS), Vector3i(257, 130, Prop.ROCK), Vector3i(338, 116, Prop.PINE),
	Vector3i(303, 215, Prop.OAK), Vector3i(274, 234, Prop.BOULDER), Vector3i(230, 249, Prop.LOGS),
	Vector3i(196, 373, Prop.BLOSSOM_TREE), Vector3i(149, 381, Prop.TALL_BAMBOO), Vector3i(109, 358, Prop.FLOWERS),
	Vector3i(115, 380, Prop.LIDDED_JAR), Vector3i(128, 386, Prop.GRAIN_SACK),
	Vector3i(94, 404, Prop.WHITE_BLOOM), Vector3i(100, 398, Prop.PINK_BLOOM),
	Vector3i(106, 424, Prop.WHITE_BLOOM), Vector3i(100, 429, Prop.PINK_BLOOM),
	Vector3i(152, 452, Prop.WHITE_BLOOM), Vector3i(161, 455, Prop.PINK_BLOOM), Vector3i(223, 445, Prop.WHITE_BLOOM),
	Vector3i(289, 285, Prop.FLOWERS), Vector3i(262, 305, Prop.BAMBOO),
	Vector3i(349, 318, Prop.MOSS_STONE), Vector3i(334, 322, Prop.FERN),
	Vector3i(348, -24, Prop.GROVE_TREE), Vector3i(356, -17, Prop.FENCE),
	Vector3i(413, -16, Prop.GATE_FAR), Vector3i(387, 32, Prop.GATE),
	Vector3i(445, 25, Prop.FENCE), Vector3i(457, 53, Prop.PINE),
	Vector3i(481, -21, Prop.GROVE_CLUSTER), Vector3i(478, 99, Prop.GROVE_TREE),
	# The pine verge separates the watch post and the training road.
	Vector3i(357, 87, Prop.OAK), Vector3i(420, 94, Prop.TALL_BAMBOO),
	Vector3i(354, 109, Prop.GROVE_TREE), Vector3i(357, 194, Prop.PINE), Vector3i(427, 155, Prop.PINE),
	Vector3i(336, 207, Prop.TALL_BAMBOO), Vector3i(348, 226, Prop.FENCE), Vector3i(446, 222, Prop.FENCE),
	Vector3i(351, 270, Prop.LOGS), Vector3i(448, 276, Prop.OAK), Vector3i(365, 319, Prop.TALL_BAMBOO),
	Vector3i(447, 326, Prop.GROVE_TREE), Vector3i(375, 378, Prop.GROVE_CLUSTER), Vector3i(453, 385, Prop.PINE),
	Vector3i(377, 436, Prop.PINE), Vector3i(447, 428, Prop.FENCE), Vector3i(474, 435, Prop.FENCE),
	Vector3i(468, 491, Prop.TALL_BAMBOO), Vector3i(423, 501, Prop.GROVE_TREE),
	# Bamboo and low grasses flank the lane between the fields and the pavilion.
	Vector3i(75, 255, Prop.BAMBOO),
	Vector3i(-7, 276, Prop.TALL_BAMBOO), Vector3i(-38, 289, Prop.TALL_BAMBOO), Vector3i(-24, 303, Prop.FERN),
	Vector3i(67, 286, Prop.ROCK), Vector3i(88, 300, Prop.TALL_BAMBOO), Vector3i(122, 307, Prop.GROVE_CLUSTER),
	Vector3i(54, 315, Prop.TALL_BAMBOO), Vector3i(81, 326, Prop.BAMBOO), Vector3i(46, 338, Prop.FERN),
	Vector3i(-24, 346, Prop.MOSS_STONE), Vector3i(-53, 367, Prop.TALL_BAMBOO), Vector3i(-80, 359, Prop.OAK),
	Vector3i(-113, 335, Prop.GROVE_CLUSTER), Vector3i(-194, 369, Prop.PINE), Vector3i(-267, 333, Prop.GROVE_TREE),
	Vector3i(0, 402, Prop.BAMBOO), Vector3i(7, 413, Prop.ROCK), Vector3i(-9, 465, Prop.FERN),
	Vector3i(65, 478, Prop.TALL_BAMBOO), Vector3i(98, 486, Prop.GROVE_TREE), Vector3i(-133, 489, Prop.OAK),
	# Southern verges and groves between the unloading yard, pasture and festival clearing.
	Vector3i(-297, 502, Prop.TALL_BAMBOO), Vector3i(-267, 496, Prop.GROVE_TREE),
	Vector3i(-217, 513, Prop.PINE), Vector3i(-188, 524, Prop.OAK), Vector3i(-150, 545, Prop.TALL_BAMBOO),
	Vector3i(-140, 566, Prop.LOGS), Vector3i(-107, 544, Prop.GRAIN_SACK), Vector3i(-117, 551, Prop.OPEN_SACK),
	Vector3i(-68, 536, Prop.LIDDED_JAR), Vector3i(-46, 521, Prop.GROVE_TREE), Vector3i(-5, 512, Prop.FERN),
	Vector3i(-88, 608, Prop.MOSS_STONE), Vector3i(-107, 616, Prop.FLOWERS), Vector3i(-150, 617, Prop.SHRUB),
	Vector3i(-294, 627, Prop.FENCE), Vector3i(-289, 652, Prop.FLOWERS), Vector3i(-200, 632, Prop.FLOWERS),
	Vector3i(101, 522, Prop.GROVE_TREE), Vector3i(122, 531, Prop.PINE),
	Vector3i(172, 530, Prop.TALL_BAMBOO), Vector3i(191, 548, Prop.LOGS), Vector3i(253, 555, Prop.JAR),
	Vector3i(112, 594, Prop.OAK), Vector3i(136, 621, Prop.PINE), Vector3i(172, 609, Prop.GROVE_TREE),
	Vector3i(37, 600, Prop.BAMBOO), Vector3i(23, 636, Prop.FLOWERS), Vector3i(4, 678, Prop.TALL_BAMBOO),
	Vector3i(281, 633, Prop.GROVE_TREE), Vector3i(315, 635, Prop.TALL_BAMBOO), Vector3i(337, 648, Prop.RAVINE_ROCK),
	Vector3i(306, 545, Prop.BAMBOO), Vector3i(341, 539, Prop.GROVE_TREE),
	Vector3i(400, 603, Prop.BLOSSOM_TREE), Vector3i(463, 539, Prop.PINE), Vector3i(457, 608, Prop.TALL_BAMBOO),
	Vector3i(489, 612, Prop.PINE), Vector3i(483, 664, Prop.OAK),
	# Reeds mark the waterline. The open west bank is the approach to the clearing.
	Vector3i(198, 663, Prop.RAVINE_RUSH), Vector3i(174, 697, Prop.BANK_GRASS),
	Vector3i(219, 766, Prop.RAVINE_ROCK), Vector3i(270, 766, Prop.BANK_GRASS),
	Vector3i(368, 715, Prop.WILLOW), Vector3i(394, 741, Prop.RAVINE_ROCK),
	Vector3i(452, 705, Prop.GROVE_TREE), Vector3i(467, 762, Prop.TALL_BAMBOO),
	Vector3i(116, 680, Prop.PINE), Vector3i(96, 735, Prop.TALL_BAMBOO), Vector3i(123, 761, Prop.MOSS_STONE),
	Vector3i(156, 807, Prop.GROVE_TREE), Vector3i(186, 823, Prop.FERN),
	Vector3i(298, 800, Prop.TALL_BAMBOO), Vector3i(343, 791, Prop.OAK), Vector3i(401, 804, Prop.GROVE_CLUSTER),
	Vector3i(215, 873, Prop.PINE), Vector3i(236, 906, Prop.SHRUB), Vector3i(463, 835, Prop.PINE),
	Vector3i(480, 876, Prop.GROVE_TREE), Vector3i(467, 931, Prop.FENCE), Vector3i(470, 971, Prop.PINE),
	Vector3i(278, 952, Prop.GROVE_TREE), Vector3i(308, 972, Prop.TALL_BAMBOO), Vector3i(369, 982, Prop.OAK),
	Vector3i(190, 977, Prop.OAK), Vector3i(126, 939, Prop.GROVE_CLUSTER), Vector3i(89, 998, Prop.PINE),
	Vector3i(31, 870, Prop.OAK), Vector3i(-44, 827, Prop.PINE), Vector3i(-85, 912, Prop.TALL_BAMBOO),
	Vector3i(-149, 865, Prop.GROVE_CLUSTER), Vector3i(-206, 833, Prop.OAK), Vector3i(-292, 825, Prop.PINE),
	Vector3i(-290, 944, Prop.GROVE_CLUSTER), Vector3i(-187, 974, Prop.PINE), Vector3i(-61, 991, Prop.OAK),
	Vector3i(55, 728, Prop.OAK), Vector3i(-41, 726, Prop.PINE), Vector3i(-100, 710, Prop.TALL_BAMBOO),
	Vector3i(-148, 722, Prop.PINE), Vector3i(-192, 712, Prop.OAK), Vector3i(-241, 723, Prop.PINE),
	Vector3i(-290, 705, Prop.TALL_BAMBOO), Vector3i(-319, 670, Prop.PINE),
]
const WILD_PROPS := [
	Vector3i(-363, -1, Prop.GATE_FAR), Vector3i(-389, 41, Prop.GATE),
	Vector3i(-423, -48, Prop.FENCE), Vector3i(-417, 73, Prop.BOULDER), Vector3i(-406, -56, Prop.GROVE_CLUSTER),
	Vector3i(-358, -46, Prop.PINE), Vector3i(-321, -32, Prop.TALL_BAMBOO), Vector3i(-285, 1, Prop.GROVE_TREE),
	Vector3i(-263, -38, Prop.OAK), Vector3i(-243, -5, Prop.MOSS_STONE), Vector3i(-223, 66, Prop.TALL_BAMBOO),
	Vector3i(-328, 84, Prop.GROVE_CLUSTER), Vector3i(-296, 66, Prop.PINE), Vector3i(-262, 100, Prop.GROVE_TREE),
	Vector3i(-427, -136, Prop.PINE), Vector3i(-397, -202, Prop.GROVE_CLUSTER), Vector3i(-359, -148, Prop.TALL_BAMBOO),
	Vector3i(-329, -209, Prop.PINE), Vector3i(-310, -97, Prop.PINE), Vector3i(-269, -151, Prop.GROVE_TREE),
	Vector3i(-233, -111, Prop.TALL_BAMBOO), Vector3i(-213, -160, Prop.PINE), Vector3i(-162, -163, Prop.BLOSSOM_TREE),
	Vector3i(-116, -155, Prop.GROVE_TREE), Vector3i(-107, -115, Prop.SHRUB), Vector3i(-138, -98, Prop.WHITE_BLOOM),
	Vector3i(-158, -80, Prop.FERN), Vector3i(-120, -26, Prop.GROVE_CLUSTER),
	Vector3i(-86, -32, Prop.RAVINE_SHOOT), Vector3i(-56, -22, Prop.PINE), Vector3i(-26, -63, Prop.BAMBOO),
	Vector3i(-116, 57, Prop.FLOWERS), Vector3i(-94, 67, Prop.STUMP),
	Vector3i(-20, 48, Prop.GROVE_TREE), Vector3i(18, 58, Prop.PINE), Vector3i(43, 88, Prop.BOULDER),
	Vector3i(-131, 125, Prop.OAK), Vector3i(-88, 130, Prop.TALL_BAMBOO), Vector3i(-39, 138, Prop.PINE),
	Vector3i(-206, 171, Prop.GROVE_CLUSTER), Vector3i(-314, 144, Prop.PINE), Vector3i(-381, 168, Prop.TALL_BAMBOO),
	Vector3i(-350, 237, Prop.PINE), Vector3i(-283, 219, Prop.GROVE_TREE), Vector3i(-229, 264, Prop.PINE),
	Vector3i(-156, 220, Prop.GROVE_TREE), Vector3i(-121, 290, Prop.PINE), Vector3i(-50, 220, Prop.OAK),
	Vector3i(39, 198, Prop.PINE), Vector3i(83, 181, Prop.OAK), Vector3i(114, 191, Prop.MOSS_STONE),
	Vector3i(143, 140, Prop.FERN), Vector3i(164, 142, Prop.RAVINE_RUSH), Vector3i(156, 208, Prop.REEDS),
	Vector3i(191, 209, Prop.PEBBLES), Vector3i(204, 227, Prop.RAVINE_ROCK), Vector3i(72, 276, Prop.WILLOW),
	Vector3i(234, 307, Prop.TALL_BAMBOO),
	Vector3i(173, 321, Prop.BAMBOO), Vector3i(167, 356, Prop.GROVE_TREE), Vector3i(235, 352, Prop.RAVINE_ROCK),
	Vector3i(153, 292, Prop.TALL_BAMBOO), Vector3i(110, 309, Prop.PINE), Vector3i(55, 302, Prop.GROVE_TREE),
	Vector3i(41, -53, Prop.PINE), Vector3i(23, -100, Prop.OAK), Vector3i(-14, -142, Prop.GROVE_CLUSTER),
	Vector3i(25, -166, Prop.GROVE_TREE), Vector3i(43, -138, Prop.TALL_BAMBOO), Vector3i(28, -218, Prop.PINE),
	Vector3i(102, -189, Prop.MOSS_STONE), Vector3i(117, -216, Prop.REEDS), Vector3i(169, -237, Prop.REEDS),
	Vector3i(112, -157, Prop.RAVINE_RUSH), Vector3i(128, -253, Prop.BANK_GRASS), Vector3i(83, -281, Prop.PINE),
	Vector3i(40, -262, Prop.TALL_BAMBOO), Vector3i(32, -314, Prop.GROVE_CLUSTER), Vector3i(79, -331, Prop.PINE),
	Vector3i(129, -287, Prop.PEBBLES), Vector3i(159, -314, Prop.REEDS), Vector3i(187, -356, Prop.RAVINE_RUSH),
	Vector3i(112, -367, Prop.TALL_BAMBOO), Vector3i(123, -406, Prop.WILLOW), Vector3i(141, -388, Prop.MOSS_STONE),
	Vector3i(115, -394, Prop.FERN), Vector3i(184, -372, Prop.BANK_GRASS), Vector3i(235, -433, Prop.RAVINE_RUSH),
	Vector3i(183, -387, Prop.PEBBLES), Vector3i(199, -421, Prop.REEDS), Vector3i(143, -456, Prop.PEBBLES),
	Vector3i(106, -460, Prop.PINE), Vector3i(61, -438, Prop.GROVE_TREE), Vector3i(25, -392, Prop.PINE),
	Vector3i(85, -504, Prop.GROVE_CLUSTER), Vector3i(134, -510, Prop.TALL_BAMBOO),
	Vector3i(164, -486, Prop.RAVINE_ROCK), Vector3i(230, -496, Prop.PINE), Vector3i(273, -465, Prop.GROVE_TREE),
	Vector3i(267, -449, Prop.WILLOW), Vector3i(258, -369, Prop.REEDS), Vector3i(290, -338, Prop.PINE),
	Vector3i(212, -290, Prop.GROVE_CLUSTER), Vector3i(262, -256, Prop.TALL_BAMBOO), Vector3i(331, -287, Prop.PINE),
	Vector3i(109, -81, Prop.RAVINE_RUSH), Vector3i(92, -70, Prop.FERN), Vector3i(176, -52, Prop.REEDS),
	Vector3i(104, -34, Prop.BANK_GRASS), Vector3i(171, -72, Prop.RAVINE_RUSH), Vector3i(92, 3, Prop.TALL_BAMBOO),
	Vector3i(107, 60, Prop.PEBBLES), Vector3i(183, 58, Prop.PEBBLES), Vector3i(204, 6, Prop.TALL_BAMBOO),
	Vector3i(117, 96, Prop.BANK_GRASS), Vector3i(141, 135, Prop.REEDS), Vector3i(203, 119, Prop.FERN),
	Vector3i(223, 129, Prop.BANK_GRASS),
	Vector3i(225, -169, Prop.WILLOW), Vector3i(208, -108, Prop.MOSS_STONE), Vector3i(241, -88, Prop.GROVE_TREE),
	Vector3i(269, -52, Prop.PINE), Vector3i(273, -103, Prop.TALL_BAMBOO), Vector3i(304, -132, Prop.GROVE_CLUSTER),
	Vector3i(319, -46, Prop.BOULDER), Vector3i(342, -70, Prop.BAMBOO), Vector3i(376, -112, Prop.PINE),
	Vector3i(383, -151, Prop.TALL_BAMBOO), Vector3i(420, -149, Prop.GROVE_TREE), Vector3i(467, -145, Prop.PINE),
	Vector3i(483, -96, Prop.TALL_BAMBOO), Vector3i(499, -69, Prop.GROVE_TREE), Vector3i(452, -63, Prop.FERN),
	Vector3i(382, -16, Prop.BANK_GRASS), Vector3i(400, -36, Prop.RAVINE_SHOOT),
	Vector3i(482, -28, Prop.BOULDER), Vector3i(414, -25, Prop.MOSS_STONE),
	Vector3i(369, 73, Prop.TALL_BAMBOO), Vector3i(376, 121, Prop.PINE), Vector3i(433, 100, Prop.GROVE_CLUSTER),
	Vector3i(486, 44, Prop.PINE), Vector3i(523, -16, Prop.TALL_BAMBOO), Vector3i(526, 99, Prop.GROVE_TREE),
	Vector3i(253, 99, Prop.PINE), Vector3i(241, 143, Prop.RAVINE_RUSH), Vector3i(280, 132, Prop.SHRUB),
	Vector3i(320, 164, Prop.BLOSSOM_TREE), Vector3i(310, 190, Prop.BOULDER), Vector3i(351, 201, Prop.OAK),
	Vector3i(249, 215, Prop.PEBBLES), Vector3i(276, 242, Prop.PEBBLES), Vector3i(296, 218, Prop.MOSS_STONE),
	Vector3i(297, 258, Prop.REEDS), Vector3i(328, 282, Prop.FERN), Vector3i(308, 305, Prop.PEBBLES),
	Vector3i(357, 311, Prop.TALL_BAMBOO), Vector3i(397, 268, Prop.GROVE_TREE), Vector3i(432, 234, Prop.PINE),
	Vector3i(488, 213, Prop.GROVE_CLUSTER), Vector3i(504, 299, Prop.PINE), Vector3i(436, 342, Prop.TALL_BAMBOO),
	Vector3i(371, 365, Prop.GROVE_TREE), Vector3i(325, 369, Prop.PINE), Vector3i(244, 394, Prop.PINE),
	Vector3i(148, 359, Prop.GROVE_TREE), Vector3i(71, 368, Prop.PINE), Vector3i(-7, 373, Prop.GROVE_CLUSTER),
]

@export var wilderness := false

@onready var tile_map := get_parent().get_node_or_null("TileMapLayer") as TileMapLayer
@onready var player := get_parent().get_node("Player") as Player
@onready var hall_rest := get_parent().get_node_or_null("HallRest")
@onready var silk_shed := get_parent().get_node_or_null("SilkShed")
@onready var pond_landing := get_parent().get_node_or_null("Scenery/PondLanding") as Node2D
@onready var footstep_effects := FOOTSTEP_EFFECTS.new()
@onready var resident_footsteps := FOOTSTEP_EFFECTS.new()

var props: Array[Vector3i] = []
var scenery: Dictionary[Sprite2D, int] = {}
var shortcut_waypost: Sprite2D
var gate_bases: Dictionary[Sprite2D, CollisionShape2D] = {}
var seasonal_textures: Dictionary[int, AtlasTexture] = {}
var painted_textures: Dictionary[int, AtlasTexture] = {}
var low_stone_texture: AtlasTexture
var forked_oak_texture: AtlasTexture
var ground_cover: SEASONAL_GROUND
var estate_terrain: ESTATE_TERRAIN
var ravine_relief: RAVINE_RELIEF
var water_surface: WATER_SURFACE
var bridge_cascade: RAVINE_BANKS
var south_pond: SOUTH_POND
var terrain_audio: TERRAIN_AUDIO
var day_lighting: DAY_LIGHTING
var creek_edge := PackedVector2Array()
var creek_profile: RAVINE_BANKS.Channel
var ford_shoal := PackedVector2Array()
var ford_stones: Array[PackedVector2Array] = []
var season := 0
var raining := false
var estate_tracks := ESTATE_TRACKS.duplicate()
var estate_track_widths: Array[float] = []
var track_shapes: Array[Dictionary] = []
var field_approaches: Dictionary[int, PackedVector2Array] = {}
var worksite_mouths: Dictionary[int, Vector2] = {}
var _scenery_ready := false
var _tree_shadows: TREE_SHADOWS
var _estate_ground: Node2D

func _ready() -> void:
	ground_cover = SEASONAL_GROUND.new(wilderness)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if not wilderness:
		estate_terrain = ESTATE_TERRAIN.new(ESTATE_BOUNDS.position.y)
		_estate_ground = Node2D.new()
		_estate_ground.name = "EstateGround"
		_estate_ground.show_behind_parent = true
		_estate_ground.draw.connect(_draw_estate_ground)
		add_child(_estate_ground)
	else:
		ravine_relief = RAVINE_RELIEF.new()
		var line := PackedVector2Array(CREEK)
		creek_edge = _ribbon(line, WATER_HALF_WIDTH)
		creek_profile = RAVINE_BANKS.Channel.new(line, WATER_HALF_WIDTH, [BRIDGE_DECK.grow(4.0), FORD_AREA])
		ford_shoal = _ford_outline()
		ford_stones = RAVINE_BANKS.ford_stone_faces()
	add_child(footstep_effects)
	resident_footsteps.name = "ResidentFootsteps"
	add_child(resident_footsteps)
	terrain_audio = AudioManager.terrain_audio
	day_lighting = DAY_LIGHTING.new()
	day_lighting.name = "DayLighting"
	add_child(day_lighting)
	day_lighting.add_cloud_shadows(MAP_BACKDROP)
	player.footstep.connect(_on_footstep)
	props.assign(WILD_PROPS if wilderness else ESTATE_PROPS)
	props.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.y < b.y)
	GameEvents.day_advanced.connect(_update_weather.unbind(1))
	GameEvents.ravine_journal_changed.connect(_refresh_shortcut_waypost)
	if not wilderness:
		get_parent().visitor_changed.connect(queue_redraw.unbind(1))
		GameEvents.well_field_added.connect(_refresh_field_layout.unbind(1))
		GameEvents.well_field_reclaimed.connect(_refresh_field_layout.unbind(2))
		GameEvents.silk_changed.connect(_refresh_scenery)
		GameEvents.channels_changed.connect(_refresh_scenery)
		GameEvents.road_provisions_delivered.connect(queue_redraw)
		GameEvents.silk_sample_delivered.connect(queue_redraw)
		GameEvents.ravine_journal_changed.connect(_refresh_estate_tracks)
		GameEvents.field_rotation_changed.connect(_refresh_estate_tracks)
		GameEvents.pond_landing_opened.connect(_refresh_estate_tracks)
		_layout_field_approaches()
	else:
		_build_track_shapes(WILD_TRACKS, WILD_TRACK_WIDTHS)
	_tree_shadows = TREE_SHADOWS.new()
	add_child(_tree_shadows)
	_add_water_surface()
	_update_weather()
	_prepare_map.call_deferred()

func _layout_field_approaches() -> void:
	field_approaches.clear()
	worksite_mouths.clear()
	var fields: Array[Rect2] = []
	for field in Global.well_fields:
		fields.append(_field_bounds(field["center_pos"]))
	# The first scene builds its roads before World initializes the starter field.
	if fields.is_empty():
		field_approaches[0] = _starter_approach(_field_bounds(Global.FIRST_FIELD_CENTER))
	for field in Global.well_fields:
		var id: int = field["field_id"]
		var area := fields[id]
		if field["center_pos"] == Global.FIRST_FIELD_CENTER and field["is_unlocked"]:
			field_approaches[id] = _starter_approach(area)
			continue
		var occupied: Array[Rect2] = []
		occupied.assign(EstateLayout.LANDMARKS)
		occupied.append_array(fields)
		occupied.erase(area)
		var approach := EstateLayout.field_approach(area, occupied)
		if not approach.is_empty():
			if field["is_unlocked"]:
				field_approaches[id] = approach
			else:
				# Leave a gap in the survey cord facing the future lane.
				worksite_mouths[id] = approach[-1].direction_to(approach[-2])

func _starter_approach(area: Rect2) -> PackedVector2Array:
	var entry := Vector2(area.get_center().x, area.end.y)
	return PackedVector2Array([EstateLayout.FIELD_TURN, entry + Vector2(1, 14), entry + Vector2(0, 6), entry])

func _refresh_field_layout() -> void:
	_layout_field_approaches()
	_refresh_estate_tracks()
	(tile_map.get_node("WellFieldMarker") as WellFieldMarker).refresh_markers()
	_refresh_scenery()

func field_entrance(field_id: int) -> Vector2:
	if not field_approaches.has(field_id):
		return worksite_mouths.get(field_id, Vector2.ZERO)
	var approach := field_approaches[field_id]
	return approach[-1].direction_to(approach[-2])

func _refresh_estate_tracks() -> void:
	estate_tracks.assign(ESTATE_TRACKS)
	estate_track_widths.assign(ESTATE_TRACK_WIDTHS)
	for approach in field_approaches.values():
		# An old field can open directly onto an adjacent road.
		if approach[0].distance_to(approach[-1]) < EstateLayout.FIELD_ENTRANCE_WIDTH * 0.5:
			continue
		estate_tracks.append(approach)
		estate_track_widths.append(EstateLayout.FIELD_ENTRANCE_WIDTH)
	var field_track_count := estate_tracks.size() - ESTATE_TRACKS.size()
	if Global.ravine_journal.garden_day > 0:
		estate_tracks.append(GARDEN_TRACK)
		estate_track_widths.append(11.0)
	if Global.pond_landing_day() > 0:
		estate_tracks.append(EstateLayout.POND_TRACK)
		estate_track_widths.append(10.0)
	if Global.field_rotation.signed_day > 0:
		estate_tracks.append(ROTATION_BOOK_TRACK)
		estate_track_widths.append(11.0)
	_build_track_shapes(estate_tracks, estate_track_widths, field_track_count)
	_estate_ground.queue_redraw()
	queue_redraw()

func _prepare_map() -> void:
	if not is_inside_tree():
		return
	var props_layer := get_parent().get_node("Scenery") as Node2D
	var crops: TileMapLayer = null if wilderness else get_parent().crops_layer
	var wind := FOLIAGE_WIND.new(crops)
	add_child(wind)
	var occlusion := SCENERY_OCCLUSION.new(player)
	add_child(occlusion)
	var rain := RAIN_VEIL.new()
	rain.name = "Rain"
	rain.z_index = 11
	for placement in props:
		if placement.z not in SORTED_PROPS:
			continue
		var foot := Vector2(placement.x, placement.y)
		var sprite := _place_sprite(props_layer, foot,
			_prop_bounds(Vector2.ZERO, placement.z).position, _prop_texture(placement.z, foot))
		scenery[sprite] = placement.z
		if WIND_FLEXIBILITY.has(placement.z):
			attach_prop_wind(wind, sprite, placement.z)
			_tree_shadows.track(sprite)
		if placement.z == Prop.HALL:
			hall_rest.paint_door(sprite, HALL_DOOR, true, HALL_WINDOWS[0], HALL_WINDOWS[1], HALL_WINDOW_RAIL)
			rain.add_roof(sprite, Rect2(-58, -40, 109, 43), [
				Vector3(-53, -39, 46), Vector3(-30, -39, 45),
				Vector3(24, -39, 46), Vector3(43, -39, 44),
			])
	if wilderness:
		rain.add_surface(BRIDGE_DECK.grow(-2.0), 5)
		var lookout := atlas_texture(RAVINE_ART, Rect2(146, 0, 48, 40))
		scenery[_place_sprite(props_layer, RavineLayout.LOOKOUT, Vector2(-24, -38), lookout)] = SCENE_LANDMARK
		scenery[INSCRIPTION.place(props_layer, RavineLayout.LOOKOUT + Vector2(-76, 47),
			INSCRIPTION.Form.STONE, "望溪台")] = Prop.SIGNPOST
		_place_ravine_wayposts(props_layer)
	else:
		_place_estate_wayposts(props_layer)
		south_pond.place_bank_plants(props_layer, wind)
		var pavilion_texture := atlas_texture(ESTATE_ART, PAVILION_REGION)
		var pavilion := _place_sprite(props_layer, SOUTH_PAVILION, _building_offset(PAVILION_REGION.size), pavilion_texture)
		scenery[pavilion] = SCENE_LANDMARK
		rain.add_roof(pavilion, Rect2(-31, -31, 59, 33), [Vector3(-29, -31, 36), Vector3(26, -31, 36)])
		INSCRIPTION.place(pavilion, Vector2(0, -20), INSCRIPTION.Form.EAVE, "南路亭")
		var shelter := atlas_texture(ESTATE_ART, Rect2(216, 0, 48, 40))
		var court := _place_sprite(props_layer, EstateLayout.WEST_COURT_SHELTER, Vector2(-24, -38), shelter)
		scenery[court] = SCENE_WEST_COURT
		rain.add_roof(court, Rect2(-21, -19, 41, 17), [Vector3(-18, -18, 22), Vector3(17, -18, 21)])
		INSCRIPTION.place(court, Vector2(0, -6), INSCRIPTION.Form.EAVE, "西廊")
		var workshop := _place_sprite(props_layer, SILK_SHED_FOOT,
			_prop_bounds(Vector2.ZERO, Prop.SILK_SHED).position, _prop_texture(Prop.SILK_SHED, SILK_SHED_FOOT))
		scenery[workshop] = Prop.SILK_SHED
		silk_shed.paint_door(workshop, SHED_DOOR, false, SHED_WINDOW)
		occlusion.watch(get_parent().get_node("RainShelterFrontPosts") as Sprite2D)
		rain.add_roof(workshop, Rect2(-35, -29, 65, 29), [
			Vector3(-32, -28, 34), Vector3(-18, -28, 33), Vector3(26, -28, 33),
		])
		var rain_shelter := get_parent().get_node("PavilionRainShelter") as Node2D
		var floor_bounds := EstateLayout.PAVILION_SHELTER_FLOOR
		floor_bounds.position -= rain_shelter.position
		rain.add_roof(rain_shelter, floor_bounds, [
			Vector3(-40, -17, 34), Vector3(-23, -17, 34), Vector3(23, -17, 34), Vector3(32, -17, 34),
		])
		rain.add_surface(HALL_LANDING.grow(-2.0), 4)
	_place_lanterns(props_layer)
	add_child(rain)
	_install_boundaries()
	_scenery_ready = true
	if _estate_ground != null:
		_estate_ground.queue_redraw()
	_refresh_scenery()
	for sprite in scenery:
		var prop := scenery[sprite]
		if prop in ROCK_PROPS or prop in ROADSIDE_PROPS:
			occlusion.watch_prop(sprite)
		elif not STORAGE_TINTS.has(prop):
			occlusion.watch(sprite)

func _place_ravine_wayposts(layer: Node2D) -> void:
	for junction: Array in RAVINE_JUNCTIONS:
		var lane: Array = junction[1]
		var post := place_waypost(layer, junction[0], lane[1] - lane[0], junction[2])
		scenery[post] = Prop.SIGNPOST
		if junction[2] == RavineLayout.SOUTH_TRAIL_NAME:
			shortcut_waypost = post
	scenery[INSCRIPTION.place(layer, RavineLayout.WEST_GATE + Vector2(26, -9), INSCRIPTION.Form.STONE,
		"西门·回封地", Vector2.LEFT)] = Prop.SIGNPOST
	scenery[place_waypost(layer, RavineLayout.SHORE_FORK + Vector2(-13, -12),
		RavineLayout.WEST_SHORE[1] - RavineLayout.SHORE_FORK, "柳湾·埠头")] = Prop.SIGNPOST
	scenery[place_waypost(layer, RavineLayout.DOCK_FORK + Vector2(-18, -5),
		RavineLayout.WEST_SHORE[4] - RavineLayout.DOCK_FORK, "柳湾")] = Prop.SIGNPOST
	scenery[place_waypost(layer, BRIDGE + Vector2(-53, 20), Vector2.RIGHT, "木桥")] = Prop.SIGNPOST

func _place_estate_wayposts(layer: Node2D) -> void:
	for entry: Array in ESTATE_WAYPOSTS:
		var post := place_waypost(layer, entry[0], entry[1], entry[2], true)
		scenery[post] = Prop.SIGNPOST
		if entry[2] == EstateLayout.RAVINE_TRAIL_NAME:
			shortcut_waypost = post
	scenery[INSCRIPTION.place(layer, EstateLayout.EAST_GATE + Vector2(-23, -9),
		INSCRIPTION.Form.STONE, "东关")] = Prop.SIGNPOST
	scenery[place_waypost(layer, EstateLayout.FESTIVAL_LANE[-5] + Vector2(-14, 4),
		EstateLayout.FESTIVAL_LANE[-4] - EstateLayout.FESTIVAL_LANE[-5], "南池畔", true)] = Prop.SIGNPOST

static func place_waypost(layer: Node2D, foot: Vector2, direction: Vector2, caption: String,
		estate_art := false) -> Sprite2D:
	var form := INSCRIPTION.Form.OAK if estate_art else INSCRIPTION.Form.BAMBOO
	return INSCRIPTION.place(layer, foot, form, caption, direction)

func _add_water_surface() -> void:
	if wilderness:
		water_surface = WATER_SURFACE.new(creek_edge, 10.0,
			[BRIDGE_DECK.grow(2.0), FORD_AREA], PackedVector2Array(CREEK))
	else:
		south_pond = SOUTH_POND.new()
		water_surface = south_pond
	water_surface.name = "WaterSurface"
	add_child(water_surface)
	if wilderness:
		bridge_cascade = RAVINE_BANKS.new()
		bridge_cascade.name = "BridgeCascade"
		add_child(bridge_cascade)

func _place_lanterns(layer: Node2D) -> void:
	if wilderness:
		day_lighting.place_lamp(layer, Vector2(-181, 20))
		var near_bank := day_lighting.place_lamp(layer, BRIDGE + Vector2(-29, 15), 0.83)
		var far_bank := day_lighting.place_lamp(layer, BRIDGE + Vector2(30, -12), 0.83)
		water_surface.reflect_lantern(near_bank.glow, BRIDGE + Vector2(-8, 22))
		water_surface.reflect_lantern(far_bank.glow, BRIDGE + Vector2(7, -33))
		day_lighting.place_lamp(layer, RavineLayout.SOUTH_TRAIL_GATE + Vector2(-22, -10), 0.72)
		day_lighting.place_lamp(layer, RAVINE_RELIEF.WEST_GATE_LAMP, 0.94, 0.05)
		day_lighting.place_lamp(layer, RAVINE_RELIEF.LOOKOUT_LAMP, 0.68, 0.12)
	else:
		day_lighting.place_lamp(layer, Vector2(HALL_FOOT) + Vector2(-18, 8), 0.90)
		day_lighting.place_lamp(layer, Vector2(HALL_FOOT) + Vector2(18, 8), 0.90)
		day_lighting.place_lamp(layer, SOUTH_PAVILION + Vector2(27, 12))
		day_lighting.place_lamp(layer, EstateLayout.SOUTH_FORK + Vector2(-15, -14), 0.76)
		day_lighting.place_lamp(layer, EstateLayout.FREIGHT_STOP + Vector2(37, -19), 0.80)
		day_lighting.place_lamp(layer, EstateLayout.FESTIVAL_FORK + Vector2(13, 18), 0.74)
		day_lighting.place_lamp(layer, EstateLayout.FESTIVAL_BANK_BEND + Vector2(-13, 20), 0.70)
		day_lighting.place_lamp(layer, EstateLayout.FESTIVAL_GROUND + Vector2(-33, -35), 0.79, 0.12)
		day_lighting.place_lamp(layer, EstateLayout.FESTIVAL_GROUND + Vector2(112, 69), 0.70, 0.19)
		day_lighting.place_lamp(layer, EstateLayout.DRIVING_START + Vector2(28, -14), 0.78)
		day_lighting.place_lamp(layer, EstateLayout.DRIVING_FINISH + Vector2(-2, -27), 0.76)
		day_lighting.place_lamp(layer, EstateLayout.RAVINE_TRAIL_GATE + Vector2(-16, -17), 0.72)
		day_lighting.place_lamp(layer, Vector2(415, 31))
		day_lighting.place_lamp(layer, Vector2(-286, -4))
		day_lighting.place_lamp(layer, EstateLayout.WEST_COURT_SHELTER + Vector2(-24, 7), 0.78)
		var pond_bank := day_lighting.place_lamp(layer, Vector2(265, 646), 0.74, 0.14)
		water_surface.reflect_lantern(pond_bank.glow, Vector2(267, 655))
	day_lighting.refresh()

static func _place_sprite(layer: Node, foot: Vector2, offset: Vector2, texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.position = foot
	sprite.centered = false
	sprite.offset = offset
	sprite.texture = texture
	layer.add_child(sprite)
	return sprite

func _update_weather() -> void:
	var next_season := Global.season_index()
	if next_season != season or seasonal_textures.is_empty():
		season = next_season
		_update_prop_textures()
	raining = Global.has_rain()
	if not wilderness:
		_refresh_estate_tracks()
	water_surface.set_weather(WATER_TINTS[season], raining)
	_refresh_scenery()

func _refresh_scenery() -> void:
	for sprite in scenery:
		var prop: int = scenery[sprite]
		if seasonal_textures.has(prop):
			sprite.texture = _prop_texture(prop, sprite.position)
		match prop:
			Prop.HALL:
				sprite.visible = _fields_clear(_ground_bounds(sprite.position, prop))
				hall_rest.set_available(sprite.visible)
			Prop.SILK_SHED:
				sprite.visible = Global.silk_workshop.built and _fields_clear(_ground_bounds(sprite.position, prop))
				silk_shed.set_available(sprite.visible)
			_:
				if prop >= 0:
					sprite.visible = wilderness or _ground_clear(_ground_bounds(sprite.position, prop))
		var tint := _prop_tint(prop)
		if not wilderness and sprite.position.y < ESTATE_BOUNDS.position.y - 48.0:
			tint *= Color("#b8c4ba")
		tint.a = sprite.modulate.a
		sprite.modulate = tint
	for sprite in gate_bases:
		gate_bases[sprite].set_deferred("disabled", not sprite.visible)
	if not wilderness:
		for lamp in day_lighting.lamps:
			lamp.visible = _ground_clear(Rect2(to_local(lamp.global_position) - Vector2(4, 2), Vector2(8, 4)))
	_refresh_shortcut_waypost()
	queue_redraw()

func _refresh_shortcut_waypost() -> void:
	if shortcut_waypost != null:
		shortcut_waypost.visible = Global.ravine_shortcut_open() and (
			wilderness or _ground_clear(_ground_bounds(shortcut_waypost.position, Prop.SIGNPOST)))

func _process(delta: float) -> void:
	if not get_tree().paused and not player.conversation_open and not MapTravel.active:
		Global.advance_daylight(delta)
		if wilderness:
			Global.advance_away_field_work(delta)
	day_lighting.refresh(delta)
	_refresh_ambience(delta)

func _refresh_ambience(delta := 0.0) -> void:
	var foot := to_local(player.global_position)
	var creek_distance := absf(foot.x - creek_x(foot.y)) if wilderness else INF
	var fall_proximity := bridge_cascade.update_waterfall(player.global_position, delta) if bridge_cascade else 0.0
	var birds_distance := foot.distance_to(BERRY_GROVE) if wilderness else minf(
		foot.distance_to(HALL_BIRD_TREE), foot.distance_to(PAVILION_BIRD_TREE))
	var cricket_distance := foot.distance_to(BERRY_GROVE if wilderness else SOUTH_PAVILION)
	var under_roof := not wilderness and EstateLayout.PAVILION_SHELTER_FLOOR.has_point(foot)
	AudioManager.set_world_ambience(creek_distance, birds_distance, cricket_distance, under_roof,
		0.78 if wilderness else 1.0, lerpf(1.0, 0.55, fall_proximity))

func _draw_estate_ground() -> void:
	# Road and grass commands stay on this layer when a canal only changes scenery above it.
	if not _scenery_ready:
		return
	_draw_ground(_estate_ground)
	_draw_field_verges(_estate_ground)
	_draw_tracks(_estate_ground)
	var winter := season == Global.Season.WINTER
	estate_terrain.draw_festival_paving(_estate_ground, SEASON_PALETTES[season][0], winter, raining)
	RAVINE_RELIEF.draw_gate(_estate_ground, EstateLayout.EAST_GATE, false, season, raining)
	estate_terrain.draw_gate_paving(_estate_ground, EstateLayout.EAST_GATE + RAVINE_RELIEF.GATE_PAVING.position, winter, raining)

func _draw() -> void:
	if not _scenery_ready:
		return
	if wilderness:
		_draw_ground(self)
		creek_profile.draw_shoulder(self, SEASON_PALETTES[season][0], season, raining)
		RAVINE_BANKS.draw_fishing_shelves(self, season, raining)
		ravine_relief.draw_trail_verges(self, season, raining)
		_draw_tracks(self)
		RAVINE_RELIEF.draw_gate(self, RavineLayout.WEST_GATE, true, season, raining)
		ravine_relief.draw_lookout(self, season, raining)
		creek_profile.draw_water(self, WATER_TINTS[season], season, raining)
		RAVINE_BANKS.draw_banks(self, season, raining)
		ravine_relief.draw_bridge_aprons(self, season, raining)
		_draw_crossings()
	else:
		var winter := season == Global.Season.WINTER
		var dirt := _track_dust()
		_draw_building_shadows()
		if _hall_landing_visible():
			estate_terrain.draw_hall_court(self, dirt, winter, raining)
		if _shed_step_visible():
			estate_terrain.draw_shed_step(self, winter, raining)
		estate_terrain.draw_spring_apron(self, _tile_point(Global.irrigation.source_cell), winter, raining)
		_draw_field_banks()
		if Global.road_provisions_delivered:
			var provisions := Rect2(SOUTH_PAVILION + Vector2(31, 0), Vector2(14, 10))
			draw_texture_rect_region(ESTATE_ART, provisions, Rect2(264, 0, 14, 10))
		if Global.silk_sample_day > 0 and _ground_clear(SILK_SAMPLE_BOUNDS):
			draw_texture_rect(SILK_SAMPLE, SILK_SAMPLE_BOUNDS, false, _prop_tint(-1))
	var shade := scenery_shade(raining)
	for sprite: Sprite2D in scenery:
		if sprite.visible:
			draw_sorted_prop_shadow(self, sprite.position, scenery[sprite], shade, raining)
	for prop in props:
		if prop.z in SORTED_PROPS:
			continue
		if season == Global.Season.WINTER and prop.z in DORMANT_PROPS:
			continue
		var foot := Vector2(prop.x, prop.y)
		var bounds := _prop_bounds(foot, prop.z)
		if not wilderness and not _ground_clear(bounds):
			continue
		draw_scenery_shadow(self, foot, prop.z, shade)
		_stamp(bounds, prop.z)

func _on_footstep(at: Vector2) -> void:
	_play_step(at, player.footstep_contact(at), player.get_real_velocity())

func _play_step(at: Vector2, contact: Vector2, movement: Vector2) -> void:
	var foot := to_local(at)
	var shoe := to_local(contact)
	if Global.is_indoors():
		var path := ^"SilkInterior" if Global.estate_room == Global.EstateRoom.SILK_SHED else ^"HallInterior"
		var room := get_parent().get_node_or_null(path)
		var stone: bool = room != null and room.on_stone_threshold(to_global(shoe))
		terrain_audio.play_step(TERRAIN_AUDIO.Surface.STONE if stone else TERRAIN_AUDIO.Surface.PLANK)
		return
	var surface := _surface_at(shoe if wilderness else foot)
	terrain_audio.play_step(surface)
	_show_ground_contact(footstep_effects, surface, foot, shoe, movement)

func show_resident_step(contact: Vector2, movement: Vector2) -> void:
	if Global.is_indoors() or not resident_footsteps.is_contact_near_view(contact):
		return
	var shoe := to_local(contact)
	_show_ground_contact(resident_footsteps, _surface_at(shoe), shoe, shoe, movement)

func _show_ground_contact(effects: FOOTSTEP_EFFECTS, surface: TERRAIN_AUDIO.Surface,
		foot: Vector2, shoe: Vector2, movement: Vector2) -> void:
	match surface:
		TERRAIN_AUDIO.Surface.SNOW:
			effects.leave_snow(shoe, movement)
		TERRAIN_AUDIO.Surface.SHALLOWS:
			effects.splash(shoe, movement, ford_shoal, ford_stones)
		TERRAIN_AUDIO.Surface.TRACK:
			if not raining and (wilderness or _ground_clear(Rect2(foot, Vector2.ONE))):
				effects.lift_dust(shoe, movement)

func _surface_at(foot: Vector2) -> TERRAIN_AUDIO.Surface:
	if wilderness:
		if BRIDGE_DECK.has_point(foot):
			return TERRAIN_AUDIO.Surface.PLANK
		if FORD_AREA.has_point(foot):
			for stone in ford_stones:
				if Geometry2D.is_point_in_polygon(foot, stone):
					return TERRAIN_AUDIO.Surface.STONE
			if Geometry2D.is_point_in_polygon(foot, ford_shoal):
				return TERRAIN_AUDIO.Surface.SHALLOWS
		if (RAVINE_RELIEF.gate_stone_at(foot, RavineLayout.WEST_GATE)
				or ravine_relief.lookout_stone_at(foot) or ravine_relief.approach_stone_at(foot)):
			return TERRAIN_AUDIO.Surface.STONE
	else:
		if EstateLayout.PAVILION_SHELTER_FLOOR.has_point(foot) \
				or get_parent().irrigation_overlay.footbridge_at(to_global(foot)):
			return TERRAIN_AUDIO.Surface.PLANK
		for field in Global.well_fields:
			var area := _field_bounds(field["center_pos"])
			if not field["is_unlocked"]:
				if area.has_point(foot):
					return TERRAIN_AUDIO.Surface.GRASS
				continue
			if _field_step_bounds(area, field_entrance(field["field_id"])).has_point(foot):
				return TERRAIN_AUDIO.Surface.STONE
			if area.has_point(foot):
				return TERRAIN_AUDIO.Surface.TRACK
		if pond_landing.visible and EstateLayout.POND_DECK.has_point(foot):
			return TERRAIN_AUDIO.Surface.PLANK
		if estate_terrain.festival_stone_at(foot):
			return TERRAIN_AUDIO.Surface.STONE
		if RAVINE_RELIEF.gate_stone_at(foot, EstateLayout.EAST_GATE):
			return TERRAIN_AUDIO.Surface.STONE
		if estate_terrain.hall_stone_at(foot) and _hall_landing_visible():
			return TERRAIN_AUDIO.Surface.STONE
		if estate_terrain.shed_stone_at(foot) and _shed_step_visible():
			return TERRAIN_AUDIO.Surface.STONE
		if estate_terrain.spring_stone_at(foot - _tile_point(Global.irrigation.source_cell)):
			return TERRAIN_AUDIO.Surface.STONE
	for track in track_shapes:
		var outline: PackedVector2Array = track.shoulder if season == Global.Season.WINTER else track.surface
		if Geometry2D.is_point_in_polygon(foot, outline):
			return TERRAIN_AUDIO.Surface.TRACK
	if season == Global.Season.WINTER and ground_cover.has_snow(foot):
		if wilderness or _ground_clear(Rect2(foot, Vector2.ONE)):
			return TERRAIN_AUDIO.Surface.SNOW
	return TERRAIN_AUDIO.Surface.GRASS

func _draw_ground(canvas: CanvasItem) -> void:
	var colors: Array = SEASON_PALETTES[season]
	var meadow: Color = colors[0]
	var shade: Color = colors[1]
	var sun: Color = colors[2]
	if wilderness:
		meadow = meadow.darkened(0.14)
		sun = sun.darkened(0.12)
	if raining:
		meadow = meadow.lerp(Color("#344c4c"), 0.34)
		shade = shade.lerp(Color("#314344"), 0.25)
		sun = sun.lerp(Color("#3f5750"), 0.28)
	ESTATE_TERRAIN.draw_grass(canvas, MAP_BACKDROP, season, raining, wilderness)
	var winter := season == Global.Season.WINTER
	var ground_shade := shade if wilderness else shade.lerp(meadow, 0.26)
	ground_cover.draw_cover(canvas, ground_shade, sun, winter)
	ground_cover.draw_marks(canvas, season, raining)
	if estate_terrain:
		estate_terrain.draw_meadow(canvas, season, raining)
		estate_terrain.draw_farm_yard(canvas, meadow, season, raining)
	var ground_tint: Color = LEAF_TINTS[season]
	if wilderness:
		ground_tint *= Color(0.87, 0.96, 0.95)
	if raining:
		ground_tint *= Color(0.88, 0.94, 0.99)
	if winter:
		ground_tint.a = 0.31
	_draw_prop_litter(canvas, ground_tint)
	if estate_terrain:
		canvas.draw_texture_rect_region(ESTATE_TERRAIN.HALL_YARD_ART, Rect2(HALL_YARD_GROUND_AT, HALL_YARD_GROUND.size),
			HALL_YARD_GROUND, ground_tint)
		estate_terrain.draw_north_bank(canvas, MAP_BACKDROP.position.y, shade, sun, winter)
		south_pond.draw_bed(canvas)
	var grass := shade.lightened(0.09)
	for prop in props:
		if SCENERY_SHADOW_SIZES.has(prop.z):
			continue
		if prop.z in LEAFY_PROPS and (not winter or prop.z not in DORMANT_PROPS):
			var patch := Vector2(prop.x, prop.y)
			if winter and ground_cover.has_snow(patch):
				continue
			canvas.draw_rect(Rect2(patch + Vector2(-14, 0), Vector2(28, 4)), Color(grass, 0.62))
			canvas.draw_rect(Rect2(patch + Vector2(-10, 4), Vector2(19, 2)), Color(grass, 0.57))

func _draw_prop_litter(canvas: CanvasItem, tint: Color) -> void:
	for placement in props:
		if not CANOPY_SHADOW_SCALE.has(placement.z) and placement.z not in ROCK_PROPS:
			continue
		var foot := Vector2(placement.x, placement.y)
		if not wilderness and HALL_YARD_AREA.has_point(foot):
			continue
		canvas.draw_texture_rect_region(ESTATE_ART, Rect2(foot - Vector2(30, 20), ESTATE_LEAF_LITTER.size),
			ESTATE_LEAF_LITTER, tint)

func _track_dust() -> Color:
	var dust: Color = SEASON_PALETTES[season][3]
	if wilderness:
		dust = dust.darkened(0.12)
	if raining:
		dust = dust.darkened(0.18)
	return dust

func _build_track_shapes(tracks: Array, widths: Array[float], field_count := 0) -> void:
	track_shapes.clear()
	for index in range(tracks.size()):
		var points := PackedVector2Array(tracks[index])
		var samples := _sample_track(points)
		var radius := widths[index] * 0.5
		var entrance := Vector2.ZERO
		if index >= ESTATE_TRACKS.size() and index < ESTATE_TRACKS.size() + field_count:
			entrance = points[-2].direction_to(points[-1])
		var gravel_path := points if wilderness else samples
		var crossing_bounds := Rect2(gravel_path[0], Vector2.ZERO)
		for point in gravel_path:
			crossing_bounds = crossing_bounds.expand(point)
		track_shapes.append({
			"shoulder": _track_outline(samples, radius + EstateLayout.ROAD_SHOULDER, index, entrance),
			"edge": _track_outline(samples, radius + 1.0, index, entrance),
			"surface": _track_outline(samples, radius, index, entrance),
			"gravel_path": gravel_path,
			"crossing_bounds": crossing_bounds,
			"width": widths[index],
		})

func track_crossing(start: Vector2, finish: Vector2) -> Variant:
	var channel_bounds := Rect2(start, finish - start).abs()
	var channel_direction := start.direction_to(finish)
	for track in track_shapes:
		var bounds: Rect2 = track.crossing_bounds
		if not bounds.intersects(channel_bounds, true):
			continue
		var line: PackedVector2Array = track.gravel_path
		for index in range(1, line.size()):
			var from := line[index - 1]
			var to := line[index]
			if absf(channel_direction.dot(from.direction_to(to))) > 0.60:
				continue
			var crossing: Variant = Geometry2D.segment_intersects_segment(start, finish, from, to)
			if crossing != null:
				return crossing
	return null

func _sample_track(points: PackedVector2Array) -> PackedVector2Array:
	if not wilderness:
		return EstateLayout.sample_road(points)
	var samples := PackedVector2Array()
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var sections := maxi(1, ceili(start.distance_to(finish) / 8.0))
		for part in sections:
			samples.append(start.lerp(finish, float(part) / sections))
	samples.append(points[-1])
	return samples

func _track_outline(samples: PackedVector2Array, radius: float, seed_offset: int, entrance: Vector2) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var end := samples.size() - 1
	var phase := float(seed_offset) * 0.81
	for index in samples.size():
		var point := samples[index]
		var direction := samples[maxi(0, index - 1)].direction_to(samples[mini(end, index + 1)])
		var at_field := entrance != Vector2.ZERO and index == end
		if at_field:
			direction = entrance
		var normal := direction.orthogonal()
		var taper := lerpf(0.39, 1.0, smoothstep(0.0, 3.0, mini(index, end - index))) if wilderness else 1.0
		var left_edge := 0.0 if at_field else 0.79 * sin(index * 0.49 + phase) + 0.37 * sin(index * 1.37 + phase * 0.73)
		var right_edge := 0.0 if at_field else 0.83 * sin(index * 0.42 - phase + 1.6) + 0.37 * sin(index * 1.25 + phase)
		left.append(point + normal * (radius + left_edge) * taper)
		right.append(point - normal * (radius + right_edge) * taper)
	if not wilderness and entrance == Vector2.ZERO:
		_append_track_cap(left, samples[end], left[-1], right[-1], samples[end - 1].direction_to(samples[end]))
	right.reverse()
	left.append_array(right)
	if not wilderness:
		_append_track_cap(left, samples[0], right[-1], left[0], samples[1].direction_to(samples[0]))
	return left

func _append_track_cap(outline: PackedVector2Array, tip: Vector2, first: Vector2, last: Vector2, outward: Vector2) -> void:
	var depth := first.distance_to(last) * 0.5
	for segment in range(1, 6):
		var part := float(segment) / 6.0
		var side := (first - tip).lerp(tip - last, part)
		outline.append(tip + side * cos(part * PI) + outward * depth * sin(part * PI))

func _draw_tracks(canvas: CanvasItem) -> void:
	var dust := _track_dust()
	var verge: Color = SEASON_PALETTES[season][0]
	if raining:
		verge = verge.darkened(0.15)
	var grain := ESTATE_TERRAIN.trail_texture() if wilderness else ESTATE_TERRAIN.TRACK_GRAIN
	for track in track_shapes:
		ESTATE_TERRAIN.draw_loam(canvas, track.shoulder, dust.lerp(verge, 0.69), grain)
	for track in track_shapes:
		ESTATE_TERRAIN.draw_verge(canvas, track.gravel_path, track.width, season, raining)
	for track in track_shapes:
		ESTATE_TERRAIN.draw_loam(canvas, track.edge, dust.lerp(verge, 0.41), grain)
	for track in track_shapes:
		ESTATE_TERRAIN.draw_loam(canvas, track.surface, dust, grain)
	for track in track_shapes:
		_track_gravel(canvas, track.gravel_path, track.width, dust)

static func scenery_shade(rain: bool) -> Color:
	var shade := Color("#27392f")
	shade.a = 0.20 if rain else 0.38
	return shade

static func draw_scenery_shadow(canvas: CanvasItem, foot: Vector2, prop: int, shade: Color) -> void:
	if not SCENERY_SHADOW_SIZES.has(prop):
		return
	var half_size: Vector2 = SCENERY_SHADOW_SIZES[prop]
	var outline := PackedVector2Array()
	for point: Vector2 in SCENERY_SHADOW_PROFILE:
		outline.append((foot + point * half_size).snapped(Vector2(0.5, 0.5)))
	canvas.draw_colored_polygon(outline, shade)

static func draw_sorted_prop_shadow(canvas: CanvasItem, foot: Vector2, prop: int, shade: Color, wet: bool) -> void:
	var tint := Color(1.0, 1.0, 1.0, 0.55) if wet else Color.WHITE
	if prop in ROCK_PROPS:
		canvas.draw_texture_rect_region(ESTATE_TERRAIN.HALL_YARD_ART,
			Rect2(foot - Vector2(15, 5), HALL_YARD_STONE_SHADOW.size), HALL_YARD_STONE_SHADOW, tint)
		return
	if CANOPY_SHADOW_SCALE.has(prop):
		var scale: float = CANOPY_SHADOW_SCALE[prop]
		canvas.draw_texture_rect_region(ESTATE_TERRAIN.HALL_YARD_ART,
			Rect2(foot - Vector2(15, 5) * scale, Vector2(32, 13) * scale), HALL_YARD_CANOPY_SHADOW, tint)
		return
	draw_scenery_shadow(canvas, foot, prop, shade)

func _draw_building_shadows() -> void:
	var ground_shadow := Color("#26352c")
	ground_shadow.a = 0.20 if raining else 0.37
	for sprite: Sprite2D in scenery:
		var mark: int = scenery[sprite]
		if not sprite.visible or not BUILDING_SHADOWS.has(mark):
			continue
		var outline := PackedVector2Array()
		for point: Vector2 in BUILDING_SHADOWS[mark]:
			outline.append(sprite.position + point)
		draw_colored_polygon(outline, ground_shadow)

func _hall_landing_visible() -> bool:
	return hall_rest != null and hall_rest.visible and _fields_clear(HALL_LANDING)

func _shed_step_visible() -> bool:
	return silk_shed != null and silk_shed.visible and _ground_clear(ESTATE_TERRAIN.SHED_STEP_BOUNDS)

func _track_gravel(canvas: CanvasItem, points: PackedVector2Array, width: float, dust: Color) -> void:
	for index in range(points.size() - 1):
		var step := points[index + 1] - points[index]
		var normal := step.normalized().orthogonal()
		var marks := maxi(1, floori(step.length() / 9.0))
		for mark in range(marks):
			var scatter := posmod(index * 7 + mark * 13, 19)
			var across := (float(scatter) / 18.0 - 0.5) * width * 0.66
			var point := points[index] + step * ((mark + 0.55) / marks) + normal * across
			var width_px := 1 + scatter % 4
			if not wilderness and scatter % 5 == 1:
				continue
			canvas.draw_rect(Rect2(point.round(), Vector2(width_px, 1)),
				dust.lightened(0.20) if scatter % 3 == 0 else dust.darkened(0.13))

func _draw_field_verges(canvas: CanvasItem) -> void:
	var verge: Color = SEASON_PALETTES[season][0]
	var dust := _track_dust()
	if raining:
		verge = verge.lerp(Color("#344c4c"), 0.34)
	for field in Global.well_fields:
		var area := _field_bounds(field["center_pos"])
		var entrance := field_entrance(field["field_id"])
		ESTATE_TERRAIN.draw_loam(canvas, _field_verge_outline(area.grow(6.0), entrance),
			verge.lerp(dust, 0.36), ESTATE_TERRAIN.TRACK_GRAIN)

func _draw_field_banks() -> void:
	var dust := _track_dust()
	var grass: Color = SEASON_PALETTES[season][0]
	var frost := season == Global.Season.WINTER
	for field in Global.well_fields:
		if not field["is_unlocked"]:
			continue
		var area := _field_bounds(field["center_pos"])
		var entrance := field_entrance(field["field_id"])
		var edge := EstateLayout.field_boundary(area, entrance, EstateLayout.FIELD_ENTRANCE_WIDTH)
		for index in range(1, edge.size()):
			_draw_field_bank_face(area, edge[index - 1], edge[index], dust, grass, frost)
		if entrance != Vector2.ZERO:
			_draw_field_step(area, entrance, dust, frost)

func _draw_field_bank_face(area: Rect2, start: Vector2, finish: Vector2, soil: Color, grass: Color, frost: bool) -> void:
	var along := start.direction_to(finish)
	var outward := Vector2(along.y, -along.x)
	var side := EstateLayout.EDGE_NORMALS.find(outward)
	var depth: float = FIELD_BANK_DEPTH[side]
	var half_span := along.abs().dot(area.size) * 0.5
	var corner_a := -along * FIELD_BANK_DEPTH[posmod(side - 1, 4)]
	var corner_b := along * FIELD_BANK_DEPTH[posmod(side + 1, 4)]
	var toe_a := start + outward * depth
	var toe_b := finish + outward * depth
	if absf((start - area.get_center()).dot(along)) == half_span:
		toe_a += corner_a
	if absf((finish - area.get_center()).dot(along)) == half_span:
		toe_b += corner_b
	var lit := side == 0 or side == 3
	var face := soil.darkened(0.25 if lit else 0.43)
	var shoulder := start.lerp(finish, 0.26) + outward * (depth + 0.8)
	var hollow := start.lerp(finish, 0.61) + outward * (depth - 0.7)
	var skirt := start.lerp(finish, 0.80) + outward * (depth + 0.6)
	draw_colored_polygon(PackedVector2Array([start, finish, toe_b, skirt, hollow, shoulder, toe_a]), face)
	var crest := soil.lightened(0.13) if lit else soil.darkened(0.08)
	draw_colored_polygon(PackedVector2Array([start, finish, finish + (toe_b - finish) * 0.32,
		start.lerp(finish, 0.69) + outward * 1.3, start.lerp(finish, 0.30) + outward * 0.9,
		start + (toe_a - start) * 0.32]), crest)
	var roots := grass.lightened(0.11).lerp(crest, 0.20) if not frost else Color("#a3a991").lerp(crest, 0.44)
	if not lit:
		roots = roots.darkened(0.15)
	var accents := PackedVector2Array([shoulder, skirt])
	for at in accents:
		var tip := at - outward * 1.5
		draw_colored_polygon(PackedVector2Array([at - along * 2.8, tip - along * 1.1,
			tip + along * 0.7 - outward * 0.6, at + along * 2.6]), roots)
	if not lit:
		for section: float in [0.18, 0.62]:
			var clay := start.lerp(finish, section) + outward * (depth * 0.52)
			var run := along * minf(7.0, start.distance_to(finish) * 0.27)
			draw_line(clay, clay + run + outward * 0.65, soil.darkened(0.24), 0.85)
			var shard := clay + run * 0.52 + outward * 0.9
			draw_colored_polygon(PackedVector2Array([shard - along * 1.55,
				shard - outward * 0.75, shard + along * 1.35, shard + outward * 0.5]), soil.lerp(Color("#aca38c"), 0.40))

func _field_step_bounds(area: Rect2, entrance: Vector2) -> Rect2:
	if entrance == Vector2.ZERO:
		return Rect2()
	var size := Vector2(14.0, 8.0) if entrance.y != 0.0 else Vector2(8.0, 14.0)
	var mouth := area.get_center() + entrance * area.size * 0.5
	return Rect2(mouth + entrance * 4.0 - size * 0.5, size)

func _draw_field_step(area: Rect2, entrance: Vector2, soil: Color, frost: bool) -> void:
	var landing := _field_step_bounds(area, entrance)
	var way := landing.get_center()
	var across := Vector2(entrance.y, -entrance.x)
	var stone := soil.lerp(Color("#a4a18b"), 0.66)
	var lower := PackedVector2Array([way - across * 6.4 - entrance * 0.8, way + across * 5.9 - entrance * 0.8,
		way + across * 7.0 + entrance * 1.8, way + across * 5.0 + entrance * 3.7,
		way - across * 4.6 + entrance * 3.9, way - across * 6.7 + entrance * 2.6])
	draw_colored_polygon(lower, stone.darkened(0.12))
	var upper := PackedVector2Array([way - across * 5.2 - entrance * 4.0, way + across * 4.7 - entrance * 4.0,
		way + across * 6.5 - entrance * 2.1, way + across * 5.4 + entrance * 0.1,
		way - across * 5.4 + entrance * 0.4, way - across * 6.9 - entrance * 1.5])
	draw_colored_polygon(PackedVector2Array([upper[3], upper[4], upper[4] + entrance * 1.2,
		upper[3] + entrance * 1.6]), stone.darkened(0.32))
	draw_colored_polygon(upper, stone)
	draw_line(way + across * 1.1 - entrance * 3.5, way + across * 0.5 + entrance * 0.3, stone.darkened(0.24), 0.65)
	var gleam := stone.lerp(Color("#c0c2a4"), 0.68 if frost else 0.35)
	draw_line(upper[4].lerp(upper[3], 0.10), upper[4].lerp(upper[3], 0.68), gleam, 0.75)
	draw_line(lower[4].lerp(lower[3], 0.19), lower[4].lerp(lower[3], 0.79), stone.darkened(0.24), 0.65)

func _field_verge_outline(area: Rect2, entrance: Vector2) -> PackedVector2Array:
	var corners := EstateLayout.corners(area)
	var outline := PackedVector2Array()
	for side in 4:
		var start := corners[side]
		var finish := corners[(side + 1) % 4]
		var along := start.direction_to(finish)
		outline.append(start + along * 5.0)
		if EstateLayout.EDGE_NORMALS[side] == entrance:
			var middle := start.lerp(finish, 0.5)
			var half_opening := along * EstateLayout.FIELD_ENTRANCE_WIDTH * 0.5
			var lip := middle - half_opening
			var far_lip := middle + half_opening
			outline.append_array(PackedVector2Array([lip, lip - entrance * 6.0,
				far_lip - entrance * 6.0, far_lip]))
		outline.append(finish - along * 5.0)
	return outline

func _draw_crossings() -> void:
	RAVINE_BANKS.draw_ford(self, ford_shoal, WATER_TINTS[season], season, raining)

static func _ford_outline() -> PackedVector2Array:
	var shoal := PackedVector2Array()
	var edge_y: Array[float] = [-17.0, -12.0, -6.0, 4.0, 12.0, 17.0]
	var half_widths: Array[float] = [5.0, 12.0, 18.0, 18.0, 13.0, 7.0]
	for i in edge_y.size():
		var y := FORD.y + edge_y[i]
		shoal.append(Vector2(roundf(creek_x(y)) - half_widths[i], y))
	for i in range(edge_y.size() - 1, -1, -1):
		var y := FORD.y + edge_y[i]
		shoal.append(Vector2(roundf(creek_x(y)) + half_widths[i], y))
	return shoal

static func creek_x(y: float) -> float:
	for i in range(1, CREEK.size()):
		var a: Vector2 = CREEK[i - 1]
		var b: Vector2 = CREEK[i]
		if y <= b.y:
			return lerpf(a.x, b.x, clampf(inverse_lerp(a.y, b.y, y), 0.0, 1.0))
	return CREEK.back().x

func _ribbon(line: PackedVector2Array, half_width: float) -> PackedVector2Array:
	var band := PackedVector2Array()
	for point in line:
		band.append(point - Vector2(half_width, 0))
	for i in range(line.size() - 1, -1, -1):
		var point := line[i]
		band.append(point + Vector2(half_width, 0))
	return band

func _install_boundaries() -> void:
	var bounds := WILD_BOUNDS if wilderness else ESTATE_BOUNDS
	var terrain := StaticBody2D.new()
	terrain.name = "TerrainEdges"
	terrain.collision_mask = 0
	add_child(terrain)
	var center := bounds.get_center()
	_add_edge(terrain, Vector2(bounds.position.x - 12, center.y), Vector2(24, bounds.size.y + 48))
	_add_edge(terrain, Vector2(bounds.end.x + 12, center.y), Vector2(24, bounds.size.y + 48))
	_add_edge(terrain, Vector2(center.x, bounds.position.y - 12), Vector2(bounds.size.x + 48, 24))
	_add_edge(terrain, Vector2(center.x, bounds.end.y + 12), Vector2(bounds.size.x + 48, 24))
	for sprite in scenery:
		var prop := scenery[sprite]
		if prop in [Prop.GATE, Prop.GATE_FAR]:
			var base := _ground_bounds(sprite.position, prop)
			gate_bases[sprite] = _add_edge(terrain, base.get_center(), base.size)
		elif wilderness and prop == Prop.BOULDER:
			var base := _add_edge(terrain, sprite.position + Vector2(0, -5), Vector2(23, 12))
			base.name = "RavineBoulder"
	if wilderness:
		RAVINE_RELIEF.install_ravine_edges(terrain)
		_block_water(terrain, bounds.position.y - 12, BRIDGE.y - CROSSING_HALF_DEPTH)
		_block_water(terrain, BRIDGE.y + CROSSING_HALF_DEPTH, FORD.y - CROSSING_HALF_DEPTH)
		_block_water(terrain, FORD.y + CROSSING_HALF_DEPTH, bounds.end.y + 12)
	else:
		RAVINE_RELIEF.install_estate_edge(terrain)
		var pond := CollisionPolygon2D.new()
		pond.name = "SouthPond"
		_update_pond_collision(pond)
		GameEvents.pond_landing_opened.connect(_update_pond_collision.bind(pond))
		terrain.add_child(pond)

	var camera := player.get_node("Camera2D") as Camera2D
	var view := bounds.grow(125)
	camera.limit_left = floori(view.position.x if wilderness else view.position.x - 60.0)
	camera.limit_right = ceili(view.end.x)
	camera.limit_top = floori(view.position.y)
	camera.limit_bottom = ceili(view.end.y if wilderness else bounds.end.y + 62.0)
	camera.force_update_scroll()

func _update_pond_collision(edge: CollisionPolygon2D) -> void:
	var bank := estate_terrain.pond
	if pond_landing.visible:
		# This ramp opens a single notch in the shore. The deck rails close its other sides.
		bank = Geometry2D.clip_polygons(bank, EstateLayout.corners(EstateLayout.POND_DECK))[0]
	edge.polygon = bank

func _add_edge(terrain: StaticBody2D, at: Vector2, size: Vector2) -> CollisionShape2D:
	var edge := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	edge.shape = shape
	edge.position = at
	terrain.add_child(edge)
	return edge

func _block_water(terrain: StaticBody2D, top: float, bottom: float) -> void:
	var line := PackedVector2Array([Vector2(creek_x(top), top)])
	for point: Vector2 in CREEK:
		if point.y > top and point.y < bottom:
			line.append(point)
	line.append(Vector2(creek_x(bottom), bottom))
	var bank := CollisionPolygon2D.new()
	bank.polygon = _ribbon(line, WATER_HALF_WIDTH)
	terrain.add_child(bank)

func _prop_bounds(foot: Vector2, index: int) -> Rect2:
	if BUILDING_REGIONS.has(index):
		var size: Vector2 = BUILDING_REGIONS[index].size
		return Rect2(foot + _building_offset(size), size)
	if RIVERSIDE_REGIONS.has(index) or EXTERNAL_REGIONS.has(index) or STONE_REGIONS.has(index):
		var size := _scenery_region(index).size
		return Rect2(foot - Vector2(size.x / 2.0, size.y - 2.0), size)
	return Rect2(foot - PROP_ANCHOR, PROP_SIZE)

func _building_offset(size: Vector2) -> Vector2:
	return Vector2(-size.x * 0.5, 4.0 - size.y)

func _ground_bounds(foot: Vector2, index: int) -> Rect2:
	if BUILDING_FOOTPRINTS.has(index):
		var footprint: Rect2 = BUILDING_FOOTPRINTS[index]
		return Rect2(foot + footprint.position, footprint.size)
	return _prop_bounds(foot, index)

func _stamp(bounds: Rect2, index: int) -> void:
	if painted_textures.has(index):
		draw_texture_rect(painted_textures[index], bounds, false, _prop_tint(index))
		return
	draw_texture_rect_region(_prop_sheet(index), bounds, _scenery_region(index, season), _prop_tint(index))

func _scenery_region(index: int, at_season := -1) -> Rect2:
	if BUILDING_REGIONS.has(index):
		return BUILDING_REGIONS[index]
	if RIVERSIDE_REGIONS.has(index):
		return riverside_region(index, at_season)
	if EXTERNAL_REGIONS.has(index):
		return EXTERNAL_REGIONS[index]
	if STONE_REGIONS.has(index):
		return STONE_REGIONS[index]
	var frame := Vector2(index % PROP_COLUMNS, floori(float(index) / PROP_COLUMNS))
	return Rect2(frame * PROP_SIZE, PROP_SIZE)

func _prop_sheet(index: int) -> Texture2D:
	if BUILDING_REGIONS.has(index):
		return ESTATE_BUILDINGS
	if STORAGE_TINTS.has(index):
		return ESTATE_STORAGE
	if RIVERSIDE_REGIONS.has(index):
		return RIVERSIDE_PLANTS
	if MEADOW_FLOWERS.has(index):
		return MEADOW_FLOWERS[index]
	return NINJA_SCENERY if EXTERNAL_REGIONS.has(index) else SCENERY

func _prop_texture(index: int, foot: Vector2) -> AtlasTexture:
	if painted_textures.has(index):
		var in_hall_yard := not wilderness and HALL_YARD_AREA.has_point(foot)
		var alternate := posmod(roundi(foot.x + foot.y), 2) == 0
		if index == Prop.ROCK:
			var low := foot.y > HALL_FOOT.y if in_hall_yard else alternate
			return low_stone_texture if low else painted_textures[index]
		if index == Prop.OAK and not in_hall_yard and alternate:
			return forked_oak_texture
		return painted_textures[index]
	if seasonal_textures.has(index):
		return seasonal_textures[index]
	return atlas_texture(_prop_sheet(index), _scenery_region(index))

func _update_prop_textures() -> void:
	for prop in [Prop.OAK, Prop.BLOSSOM_TREE, Prop.PINE, Prop.GROVE_TREE, Prop.GROVE_CLUSTER]:
		seasonal_textures[prop] = tree_texture(prop, season)
	for prop: int in RIVERSIDE_REGIONS:
		seasonal_textures[prop] = painted_riverside_texture(prop, season) if ESTATE_RIVER_REGIONS.has(prop) \
			else riverside_texture(prop, season)
	for prop: int in HALL_YARD_REGIONS:
		var region: Rect2 = HALL_YARD_REGIONS[prop]
		if seasonal_textures.has(prop):
			region.position.x += season * region.size.x
		painted_textures[prop] = atlas_texture(ESTATE_TERRAIN.HALL_YARD_ART, region)
	low_stone_texture = atlas_texture(ESTATE_TERRAIN.HALL_YARD_ART, Rect2(176, 0, 48, 48))
	forked_oak_texture = atlas_texture(ESTATE_ART, Rect2(season * 48, 152, 48, 48))
	painted_textures[Prop.GROVE_CLUSTER] = atlas_texture(ESTATE_ART, Rect2(season * 64, 200, 64, 48))
	for prop: int in ESTATE_SITE_REGIONS:
		painted_textures[prop] = atlas_texture(ESTATE_ART, ESTATE_SITE_REGIONS[prop])
	for prop: int in ESTATE_RIVER_REGIONS:
		painted_textures[prop] = seasonal_textures[prop]
	for prop: int in STORAGE_TINTS:
		painted_textures[prop] = atlas_texture(ESTATE_VESSELS, EXTERNAL_REGIONS[prop])
	if wilderness:
		painted_textures[Prop.PINE] = painted_tree_texture(Prop.PINE, season)
		painted_textures[Prop.RAVINE_SHOOT] = atlas_texture(RAVINE_ART, Rect2(146, 50, 14, 18))
		painted_textures[Prop.STUMP] = atlas_texture(RAVINE_ART, Rect2(164, 50, 16, 16))

static func painted_tree_texture(prop: int, season_index: int, forked := false) -> AtlasTexture:
	if prop == Prop.PINE:
		return atlas_texture(RAVINE_ART, Rect2(248 if season_index == Global.Season.WINTER else 200, 0, 48, 48))
	if prop == Prop.OAK and forked:
		return atlas_texture(ESTATE_ART, Rect2(48 * season_index, 152, 48, 48))
	var region: Rect2 = HALL_YARD_REGIONS[prop]
	region.position.x += season_index * region.size.x
	return atlas_texture(ESTATE_TERRAIN.HALL_YARD_ART, region)

static func painted_riverside_texture(prop: int, season_index: int) -> AtlasTexture:
	if BAMBOO_FRAMES.has(prop):
		var clump: Rect2 = BAMBOO_FRAMES[prop]
		if season_index == Global.Season.WINTER:
			clump.position.y += 48
		return atlas_texture(load(BAMBOO_ART_PATH), clump)
	var region: Rect2 = ESTATE_RIVER_REGIONS[prop]
	if season_index == Global.Season.WINTER:
		region.position.y += RIVERSIDE_WINTER_ROW
	return atlas_texture(ESTATE_ART, region)

static func riverside_texture(prop: int, season_index: int) -> AtlasTexture:
	return atlas_texture(RIVERSIDE_PLANTS, riverside_region(prop, season_index))

static func riverside_region(prop: int, season_index: int) -> Rect2:
	var region: Rect2 = RIVERSIDE_REGIONS[prop]
	if season_index == Global.Season.WINTER and prop not in DORMANT_PROPS:
		region.position.y += RIVERSIDE_WINTER_ROW
	return region

static func riverside_tint(season_index: int, wet: bool) -> Color:
	var tint := Color.WHITE
	if season_index == Global.Season.AUTUMN:
		tint = Color(1.12, 0.94, 0.69)
	elif season_index == Global.Season.SUMMER:
		tint = Color(1.0, 1.08, 0.97)
	return tint * Color(0.88, 0.94, 0.99) if wet else tint

static func tree_texture(prop: int, season_index: int) -> AtlasTexture:
	if WOODLAND_REGIONS.has(prop):
		var region: Rect2 = WOODLAND_REGIONS[prop]
		if season_index == Global.Season.WINTER:
			region.position.y += 48.0
		return atlas_texture(WOODLAND, region)
	var frame: Vector2 = ORCHARD_FRAMES[season_index] if prop == Prop.BLOSSOM_TREE else Vector2(season_index, 0)
	return atlas_texture(SEASONAL_TREES, Rect2(frame * PROP_SIZE, PROP_SIZE))

static func attach_prop_wind(wind: FOLIAGE_WIND, sprite: Sprite2D, prop: int) -> void:
	wind.attach(sprite, WIND_FLEXIBILITY[prop], DRIFT_CROWNS.get(prop, FOLIAGE_WIND.Crown.NONE))

static func atlas_texture(source: Texture2D, region: Rect2) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = source
	result.region = region
	result.filter_clip = true
	return result

func _prop_tint(index: int) -> Color:
	if painted_textures.has(index):
		if ESTATE_RIVER_REGIONS.has(index) or index == Prop.SHRUB:
			return riverside_tint(season, raining)
		var wet := Color(0.88, 0.94, 0.99) if raining else Color.WHITE
		return wet * WINTER_ROCK_TINT if season == Global.Season.WINTER and index in ROCK_PROPS else wet
	if RIVERSIDE_REGIONS.has(index):
		return riverside_tint(season, raining)
	if WOODLAND_REGIONS.has(index):
		var woodland: Color = LEAF_TINTS[season] if index != Prop.PINE and season != Global.Season.WINTER else Color.WHITE
		return woodland * Color(0.88, 0.94, 0.99) if raining else woodland
	var painted_tree := index == Prop.OAK or index == Prop.BLOSSOM_TREE
	if painted_tree:
		return Color(0.88, 0.94, 0.99) if raining else Color.WHITE
	var tint := Color.WHITE
	if STORAGE_TINTS.has(index):
		tint = STORAGE_TINTS[index]
	elif MEADOW_FLOWERS.has(index):
		tint = Color(0.86, 0.87, 0.79)
	elif index == Prop.STUMP:
		tint = Color(0.75, 0.76, 0.82)
	elif EXTERNAL_REGIONS.has(index):
		tint = NINJA_TINT
	if season == Global.Season.WINTER and index in ROCK_PROPS:
		tint *= WINTER_ROCK_TINT
	if index in LEAFY_PROPS:
		tint *= LEAF_TINTS[season]
	if raining:
		tint *= Color(0.88, 0.94, 0.99)
	return tint

func _fields_clear(artwork: Rect2) -> bool:
	for field in Global.well_fields:
		if artwork.intersects(_field_bounds(field["center_pos"])):
			return false
	return true

func _ground_clear(artwork: Rect2) -> bool:
	if not _fields_clear(artwork):
		return false
	var area := artwork.grow(tile_map.tile_set.tile_size.x * 0.5)
	var network := Global.irrigation
	if area.has_point(_tile_point(network.source_cell)):
		return false
	var channels := network.channels
	if channels.size() > 4 and tile_map.tile_set.tile_shape == TileSet.TILE_SHAPE_SQUARE:
		var to_tiles := tile_map.global_transform.affine_inverse() * global_transform
		var tile_area := to_tiles * area
		var first := tile_map.local_to_map(tile_area.position)
		var last := tile_map.local_to_map(tile_area.end)
		var span := last - first + Vector2i.ONE
		if span.x * span.y < channels.size():
			# The box finds candidates. Test each center in the original scenery coordinates.
			for y in range(first.y, last.y + 1):
				for x in range(first.x, last.x + 1):
					var cell := Vector2i(x, y)
					if channels.has(cell) and area.has_point(_tile_point(cell)):
						return false
			return true
	for cell in channels:
		if area.has_point(_tile_point(cell)):
			return false
	return true

func _field_bounds(center: Vector2i) -> Rect2:
	return EstateLayout.field_bounds(center)

func _tile_point(cell: Vector2i) -> Vector2:
	return to_local(tile_map.to_global(tile_map.map_to_local(cell)))
