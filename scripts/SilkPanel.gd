extends VBoxContainer

signal study_requested()

const MATERIAL_ART := preload("res://assets/inventory/estate-goods.png")
const STATION_ART := preload("res://assets/world/silk-interior.png")
const MATERIAL_NAMES := ["桑叶", "蚕茧", "生丝", "丝绸"]
const MATERIAL_UNITS := ["片", "只", "份", "匹"]
const GOLD := Color("#f1d39a")
const INK := Color("#d7e0cb")

var card_style := StyleBoxFlat.new()
var stock_counts: Array[Label] = []
var production: ScrollContainer
var status_label: Label
var build_status: Label
var stage_notes: Dictionary[SilkWorkshop.Action, Label] = {}
var buttons: Array[Button] = []
var stages: VBoxContainer
var trade: HBoxContainer
var repeat_button: CheckButton
var bulk_buttons: Dictionary[SilkWorkshop.Action, Button] = {}
var night: VBoxContainer
var night_reeling_button: CheckButton
var night_status: Label
var sample_status: Label
var visit_button: Button
var build_row: HBoxContainer
var study_button: Button
var mulberry_row: HBoxContainer
var mulberry_note: Label
var mulberry_button: Button
var mulberry_route := -1

func _ready() -> void:
	card_style.bg_color = Color("#26382e")
	card_style.border_color = Color("#4d6048")
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(5)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		card_style.set_content_margin(side, 8.0)
	_add_stock()

	production = ScrollContainer.new()
	production.name = "Production"
	production.size_flags_vertical = Control.SIZE_EXPAND_FILL
	production.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	production.follow_focus = true
	add_child(production)
	var scroll_bar := production.get_v_scroll_bar()
	scroll_bar.theme = preload("res://resources/estate_hud_theme.tres")
	scroll_bar.theme_type_variation = &"HudJournalBar"
	scroll_bar.focus_mode = Control.FOCUS_ALL
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	production.add_child(content)

	buttons.resize(SilkWorkshop.Action.size())
	var build := VBoxContainer.new()
	content.add_child(build)
	build_status = _label(build, "", 16, INK)
	build_row = HBoxContainer.new()
	build.add_child(build_row)
	_add_action(build_row, SilkWorkshop.Action.BUILD)
	study_button = Button.new()
	study_button.custom_minimum_size = Vector2(116, 36)
	study_button.text = "去研读"
	study_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	study_button.pressed.connect(study_requested.emit)
	build_row.add_child(study_button)
	InterfaceFont.scale_reading_text(study_button)

	stages = VBoxContainer.new()
	stages.add_theme_constant_override("separation", 8)
	content.add_child(stages)
	_add_stage(SilkWorkshop.Action.START_BATCH, "养蚕", Rect2(0, 144, 56, 40))
	_add_stage(SilkWorkshop.Action.REEL, "缫丝", Rect2(56, 144, 58, 45))
	_add_stage(SilkWorkshop.Action.WEAVE, "织绸", Rect2(114, 144, 64, 48))
	status_label = stage_notes[SilkWorkshop.Action.START_BATCH]

	mulberry_row = HBoxContainer.new()
	mulberry_row.add_theme_constant_override("separation", 10)
	mulberry_row.hide()
	content.add_child(mulberry_row)
	mulberry_note = _label(mulberry_row, "", 15, GOLD)
	mulberry_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mulberry_button = Button.new()
	mulberry_button.custom_minimum_size = Vector2(116, 36)
	mulberry_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mulberry_button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	mulberry_button.pressed.connect(func(): GameEvents.mulberry_directions_requested.emit(mulberry_route))
	mulberry_row.add_child(mulberry_button)
	InterfaceFont.scale_reading_text(mulberry_button)

	night = VBoxContainer.new()
	content.add_child(night)
	_label(night, "夜间安排", 16, GOLD)
	var schedule := HBoxContainer.new()
	night.add_child(schedule)
	repeat_button = CheckButton.new()
	repeat_button.name = "RepeatBatches"
	repeat_button.text = "桑叶足够时续养"
	repeat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repeat_button.toggled.connect(Global.set_repeat_silk_batches)
	schedule.add_child(repeat_button)
	InterfaceFont.scale_reading_text(repeat_button)
	night_reeling_button = CheckButton.new()
	night_reeling_button.name = "NightReeling"
	night_reeling_button.text = "委派门客夜间缫丝"
	night_reeling_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	night_reeling_button.toggled.connect(Global.set_night_reeling)
	schedule.add_child(night_reeling_button)
	InterfaceFont.scale_reading_text(night_reeling_button)
	night_status = _label(night, "", 15, INK)
	sample_status = _label(content, "", 15, GOLD)

	trade = HBoxContainer.new()
	add_child(trade)
	_add_action(trade, SilkWorkshop.Action.SELL)
	_add_action(trade, SilkWorkshop.Action.OFFER)
	visit_button = Button.new()
	visit_button.text = "指路去蚕棚"
	visit_button.pressed.connect(GameEvents.silk_shed_directions_requested.emit)
	add_child(visit_button)
	InterfaceFont.scale_reading_text(visit_button)

	visibility_changed.connect(_refresh)
	GameEvents.silk_changed.connect(_refresh)
	GameEvents.farm_state_changed.connect(_refresh_mulberry)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.estate_room_changed.connect(_refresh.unbind(1))
	GameEvents.well_field_added.connect(_refresh.unbind(1))
	GameEvents.channels_changed.connect(_refresh)
	GameEvents.money_changed.connect(_refresh.unbind(1))
	GameEvents.food_changed.connect(_refresh.unbind(1))
	GameEvents.inventory_changed.connect(_refresh.unbind(1))
	GameEvents.night_rations_changed.connect(_refresh)
	GameEvents.retainer_duty_changed.connect(_refresh.unbind(1))
	GameEvents.retainer_recruited.connect(_refresh.unbind(1))
	GameEvents.retainer_departed.connect(_refresh.unbind(1))
	Global.player_stats.level_up.connect(_refresh.unbind(2))
	_refresh()

func _label(host: Control, copy: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = copy
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	host.add_child(label)
	InterfaceFont.scale_reading_text(label)
	return label

func _card(host: Control) -> HBoxContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", card_style)
	host.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	return row

func _picture(row: HBoxContainer, texture: Texture2D, region: Rect2, size: Vector2) -> void:
	var cell := AtlasTexture.new()
	cell.atlas = texture
	cell.region = region
	cell.filter_clip = true
	var picture := TextureRect.new()
	picture.texture = cell
	picture.custom_minimum_size = size
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(picture)

func _add_stock() -> void:
	var stock := HBoxContainer.new()
	stock.name = "Stock"
	add_child(stock)
	for index in MATERIAL_NAMES.size():
		var cell := _card(stock)
		_picture(cell, MATERIAL_ART, Rect2(32 * (index + 1), 0, 32, 32), Vector2(32, 32))
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(text)
		_label(text, MATERIAL_NAMES[index], 14, INK)
		stock_counts.append(_label(text, "", 17, GOLD))

func _add_stage(action: SilkWorkshop.Action, title: String, region: Rect2) -> void:
	var row := _card(stages)
	_picture(row, STATION_ART, region, Vector2(48, 40))
	var explanation := VBoxContainer.new()
	explanation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(explanation)
	_label(explanation, title, 16, GOLD)
	stage_notes[action] = _label(explanation, "", 15, INK)
	var actions := HBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(actions)
	_add_action(actions, action)
	if action in [SilkWorkshop.Action.REEL, SilkWorkshop.Action.WEAVE]:
		var bulk := Button.new()
		bulk.custom_minimum_size.y = 36
		bulk.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		bulk.pressed.connect(_process_all.bind(action))
		actions.add_child(bulk)
		InterfaceFont.scale_reading_text(bulk)
		bulk_buttons[action] = bulk

func _add_action(host: Control, action: SilkWorkshop.Action) -> void:
	var button := Button.new()
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.pressed.connect(_act.bind(action))
	buttons[action] = button
	host.add_child(button)
	InterfaceFont.scale_reading_text(button)

func _process_all(action: SilkWorkshop.Action) -> void:
	_act(action, Global.silk_workshop.capacity(action, Global.balance))

func _act(action: SilkWorkshop.Action, amount := 1) -> void:
	if not Global.use_workshop(action, amount):
		_refresh()
	elif action == SilkWorkshop.Action.SELL:
		AudioManager.play_trade_cue(AudioManager.TradeCue.SALE)
	else:
		AudioManager.play_workshop_cue(action)

func _refresh() -> void:
	var workshop := Global.silk_workshop
	var balance := Global.balance
	var literacy := Global.player_stats.get_level(PlayerStats.Art.LITERACY)
	var amounts := [workshop.leaves, workshop.cocoons, workshop.raw_silk, workshop.bolts]
	for index in stock_counts.size():
		stock_counts[index].text = "%d %s" % [amounts[index], MATERIAL_UNITS[index]]
	var estate := get_tree().current_scene
	var shed := estate.get_node_or_null("World/SilkShed") as Node2D if estate else null
	visit_button.visible = shed != null and shed.visible and Global.estate_room != Global.EstateRoom.SILK_SHED
	build_status.visible = not workshop.built
	build_status.text = "建蚕室 · 书 %d/%d 级 · 铜钱 %d/%d" % [
		literacy, SilkWorkshop.LITERACY_LEVEL, Global.money, balance.silk_workshop_cost]
	build_row.visible = not workshop.built
	study_button.visible = literacy < SilkWorkshop.LITERACY_LEVEL
	stages.visible = workshop.built
	night.visible = workshop.built
	trade.visible = workshop.built
	buttons[SilkWorkshop.Action.BUILD].text = "建蚕室 · %d 铜钱" % balance.silk_workshop_cost
	buttons[SilkWorkshop.Action.START_BATCH].text = "开养一批 · %d 夜" % balance.silk_batch_nights
	buttons[SilkWorkshop.Action.REEL].text = "缫 1 只"
	buttons[SilkWorkshop.Action.WEAVE].text = "织 1 匹"
	buttons[SilkWorkshop.Action.SELL].text = "出售 1 匹 · +%d 铜钱" % balance.silk_sell_price
	buttons[SilkWorkshop.Action.OFFER].text = "进献 1 匹 · +%d 声望" % balance.silk_offer_reputation
	for action in SilkWorkshop.Action.values():
		buttons[action].disabled = not Global.can_use_workshop(action)
	if workshop.built:
		_refresh_stages(workshop, balance)
		for action in bulk_buttons:
			var count := workshop.capacity(action, balance)
			var button := bulk_buttons[action]
			button.visible = count > 1
			button.text = ("缫完 %d 茧" if action == SilkWorkshop.Action.REEL else "织完 %d 匹") % count
		_refresh_night_work(workshop)
	_refresh_sample(workshop)
	_refresh_mulberry()

func _refresh_stages(workshop: SilkWorkshop, balance: BalanceData) -> void:
	var feeding := SilkWorkshop.Action.START_BATCH
	var reeling := SilkWorkshop.Action.REEL
	var weaving := SilkWorkshop.Action.WEAVE
	if workshop.nights_left > 0:
		status_label.text = "余 %d 夜 · 每夜喂 %d 片桑叶" % [workshop.nights_left, balance.silk_leaves_per_night]
	else:
		status_label.text = "空匾 · 首夜用 %d 片，%d 夜共用 %d 片桑叶，结 %d 只茧。" % [
			balance.silk_leaves_per_night, balance.silk_batch_nights,
			workshop.batch_leaf_cost(balance), balance.silk_cocoons_per_batch]
	stage_notes[reeling].text = "1 只蚕茧 → %d 份生丝" % Global.silk_thread_yield()
	stage_notes[weaving].text = "%d 份生丝 → 1 匹丝绸" % balance.silk_thread_per_bolt
	for action in [feeding, reeling, weaving]:
		var shortage := workshop.material_shortage(action, balance)
		if not shortage.is_empty():
			if action == feeding:
				shortage = ("今夜" if workshop.nights_left > 0 else "开养") + shortage
			stage_notes[action].text += "\n" + shortage
		buttons[action].tooltip_text = shortage

func _refresh_mulberry() -> void:
	if not is_visible_in_tree():
		return
	var estate := get_tree().current_scene
	var world := estate.get_node_or_null("World") if estate else null
	var workshop := Global.silk_workshop
	var balance := Global.balance
	var leaf_nights := workshop.nights_left if workshop.nights_left > 0 else balance.silk_batch_nights
	var missing := leaf_nights * balance.silk_leaves_per_night - workshop.leaves
	mulberry_row.visible = world != null and missing > 0 and workshop.cocoons == 0 and workshop.capacity(SilkWorkshop.Action.WEAVE, balance) == 0
	if not mulberry_row.visible:
		return
	var note := ""
	mulberry_route = -1
	mulberry_button.show()
	if world.find_field_task(Global.MulberryRoute.HARVEST) != null:
		mulberry_route = Global.MulberryRoute.HARVEST
		mulberry_button.text = "指路收桑"
		note = "私田的桑叶可采"
	elif world.find_field_task(Global.MulberryRoute.WATER) != null:
		mulberry_route = Global.MulberryRoute.WATER
		mulberry_button.text = "指路浇桑"
		note = "私田的桑苗待浇水"
	else:
		var nights: int = world.mulberry_growth_remaining()
		if nights > 0:
			mulberry_button.hide()
			note = "桑苗已得水 · 最快再供水 %d 夜" % nights
		elif world.find_field_task(Global.MulberryRoute.PLANT) != null:
			mulberry_route = Global.MulberryRoute.PLANT
			mulberry_button.text = "标出私田"
			note = "种桑后采叶"
		else:
			mulberry_button.text = "查看井田"
			note = "腾出一格私田再播桑"
	var batch := "养完本批" if workshop.nights_left > 0 else "备齐整批"
	mulberry_note.text = "%s还缺 %d 片桑叶 · %s" % [batch, missing, note]

func _refresh_night_work(workshop: SilkWorkshop) -> void:
	repeat_button.set_pressed_no_signal(workshop.repeat_batches)
	night_reeling_button.set_pressed_no_signal(workshop.night_reeling)
	var details := PackedStringArray()
	if workshop.night_reeling and Global.silk_reelers() == 0:
		details.append("在门客列表安排墨家缫丝后可委派夜间工作。")
	var forecast := Global.silk_night_summary(Global.night_rations_plan().fed)
	if not forecast.is_empty():
		details.append("今夜 · " + forecast)
	var receipt := workshop.last_work_summary()
	if not receipt.is_empty():
		details.append("昨夜 · " + receipt)
	night_status.visible = not details.is_empty()
	night_status.text = "\n".join(details)

func _refresh_sample(workshop: SilkWorkshop) -> void:
	var requested := Global.silk_sample_requested()
	sample_status.visible = requested or Global.silk_sample_day > 0
	if requested:
		var progress := "已备好" if workshop.bolts > 0 else "待织"
		sample_status.text = "陶辛的样绸 · %s · 一匹换 %d 铜钱。见到陶辛时可交付。" % [
			progress, Global.silk_sample_price()]
	elif Global.silk_sample_day > 0:
		sample_status.text = "陶辛已带绸去南路。西廊挂着这匹绸的样布。"
