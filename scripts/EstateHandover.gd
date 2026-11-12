extends "res://scripts/SurveyMap.gd"

signal find_keeper_requested()

@export var public_plot: StyleBox
@export var private_plot: StyleBox

@onready var world: Node2D = $"../../../World"
@onready var heading: Label = %HandoverTitle
@onready var sketch: GridContainer = %WellFieldSketch
@onready var find_keeper: Button = %FindKeeper

func _ready() -> void:
	super._ready()
	find_keeper.pressed.connect(_find_keeper)
	for index in 9:
		var plot := PanelContainer.new()
		plot.custom_minimum_size = Vector2(42, 42)
		var center := index == 4
		plot.add_theme_stylebox_override("panel", public_plot if center else private_plot)
		sketch.add_child(plot)
		if center:
			var label := Label.new()
			label.text = "公田"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			plot.add_child(label)

func _map_available() -> bool:
	return not Global.first_tribute_delivered()

func _refresh_on_open() -> void:
	heading.text = "%s · 交接简" % Global.campaign_name
	find_keeper.visible = is_instance_valid(world.neighbor_actor(VisitorData.FIELD_KEEPER))

func _find_keeper() -> void:
	close_map()
	find_keeper_requested.emit()
