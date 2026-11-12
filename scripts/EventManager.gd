extends Node

var event_panel_scene := preload("res://scenes/EventPanel.tscn")
var active_panel: Control

func _ready() -> void:
	GameEvents.day_advanced.connect(_on_day_advanced)
	GameEvents.crop_harvested.connect(_check_progress.unbind(1), CONNECT_DEFERRED)
	GameEvents.money_changed.connect(_check_progress.unbind(1), CONNECT_DEFERRED)
	GameEvents.silk_changed.connect(_check_progress, CONNECT_DEFERRED)
	GameEvents.raid_defeated.connect(_check_progress, CONNECT_DEFERRED)
	get_tree().scene_changed.connect(_check_progress)

func _on_day_advanced(_day: int) -> void:
	if Global.outcome != Global.Outcome.RUNNING:
		return
	if Global.tax_reform_choice == Global.TaxReformChoice.DELAYED:
		_process_research()
	else:
		_check_progress()

func _check_progress() -> void:
	if Global.outcome != Global.Outcome.RUNNING:
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != Global.ESTATE_SCENE:
		return
	match Global.tax_reform_choice:
		Global.TaxReformChoice.NONE:
			invite_if_eligible()
		Global.TaxReformChoice.DELAYED:
			return
		_:
			for goal in Global.route_objectives():
				if goal["value"] < goal["target"]:
					return
			var ending := Global.Outcome.TRADITIONAL if Global.tax_reform_choice == Global.TaxReformChoice.TRADITIONAL else Global.Outcome.REFORMED
			Global.finish_campaign(ending)

func invite_if_eligible() -> void:
	if Global.tax_reform_choice != Global.TaxReformChoice.NONE or Global.tax_council_invited:
		return
	if Global.current_day < Global.tax_council_start_day() or Global.current_rank < Global.Rank.DA_FU:
		return
	if Global.king_storage > 0 and Global.public_contribution_ratio() >= Global.balance.public_field_ratio_threshold:
		Global.tax_council_invited = true
		GameEvents.tax_reform_triggered.emit()

func _process_research() -> void:
	var elapsed := Global.current_day - Global.tax_reform_day
	if elapsed <= 0 or Global.research_choice_pending:
		return
	if elapsed % Global.research_payment_interval() == 0:
		var cost := Global.balance.research_monthly_cost
		if Global.money < cost:
			Global.research_choice_pending = true
			GameEvents.tax_reform_triggered.emit()
			return
		Global.money -= cost
		GameEvents.money_changed.emit(Global.money)
	if Global.research_days_remaining() == 0:
		GameEvents.tax_reform_triggered.emit()

func open_tax_council(world: Node, host: Control) -> void:
	if is_instance_valid(active_panel) or not Global.tax_council_waiting():
		return
	active_panel = event_panel_scene.instantiate()
	active_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(active_panel)
	active_panel.choice_selected.connect(_on_tax_reform_choice, CONNECT_ONE_SHOT)
	active_panel.dismissed.connect(func(): get_tree().paused = false)
	active_panel.tree_exited.connect(func(): GameEvents.modal_visibility_changed.emit(false))
	active_panel.setup(_event_data(world, Global.tax_reform_choice == Global.TaxReformChoice.DELAYED))
	GameEvents.modal_visibility_changed.emit(true)
	get_tree().paused = true

func _event_data(world: Node, final_choice: bool) -> Dictionary:
	var finished_fields := 0
	var public_plots := 0
	for field in Global.well_fields:
		if field["is_unlocked"]:
			finished_fields += 1
			public_plots += int(Global.is_public_plot(field["center_pos"]))
	var levy_rate := clampf(Global.balance.reformed_tax_rate, 0.0, 1.0)
	var percentage := String.num(levy_rate * 100.0, 2)
	if "." in percentage:
		percentage = percentage.rstrip("0").trim_suffix(".")
	var reform := Global.TaxReformChoice.REFORMED
	var tradition := Global.TaxReformChoice.TRADITIONAL
	var choices := [
		{
			"text": "支持改革",
			"choice_type": reform,
			"levy": "%d 格公田转为私田，收成入私仓。每份作物的铜钱收入扣税 %s%%。" % [public_plots, percentage],
			"harvest": _describe_harvest(world.council_harvest_forecast(reform)),
			"household": _retainer_preview(reform),
			"heading": "结局 · 税亩富民",
			"detail": _goal_preview(reform),
		},
		{
			"text": "坚守传统",
			"choice_type": tradition,
			"levy": "%d 格公田继续纳贡。私田收成入仓，铜钱按原价结算。" % public_plots,
			"harvest": _describe_harvest(world.council_harvest_forecast(tradition)),
			"household": _retainer_preview(tradition),
			"heading": "结局 · 守礼安邦",
			"detail": _goal_preview(tradition),
		}
	]
	if not final_choice:
		choices.append(_research_preview(choices[1]["harvest"]))
	var greeting := "国君问起今后的田赋。请卿看看这份收成账，再作决定。"
	if final_choice:
		var shortage := Global.balance.research_monthly_cost - Global.money
		if Global.research_choice_pending:
			greeting = ("这笔研究经费还差 %d 铜钱。请卿今日定下田赋。" % shortage if shortage > 0 else
				"研究经费未能如期缴清。请卿今日定下田赋。")
		else:
			greeting = "一年研究期满。请卿定下采邑今后的田赋。"
	return {
		"title": "国君密诏 · 初税亩",
		"speaker": "国君使者 · 召简",
		"text": greeting,
		"ledger": "井田 %d 块 · 公田 %d 格    国库 %d 份 · 私仓 %d 份 · 粮仓 %d 份 · 铜钱 %d" % [
			finished_fields, public_plots, Global.king_storage, Global.player_inventory, Global.food_storage, Global.money],
		"choices": choices,
	}

func _describe_harvest(result: Dictionary) -> String:
	if result["plots"] == 0:
		return "当前暂无成熟作物。"
	var leaves := " · 桑叶 +%d" % result["leaves"] if result["leaves"] > 0 else ""
	return "收齐已熟 %d 格\n国库 +%d · 私仓 +%d\n铜钱 +%d%s" % [
		result["plots"], result["tribute"], result["stock"], result["copper"], leaves]

func _goal_preview(choice: Global.TaxReformChoice) -> String:
	var lines := PackedStringArray()
	for goal in Global.route_objectives(choice):
		lines.append("%s %d/%d" % [goal["label"], mini(goal["value"], goal["target"]), goal["target"]])
	return " · ".join(lines.slice(0, 2)) + "\n" + " · ".join(lines.slice(2))

func _loyalty_after_choice(retainer: RetainerData, choice: Global.TaxReformChoice) -> float:
	var balance := Global.balance
	var change := balance.tax_reform_legalist_loyalty_change if choice == Global.TaxReformChoice.REFORMED else balance.tax_reform_confucian_loyalty_change
	return clampf(retainer.loyalty + change, 0.0, 100.0)

func _retainer_preview(choice: Global.TaxReformChoice) -> String:
	var balance := Global.balance
	var reformed := choice == Global.TaxReformChoice.REFORMED
	var food := Global.retainer_food_cost()
	var departures := PackedStringArray()
	if reformed:
		for retainer in Global.retainers:
			if retainer.school == RetainerData.School.CONFUCIAN and _loyalty_after_choice(retainer, choice) == 0.0:
				departures.append(retainer.name)
				food -= Global.retainer_night_ration(retainer)
	var text := "周礼 下下 · 儒家忠诚 %+d" % balance.tax_reform_legalist_loyalty_change if reformed else (
		"周礼 上上 · 儒家、墨家忠诚 %+d" % balance.tax_reform_confucian_loyalty_change)
	var upkeep := "每夜用粮 %d 份" % food
	if not departures.is_empty():
		var names := "、".join(departures.slice(0, 2))
		if departures.size() > 2:
			names += "等 %d 人" % departures.size()
		upkeep = "%s将离开 · %s" % [names, upkeep]
	return text + "\n" + upkeep

func _research_preview(harvest: String) -> Dictionary:
	var duration := maxi(1, Global.balance.days_per_year)
	var interval := Global.research_payment_interval()
	var payments := floori(float(duration) / interval)
	var fee := Global.balance.research_monthly_cost
	var first_payment := "第 %d 天首付" % (Global.current_day + interval)
	if Global.money < fee:
		first_payment += " · 尚差 %d 铜钱" % (fee - Global.money)
	return {
		"text": "暂缓决定",
		"choice_type": Global.TaxReformChoice.DELAYED,
		"levy": "研究期间沿用井田纳贡和私田收成。",
		"harvest": harvest,
		"household": "每夜用粮 %d 份" % Global.retainer_food_cost(),
		"heading": "经费与期限",
		"detail": "每 %d 天缴 %d 铜钱 · 共 %d 笔\n%s\n第 %d 天到期 · 共需 %d 铜钱\n到期或经费不足时定案。" % [
			interval, fee, payments, first_payment, Global.current_day + duration, payments * fee],
	}

func _on_tax_reform_choice(choice: Global.TaxReformChoice) -> void:
	Global.tax_council_invited = false
	Global.research_choice_pending = false
	Global.tax_reform_choice = choice
	Global.tax_reform_year = Global.get_current_year()
	Global.tax_reform_day = Global.current_day
	if choice != Global.TaxReformChoice.DELAYED:
		Global.set_route_baseline()
	match choice:
		Global.TaxReformChoice.REFORMED:
			Global.tax_rate = clampf(Global.balance.reformed_tax_rate, 0.0, 1.0)
			Global.zhou_li_score = "下下"
			Global.days_without_contribution = 0
			for retainer in Global.retainers.duplicate():
				if retainer.school == RetainerData.School.CONFUCIAN:
					retainer.loyalty = _loyalty_after_choice(retainer, choice)
					if retainer.loyalty == 0.0:
						Global.dismiss_retainer(retainer, Global.DepartureReason.REFORM)
		Global.TaxReformChoice.TRADITIONAL:
			Global.tax_rate = 0.0
			Global.zhou_li_score = "上上"
			for retainer in Global.retainers:
				if retainer.school in [RetainerData.School.CONFUCIAN, RetainerData.School.MOHIST]:
					retainer.loyalty = _loyalty_after_choice(retainer, choice)
	GameEvents.tax_reform_choice_made.emit(choice)
	Global.save_automatically("council")
	get_tree().paused = false
