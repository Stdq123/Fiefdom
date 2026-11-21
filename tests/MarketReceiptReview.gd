extends RefCounted

var tree: SceneTree
var evidence := ""
var failed := false

func run(scenario: SceneTree, directory := "") -> bool:
	tree = scenario
	evidence = directory
	tree.paused = true
	await _settle()
	var state := tree.root.get_node("Global")
	var prefs := tree.root.get_node("Preferences")
	state.current_day = 14
	state.day_progress = 0.38
	state.king_storage = 7
	state.money = 125
	state.food_storage = 4
	state.current_rank = Global.Rank.DA_FU
	state.max_well_fields = 3
	state.tax_reform_choice = Global.TaxReformChoice.REFORMED
	state.retainers.assign([RetainerData.new("渠伯"), RetainerData.new("季青"), RetainerData.new("石墨"), RetainerData.new("陶辛")])
	state.crop_stock.lots.clear()
	for crop: String in CropData.IDS:
		state.crop_stock.lots[crop] = 8
	state.fish_collection["perch"] = {"first_day": 13, "first_site": 1, "stock": 2}
	state.silk_workshop.built = true
	state.silk_workshop.bolts = 3
	state.sheepfold.bought_day = 8
	state.sheepfold.wool = 3
	_expect(prefs.set_reading_size(2) == OK, "Use the largest reading size for the fixed receipts.")
	if not _expect(tree.change_scene_to_file("res://scenes/WestMarket.tscn") == OK, "Open the fixed market view."):
		return false
	await tree.scene_changed
	await _settle()
	var counter := tree.current_scene.get_node("UI/Control/Counter") as Control
	var field_hud := tree.current_scene.get_node("CampaignHUD")
	var receipt: MarketReceipt = counter.trade_receipt
	var baseline := _snapshot(state)
	_expect(counter.grain.receipt == receipt and counter.fish.receipt == receipt
		and counter.fish.market_offer.trade_receipt == receipt and counter.sheep.receipt == receipt,
		"All the market views use the one fixed receipt above the scroll area.")
	_expect(field_hud.backpack_button.visible, "The backpack button is available in the street.")
	var items := tree.root.get_node("ItemManager")
	counter.open_for(MarketStall.Kind.GRAIN)
	counter.grain.reserve_kind.select(counter.grain.reserve_kind.get_item_index(counter.grain.ReserveKind.RECLAMATION))
	counter.grain._change_reserve_kind()
	await _settle()
	_expect(counter.counter_balance.is_visible_in_tree() and "125" in counter.counter_balance.text
		and not receipt.visible and not field_hud.backpack_button.visible,
		"The grain counter starts with an empty receipt and an unobstructed balance.")
	var sale := "售出 黍 3 · 铜钱 +%d" % (3 * state.balance.market_crop_price)
	counter.grain.receipt.present_crops(sale, {"millet": 3})
	await _settle()
	_check_receipt(counter, sale, items.harvest_icon("millet"))
	var top := receipt.get_global_rect()
	await _capture("01-grain-sale")
	var bar: VScrollBar = counter.scroll.get_v_scroll_bar()
	bar.value = bar.max_value
	await _settle()
	print("MARKET_RECEIPT_SCROLL offset=", counter.scroll.scroll_vertical, " body=", counter.scroll.size.y,
		" record_before=", top, " record_after=", receipt.get_global_rect())
	_expect(counter.scroll.scroll_vertical > 0 and receipt.get_global_rect() == top,
		"Scrolling to the reserve quote keeps the transaction receipt at the top.")
	await _capture("02-grain-sale-scrolled")
	var mixed := "开垦粮已备齐 · 入仓 63 份 · 实付 188 铜钱\n转用 黍 7、稷 8、稻 8、麦 8、菽 8、桑 8、麻 8"
	counter.grain.receipt.present_crops(mixed, {"millet": 7, "beans": 8})
	await _settle()
	_check_receipt(counter, mixed, items.harvest_icon(CropStock.MIXED))
	_expect(receipt.label.get_line_count() >= 2, "Long settlement details expand the fixed receipt.")
	await _capture("03-grain-mixed-reserve")
	var buy: Button = counter.grain.buy_button
	buy.grab_focus()
	buy.disabled = true
	var warning := "库存或用粮已有变化，请核对新计划。"
	var ledger_icon := HUDIcons.icon(HUDIcons.Symbol.LEDGER)
	counter.grain.receipt.present(warning, ledger_icon, true)
	await _settle()
	_check_receipt(counter, warning, ledger_icon)
	_expect(counter.close_button.has_focus() and receipt.label.get_theme_color(&"font_color") == MarketReceipt.WARNING_INK,
		"A changed quote is readable and focus leaves an unavailable trade button.")

	counter.open_for(MarketStall.Kind.FISH)
	await _settle()
	_expect(not receipt.visible, "Switching counters clears the last transaction.")
	var offer: Dictionary = state.fish_market_offer()
	var fish_id: String = offer.fish
	var fish_record := "留鱼单 · %s −1 尾 · 粮仓 +%d 份" % [CreekFish.SPECIES[fish_id].name, offer.food]
	counter.fish.market_offer.trade_receipt.present(fish_record, CreekFish.portrait(fish_id))
	await _settle()
	_check_receipt(counter, fish_record, CreekFish.portrait(fish_id))
	var note_ink: Color = counter.fish.market_offer.note.get_theme_color(&"font_color")
	_expect(note_ink.get_luminance() > 0.65, "The order note reads clearly on its dark card.")
	await _capture("04-fish-exchange")
	counter.open_for(MarketStall.Kind.SILK)
	await _settle()
	_expect(not receipt.visible and counter.silk_quote.is_visible_in_tree(), "The silk quote has its own place before a transaction.")
	var silk_icon: Texture2D = items.goods_icon(items.Goods.SILK_BOLT)
	var silk_record := "丝绸 −1 匹 · 铜钱 +%d" % state.balance.silk_sell_price
	receipt.present(silk_record, silk_icon)
	await _settle()
	_check_receipt(counter, silk_record, silk_icon)
	await _capture("05-silk-sale")
	var sheep_tab := counter.get_node("%SheepTrade") as Button
	sheep_tab.pressed.emit()
	await _settle()
	_expect(not receipt.visible and counter.sheep.is_visible_in_tree(), "Moving to the wool offer drops the silk receipt.")
	var wool_icon: Texture2D = items.goods_icon(items.Goods.WOOL)
	var wool_record := "羊毛 −1 份 · 铜钱 +%d" % state.balance.sheep_wool_price
	counter.sheep.receipt.present(wool_record, wool_icon)
	await _settle()
	_check_receipt(counter, wool_record, wool_icon)
	await _capture("06-wool-sale")
	counter.close_counter()
	await _settle()
	_expect(not receipt.visible and receipt.text.is_empty() and field_hud.backpack_button.visible
		and _snapshot(state) == baseline and state.saved_games().is_empty(),
		"The receipt closes with the counter and the staged balances, goods and saves are untouched.")
	print("MARKET_RECEIPT_VIEWS grain=true fish=true silk=true wool=true text_size=", receipt.label.get_theme_font_size(&"font_size"), " saves=", state.saved_games().size())
	return not failed

func _check_receipt(counter: Control, message: String, picture: Texture2D) -> void:
	var receipt: MarketReceipt = counter.trade_receipt
	var bounds := receipt.get_global_rect()
	_expect(receipt.is_visible_in_tree() and bounds.end.y <= counter.scroll.get_global_rect().position.y
		and tree.root.get_visible_rect().encloses(counter.card.get_global_rect())
		and bounds.encloses(receipt.label.get_global_rect()) and receipt.label.get_visible_line_count() == receipt.label.get_line_count(),
		"The receipt is fully legible above the scroll area at the largest reading size.")
	var art: Texture2D = receipt.art.texture
	var matching := art == picture
	if art is AtlasTexture and picture is AtlasTexture:
		matching = art.atlas == picture.atlas and art.region == picture.region
	_expect(receipt.text == message and matching and receipt.label.get_theme_font_size(&"font_size") == 22,
		"The exact amounts and original goods drawing appear in the fixed receipt.")

func _snapshot(state: Node) -> Array:
	return [state.current_day, state.day_progress, state.money, state.food_storage, state.current_stamina,
		hash(state.crop_stock.lots), state.fish_count("perch"), state.silk_workshop.bolts, state.sheepfold.wool]

func _settle() -> void:
	for frame in 7:
		await tree.process_frame

func _capture(name: String) -> void:
	if evidence.is_empty():
		return
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(evidence.path_join(name + ".png")) == OK, "Capture the fixed Western market view.")
	print("MARKET_RECEIPT_FRAME ", name, " pixels=", frame.get_size())

func _expect(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		push_error(message)
	return ok
