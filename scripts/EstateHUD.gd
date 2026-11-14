extends Control

const SEED_BUTTON := preload("res://scripts/SeedButton.gd")

@onready var day_label: Label = %DayLabel
@onready var watch_label: Label = %WatchLabel
@onready var watch_dial: Control = %WatchDial
@onready var calendar_label: Label = %CalendarLabel
@onready var forecast_label: Label = %ForecastLabel
@onready var calendar_button: Button = %CalendarButton
@onready var weather_icon: TextureRect = %WeatherIcon
@onready var ledger_toggle: Button = %LedgerToggle
@onready var ledger_details: VBoxContainer = %LedgerDetails
@onready var journal_details: Button = %JournalDetails
@onready var season_event_button: Button = %SeasonEventButton
@onready var rank_label: Label = %RankLabel
@onready var reputation_label: Label = %ReputationLabel
@onready var money_label: Label = %MoneyLabel
@onready var king_label: Label = %KingLabel
@onready var inventory_label: Label = %InventoryLabel
@onready var well_field_label: Label = %WellFieldLabel
@onready var tribute_button: Button = %TributeButton
@onready var visitor_label: Label = %VisitorLabel
@onready var opening_action: Button = %OpeningAction
@onready var rotation_guide_button: Button = %RotationGuideButton
@onready var first_private_button: Button = %FirstPrivateButton
@onready var handover_button: Button = %HandoverButton
@onready var arrival: Label = %Arrival
@onready var route_progress: Button = %RouteProgress
@onready var council_prep_button: Button = %CouncilPrepButton
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
@onready var field_gate_button: Button = %FieldGateButton
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
@onready var morning_button: Button = %MorningButton
@onready var map_overlays: Array[Control] = [$Journal, $Calendar, $SeedBelt, $Vitals, $Tools, $Actions, $RationsButton, $SaveNotice]

var seed_buttons: Dictionary = {}
var save_notice_tween: Tween
var fields_needing_water := 0
var reclamation_mode := false
var indoors := false
var driving := false
var channel_message := ""
var sky_icons := HUDIcons.SKY.map(HUDIcons.icon)

func map_space_clear(area: Rect2) -> bool:
	if not get_viewport_rect().grow(-8.0).encloses(area):
		return false
	for overlay in map_overlays:
		if overlay.is_visible_in_tree() and overlay.get_global_rect().grow(4.0).intersects(area):
			return false
	return true

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
	for card: PanelContainer in [$Journal, $Calendar]:
		card.minimum_size_changed.connect(_fit_top_card.bind(card), CONNECT_DEFERRED)
		_fit_top_card.call_deferred(card)
	journal_details.toggled.connect(_toggle_journal_details)
	ledger_toggle.pressed.connect(_toggle_ledger_details)
	%CoinIcon.texture = HUDIcons.icon(HUDIcons.Symbol.COIN)
	%HealthIcon.texture = HUDIcons.icon(HUDIcons.Symbol.HEALTH)
	%StaminaIcon.texture = HUDIcons.icon(HUDIcons.Symbol.STAMINA)
	calendar_button.icon = HUDIcons.icon(HUDIcons.Symbol.CALENDAR)
	map_button.icon = HUDIcons.icon(HUDIcons.Symbol.MAP)
	settings_button.icon = HUDIcons.icon(HUDIcons.Symbol.SETTINGS)
	sleep_button.icon = HUDIcons.icon(HUDIcons.Symbol.MOON)
	GameEvents.estate_arrived.connect(_show_arrival)
	GameEvents.day_advanced.connect(arrival.hide.unbind(1))
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
	GameEvents.tax_reform_choice_made.connect(_refresh_pinned_order.unbind(1))
	GameEvents.campaign_ended.connect(_refresh_pinned_order.unbind(1))
	GameEvents.day_advanced.connect(_refresh_raid_alert.unbind(1))
	GameEvents.raid_started.connect(_refresh_raid_alert)
	GameEvents.raid_defeated.connect(_refresh_raid_alert)
	GameEvents.east_watch_built.connect(_refresh_raid_alert)
	GameEvents.campaign_ended.connect(_refresh_raid_alert.unbind(1))
	_update_health(Global.health)
	_refresh_pinned_order()
	_refresh_raid_alert()
	refresh_morning_record()

func _toggle_journal_details(expanded: bool) -> void:
	visitor_label.visible = expanded
	journal_details.text = "收起来客" if expanded else "封地手记"

func _toggle_ledger_details() -> void:
	ledger_details.visible = not ledger_details.visible
	ledger_toggle.text = "收起" if ledger_details.visible else "账目"

func _fit_top_card(card: PanelContainer) -> void:
	card.size.y = card.get_combined_minimum_size().y

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
	var schedule := Global.pinned_season_order()
	pinned_order.visible = not schedule.is_empty()
	if not pinned_order.visible:
		return
	var amounts := ItemManager.describe_season_order_progress(schedule)
	var harvest := Global.has_season_order_harvest(schedule)
	if schedule.start > Global.current_day:
		var next_action := "第 %d 天开收" % schedule.start
		if harvest:
			next_action = "收备货私田 · " + next_action
		pinned_order.text = "下季备货   %s   ·   %s" % [amounts, next_action]
		pinned_order.tooltip_text = pinned_order.text
		return
	var action := "第 %d 天截止" % schedule.end
	if Global.can_deliver_season_order(schedule):
		action = "去西市交货"
	elif harvest:
		action = "收备货私田"
	pinned_order.text = "时令单   %s   ·   %s" % [amounts, action]
	pinned_order.tooltip_text = pinned_order.text

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
	watch_dial.show_watch(watch_label.text)
	weather_icon.texture = sky_icons[HUDIcons.sky_index()]

func refresh_morning_record() -> void:
	morning_button.visible = Global.has_morning_record()
	var fields := Global.last_field_night
	var ripe: int = fields.get("public_ripe", 0) + fields.get("private_ripe", 0)
	var meals := Global.night_rations.last
	var missing: int = meals.get("need", 0) - meals.get("served", 0)
	var rank_change: int = Global.last_dawn.get("rank_change", 0)
	morning_button.text = "昨夜结算"
	if missing > 0:
		morning_button.text += " · 缺粮 %d 份" % missing
	elif rank_change != 0:
		var change := "晋升" if rank_change > 0 else "削爵至"
		morning_button.text += " · " + change + Global.rank_names[Global.current_rank]
	elif not Global.last_dawn.get("completed_fields", []).is_empty():
		morning_button.text += " · 井田完工"
	elif ripe > 0:
		morning_button.text += " · 新熟 %d 格" % ripe

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
		rations_button.text = "今夜安排 · 缺粮 %d" % plan.uncovered
		tone = Color("#efbf8a")
	elif Global.tribute_penalty_tonight() > 0:
		rations_button.text = "今夜安排 · 纳贡到期"
		tone = Color("#efbf8a")
	elif plan.missing > 0:
		rations_button.text = "今夜安排 · 口粮可补足"
		tone = Color("#c7dcaf")
	elif fields_needing_water > 0:
		rations_button.text = "今夜安排 · %d 格缺水" % fields_needing_water
		tone = Color("#efbf8a")
	else:
		rations_button.text = "今夜安排"
	rations_button.add_theme_color_override("font_color", tone)
	rations_button.tooltip_text = "查看田务和用粮\n粮仓 %d 份 · 今夜所需 %d 份" % [Global.food_storage, plan.need]

func refresh_tribute() -> void:
	var due := Global.tribute_deadline()
	tribute_button.visible = (Global.outcome == Global.Outcome.RUNNING and due > 0
		and (Global.first_tribute_delivered() or due <= Global.current_day + 1))
	if tribute_button.visible:
		var tonight := due == Global.current_day
		tribute_button.text = "纳贡 · 今夜前" if tonight else "纳贡 · 第 %d 天过夜前" % due
		if Global.tribute_overdue():
			tribute_button.text = "欠贡 · 查看公田"
		tribute_button.tooltip_text = "收割任一公田，作物入国库，期限重新计算。"
		tribute_button.add_theme_color_override("font_color", Color("#efbf8a") if tonight else Color("#e7ddbd"))
	_refresh_sleep_tooltip()

func _refresh_sleep_tooltip() -> void:
	sleep_button.tooltip_text = "结束今天，恢复体力"
	if fields_needing_water > 0:
		sleep_button.tooltip_text += "\n%d 格作物缺水会停长。查看「今夜安排」。" % fields_needing_water
	var penalty := Global.tribute_penalty_tonight()
	if penalty > 0:
		sleep_button.tooltip_text += "\n若今夜仍无纳贡，声望 −%d。" % penalty

func setup_seeds(ids: Array, select_seed: Callable) -> void:
	var group := ButtonGroup.new()
	for i in ids.size():
		var id: String = ids[i]
		var crop := ItemManager.get_crop(id)
		var picture := ItemManager.crop_picture(crop)
		var slot := SEED_BUTTON.new()
		slot.setup(id, crop.crop_name, picture)
		slot.name = "Seed%d" % (i + 1)
		slot.custom_minimum_size = Vector2(51, 44)
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.focus_mode = Control.FOCUS_NONE # Each seed has its own shortcut.
		slot.toggle_mode = true
		slot.button_group = group
		slot.theme_type_variation = &"HudSeedPocket"
		seed_slots.add_child(slot)
		slot.pressed.connect(select_seed.bind(id))
		seed_buttons[id] = slot

		var icon := TextureRect.new()
		icon.texture = picture.texture
		icon.self_modulate = picture.tint
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(3, 14)
		icon.size = Vector2(23, 24)
		slot.add_child(icon)

		var shortcut := _slot_label(slot, "", Vector2(6, 2), 11, Color("#d9c79d"))
		shortcut.name = "Shortcut"
		shortcut.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		shortcut.size.x = 31.0
		_slot_label(slot, SEED_BUTTON.display_name(id, crop.crop_name), Vector2(27, 14), 17, Color("#f6e6bc"))
		var mark := _slot_label(slot, "令", Vector2(37, 2), 10, Color("#edd18a"))
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
	var name_in_belt := SEED_BUTTON.display_name(seed_id, crop.crop_name)
	help_label.text = "%s · %s%d 夜%s" % [name_in_belt, seasonal, nights, water]

func refresh_seed_calendar() -> void:
	var tomorrow := Global.current_day + 1
	forecast_label.text = "明日 %s · %s" % [
		Global.get_current_solar_term(tomorrow), "雨润旱田" if Global.has_rain(tomorrow) else "晴"]
	calendar_button.tooltip_text = forecast_label.text
	_refresh_watch()
	for id in seed_buttons:
		var crop := ItemManager.get_crop(id)
		var slot: SEED_BUTTON = seed_buttons[id]
		var nights := Global.sowing_nights(crop)
		slot.get_node("SeasonMark").visible = nights < crop.days_to_grow
		slot.refresh_tooltip(crop, nights)

func refresh_farm_status() -> void:
	var report := Global.field_night_forecast()
	farm_status.tooltip_text = "待浇 %d · 可收 %d · 今夜成熟 %d" % [
		report.dry, report.ready, report.public_ripe + report.private_ripe]
	if report.blocked > 0:
		farm_status.tooltip_text += " · 断水 %d" % report.blocked
	var work := PackedStringArray()
	if report.ready > 0:
		work.append("可收 %d" % report.ready)
	if report.dry > 0:
		work.append("待浇 %d" % report.dry)
	if report.blocked > 0:
		work.append("断水 %d" % report.blocked)
	farm_status.text = "田务" if work.is_empty() else " · ".join(work)
	var needs_water: int = report.dry + report.blocked
	if needs_water != fields_needing_water:
		fields_needing_water = needs_water
		_refresh_sleep_tooltip()
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
	elif field_gate_button.text == "取消装闸":
		keys = "A 在金框处装闸 · B 取消" if pad else "左键在金框处装闸 · Esc 取消"
	else:
		keys = ("A 挖渠（%d 铜钱/格） · LT+A 填渠 · B 退出" % Global.channel_cost() if pad
			else "左键挖渠（%d 铜钱/格） · %s+左键填渠 · Esc 退出" % [Global.channel_cost(), Preferences.key_label(KeyBindings.FILL)])
	help_label.text = "%s\n%s" % [channel_message, keys]

func refresh_survey_button() -> void:
	survey_button.disabled = Global.channel_survey_day == 0
	field_gate_button.visible = not survey_button.disabled
	survey_button.tooltip_text = ("定渠线起点，查看价格再确认施工" if not survey_button.disabled else
		"让渠水养苗过一夜，再找石墨学习放样。")

func show_survey_mode(active: bool) -> void:
	survey_button.text = "取消放样" if active else "放样"
	show_channel_help("放样 · 先定渠线起点" if active else "把水渠接到水源")

func show_field_gate_mode(active: bool) -> void:
	field_gate_button.text = "取消装闸" if active else "装田口闸"
	show_channel_help("选通水一侧的田边中格 · 每块井田一闸" if active else "把水渠接到水源")

func _update_health(health: int) -> void:
	health_label.text = "气血 %d / %d" % [health, Global.balance.player_max_health]
	health_label.add_theme_color_override("font_color", Color("#8d3529") if health * 3 < Global.balance.player_max_health else Color("#37291c"))
	health_bar.max_value = Global.balance.player_max_health
	health_bar.value = health
