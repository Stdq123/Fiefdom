extends Control

const SEED_BUTTON := preload("res://scripts/SeedButton.gd")
const VISITOR_NOTES_MAX_HEIGHT := 116.0
const SAVE_NOTICE_MAX_WIDTH := 352.0
const SAVE_NOTICE_INFO := Color("#d9e2b6")
const SAVE_NOTICE_WARNING := Color("#ffc399")
const WORKSHOP_TEXT := Color("#ebd6ad")
const WORKSHOP_SHORTAGE := Color("#ffc399")

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
@onready var visitor_notes: ScrollContainer = %VisitorNotes
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
@onready var defense_report: Button = %DefenseReport
@onready var practice_label: Label = %PracticeLabel
@onready var driving_panel: PanelContainer = %DrivingPanel
@onready var driving_status: Label = %DrivingStatus
@onready var driving_hint: Label = %DrivingHint
@onready var leave_cart: Button = %LeaveCart
@onready var help_label: Label = %HelpLabel
@onready var farm_status: Button = %FarmStatus
@onready var sow_from_plan: Button = %SowFromPlan
@onready var plan_actions: HBoxContainer = %PlanActions
@onready var prepare_empty_plots: Button = %PrepareEmptyPlots
@onready var replant_after_harvest: Button = %ReplantAfterHarvest
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
@onready var dawn_notice: PanelContainer = $DawnNotice
@onready var workshop_status: PanelContainer = $WorkshopStatus
@onready var workshop_stock: SilkStock = %WorkshopStock
@onready var workshop_batch: Label = %WorkshopBatch
@onready var workshop_last_work: Label = %WorkshopLastWork
@onready var map_overlays: Array[Control] = [$Journal, $Calendar, $SeedBelt, $Vitals, $Tools, $Actions,
	$RationsButton, $SaveNotice, $HarvestReceipt, dawn_notice, $RoomLocation, workshop_status]

var seed_buttons: Dictionary = {}
var save_notice_tween: Tween
var _save_notice_covered := false
var fields_needing_water := 0
var pavilion_story_available := false
var pavilion_story_expected := false
var reclamation_mode := false
var indoors := false
var driving := false
var channel_message := ""
var sky_icons := HUDIcons.SKY.map(HUDIcons.icon)

func map_space_clear(area: Rect2) -> bool:
	if not get_viewport_rect().grow(-8.0).encloses(area):
		return false
	for reserved in map_obstacles():
		if reserved.intersects(area):
			return false
	return true

func map_obstacles() -> Array[Rect2]:
	var occupied: Array[Rect2] = []
	for overlay in map_overlays:
		if overlay.is_visible_in_tree():
			occupied.append(overlay.get_global_rect().grow(4.0))
	return occupied

func set_reclamation_mode(active: bool) -> void:
	reclamation_mode = active
	_refresh_sections()

func set_field_effort(cost: int) -> void:
	$Vitals.set_stamina_cost(cost)

func set_estate_room(room: Global.EstateRoom) -> void:
	indoors = room != Global.EstateRoom.OUTDOORS
	$RoomLocation.text = "蚕棚" if room == Global.EstateRoom.SILK_SHED else "堂屋"
	workshop_status.visible = room == Global.EstateRoom.SILK_SHED
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
	for control in $Journal.find_children("*", "Label") + $Journal.find_children("*", "Button"):
		InterfaceFont.scale_reading_text(control)
	for control: Control in [day_label, calendar_label, rank_label,
			reputation_label, money_label, king_label, inventory_label, well_field_label, help_label,
		farm_status, sow_from_plan, prepare_empty_plots, replant_after_harvest, canal_preview, morning_button, pinned_order,
		$RoomLocation, workshop_batch, workshop_last_work]:
		InterfaceFont.scale_reading_text(control)
	save_notice.add_theme_stylebox_override(&"normal", get_theme_stylebox(&"panel", &"HudRail"))
	InterfaceFont.scale_reading_text(save_notice)
	Preferences.reading_size_changed.connect(_fit_save_notice_width)
	resized.connect(_fit_save_notice_width)
	save_notice.minimum_size_changed.connect(_fit_save_notice_height, CONNECT_DEFERRED)
	for card: PanelContainer in [$Journal, $Calendar]:
		card.minimum_size_changed.connect(_fit_top_card.bind(card), CONNECT_DEFERRED)
		_fit_top_card.call_deferred(card)
	journal_details.toggled.connect(_toggle_journal_details)
	var notes_bar := visitor_notes.get_v_scroll_bar()
	notes_bar.theme_type_variation = &"HudJournalBar"
	notes_bar.focus_mode = Control.FOCUS_ALL
	visitor_label.minimum_size_changed.connect(_fit_visitor_notes, CONNECT_DEFERRED)
	_toggle_journal_details(journal_details.button_pressed)
	ledger_toggle.pressed.connect(_toggle_ledger_details)
	%CoinIcon.texture = HUDIcons.icon(HUDIcons.Symbol.COIN)
	%GrainIcon.texture = HUDIcons.icon(HUDIcons.Symbol.GRAIN)
	calendar_button.icon = HUDIcons.icon(HUDIcons.Symbol.CALENDAR)
	reclaim_button.icon = HUDIcons.icon(HUDIcons.Symbol.HOE)
	channel_button.icon = HUDIcons.icon(HUDIcons.Symbol.WATER)
	map_button.icon = HUDIcons.icon(HUDIcons.Symbol.MAP)
	settings_button.icon = HUDIcons.icon(HUDIcons.Symbol.SETTINGS)
	manage_button.icon = HUDIcons.icon(HUDIcons.Symbol.LEDGER)
	pinned_order.icon = HUDIcons.icon(HUDIcons.Symbol.LEDGER)
	rations_button.icon = HUDIcons.icon(HUDIcons.Symbol.RATIONS)
	_refresh_sleep_action()
	GameEvents.estate_arrived.connect(_show_arrival)
	GameEvents.day_advanced.connect(arrival.hide.unbind(1))
	GameEvents.driving_practice_progress.connect(show_driving_progress)
	GamepadInput.changed.connect(_refresh_shortcuts)
	Preferences.bindings_changed.connect(_refresh_shortcuts)
	_refresh_shortcuts()
	GameEvents.silk_changed.connect(_refresh_silk_stock)
	GameEvents.daylight_changed.connect(_refresh_watch)
	GameEvents.field_wait_policy_changed.connect(_refresh_sleep_action)
	_refresh_watch()
	GameEvents.season_order_pin_changed.connect(_refresh_pinned_order)
	GameEvents.day_advanced.connect(_refresh_pinned_order.unbind(1))
	GameEvents.inventory_changed.connect(_refresh_pinned_order.unbind(1))
	GameEvents.management_visibility_changed.connect(_refresh_pinned_order.unbind(1))
	GameEvents.management_visibility_changed.connect(_refresh_plan_seed_button.unbind(1))
	GameEvents.farm_state_changed.connect(_refresh_plan_seed_button)
	GameEvents.crop_harvested.connect(_refresh_pinned_order.unbind(1))
	GameEvents.farm_state_changed.connect(_refresh_pinned_order)
	GameEvents.channels_changed.connect(_refresh_pinned_order)
	GameEvents.well_field_reclaimed.connect(_refresh_pinned_order.unbind(2))
	GameEvents.retainer_recruited.connect(_refresh_pinned_order.unbind(1))
	GameEvents.retainer_departed.connect(_refresh_pinned_order.unbind(1))
	GameEvents.fish_changed.connect(_refresh_pinned_order)
	GameEvents.silk_changed.connect(_refresh_pinned_order)
	GameEvents.tax_reform_choice_made.connect(_refresh_pinned_order.unbind(1))
	GameEvents.campaign_ended.connect(_refresh_pinned_order.unbind(1))
	GameEvents.day_advanced.connect(_refresh_raid_alert.unbind(1))
	GameEvents.raid_started.connect(_refresh_raid_alert)
	GameEvents.raid_defeated.connect(_refresh_raid_alert)
	GameEvents.east_watch_built.connect(_refresh_raid_alert)
	GameEvents.campaign_ended.connect(_refresh_raid_alert.unbind(1))
	_refresh_pinned_order()
	_refresh_raid_alert()
	refresh_morning_record()

func _toggle_journal_details(expanded: bool) -> void:
	visitor_notes.visible = expanded
	if expanded:
		visitor_notes.scroll_vertical = 0
		_fit_visitor_notes()
	journal_details.text = "收起来客" if expanded else "封地手记"
	journal_details.icon = journal_details.get_theme_icon(&"arrow" if expanded else &"arrow_collapsed", &"Tree")

func _fit_visitor_notes() -> void:
	visitor_notes.custom_minimum_size.y = minf(visitor_label.get_combined_minimum_size().y, VISITOR_NOTES_MAX_HEIGHT)

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
	var running := Global.outcome == Global.Outcome.RUNNING
	defense_report.visible = running and Global.defense_review_ready()
	raid_alert.visible = running and (Global.raid_day > 0 or Global.is_raid_day(tomorrow))
	if not raid_alert.visible:
		return
	if Global.raid_day > 0:
		raid_alert.text = "%s来袭 · 标出位置" % Global.raid_name(Global.raid_kind)
		raid_alert.tooltip_text = GamepadInput.bow_instruction() + "。侧走避开地面标记。"
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
	var upcoming: bool = schedule.start > Global.current_day
	var timing := "第 %d 天开收" % schedule.start if upcoming else "第 %d 天截止" % schedule.end
	var action := timing
	if Global.can_deliver_season_order(schedule):
		action = "去西市交货"
	else:
		var plan := Global.season_order_work(schedule)
		if not plan.is_empty():
			var label := ItemManager.crop_label(plan.crop_id)
			match int(plan.action):
				Global.OrderWork.HARVEST: action = "收备货私田"
				Global.OrderWork.WATER: action = "给%s浇水" % label
				Global.OrderWork.SOW: action = "种%s" % label
				Global.OrderWork.WAIT: action = "%s最早第 %d 天收" % [label, plan.day]
	var heading := "下季备货" if upcoming else "时令单"
	var progress := amounts if action == timing else "%s · %s" % [amounts, timing]
	pinned_order.text = "%s · %s\n%s" % [heading, action, progress]
	pinned_order.accessibility_description = schedule.order.title

func _refresh_silk_stock() -> void:
	if not workshop_status.visible:
		return
	var silk := Global.silk_workshop
	workshop_stock.refresh(silk)
	var feed := Global.balance.silk_leaves_per_night
	var missing := feed - silk.leaves
	var summary := "蚕匾空着\n首夜用 %d 片桑叶" % feed
	if silk.nights_left > 0:
		summary = "还需养 %d 夜\n%s" % [silk.nights_left,
			"今夜缺 %d 片桑叶" % missing if missing > 0 else "每夜用 %d 片桑叶" % feed]
	elif silk.repeat_batches:
		missing = silk.batch_leaf_cost(Global.balance) - silk.leaves
		summary = "续养还差 %d 片桑叶" % missing if missing > 0 else "今晚可续养\n首夜用 %d 片桑叶" % feed
	elif missing > 0:
		summary = "蚕匾空着\n开养还差 %d 片桑叶" % missing
	workshop_batch.text = summary
	workshop_batch.add_theme_color_override(&"font_color", WORKSHOP_SHORTAGE if missing > 0 else WORKSHOP_TEXT)
	var last_work := silk.last_work_summary()
	workshop_last_work.text = "昨夜 · " + last_work.replace(" · ", "\n")
	workshop_last_work.visible = not last_work.is_empty()

func _refresh_shortcuts() -> void:
	var pad := GamepadInput.active
	leave_cart.text = "下车  B" if pad else "下车  Esc"
	map_button.text = "舆图  %s" % ("Y" if pad else Preferences.key_label(KeyBindings.MAP))
	calendar_button.text = "历书 %s" % ("View" if pad else Preferences.key_label(KeyBindings.ALMANAC))
	for id in seed_buttons:
		var shortcut := seed_buttons[id].get_node("Shortcut") as Label
		shortcut.text = Preferences.seed_label(id)
		shortcut.visible = not pad
	_refresh_raid_alert()
	refresh_seed_calendar()

func _refresh_watch() -> void:
	watch_label.text = Global.day_watch_label()
	watch_dial.show_watch(watch_label.text)
	weather_icon.texture = sky_icons[HUDIcons.sky_index()]

func refresh_morning_record() -> void:
	morning_button.visible = Global.has_morning_record()
	var fields := Global.last_field_night
	var ripe: int = fields.get("public_ripe", 0) + fields.get("private_ripe", 0)
	var rank_change: int = Global.last_dawn.get("rank_change", 0)
	var warnings := Global.dawn_warnings()
	morning_button.text = "昨夜结算"
	morning_button.tooltip_text = "\n".join(warnings)
	if warnings.size() > 1:
		morning_button.text += " · %d 项提醒" % warnings.size()
	elif not warnings.is_empty():
		morning_button.text += " · " + warnings[0]
	elif rank_change != 0:
		var change := "晋升" if rank_change > 0 else "削爵至"
		morning_button.text += " · " + change + Global.rank_names[Global.current_rank]
	elif not Global.last_dawn.get("completed_fields", []).is_empty():
		morning_button.text += " · 井田完工"
	elif ripe > 0:
		morning_button.text += " · 新熟 %d 格" % ripe

func show_dawn_notice() -> void:
	var warnings := Global.dawn_warnings(true)
	if Global.raid_day == Global.current_day:
		warnings.insert(0, "东路来敌 · " + Global.raid_name(Global.raid_kind))
	var result := "\n".join(warnings)
	if result.is_empty():
		var milestones := Global.dawn_milestones()
		result = milestones[0] if not milestones.is_empty() else _dawn_harvest()
	dawn_notice.present(result, not warnings.is_empty())

func _dawn_harvest() -> String:
	var fields := Global.last_field_night
	var public_ripe: int = fields.get("public_ripe", 0)
	var private_ripe: int = fields.get("private_ripe", 0)
	var ready := PackedStringArray()
	if public_ripe > 0:
		ready.append("公田新熟 %d 格" % public_ripe)
	if private_ripe > 0:
		ready.append("私田新熟 %d 格" % private_ripe)
	return " · ".join(ready)

func show_save_notice(message: String, warning := false) -> void:
	if save_notice_tween:
		save_notice_tween.kill()
		save_notice_tween = null
	save_notice.text = message
	save_notice.add_theme_color_override(&"font_color", SAVE_NOTICE_WARNING if warning else SAVE_NOTICE_INFO)
	_fit_save_notice_width()
	if not warning and not message.is_empty():
		save_notice_tween = create_tween()
		save_notice_tween.tween_interval(2.8)
		save_notice_tween.tween_callback(_dismiss_save_notice)
	_refresh_save_notice_visibility()

func set_save_notice_covered(covered: bool) -> void:
	_save_notice_covered = covered
	_refresh_save_notice_visibility()

func _refresh_save_notice_visibility() -> void:
	save_notice.visible = not _save_notice_covered and not save_notice.text.is_empty()
	if save_notice_tween and save_notice_tween.is_valid():
		if save_notice.visible:
			save_notice_tween.play()
		else:
			save_notice_tween.pause()

func _dismiss_save_notice() -> void:
	save_notice.hide()
	save_notice.text = ""

func _fit_save_notice_width() -> void:
	if save_notice.text.is_empty():
		return
	var font := save_notice.get_theme_font(&"font")
	var font_size := save_notice.get_theme_font_size(&"font_size")
	var text_width := font.get_multiline_string_size(save_notice.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var padding := save_notice.get_theme_stylebox(&"normal").get_minimum_size().x
	var available := clampf(size.x - 32.0, padding, SAVE_NOTICE_MAX_WIDTH)
	save_notice.offset_left = save_notice.offset_right - minf(ceilf(text_width + padding), available)
	_fit_save_notice_height.call_deferred()

func _fit_save_notice_height() -> void:
	save_notice.offset_top = save_notice.offset_bottom - save_notice.get_combined_minimum_size().y

func refresh_rations() -> void:
	var plan := Global.night_rations_plan()
	var tone := Color("#e7ddbd")
	if plan.research_gap > 0:
		rations_button.text = "今夜安排 · 缺经费"
		tone = Color("#efbf8a")
	elif plan.uncovered > 0:
		rations_button.text = "今夜安排 · 缺粮 %d" % plan.uncovered
		tone = Color("#efbf8a")
	elif Global.tribute_penalty_tonight() > 0:
		rations_button.text = "今夜安排 · 纳贡到期"
		tone = Color("#efbf8a")
	elif pavilion_story_available:
		rations_button.text = "今夜安排 · " + PavilionRest.STORY_LABEL
		tone = Color("#f1d38d")
	elif plan.missing > 0:
		rations_button.text = "今夜安排 · 口粮可补足"
		tone = Color("#c7dcaf")
	elif fields_needing_water > 0:
		rations_button.text = "今夜安排 · %d 格缺水" % fields_needing_water
		tone = Color("#efbf8a")
	elif pavilion_story_expected:
		rations_button.text = "今夜安排 · 亭中有约"
		tone = Color("#f1d38d")
	else:
		rations_button.text = "今夜安排"
	rations_button.add_theme_color_override("font_color", tone)
	rations_button.tooltip_text = "查看田务和用粮\n粮仓 %d 份 · 今夜所需 %d 份" % [Global.food_storage, plan.need]
	if plan.research_gap > 0:
		rations_button.tooltip_text += "\n明早研究费 %d 铜钱，备粮后还差 %d。" % [plan.research_fee, plan.research_gap]
		if plan.uncovered > 0:
			rations_button.tooltip_text += "\n预计口粮还缺 %d 份。" % plan.uncovered
	if pavilion_story_available:
		rations_button.tooltip_text += "\n邻居已入席，可指路去听灯下小谈。"
	elif pavilion_story_expected:
		rations_button.tooltip_text += "\n%s起有小谈，可先去亭边候席。" % PavilionRest.rest_watch()

func refresh_tribute() -> void:
	var due := Global.tribute_deadline()
	tribute_button.visible = Global.outcome == Global.Outcome.RUNNING and due > 0
	if tribute_button.visible:
		var tonight := due == Global.current_day
		var name := "纳贡" if Global.first_tribute_delivered() else "首贡 1 份"
		var deadline := "今夜到期" if tonight else "第 %d 天过夜前" % due
		if Global.tribute_overdue():
			deadline = "已逾期"
		tribute_button.text = "%s · %s" % [name, deadline]
		tribute_button.tooltip_text = "查看今夜安排。收割任一公田后，纳贡期限重新计算。"
		tribute_button.add_theme_color_override("font_color", Color("#efbf8a") if tonight else Color("#e7ddbd"))
	_refresh_sleep_action()

func _refresh_sleep_action() -> void:
	var council_waiting := Global.tax_council_waiting()
	sleep_button.text = "去见召简" if council_waiting else "睡觉"
	sleep_button.icon = HUDIcons.icon(HUDIcons.Symbol.MAP if council_waiting else HUDIcons.Symbol.MOON)
	if council_waiting:
		sleep_button.tooltip_text = "召简在堂前候议。议税后可过夜。"
		return
	sleep_button.tooltip_text = "结束今天，恢复体力"
	if Global.wait_for_fields_before_sleep:
		sleep_button.tooltip_text += "\n已安排门客在剩余时辰先收工。"
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
		if HUDIcons.CROPS.has(id):
			icon.texture = HUDIcons.icon(HUDIcons.CROPS[id])
			icon.self_modulate = Color.WHITE
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

func show_seed(seed_id: String, from_plan: bool, prepare: bool, replant: bool) -> void:
	var crop := ItemManager.get_crop(seed_id)
	if not crop:
		return
	seed_slots.show()
	farm_status.show()
	canal_controls.hide()
	sow_from_plan.set_pressed_no_signal(from_plan)
	prepare_empty_plots.set_pressed_no_signal(prepare)
	replant_after_harvest.set_pressed_no_signal(replant)
	_refresh_plan_seed_button()
	for id in seed_buttons:
		seed_buttons[id].set_pressed_no_signal(not from_plan and id == seed_id)
	if from_plan:
		var batch_key := "LT" if GamepadInput.active else Preferences.key_label(KeyBindings.FILL)
		if replant:
			help_label.text = "按住 %s 预览批量田务" % batch_key
		else:
			help_label.text = "按住 %s 预览整备" % batch_key if prepare else "空畦按各格安排选种"
		return
	var nights := Global.sowing_nights(crop)
	var seasonal := "当令 " if nights < crop.days_to_grow else ""
	var water := " · 需通水" if crop.is_water_crop else ""
	var name_in_belt := SEED_BUTTON.display_name(seed_id, crop.crop_name)
	help_label.text = "%s · %s%d 夜%s" % [name_in_belt, seasonal, nights, water]

func _refresh_plan_seed_button() -> void:
	sow_from_plan.visible = not canal_controls.visible and (sow_from_plan.button_pressed or not Global.field_seed_plans.is_empty())
	plan_actions.visible = sow_from_plan.visible and sow_from_plan.button_pressed
	if sow_from_plan.visible:
		var batch_key := "LT" if GamepadInput.active else Preferences.key_label(KeyBindings.FILL)
		var batch_task := "整备" if prepare_empty_plots.button_pressed else "整田播种"
		sow_from_plan.tooltip_text = "依各格续播安排选种。按住 %s 预览%s。" % [batch_key, batch_task]
		prepare_empty_plots.tooltip_text = "按住 %s 预览翻地、播种和浇水。空的计划田才整备，缺水才浇。" % batch_key
		replant_after_harvest.tooltip_text = "按住 %s 指向成熟作物，预览批收、下茬和耗体力。只给本次收下且可播的计划田续播。" % batch_key

func refresh_seed_calendar() -> void:
	var tomorrow := Global.current_day + 1
	forecast_label.text = "明日 %s · %s" % [
		Global.get_current_solar_term(tomorrow), "雨润旱田" if Global.has_rain(tomorrow) else Global.weather_label(tomorrow)]
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
		_refresh_sleep_action()
		refresh_rations()

func show_channel_help(message: String) -> void:
	seed_slots.hide()
	farm_status.hide()
	sow_from_plan.hide()
	plan_actions.hide()
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
