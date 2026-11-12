extends RefCounted
class_name FieldSeedPlan

const BEANS := "beans"
const ROTATION_PREFIX := "rotation:"

static func with_beans(seed_id: String) -> String:
	return ROTATION_PREFIX + seed_id

static func is_rotation(plan: String) -> bool:
	return plan.begins_with(ROTATION_PREFIX)

static func crop_id(plan: String) -> String:
	return plan.trim_prefix(ROTATION_PREFIX)

static func supports_rotation(crop: CropData) -> bool:
	return not crop.restores_fertility and not crop.is_perennial

static func is_valid(plan: String) -> bool:
	var crop := ItemManager.get_crop(crop_id(plan))
	return crop != null and (not is_rotation(plan) or supports_rotation(crop))
