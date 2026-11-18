extends RefCounted
class_name WinterSupper

const TERM := "冬至"
const PLACE := "冬至围炉"
const HOST := "禾伯"
const EVENING := 11.0 / 16.0
const BEAN := "wheat_bean"
const FISH := "wheat_fish"
const MENU := [BEAN, FISH]
const RECIPES := {
	BEAN: {"name": "麦菽粥", "crops": {"wheat": 1, "beans": 1}},
	FISH: {"name": "鱼麦羹", "crops": {"wheat": 1}},
}

static func portions(recipe: String, balance: BalanceData) -> int:
	return balance.winter_fish_rations if recipe == FISH else balance.winter_bean_rations
