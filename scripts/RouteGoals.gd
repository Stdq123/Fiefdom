extends "res://scripts/SurveyMap.gd"

signal action_requested(kind: Global.RouteGoal)

const GOAL_ROW := preload("res://scenes/RouteGoalRow.tscn")
const GUIDANCE := {
	Global.RouteGoal.TRIBUTE: {
		"unit": "份", "action": "查看井田", "detail": "收获井田中央的公田。定案后入国库的作物会记在这里。",
	},
	Global.RouteGoal.TAXED_HARVEST: {
		"unit": "份", "action": "查看井田", "detail": "各格收成按新法计税。定案后收入私仓的作物会记在这里。",
	},
	Global.RouteGoal.OFFER_SILK: {
		"unit": "匹", "action": "打开蚕桑", "detail": "到蚕桑页查看织绸工序。库里已有丝绸时，可直接点「进献」。",
	},
	Global.RouteGoal.SELL_SILK: {
		"unit": "匹", "action": "打开蚕桑", "detail": "到蚕桑页查看织绸工序。库里已有丝绸时，可直接点「出售」。",
	},
	Global.RouteGoal.COPPER: {
		"unit": "铜钱", "action": "打开市场", "detail": "结局以手头余额为准。收获或卖作物可攒钱，支出会减少进度。",
	},
	Global.RouteGoal.RAIDS: {
		"unit": "次", "detail": "累计击退次数。可分派军务门客守卫，或亲自射箭迎敌。",
	},
}

@onready var heading: Label = %RouteTitle
@onready var summary: Label = %RouteSummary
@onready var harvest_entry: Label = %HarvestEntry
@onready var rows: VBoxContainer = %GoalRows

var world: Node2D

func _map_available() -> bool:
	return Global.ending_record.is_empty() and not Global.route_objectives().is_empty()

func _refresh_on_open() -> void:
	var goals := Global.route_objectives()
	var complete := goals.filter(func(goal: Dictionary) -> bool: return goal.value >= goal.target).size()
	heading.text = "贡簿 · 守礼安邦" if Global.tax_reform_choice == Global.TaxReformChoice.TRADITIONAL else "新税册 · 税亩富民"
	summary.text = "已达成 %d/%d 项" % [complete, goals.size()]
	if Global.tax_reform_day > 0:
		summary.text = "第 %d 天定案 · " % Global.tax_reform_day + summary.text
	var entry := Global.route_harvest_note()
	harvest_entry.text = entry
	harvest_entry.visible = not entry.is_empty()
	for row in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	for goal in goals:
		_add_goal(goal)

func _add_goal(goal: Dictionary) -> void:
	var row := GOAL_ROW.instantiate() as PanelContainer
	rows.add_child(row)
	var kind: Global.RouteGoal = goal.kind
	var guide: Dictionary = GUIDANCE[kind]
	var complete: bool = goal.value >= goal.target
	row.get_node("%GoalTitle").text = goal.label
	var detail: String = guide.detail
	var action_text: String = _raid_action() if kind == Global.RouteGoal.RAIDS else guide.action
	if not complete and kind in [Global.RouteGoal.TRIBUTE, Global.RouteGoal.TAXED_HARVEST]:
		var harvest: Dictionary = world.council_harvest_forecast(Global.tax_reform_choice)
		if kind == Global.RouteGoal.TRIBUTE and harvest.tribute > 0:
			detail = "当前熟公田可纳贡 %d 份。" % harvest.tribute
			action_text = "指路收公田"
		elif kind == Global.RouteGoal.TAXED_HARVEST and harvest.stock > 0:
			detail = "当前熟田可入仓 %d 份 · 税后 +%d 铜钱。" % [harvest.stock, harvest.copper]
			action_text = "指路收熟田"
	elif not complete and kind == Global.RouteGoal.COPPER:
		var quote := Global.reform_sale_quote()
		if not quote.is_empty():
			detail = "可售 %d 份余粮 · +%d 铜钱。预留今夜口粮与备好的货。" % [quote.amount, quote.gain]
			action_text = "查看售粮报价"
	elif not complete and kind in [Global.RouteGoal.OFFER_SILK, Global.RouteGoal.SELL_SILK]:
		var bolts := Global.silk_workshop.bolts
		var trade := "进献" if kind == Global.RouteGoal.OFFER_SILK else "出售"
		if bolts > 0:
			detail = "手中已有 %d 匹。到蚕桑页点「%s」，记入本案。" % [bolts, trade]
		else:
			detail = "蚕桑页可查看现有蚕茧和生丝，缺叶时可标出桑田。织成后%s。" % trade
	row.get_node("%GoalDetail").text = detail
	var count: Label = row.get_node("%GoalCount")
	count.text = "%d / %d %s" % [goal.value, goal.target, guide.unit]
	if complete:
		count.text += " · 达成"
		count.add_theme_color_override("font_color", Color("#c5d592"))
	var progress: ProgressBar = row.get_node("%GoalMeter")
	progress.max_value = maxi(1, goal.target)
	progress.value = progress.max_value if complete else goal.value
	var action: Button = row.get_node("%GoalAction")
	action.visible = not complete
	action.text = action_text
	action.pressed.connect(_take_action.bind(kind))

func _raid_action() -> String:
	if Global.raid_day > 0:
		return "标出来敌"
	if Global.is_raid_day(Global.current_day + 1):
		return "查看明日守备"
	return "分派守卫"

func _take_action(kind: Global.RouteGoal) -> void:
	close_map()
	action_requested.emit(kind)
