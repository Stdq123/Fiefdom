extends RefCounted
class_name RavineLayout

const BOUNDS := Rect2(-436, -508, 990, 882)
const WEST_GATE := Vector2(-376, 20)
const WEST_ARRIVAL := Vector2(-334, 20)
const GROVE_FORK := Vector2(-184, 18)
const FORD_FORK := Vector2(-75, 6)
const SHORE_FORK := Vector2(38, 13)
const DOCK_FORK := Vector2(81, -88)
const WILLOW_FORK := Vector2(167, -404)
const RAFT_LANDING := Vector2(104, -102)
const BRIDGE := Vector2(148, 36)
const BRIDGE_DECK := Rect2(BRIDGE - Vector2(27, 13), Vector2(54, 26))
const FORD := Vector2(213, 182)
const FORD_WEST := FORD + Vector2(-35, 0)
const FORD_EAST := FORD + Vector2(35, 0)
const RIDGE_FORK := Vector2(330, 19)
const SOUTH_TRAIL_GATE := Vector2(205, 347)
const SOUTH_TRAIL_ARRIVAL := Vector2(203, 310)
const SOUTH_TRAIL_NAME := "南路小径"

const FRUIT := Vector2(-139, -123)
const HERBS := Vector2(452, -102)
const WILLOW_POOL := Vector2(190, -410)
const POOL_TRAP := Vector2(155, -448)
const GRAVEL_SHOAL := Vector2(277, 229)
const SHOAL_TRAP := Vector2(312, 283)
const LOOKOUT := Vector2(431, -108)

const BRIDGE_JOURNAL := Vector2(118, 27)
const FORD_JOURNAL := FORD_EAST + Vector2(10, 13)
const LOOKOUT_JOURNAL := Vector2(412, -80)

const MAIN_TRAIL := [
	Vector2(-595, 18), Vector2(-491, 19), Vector2(-433, 26), WEST_GATE, WEST_ARRIVAL,
	Vector2(-284, 33), Vector2(-239, 39), GROVE_FORK, Vector2(-126, 12), FORD_FORK,
	Vector2(-12, 9), SHORE_FORK, Vector2(78, 20), Vector2(114, 36), BRIDGE, Vector2(184, 36),
	Vector2(223, 27), Vector2(269, 19), RIDGE_FORK,
]
const BERRY_LANE := [
	GROVE_FORK, Vector2(-196, -24), Vector2(-192, -65), Vector2(-170, -103), FRUIT,
]
const WEST_SHORE := [
	SHORE_FORK, Vector2(54, -22), Vector2(66, -62), DOCK_FORK,
	Vector2(68, -134), Vector2(61, -180), Vector2(76, -223), Vector2(101, -263),
	Vector2(112, -298), Vector2(133, -335), Vector2(153, -370), WILLOW_FORK, WILLOW_POOL,
]
const DOCK_LANE := [DOCK_FORK, Vector2(95, -99), RAFT_LANDING]
const POOL_TRAP_LANE := [WILLOW_FORK, Vector2(161, -427), POOL_TRAP]
const FORD_TRAIL := [
	FORD_FORK, Vector2(-59, 44), Vector2(-28, 83), Vector2(19, 109), Vector2(72, 126),
	Vector2(118, 148), Vector2(151, 172), FORD_WEST, FORD, FORD_EAST, Vector2(277, 167),
	Vector2(297, 135), Vector2(310, 98), Vector2(323, 58), RIDGE_FORK,
]
const SHOAL_LANE := [
	FORD_EAST, Vector2(261, 206), GRAVEL_SHOAL, Vector2(289, 255), SHOAL_TRAP,
]
const RIDGE_LANE := [
	RIDGE_FORK, Vector2(348, -17), Vector2(376, -51), LOOKOUT_JOURNAL, Vector2(430, -90), HERBS,
]
const SOUTH_TRAIL := [
	FORD_WEST, Vector2(169, 223), Vector2(183, 263), SOUTH_TRAIL_ARRIVAL,
	SOUTH_TRAIL_GATE, Vector2(190, 392), Vector2(184, 453), Vector2(184, 518),
]
const TRACKS := [MAIN_TRAIL, BERRY_LANE, WEST_SHORE, DOCK_LANE, POOL_TRAP_LANE, FORD_TRAIL, SHOAL_LANE, RIDGE_LANE, SOUTH_TRAIL]
const TRACK_WIDTHS: Array[float] = [26.0, 13.0, 16.0, 12.0, 10.0, 17.0, 13.0, 15.0, 14.0]

const CREEK := [
	Vector2(210, -665), Vector2(184, -552), Vector2(188, -490), Vector2(202, -450),
	Vector2(226, -410), Vector2(228, -378), Vector2(206, -341), Vector2(177, -302),
	Vector2(153, -267), Vector2(145, -234), Vector2(147, -204), Vector2(158, -171),
	Vector2(151, -136), Vector2(132, -73),
	Vector2(139, -19), Vector2(145, 17), BRIDGE, Vector2(149, 79), Vector2(161, 102), Vector2(177, 119),
	Vector2(192, 143), FORD, Vector2(256, 246), Vector2(283, 338), Vector2(308, 412), Vector2(334, 528),
]
# The fishing shelves share their water-facing edge with the visible rock faces.
const WILLOW_WATERLINE := [
	Vector2(180, -469), Vector2(183, -459), Vector2(187, -447), Vector2(196, -434),
	Vector2(205, -418), Vector2(210, -405), Vector2(210, -389), Vector2(210, -376),
]
const WILLOW_BANK := WILLOW_WATERLINE + [
	Vector2(193, -373), Vector2(175, -377), Vector2(155, -389), Vector2(145, -404),
	Vector2(138, -421), Vector2(134, -439), Vector2(141, -455), Vector2(156, -469), Vector2(173, -471),
]
const GRAVEL_WATERLINE := [
	Vector2(244, 202), Vector2(252, 214), Vector2(260, 227), Vector2(268, 238),
	Vector2(275, 251), Vector2(279, 264), Vector2(282, 277),
]
const GRAVEL_BAR := GRAVEL_WATERLINE + [
	Vector2(293, 274), Vector2(302, 268), Vector2(312, 255), Vector2(313, 242),
	Vector2(306, 222), Vector2(291, 207), Vector2(277, 198), Vector2(259, 197),
]
