extends "res://scripts/SurveyMap.gd"

signal find_keeper_requested()
signal public_plot_requested()

const PUBLIC_INK := Color("#f7de9e")
const PRIVATE_INK := Color("#cddab6")
const LATE_INK := Color("#f2b398")

@export var public_plot: StyleBox
@export var private_plot: StyleBox

@onready var world: Node2D = $"../../../World"
@onready var heading: Label = %HandoverTitle
@onready var sketch: GridContainer = %WellFieldSketch
@onready var find_keeper: Button = %FindKeeper
@onready var find_public_plot: Button = %FindPublicPlot
@onready var tribute_due: Label = %FirstTributeDue

func _ready() -> void:
	super._ready()
	for label: Label in [heading, %Letter, %Public, %Tribute, %Private, %Income, tribute_due]:
		InterfaceFont.scale_reading_text(label)
	for button: Button in [find_keeper, find_public_plot]:
		InterfaceFont.scale_reading_text(button)
	find_keeper.pressed.connect(_find_keeper)
	find_public_plot.pressed.connect(_find_public_plot)
	for index in 9:
		var plot := PanelContainer.new()
		plot.custom_minimum_size = Vector2(48, 48)
		var center := index == 4
		plot.add_theme_stylebox_override("panel", public_plot if center else private_plot)
		sketch.add_child(plot)
		var label := Label.new()
		label.text = "公田" if center else "私"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", PUBLIC_INK if center else PRIVATE_INK)
		plot.add_child(label)
		InterfaceFont.scale_reading_text(label)

func _show_map() -> void:
	super._show_map()
	if find_public_plot.visible:
		find_public_plot.grab_focus()

func _map_available() -> bool:
	return not Global.first_tribute_delivered()

func _refresh_on_open() -> void:
	heading.text = "%s · 交接简" % Global.campaign_name
	find_keeper.visible = is_instance_valid(world.neighbor_actor(VisitorData.FIELD_KEEPER))
	find_public_plot.visible = not Global.tribute_field_plan().is_empty()
	var due := Global.tribute_deadline()
	tribute_due.visible = due > 0
	if due <= 0:
		return
	var overdue := Global.tribute_overdue()
	var tonight := due == Global.current_day
	var when := "第 %d 天过夜前" % due
	if overdue:
		when = "已逾期"
	elif tonight:
		when = "今夜到期"
	tribute_due.text = "首贡 1 份 · " + when
	tribute_due.add_theme_color_override("font_color", LATE_INK if overdue or tonight else PUBLIC_INK)

func _find_keeper() -> void:
	close_map()
	find_keeper_requested.emit()

func _find_public_plot() -> void:
	close_map()
	public_plot_requested.emit()
