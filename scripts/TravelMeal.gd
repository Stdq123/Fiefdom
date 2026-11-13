extends RefCounted
class_name TravelMeal

const BEAN_MILLET := "bean_millet"
const RICE_FISH := "rice_fish"
const WHEAT_CAKE := "wheat_cake"
const RECIPES := {
	BEAN_MILLET: {"name": "菽黍饭", "crops": {"beans": 1, "millet": 1}, "frame": 0},
	RICE_FISH: {"name": "稻鱼羹", "crops": {"rice": 1}, "frame": 1},
	WHEAT_CAKE: {"name": "麦饼", "crops": {"wheat": 1}, "frame": 2},
}

static func benefits(meal: String, balance: BalanceData) -> Vector2i:
	if meal == BEAN_MILLET:
		return Vector2i(balance.bean_millet_stamina, 0)
	if meal == WHEAT_CAKE:
		return Vector2i(balance.wheat_cake_stamina, 0)
	return Vector2i(balance.rice_fish_stamina, balance.rice_fish_health)

static func describe_recovery(amount: Vector2i) -> String:
	if amount.x > 0 and amount.y > 0:
		return "体力 +%d · 气血 +%d" % [amount.x, amount.y]
	return "体力 +%d" % amount.x if amount.x > 0 else "气血 +%d" % amount.y

static func icon(meal: String) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/world/travel-meals.svg")
	texture.region = Rect2(RECIPES[meal].frame * 32, 0, 32, 32)
	texture.filter_clip = true
	return texture
