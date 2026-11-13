extends RefCounted

const BOUNDS := Rect2(-282, -142, 564, 326)
const MARKET_GATE := Vector2(-258, 36)
const ESTATE_GATE := Vector2(258, 36)
const BRIDGE := Rect2(-49, 16, 94, 40)
const MEADOW_JUNCTION := Vector2(127, 32)
const MEADOW := Vector2(165, 136)
const MEADOW_TRACK := [
	MEADOW_JUNCTION, Vector2(115, 62), Vector2(106, 91), Vector2(118, 114),
	Vector2(144, 128), MEADOW,
]
const ROAD := [
	Vector2(-400, 36), MARKET_GATE, Vector2(-192, 40), Vector2(-119, 38),
	Vector2(-59, 36), Vector2(59, 36), MEADOW_JUNCTION, Vector2(196, 34), ESTATE_GATE, Vector2(400, 36),
]
const CREEK := [
	Vector2(-48, -400), Vector2(-52, -170), Vector2(-42, -106), Vector2(-23, -59),
	Vector2(-5, -14), Vector2(-4, 38), Vector2(-15, 87), Vector2(-35, 130),
	Vector2(-51, 192), Vector2(-27, 425),
]
