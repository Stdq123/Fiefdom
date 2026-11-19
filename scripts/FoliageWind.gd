extends Node

const SHADER := preload("res://resources/foliage-wind.gdshader")
const CROP_SHADER := preload("res://resources/field-crop-wind.gdshader")
const CROWN := 0.78
const NEEDLES := 0.47
const WILLOW := 0.98
const STEM := 1.20

var material := ShaderMaterial.new()
var crop_material: ShaderMaterial
var phase := 0.0

func _init(crops: TileMapLayer = null) -> void:
	name = "FoliageWind"
	material.shader = SHADER
	if crops:
		crop_material = ShaderMaterial.new()
		crop_material.shader = CROP_SHADER
		crops.material = crop_material

func _ready() -> void:
	GameEvents.day_advanced.connect(_refresh_weather.unbind(1))
	GameEvents.estate_room_changed.connect(_refresh_room.unbind(1))
	_refresh_weather()
	_refresh_room()

func attach(plant: Sprite2D, flexibility := CROWN) -> void:
	plant.material = material
	plant.set_instance_shader_parameter(&"flexibility", flexibility)

func _set_wind_parameter(parameter: StringName, value: float) -> void:
	material.set_shader_parameter(parameter, value)
	if crop_material:
		crop_material.set_shader_parameter(parameter, value)

func _refresh_weather() -> void:
	var strength := 0.054 if Global.season_index() != Global.Season.WINTER else 0.040
	if Global.has_rain():
		strength *= 1.40
	_set_wind_parameter(&"wind_strength", strength)

func _refresh_room() -> void:
	set_process(not Global.is_indoors())

func _process(delta: float) -> void:
	phase = fposmod(phase + delta * 0.85, TAU)
	_set_wind_parameter(&"wind_phase", phase)
