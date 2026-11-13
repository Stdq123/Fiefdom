extends RefCounted
class_name NightRations

const MAX_COPPER_LIMIT := 2147483647
const MISSED_MEAL_LOYALTY := 20.0

var enabled := false
var partial_meals := false
var copper_limit := 0
var priority: RetainerData
var last: Dictionary = {}

func plan(need: int, food: int, money: int, stock: CropStock, keep: Dictionary, unit_price: int,
		allocate_meals: Callable) -> Dictionary:
	var missing := maxi(0, need - food)
	var reserved: Dictionary[String, int] = {}
	for id: String in keep:
		var amount := mini(stock.count(id), int(keep[id]))
		if amount > 0:
			reserved[id] = amount
	var result := {
		"need": need, "missing": missing, "uncovered": missing, "reserved": reserved,
		"used": {}, "converted": 0, "bought": 0, "copper": 0,
	}
	if not enabled or missing == 0:
		return result
	var converted := mini(missing, stock.count() - stock_count(reserved))
	var price := maxi(1, unit_price)
	var affordable := floori(float(mini(copper_limit, maxi(0, money))) / price)
	var bought := mini(missing - converted, affordable)
	var supplement := converted + bought
	result.uncovered = missing - supplement
	if result.uncovered > 0:
		if not partial_meals:
			return result
		var meal: Dictionary = allocate_meals.call(food + supplement)
		supplement = maxi(0, int(meal.served) - food)
		result.uncovered = missing - supplement
	result.converted = mini(converted, supplement)
	result.bought = supplement - int(result.converted)
	result.used = stock.plan(result.converted, "", keep)
	result.copper = result.bought * price
	return result

static func stock_count(lots: Dictionary) -> int:
	var total := 0
	for amount: int in lots.values():
		total += amount
	return total
