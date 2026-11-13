extends RefCounted
class_name CropStock

const MIXED := "mixed"
const IDS := [MIXED] + CropData.IDS

var lots: Dictionary[String, int] = {}

func count(crop_id := "") -> int:
	if not crop_id.is_empty():
		return lots.get(crop_id, 0)
	var total := 0
	for amount in lots.values():
		total += amount
	return total

func add(crop_id: String, amount: int) -> void:
	if amount > 0:
		var key := crop_id if crop_id in IDS else MIXED
		lots[key] = count(key) + amount

func plan(amount: int, crop_id := "", keep: Dictionary = {}) -> Dictionary[String, int]:
	var use: Dictionary[String, int] = {}
	if amount <= 0 or amount > count(crop_id):
		return use
	if not crop_id.is_empty():
		use[crop_id] = amount
		return use

	# Bulk operations use mixed stock and surplus crops before order ingredients.
	var left := amount
	for id: String in IDS:
		var take := mini(left, maxi(0, count(id) - int(keep.get(id, 0))))
		if take > 0:
			use[id] = take
			left -= take
		if left == 0:
			return use
	for id: String in IDS:
		var taken: int = use.get(id, 0)
		var take := mini(left, count(id) - taken)
		if take > 0:
			use[id] = taken + take
			left -= take
		if left == 0:
			break
	return use

func can_spend(use: Dictionary) -> bool:
	for id in use:
		if use[id] <= 0 or use[id] > count(id):
			return false
	return true

func spend(use: Dictionary) -> bool:
	if not can_spend(use):
		return false
	for id in use:
		lots[id] -= use[id]
		if lots[id] == 0:
			lots.erase(id)
	return true
