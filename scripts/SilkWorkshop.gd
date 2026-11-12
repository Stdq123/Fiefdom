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
var repeat_batches := false
var night_reeling := false
var last_leaves_used := 0
var last_hatched := 0
var last_reeled := 0
var last_reel_thread := 0

func batch_leaf_cost(balance: BalanceData) -> int:
	return balance.silk_leaves_per_night * balance.silk_batch_nights

func capacity(action: Action, balance: BalanceData) -> int:
	match action:
		Action.REEL: return cocoons
		Action.WEAVE:
			@warning_ignore("integer_division")
			return raw_silk / balance.silk_thread_per_bolt
	return 1

func can_act(action: Action, balance: BalanceData, literacy: int, money: int) -> bool:
	if action == Action.BUILD:
		return not built and literacy >= LITERACY_LEVEL and money >= balance.silk_workshop_cost
	if not built:
		return false
	match action:
		Action.START_BATCH: return nights_left == 0 and leaves >= balance.silk_leaves_per_night
		Action.REEL, Action.WEAVE: return capacity(action, balance) > 0
		Action.SELL, Action.OFFER: return bolts > 0
	return false

func apply(action: Action, balance: BalanceData, thread_per_cocoon: int, amount := 1) -> void:
	match action:
		Action.BUILD: built = true
		Action.START_BATCH: nights_left = balance.silk_batch_nights
		Action.REEL:
			cocoons -= amount
			raw_silk += amount * thread_per_cocoon
		Action.WEAVE:
			raw_silk -= amount * balance.silk_thread_per_bolt
			bolts += amount
		Action.SELL, Action.OFFER: bolts -= 1

func plan_night(balance: BalanceData, fed_reelers: int) -> Dictionary:
	var starts_batch := repeat_batches and nights_left == 0 and leaves >= batch_leaf_cost(balance)
	var remaining := balance.silk_batch_nights if starts_batch else nights_left
	var feed := 0
	var hatched := 0
	if remaining > 0 and leaves >= balance.silk_leaves_per_night:
		feed = balance.silk_leaves_per_night
		remaining -= 1
		if remaining == 0:
			hatched = balance.silk_cocoons_per_batch
	var reeled := mini(cocoons + hatched, fed_reelers) if night_reeling else 0
	return {"starts_batch": starts_batch, "remaining": remaining, "feed": feed, "hatched": hatched,
		"reeled": reeled, "thread": reeled * thread_yield(balance, fed_reelers)}

func advance_day(balance: BalanceData, fed_reelers := 0) -> bool:
	var previous_work := last_leaves_used > 0 or last_reeled > 0
	var plan := plan_night(balance, fed_reelers)
	nights_left = plan.remaining
	last_leaves_used = plan.feed
	last_hatched = plan.hatched
	last_reeled = plan.reeled
	last_reel_thread = plan.thread
	leaves -= last_leaves_used
	cocoons += last_hatched - last_reeled
	raw_silk += last_reel_thread
	return previous_work or last_leaves_used > 0 or last_reeled > 0

func describe_tonight(balance: BalanceData, fed_reelers: int) -> String:
	var plan := plan_night(balance, fed_reelers)
	var details := _work_details(plan.feed, plan.hatched, plan.reeled, plan.thread)
	if plan.starts_batch:
		details.insert(0, "续养一批")
	elif plan.feed == 0:
		if nights_left > 0:
			details.insert(0, "喂养缺 %d 片桑叶" % (balance.silk_leaves_per_night - leaves))
		elif repeat_batches:
			details.insert(0, "续养还差 %d 片桑叶" % (batch_leaf_cost(balance) - leaves))
	if night_reeling and plan.reeled == 0 and cocoons + plan.hatched > 0:
		details.append("暂无领足口粮的缫丝门客")
	return " · ".join(details)

func last_work_summary() -> String:
	return " · ".join(_work_details(last_leaves_used, last_hatched, last_reeled, last_reel_thread))

func _work_details(feed: int, hatched: int, reeled: int, thread: int) -> PackedStringArray:
	var details := PackedStringArray()
	if feed > 0:
		details.append("用桑叶 %d 片" % feed)
	if hatched > 0:
		details.append("结茧 %d 只" % hatched)
	if reeled > 0:
		details.append("缫 %d 茧得 %d 生丝" % [reeled, thread])
	return details

static func thread_yield(balance: BalanceData, workers: int) -> int:
	return balance.silk_thread_per_cocoon + workers * balance.mohist_reel_bonus
