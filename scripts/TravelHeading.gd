extends HBoxContainer
class_name TravelHeading

@export var place_name := ""

func _ready() -> void:
	var place: Label = $Place
	place.text = place_name
	InterfaceFont.scale_reading_text(place)
	GameEvents.daylight_changed.connect(_refresh_daylight)
	_refresh_daylight()

func _refresh_daylight() -> void:
	$WatchDial.show_watch(Global.day_watch_label())
	var weather: TextureRect = %WeatherIcon
	weather.texture = HUDIcons.icon(HUDIcons.SKY[HUDIcons.sky_index()])
	weather.accessibility_name = Global.weather_label(0, true)

static func date_caption() -> String:
	var caption := "第 %d 天 · %s · %s" % [Global.current_day, Global.day_watch_label(), Global.get_current_solar_term()]
	if Global.weather_on() != Global.Weather.CLEAR:
		caption += " · " + Global.weather_label()
	return caption
