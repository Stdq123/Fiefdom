extends PanelContainer
class_name ArtProgressCard

@onready var seal: Label = %Seal
@onready var activity: Label = %Activity
@onready var level_label: Label = %Level
@onready var xp_label: Label = %Experience
@onready var meter: ProgressBar = %Meter

var art: int

func _ready() -> void:
	for label: Label in [activity, level_label, xp_label]:
		InterfaceFont.scale_reading_text(label)

func setup(art_index: int, source: String) -> void:
	art = art_index
	seal.text = Global.player_stats.get_art_name(art)
	activity.text = source
	refresh()

func refresh() -> void:
	var record := Global.player_stats.get_stat(art)
	level_label.text = "%d 级" % record.level
	xp_label.text = "本级经验 %d/%d" % [record.xp, record.max_xp]
	meter.max_value = record.max_xp
	meter.value = record.xp
