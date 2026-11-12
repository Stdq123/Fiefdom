extends Control

signal market_requested
signal duties_requested
signal dry_plot_requested
signal harvest_requested
signal tribute_field_requested
signal sleep_requested

const GOOD := Color("#c7dcaf")
const SHORT := Color("#efbf8a")
const WINDOW_MARGIN := 16.0

@onready var window: PanelContainer = $Center/Window
@onready var content: VBoxContainer = $Center/Window/Content
@onready var header: HBoxContainer = $Center/Window/Content/Header
@onready var grain: Label = %Grain
@onready var need: Label = %Need
@onready var money: Label = %Money
@onready var raid_plan: PanelContainer = %RaidPlan
@onready var raid_heading: Label = %RaidHeading
@onready var raid_instructions: Label = %RaidInstructions
@onready var tribute_plan: PanelContainer = %TributePlan
@onready var tribute_deadline: Label = %TributeDeadline
@onready var tribute_details: Label = %TributeDetails
@onready var tribute_goal: Label = %TributeGoal
@onready var find_tribute: Button = %FindTribute
@onready var field_forecast: Label = %FieldForecast
@onready var field_warning: Label = %FieldWarning
@onready var sheep_note: Label = %SheepNote
@onready var silk_note: Label = %SilkNote
@onready var find_plot: Button = %FindPlot
@onready var delegate: CheckButton = %Delegate
@onready var budget: SpinBox = %Budget
@onready var partial_meals: CheckButton = %PartialMeals
@onready var research_fee: Label = %ResearchFee
@onready var forecast: Label = %Forecast
@onready var keep: Label = %Keep
@onready var priority_row: HBoxContainer = %PriorityRow
@onready var priority_picker: OptionButton = %Priority
@onready var meal_forecast: Label = %MealForecast
@onready var duties_button: Button = %Duties
@onready var last_card: PanelContainer = %LastCard
@onready var receipt: Label = %Receipt
@onready var field_receipt: Label = %FieldReceipt
@onready var silk_receipt: Label = %SilkReceipt
@onready var milestones: Label = %Milestones
@onready var find_harvest: Button = %FindHarvest
@onready var title: Label = %Title
@onready var page_button: Button = %PageButton
@onready var plan_body: VBoxContainer = %Plan
@onready var footer: HBoxContainer = %Footer
@onready var close_button: Button = %Close
@onready var scroll: ScrollContainer = %Scroll
@onready var body: VBoxContainer = %Body

var show_previous := false

func _ready() -> void:
	budget.max_value = NightRations.MAX_COPPER_LIMIT
	budget.get_line_edit().max_length = 10
	delegate.toggled.connect(_change_policy.unbind(1))
	budget.value_changed.connect(_change_policy.unbind(1))
	partial_meals.toggled.connect(_change_policy.unbind(1))
	priority_picker.item_selected.connect(_select_priority)
	body.minimum_size_changed.connect(_fit_body)
	get_viewport().size_changed.connect(_fit_body)
	close_button.pressed.connect(queue_free)
	find_plot.pressed.connect(dry_plot_requested.emit)
	find_harvest.pressed.connect(harvest_requested.emit)
	find_tribute.pressed.connect(tribute_field_requested.emit)
	page_button.pressed.connect(func(): _show_page(not show_previous))
	%Market.pressed.connect(func():
		queue_free()
		market_requested.emit()
	)
	duties_button.pressed.connect(func():
		queue_free()
		duties_requested.emit()
	)
	%Sleep.pressed.connect(func():
		queue_free()
		sleep_requested.emit()
	)
	GameEvents.night_rations_changed.connect(_refresh)
	GameEvents.sheepfold_changed.connect(_refresh)
	GameEvents.silk_changed.connect(_refresh)
	GameEvents.food_changed.connect(_refresh.unbind(1))
	GameEvents.money_changed.connect(_refresh.unbind(1))
	GameEvents.inventory_changed.connect(_refresh.unbind(1))
	GameEvents.retainer_recruited.connect(_refresh.unbind(1))
	GameEvents.retainer_departed.connect(_refresh.unbind(1))
	GameEvents.retainer_duty_changed.connect(_refresh.unbind(1))
	GameEvents.farm_state_changed.connect(_refresh_fields)
	GameEvents.crop_harvested.connect(_refresh_fields.unbind(1))
	GameEvents.channels_changed.connect(_refresh_fields)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.raid_started.connect(_refresh_raid_plan)
	GameEvents.raid_defeated.connect(_refresh_raid_plan)
	_refresh()
	_show_page(show_previous)
	close_button.grab_focus()

func _show_page(previous: bool) -> void:
	show_previous = previous
	title.text = "昨夜结算" if previous else "今夜安排"
	page_button.text = "今夜安排" if previous else "昨夜结算"
	plan_body.visible = not previous
	footer.visible = not previous
	_refresh_fields()
	scroll.set_deferred("scroll_vertical", 0)
	_fit_body.call_deferred()

func _fit_body() -> void:
	var separation := content.get_theme_constant("separation")
	var frame_height := window.get_theme_stylebox("panel").get_minimum_size().y \
		+ header.get_combined_minimum_size().y + separation
	if footer.visible:
		frame_height += footer.get_combined_minimum_size().y + separation
	var height := maxf(0.0, get_viewport_rect().size.y - WINDOW_MARGIN * 2.0 - frame_height)
	scroll.custom_minimum_size.y = minf(body.get_combined_minimum_size().y, height)

func _change_policy() -> void:
	Global.set_night_rations(delegate.button_pressed, int(budget.value), partial_meals.button_pressed)

func _select_priority(index: int) -> void:
	Global.set_ration_priority(priority_picker.get_item_metadata(index) as RetainerData)

func _refresh() -> void:
	_refresh_raid_plan()
	_refresh_fields()
	sheep_note.visible = Global.sheepfold.owned()
	if sheep_note.visible:
		var feed := Global.sheep_feed(Global.sheepfold.fodder)
		sheep_note.text = "羊棚 · " + Sheepfold.FEED_LABELS[feed]
		sheep_note.modulate = SHORT if feed == Sheepfold.Feed.SHORTAGE else GOOD
	var plan := Global.night_rations_plan()
	var silk_forecast := Global.silk_night_summary(plan.fed)
	silk_note.visible = not silk_forecast.is_empty()
	silk_note.text = "蚕棚 · " + silk_forecast
	var policy := Global.night_rations
	grain.text = "粮仓\n%d 份" % Global.food_storage
	need.text = "今夜所需\n%d 份" % plan.need
	money.text = "铜钱\n%d 枚" % Global.money
	delegate.set_pressed_no_signal(policy.enabled)
	budget.set_value_no_signal(policy.copper_limit)
	budget.editable = policy.enabled
	partial_meals.visible = policy.enabled
	partial_meals.set_pressed_no_signal(policy.partial_meals)
	research_fee.visible = plan.research_fee > 0
	if research_fee.visible:
		var due: int = plan.research_fee
		research_fee.modulate = GOOD if plan.research_reserve > 0 else SHORT
		research_fee.text = ("明早预留 %d 铜钱缴研究费。" % due if plan.research_reserve > 0
			else "明早研究费 %d 铜钱 · 备粮后还差 %d" % [due, due - Global.money + int(plan.copper)])
	forecast.add_theme_color_override("font_color", SHORT if plan.uncovered > 0 else GOOD)
	var supplement: int = plan.converted + plan.bought
	if plan.need == 0:
		forecast.text = "今夜暂无门客用粮。"
	elif plan.supper == plan.need:
		forecast.text = "今夜口粮由围炉供齐，共 %d 份。" % plan.supper
	elif plan.missing == 0:
		forecast.text = "粮仓够用，今夜从粮仓取 %d 份。" % (plan.need - plan.supper)
	elif not policy.enabled:
		forecast.text = "今夜缺 %d 份。可到市集备粮，或开启夜间备粮。" % plan.missing
	elif supplement > 0:
		var action := "先补" if plan.uncovered > 0 else "补足"
		forecast.text = "今夜%s %d 份 · %s" % [action, supplement, _describe_exchange(plan)]
	else:
		var rule := "补粮按门客整份口粮结算。" if policy.partial_meals else "凑齐才执行夜间备粮。"
		forecast.text = "今夜还差 %d 份。%s" % [plan.uncovered, rule]
	if plan.supper > 0 and plan.supper < plan.need:
		forecast.text = "围炉供 %d 份。%s" % [plan.supper, forecast.text]
	var reserved := ItemManager.describe_crops(plan.reserved)
	keep.visible = policy.enabled and (not reserved.is_empty() or plan.new_order)
	if not reserved.is_empty():
		keep.text = "%s「%s」留货 · %s" % ["明日" if plan.new_order else "", plan.order_name, reserved]
	else:
		keep.text = "明日换季，按「%s」留货。" % plan.order_name
	_refresh_meal(plan)
	var meal := policy.last
	receipt.visible = not meal.is_empty()
	if receipt.visible:
		receipt.text = "第 %d 夜 · 用粮 %d/%d 份" % [meal.day, meal.served, meal.need]
		if meal.has("supper"):
			receipt.text += " · 围炉 %d 份" % meal.supper
		var exchange := _describe_exchange(meal)
		if not exchange.is_empty():
			receipt.text += "\n" + exchange
		elif meal.served < meal.need:
			receipt.text += " · 缺 %d 份" % (meal.need - meal.served)
		var missed: PackedStringArray = meal.get("missed", PackedStringArray())
		var departed: PackedStringArray = meal.get("departed", PackedStringArray())
		if not missed.is_empty():
			receipt.text += "\n缺餐 · " + "、".join(missed)
		if not departed.is_empty():
			receipt.text += "\n已离任 · " + "、".join(departed)
	_refresh_field_receipt()
	var last_silk := Global.silk_workshop.last_work_summary()
	silk_receipt.visible = not last_silk.is_empty()
	silk_receipt.text = "昨夜蚕棚 · " + last_silk
	milestones.text = "\n".join(Global.dawn_milestones())
	milestones.visible = not milestones.text.is_empty()
	last_card.visible = receipt.visible or field_receipt.visible or silk_receipt.visible or milestones.visible
	page_button.visible = last_card.visible

func _refresh_meal(plan: Dictionary) -> void:
	var short: bool = not plan.missed.is_empty()
	var preferred := Global.night_rations.priority
	priority_row.visible = preferred != null or (short and plan.served > 0 and Global.retainers.size() > 1)
	if priority_row.visible:
		priority_picker.clear()
		priority_picker.add_item("按留任顺序")
		priority_picker.select(0)
		for worker in Global.retainers:
			var index := priority_picker.item_count
			priority_picker.add_item("%s · %d 份" % [worker.name, Global.retainer_night_ration(worker)])
			priority_picker.set_item_metadata(index, worker)
			if worker == preferred:
				priority_picker.select(index)
	duties_button.visible = short and plan.need > Global.retainers.size()
	meal_forecast.visible = short
	if not short:
		return
	var lines := PackedStringArray(["预计用粮 %d/%d 份" % [plan.served, plan.need]])
	if not plan.fed.is_empty():
		lines[0] += " · 领足 " + _retainer_names(plan.fed)
	lines.append("缺餐 · %s · 忠诚 −%d" % [_retainer_names(plan.missed), int(NightRations.MISSED_MEAL_LOYALTY)])
	var leaving: Array = plan.missed.filter(func(worker: RetainerData) -> bool:
		return worker.loyalty <= NightRations.MISSED_MEAL_LOYALTY
	)
	if not leaving.is_empty():
		lines.append("预计离任 · " + _retainer_names(leaving))
	var grain_left := Global.food_storage + int(plan.converted) + int(plan.bought) - maxi(0, int(plan.served) - int(plan.supper))
	if grain_left > 0:
		lines.append("粮仓将余 %d 份，留待下次分餐。" % grain_left)
	var work := PackedStringArray()
	for worker: RetainerData in plan.fed:
		if worker.duty == RetainerData.Duty.TEACH:
			work.append(worker.name + "可教习")
		elif worker.duty == RetainerData.Duty.REEL and Global.silk_workshop.night_reeling:
			work.append(worker.name + "可夜缫丝")
	if not work.is_empty():
		lines.append(" · ".join(work))
	meal_forecast.text = "\n".join(lines)

func _retainer_names(roster: Array) -> String:
	return "、".join(PackedStringArray(roster.map(func(worker: RetainerData) -> String: return worker.name)))

func _refresh_raid_plan() -> void:
	var tomorrow := Global.current_day + 1
	var active := Global.raid_day > 0
	raid_plan.visible = active or Global.is_raid_day(tomorrow)
	if not raid_plan.visible:
		return
	raid_heading.text = "东路来敌 · " + Global.raid_name(Global.raid_kind) if active else "明日有敌袭"
	if not active and Global.east_watch_day > 0:
		raid_heading.text += " · " + Global.raid_name(Global.raid_kind_on(tomorrow))
	var instructions := "右键朝来敌射箭，侧走避开地面标记。"
	if not active:
		instructions = "过夜前可先收成熟作物。" + instructions
	if Global.retainers.any(func(worker: RetainerData) -> bool: return worker.can_take_duty(RetainerData.Duty.GUARD)):
		instructions += "\n可在「管理」中安排兵家门客守卫。"
	raid_instructions.text = instructions

func _refresh_fields() -> void:
	_refresh_tribute()
	var report := Global.field_night_forecast()
	field_forecast.text = "已有 %d 格可收 · 今夜预计 %d 格生长" % [
		report.ready, report.growing + report.public_ripe + report.private_ripe]
	var ripe := _describe_ripe(report)
	if not ripe.is_empty():
		field_forecast.text += "\n明早新熟 · " + ripe
	var away_jobs := Global.away_field_summary(Global.AWAY_FIELD_JOBS)
	if not away_jobs.is_empty():
		field_forecast.text += "\n外出田务 · " + away_jobs
		var away_yields := Global.away_field_summary(Global.AWAY_FIELD_YIELDS)
		if not away_yields.is_empty():
			field_forecast.text += "\n" + away_yields
	var warnings := PackedStringArray()
	if report.dry > 0:
		warnings.append("%d 格待浇，缺水会停长" % report.dry)
	if report.blocked > 0:
		warnings.append("%d 格稻田断水，需接通水渠" % report.blocked)
	field_warning.text = " · ".join(warnings)
	field_warning.visible = not warnings.is_empty()
	find_plot.visible = report.dry > 0
	find_harvest.visible = show_previous and report.ready > 0

func _refresh_tribute() -> void:
	var due := Global.tribute_deadline()
	tribute_plan.visible = due > 0
	if not tribute_plan.visible:
		return
	var field := Global.tribute_field_plan()
	var tonight := due == Global.current_day
	var late_crop: bool = not field.is_empty() and field.ready_day > due
	tribute_deadline.text = "公田纳贡 · 今夜到期" if tonight else "公田纳贡 · 第 %d 天过夜前" % due
	if Global.tribute_overdue():
		tribute_deadline.text = "公田纳贡 · 已逾期"
	tribute_deadline.add_theme_color_override("font_color", SHORT if tonight or late_crop else GOOD)
	tribute_goal.visible = not Global.quest_completed
	tribute_goal.text = "累计纳贡 %d/%d · 达标得 %d 声望" % [
		Global.quest_progress, Global.quest_target, Global.TRIBUTE_QUEST_REPUTATION]
	find_tribute.visible = not field.is_empty()
	tribute_details.text = "收割公田后，作物入国库，期限重新计算。"
	if not field.is_empty():
		_describe_tribute_field(field)
	var penalty := Global.tribute_penalty_tonight()
	if penalty > 0:
		tribute_details.text += "\n若今夜仍无纳贡，声望 −%d。" % penalty
		if Global.reputation - penalty <= Global.balance.rank_strip_threshold:
			tribute_details.text += "将失去封地。" if Global.current_rank == Global.Rank.XIA_SHI else "将被削爵。"
	elif late_crop and Global.balance.no_contribution_penalty > 0:
		tribute_details.text += "\n这茬赶不上期限。欠贡将扣 %d 点声望。" % Global.balance.no_contribution_penalty

func _describe_tribute_field(field: Dictionary) -> void:
	var name := "井田 %d 的%s" % [field.field, field.crop]
	var growth := "每夜供水，最早第 %d 天可收。" % field.ready_day
	match field.status:
		Global.NightGrowth.READY:
			tribute_details.text = "%s已熟。收下即可纳贡。" % name
			find_tribute.text = "找熟公田"
		Global.NightGrowth.BLOCKED:
			tribute_details.text = "%s需接通水渠。%s" % [name, growth]
			find_tribute.text = "找断水公田"
		Global.NightGrowth.DRY:
			tribute_details.text = "%s今天待浇。%s" % [name, growth]
			find_tribute.text = "找待浇公田"
		-1:
			tribute_details.text = "若今天在井田 %d 播%s并逐夜供水，最早第 %d 天可收。" % [field.field, field.crop, field.ready_day]
			find_tribute.text = "选%s并指路" % field.crop
		_:
			tribute_details.text = "%s已有水。%s" % [name, growth]
			find_tribute.text = "标出公田"

func _refresh_field_receipt() -> void:
	var report := Global.last_field_night
	var details := PackedStringArray()
	if not report.is_empty():
		var ripe := _describe_ripe(report)
		if not ripe.is_empty():
			details.append("新熟 " + ripe)
		if report.growing > 0:
			details.append("%d 格长了一阶" % report.growing)
		if report.dry > 0:
			details.append("%d 格漏浇停长" % report.dry)
		if report.blocked > 0:
			details.append("%d 格稻田断水停长" % report.blocked)
	field_receipt.visible = not details.is_empty()
	if field_receipt.visible:
		field_receipt.text = "第 %d 夜田务 · %s" % [report.day, " · ".join(details)]

func _describe_ripe(report: Dictionary) -> String:
	if report.public_ripe + report.private_ripe == 0:
		return ""
	return "公田 %d 格、私田 %d 格" % [report.public_ripe, report.private_ripe]

func _describe_exchange(plan: Dictionary) -> String:
	var details := PackedStringArray()
	if not plan.used.is_empty():
		details.append("转用 %s" % ItemManager.describe_crops(plan.used))
	if plan.bought > 0:
		details.append("购粮 %d 份（%d 铜钱）" % [plan.bought, plan.copper])
	return " · ".join(details)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
