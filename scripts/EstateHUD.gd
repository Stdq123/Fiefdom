extends Control

@onready var day_label: Label = %DayLabel
@onready var watch_label: Label = %WatchLabel
@onready var calendar_label: Label = %CalendarLabel
@onready var forecast_label: Label = %ForecastLabel
@onready var calendar_button: Button = %CalendarButton
@onready var gathering_label: Label = %GatheringLabel
@onready var rank_label: Label = %RankLabel
@onready var reputation_label: Label = %ReputationLabel
@onready var money_label: Label = %MoneyLabel
@onready var king_label: Label = %KingLabel
@onready var inventory_label: Label = %InventoryLabel
@onready var well_field_label: Label = %WellFieldLabel
@onready var quest_label: Label = %QuestLabel
@onready var visitor_label: Label = %VisitorLabel
@onready var opening_action: Button = %OpeningAction
@onready var handover_button: Button = %HandoverButton
@onready var arrival: Label = %Arrival
@onready var route_progress: Button = %RouteProgress
@onready var neighbors_button: Button = %NeighborsButton
@onready var raid_alert: Button = %RaidAlert
@onready var stamina_label: Label = %StaminaLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var health_label: Label = %HealthLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var practice_label: Label = %PracticeLabel
@onready var driving_panel: PanelContainer = %DrivingPanel
@onready var driving_status: Label = %DrivingStatus
@onready var driving_hint: Label = %DrivingHint
@onready var leave_cart: Button = %LeaveCart
@onready var help_label: Label = %HelpLabel
@onready var farm_status: Button = %FarmStatus
@onready var pinned_order: Button = %PinnedOrder
@onready var canal_controls: HBoxContainer = %CanalControls
@onready var canal_preview: Label = %CanalPreview
@onready var survey_button: Button = %SurveyButton
@onready var seed_slots: HBoxContainer = %SeedSlots
@onready var manage_button: Button = %ManageButton
@onready var sleep_button: Button = %SleepButton
@onready var rations_button: Button = %RationsButton
@onready var reclaim_button: Button = %ReclaimButton
@onready var map_button: Button = %MapButton
@onready var settings_button: Button = %SettingsButton
@onready var channel_button: Button = %ChannelButton
@onready var guide: Label = %CampaignGuide
@onready var worksite_button: Button = %WorksiteButton
@onready var cancel_directions: Button = %CancelDirections
@onready var save_notice: Label = %SaveNotice

var seed_buttons: Dictionary = {}
var save_notice_tween: Tween
var fields_needing_water := 0
var reclamation_mode := false
var indoors := false
var driving := false
var channel_message := ""

func set_reclamation_mode(active: bool) -> void:
	reclamation_mode = active
	_refresh_sections()

func set_estate_room(room: Global.EstateRoom) -> void:
	indoors = room != Global.EstateRoom.OUTDOORS
	$RoomLocation.text = "蚕棚" if room == Global.EstateRoom.SILK_SHED else "堂屋"
	$WorkshopStatus.visible = room == Global.EstateRoom.SILK_SHED
	practice_label.text = ""
	_refresh_sections()
	_refresh_silk_stock()

func _refresh_sections() -> void:
	var outdoors := not reclamation_mode and not indoors
	$Journal.visible = outdoors
	rations_button.visible = outdoors
	$SeedBelt.visible = outdoors and not driving
	driving_panel.visible = outdoors and driving
	$Tools.visible = not reclamation_mode
	$Actions.visible = not reclamation_mode
	$Vitals.visible = not indoors
	$RoomLocation.visible = indoors
	reclaim_button.visible = not indoors
	channel_button.visible = not indoors
	sleep_button.visible = not indoors

func set_driving(active: bool) -> void:
	driving = active
	practice_label.text = ""
	_refresh_sections()

func show_driving_progress(progress: String, instruction: String) -> void:
	driving_status.text = progress
	driving_hint.text = instruction

func _ready() -> void:
	GameEvents.estate_arrived.connect(_show_arrival)
	GameEvents.driving_practice_progress.connect(show_driving_progress)
	GamepadInput.changed.connect(_refresh_shortcuts)
	Preferences.bindings_changed.connect(_refresh_shortcuts)
	_refresh_shortcuts()
	GameEvents.silk_changed.connect(_refresh_silk_stock)
	GameEvents.daylight_changed.connect(_refresh_watch)
	_refresh_watch()
	GameEvents.health_changed.connect(_update_health)
	GameEvents.season_order_pin_changed.connect(_refresh_pinned_order)
	GameEvents.day_advanced.connect(_refresh_pinned_order.unbind(1))
	GameEvents.inventory_changed.connect(_refresh_pinned_order.unbind(1))
	GameEvents.crop_harvested.connect(_refresh_pinned_order.unbind(1))
	GameEvents.fish_changed.connect(_refresh_pinned_order)
	GameEvents.silk_changed.connect(_refresh_pinned_order)
	GameEvents.campaign_ended.connect(_refresh_pinned_order.unbind(1))
	GameEvents.day_advanced.connect(_refresh_raid_alert.unbind(1))
	GameEvents.raid_started.connect(_refresh_raid_alert)
	GameEvents.raid_defeated.connect(_refresh_raid_alert)
	GameEvents.east_watch_built.connect(_refresh_raid_alert)
	GameEvents.campaign_ended.connect(_refresh_raid_alert.unbind(1))
	_update_health(Global.health)
	_refresh_pinned_order()
	_refresh_raid_alert()

func _show_arrival() -> void:
	arrival.show()
	var fade := create_tween()
	fade.tween_interval(4.8)
	fade.tween_property(arrival, "modulate:a", 0.0, 0.35)
	fade.tween_callback(arrival.hide)

func _refresh_raid_alert() -> void:
	var tomorrow := Global.current_day + 1
	raid_alert.visible = Global.outcome == Global.Outcome.RUNNING and (Global.raid_day > 0 or Global.is_raid_day(tomorrow))
	if not raid_alert.visible:
		return
	if Global.raid_day > 0:
		raid_alert.text = "%s来袭 · 标出位置" % Global.raid_name(Global.raid_kind)
		raid_alert.tooltip_text = "右键朝来敌射箭，侧走避开地面标记。"
	else:
		var threat := "明日有敌袭"
		if Global.east_watch_day > 0:
			threat += " · " + Global.raid_name(Global.raid_kind_on(tomorrow))
		raid_alert.text = threat + " · 查看准备"
		raid_alert.tooltip_text = "打开今夜安排，查看守田准备。"

func _refresh_pinned_order() -> void:
	var schedule := Global.season_order()
	pinned_order.visible = Global.is_season_order_pinned(schedule)
	if not pinned_order.visible:
		return
	var amounts := PackedStringArray()
	var goods := SeasonOrders.cargo(schedule.order)
	for id: String in goods:
		var required: int = goods[id]
		amounts.append("%s %d/%d" % [
			ItemManager.season_item_label(id), mini(Global.season_order_stock(id), required), required])
	var action := "去西市交货" if Global.can_deliver_season_order(schedule) else "第 %d 天截止" % schedule.end
	pinned_order.text = "时令单   %s   ·   %s" % ["、".join(amounts), action]

func _refresh_silk_stock() -> void:
	if not $WorkshopStatus.visible:
		return
	var silk := Global.silk_workshop
	%WorkshopStock.text = "桑叶 %d　　蚕茧 %d　　生丝 %d　　丝绸 %d" % [silk.leaves, silk.cocoons, silk.raw_silk, silk.bolts]
	var summary := "空匾 · 每夜用 %d 片桑叶" % Global.balance.silk_leaves_per_night
	if silk.nights_left > 0:
		summary = "还需 %d 夜 · 每夜用 %d 片桑叶" % [silk.nights_left, Global.balance.silk_leaves_per_night]
		if silk.leaves < Global.balance.silk_leaves_per_night:
			summary += " · 缺桑叶"
	elif silk.repeat_batches:
		summary = "空匾 · 已安排续养"
		var missing := silk.batch_leaf_cost(Global.balance) - silk.leaves
		if missing > 0:
			summary += " · 还差 %d 片桑叶" % missing
	if silk.last_reeled > 0:
		summary += "　　上夜缫 %d 茧 · 生丝 +%d" % [silk.last_reeled, silk.last_reel_thread]
	%WorkshopBatch.text = summary

func _refresh_shortcuts() -> void:
	var pad := GamepadInput.active
	leave_cart.text = "下车  B" if pad else "下车  Esc"
	map_button.text = "舆图  %s" % ("Y" if pad else Preferences.key_label(KeyBindings.MAP))
	calendar_button.text = "历书 %s" % ("View" if pad else Preferences.key_label(KeyBindings.ALMANAC))
	for id in seed_buttons:
		var shortcut := seed_buttons[id].get_node("Shortcut") as Label
		shortcut.text = Preferences.seed_label(id)
		shortcut.visible = not pad
	refresh_seed_calendar()

func _refresh_watch() -> void:
	watch_label.text = Global.day_watch_label()

func show_save_notice(message: String, warning := false) -> void:
	if save_notice_tween:
		save_notice_tween.kill()
	save_notice.text = message
	save_notice.modulate = Color("#eeb98e") if warning else Color("#c5d7a7")
	save_notice.show()
	if not warning:
		save_notice_tween = create_tween()
		save_notice_tween.tween_interval(2.8)
		save_notice_tween.tween_callback(save_notice.hide)

func refresh_rations() -> void:
	var plan := Global.night_rations_plan()
	var tone := Color("#e7ddbd")
	if plan.uncovered > 0:
		rations_button.text = "今夜安排 · 缺粮 %d" % plan.missing
		tone = Color("#efbf8a")
	elif plan.missing > 0:
		rations_button.text = "今夜安排 · 口粮可补足"
		tone = Color("#c7dcaf")
	elif fields_needing_water > 0:
		rations_button.text = "今夜安排 · %d 格缺水" % fields_needing_water
		tone = Color("#efbf8a")
	elif plan.need > 0:
		rations_button.text = "今夜安排 · 口粮已备"
	else:
		rations_button.text = "今夜安排"
	rations_button.add_theme_color_override("font_color", tone)
	rations_button.tooltip_text = "查看田务和用粮\n粮仓 %d 份 · 今夜所需 %d 份" % [Global.food_storage, plan.need]

func setup_seeds(ids: Array, select_seed: Callable) -> void:
	var group := ButtonGroup.new()
	var rest := _slot_style(Color("#2c392b"), Color("#697651"))
	var hover := _slot_style(Color("#3b492f"), Color("#b6ba80"))
	var selected := _slot_style(Color("#594931"), Color("#e2bf73"))
	for i in ids.size():
		var id: String = ids[i]
		var crop := ItemManager.get_crop(id)
		var slot := Button.new()
		slot.name = "Seed%d" % (i + 1)
		slot.custom_minimum_size = Vector2(56, 47)
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.focus_mode = Control.FOCUS_NONE # Each seed has its own shortcut.
		slot.toggle_mode = true
		slot.button_group = group
		slot.add_theme_stylebox_override("normal", rest)
		slot.add_theme_stylebox_override("hover", hover)
		slot.add_theme_stylebox_override("pressed", selected)
		slot.add_theme_stylebox_override("hover_pressed", selected)
		seed_slots.add_child(slot)
		slot.pressed.connect(select_seed.bind(id))
		seed_buttons[id] = slot

		var icon := TextureRect.new()
		var picture := ItemManager.crop_picture(crop)
		icon.texture = picture.texture
		icon.self_modulate = picture.tint
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(4, 16)
		icon.size = Vector2(24, 24)
		slot.add_child(icon)

		var shortcut := _slot_label(slot, "", Vector2(6, 2), 11, Color("#d9c79d"))
		shortcut.name = "Shortcut"
		shortcut.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		shortcut.size.x = 31.0
		_slot_label(slot, crop.crop_name, Vector2(30, 16), 17, Color("#f6e6bc"))
		var mark := _slot_label(slot, "令", Vector2(41, 2), 10, Color("#edd18a"))
		mark.name = "SeasonMark"
	_refresh_shortcuts()

func _slot_label(slot: Button, text: String, at: Vector2, font_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	slot.add_child(label)
	return label

func _slot_style(background: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = edge
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(4)
	return style

func show_seed(seed_id: String) -> void:
	var crop := ItemManager.get_crop(seed_id)
	if not crop:
		return
	seed_slots.show()
	farm_status.show()
	canal_controls.hide()
	for id in seed_buttons:
		seed_buttons[id].set_pressed_no_signal(id == seed_id)
	var nights := Global.sowing_nights(crop)
	var seasonal := "当令 " if nights < crop.days_to_grow else ""
	var water := " · 需通水" if crop.is_water_crop else ""
	var sweep := "按住 A，右摇杆拖过田格" if GamepadInput.active else "按住左键拖过田格"
	help_label.text = "%s · %s%d 夜成熟%s   |   %s" % [crop.crop_name, seasonal, nights, water, sweep]

func refresh_seed_calendar() -> void:
	var tomorrow := Global.current_day + 1
	forecast_label.text = "明日 %s · %s" % [
		Global.get_current_solar_term(tomorrow), "雨润旱田" if Global.has_rain(tomorrow) else "晴"]
	for id in seed_buttons:
		var crop := ItemManager.get_crop(id)
		var slot: Button = seed_buttons[id]
		var nights := Global.sowing_nights(crop)
		slot.get_node("SeasonMark").visible = nights < crop.days_to_grow
		slot.tooltip_text = "%s · %d 次供水过夜成熟" % [crop.crop_name, nights]
		if not GamepadInput.active:
			slot.tooltip_text += " · %s 换种" % Preferences.seed_label(id)
		if crop.favored_season >= 0:
			var saving := crop.days_to_grow - crop.sowing_nights(crop.favored_season, Global.balance.seasonal_growth_reduction)
			if saving > 0:
				slot.tooltip_text += " · %s播少等 %d 夜" % [Global.SEASON_NAMES[crop.favored_season], saving]
		if crop.is_water_crop:
			slot.tooltip_text += "\n相邻水渠通水后才能种稻。断水时停长。"
		elif crop.is_perennial:
			slot.tooltip_text += "\n收叶后保留桑树。当令加成用于初栽。"
		elif crop.restores_fertility:
			slot.tooltip_text += "\n收菽留肥。下一茬非菽作物多收一份。"

func refresh_farm_status() -> void:
	var report := Global.field_night_forecast()
	farm_status.text = "田务  ›  待浇 %d · 可收 %d · 今夜成熟 %d" % [
		report.dry, report.ready, report.public_ripe + report.private_ripe]
	if report.blocked > 0:
		farm_status.text += " · 断水 %d" % report.blocked
	var needs_water: int = report.dry + report.blocked
	if needs_water != fields_needing_water:
		fields_needing_water = needs_water
		sleep_button.tooltip_text = "结束今天，恢复体力"
		if needs_water > 0:
			sleep_button.tooltip_text += "\n%d 格作物缺水会停长。查看「今夜安排」。" % needs_water
		refresh_rations()

func show_channel_help(message: String) -> void:
	seed_slots.hide()
	farm_status.hide()
	canal_controls.show()
	channel_message = message
	refresh_channel_help()

func refresh_channel_help() -> void:
	var pad := GamepadInput.active
	var keys: String
	if survey_button.text == "取消放样":
		keys = ("A 定起点或确认 · Menu 换弯 · B 取消" if pad
			else "左键定起点或确认 · %s 换弯 · Esc 取消" % Preferences.key_label(KeyBindings.ROTATE))
	else:
		keys = ("A 挖渠（%d 铜钱/格） · LT+A 填渠 · B 退出" % Global.channel_cost() if pad
			else "左键挖渠（%d 铜钱/格） · %s+左键填渠 · Esc 退出" % [Global.channel_cost(), Preferences.key_label(KeyBindings.FILL)])
	help_label.text = "%s\n%s" % [channel_message, keys]

func refresh_survey_button() -> void:
	survey_button.disabled = Global.channel_survey_day == 0
	survey_button.tooltip_text = ("定渠线起点，查看价格再确认施工" if not survey_button.disabled else
		"让渠水养苗过一夜，再找石墨学习放样。")

func show_survey_mode(active: bool) -> void:
	survey_button.text = "取消放样" if active else "放样"
	show_channel_help("放样 · 先定渠线起点" if active else "把水渠接到水源")

func _update_health(health: int) -> void:
	health_label.text = "气血 %d / %d" % [health, Global.balance.player_max_health]
	health_label.modulate = Color("#f19279") if health * 3 < Global.balance.player_max_health else Color.WHITE
	health_bar.max_value = Global.balance.player_max_health
	health_bar.value = health
