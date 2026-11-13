extends RefCounted

const BOUNDS := Rect2(-435, -200, 870, 426)
const BASIN := Rect2(-250, -145, 60, 38)
const FISH_PICKUP := Vector2(-198, -91)
const CART_STOP := Vector2(-262, 180)
const EAST_GATE := Vector2(392, 36)
const EAST_OUTSIDE := Vector2(526, 36)
const SILK_JUNCTION := Vector2(206, 57)
const FISH_JUNCTION := Vector2(-38, 61)
const YARD_ENTRANCE := Vector2(-195, 117)
const UNLOADING_YARD := Vector2(-272, 143)
const GRAIN_COURT := Vector2(-340, 142)
const TAO_STOP := Vector2(233, 177)

const MAIN_ROAD := [
	GRAIN_COURT, UNLOADING_YARD, YARD_ENTRANCE, Vector2(-123, 73), FISH_JUNCTION,
	Vector2(48, 74), Vector2(134, 76), SILK_JUNCTION, Vector2(273, 36), EAST_GATE,
]
const FISH_LANE := [
	FISH_JUNCTION, Vector2(-41, 18), Vector2(-61, -32), Vector2(-96, -70), Vector2(-161, -112),
]
const SILK_LANE := [SILK_JUNCTION, Vector2(233, 98), Vector2(248, 142), Vector2(244, 164), TAO_STOP, Vector2(180, 175)]
const GRAIN_LANE := [GRAIN_COURT, Vector2(-340, 122)]
const BOARD_LANE := [UNLOADING_YARD, Vector2(-280, 157)]
const CART_DRIVE := [CART_STOP, Vector2(-218, 180), Vector2(-200, 156), YARD_ENTRANCE]
const WALKING_ROADS := [MAIN_ROAD, FISH_LANE, SILK_LANE, GRAIN_LANE, BOARD_LANE]

static func freight_path() -> Array:
	return CART_DRIVE + MAIN_ROAD.slice(MAIN_ROAD.find(YARD_ENTRANCE) + 1) + [EAST_OUTSIDE]

static func silk_guest_path() -> PackedVector2Array:
	var approach := MAIN_ROAD.slice(MAIN_ROAD.find(SILK_JUNCTION))
	approach.reverse()
	return PackedVector2Array(approach + SILK_LANE.slice(1, -1))
