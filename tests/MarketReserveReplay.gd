extends "res://tests/NightRationsReplay.gd"

const RESERVE_DAY := 63
const AUTUMN_DAY := 64
const WINTER_START := 67
const INITIAL_CROPS := {"mixed": 1, "millet": 1, "sorghum": 2, "beans": 1, "hemp": 1, "wheat": 2}
const HELD_CROPS := {"millet": 1, "sorghum": 2, "beans": 1, "hemp": 1, "wheat": 2}
const AFTER_OVERRIDE := {"sorghum": 1, "beans": 1, "hemp": 1, "wheat": 2}

var management: Control

func run_market_reserve(host: SceneTree, mode := "", captures := "") -> void:
	tree = host
	state = tree.root.get_node("Global")
	capture_dir = captures
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"),
			"Use an isolated market reserve profile."):
		_end()
		return
	if mode != "market-reserve-resume":
		_write_fixture()
	if not await _continue():
		_end()
		return
	if mode != "market-reserve-resume":
		await _set_holds()
		await _save_manually()
	var checkpoint: String = state.manual_save_path()
	if not _expect(state.current_day == RESERVE_DAY and state.food_storage == 3 and state.money == 110
			and state.crop_stock.lots == INITIAL_CROPS and state.pinned_season_start == WINTER_START
			and state.night_rations.festival_day == AUTUMN_DAY and state.research_fee_due(AUTUMN_DAY) == 100
			and state.retainer_food_cost() == 2 and state.can_deliver_season_order(state.season_order()),
			"The same evening has a ready autumn order, winter wheat, a festival hold and a funded fee."):
		_end()
		return
	if mode == "market-reserve-baseline":
		await _baseline()
	else:
		state.balance.raid_first_day = 10000
		await _protected()
		if mode != "market-reserve-resume" and await _restore(checkpoint):
			await _explicit_choice()
			if await _restore(checkpoint):
				await _construction()
	_end()

func _write_fixture() -> void:
	var file := FileAccess.open(state.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"save_version": 2, "legacy_order_start": 0, "current_day": RESERVE_DAY, "current_rank": state.Rank.DA_FU,
		"tax_reform_choice": state.TaxReformChoice.DELAYED, "tax_reform_day": RESERVE_DAY - 1, "tax_reform_year": 3,
		"food_storage": 3, "money": 110, "king_storage": 30, "private_harvest_total": 65, "reputation": 325,
		"player_inventory": NightRations.stock_count(INITIAL_CROPS), "crop_stock": INITIAL_CROPS,
		"retainers": [
			{"name": "渠伯", "school": 2, "duty": RetainerData.Duty.FIELD, "loyalty": 80},
			{"name": "石墨", "school": 2, "duty": RetainerData.Duty.FIELD, "loyalty": 80},
		],
	}))
	file.close()

func _continue() -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	tree.root.notify_mouse_entered()
	await tree.process_frame
	var button: Button = tree.current_scene.continue_button
	if not _expect(button.visible and not button.disabled, "The title offers Continue for the staged campaign."):
		return false
	await _click(button)
	if tree.current_scene == null:
		await tree.scene_changed
	return await _bind_estate()

func _restore(path: String) -> bool:
	if not _expect(state.load_game(path) == OK, "Restore the saved pre-market checkpoint."):
		return false
	await tree.scene_changed
	return await _bind_estate()

func _bind_estate() -> bool:
	if not _expect(tree.current_scene.has_node("UI"), "Continue to the ordinary estate."):
		return false
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame
	return true

func _set_holds() -> void:
	await _click(ui.hud.season_event_button)
	var book: Control = ui.calendar
	if _expect(book.keep_samples.is_visible_in_tree(), "The autumn notice offers the real sample hold."):
		await _click(book.keep_samples)
	await _click(book.close_button)
	await _click(ui.manage_button)
	management = ui.panel_manager.management_panel_instance
	management.show_season_orders()
	await tree.process_frame
	await _click(management.season_order_panel.next_plan_button)
	await _click(management.close_button)

func _save_manually() -> void:
	await _click(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _click(button)
			break
	_expect(settings.save_status.text == "游戏已保存", "Settings writes the real checkpoint for this executable.")
	await _click(settings.close_button)

func _market() -> Control:
	var ration_panel := await _open()
	if not _expect(ration_panel != null, "Open the night ledger from its HUD button."):
		return null
	await _click(ration_panel.get_node("%Market"))
	management = ui.panel_manager.management_panel_instance
	var market: Control = management.market_panel
	_expect(market.is_visible_in_tree() and market.reserve_kind.selected == market.ReserveKind.HOUSEHOLD,
		"The night ledger leads to the household quote.")
	return market

func _baseline() -> void:
	var market := await _market()
	if market == null:
		return
	var quote: Dictionary = state.food_reserve_plan(3)
	_expect(quote.used == {"mixed": 1, "millet": 1, "sorghum": 1} and quote.copper == 0,
		"The previous executable uses the held millet and then an order crop.")
	await _capture("01-previous-quote")
	await _click(market.reserve_button)
	_expect(state.food_storage == 6 and state.money == 110 and state.crop_stock.lots == AFTER_OVERRIDE
		and not state.can_deliver_season_order(state.season_order()),
		"The previous executable fills the granary but the ready autumn order becomes short.")
	await _capture("02-previous-exchange")
	print("MARKET_RESERVE_BASELINE food=", state.food_storage, " copper=", state.money, " used=", quote.used,
		" ready=", state.can_deliver_season_order(state.season_order()), " save=", state.manual_save_path())

func _protected() -> void:
	var market := await _market()
	if market == null:
		return
	var quote: Dictionary = state.food_reserve_plan(3)
	_expect(quote.used == {"mixed": 1} and quote.retained == HELD_CROPS and quote.copper == 10
		and quote.research_day == AUTUMN_DAY and quote.research_reserve == 100 and quote.can_order
		and market.use_reserved.visible and not market.use_reserved.button_pressed,
		"The household quote holds seven crops and the next fee while offering one crop and two bought rations.")
	_expect_window(market)
	await _capture("01-protected-quote")

	# Simulate an account change between the displayed quote and the click.
	state.money = 109
	await _click(market.reserve_button)
	_expect(state.food_storage == 3 and state.crop_stock.lots == INITIAL_CROPS and state.money == 109
		and market.reserve_button.disabled and "请核对新计划" in market.receipt.text,
		"A displayed quote cannot apply after it becomes unaffordable.")
	state.money = 110
	tree.root.get_node("GameEvents").money_changed.emit(state.money)
	await _click(market.reserve_button)
	_expect(state.food_storage == 6 and state.money == 100 and state.crop_stock.lots == HELD_CROPS
		and state.king_storage == 30 and state.can_deliver_season_order(state.season_order())
		and market.reserve_button.disabled and not market.use_reserved.visible,
		"The agreed transaction fills three nights, keeping the treasury, pledge and fee.")
	await _capture("02-protected-exchange")
	await _click(management.close_button)
	await _sleep("03-fee-paid")
	_expect(state.current_day == AUTUMN_DAY and state.food_storage == 4 and state.money == 0
		and not state.research_choice_pending and state.night_rations.last.get("served") == 2
		and "研究经费已缴 100 铜钱" in ui.hud.dawn_notice.result_label.text
		and state.crop_stock.lots == HELD_CROPS and state.can_deliver_season_order(state.season_order()),
		"Ordinary sleep feeds both retainers, pays the fee and leaves autumn delivery available.")
	print("MARKET_RESERVE_PROTECTED day=", state.current_day, " food=", state.food_storage,
		" reserved_crops=", state.crop_stock.lots, " paid_fee=", 100 - state.money,
		" order_ready=", state.can_deliver_season_order(state.season_order()))
	await _deliver_autumn_order()

func _deliver_autumn_order() -> void:
	await _click(ui.manage_button)
	management = ui.panel_manager.management_panel_instance
	management.show_season_orders()
	await tree.process_frame
	var order: Control = management.season_order_panel
	var schedule: Dictionary = state.season_order()
	var reward: int = state.season_order_rewards(schedule).copper
	if not _expect(order.copper_button.is_visible_in_tree() and not order.copper_button.disabled,
			"The normal order book still accepts the autumn cargo."):
		return
	await _click(order.copper_button)
	_expect(state.season_order_delivered_at(schedule) == AUTUMN_DAY and state.money == reward
		and state.crop_stock.lots == {"millet": 1, "wheat": 2} and state.king_storage == 30,
		"Deliver the full autumn order while keeping the reserved millet and winter wheat.")
	await _capture("03a-autumn-order-receipt")
	print("MARKET_RESERVE_DELIVERY reward=", reward, " day=", state.season_order_delivered_at(schedule),
		" remaining_crops=", state.crop_stock.lots)

func _explicit_choice() -> void:
	state.money = 105
	var market := await _market()
	if market == null:
		return
	_expect(market.reserve_button.disabled and "还差 5 铜钱" in market.reserve_label.text
		and not market.use_reserved.button_pressed and state.food_storage == 3,
		"The tighter budget shows how much more is needed with reserves intact.")
	await _capture("04-short-after-holds")
	await _pad_click(market.use_reserved)
	_expect(market.use_reserved.button_pressed and not market.reserve_button.disabled
		and "将动用预留 黍 1、稷 1" in market.reserve_label.text
		and state.crop_stock.lots == INITIAL_CROPS and state.money == 105,
		"Opting in previews the exact reserved lots and debits nothing.")
	await _capture("05-explicit-reserve-quote")
	await _click(management.close_button)
	market = await _market()
	if market == null:
		return
	_expect(not market.use_reserved.button_pressed and market.reserve_button.disabled,
		"Closing and reopening restores the protected default before any order.")
	await _pad_click(market.use_reserved)
	await _pad_click(market.reserve_button)
	_expect(state.food_storage == 6 and state.crop_stock.lots == AFTER_OVERRIDE and state.money == 105
		and not market.use_reserved.visible and not market.use_reserved.button_pressed and market.reserve_kind.has_focus(),
		"Confirming with a pad spends exactly the displayed crops and returns focus to the plan selector.")
	print("MARKET_RESERVE_OVERRIDE food=", state.food_storage, " remaining_crops=", state.crop_stock.lots, " copper=", state.money)

func _construction() -> void:
	var site: Dictionary = state.reclamation_plan()
	state.food_storage = site.grain + site.crew_food - 3
	state.money = site.copper + 110
	await _click(ui.hud.reclaim_button)
	var survey := ui.get_node_or_null("Control/ReclamationPanel") as Control
	if not _expect(survey != null and survey.market_button.is_visible_in_tree(),
			"The real reclamation ledger offers a shortcut for crew supplies."):
		return
	await _click(survey.market_button)
	management = ui.panel_manager.management_panel_instance
	var market: Control = management.market_panel
	_expect_window(market)
	var quote: Dictionary = state.reclamation_food_plan()
	_expect(market.reserve_kind.selected == market.ReserveKind.RECLAMATION
		and market.survey_button.is_visible_in_tree() and quote.retained == HELD_CROPS and quote.used == {"mixed": 1}
		and quote.copper == 10 and quote.research_reserve == 100 and quote.copper_short == 0 and quote.can_order,
		"The construction quote budgets its site and both sets of reservations before buying two rations.")
	await _capture("06-construction-quote")
	await _click(market.reserve_button)
	_expect(state.food_storage == quote.target and state.money == site.copper + 100
		and state.crop_stock.lots == HELD_CROPS and "实付 10 铜钱" in market.receipt.text,
		"Construction buys crew food and leaves enough money for both the stakes and the fee.")
	await _capture("07-construction-exchange")
	await _click(market.survey_button)
	_expect(ui.has_node("Control/ReclamationPanel"), "Return from the quote to the reclamation ledger.")
	print("MARKET_RESERVE_CONSTRUCTION target=", quote.target, " food=", state.food_storage,
		" stakes=", site.copper, " copper_left=", state.money)

func _expect_window(market: Control) -> void:
	var frame: Rect2 = management.get_node("Frame").get_global_rect()
	_expect(frame.encloses(market.use_reserved.get_global_rect()) and frame.encloses(market.reserve_button.get_global_rect())
		and not market.use_reserved.get_global_rect().intersects(market.reserve_kind.get_global_rect()),
		"Both the reservation choice and the exchange fit inside the market.")

func _pad_click(control: Control) -> void:
	control.grab_focus()
	var pointer := tree.root.get_node("GamepadInput")
	pointer.snap_pointer_to_focus()
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await tree.process_frame
	await tree.process_frame
