extends "res://scripts/SurveyMap.gd"

signal fields_requested()
signal public_plot_requested()
signal six_arts_requested()
signal silk_requested()
signal orders_requested()
signal sowing_plans_requested(field_id: int)

const READY := Color("#c5d592")
const PENDING := Color("#f2bc85")

@onready var date_line: Label = %DateLine
@onready var date_status: Label = %DateStatus
@onready var rank_line: Label = %RankLine
@onready var rank_status: Label = %RankStatus
@onready var contribution: Label = %Contribution
@onready var account: Label = %Account
@onready var contribution_status: Label = %ContributionStatus
@onready var petition_card: PanelContainer = %PetitionCard
@onready var petition_heading: Label = %PetitionHeading
@onready var petition_detail: Label = %PetitionDetail
@onready var orders_button: Button = %OrdersButton
@onready var petition_button: Button = %PetitionButton
@onready var preview_heading: Label = %PreviewHeading
@onready var public_card: PanelContainer = %PublicCard
@onready var public_preview: Label = %PublicPreview
@onready var public_result: Label = %PublicResult
@onready var mixed_card: PanelContainer = %MixedCard
@onready var mixed_title: Label = %MixedTitle
@onready var mixed_preview: Label = %MixedPreview
@onready var mixed_result: Label = %MixedResult
@onready var harvest_policy: HBoxContainer = %HarvestPolicy
@onready var harvest_policy_note: Label = %HarvestPolicyNote
@onready var harvest_policy_button: Button = %HarvestPolicyButton
@onready var tribute_rows_button: Button = %TributeRowsButton
@onready var public_plan_card: PanelContainer = %PublicPlanCard
@onready var public_plan_title: Label = %PublicPlanTitle
@onready var public_plan_detail: Label = %PublicPlanDetail
@onready var public_plan_button: Button = %PublicPlanButton
@onready var field_button: Button = %FieldButton
@onready var sowing_note: Label = %SowingNote
@onready var sowing_button: Button = %SowingButton
@onready var arts_button: Button = %ArtsButton
@onready var silk_stock: Label = %SilkStock
@onready var silk_button: Button = %SilkButton

var world: Node2D
var sowing_field_id := -1

func _ready() -> void:
	super()
	field_button.pressed.connect(func():
		close_map()
		fields_requested.emit())
	public_plan_button.pressed.connect(func():
		close_map()
		public_plot_requested.emit())
	sowing_button.pressed.connect(func():
		close_map()
		sowing_plans_requested.emit(sowing_field_id))
	harvest_policy_button.pressed.connect(func():
		Global.set_private_harvest_hold(not Global.hold_private_harvest)
		_refresh_harvest_policy())
	tribute_rows_button.pressed.connect(func():
		Global.set_council_tribute_rows(not Global.council_tribute_rows)
		_refresh_on_open())
	arts_button.pressed.connect(func():
		close_map()
		six_arts_requested.emit())
	silk_button.pressed.connect(func():
		close_map()
		silk_requested.emit())
	orders_button.pressed.connect(func():
		close_map()
		orders_requested.emit())
	petition_button.pressed.connect(func():
		if EventManager.petition_tax_council():
			close_map())

func _map_available() -> bool:
	return Global.tax_reform_choice == Global.TaxReformChoice.NONE and not Global.tax_council_waiting()

func _refresh_on_open() -> void:
	var opening := Global.tax_council_start_day()
	var nights := maxi(0, opening - Global.current_day)
	date_line.text = "常规会期 · 第 %d 天起" % opening
	date_status.text = "已到议税时日" if nights == 0 else "还需 %d 夜" % nights
	date_status.modulate = READY if nights == 0 else PENDING

	var ranked := Global.current_rank >= Global.Rank.DA_FU
	var current: String = Global.rank_names[Global.current_rank]
	rank_line.text = "当前爵位 · " + current if ranked else "当前%s · 需大夫" % current
	rank_status.text = "爵位已达标" if ranked else Global.promotion_summary()
	if not ranked and Global.eligible_for_promotion():
		rank_status.text += " · 过夜核定"
	rank_status.modulate = READY if ranked else PENDING
	var required_art := Global.balance.upper_rank_art_level
	var highest_art := Global.highest_six_art_level()
	arts_button.visible = Global.current_rank == Global.Rank.ZHONG_SHI and highest_art < required_art
	if arts_button.visible:
		rank_status.text = "晋升上士 · 声望 %d/%d\n任一六艺需 %d 级 · 当前最高 %d 级" % [
			Global.reputation, Global.promotion_reputation(), required_art, highest_art]

	var threshold := String.num(Global.balance.public_field_ratio_threshold * 100.0, 2).trim_suffix(".0")
	contribution.text = "公田贡献 %s · 要求 %s%%" % [
		_percentage(), threshold]
	account.text = "累计纳贡 %d 份 · 累计私田收成 %d 份" % [Global.king_storage, Global.private_harvest_total]
	var gap := Global.tax_council_public_gap()
	_describe_gap(contribution_status, gap)
	_refresh_sowing_plans(gap)
	petition_card.visible = nights > 0
	if petition_card.visible:
		_refresh_petition()

	var totals: Dictionary = world.council_harvest_forecast(Global.TaxReformChoice.NONE)
	var tribute: int = totals.tribute
	var private_yield: int = totals.stock
	public_card.visible = tribute > 0
	mixed_card.visible = private_yield > 0
	preview_heading.text = "眼下没有成熟作物" if totals.plots == 0 else "收下眼前的熟田"
	public_preview.text = "纳贡 +%d 份" % tribute
	_describe_projection(public_result, tribute, 0)
	mixed_title.text = "先收私田，再收公田" if tribute > 0 else "只收熟私田"
	mixed_preview.text = "私仓 +%d · 铜钱 +%d" % [private_yield, totals.copper]
	if tribute > 0:
		mixed_preview.text = "纳贡 +%d · " % tribute + mixed_preview.text
	_describe_projection(mixed_result, tribute, private_yield)
	field_button.text = "指路收公田" if tribute > 0 else "查看井田"
	_refresh_public_plan(gap > 0 and tribute == 0)
	if public_plan_card.visible:
		preview_heading.text = "筹备下次纳贡" if totals.plots == 0 else "筹备纳贡与收成"
	_refresh_harvest_policy()

	var bolts := Global.silk_workshop.bolts
	var silk_target := Global.balance.ending_silk_target
	silk_stock.text = "备绸 · %d / %d 匹" % [bolts, silk_target]
	silk_stock.modulate = READY if bolts >= silk_target else PENDING
	silk_button.text = "查看蚕桑" if bolts >= silk_target else "准备丝绸"

func _refresh_harvest_policy() -> void:
	var held := Global.hold_private_harvest
	var rows := Global.council_tribute_rows
	tribute_rows_button.visible = Global.can_arrange_council_tribute_rows()
	harvest_policy_button.visible = held or (Global.can_hold_private_harvest()
		and Global.retainers.any(func(worker: RetainerData) -> bool:
			return worker.duty in [RetainerData.Duty.STEWARD, RetainerData.Duty.HARVEST]))
	harvest_policy.visible = harvest_policy_button.visible or tribute_rows_button.visible
	tribute_rows_button.text = "北排恢复私收" if rows else "北排三格纳贡"
	harvest_policy_button.text = "恢复门客收私田" if held else "暂留熟私田"
	harvest_policy_note.modulate = READY if held or rows else Color.WHITE
	if rows:
		harvest_policy_note.text = ("每块井田北排已纳贡，余田仍暂留。" if held
			else "每块井田北排纳贡，余田照收。议税选定后复原。")
	elif held:
		harvest_policy_note.text = "门客暂留熟私田，仍可亲手收。定案后恢复代收。"
	elif tribute_rows_button.visible:
		harvest_policy_note.text = "暂划每块井田北排三格纳贡，另外五格照收。"
	else:
		harvest_policy_note.text = "想先收公田时，可请门客把熟私田留给你。"

func _refresh_public_plan(needs_crop: bool) -> void:
	var plan := Global.tribute_field_plan() if needs_crop else {}
	public_plan_card.visible = not plan.is_empty()
	if plan.is_empty():
		return
	public_plan_title.text = "井田 %d · 公田" % plan.field
	public_plan_button.text = "选种并标出公田" if not plan.seed_id.is_empty() else "标出公田"
	var earliest := "最早第 %d 天可收。" % plan.ready_day
	match plan.status:
		Global.NightGrowth.BLOCKED:
			public_plan_detail.text = "%s缺渠水。接通水渠后才能生长。" % plan.crop
		Global.NightGrowth.DRY:
			public_plan_detail.text = "%s待浇。\n" % plan.crop + earliest
		Global.NightGrowth.READY:
			public_plan_detail.text = "%s已成熟。" % plan.crop
		Global.NightGrowth.GROW, Global.NightGrowth.RIPEN:
			public_plan_detail.text = "%s今夜有水。\n" % plan.crop + earliest
		_:
			public_plan_detail.text = "播%s后供水。\n" % plan.crop + earliest

func _refresh_sowing_plans(gap: int) -> void:
	var private_plans := 0
	var most_in_one_field := 0
	sowing_field_id = -1
	if gap > 0:
		for field in Global.well_fields:
			if not field.is_unlocked:
				continue
			var center: Vector2i = field.center_pos
			var count := 0
			for y in range(-1, 2):
				for x in range(-1, 2):
					var cell := center + Vector2i(x, y)
					if not Global.is_public_plot(cell) and Global.field_seed_plans.has(cell) and not Global.deferred_field_sowing.has(cell):
						count += 1
			private_plans += count
			if count > most_in_one_field:
				most_in_one_field = count
				sowing_field_id = field.field_id
	var deferred := Global.deferred_field_sowing.size()
	sowing_note.visible = private_plans > 0 or deferred > 0
	sowing_button.visible = private_plans > 0
	var notes := PackedStringArray()
	if private_plans > 0:
		notes.append("%d 格私田仍在续播。可暂缓下一茬，保留原定种法。" % private_plans)
	if deferred > 0:
		notes.append("%d 格已暂缓，定案后接续。" % deferred)
	sowing_note.text = " ".join(notes)

func _refresh_petition() -> void:
	var delivered := Global.tax_council_petition_order_count()
	var required := Global.TAX_COUNCIL_PETITION_ORDERS
	var opening := Global.tax_council_petition_day()
	var ready := Global.can_petition_tax_council()
	petition_heading.text = "提前请议 · 第 %d 年交货 %d/%d 季" % [
		Global.TAX_COUNCIL_YEAR - 1, mini(delivered, required), required]
	petition_heading.modulate = READY if ready else Color.WHITE
	orders_button.visible = delivered < required
	petition_button.visible = ready
	if ready:
		petition_detail.text = "递上交货回执后，召简今日到堂前。"
	elif delivered >= required and Global.current_day >= opening:
		var missing := PackedStringArray()
		if Global.current_rank < Global.Rank.DA_FU:
			missing.append("爵位需大夫")
		var gap := Global.tax_council_public_gap()
		if gap > 0:
			missing.append("还差 %d 份纳贡" % gap)
		elif gap < 0:
			missing.append("纳贡占比未达标")
		petition_detail.text = "回执已齐 · " + " · ".join(missing)
	elif Global.current_day < opening:
		petition_detail.text = "第 %d 天起可请议，须达到大夫和纳贡门槛。" % opening
	else:
		petition_detail.text = "交齐两季时令单、爵位和纳贡达标后，即可请议。"

func _percentage(public_yield := 0, private_yield := 0) -> String:
	return "%.2f%%" % (Global.public_contribution_ratio(public_yield, private_yield) * 100.0)

func _describe_gap(label: Label, gap: int) -> void:
	label.modulate = READY if gap == 0 else PENDING
	if gap < 0:
		label.text = "按此比例要求，当前账目无法达标"
	else:
		label.text = "纳贡已达标" if gap == 0 else "还差 %d 份纳贡" % gap

func _describe_projection(label: Label, public_yield: int, private_yield: int) -> void:
	_describe_gap(label, Global.tax_council_public_gap(public_yield, private_yield))
	label.text = _percentage(public_yield, private_yield) + " · " + label.text
