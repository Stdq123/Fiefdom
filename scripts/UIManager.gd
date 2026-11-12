extends CanvasLayer

const NIGHT_RATIONS_PANEL := preload("res://scenes/NightRationsPanel.tscn")

@onready var world = $"../World"
@onready var hud = $Control/EstateHUD
@onready var sleep_button: Button = hud.sleep_button
@onready var manage_button: Button = hud.manage_button
@onready var reclaim_button: Button = hud.reclaim_button
@onready var settings_button: Button = hud.settings_button
@onready var channel_button: Button = hud.channel_button
@onready var help_label: Label = hud.help_label
@onready var fader: ColorRect = $Control/Fader
@onready var dawn_caption: Label = $Control/Fader/DawnCaption
@onready var directions = $Control/EstateDirections
@onready var estate_map = $Control/EstateMap
@onready var route_goals = $Control/RouteGoals
@onready var calendar = $Control/SeasonCalendar
@onready var autumn_exhibit_panel = $Control/AutumnExhibitPanel
@onready var sheepfold_panel = $Control/SheepfoldPanel

var state_manager: UIStateManager
var panel_manager: UIPanelManager
var dialog_manager: UIDialogManager
var sleep_tween: Tween

func _ready() -> void:
	state_manager = UIStateManager.new()
	add_child(state_manager)
	state_manager.setup(hud.day_label, hud.inventory_label, hud.king_label, hud.stamina_label,
		hud.rank_label, hud.money_label, hud.well_field_label, hud.stamina_bar)

	panel_manager = UIPanelManager.new()
	add_child(panel_manager)
	panel_manager.setup($Control)
	var settings := panel_manager.settings_panel_instance
	settings.visibility_changed.connect(func(): GameEvents.settings_visibility_changed.emit(settings.visible))

	dialog_manager = UIDialogManager.new()
	add_child(dialog_manager)
	dialog_manager.setup($Control, world.player)

	hud.setup_seeds(world.SEED_ORDER, world.select_seed)
	hud.show_seed(world.current_seed_id)
	hud.guide.setup(world)
	GamepadInput.changed.connect(_refresh_control_hints)
	Preferences.bindings_changed.connect(_refresh_control_hints)
	hud.refresh_farm_status()
	directions.setup(world, hud)
	if not Global.ravine_trip_target.is_empty():
		directions.follow_ravine(Global.ravine_trip_target)
	estate_map.setup(world, directions, _map_controls_blocked)
	hud.map_button.pressed.connect(estate_map.open_map)
	hud.route_progress.pressed.connect(_open_route_goals)
	route_goals.action_requested.connect(_on_route_goal_action)
	calendar.controls_blocked = _map_controls_blocked
	hud.calendar_button.pressed.connect(calendar.open_map)
	calendar.directions_requested.connect(_guide_calendar_event)
	hud.pinned_order.pressed.connect(_on_pinned_order_pressed)
	_connect_signals()
	_refresh_worksite_button()
	_refresh_channel_button()
	hud.refresh_survey_button()
	update_ui()
	if not Global.restore_notice.is_empty():
		hud.show_save_notice(Global.restore_notice, true)
		Global.restore_notice = ""
	if MapTravel.active:
		MapTravel.finished.connect(_show_away_field_report, CONNECT_ONE_SHOT)
	else:
		_show_away_field_report.call_deferred()

func _show_away_field_report() -> void:
	if not Global.acknowledge_away_field_work():
		return
	var report := Global.away_field_report
	var notice := "今日外出田务 · " + Global.away_field_summary(Global.AWAY_FIELD_JOBS)
	if report.first_tribute:
		report.first_tribute = false
		if Global.rotation_offer_ready() and directions.destination().is_empty() and directions.follow_neighbor(VisitorData.FIELD_KEEPER):
			notice += " · 可找渠伯谈轮作"
	GameEvents.world_notice.emit(notice)

func _process(_delta: float) -> void:
	world.player.menu_open = _estate_panel_open()
	var blocked := _estate_controls_blocked()
	world.player.meal_controls_blocked = blocked
	hud.map_button.disabled = blocked or world.player.training_cart.visible or Global.outcome != Global.Outcome.RUNNING
	hud.calendar_button.disabled = hud.map_button.disabled
	hud.route_progress.disabled = hud.map_button.disabled
	hud.raid_alert.disabled = blocked
	directions.update_marker(blocked or Global.is_indoors())

func _estate_controls_blocked() -> bool:
	return (MapTravel.active or world.channel_mode or world.player.conversation_open
		or (sleep_tween and sleep_tween.is_running())
		or _estate_panel_open())

func _estate_panel_open() -> bool:
	var management := panel_manager.management_panel_instance
	return ((is_instance_valid(management) and management.visible)
		or panel_manager.settings_panel_instance.visible or $Control.has_node("ReclamationPanel"))

func _map_controls_blocked() -> bool:
	return _estate_controls_blocked() or world.player.training_cart.visible

func _open_route_goals() -> void:
	if not _map_controls_blocked():
		route_goals.open_map()

func _on_route_goal_action(kind: Global.RouteGoal) -> void:
	match kind:
		Global.RouteGoal.TRIBUTE, Global.RouteGoal.TAXED_HARVEST:
			estate_map.open_fields()
		Global.RouteGoal.OFFER_SILK, Global.RouteGoal.SELL_SILK:
			panel_manager.show_management_panel()
			panel_manager.management_panel_instance.show_silk()
		Global.RouteGoal.COPPER:
			_show_market()
		Global.RouteGoal.RAIDS:
			if Global.raid_day > 0 or Global.is_raid_day(Global.current_day + 1):
				_on_raid_alert_pressed()
			else:
				panel_manager.show_management_panel()
				panel_manager.management_panel_instance.show_estate()

func _connect_signals() -> void:
	GameEvents.day_advanced.connect(update_ui.unbind(1))
	GameEvents.day_advanced.connect(_refresh_farm_calendar.unbind(1))
	GameEvents.save_finished.connect(_on_save_finished)
	GameEvents.farm_state_changed.connect(hud.refresh_farm_status)
	GameEvents.farm_state_changed.connect(_refresh_opening_action)
	GameEvents.crop_harvested.connect(hud.refresh_farm_status.unbind(1))
	GameEvents.channels_changed.connect(hud.refresh_farm_status)
	GameEvents.channels_changed.connect(_refresh_opening_action)
	GameEvents.crop_harvested.connect(update_ui.unbind(1))
	GameEvents.stamina_changed.connect(update_ui.unbind(1))
	GameEvents.visitor_interacted.connect(_on_visitor_interacted)
	GameEvents.gathering_guest_interacted.connect(_on_gathering_guest_interacted)
	GameEvents.gathering_book_requested.connect(_on_gathering_book_requested)
	GameEvents.neighbor_directions_requested.connect(_on_neighbor_directions_requested)
	GameEvents.gathering_recital_recorded.connect(update_ui)
	GameEvents.autumn_exhibit_requested.connect(_on_autumn_exhibit_requested)
	GameEvents.autumn_exhibit_completed.connect(update_ui)
	GameEvents.autumn_guest_interacted.connect(_on_autumn_guest_interacted)
	GameEvents.sheepfold_requested.connect(_on_sheepfold_requested)
	GameEvents.retainer_interacted.connect(_on_retainer_interacted)
	GameEvents.season_board_interacted.connect(_on_season_board_interacted)
	GameEvents.freight_arrival_interacted.connect(_on_freight_arrival_interacted)
	GameEvents.travel_hearth_interacted.connect(_on_travel_hearth_interacted)
	GameEvents.winter_supper_requested.connect(_on_winter_supper_requested)
	GameEvents.winter_supper_prepared.connect(update_ui)
	GameEvents.road_rest_interacted.connect(_on_road_rest_interacted)
	GameEvents.rotation_book_interacted.connect(_on_rotation_book_interacted)
	GameEvents.east_watch_read_requested.connect(dialog_manager.show_east_watch)
	GameEvents.east_watch_built.connect(update_ui)
	GameEvents.tax_reform_triggered.connect(_refresh_opening_action)
	GameEvents.tax_reform_choice_made.connect(_refresh_opening_action.unbind(1))
	GameEvents.tax_envoy_interacted.connect(_on_tax_envoy_interacted)
	GameEvents.channel_survey_learned.connect(hud.refresh_survey_button)
	GameEvents.channel_survey_learned.connect(update_ui)
	GameEvents.raid_defeated.connect(update_ui)
	GameEvents.retainer_duty_changed.connect(update_ui.unbind(1))
	GameEvents.retainer_recruited.connect(update_ui.unbind(1))
	GameEvents.retainer_departed.connect(update_ui.unbind(1))
	GameEvents.reputation_changed.connect(update_ui.unbind(1))
	GameEvents.money_changed.connect(update_ui.unbind(1))
	GameEvents.inventory_changed.connect(update_ui.unbind(1))
	GameEvents.food_changed.connect(update_ui.unbind(1))
	GameEvents.night_rations_changed.connect(update_ui)
	GameEvents.night_rations_requested.connect(_show_night_rations)
	GameEvents.silk_changed.connect(update_ui)
	GameEvents.ravine_journal_changed.connect(update_ui)
	GameEvents.rank_changed.connect(update_ui.unbind(1))
	GameEvents.well_field_added.connect(update_ui.unbind(1))
	GameEvents.well_field_added.connect(_refresh_worksite_button.unbind(1))
	GameEvents.well_field_reclaimed.connect(_refresh_worksite_button.unbind(2))
	GameEvents.irrigation_unlocked.connect(_refresh_channel_button)
	var feedback := func(message: String): hud.practice_label.text = message
	GameEvents.practice_feedback.connect(feedback)
	GameEvents.silk_station_feedback.connect(feedback)
	GameEvents.estate_room_changed.connect(hud.set_estate_room)
	GameEvents.silk_shed_directions_requested.connect(_on_silk_shed_directions_requested)
	GameEvents.west_market_directions_requested.connect(_on_west_market_directions_requested)
	GameEvents.ravine_trip_requested.connect(_on_ravine_trip_requested)

	world.seed_selected.connect(hud.show_seed)
	world.channel_mode_changed.connect(_on_channel_mode_changed)
	world.channel_feedback.connect(hud.show_channel_help)
	world.irrigation_overlay.preview_changed.connect(func(message: String): hud.canal_preview.text = message)
	world.irrigation_overlay.survey_changed.connect(hud.show_survey_mode)
	hud.survey_button.pressed.connect(world.irrigation_overlay.toggle_survey)
	world.visitor_changed.connect(_update_visitor_note)
	hud.cancel_directions.visibility_changed.connect(_refresh_opening_action)
	hud.opening_action.pressed.connect(_on_opening_action)
	sleep_button.pressed.connect(_on_sleep_pressed)
	hud.rations_button.pressed.connect(_show_night_rations)
	hud.raid_alert.pressed.connect(_on_raid_alert_pressed)
	manage_button.pressed.connect(_on_manage_pressed)
	hud.neighbors_button.pressed.connect(_on_neighbors_pressed)
	reclaim_button.pressed.connect(_on_reclaim_pressed)
	hud.worksite_button.pressed.connect(_on_worksite_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	channel_button.pressed.connect(func(): world.set_channel_mode(not world.channel_mode))

func update_ui() -> void:
	state_manager.update_all_ui()
	hud.refresh_rations()
	hud.quest_label.visible = (Global.tax_reform_choice != Global.TaxReformChoice.REFORMED
		and Global.first_tribute_delivered() and not Global.quest_completed)
	hud.quest_label.text = Global.current_quest.trim_prefix("目标：")
	hud.reputation_label.text = "声望 %d" % Global.reputation
	hud.calendar_label.text = "第 %d 年 · %s · %s · %s" % [
		Global.get_current_year(), Global.SEASON_NAMES[Global.season_index()], Global.get_current_solar_term(),
		"雨润旱田" if Global.has_rain() else "晴"]
	hud.gathering_label.text = ""
	if Global.is_gathering_day():
		hud.gathering_label.text = "今日谷雨亭集 · 迎客曲已入簿" if Global.gathering_score() > 0 else "今日谷雨亭集 · 南路亭东"
	elif Global.is_gathering_day(Global.current_day + 1):
		hud.gathering_label.text = "明日谷雨亭集 · 南路亭东"
	elif Global.is_summer_raft_day():
		hud.gathering_label.text = ("今日夏至试筏 · 竹涧西岸" if not Global.summer_raft_results.has(Global.current_day)
			else "夏至试筏 · 成绩已入簿")
	elif Global.is_summer_raft_day(Global.current_day + 1):
		hud.gathering_label.text = "明日夏至试筏 · 竹涧西岸"
	elif Global.is_autumn_exhibit_day():
		hud.gathering_label.text = "今日秋社 · 南路亭东" if Global.autumn_exhibit_record(Global.current_day).is_empty() else "今日秋社 · 已入簿"
	elif Global.is_autumn_exhibit_day(Global.current_day + 1):
		hud.gathering_label.text = "明日秋社 · 备三种私田收成"
	elif Global.is_winter_supper_day():
		hud.gathering_label.text = ("今日冬至围炉 · 南路亭东" if Global.winter_supper_record().is_empty()
			else "冬至围炉 · 今夜已备饭")
	elif Global.is_winter_supper_day(Global.current_day + 1):
		hud.gathering_label.text = "明日冬至围炉 · 备麦和菽或鱼"
	hud.gathering_label.visible = not hud.gathering_label.text.is_empty()
	_update_visitor_note(world.current_visitor())

func _refresh_farm_calendar() -> void:
	hud.refresh_seed_calendar()
	hud.refresh_farm_status()
	if not world.channel_mode:
		hud.show_seed(world.current_seed_id)

func _refresh_channel_button() -> void:
	channel_button.disabled = not Global.tech_unlocked["irrigation"]
	channel_button.tooltip_text = ("每格 %d 铜钱" % Global.channel_cost() if not channel_button.disabled else
		"书达到 %d 级后，可在「管理 → 科技」解锁水利" % Irrigation.UNLOCK_LITERACY_LEVEL)

func _on_channel_mode_changed(enabled: bool) -> void:
	channel_button.text = "结束挖渠" if enabled else "挖渠"
	if enabled:
		hud.show_channel_help("把水渠接到水源")
	else:
		hud.show_seed(world.current_seed_id)

func _refresh_control_hints() -> void:
	if world.channel_mode:
		hud.refresh_channel_help()
	else:
		hud.show_seed(world.current_seed_id)
	_update_visitor_note(world.current_visitor())

func _on_visitor_interacted(data: VisitorData) -> void:
	directions.arrive_at(data.name)
	world.set_channel_mode(false)
	var actor := world.neighbor_actor(data.name) as Visitor
	dialog_manager.show_visitor_dialog(data, actor.visit_note() if actor else data.meeting_place,
		actor != null and actor.resting_at_pavilion())

func _on_gathering_guest_interacted(data: VisitorData) -> void:
	directions.arrive_at(data.name)
	world.set_channel_mode(false)
	dialog_manager.show_gathering_guest(data)

func _on_gathering_book_requested() -> void:
	world.set_channel_mode(false)
	dialog_manager.show_gathering_book()

func _on_retainer_interacted(data: RetainerData) -> void:
	directions.arrive_at(data.name)
	world.set_channel_mode(false)
	dialog_manager.show_retainer_dialog(data)

func _on_rotation_book_interacted() -> void:
	world.set_channel_mode(false)
	dialog_manager.show_rotation_book(world.irrigation_overlay.highlight_fertile_cells)

func _on_tax_envoy_interacted() -> void:
	world.set_channel_mode(false)
	directions.arrive_at(Global.TAX_ENVOY)
	EventManager.open_tax_council(world, $Control)

func _opening_neighbor() -> String:
	if Global.tax_council_waiting():
		return Global.TAX_ENVOY
	if not hud.guide.waiting_for_tribute_crop:
		return ""
	var visitor: VisitorData = world.current_visitor()
	if visitor:
		return visitor.name
	return VisitorData.FIELD_KEEPER if is_instance_valid(world.neighbor_actor(VisitorData.FIELD_KEEPER)) else ""

func _refresh_opening_action() -> void:
	var speaker := _opening_neighbor()
	var can_trade := (Global.current_rank == Global.Rank.XIA_SHI and Global.first_tribute_delivered()
		and Global.private_harvest_total > 0 and Global.player_inventory > 0 and not Global.retainers.is_empty())
	var action: Button = hud.opening_action
	action.visible = (Global.outcome == Global.Outcome.RUNNING and not hud.cancel_directions.visible
		and (not speaker.is_empty() or can_trade))
	hud.visitor_label.visible = speaker.is_empty() or not action.visible
	if not action.visible:
		return
	if speaker.is_empty():
		action.text = "用私田收成换口粮"
		action.tooltip_text = "打开市场，查看作物转粮。"
	elif speaker == Global.TAX_ENVOY:
		action.text = "去见召简 · 堂前"
		action.tooltip_text = "走到堂前，按 %s 议税。" % GamepadInput.interact_key()
	else:
		var visitor: Visitor = world.current_visitor_actor()
		action.text = "去见%s · %s" % [speaker, visitor.visit_note() if visitor else "田边"]
		action.tooltip_text = "按地图标记走到近处，按 %s 交谈。" % GamepadInput.interact_key()

func _on_opening_action() -> void:
	if _estate_controls_blocked():
		return
	var speaker := _opening_neighbor()
	if speaker.is_empty():
		_show_market()
		panel_manager.management_panel_instance.market_panel.focus_crop_conversion()
	else:
		_on_neighbor_directions_requested(speaker)

func _update_visitor_note(data: VisitorData) -> void:
	_refresh_opening_action()
	var interact_key := GamepadInput.interact_key()
	if data:
		var visitor: Visitor = world.current_visitor_actor()
		var verb := "" if visitor.walking_to_stop else "在"
		hud.visitor_label.text = "%s%s%s，靠近按 %s。" % [data.name, verb, visitor.visit_note(), interact_key]
	elif Global.field_keeper_visiting():
		hud.visitor_label.text = "渠伯今天回到井田西南。"
	elif Global.current_day == 1 and not Global.retainers.is_empty() and Global.retainers[0].name == VisitorData.FIELD_KEEPER:
		hud.visitor_label.text = "渠伯在田边，靠近按 %s。" % interact_key
	elif Global.last_recruit_day == Global.current_day and not Global.retainers.is_empty():
		var resident: RetainerData = Global.retainers.back()
		hud.visitor_label.text = "%s已留下，可到%s找他。" % [resident.name, world.duty_place(resident)]
	else:
		hud.visitor_label.text = "今日无客来访。"
	if Global.defense_review_ready():
		if data and data.name == VisitorData.EAST_WATCHER:
			hud.visitor_label.text += " 可复盘守备。"
		else:
			for resident in Global.retainers:
				if resident.name == VisitorData.EAST_WATCHER:
					hud.visitor_label.text += "\n可到%s找弋戎复盘。" % world.duty_place(resident)
					break
	if Global.water_review_ready():
		if data and data.name == VisitorData.WATER_GUIDE:
			hud.visitor_label.text += " 可请他勘渠。"
		else:
			for resident in Global.retainers:
				if resident.name == VisitorData.WATER_GUIDE:
					hud.visitor_label.text += "\n可到%s找石墨勘渠。" % world.duty_place(resident)
					break
	if Global.ravine_handoff_ready():
		for resident in Global.retainers:
			if resident.name == VisitorData.RAVINE_GUIDE:
				hud.visitor_label.text += "\n手记齐了 · 到%s找蒲宁。" % world.duty_place(resident)
				return
		hud.visitor_label.text += "\n" + Global.ravine_status()
	elif data and data.name == VisitorData.RAVINE_GUIDE and Global.knows_ravine_journal():
		hud.visitor_label.text += "\n" + Global.ravine_status()
	elif data and data.name == VisitorData.SILK_MERCHANT and Global.silk_sample_requested():
		hud.visitor_label.text += ("\n样绸 · 已织好，可到西廊交付。" if Global.silk_workshop.bolts > 0 else
			"\n样绸 · 织好一匹后可交给陶辛。")
	elif Global.road_provisions_requested():
		for resident in Global.retainers:
			if resident.name == VisitorData.ROAD_KEEPER:
				hud.visitor_label.text += "\n路粮 · 可到%s找季青。" % world.duty_place(resident)
				return
		if data and data.name == VisitorData.ROAD_KEEPER:
			hud.visitor_label.text += "\n季青想托你备一份路粮。"
		else:
			hud.visitor_label.text += "\n路粮 · 季青会再到南路亭。"
	elif Global.silk_sample_requested() and Global.silk_workshop.bolts > 0:
		for resident in Global.retainers:
			if resident.name == VisitorData.SILK_MERCHANT:
				hud.visitor_label.text += "\n样绸 · 可到%s找陶辛。" % world.duty_place(resident)
				return
		hud.visitor_label.text += "\n样绸 · 留一匹绸给西廊的陶辛。"
	elif Global.knows_ravine_journal() and Global.ravine_journal.garden_day == 0:
		hud.visitor_label.text += "\n" + Global.ravine_status()

func _on_manage_pressed() -> void:
	world.set_channel_mode(false)
	panel_manager.toggle_management_panel()

func _on_raid_alert_pressed() -> void:
	if Global.raid_day > 0:
		directions.follow_raid()
	else:
		_show_night_rations()

func _show_night_rations() -> void:
	if Global.outcome != Global.Outcome.RUNNING or world.player.conversation_open or (sleep_tween and sleep_tween.is_running()):
		return
	world.set_channel_mode(false)
	panel_manager.hide_settings_panel()
	var panel := NIGHT_RATIONS_PANEL.instantiate()
	var player: Player = world.player
	player.conversation_open = true
	$Control.add_child(panel)
	GameEvents.modal_visibility_changed.emit(true)
	panel.market_requested.connect(_show_market)
	panel.dry_plot_requested.connect(_on_dry_plot_requested.bind(panel))
	panel.sleep_requested.connect(func():
		panel_manager.hide_management_panel()
		_on_sleep_pressed()
	)
	panel.tree_exited.connect(func():
		GameEvents.modal_visibility_changed.emit(false)
		if is_instance_valid(player):
			player.conversation_open = false
	)

func _on_dry_plot_requested(panel: Control) -> void:
	var cell: Variant = world.find_dry_plot()
	if cell != null:
		directions.follow_dry_plot(cell)
		panel_manager.hide_management_panel()
		panel.queue_free()
		if Global.is_indoors():
			hud.practice_label.text = "已标出待浇田 · 从南门回田边"

func _on_silk_shed_directions_requested() -> void:
	var shed := world.get_node("SilkShed") as Node2D
	if shed.visible:
		var yard := shed.get_node("Yard") as Marker2D
		directions.follow_place("蚕棚", world.to_local(yard.global_position))
		panel_manager.hide_management_panel()
		if Global.is_indoors():
			hud.practice_label.text = "已标出蚕棚 · 从南门回封地"

func _show_market() -> void:
	panel_manager.show_management_panel()
	panel_manager.management_panel_instance.show_market()

func _show_reclamation_market(site: Variant) -> void:
	_show_market()
	panel_manager.management_panel_instance.market_panel.show_reclamation_reserve(_on_reclaim_pressed.bind(site))

func _on_west_market_directions_requested() -> void:
	world.set_channel_mode(false)
	directions.follow_place("西市", world.get_node("WestMarketGate").position)
	panel_manager.hide_management_panel()
	if Global.is_indoors():
		hud.practice_label.text = "已标出西市 · 从南门回封地"

func _on_ravine_trip_requested(place: String) -> void:
	world.set_channel_mode(false)
	directions.follow_ravine(place)
	panel_manager.hide_management_panel()
	if Global.is_indoors():
		hud.practice_label.text = "已标出东关 · 从南门回封地"

func _on_pinned_order_pressed() -> void:
	if Global.can_deliver_season_order(Global.season_order()):
		_on_west_market_directions_requested()
	else:
		_on_season_board_interacted()

func _on_season_board_interacted() -> void:
	world.set_channel_mode(false)
	panel_manager.show_management_panel()
	panel_manager.management_panel_instance.show_season_orders()

func _on_road_rest_interacted() -> void:
	world.set_channel_mode(false)
	dialog_manager.show_road_rest()

func _on_freight_arrival_interacted(speech: String, portrait: Texture2D) -> void:
	world.set_channel_mode(false)
	dialog_manager.show_freight_arrival(speech, portrait, _guide_travel_hearth)

func _guide_travel_hearth() -> void:
	var approach := world.get_node("TravelHearth/Approach") as Marker2D
	directions.follow_place("南路灶台", world.to_local(approach.global_position))

func _guide_calendar_event(place: String) -> void:
	if place == SummerRaft.PLACE:
		directions.follow_ravine(place)
		return
	var path := "SpringGathering"
	match place:
		"秋社展台": path = "AutumnExhibit/Approach"
		WinterSupper.PLACE: path = "WinterSupper/Approach"
	var destination := world.get_node(path) as Node2D
	directions.follow_place(place, world.to_local(destination.global_position))

func _on_winter_supper_requested() -> void:
	world.set_channel_mode(false)
	if directions.tracked_place == WinterSupper.PLACE:
		directions.clear_tracking()
	dialog_manager.show_winter_supper()

func _on_autumn_exhibit_requested() -> void:
	world.set_channel_mode(false)
	if directions.tracked_place == "秋社展台":
		directions.clear_tracking()
	autumn_exhibit_panel.open_map()

func _on_autumn_guest_interacted(guest: Node2D) -> void:
	directions.arrive_at(guest.speaker)
	world.set_channel_mode(false)
	dialog_manager.show_autumn_guest(guest)

func _on_sheepfold_requested() -> void:
	world.set_channel_mode(false)
	if directions.tracked_place == Sheepfold.PLACE:
		directions.clear_tracking()
	sheepfold_panel.open_map()

func _on_travel_hearth_interacted() -> void:
	world.set_channel_mode(false)
	if directions.tracked_place == "南路灶台":
		directions.clear_tracking()
	dialog_manager.show_travel_hearth(_on_west_market_directions_requested)

func _on_neighbors_pressed() -> void:
	world.set_channel_mode(false)
	panel_manager.hide_settings_panel()
	panel_manager.show_management_panel()
	panel_manager.management_panel_instance.show_neighbors()

func _on_neighbor_directions_requested(speaker: String) -> void:
	if directions.follow_neighbor(speaker):
		panel_manager.hide_management_panel()

func _on_reclaim_pressed(previous_site: Variant = null) -> void:
	if ($Control.has_node("ReclamationPanel") or world.player.conversation_open or MapTravel.active
		or (sleep_tween and sleep_tween.is_running()) or Global.outcome != Global.Outcome.RUNNING):
		return
	world.set_channel_mode(false)
	panel_manager.hide_settings_panel()
	panel_manager.hide_management_panel()
	var reclamation_panel = preload("res://scenes/ReclamationPanel.tscn").instantiate()
	$Control.add_child(reclamation_panel)
	reclamation_panel.setup(world, previous_site)
	hud.set_reclamation_mode(true)
	reclamation_panel.tree_exited.connect(func():
		if is_instance_valid(hud):
			hud.set_reclamation_mode(false)
	)
	reclamation_panel.market_requested.connect(_show_reclamation_market)
	reclamation_panel.visitor_requested.connect(_on_neighbor_directions_requested)
	reclamation_panel.worksite_requested.connect(directions.follow_worksite)

func _refresh_worksite_button() -> void:
	hud.worksite_button.visible = world.nearest_worksite() >= 0

func _on_worksite_pressed() -> void:
	var field_id: int = world.nearest_worksite()
	if field_id >= 0:
		world.set_channel_mode(false)
		directions.follow_worksite(field_id)

func _on_settings_pressed() -> void:
	world.set_channel_mode(false)
	panel_manager.toggle_settings_panel()

func _unhandled_key_input(event: InputEvent) -> void:
	var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if OS.is_debug_build() and event.is_action_pressed("ui_toggle_debug") and Preferences.bound_action(code) == &"":
		panel_manager.toggle_debug_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		var management := panel_manager.management_panel_instance
		if is_instance_valid(management) and management.visible:
			panel_manager.hide_management_panel()
			get_viewport().set_input_as_handled()

func _on_sleep_pressed() -> void:
	if MapTravel.active or (sleep_tween and sleep_tween.is_running()):
		return
	world.set_channel_mode(false)
	if Global.tax_council_waiting():
		directions.follow_neighbor(Global.TAX_ENVOY)
		if Global.is_indoors():
			hud.practice_label.text = "从南门出去，到堂前见召简。"
		else:
			GameEvents.world_notice.emit("召简在堂前等候 · 议税后可过夜")
		return
	world.player.resting = true
	fader.mouse_filter = Control.MOUSE_FILTER_STOP
	sleep_tween = create_tween()
	sleep_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	sleep_tween.tween_property(fader, "color:a", 1.0, 0.5)
	sleep_tween.tween_callback(func():
		if Global.outcome != Global.Outcome.RUNNING:
			_clear_fader()
			return
		Global.begin_next_day()
		Global.restore_stamina()
		if Global.outcome != Global.Outcome.RUNNING:
			_clear_fader()
			return
		var promoted := Global.check_rank_up()
		var unfinished := Global.well_fields.filter(func(field: Dictionary) -> bool: return not field["is_unlocked"])
		GameEvents.day_advanced.emit(Global.current_day)
		Global.save_automatically("dawn")
		dawn_caption.text = "第 %d 天 · %s · %s" % [Global.current_day, Global.get_current_solar_term(), Global.day_watch_label()]
		if Global.raid_day == Global.current_day:
			dawn_caption.text += "\n东路来敌 · " + Global.raid_name(Global.raid_kind)
		if promoted:
			dawn_caption.text += "\n晋升%s · 井田上限 %d 块 · 堂屋添了新衣" % [Global.rank_names[Global.current_rank], Global.max_well_fields]
		var completed := PackedStringArray()
		for field in unfinished:
			if field["is_unlocked"]:
				completed.append(str(field["field_id"] + 1))
		if not completed.is_empty():
			dawn_caption.text += "\n井田 %s 已完工 · 可耕种" % "、".join(completed)
		var fields := Global.last_field_night
		var newly_ripe: int = fields.public_ripe + fields.private_ripe
		if newly_ripe > 0:
			dawn_caption.text += "\n新熟 %d 格" % newly_ripe
		var meal := Global.night_rations.last
		if meal.served < meal.need:
			dawn_caption.text += "\n昨夜缺粮 %d 份" % (meal.need - meal.served)
		else:
			var prepared := NightRations.stock_count(meal.used) + int(meal.bought)
			if prepared > 0:
				dawn_caption.text += "\n昨夜备粮 %d 份" % prepared
				if meal.copper > 0:
					dawn_caption.text += " · 用 %d 铜钱" % meal.copper
		if meal.has("supper"):
			dawn_caption.text += "\n围炉供饭 %d 份" % meal.supper
		dawn_caption.modulate.a = 1.0
		dawn_caption.show()
	)
	sleep_tween.tween_property(fader, "color:a", 0.0, 0.5)
	sleep_tween.parallel().tween_property(dawn_caption, "modulate:a", 0.0, 0.40).set_delay(0.10)
	sleep_tween.tween_callback(_clear_fader)

func _clear_fader() -> void:
	world.player.resting = false
	fader.color.a = 0.0
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dawn_caption.hide()

func _on_save_finished(result: Error, automatic: bool) -> void:
	if result == OK:
		var action := "已自动保存" if automatic else "已手动保存"
		hud.show_save_notice("%s · 第 %d 天" % [action, Global.current_day])
	elif automatic:
		hud.show_save_notice("自动保存失败 · 可尝试手动保存", true)
