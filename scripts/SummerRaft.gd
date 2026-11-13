extends RefCounted
class_name SummerRaft

const TERM := "夏至"
const TITLE := "夏至试筏"
const PLACE := "试筏埠头"
const LANDING := RavineLayout.RAFT_LANDING
const START_Y := -106.0
const FINISH_Y := 12.0
const GATES := [Vector2(-6, -81), Vector2(6, -54), Vector2(-6, -26), Vector2(6, 2)]
const MIN_GATES := 3

static func score_text(gates: int, time_ms: int) -> String:
	return "%d/%d 道 · %.2f 秒" % [gates, GATES.size(), time_ms / 1000.0]
