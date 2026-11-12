extends RefCounted
class_name SilkWorkshop

const LITERACY_LEVEL := 2
enum Action { BUILD, START_BATCH, REEL, WEAVE, SELL, OFFER }

var built := false
var leaves := 0
var cocoons := 0
var raw_silk := 0
var bolts := 0
var nights_left := 0
var night_reeling := false
var last_reeled := 0
var last_reel_thread := 0

func can_act(action: Action, balance: BalanceData, literacy: int, money: int) -> bool:
	if action == Action.BUILD:
		return not built and literacy >= LITERACY_LEVEL and money >= balance.silk_workshop_cost
	if not built:
		return false
	match action:
		Action.START_BATCH: return nights_left == 0 and leaves >= balance.silk_leaves_per_night
		Action.REEL: return cocoons > 0
		Action.WEAVE: return raw_silk >= balance.silk_thread_per_bolt
		Action.SELL, Action.OFFER: return bolts > 0
	return false

func apply(action: Action, balance: BalanceData, thread_per_cocoon: int) -> void:
	match action:
		Action.BUILD: built = true
		Action.START_BATCH: nights_left = balance.silk_batch_nights
		Action.REEL: _reel(1, thread_per_cocoon)
		Action.WEAVE:
			raw_silk -= balance.silk_thread_per_bolt
			bolts += 1
		Action.SELL, Action.OFFER: bolts -= 1

func advance_day(balance: BalanceData, fed_reelers := 0) -> bool:
	var changed := last_reeled > 0
	last_reeled = 0
	last_reel_thread = 0
	if nights_left > 0 and leaves >= balance.silk_leaves_per_night:
		leaves -= balance.silk_leaves_per_night
		nights_left -= 1
		if nights_left == 0:
			cocoons += balance.silk_cocoons_per_batch
		changed = true

	if night_reeling and fed_reelers > 0 and cocoons > 0:
		var yield_per_cocoon := thread_yield(balance, fed_reelers)
		last_reeled = mini(cocoons, fed_reelers)
		last_reel_thread = last_reeled * yield_per_cocoon
		_reel(last_reeled, yield_per_cocoon)
		changed = true
	return changed

func _reel(amount: int, thread_per_cocoon: int) -> void:
	cocoons -= amount
	raw_silk += amount * thread_per_cocoon

static func thread_yield(balance: BalanceData, workers: int) -> int:
	return balance.silk_thread_per_cocoon + workers * balance.mohist_reel_bonus
