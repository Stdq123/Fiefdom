extends "res://tests/WestMarketReplay.gd"

var write_previous := false
var resume_previous := false

func _play() -> void:
	if resume_previous:
		await _resume_previous()
		return
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	var world: Node2D = tree.current_scene.get_node("World")
	await Campaign.walk_estate_road_to(tree, world, Vector2(-270, -21))
	if not await _cross(&"ui_left", state.WEST_MARKET_SCENE):
		return
	var market := tree.current_scene as Node2D
	await _snapshot("01-east-entrance")
	if write_previous:
		await _time_at(0.224)
		await _button(market.get_node("%SettingsButton"))
		await _button(market.settings.save_button)
		_expect(FileAccess.file_exists(state.manual_save_path()), "Write the old market save from its settings.")
		print("MARKET_DYE_OLD_SAVED day=", state.current_day, " clock=", state.day_progress)
		return
	if not await _first_visit(market):
		return
	await _save_while_walking(market)
	await _weather_and_sample()

func _first_visit(market: Node2D) -> bool:
	var dyer: Node2D = market.dyer
	var layout = market.ground.LAYOUT
	var actor: Player = market.player
	var rack := market.get_node("DryingRack/ClothLine") as Sprite2D
	_expect(state.current_day == 1 and dyer.position == layout.DYE_RACK_STOP and rack.frame == 0,
		"The first walk into West Market shows Aling at the full drying rack.")
	await _walk(actor, [Vector2(335, 26), Vector2(328, 22)])
	await _key(KEY_E)
	var talk: Control = market.get_node_or_null("UI/Control/DialoguePanel")
	if not _expect(talk != null and talk.name_label.text == "阿苓" and "染缸" in talk.text_label.text,
			"Talk to the dye worker beside the cloth on the first visit."):
		return false
	var clock: float = state.day_progress
	var prior_position := dyer.position
	await _snapshot("02-ask-directions")
	await tree.create_timer(0.20).timeout
	_expect(state.day_progress == clock and dyer.position == prior_position, "Talking pauses the market clock.")
	await _button(talk.choices[0])
	_expect(state.market_trip_target == "绸摊" and not actor.conversation_open,
		"Take actual Silk Stall directions from the conversation.")
	await _key(KEY_M)
	await _snapshot("03-market-map")
	await _key(KEY_M)
	await Campaign.walk_market_to(tree, market, Vector2(180, 175))
	await _key(KEY_E)
	_expect(market.counter.visible and state.market_trip_target.is_empty() and state.money == 0
		and state.food_storage == 10 and state.king_storage == 0 and state.player_inventory == 0,
		"Follow the real alley, talk to the silk keeper, and leave the day-one resources intact.")
	await _key(KEY_ESCAPE)
	await Campaign.walk_market_to(tree, market, Vector2(279, 37))
	await _walk(actor, [Vector2(271, 17), Vector2(259, 0), layout.DYE_EAVE])
	_expect(actor.position.distance_to(layout.DYE_EAVE) < 3.0 and market.ground.is_on_paving(actor.position),
		"The shaded stone approach can be walked to the dye-house step.")
	await Campaign.walk_straight(tree, actor, layout.DYE_EAVE + Vector2(0, -36))
	_expect(actor.position.y > layout.DYE_HOUSE.y and actor.position.y < layout.DYE_EAVE.y,
		"The visible workshop foundation stops a walk through the front wall.")
	await _snapshot("04-workshop-step")
	print("MARKET_DYE_FIRST_VISIT day=", state.current_day, " foot=", actor.position, " stock=", state.food_storage)
	return not failed

func _save_while_walking(market: Node2D) -> void:
	await _time_at(0.218)
	var dyer: Node2D = market.dyer
	var start := dyer.position
	await tree.create_timer(0.45).timeout
	_expect(dyer.position.distance_to(start) > 4.0 and dyer.bundle.visible and dyer.body.walking,
		"The dye worker walks with a cloth bundle on the sunny morning route.")
	await _snapshot("05-carry-cloth")
	await _button(market.get_node("%SettingsButton"))
	var saved_spot := dyer.position
	var saved_clock: float = state.day_progress
	await _button(market.settings.save_button)
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	market = await _continue_market()
	if market == null:
		return
	dyer = market.dyer
	_expect(dyer.position.distance_to(saved_spot) < 2.0 and dyer.bundle.visible
		and absf(state.day_progress - saved_clock) < 0.002, "Continuing restores her along the same delivery.")
	await _time_at(0.32)
	_expect(dyer.position.is_equal_approx(market.ground.LAYOUT.DYE_DELIVERY) and not dyer.bundle.visible,
		"Once the parcel is delivered she stops near the silk stall.")
	await Campaign.walk_market_to(tree, market, Vector2(244, 145))
	await _snapshot("06-at-the-silk-stall")
	await _time_at(0.568)
	var returning := dyer.position
	await tree.create_timer(0.45).timeout
	_expect(dyer.position.y < returning.y - 2.0 and not dyer.bundle.visible, "She returns to the workshop in the afternoon.")
	await _time_at(0.79)
	var shade := market.get_node("DryingRack/ClothLine") as Sprite2D
	_expect(dyer.position == market.ground.LAYOUT.DYE_EAVE and shade.frame == 1, "At dusk the rack is empty.")
	print("MARKET_DYE_CONTINUE clock=", saved_clock, " foot=", saved_spot, " dusk=", dyer.position)

func _weather_and_sample() -> void:
	# Dates and the existing sample receipt are set to cover conditions outside the opening walk.
	var rain_day: int = state.SOLAR_TERMS.find(state.balance.rain_solar_term) + 1
	var market := await _market_at(rain_day, 0.25)
	var dyer: Node2D = market.dyer
	var layout = market.ground.LAYOUT
	var rack := market.get_node("DryingRack/ClothLine") as Sprite2D
	_expect(state.has_rain() and dyer.position == layout.DYE_EAVE and rack.frame == 1
		and not dyer.bundle.visible, "In rain the cloth is under cover and the delivery route is idle.")
	await _walk(market.player, [Vector2(273, 36), Vector2(271, 17), Vector2(259, 0)])
	await _key(KEY_E)
	var talk: Control = market.get_node_or_null("UI/Control/DialoguePanel")
	if _expect(talk != null and "收进檐下" in talk.text_label.text, "The rainy-day conversation is available at the door."):
		await _snapshot("07-rain-shelter")
		await _button(talk.choices[1])
	var winter_day: int = state.SOLAR_TERMS.find("立冬") + 1
	state.silk_sample_day = winter_day - 1
	market = await _market_at(winter_day, 0.15)
	var roof := market.get_node("DyeHouse/Building") as Sprite2D
	_expect(roof.frame == 1 and market.sample.visible, "The winter roof and the player's displayed sample load together.")
	await _snapshot("08-winter-entrance")
	await _walk(market.player, [Vector2(335, 26), Vector2(328, 22)])
	await _key(KEY_E)
	talk = market.get_node_or_null("UI/Control/DialoguePanel")
	if _expect(talk != null and "你那匹样绸" in talk.text_label.text,
			"The workshop conversation recognizes the sample already on display."):
		await _snapshot("09-sample-recognized")
		await _button(talk.choices[1])
	print("MARKET_DYE_WEATHER rain=", rain_day, " winter=", winter_day, " sample=", market.sample.visible)

func _market_at(day: int, clock: float) -> Node2D:
	state.current_day = day
	state.day_progress = clock
	tree.change_scene_to_file(state.WEST_MARKET_SCENE)
	await tree.scene_changed
	await tree.process_frame
	return tree.current_scene as Node2D

func _continue_market() -> Node2D:
	var title: Control = tree.current_scene
	_expect("西市" in title.status.text, "The title identifies the actual market save.")
	await _button(title.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	var market := tree.current_scene as Node2D
	if not _expect(market.scene_file_path == state.WEST_MARKET_SCENE, "Continue the market save into West Market."):
		return null
	return market

func _resume_previous() -> void:
	var market := await _continue_market()
	if market == null:
		return
	var dyer: Node2D = market.dyer
	_expect(state.current_day == 1 and absf(state.day_progress - 0.224) < 0.004
		and dyer.bundle.visible and not dyer.position.is_equal_approx(market.ground.LAYOUT.DYE_RACK_STOP),
		"An older save acquires the dye worker's correct route position from its existing day and watch.")
	await _snapshot("10-older-save-continued")
	print("MARKET_DYE_OLD_CONTINUE day=", state.current_day, " clock=", state.day_progress, " foot=", dyer.position)
