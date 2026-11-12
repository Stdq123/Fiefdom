extends "res://scripts/SurveyMap.gd"

signal fields_requested()
signal six_arts_requested()

const READY := Color("#c5d592")
const PENDING := Color("#f2bc85")

@onready var date_line: Label = %DateLine
@onready var date_status: Label = %DateStatus
@onready var rank_line: Label = %RankLine
@onready var rank_status: Label = %RankStatus
@onready var contribution: Label = %Contribution
@onready var account: Label = %Account
@onready var contribution_status: Label = %ContributionStatus
@onready var preview_heading: Label = %PreviewHeading
@onready var public_card: PanelContainer = %PublicCard
@onready var public_preview: Label = %PublicPreview
@onready var public_result: Label = %PublicResult
@onready var mixed_card: PanelContainer = %MixedCard
@onready var mixed_title: Label = %MixedTitle
@onready var mixed_preview: Label = %MixedPreview
@onready var mixed_result: Label = %MixedResult
@onready var field_button: Button = %FieldButton
@onready var arts_button: Button = %ArtsButton

var world: Node2D

func _ready() -> void:
	super()
	field_button.pressed.connect(func():
		close_map()
		fields_requested.emit())
	arts_button.pressed.connect(func():
		close_map()
		six_arts_requested.emit())

func _map_available() -> bool:
	return Global.tax_reform_choice == Global.TaxReformChoice.NONE and not Global.tax_council_waiting()

func _refresh_on_open() -> void:
	var opening := Global.tax_council_start_day()
	var nights := maxi(0, opening - Global.current_day)
	date_line.text = "第 %d 年起 · 第 %d 天" % [Global.TAX_COUNCIL_YEAR, opening]
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
	_describe_gap(contribution_status, Global.tax_council_public_gap())

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
