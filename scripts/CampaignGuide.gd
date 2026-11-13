extends Label

enum OpeningCue { NONE, PLOT, SEED, SLEEP }

const ESTATE_WORLD := preload("res://scripts/World.gd")

@onready var heading: Label = %GuideHeading
@onready var route_progress: Button = %RouteProgress
@onready var council_prep: Button = %CouncilPrepButton
@onready var six_arts: Button = %PromotionArts
@onready var first_private_button: Button = %FirstPrivateButton
@onready var cancel_directions: Button = %CancelDirections

var world: ESTATE_WORLD
var opening_cue := OpeningCue.NONE
var opening_cell := Vector2i.ZERO
var opening_plot_name := "公田"
var opening_seed_id := "millet"
var waiting_for_tribute_crop := false
var tending_first_private := false
var offer_first_private := false
var private_crop_planted := false

func _ready() -> void:
	first_private_button.pressed.connect(_toggle_first_private)
	cancel_directions.visibility_changed.connect(_refresh_first_private_button)
	GamepadInput.changed.connect(refresh)
	Preferences.bindings_changed.connect(refresh)
	GameEvents.farm_state_changed.connect(refresh)
	GameEvents.channels_changed.connect(refresh)
	GameEvents.day_advanced.connect(refresh.unbind(1))
	GameEvents.crop_harvested.connect(refresh.unbind(1))
	GameEvents.retainer_recruited.connect(refresh.unbind(1))
	GameEvents.retainer_departed.connect(refresh.unbind(1))
	GameEvents.reputation_changed.connect(refresh.unbind(1))
	GameEvents.inventory_changed.connect(refresh.unbind(1))
	GameEvents.food_changed.connect(refresh.unbind(1))
	GameEvents.money_changed.connect(refresh.unbind(1))
	GameEvents.rank_changed.connect(refresh.unbind(1))
	GameEvents.well_field_added.connect(refresh.unbind(1))
	GameEvents.well_field_reclaimed.connect(refresh.unbind(2))
	GameEvents.tax_reform_triggered.connect(refresh)
	GameEvents.tax_reform_choice_made.connect(refresh.unbind(1))
	GameEvents.silk_changed.connect(refresh)
	GameEvents.raid_defeated.connect(refresh)
	GameEvents.campaign_ended.connect(refresh.unbind(1))
	GameEvents.field_rotation_changed.connect(refresh)

func setup(estate_world: ESTATE_WORLD) -> void:
	world = estate_world
	world.seed_selected.connect(refresh.unbind(1))
	world.get_node("Scenery/EndingRecord").visibility_changed.connect(refresh)
	Global.player_stats.level_up.connect(refresh.unbind(2))
	GameEvents.stamina_changed.connect(refresh.unbind(1))
	refresh()

func refresh() -> void:
	opening_cue = OpeningCue.NONE
	waiting_for_tribute_crop = false
	offer_first_private = false
	six_arts.hide()
	if not world or Global.well_fields.is_empty():
		return
	var goals := Global.route_objectives()
	route_progress.visible = (not goals.is_empty() and Global.outcome == Global.Outcome.RUNNING
		and Global.ending_record.is_empty())
	council_prep.visible = (Global.outcome == Global.Outcome.RUNNING
		and Global.tax_reform_choice == Global.TaxReformChoice.NONE and not Global.tax_council_waiting()
		and (Global.current_rank >= Global.Rank.SHANG_SHI
			or (Global.well_fields.size() > 1 and Global.well_fields[1].is_unlocked)))
	var can_petition := council_prep.visible and Global.can_petition_tax_council()
	council_prep.text = "请议已就绪" if can_petition else "查议税条件"
	var record_stand := world.get_node("Scenery/EndingRecord")
	if record_stand.archived:
		var route := "守礼安邦" if Global.ending_record["outcome"] == Global.Outcome.TRADITIONAL else "税亩富民"
		_describe(route + " · 已通关", "到%s翻看%s。" % [record_stand.place_name, record_stand.record_name])
		_refresh_first_private_button()
		return
	if Global.tax_council_waiting():
		_describe("初税亩 · 召简来访", "使者在堂前候议。请在过夜前定案。")
	elif route_progress.visible:
		var route := "守礼安邦" if Global.tax_reform_choice == Global.TaxReformChoice.TRADITIONAL else "税亩富民"
		var pending := goals.filter(func(goal: Dictionary) -> bool: return goal.value < goal.target)
		var next := "已达成全部目标"
		if record_stand.ready_to_present:
			next = "到%s呈交%s。" % [record_stand.place_name, record_stand.record_name]
		if not pending.is_empty():
			var goal: Dictionary = pending.front()
			next = "%s %d/%d" % [goal.label, goal.value, goal.target]
		_describe(route, next)
		route_progress.text = ("指路呈交%s" % record_stand.record_name if record_stand.ready_to_present
			else "结局目标 · %d/%d 项" % [goals.size() - pending.size(), goals.size()])
	elif Global.tax_reform_choice == Global.TaxReformChoice.DELAYED:
		_describe("暂缓议税 · 还剩 %d 天" % Global.research_days_remaining(),
			"%d 天后缴 %d 铜钱研究费。经费不足时须抉择。" % [
				Global.research_days_until_payment(), Global.balance.research_monthly_cost])
	elif Global.current_rank >= Global.Rank.DA_FU:
		var start := Global.tax_council_start_day()
		var date := "第 %d 天起议税" % start if Global.current_day < start else "已到议税时日"
		if can_petition:
			date = "可请召简提前议税"
		var gap := Global.tax_council_public_gap()
		var tribute := "纳贡已达标" if gap == 0 else "还差 %d 份纳贡" % gap
		if gap < 0:
			tribute = "查看纳贡条件"
		_describe("筹备初税亩", "%s\n公田 %.2f%% · %s" % [date, Global.public_contribution_ratio() * 100.0, tribute])
	elif Global.well_fields.size() >= 2:
		var field: Dictionary = Global.well_fields[1]
		if not field["is_unlocked"]:
			var progress: int = field["reclamation_progress"]
			_describe("开垦第二块井田", "已完成 %d/%d 夜 · %s\n睡觉可推进。" % [
				progress, Global.RECLAMATION_NIGHTS, Global.reclamation_stage(progress)])
		else:
			_show_next_promotion()
	elif not Global.first_tribute_delivered() and Global.current_rank == Global.Rank.XIA_SHI:
		_show_first_tribute()
	elif (Global.current_rank == Global.Rank.XIA_SHI and Global.private_harvest_total == 0
		and not Global.eligible_for_promotion()):
		_describe("第一茬私田", _opening_field_step(_first_private_cell(), false))
	elif Global.current_rank == Global.Rank.XIA_SHI:
		_show_first_promotion()
	else:
		_show_first_expansion()
	if Global.first_tribute_delivered() or Global.private_harvest_total > 0:
		tending_first_private = false
	_refresh_first_private_button()

func _show_first_tribute() -> void:
	var public_cell: Vector2i = Global.well_fields[0].center_pos
	var public_step := _opening_field_step(public_cell, true)
	var due := Global.tribute_deadline()
	if due > 0 and not Global.active_crops.has(public_cell):
		public_step += "\n首贡期限 · 第 %d 天过夜前" % due
	_describe("第一次纳贡", public_step)
	if not waiting_for_tribute_crop or Global.private_harvest_total > 0:
		return
	var cell := _first_private_cell()
	var action := world.field_action(cell)
	private_crop_planted = Global.active_crops.has(cell)
	offer_first_private = (action in [ESTATE_WORLD.FieldAction.TILL, ESTATE_WORLD.FieldAction.SOW,
		ESTATE_WORLD.FieldAction.RICE_SEED, ESTATE_WORLD.FieldAction.WATER, ESTATE_WORLD.FieldAction.HARVEST]
		and world.field_cost(action) <= Global.current_stamina)
	if offer_first_private and tending_first_private:
		_describe("兼顾一格私田", _opening_field_step(cell, false))

func _toggle_first_private() -> void:
	tending_first_private = not tending_first_private
	refresh()

func _refresh_first_private_button() -> void:
	first_private_button.visible = offer_first_private and not cancel_directions.visible
	if tending_first_private:
		first_private_button.text = "返回纳贡指引"
	else:
		first_private_button.text = "照料首茬私田" if private_crop_planted else "兼种一格私田"

func _show_first_promotion() -> void:
	var title := "晋升中士 · %d/%d 声望" % [Global.reputation, Global.promotion_reputation()]
	if Global.eligible_for_promotion():
		_describe(title, "声望和周礼已达标。过夜核定爵位，晋升后可扩建。")
	elif Global.reputation >= Global.promotion_reputation():
		_describe(title, "晋升要求周礼中等或以上。当前周礼为「%s」。" % Global.zhou_li_score)
	else:
		_describe(title, "纳贡或交谈积声望，达标后过夜晋升。\n招募一人会花 %d 声望。" % Global.balance.recruit_reputation_requirement)

func _show_next_promotion() -> void:
	if Global.current_rank == Global.Rank.XIA_SHI:
		_show_first_promotion()
		return
	var title := "晋升" + String(Global.rank_names[Global.current_rank + 1])
	var reputation := "声望 %d/%d" % [Global.reputation, Global.promotion_reputation()]
	if Global.eligible_for_promotion():
		_describe(title, reputation + " · 过夜核定爵位。")
		return
	var required_art := Global.balance.upper_rank_art_level
	var best_art := Global.highest_six_art_level()
	if Global.current_rank == Global.Rank.ZHONG_SHI and best_art < required_art:
		six_arts.show()
		_describe(title, "%s\n任一六艺需 %d 级，当前最高 %d 级。" % [reputation, required_art, best_art])
	else:
		_describe(title, reputation + "\n纳贡或同来客交谈积声望。")

func _show_first_expansion() -> void:
	var plan := Global.reclamation_plan()
	if plan.ready:
		_describe("开垦第二块井田", "点「开垦」勘定田址。立桩后 %d 夜完工。" % Global.RECLAMATION_NIGHTS)
	elif plan.workers_needed > 0:
		_describe("延揽门客 · %d/%d 人" % [Global.retainers.size(), Global.RECLAMATION_RETAINERS],
			"交谈可积声望，招募一人花 %d 声望。点「开垦」查看来客与筹备进度。" %
			Global.balance.recruit_reputation_requirement)
	else:
		_describe("筹措开垦物资", "铜钱 %d/%d · 粮食 %d/%d\n收私田赚铜钱，作物可到市场换粮。" %
			[Global.money, plan.copper, Global.food_storage, plan.grain])

func _describe(title: String, detail: String) -> void:
	heading.text = title
	text = detail

func _first_private_cell() -> Vector2i:
	var center: Vector2i = Global.well_fields[0]["center_pos"]
	var fallow := center + Vector2i.DOWN
	var planted := fallow
	var fewest_nights := INF
	for y in range(-1, 2):
		for x in range(-1, 2):
			var cell := center + Vector2i(x, y)
			if cell == center:
				continue
			var crop: Dictionary = Global.active_crops.get(cell, {})
			if crop.is_empty():
				if Global.active_crops.has(fallow) or (Global.tilled_cells.has(cell) and not Global.tilled_cells.has(fallow)):
					fallow = cell
			elif world.field_action(cell) != ESTATE_WORLD.FieldAction.DRY_RICE:
				var nights: int = crop.growth_nights - crop.age
				if nights < fewest_nights:
					fewest_nights = nights
					planted = cell
	return planted if fewest_nights < INF else fallow

func _opening_field_step(cell: Vector2i, is_public: bool) -> String:
	opening_cell = cell
	opening_plot_name = "公田" if is_public else "私田"
	var action: int = world.field_action(cell)
	var cost: int = world.field_cost(action)
	if cost > Global.current_stamina:
		opening_cue = OpeningCue.SLEEP
		return "体力不足，%s需要 %d 点。点「睡觉」恢复体力。" % [opening_plot_name, cost]
	if (not is_public and Global.field_rotation.waiting_for_harvest() and world.current_seed_id != "beans"
		and action in [ESTATE_WORLD.FieldAction.SOW, ESTATE_WORLD.FieldAction.RICE_SEED]):
		opening_cue = OpeningCue.SEED
		opening_seed_id = "beans"
		return "按 %s 或点「菽」换种。\n在私田播菽，收后能给下一茬留肥。" % _seed_shortcut("beans")
	opening_cue = OpeningCue.PLOT
	var pad := GamepadInput.active
	var act := "按 A" if pad else "左键"
	var point := "对准%s按 A" % opening_plot_name if pad else "左键点%s" % opening_plot_name
	match action:
		ESTATE_WORLD.FieldAction.TILL:
			if is_public:
				return ("左摇杆移动，右摇杆对准金边公田。\n按 A 翻地，收成用来纳贡。" if pad
					else "%s 或方向键移动。\n左键点金边公田翻地，收成用来纳贡。" % _walking_keys())
			return "%s翻地。\n收成归你，可换口粮或留作时令交货。" % point
		ESTATE_WORLD.FieldAction.SOW:
			var seed := ItemManager.get_crop(world.current_seed_id)
			return "%s播种「%s」。供水 %d 夜可收。\n%s" % [
				point, seed.crop_name, Global.sowing_nights(seed), "LB/RB 换种。" if pad else "可在下方换种。"]
		ESTATE_WORLD.FieldAction.RICE_SEED:
			opening_cue = OpeningCue.SEED
			opening_seed_id = "millet"
			return "稻种需要渠水。\n先按 %s 或点「黍」换种。" % _seed_shortcut("millet")
		ESTATE_WORLD.FieldAction.HARVEST:
			return ("公田已熟。%s收割，收成入国库。" % act if is_public
				else "私田成熟了。%s收获，作物收入私仓，也会赚到铜钱。" % act)
		ESTATE_WORLD.FieldAction.DRY_RICE:
			return "这格稻田断水了。恢复供水后再过夜。"
		ESTATE_WORLD.FieldAction.WATER:
			var crop: Dictionary = Global.active_crops[cell]
			return "%s浇水。还需供水 %d 夜。\n今晚缺水就会停长。" % [point, crop.growth_nights - crop.age]
		ESTATE_WORLD.FieldAction.CHANNEL, ESTATE_WORLD.FieldAction.RAIN, ESTATE_WORLD.FieldAction.WATERED:
			var crop: Dictionary = Global.active_crops[cell]
			opening_cue = OpeningCue.SLEEP
			waiting_for_tribute_crop = is_public
			if crop.growth_nights - crop.age == 1:
				return "水已到田，过夜后这格%s就能收。" % opening_plot_name
			return "水已到田，过夜后生长。\n还需供水 %d 夜。" % (crop.growth_nights - crop.age)
	return "井田中央用于纳贡，四周的田由你经营。"

func _seed_shortcut(crop_id: String) -> String:
	return "LB/RB" if GamepadInput.active else Preferences.seed_label(crop_id)

func _walking_keys() -> String:
	var labels: Array[String] = []
	for action in [KeyBindings.UP, KeyBindings.LEFT, KeyBindings.DOWN, KeyBindings.RIGHT]:
		labels.append(Preferences.key_label(action))
	return "WASD" if labels == ["W", "A", "S", "D"] else " / ".join(labels)
