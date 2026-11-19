extends SceneTree

var failed := false

func _initialize() -> void:
	_check.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _check() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run market-counter-reading in an isolated profile.")
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	var prefs := root.get_node("Preferences")
	state.current_day = 14
	state.money = 3
	state.king_storage = 7
	state.crop_stock.lots["beans"] = 1
	state.fish_collection["perch"] = {"first_day": 13, "first_site": 1, "stock": 1}
	state.silk_workshop.built = true
	state.silk_workshop.bolts = 4
	if change_scene_to_file("res://scenes/WestMarket.tscn") != OK:
		push_error("Mount the paused market.")
		quit(1)
		return
	await scene_changed
	var counter := current_scene.get_node("UI/Control/Counter") as Control
	var stall = load("res://scripts/MarketStall.gd")
	counter.open_for(stall.Kind.GRAIN)
	var grain: Control = counter.grain
	grain.quantity.value = 6
	grain.crop_choice.select(state.crop_stock.get_script().IDS.find("beans") + 1)
	grain._refresh_trade()
	_expect(grain.debit_plan.text == "出售或转粮还差 5 份菽\n买粮还差 27 铜钱"
		and grain.sell_button.disabled and grain.convert_button.disabled and grain.buy_button.disabled,
		"Both shortages remain visible with the selected kind and amount.")
	var standard: int = grain.debit_plan.get_theme_font_size("font_size")
	_expect(prefs.set_reading_size(2) == OK and grain.debit_plan.get_theme_font_size("font_size") == standard + 6,
		"Grain quotes use the reading size.")
	counter.open_for(stall.Kind.FISH)
	var row: Dictionary = counter.fish.rows["perch"]
	_expect(row.sell.text == "售 1 尾 · +16 铜钱" and row.food.text == "留 1 尾 · 口粮 +5"
		and not row.sell.disabled and counter.fish.market_offer.copper_button.visible,
		"Ordinary stock and the seasonal order show their own exchange.")
	counter.open_for(stall.Kind.SILK)
	_expect(counter.silk_quote.text == "交 1 匹丝绸 · 收 35 铜钱\n售后余 3 匹，钱袋 38 枚"
		and not counter.sell_silk.disabled, "The silk counter shows the projected balance and stock.")
	_expect(state.silk_workshop.bolts == 4 and state.money == 3 and state.fish_count("perch") == 1
		and state.crop_stock.count("beans") == 1 and state.saved_games().is_empty(), "Reading preserves the goods and purse.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
