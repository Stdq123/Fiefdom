extends RefCounted
class_name FieldSeedPlan

const BEANS := "beans"
const SEASONAL := "seasonal"
const SEASONAL_CROPS := [BEANS, "rice", "sorghum", "wheat"]
const ROTATION_PREFIX := "rotation:"
const ORDER_PREFIX := "order:"

static func seasonal_seed(season: int, has_canal_water: bool) -> String:
	var seed: String = SEASONAL_CROPS[season]
	return "millet" if seed == "rice" and not has_canal_water else seed

static func with_beans(seed_id: String) -> String:
	return ROTATION_PREFIX + seed_id

static func is_rotation(plan: String) -> bool:
	return plan.begins_with(ROTATION_PREFIX)

static func for_order(start_day: int, seed_id: String) -> String:
	return "%s%d:%s" % [ORDER_PREFIX, start_day, seed_id]

static func is_order(plan: String) -> bool:
	return plan.begins_with(ORDER_PREFIX)

static func order_start(plan: String) -> int:
	return plan.get_slice(":", 1).to_int() if is_order(plan) else 0

static func crop_id(plan: String) -> String:
	return plan.get_slice(":", 2) if is_order(plan) else plan.trim_prefix(ROTATION_PREFIX)

static func supports_rotation(crop: CropData) -> bool:
	return not crop.restores_fertility and not crop.is_perennial

static func is_valid(plan: String) -> bool:
	if plan == SEASONAL:
		return true
	var crop := ItemManager.get_crop(crop_id(plan))
	if is_order(plan):
		return (crop != null and not crop.is_perennial and plan.get_slice_count(":") == 3
			and plan.get_slice(":", 1).is_valid_int() and order_start(plan) > 0)
	return crop != null and (not is_rotation(plan) or supports_rotation(crop))
