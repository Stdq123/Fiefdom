extends "res://scripts/SurveyMap.gd"

signal action_requested(kind: Global.RouteGoal)
signal filing_requested()

const GOAL_ROW := preload("res://scenes/RouteGoalRow.tscn")
const LEDGER_DESK := preload("res://scripts/RouteLedgerDesk.gd")
const LEDGER_MARGIN := 20.0
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
		"unit": "次",
	},
}

@onready var ledger: PanelContainer = %Ledger
@onready var stack: VBoxContainer = %Stack
@onready var header: HBoxContainer = %Header
@onready var volume: TextureRect = %Volume
@onready var heading: Label = %RouteTitle
@onready var summary: Label = %RouteSummary
@onready var scroll: ScrollContainer = %ReadScroll
@onready var body: VBoxContainer = %Body
@onready var harvest_record: VBoxContainer = %HarvestRecord
@onready var harvest_entry: Label = %HarvestEntry
@onready var rows: VBoxContainer = %GoalRows
@onready var filing_bar: HBoxContainer = %FilingBar
@onready var filing: Label = %Filing
@onready var follow_filing: Button = %FollowFiling

var world: Node2D

func _ready() -> void:
	super._ready()
	for control: Control in [summary, harvest_entry, filing, follow_filing]:
		InterfaceFont.scale_reading_text(control)
	follow_filing.pressed.connect(_request_filing)
	var bar := PANEL_FOCUS.reading_scrollbar(scroll)
	bar.theme = preload("res://resources/estate_hud_theme.tres")
	bar.theme_type_variation = &"HudJournalBar"
	for part: Control in [body, header, filing_bar]:
		part.minimum_size_changed.connect(_fit_body, CONNECT_DEFERRED)
	get_viewport().size_changed.connect(_fit_body)

func _map_available() -> bool:
	return Global.ending_record.is_empty() and not Global.route_objectives().is_empty()

func _refresh_on_open() -> void:
	var goals := Global.route_objectives()
	var complete := goals.filter(func(goal: Dictionary) -> bool: return goal.value >= goal.target).size()
	var traditional := Global.tax_reform_choice == Global.TaxReformChoice.TRADITIONAL
	heading.text = "贡簿 · 守礼安邦" if traditional else "新税册 · 税亩富民"
	volume.texture = LEDGER_DESK.volume_texture(traditional)
	summary.text = "已达成 %d/%d 项" % [complete, goals.size()]
	if Global.tax_reform_day > 0:
		summary.text = "第 %d 天定案 · " % Global.tax_reform_day + summary.text
	var entry := Global.route_harvest_note()
	harvest_entry.text = entry
	harvest_record.visible = not entry.is_empty()
	harvest_entry.visible = harvest_record.visible
	var stand := world.get_node("Scenery/EndingRecord")
	var ready := Global.route_ready_to_present()
	follow_filing.visible = ready
	var prompt := "目标齐备 · 到" if ready else "达标后到"
	filing.text = prompt + stand.place_name + "呈交" + stand.record_name
	for row in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	for goal in goals:
		_add_goal(goal)
	scroll.set_deferred("scroll_vertical", 0)
	_fit_body.call_deferred()

func _fit_body() -> void:
	var chrome := ledger.get_theme_stylebox("panel").get_minimum_size().y \
		+ header.get_combined_minimum_size().y + filing_bar.get_combined_minimum_size().y \
		+ stack.get_theme_constant("separation") * 2
	var available := maxf(0.0, get_viewport_rect().size.y - LEDGER_MARGIN * 2.0 - chrome)
	scroll.custom_minimum_size.y = minf(body.get_combined_minimum_size().y, available)

func _add_goal(goal: Dictionary) -> void:
	var row := GOAL_ROW.instantiate() as PanelContainer
	rows.add_child(row)
	var kind: Global.RouteGoal = goal.kind
	var guide: Dictionary = GUIDANCE[kind]
	var complete: bool = goal.value >= goal.target
	row.get_node("%GoalTitle").text = goal.label
	var detail: String = guide.get("detail", "")
	var action_text: String = guide.get("action", "")
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
	elif not complete and kind == Global.RouteGoal.RAIDS:
		var defense := _defense_guide()
		detail = defense.detail
		action_text = defense.action
	var note: Label = row.get_node("%GoalDetail")
	note.text = detail
	note.visible = not complete
	var count: Label = row.get_node("%GoalCount")
	count.text = "%d / %d %s" % [goal.value, goal.target, guide.unit]
	if complete:
		count.text += " · 达成"
		count.add_theme_color_override("font_color", Color("#c5d592"))
	var gap: Label = row.get_node("%GoalGap")
	gap.visible = not complete
	if not complete:
		gap.text = "还差 %d %s" % [goal.target - goal.value, guide.unit]
	for label: Label in [note, count, gap]:
		InterfaceFont.scale_reading_text(label)
	var progress: ProgressBar = row.get_node("%GoalMeter")
	progress.max_value = maxi(1, goal.target)
	progress.value = progress.max_value if complete else goal.value
	var action: Button = row.get_node("%GoalAction")
	action.visible = not complete
	action.text = action_text
	action.pressed.connect(_take_action.bind(kind))

func _defense_guide() -> Dictionary:
	if Global.raid_day > 0:
		return {"action": "标出来敌", "detail": "东路已有%s，可沿标记找到来敌。" % Global.raid_name(Global.raid_kind)}
	var tomorrow := Global.current_day + 1
	var raid := Global.next_raid_day(tomorrow)
	var detail := "预计第 %d 天卯时来敌。" % raid
	if raid == tomorrow:
		detail = "明日卯时来敌（第 %d 天）。" % raid
	var action := "查看守备准备"
	var guard := Global.guard_for_defense()
	if guard and guard.duty == RetainerData.Duty.GUARD:
		detail += "%s已任守卫。" % guard.name
		action = "查看守卫"
	elif guard:
		detail += "可安排%s守卫。" % guard.name
		action = "分派守卫"
	else:
		detail += "可亲自射箭守卫。"
	if raid == tomorrow:
		action = "查看明日守备"
	return {"action": action, "detail": detail}

func _take_action(kind: Global.RouteGoal) -> void:
	close_map()
	action_requested.emit(kind)

func _request_filing() -> void:
	if not Global.route_ready_to_present():
		_refresh_on_open()
		return
	close_map()
	filing_requested.emit()
