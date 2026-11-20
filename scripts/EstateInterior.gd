extends Node2D

const SCENERY_OCCLUSION := preload("res://scripts/SceneryOcclusion.gd")
# Indexed by Global.Weather.
const LAMP_DAY: Array[float] = [0.19, 0.34, 0.25, 0.36]
const WINDOW_DAY: Array[float] = [0.30, 0.26, 0.285, 0.24]
const DOOR_DAY: Array[Vector3] = [
	Vector3(0.34, 0.29, 0.23), Vector3(0.11, 0.15, 0.20),
	Vector3(0.17, 0.23, 0.28), Vector3(0.14, 0.20, 0.24),
]

# The hall and the silk shed share the same painted steps.
static var _stone_threshold := PackedVector2Array([
	Vector2(-14, 49), Vector2(15, 49), Vector2(23, 68),
	Vector2(22, 71), Vector2(-22, 71), Vector2(-23, 68),
])

@export var room_kind := Global.EstateRoom.HALL
@export var facade_path: NodePath = ^"../HallRest"
@export var resume_path: NodePath = ^"Entry"
@export var foreground_paths: Array[NodePath] = []

@onready var player: Player = $"../Player"
@onready var facade: Node2D = get_node(facade_path)
@onready var entrance: Area2D = facade.get_node("Entrance")
@onready var yard: Marker2D = facade.get_node("Yard")
@onready var room_camera: Camera2D = $RoomCamera
@onready var lamp: PointLight2D = $Lamp
@onready var window_light: PointLight2D = $WindowLight
@onready var window_projection: ShaderMaterial = $Floor.material

var flame_phase := 0.0

func on_stone_threshold(at: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(at), _stone_threshold)

func _ready() -> void:
	window_projection.set_shader_parameter("room_origin", global_position)
	if not foreground_paths.is_empty():
		var occlusion := SCENERY_OCCLUSION.new(player, room_kind)
		for path in foreground_paths:
			var art := get_node(path) as Sprite2D
			occlusion.watch_prop(art, art.get_parent() as Node2D)
		add_child(occlusion)
	entrance.add_to_group("travel_threshold")
	$Exit.add_to_group("travel_threshold")
	entrance.body_entered.connect(_on_entrance)
	$Exit.body_entered.connect(_on_exit)
	GameEvents.campaign_ended.connect(_on_campaign_ended)
	set_process(false)
	_restore_room.call_deferred()

func _restore_room() -> void:
	if Global.estate_room != room_kind:
		return
	if facade.visible:
		_arrive(true, get_node(resume_path))
		var floor_art: Sprite2D = $Floor
		player.restore_walking_checkpoint(floor_art.global_transform * floor_art.get_rect())
	else:
		Global.restored_walking_checkpoint.clear()
		Global.estate_room = Global.EstateRoom.OUTDOORS
		GameEvents.estate_room_changed.emit(Global.estate_room)

func _on_entrance(body: Node2D) -> void:
	if (body == player and player.facing_row == Player.Facing.BACK and facade.visible and not Global.is_indoors()
		and not player.conversation_open and not player.resting and not player.training_cart.visible):
		MapTravel.relocate(_enter_room)

func _on_exit(body: Node2D) -> void:
	if (body == player and player.facing_row == Player.Facing.FRONT and Global.estate_room == room_kind
		and not player.conversation_open and not player.resting):
		MapTravel.relocate(_leave_room)

func _enter_room() -> bool:
	if not facade.visible:
		return false
	_arrive(true, $Entry)
	return true

func _leave_room() -> bool:
	_arrive(false, yard)
	return true

func _arrive(inside: bool, marker: Marker2D) -> void:
	Global.estate_room = room_kind if inside else Global.EstateRoom.OUTDOORS
	visible = inside
	player.arrive_at(marker)
	room_camera.enabled = inside
	var camera := room_camera if inside else player.camera
	camera.make_current()
	camera.reset_smoothing()
	camera.force_update_scroll()
	if inside:
		_refresh_lighting()
	else:
		facade.present_exit()
	set_process(inside)
	GameEvents.estate_room_changed.emit(Global.estate_room)

func _process(delta: float) -> void:
	flame_phase = fposmod(flame_phase + delta * 4.0, TAU)
	_refresh_lighting()

func _refresh_lighting() -> void:
	var dusk := Global.dusk_amount()
	var weather := Global.weather_on()
	var flicker := 0.032 * sin(flame_phase) + 0.013 * sin(3.0 * flame_phase)
	lamp.energy = lerpf(LAMP_DAY[weather], 0.86, dusk) + flicker
	window_light.energy = lerpf(WINDOW_DAY[weather], 0.035, dusk)

	var daylight := minf(Global.day_progress / 0.86, 1.0)
	var sun_height := sin(daylight * PI)
	var strength := (1.0 - dusk) * lerpf(0.76, 1.0, sun_height)
	window_projection.set_shader_parameter("direct_light", strength if weather == Global.Weather.CLEAR else 0.0)
	window_projection.set_shader_parameter("beam_origin",
		Vector2(lerpf(-17.0, 18.0, daylight), lerpf(3.0, -12.0, sun_height)))
	window_projection.set_shader_parameter("beam_depth", lerpf(47.0, 34.0, sun_height))
	window_projection.set_shader_parameter(&"door_gain", DOOR_DAY[weather] * (1.0 - dusk))
	var clear := weather == Global.Weather.CLEAR
	window_projection.set_shader_parameter(&"door_slant", lerpf(-14.0, 20.0, daylight) if clear else 0.0)
	window_projection.set_shader_parameter(&"door_softness", 1.5 if clear else 5.0)

func _on_campaign_ended(_outcome: Global.Outcome) -> void:
	if Global.estate_room == room_kind:
		_arrive(false, yard)
