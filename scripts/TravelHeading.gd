extends HBoxContainer
class_name TravelHeading

@export var place_name := ""

func _ready() -> void:
	$Place.text = place_name
	GameEvents.daylight_changed.connect(_refresh_daylight)
	_refresh_daylight()

func _refresh_daylight() -> void:
	$WatchDial.show_watch(Global.day_watch_label())
	%WeatherIcon.texture = HUDIcons.icon(HUDIcons.SKY[HUDIcons.sky_index()])
