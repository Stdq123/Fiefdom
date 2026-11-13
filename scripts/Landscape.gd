extends Node2D

enum Prop {
	HALL, SILK_SHED, OAK, PINE, ROCK, GATE, BAMBOO, BOULDER, FLOWERS, REEDS, SUPPLIES, SIGNPOST, LOGS, SHRUB, BRIDGE, FENCE,
	GROVE_TREE, GROVE_CLUSTER, MOSS_STONE, FERN, STUMP, JAR, PEBBLES, WILLOW, BANK_GRASS, TALL_BAMBOO,
	GRAIN_SACK, OPEN_SACK, LIDDED_JAR, RAVINE_ROCK, RAVINE_SHOOT, RAVINE_RUSH, WHITE_BLOOM, PINK_BLOOM,
	BLOSSOM_TREE, GATE_FAR
}

const SCENERY := preload("res://assets/world/scenery.svg")
const ESTATE_BUILDINGS := preload("res://assets/world/estate-buildings.svg")
const GRAIN := preload("res://assets/world/ground-grain.svg")
const SEASONAL_TREES := preload("res://assets/world/seasonal-trees.svg")
const WINTER_WILLOW := preload("res://assets/world/winter-willow.svg")
const SEASONAL_GROUND := preload("res://scripts/SeasonalGround.gd")
const ESTATE_TERRAIN := preload("res://scripts/EstateTerrain.gd")
const WATER_SURFACE := preload("res://scripts/WaterSurface.gd")
const SNOW_FOOTPRINTS := preload("res://scripts/SnowFootprints.gd")
const ROAD_PAVILION := preload("res://assets/world/road-pavilion.svg")
const SILK_SAMPLE := preload("res://assets/world/west-court-sample.svg")
const SILK_SAMPLE_BOUNDS := Rect2(EstateLayout.WEST_COURT + Vector2(-37, -4), Vector2(28, 24))
const LOOKOUT := preload("res://assets/world/stone-lookout.svg")
const RAIN_VEIL := preload("res://scripts/RainVeil.gd")
const TERRAIN_AUDIO := preload("res://scripts/TerrainAudio.gd")
const DAY_LIGHTING := preload("res://scripts/DayLighting.gd")
const NINJA_SCENERY := preload("res://assets/world/ninja-adventure/tileset_village_abandoned.png")
const ACTG_SCENERY := preload("res://assets/world/actg/swamp.png")
const MOUNTAIN_POST_BAMBOO := preload("res://assets/world/mountain-post/bamboo.png")
const ESTATE_STORAGE := preload("res://assets/world/estate-storage.svg")
const RAVINE_ACCENTS := preload("res://assets/world/momonga/ravine-accents.png")
const RAVINE_ACCENT_PROPS := [Prop.RAVINE_ROCK, Prop.RAVINE_SHOOT, Prop.RAVINE_RUSH]
const MEADOW_FLOWERS := {
	Prop.WHITE_BLOOM: preload("res://assets/world/mini-meadow/flower_white.png"),
	Prop.PINK_BLOOM: preload("res://assets/world/mini-meadow/flower_pink.png"),
}
const ACTG_PROPS := [Prop.WILLOW, Prop.BANK_GRASS]
const STORAGE_TINTS := {
	Prop.GRAIN_SACK: Color(0.88, 0.83, 0.68),
	Prop.OPEN_SACK: Color(0.84, 0.79, 0.64),
	Prop.JAR: Color(0.73, 0.53, 0.53),
	Prop.LIDDED_JAR: Color(0.64, 0.54, 0.60),
}
const EXTERNAL_REGIONS := {
	Prop.GROVE_TREE: Rect2(64, 144, 32, 32),
	Prop.GROVE_CLUSTER: Rect2(0, 144, 64, 48),
	Prop.MOSS_STONE: Rect2(112, 80, 32, 32),
	Prop.FERN: Rect2(80, 80, 16, 16),
	Prop.STUMP: Rect2(96, 128, 16, 16),
	Prop.PEBBLES: Rect2(160, 64, 16, 16),
	Prop.WILLOW: Rect2(411, 22, 80, 100),
	Prop.BANK_GRASS: Rect2(251, 30, 32, 36),
	Prop.TALL_BAMBOO: Rect2(0, 0, 32, 44),
	Prop.GRAIN_SACK: Rect2(0, 0, 16, 16),
	Prop.OPEN_SACK: Rect2(16, 0, 16, 16),
	Prop.JAR: Rect2(32, 0, 16, 16),
	Prop.LIDDED_JAR: Rect2(48, 0, 16, 16),
	Prop.RAVINE_ROCK: Rect2(0, 0, 34, 17),
	Prop.RAVINE_SHOOT: Rect2(44, 0, 11, 17),
	Prop.RAVINE_RUSH: Rect2(62, 0, 22, 17),
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
const PAVILION_REGION := Rect2(Vector2(208, 0), EstateLayout.PAVILION_SIZE)
const BUILDING_FOOTPRINTS := {
	Prop.HALL: EstateLayout.HALL_BASE,
	Prop.SILK_SHED: EstateLayout.SILK_SHED_BASE,
	Prop.GATE: Rect2(-12, -5, 24, 7),
	Prop.GATE_FAR: Rect2(-12, -5, 24, 7),
}
const ORCHARD_FRAMES := [Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(3, 1)]
const MAP_BACKDROP := Rect2(-1650, -1400, 3350, 2800)
const ESTATE_BOUNDS := EstateLayout.BOUNDS
const WILD_BOUNDS := RavineLayout.BOUNDS
const HALL_FOOT := EstateLayout.HALL_FOOT
const HALL_LANDING := EstateLayout.HALL_LANDING
const SOUTH_PAVILION := EstateLayout.SOUTH_PAVILION
const PAVILION_TURN := EstateLayout.PAVILION_TURN
const PAVILION_REST_FOOT := SOUTH_PAVILION + Vector2(5, 5)
const PAVILION_WATER := PAVILION_REST_FOOT + Vector2(10, -4)
const SILK_SHED_FOOT := EstateLayout.SILK_SHED_FOOT
const SCENE_LANDMARK := -1
const SCENE_WEST_COURT := -2
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
const SORTED_PROPS := [Prop.HALL, Prop.SILK_SHED, Prop.OAK, Prop.BLOSSOM_TREE, Prop.PINE, Prop.GATE, Prop.GATE_FAR, Prop.BAMBOO,
	Prop.GROVE_TREE, Prop.GROVE_CLUSTER, Prop.WILLOW, Prop.TALL_BAMBOO,
	Prop.GRAIN_SACK, Prop.OPEN_SACK, Prop.JAR, Prop.LIDDED_JAR]
const LEAFY_PROPS := [Prop.OAK, Prop.BLOSSOM_TREE, Prop.GROVE_TREE, Prop.GROVE_CLUSTER, Prop.SHRUB, Prop.FERN,
	Prop.FLOWERS, Prop.WILLOW, Prop.BANK_GRASS, Prop.TALL_BAMBOO, Prop.RAVINE_SHOOT, Prop.RAVINE_RUSH,
	Prop.WHITE_BLOOM, Prop.PINK_BLOOM]
const DORMANT_PROPS := [Prop.FLOWERS, Prop.FERN, Prop.RAVINE_SHOOT, Prop.RAVINE_RUSH, Prop.WHITE_BLOOM, Prop.PINK_BLOOM]
const BERRY_GROVE := RavineLayout.FRUIT + Vector2(-17, 8)
const BRIDGE := RavineLayout.BRIDGE
const BRIDGE_DECK := Rect2(BRIDGE - Vector2(27, 13), Vector2(54, 26))
const FORD := RavineLayout.FORD
const FORD_AREA := Rect2(FORD - Vector2(35, 17), Vector2(70, 34))
const CROSSING_HALF_DEPTH := 16.0
const WATER_HALF_WIDTH := 17.0
const EAST_LANE_JUNCTION := EstateLayout.EAST_LANE_JUNCTION
const ESTATE_SOUTH_LANE := EstateLayout.SOUTH_LANE
const ESTATE_EAST_LANE := EstateLayout.EAST_LANE
const ESTATE_TRACKS := EstateLayout.ROADS + EstateLayout.SOUTH_ROADS + [
	[EstateLayout.FREIGHT_STOP + Vector2(-21, 0), EstateLayout.FREIGHT_STOP + Vector2(32, 0)],
	[EstateLayout.HEARTH_APPROACH + Vector2(-13, 0), EstateLayout.HEARTH_APPROACH + Vector2(23, 4)],
] + EstateLayout.DRIVING_ROADS
const WILD_TRACKS := RavineLayout.TRACKS
const ESTATE_TRACK_WIDTHS: Array[float] = EstateLayout.ROAD_WIDTHS + [
	18.0, 13.0, 17.0, 14.0, 17.0, 15.0, 13.0, 16.0, 41.0, 30.0, 19.0, 34.0,
]
const GARDEN_TRACK := [EstateLayout.PAVILION_TURN, Vector2(39, 396), Vector2(58, 402), Vector2(78, 407), Vector2(101, 408)]
const ROAD_REST_TRACK := [EstateLayout.PAVILION_JUNCTION, Vector2(9, 432), Vector2(-7, 442)]
const ROTATION_BOOK_TRACK := [EstateLayout.FIELD_LANE_TURN, Vector2(22, 236), Vector2(0, 233), Vector2(-21, 234), Vector2(-43, 238)]
const WILD_TRACK_WIDTHS := RavineLayout.TRACK_WIDTHS
const CREEK := RavineLayout.CREEK
const GRAVEL_BAR := [
	Vector2(249, 197), Vector2(281, 202), Vector2(300, 218), Vector2(312, 249),
	Vector2(298, 273), Vector2(265, 254), Vector2(238, 216),
]
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
	Vector3i(-239, 10, Prop.SIGNPOST),
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
	Vector3i(120, 54, Prop.SIGNPOST),
	Vector3i(286, 32, Prop.SIGNPOST), Vector3i(348, -24, Prop.GROVE_TREE), Vector3i(356, -17, Prop.FENCE),
	Vector3i(413, -16, Prop.GATE_FAR), Vector3i(387, 32, Prop.GATE),
	Vector3i(445, 25, Prop.FENCE), Vector3i(457, 53, Prop.PINE),
	Vector3i(481, -21, Prop.GROVE_CLUSTER), Vector3i(478, 99, Prop.GROVE_TREE),
	# The pine verge separates the watch post and the training road.
	Vector3i(351, 57, Prop.SIGNPOST), Vector3i(357, 87, Prop.OAK), Vector3i(420, 94, Prop.TALL_BAMBOO),
	Vector3i(354, 109, Prop.GROVE_TREE), Vector3i(357, 194, Prop.PINE), Vector3i(427, 155, Prop.PINE),
	Vector3i(336, 207, Prop.TALL_BAMBOO), Vector3i(348, 226, Prop.FENCE), Vector3i(446, 222, Prop.FENCE),
	Vector3i(351, 270, Prop.LOGS), Vector3i(448, 276, Prop.OAK), Vector3i(365, 319, Prop.TALL_BAMBOO),
	Vector3i(447, 326, Prop.GROVE_TREE), Vector3i(375, 378, Prop.GROVE_CLUSTER), Vector3i(453, 385, Prop.PINE),
	Vector3i(377, 436, Prop.PINE), Vector3i(447, 428, Prop.FENCE), Vector3i(474, 435, Prop.FENCE),
	Vector3i(468, 491, Prop.TALL_BAMBOO), Vector3i(423, 501, Prop.GROVE_TREE),
	# Bamboo and low grasses flank the lane between the fields and the pavilion.
	Vector3i(12, 224, Prop.SIGNPOST), Vector3i(75, 255, Prop.BAMBOO),
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
	Vector3i(50, 511, Prop.SIGNPOST), Vector3i(101, 522, Prop.GROVE_TREE), Vector3i(122, 531, Prop.PINE),
	Vector3i(172, 530, Prop.TALL_BAMBOO), Vector3i(191, 548, Prop.LOGS), Vector3i(253, 555, Prop.JAR),
	Vector3i(112, 594, Prop.OAK), Vector3i(136, 621, Prop.PINE), Vector3i(172, 609, Prop.GROVE_TREE),
	Vector3i(37, 600, Prop.BAMBOO), Vector3i(23, 636, Prop.FLOWERS), Vector3i(4, 678, Prop.TALL_BAMBOO),
	Vector3i(281, 633, Prop.GROVE_TREE), Vector3i(315, 635, Prop.TALL_BAMBOO), Vector3i(337, 648, Prop.RAVINE_ROCK),
	Vector3i(278, 553, Prop.SIGNPOST), Vector3i(306, 545, Prop.BAMBOO), Vector3i(341, 539, Prop.GROVE_TREE),
	Vector3i(400, 603, Prop.BLOSSOM_TREE), Vector3i(463, 539, Prop.PINE), Vector3i(457, 608, Prop.TALL_BAMBOO),
	Vector3i(489, 612, Prop.PINE), Vector3i(483, 664, Prop.OAK),
	# Reeds mark the waterline. The open west bank is the approach to the clearing.
	Vector3i(198, 663, Prop.RAVINE_RUSH), Vector3i(174, 697, Prop.BANK_GRASS),
	Vector3i(190, 742, Prop.REEDS), Vector3i(219, 766, Prop.RAVINE_ROCK),
	Vector3i(270, 766, Prop.BANK_GRASS), Vector3i(327, 735, Prop.REEDS),
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
	Vector3i(-429, -4, Prop.FENCE), Vector3i(-417, 73, Prop.BOULDER), Vector3i(-406, -56, Prop.GROVE_CLUSTER),
	Vector3i(-358, -32, Prop.PINE), Vector3i(-321, -15, Prop.TALL_BAMBOO), Vector3i(-285, 1, Prop.GROVE_TREE),
	Vector3i(-263, -38, Prop.OAK), Vector3i(-243, -5, Prop.MOSS_STONE), Vector3i(-223, 66, Prop.TALL_BAMBOO),
	Vector3i(-328, 84, Prop.GROVE_CLUSTER), Vector3i(-296, 66, Prop.PINE), Vector3i(-262, 100, Prop.GROVE_TREE),
	Vector3i(-427, -136, Prop.PINE), Vector3i(-397, -202, Prop.GROVE_CLUSTER), Vector3i(-359, -148, Prop.TALL_BAMBOO),
	Vector3i(-329, -209, Prop.PINE), Vector3i(-310, -97, Prop.PINE), Vector3i(-269, -151, Prop.GROVE_TREE),
	Vector3i(-233, -111, Prop.TALL_BAMBOO), Vector3i(-213, -160, Prop.PINE), Vector3i(-162, -163, Prop.BLOSSOM_TREE),
	Vector3i(-116, -155, Prop.GROVE_TREE), Vector3i(-107, -115, Prop.SHRUB), Vector3i(-138, -98, Prop.WHITE_BLOOM),
	Vector3i(-158, -80, Prop.FERN), Vector3i(-174, 35, Prop.SIGNPOST), Vector3i(-120, -26, Prop.GROVE_CLUSTER),
	Vector3i(-86, -32, Prop.RAVINE_SHOOT), Vector3i(-56, -22, Prop.PINE), Vector3i(-26, -63, Prop.BAMBOO),
	Vector3i(-116, 57, Prop.FLOWERS), Vector3i(-94, 67, Prop.STUMP), Vector3i(-62, 14, Prop.SIGNPOST),
	Vector3i(-20, 48, Prop.GROVE_TREE), Vector3i(18, 58, Prop.PINE), Vector3i(43, 88, Prop.BOULDER),
	Vector3i(-131, 125, Prop.OAK), Vector3i(-88, 130, Prop.TALL_BAMBOO), Vector3i(-39, 138, Prop.PINE),
	Vector3i(-206, 171, Prop.GROVE_CLUSTER), Vector3i(-314, 144, Prop.PINE), Vector3i(-381, 168, Prop.TALL_BAMBOO),
	Vector3i(-350, 237, Prop.PINE), Vector3i(-283, 219, Prop.GROVE_TREE), Vector3i(-229, 264, Prop.PINE),
	Vector3i(-156, 220, Prop.GROVE_TREE), Vector3i(-121, 290, Prop.PINE), Vector3i(-50, 220, Prop.OAK),
	Vector3i(39, 198, Prop.PINE), Vector3i(83, 181, Prop.OAK), Vector3i(114, 191, Prop.MOSS_STONE),
	Vector3i(143, 140, Prop.FERN), Vector3i(164, 142, Prop.RAVINE_RUSH), Vector3i(156, 208, Prop.REEDS),
	Vector3i(191, 209, Prop.PEBBLES), Vector3i(204, 227, Prop.RAVINE_ROCK), Vector3i(72, 276, Prop.WILLOW),
	Vector3i(141, 228, Prop.SIGNPOST), Vector3i(234, 307, Prop.TALL_BAMBOO),
	Vector3i(173, 321, Prop.BAMBOO), Vector3i(167, 356, Prop.GROVE_TREE), Vector3i(235, 352, Prop.RAVINE_ROCK),
	Vector3i(153, 292, Prop.TALL_BAMBOO), Vector3i(110, 309, Prop.PINE), Vector3i(55, 302, Prop.GROVE_TREE),
	Vector3i(41, -53, Prop.PINE), Vector3i(23, -100, Prop.OAK), Vector3i(-14, -142, Prop.GROVE_CLUSTER),
	Vector3i(25, -166, Prop.GROVE_TREE), Vector3i(43, -138, Prop.TALL_BAMBOO), Vector3i(28, -218, Prop.PINE),
	Vector3i(102, -189, Prop.MOSS_STONE), Vector3i(117, -216, Prop.REEDS), Vector3i(169, -237, Prop.REEDS),
	Vector3i(112, -157, Prop.RAVINE_RUSH), Vector3i(128, -253, Prop.BANK_GRASS), Vector3i(83, -281, Prop.PINE),
	Vector3i(40, -262, Prop.TALL_BAMBOO), Vector3i(32, -314, Prop.GROVE_CLUSTER), Vector3i(79, -331, Prop.PINE),
	Vector3i(129, -287, Prop.PEBBLES), Vector3i(159, -314, Prop.REEDS), Vector3i(187, -356, Prop.RAVINE_RUSH),
	Vector3i(112, -367, Prop.TALL_BAMBOO), Vector3i(128, -417, Prop.WILLOW), Vector3i(141, -388, Prop.MOSS_STONE),
	Vector3i(183, -387, Prop.PEBBLES), Vector3i(199, -421, Prop.REEDS), Vector3i(143, -456, Prop.PEBBLES),
	Vector3i(106, -460, Prop.PINE), Vector3i(61, -438, Prop.GROVE_TREE), Vector3i(25, -392, Prop.PINE),
	Vector3i(85, -504, Prop.GROVE_CLUSTER), Vector3i(134, -510, Prop.TALL_BAMBOO),
	Vector3i(164, -486, Prop.RAVINE_ROCK), Vector3i(230, -496, Prop.PINE), Vector3i(273, -465, Prop.GROVE_TREE),
	Vector3i(262, -422, Prop.WILLOW), Vector3i(258, -369, Prop.REEDS), Vector3i(290, -338, Prop.PINE),
	Vector3i(212, -290, Prop.GROVE_CLUSTER), Vector3i(262, -256, Prop.TALL_BAMBOO), Vector3i(331, -287, Prop.PINE),
	Vector3i(117, -80, Prop.RAVINE_RUSH), Vector3i(157, -55, Prop.REEDS), Vector3i(92, 3, Prop.TALL_BAMBOO),
	Vector3i(107, 60, Prop.PEBBLES), Vector3i(183, 58, Prop.PEBBLES), Vector3i(204, 6, Prop.TALL_BAMBOO),
	Vector3i(225, -169, Prop.WILLOW), Vector3i(208, -108, Prop.MOSS_STONE), Vector3i(241, -88, Prop.GROVE_TREE),
	Vector3i(269, -52, Prop.PINE), Vector3i(273, -103, Prop.TALL_BAMBOO), Vector3i(304, -132, Prop.GROVE_CLUSTER),
	Vector3i(319, -46, Prop.BOULDER), Vector3i(348, -61, Prop.BAMBOO), Vector3i(370, -105, Prop.PINE),
	Vector3i(383, -151, Prop.TALL_BAMBOO), Vector3i(420, -149, Prop.GROVE_TREE), Vector3i(467, -145, Prop.PINE),
	Vector3i(483, -96, Prop.TALL_BAMBOO), Vector3i(499, -69, Prop.GROVE_TREE), Vector3i(452, -63, Prop.FERN),
	Vector3i(482, -28, Prop.BOULDER), Vector3i(404, -28, Prop.MOSS_STONE), Vector3i(355, 33, Prop.SIGNPOST),
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

var props: Array[Vector3i] = []
var scenery: Dictionary[Sprite2D, int] = {}
var gate_bases: Dictionary[Sprite2D, CollisionShape2D] = {}
var seasonal_textures: Dictionary[int, AtlasTexture] = {}
var ground_cover: SEASONAL_GROUND
var estate_terrain: ESTATE_TERRAIN
var snow_footprints: SNOW_FOOTPRINTS
var water_surface: WATER_SURFACE
var terrain_audio: TERRAIN_AUDIO
var day_lighting: DAY_LIGHTING
var season := 0
var raining := false
var estate_tracks := ESTATE_TRACKS.duplicate()
var estate_track_widths: Array[float] = []
var track_shapes: Array[Dictionary] = []
var field_approaches: Dictionary[int, PackedVector2Array] = {}

func _ready() -> void:
	ground_cover = SEASONAL_GROUND.new(wilderness)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if not wilderness:
		estate_terrain = ESTATE_TERRAIN.new(ESTATE_BOUNDS.position.y)
	snow_footprints = SNOW_FOOTPRINTS.new()
	snow_footprints.name = "SnowFootprints"
	add_child(snow_footprints)
	terrain_audio = AudioManager.terrain_audio
	day_lighting = DAY_LIGHTING.new()
	day_lighting.name = "DayLighting"
	add_child(day_lighting)
	player.footstep.connect(_on_footstep)
	props.assign(WILD_PROPS if wilderness else ESTATE_PROPS)
	props.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.y < b.y)
	GameEvents.day_advanced.connect(_update_weather.unbind(1))
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
		GameEvents.seed_garden_arrived.connect(_refresh_estate_tracks)
		GameEvents.pond_landing_opened.connect(_refresh_estate_tracks)
		_layout_field_approaches()
	else:
		_build_track_shapes(WILD_TRACKS, WILD_TRACK_WIDTHS)
	_add_water_surface()
	_update_weather()
	_prepare_map.call_deferred()

func _layout_field_approaches() -> void:
	field_approaches.clear()
	var fields: Array[Rect2] = []
	for field in Global.well_fields:
		fields.append(_field_bounds(field["center_pos"]))
	# The first scene builds its roads before World initializes the starter field.
	if fields.is_empty():
		field_approaches[0] = _starter_approach(_field_bounds(Global.FIRST_FIELD_CENTER))
	for field in Global.well_fields:
		if not field["is_unlocked"]:
			continue
		var id: int = field["field_id"]
		var area := fields[id]
		if field["center_pos"] == Global.FIRST_FIELD_CENTER:
			field_approaches[id] = _starter_approach(area)
			continue
		var occupied: Array[Rect2] = []
		occupied.assign(EstateLayout.LANDMARKS)
		occupied.append_array(fields)
		occupied.erase(area)
		var approach := EstateLayout.field_approach(area, occupied)
		if not approach.is_empty():
			field_approaches[id] = approach

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
		return Vector2.ZERO
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
	if Global.seed_garden_day() > 0:
		estate_tracks.append(EstateLayout.SEED_GARDEN_TRACK)
		estate_track_widths.append(11.0)
	elif Global.road_rest_built():
		estate_tracks.append(ROAD_REST_TRACK)
		estate_track_widths.append(12.0)
	if Global.pond_landing_day() > 0:
		estate_tracks.append(EstateLayout.POND_TRACK)
		estate_track_widths.append(10.0)
	if Global.field_rotation.signed_day > 0:
		estate_tracks.append(ROTATION_BOOK_TRACK)
		estate_track_widths.append(11.0)
	_build_track_shapes(estate_tracks, estate_track_widths, field_track_count)
	queue_redraw()

func _prepare_map() -> void:
	if not is_inside_tree():
		return
	var props_layer := get_parent().get_node("Scenery") as Node2D
	for placement in props:
		if placement.z not in SORTED_PROPS:
			continue
		var sprite := _place_sprite(props_layer, Vector2(placement.x, placement.y),
			_prop_bounds(Vector2.ZERO, placement.z).position, _prop_texture(placement.z))
		scenery[sprite] = placement.z
	if wilderness:
		scenery[_place_sprite(props_layer, RavineLayout.LOOKOUT, Vector2(-24, -38), LOOKOUT)] = SCENE_LANDMARK
	else:
		var pavilion_texture := _atlas_texture(ESTATE_BUILDINGS, PAVILION_REGION)
		scenery[_place_sprite(props_layer, SOUTH_PAVILION, _building_offset(PAVILION_REGION.size), pavilion_texture)] = SCENE_LANDMARK
		var shelter := _atlas_texture(ROAD_PAVILION, Rect2(0, 0, 48, 40))
		scenery[_place_sprite(props_layer, EstateLayout.WEST_COURT_SHELTER, Vector2(-24, -38), shelter)] = SCENE_WEST_COURT
		var workshop := _place_sprite(props_layer, SILK_SHED_FOOT,
			_prop_bounds(Vector2.ZERO, Prop.SILK_SHED).position, _prop_texture(Prop.SILK_SHED))
		scenery[workshop] = Prop.SILK_SHED
	_place_lanterns(props_layer)

	var rain := RAIN_VEIL.new()
	rain.name = "Rain"
	rain.z_index = 11
	add_child(rain)
	_add_landmark_labels()
	_install_boundaries()
	_refresh_scenery()

func _add_water_surface() -> void:
	if wilderness:
		water_surface = WATER_SURFACE.new(_ribbon(PackedVector2Array(CREEK), WATER_HALF_WIDTH), 10.0,
			[BRIDGE_DECK.grow(2.0), FORD_AREA])
	else:
		water_surface = WATER_SURFACE.new(estate_terrain.pond, 0.0)
	water_surface.name = "WaterSurface"
	add_child(water_surface)

func _place_lanterns(layer: Node2D) -> void:
	if wilderness:
		day_lighting.place_lamp(layer, Vector2(-181, 20))
		day_lighting.place_lamp(layer, BRIDGE + Vector2(-29, 15), 0.83)
		day_lighting.place_lamp(layer, BRIDGE + Vector2(30, -12), 0.83)
		day_lighting.place_lamp(layer, RavineLayout.SOUTH_TRAIL_GATE + Vector2(-22, -10), 0.72)
	else:
		day_lighting.place_lamp(layer, Vector2(HALL_FOOT) + Vector2(-18, 8), 0.90)
		day_lighting.place_lamp(layer, Vector2(HALL_FOOT) + Vector2(18, 8), 0.90)
		day_lighting.place_lamp(layer, SOUTH_PAVILION + Vector2(27, 12))
		day_lighting.place_lamp(layer, EstateLayout.SOUTH_FORK + Vector2(-15, -14), 0.76)
		day_lighting.place_lamp(layer, EstateLayout.FREIGHT_STOP + Vector2(37, -19), 0.80)
		day_lighting.place_lamp(layer, EstateLayout.FESTIVAL_FORK + Vector2(13, 18), 0.74)
		day_lighting.place_lamp(layer, EstateLayout.FESTIVAL_BANK_BEND + Vector2(-13, 20), 0.70)
		day_lighting.place_lamp(layer, EstateLayout.DRIVING_START + Vector2(28, -14), 0.78)
		day_lighting.place_lamp(layer, EstateLayout.DRIVING_FINISH + Vector2(-2, -27), 0.76)
		day_lighting.place_lamp(layer, EstateLayout.RAVINE_TRAIL_GATE + Vector2(-16, -17), 0.72)
		day_lighting.place_lamp(layer, Vector2(415, 31))
		day_lighting.place_lamp(layer, Vector2(-286, -4))
		day_lighting.place_lamp(layer, EstateLayout.WEST_COURT + Vector2(-31, -9), 0.78)
	day_lighting.refresh()

func _place_sprite(layer: Node, foot: Vector2, offset: Vector2, texture: Texture2D) -> Sprite2D:
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
		if season == Global.Season.WINTER:
			snow_footprints.clear()
		season = next_season
		_update_tree_textures()
	raining = Global.has_rain()
	if not wilderness:
		_refresh_estate_tracks()
	water_surface.set_weather(WATER_TINTS[season], raining)
	_refresh_scenery()

func _refresh_scenery() -> void:
	for sprite in scenery:
		var prop: int = scenery[sprite]
		if seasonal_textures.has(prop):
			sprite.texture = seasonal_textures[prop]
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
		sprite.self_modulate = tint
	for sprite in gate_bases:
		gate_bases[sprite].set_deferred("disabled", not sprite.visible)
	if not wilderness:
		for lamp in day_lighting.lamps:
			lamp.visible = _ground_clear(Rect2(to_local(lamp.global_position) - Vector2(4, 2), Vector2(8, 4)))
	queue_redraw()

func _process(delta: float) -> void:
	if not get_tree().paused and not player.conversation_open and not MapTravel.active:
		Global.advance_daylight(delta)
		if wilderness:
			Global.advance_away_field_work(delta)
	day_lighting.refresh(delta)
	var foot := to_local(player.global_position)
	var creek_distance := absf(foot.x - creek_x(foot.y)) if wilderness else INF
	var birds_distance := foot.distance_to(BERRY_GROVE) if wilderness else INF
	var cricket_distance := foot.distance_to(BERRY_GROVE if wilderness else SOUTH_PAVILION)
	AudioManager.set_world_ambience(creek_distance, birds_distance, cricket_distance)
	for sprite in scenery:
		if not sprite.visible:
			continue
		var from_foot := sprite.to_local(player.global_position)
		var crown := sprite.get_rect().grow(-3.0)
		var behind := from_foot.y < -2.0 and crown.has_point(from_foot - Vector2(0, 7))
		var tint := sprite.self_modulate
		tint.a = move_toward(tint.a, 0.28 if behind else 1.0, delta * 5.6)
		sprite.self_modulate = tint

func _draw() -> void:
	_draw_ground()
	if wilderness:
		var gravel := _track_dust().lerp(Color("#939988"), 0.58)
		draw_colored_polygon(PackedVector2Array(GRAVEL_BAR), gravel)
		draw_colored_polygon(PackedVector2Array(RavineLayout.WILLOW_BANK), gravel)
		_draw_tracks()
		_draw_creek()
		_draw_crossings()
	else:
		_draw_field_verges()
		_draw_tracks()
		_draw_hall_landing()
		_draw_field_banks()
		if Global.road_provisions_delivered:
			var provisions := Rect2(SOUTH_PAVILION + Vector2(31, 0), Vector2(14, 10))
			draw_texture_rect_region(ROAD_PAVILION, provisions, Rect2(48, 30, 14, 10))
		_draw_pavilion_rest()
		if Global.silk_sample_day > 0 and _ground_clear(SILK_SAMPLE_BOUNDS):
			draw_texture_rect(SILK_SAMPLE, SILK_SAMPLE_BOUNDS, false, _prop_tint(-1))
	for prop in props:
		if prop.z in SORTED_PROPS and prop.z != Prop.TALL_BAMBOO and not STORAGE_TINTS.has(prop.z):
			continue
		if season == Global.Season.WINTER and prop.z in DORMANT_PROPS:
			continue
		var foot := Vector2(prop.x, prop.y)
		var bounds := _prop_bounds(foot, prop.z)
		if not wilderness and not _ground_clear(bounds):
			continue
		if prop.z == Prop.TALL_BAMBOO:
			draw_rect(Rect2(foot - Vector2(11, 2), Vector2(22, 5)), Color("#23382b80"))
		elif STORAGE_TINTS.has(prop.z):
			draw_rect(Rect2(foot - Vector2(6, 1), Vector2(12, 3)), Color("#23382b80"))
		else:
			_stamp(bounds, prop.z)

func _on_footstep(at: Vector2) -> void:
	var foot := to_local(at)
	var surface := TERRAIN_AUDIO.Surface.PLANK if Global.is_indoors() else _surface_at(foot)
	terrain_audio.play_step(surface)
	if surface == TERRAIN_AUDIO.Surface.SNOW:
		snow_footprints.leave(foot, player.get_real_velocity(), terrain_audio.step_variant % 2 == 0)

func _surface_at(foot: Vector2) -> TERRAIN_AUDIO.Surface:
	if wilderness:
		if BRIDGE_DECK.has_point(foot):
			return TERRAIN_AUDIO.Surface.PLANK
		if absf(foot.y - FORD.y) < CROSSING_HALF_DEPTH and absf(foot.x - creek_x(foot.y)) < WATER_HALF_WIDTH:
			return TERRAIN_AUDIO.Surface.SHALLOWS
	else:
		if get_parent().irrigation_overlay.footbridge_at(to_global(foot)):
			return TERRAIN_AUDIO.Surface.PLANK
		for field in Global.well_fields:
			if _field_bounds(field["center_pos"]).has_point(foot):
				return TERRAIN_AUDIO.Surface.GRASS
		if HALL_LANDING.has_point(foot) and _hall_landing_visible():
			return TERRAIN_AUDIO.Surface.TRACK
	for track in track_shapes:
		var outline: PackedVector2Array = track.shoulder if season == Global.Season.WINTER else track.surface
		if Geometry2D.is_point_in_polygon(foot, outline):
			return TERRAIN_AUDIO.Surface.TRACK
	if season == Global.Season.WINTER and ground_cover.has_snow(foot):
		if wilderness or _ground_clear(Rect2(foot, Vector2.ONE)):
			return TERRAIN_AUDIO.Surface.SNOW
	return TERRAIN_AUDIO.Surface.GRASS

func _draw_pavilion_rest() -> void:
	var guest: Visitor = get_parent().current_visitor_actor()
	if not is_instance_valid(guest) or not guest.resting_at_pavilion():
		return
	var mat := PAVILION_REST_FOOT + Vector2(-11, -2)
	draw_rect(Rect2(mat + Vector2(0, 1), Vector2(22, 6)), Color("#373b2d"))
	draw_rect(Rect2(mat + Vector2(1, 0), Vector2(20, 5)), Color("#ad9565"))
	for offset in range(2, 21, 3):
		draw_rect(Rect2(mat + Vector2(offset, 1), Vector2(1, 3)), Color("#786647"))
	var bowl := PAVILION_WATER
	draw_rect(Rect2(bowl + Vector2(-3, 1), Vector2(7, 3)), Color("#694837"))
	draw_rect(Rect2(bowl + Vector2(-4, 0), Vector2(9, 2)), Color("#b78c61"))
	draw_rect(Rect2(bowl + Vector2(-2, 0), Vector2(5, 1)), Color("#5e6553"))

func _add_landmark_labels() -> void:
	if wilderness:
		_label_at(RavineLayout.WEST_GATE + Vector2(0, -79), "← 西门 · 回封地")
		_label_at(RavineLayout.GROVE_FORK + Vector2(0, -42), "↑ 野果坳")
		_label_at(RavineLayout.FORD_FORK + Vector2(-10, 23), "浅滩 ↘")
		_label_at(Vector2(140, 186), "南路小径 ↓")
		_label_at(RavineLayout.SHORE_FORK + Vector2(0, -31), "↑ 柳湾 · 埠头")
		_label_at(RavineLayout.DOCK_FORK + Vector2(-24, -19), "↑ 柳湾")
		_label_at(BRIDGE + Vector2(-66, -31), "木桥 →")
		_label_at(RavineLayout.RIDGE_FORK + Vector2(0, -34), "望溪台 ↗")
		_label_at(RavineLayout.LOOKOUT + Vector2(0, -55), "望溪台")
	else:
		_label_at(Vector2(-305, -104), "← 西市")
		_label_at(Vector2(-136, 37), "← 西市")
		_label_at(Vector2(-239, -21), "西廊 ↓")
		_label_at(EstateLayout.WEST_COURT_SHELTER + Vector2(0, -48), "西廊")
		_label_at(Vector2(120, 6), "东关 →")
		_label_at(Vector2(287, -22), "东关 · 竹涧 →")
		_label_at(Vector2(400, -78), "东关")
		_label_at(Vector2(348, 14), "驾御场 ↘")
		_label_at(SOUTH_PAVILION + Vector2(0, -69), "南路亭")
		_label_at(Vector2(12, 181), "南路亭 ↓")
		_label_at(EstateLayout.SOUTH_FORK + Vector2(22, -38), "西坡 ↙  ·  灶台 →")
		_label_at(Vector2(278, 510), "竹涧小径 →")
		_label_at(EstateLayout.FESTIVAL_FORK + Vector2(4, 46), "↙ 南池")

func _label_at(center: Vector2, text: String) -> void:
	var label := Label.new()
	label.material = preload("res://resources/world_hint_material.tres")
	label.text = text
	label.position = center - Vector2(55, 0)
	label.size.x = 110
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 7
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#e8dbac"))
	label.add_theme_color_override("font_outline_color", Color("#243a2d"))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)

func _draw_ground() -> void:
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
	draw_rect(MAP_BACKDROP, meadow)
	var winter := season == Global.Season.WINTER
	var ground_shade := shade if wilderness else shade.lerp(meadow, 0.26)
	ground_cover.draw_cover(self, ground_shade, sun, winter)
	var grain_strength := 0.46 if winter else (1.0 if wilderness else 0.57)
	draw_texture_rect(GRAIN, MAP_BACKDROP, true, Color(Color.WHITE, grain_strength))
	ground_cover.draw_marks(self, season, raining)
	if estate_terrain:
		estate_terrain.draw_meadow(self, meadow, winter)
		estate_terrain.draw_north_bank(self, MAP_BACKDROP.position.y, shade, sun, winter)
		var pond_water: Color = WATER_TINTS[season]
		estate_terrain.draw_pond(self, meadow, pond_water, winter)
	var grass := shade.lightened(0.09)
	for prop in props:
		if prop.z in LEAFY_PROPS and (not winter or prop.z not in DORMANT_PROPS):
			var patch := Vector2(prop.x, prop.y)
			if winter and ground_cover.has_snow(patch):
				continue
			draw_rect(Rect2(patch + Vector2(-14, 0), Vector2(28, 4)), Color(grass, 0.62))
			draw_rect(Rect2(patch + Vector2(-10, 4), Vector2(19, 2)), Color(grass, 0.57))

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
		track_shapes.append({
			"shoulder": _track_outline(samples, radius + EstateLayout.ROAD_SHOULDER, index, entrance),
			"edge": _track_outline(samples, radius + 1.0, index, entrance),
			"surface": _track_outline(samples, radius, index, entrance),
			"gravel_path": points if wilderness else samples,
			"width": widths[index],
		})

func track_crossing(start: Vector2, finish: Vector2) -> Variant:
	var channel_direction := start.direction_to(finish)
	for track in track_shapes:
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

func _draw_tracks() -> void:
	var dust := _track_dust()
	var verge: Color = SEASON_PALETTES[season][0]
	if raining:
		verge = verge.darkened(0.15)
	if estate_terrain:
		for track in track_shapes:
			estate_terrain.draw_verge(self, track.gravel_path, track.width, verge, season == Global.Season.WINTER)
	for track in track_shapes:
		draw_colored_polygon(track.shoulder, dust.lerp(verge, 0.69))
	for track in track_shapes:
		draw_colored_polygon(track.edge, dust.lerp(verge, 0.41))
	for track in track_shapes:
		ESTATE_TERRAIN.draw_loam(self, track.surface, dust)
	for track in track_shapes:
		_track_gravel(track.gravel_path, track.width, dust)

func _hall_landing_visible() -> bool:
	return hall_rest != null and hall_rest.visible and _fields_clear(HALL_LANDING)

func _draw_hall_landing() -> void:
	if not _hall_landing_visible():
		return
	var at := HALL_LANDING.position
	var stone := Color("#a39879").darkened(0.15 if raining else 0.0)
	draw_rect(HALL_LANDING, stone.darkened(0.31))
	draw_rect(Rect2(at + Vector2(1, 1), HALL_LANDING.size - Vector2(2, 3)), stone)
	draw_rect(Rect2(at + Vector2(2, 7), Vector2(40, 1)), stone.darkened(0.19))
	draw_rect(Rect2(at + Vector2(13, 1), Vector2(1, 6)), stone.darkened(0.19))
	draw_rect(Rect2(at + Vector2(32, 1), Vector2(1, 6)), stone.darkened(0.19))
	draw_rect(Rect2(at + Vector2(23, 8), Vector2(1, 5)), stone.darkened(0.19))
	draw_rect(Rect2(at + Vector2(4, 9), Vector2(9, 1)), stone.lightened(0.12))
	draw_rect(Rect2(at + Vector2(31, 3), Vector2(8, 1)), stone.lightened(0.12))

func _track_gravel(points: PackedVector2Array, width: float, dust: Color) -> void:
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
			draw_rect(Rect2(point.round(), Vector2(width_px, 1)),
				dust.lightened(0.20) if scatter % 3 == 0 else dust.darkened(0.13))

func _draw_field_verges() -> void:
	var verge: Color = SEASON_PALETTES[season][0]
	var dust := _track_dust()
	if raining:
		verge = verge.lerp(Color("#344c4c"), 0.34)
	for field in Global.well_fields:
		var area := _field_bounds(field["center_pos"])
		var entrance := field_entrance(field["field_id"])
		_draw_field_edge(area.grow(5.0), verge.lerp(dust, 0.27), entrance, 5.0, true)

func _draw_field_banks() -> void:
	var dust := _track_dust()
	for field in Global.well_fields:
		if not field["is_unlocked"]:
			continue
		var area := _field_bounds(field["center_pos"])
		var entrance := field_entrance(field["field_id"])
		var bank := area.grow(2.0)
		if entrance.x == 0.0:
			bank.size.y += 2.0
		_draw_field_edge(bank, dust.darkened(0.25), entrance, 4.0)
		var highlight := Rect2(area.position + Vector2(2, -2), Vector2(area.size.x - 4.0, 1))
		if entrance == Vector2.UP:
			var length := (highlight.size.x - EstateLayout.FIELD_ENTRANCE_WIDTH) * 0.5
			draw_rect(Rect2(highlight.position, Vector2(length, 1)), dust.lightened(0.13))
			highlight.position.x = highlight.end.x - length
			highlight.size.x = length
		draw_rect(highlight, dust.lightened(0.13))

func _draw_field_edge(area: Rect2, color: Color, entrance: Vector2, depth: float, loam := false) -> void:
	var corners := EstateLayout.corners(area)
	var outline := PackedVector2Array()
	for side in 4:
		var start := corners[side]
		var finish := corners[(side + 1) % 4]
		var along := start.direction_to(finish)
		outline.append(start + along * 3.0)
		if EstateLayout.EDGE_NORMALS[side] == entrance:
			var middle := start.lerp(finish, 0.5)
			var half_opening := along * EstateLayout.FIELD_ENTRANCE_WIDTH * 0.5
			var lip := middle - half_opening
			var far_lip := middle + half_opening
			outline.append_array(PackedVector2Array([lip, lip - entrance * depth,
				far_lip - entrance * depth, far_lip]))
		outline.append(finish - along * 3.0)
	if loam:
		ESTATE_TERRAIN.draw_loam(self, outline, color)
	else:
		draw_colored_polygon(outline, color)

func _draw_creek() -> void:
	var line := PackedVector2Array(CREEK)
	var water: Color = WATER_TINTS[season]
	var winter := season == Global.Season.WINTER
	var silt := Color("#778b7d") if winter else Color("#727b5e")
	var bank := _ribbon(line, WATER_HALF_WIDTH)
	draw_colored_polygon(_ribbon(line, 26), Color("#505f59") if winter else Color("#475b49"))
	draw_colored_polygon(_ribbon(line, 22), silt)
	draw_colored_polygon(bank, water.lerp(Color("#86a587"), 0.43))
	draw_colored_polygon(_ribbon(line, 11.0, true), water.darkened(0.13))
	WATER_SURFACE.draw_shore(self, bank, silt, water, winter, [BRIDGE_DECK.grow(4.0), FORD_AREA])

func _draw_crossings() -> void:
	var deck := BRIDGE_DECK
	draw_rect(deck.grow(2), Color("#534332"))
	draw_rect(deck, Color("#ba9967"))
	for plank in 10:
		var x := deck.position.x + 2 + plank * 5
		draw_rect(Rect2(x, deck.position.y + 2, 1, 22), Color("#96744d"))
		draw_rect(Rect2(x + 1, deck.position.y + 2, 2, 1), Color("#dec18b"))
	for side: float in [-1.0, 1.0]:
		var rail_y := BRIDGE.y + side * 13
		draw_rect(Rect2(BRIDGE.x - 27, rail_y - 1, 54, 2), Color("#795636"))
		for end: float in [-1.0, 1.0]:
			var foot := BRIDGE + Vector2(end * 25, side * 13)
			draw_rect(Rect2(foot - Vector2(2, 3), Vector2(4, 7)), Color("#755538"))
			draw_rect(Rect2(foot - Vector2(1, 3), Vector2(2, 2)), Color("#dec18b"))

	var ford_water: Color = WATER_TINTS[season]
	var shoal := PackedVector2Array()
	var edge_y: Array[float] = [-17.0, -12.0, -6.0, 4.0, 12.0, 17.0]
	var half_widths: Array[float] = [5.0, 12.0, 18.0, 18.0, 13.0, 7.0]
	for i in edge_y.size():
		var y := FORD.y + edge_y[i]
		shoal.append(Vector2(roundf(creek_x(y)) - half_widths[i], y))
	for i in range(edge_y.size() - 1, -1, -1):
		var y := FORD.y + edge_y[i]
		shoal.append(Vector2(roundf(creek_x(y)) + half_widths[i], y))
	draw_colored_polygon(shoal, ford_water.lightened(0.16))
	for i in 6:
		var stone := FORD + Vector2(-25 + i * 10, -4 + posmod(i * 7, 9))
		var width := 8.0 + posmod(i, 3)
		draw_rect(Rect2(stone + Vector2(-4, -2), Vector2(width + 2.0, 7)), Color("#61776a"))
		draw_rect(Rect2(stone + Vector2(-3, -4), Vector2(width, 5)), Color("#a2a898"))
		draw_rect(Rect2(stone + Vector2(-1, -5), Vector2(width - 3.0, 2)), Color("#c6c3aa"))

static func creek_x(y: float) -> float:
	for i in range(1, CREEK.size()):
		var a: Vector2 = CREEK[i - 1]
		var b: Vector2 = CREEK[i]
		if y <= b.y:
			return lerpf(a.x, b.x, clampf(inverse_lerp(a.y, b.y, y), 0.0, 1.0))
	return CREEK.back().x

func _ribbon(line: PackedVector2Array, half_width: float, uneven := false) -> PackedVector2Array:
	var band := PackedVector2Array()
	for point in line:
		var edge := half_width + (sin(point.y * 0.046) * 2.6 if uneven else 0.0)
		band.append(point - Vector2(edge, 0))
	for i in range(line.size() - 1, -1, -1):
		var point := line[i]
		var edge := half_width + (cos(point.y * 0.052) * 2.2 if uneven else 0.0)
		band.append(point + Vector2(edge, 0))
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
	if wilderness:
		_block_water(terrain, bounds.position.y - 12, BRIDGE.y - CROSSING_HALF_DEPTH)
		_block_water(terrain, BRIDGE.y + CROSSING_HALF_DEPTH, FORD.y - CROSSING_HALF_DEPTH)
		_block_water(terrain, FORD.y + CROSSING_HALF_DEPTH, bounds.end.y + 12)
	else:
		var pond := CollisionPolygon2D.new()
		pond.name = "SouthPond"
		pond.polygon = estate_terrain.pond
		terrain.add_child(pond)

	var camera := player.get_node("Camera2D") as Camera2D
	var view := bounds.grow(125)
	camera.limit_left = floori(view.position.x if wilderness else view.position.x - 60.0)
	camera.limit_right = ceili(view.end.x)
	camera.limit_top = floori(view.position.y)
	camera.limit_bottom = ceili(view.end.y if wilderness else bounds.end.y + 62.0)
	camera.force_update_scroll()

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
	if EXTERNAL_REGIONS.has(index):
		var size: Vector2 = EXTERNAL_REGIONS[index].size
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
	draw_texture_rect_region(_prop_sheet(index), bounds, _scenery_region(index), _prop_tint(index))

func _scenery_region(index: int) -> Rect2:
	if BUILDING_REGIONS.has(index):
		return BUILDING_REGIONS[index]
	if EXTERNAL_REGIONS.has(index):
		return EXTERNAL_REGIONS[index]
	var frame := Vector2(index % PROP_COLUMNS, floori(float(index) / PROP_COLUMNS))
	return Rect2(frame * PROP_SIZE, PROP_SIZE)

func _prop_sheet(index: int) -> Texture2D:
	if BUILDING_REGIONS.has(index):
		return ESTATE_BUILDINGS
	if STORAGE_TINTS.has(index):
		return ESTATE_STORAGE
	if index == Prop.TALL_BAMBOO:
		return MOUNTAIN_POST_BAMBOO
	if index in RAVINE_ACCENT_PROPS:
		return RAVINE_ACCENTS
	if MEADOW_FLOWERS.has(index):
		return MEADOW_FLOWERS[index]
	if index in ACTG_PROPS:
		return ACTG_SCENERY
	return NINJA_SCENERY if EXTERNAL_REGIONS.has(index) else SCENERY

func _prop_texture(index: int) -> AtlasTexture:
	if seasonal_textures.has(index):
		return seasonal_textures[index]
	return _atlas_texture(_prop_sheet(index), _scenery_region(index))

func _update_tree_textures() -> void:
	seasonal_textures[Prop.OAK] = _atlas_texture(SEASONAL_TREES, Rect2(Vector2(season, 0) * PROP_SIZE, PROP_SIZE))
	seasonal_textures[Prop.BLOSSOM_TREE] = _atlas_texture(SEASONAL_TREES,
		Rect2(ORCHARD_FRAMES[season] * PROP_SIZE, PROP_SIZE))
	if season == Global.Season.WINTER:
		seasonal_textures[Prop.PINE] = _atlas_texture(SEASONAL_TREES, Rect2(Vector2(2, 1) * PROP_SIZE, PROP_SIZE))
		seasonal_textures[Prop.WILLOW] = _atlas_texture(WINTER_WILLOW, Rect2(Vector2.ZERO, WINTER_WILLOW.get_size()))
	else:
		seasonal_textures[Prop.PINE] = _atlas_texture(SCENERY, _scenery_region(Prop.PINE))
		seasonal_textures[Prop.WILLOW] = _atlas_texture(ACTG_SCENERY, _scenery_region(Prop.WILLOW))

func _atlas_texture(source: Texture2D, region: Rect2) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = source
	result.region = region
	result.filter_clip = true
	return result

func _prop_tint(index: int) -> Color:
	var painted_tree := index == Prop.OAK or index == Prop.BLOSSOM_TREE \
		or (season == Global.Season.WINTER and index in [Prop.PINE, Prop.WILLOW])
	if painted_tree:
		return Color(0.88, 0.94, 0.99) if raining else Color.WHITE
	var tint := Color.WHITE
	if STORAGE_TINTS.has(index):
		tint = STORAGE_TINTS[index]
	elif index in ACTG_PROPS:
		tint = Color(0.96, 0.91, 0.85)
	elif MEADOW_FLOWERS.has(index) or index in RAVINE_ACCENT_PROPS:
		tint = Color(0.86, 0.87, 0.79)
	elif index == Prop.STUMP:
		tint = Color(0.75, 0.76, 0.82)
	elif index != Prop.TALL_BAMBOO and EXTERNAL_REGIONS.has(index):
		tint = NINJA_TINT
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
	var half_tile := Vector2(tile_map.tile_set.tile_size) / 2.0
	for cell in Global.irrigation.channels:
		if artwork.grow(half_tile.x).has_point(_tile_point(cell)):
			return false
	return not artwork.grow(half_tile.x).has_point(_tile_point(Global.irrigation.source_cell))

func _field_bounds(center: Vector2i) -> Rect2:
	return EstateLayout.field_bounds(center)

func _tile_point(cell: Vector2i) -> Vector2:
	return to_local(tile_map.to_global(tile_map.map_to_local(cell)))
