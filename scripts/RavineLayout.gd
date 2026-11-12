extends RefCounted
class_name RavineLayout

const BOUNDS := Rect2(-436, -276, 990, 650)
const WEST_GATE := Vector2(-376, 20)
const WEST_ARRIVAL := Vector2(-334, 20)
const GROVE_FORK := Vector2(-184, 18)
const FORD_FORK := Vector2(-75, 6)
const SHORE_FORK := Vector2(38, 13)
const DOCK_FORK := Vector2(81, -88)
const WILLOW_FORK := Vector2(114, -185)
const RAFT_LANDING := Vector2(104, -102)
const BRIDGE := Vector2(148, 36)
const FORD := Vector2(213, 182)
const FORD_WEST := FORD + Vector2(-35, 0)
const FORD_EAST := FORD + Vector2(35, 0)
const RIDGE_FORK := Vector2(330, 19)

const FRUIT := Vector2(-139, -123)
const HERBS := Vector2(446, -106)
const WILLOW_POOL := Vector2(138, -180)
const POOL_TRAP := Vector2(126, -210)
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
	SHORE_FORK, Vector2(54, -22), Vector2(66, -62), DOCK_FORK, Vector2(88, -128),
	Vector2(99, -161), WILLOW_FORK, WILLOW_POOL,
]
const DOCK_LANE := [DOCK_FORK, Vector2(95, -99), RAFT_LANDING]
const POOL_TRAP_LANE := [WILLOW_FORK, Vector2(117, -201), POOL_TRAP]
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
const TRACKS := [MAIN_TRAIL, BERRY_LANE, WEST_SHORE, DOCK_LANE, POOL_TRAP_LANE, FORD_TRAIL, SHOAL_LANE, RIDGE_LANE]
const TRACK_WIDTHS: Array[float] = [26.0, 13.0, 16.0, 12.0, 10.0, 17.0, 13.0, 15.0]

const CREEK := [
	Vector2(275, -452), Vector2(237, -331), Vector2(203, -250), Vector2(177, -193), Vector2(151, -136), Vector2(132, -73),
	Vector2(139, -19), Vector2(145, 17), BRIDGE, Vector2(149, 79), Vector2(161, 102), Vector2(177, 119),
	Vector2(192, 143), FORD, Vector2(256, 246), Vector2(283, 338), Vector2(308, 412), Vector2(334, 528),
]
