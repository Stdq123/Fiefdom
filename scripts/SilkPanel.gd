extends VBoxContainer

var stock_label: Label
var status_label: Label
var buttons: Array[Button] = []
var stages: VBoxContainer
var repeat_button: CheckButton
var bulk_buttons: Dictionary[SilkWorkshop.Action, Button] = {}
var night_reeling_button: CheckButton
var night_status: Label
var sample_status: Label
var visit_button: Button

func _ready() -> void:
	stock_label = Label.new()
	stock_label.add_theme_font_size_override("font_size", 18)
	add_child(stock_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)

	buttons.resize(SilkWorkshop.Action.size())
	_add_action(self, SilkWorkshop.Action.BUILD)
	stages = VBoxContainer.new()
	stages.add_theme_constant_override("separation", 8)
	add_child(stages)
	_add_action(stages, SilkWorkshop.Action.START_BATCH)
	_add_processing_row(SilkWorkshop.Action.REEL)
	_add_processing_row(SilkWorkshop.Action.WEAVE)
	var trade := HBoxContainer.new()
	stages.add_child(trade)
	_add_action(trade, SilkWorkshop.Action.SELL)
	_add_action(trade, SilkWorkshop.Action.OFFER)
	var schedule := HBoxContainer.new()
	stages.add_child(schedule)
	repeat_button = CheckButton.new()
	repeat_button.name = "RepeatBatches"
	repeat_button.text = "桑叶足够时续养"
	repeat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repeat_button.toggled.connect(Global.set_repeat_silk_batches)
	schedule.add_child(repeat_button)
	night_reeling_button = CheckButton.new()
	night_reeling_button.name = "NightReeling"
	night_reeling_button.text = "委派门客夜间缫丝"
	night_reeling_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	night_reeling_button.toggled.connect(Global.set_night_reeling)
	schedule.add_child(night_reeling_button)
	night_status = Label.new()
	night_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stages.add_child(night_status)
	sample_status = Label.new()
	sample_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sample_status.add_theme_color_override("font_color", Color("#e4c68d"))
	add_child(sample_status)
	visit_button = Button.new()
	visit_button.text = "指路去蚕棚"
	visit_button.pressed.connect(GameEvents.silk_shed_directions_requested.emit)
	add_child(visit_button)

	visibility_changed.connect(_refresh)
	GameEvents.silk_changed.connect(_refresh)
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

func _add_action(host: Control, action: SilkWorkshop.Action) -> void:
	var button := Button.new()
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_act.bind(action))
	buttons[action] = button
	host.add_child(button)

func _add_processing_row(action: SilkWorkshop.Action) -> void:
	var row := HBoxContainer.new()
	stages.add_child(row)
	_add_action(row, action)
	var button := Button.new()
	button.custom_minimum_size = Vector2(132, 36)
	button.pressed.connect(_process_all.bind(action))
	row.add_child(button)
	bulk_buttons[action] = button

func _process_all(action: SilkWorkshop.Action) -> void:
	_act(action, Global.silk_workshop.capacity(action, Global.balance))

func _act(action: SilkWorkshop.Action, amount := 1) -> void:
	if not Global.use_workshop(action, amount):
		_refresh()

func _refresh() -> void:
	var workshop := Global.silk_workshop
	var balance := Global.balance
	var literacy := Global.player_stats.get_level(PlayerStats.Art.LITERACY)
	stock_label.text = "桑叶 %d · 蚕茧 %d · 生丝 %d · 丝绸 %d" % [
		workshop.leaves, workshop.cocoons, workshop.raw_silk, workshop.bolts]
	var estate := get_tree().current_scene
	var shed := estate.get_node_or_null("World/SilkShed") as Node2D if estate else null
	visit_button.visible = shed != null and shed.visible and Global.estate_room != Global.EstateRoom.SILK_SHED
	if not workshop.built:
		status_label.text = "在私田种桑取叶。书 %d/%d 级，建蚕室需 %d 铜钱。" % [
			literacy, SilkWorkshop.LITERACY_LEVEL, balance.silk_workshop_cost]
	elif workshop.nights_left > 0:
		status_label.text = "蚕批剩余 %d 夜 · 每晚喂 %d 桑叶" % [workshop.nights_left, balance.silk_leaves_per_night]
		if workshop.leaves < balance.silk_leaves_per_night:
			status_label.text += " · 缺桑叶，喂养暂停"
	else:
		status_label.text = "空匾 · 一批养 %d 夜，共用 %d 片桑叶，得 %d 只茧。" % [
			balance.silk_batch_nights, workshop.batch_leaf_cost(balance), balance.silk_cocoons_per_batch]

	buttons[SilkWorkshop.Action.BUILD].visible = not workshop.built
	stages.visible = workshop.built
	buttons[SilkWorkshop.Action.BUILD].text = "建蚕室 · %d 铜钱" % balance.silk_workshop_cost
	buttons[SilkWorkshop.Action.START_BATCH].text = "开养一批 · %d 夜" % balance.silk_batch_nights
	buttons[SilkWorkshop.Action.REEL].text = "缫丝 · 1 蚕茧 → %d 生丝" % Global.silk_thread_yield()
	buttons[SilkWorkshop.Action.WEAVE].text = "织绸 · %d 生丝 → 1 丝绸" % balance.silk_thread_per_bolt
	buttons[SilkWorkshop.Action.SELL].text = "出售 1 匹 · +%d 铜钱" % balance.silk_sell_price
	buttons[SilkWorkshop.Action.OFFER].text = "进献 1 匹 · +%d 声望" % balance.silk_offer_reputation
	for action in SilkWorkshop.Action.values():
		buttons[action].disabled = not Global.can_use_workshop(action)
	if workshop.built:
		for action in bulk_buttons:
			var count := workshop.capacity(action, balance)
			var button := bulk_buttons[action]
			button.visible = count > 1
			button.text = ("缫完 %d 茧" if action == SilkWorkshop.Action.REEL else "织完 %d 匹") % count
		_refresh_night_work(workshop)
	_refresh_sample(workshop)

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
