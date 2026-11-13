extends Node2D

const WINGS := preload("res://assets/world/ivan-voirol/butterfly-wings.png")
const WING_FRAMES := [0, 1, 2, 1]
const TINTS := [Color("#c7b784"), Color("#b5c9af")]
const FLIGHT_SECONDS := 8.0

@export_enum("Swallowtail", "Glider") var variety := 0

@onready var wings := Sprite2D.new()
var perch: Vector2
var flight_time := 0.0

func _ready() -> void:
	perch = position
	flight_time = 2.0 * variety
	wings.texture = WINGS
	wings.hframes = 3
	wings.vframes = 2
	wings.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wings.self_modulate = TINTS[variety]
	wings.scale = Vector2(0.81, 0.81)
	add_child(wings)
	GameEvents.day_advanced.connect(_update_weather.unbind(1))
	_update_weather()
	_process(0.0)

func _update_weather() -> void:
	visible = Global.season_index() <= Global.Season.SUMMER and not Global.has_rain()
	set_process(visible)

func _process(delta: float) -> void:
	modulate.a = 1.0 - Global.dusk_amount()
	flight_time = fposmod(flight_time + delta, FLIGHT_SECONDS)
	var angle := flight_time * TAU / FLIGHT_SECONDS
	position = (perch + Vector2(sin(angle) * 16.0, sin(angle * 2.0 + 0.6) * 9.0)).round()
	wings.position.y = -roundf(9.0 + sin(angle * 3.0) * 3.0)
	wings.frame_coords = Vector2i(WING_FRAMES[floori(flight_time * 18.0) % WING_FRAMES.size()], variety)

func _draw() -> void:
	draw_rect(Rect2(-2, 0, 4, 1), Color("#263a2b7a"))
