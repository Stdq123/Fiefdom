extends Node2D

@export var room_kind := Global.EstateRoom.HALL
@export var facade_path: NodePath = ^"../HallRest"
@export var resume_path: NodePath = ^"Entry"

@onready var player: Player = $"../Player"
@onready var facade: Node2D = get_node(facade_path)
@onready var entrance: Area2D = facade.get_node("Entrance")
@onready var yard: Marker2D = facade.get_node("Yard")
@onready var room_camera: Camera2D = $RoomCamera
@onready var lamp: PointLight2D = $Lamp
@onready var window_light: PointLight2D = $WindowLight
@onready var window_projection: ShaderMaterial = $Floor.material

var flame_phase := 0.0

func _ready() -> void:
	window_projection.set_shader_parameter("room_origin", global_position)
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
	set_process(inside)
	GameEvents.estate_room_changed.emit(Global.estate_room)

func _process(delta: float) -> void:
	flame_phase = fposmod(flame_phase + delta * 4.0, TAU)
	_refresh_lighting()

func _refresh_lighting() -> void:
	var dusk := Global.dusk_amount()
	var rain := Global.has_rain()
	var flicker := 0.032 * sin(flame_phase) + 0.013 * sin(3.0 * flame_phase)
	lamp.energy = lerpf(0.34 if rain else 0.19, 0.86, dusk) + flicker
	window_light.energy = lerpf(0.26 if rain else 0.30, 0.035, dusk)

	var daylight := minf(Global.day_progress / 0.86, 1.0)
	var sun_height := sin(daylight * PI)
	var strength := (1.0 - dusk) * lerpf(0.76, 1.0, sun_height)
	window_projection.set_shader_parameter("direct_light", 0.0 if rain else strength)
	window_projection.set_shader_parameter("beam_origin",
		Vector2(lerpf(-17.0, 18.0, daylight), lerpf(3.0, -12.0, sun_height)))
	window_projection.set_shader_parameter("beam_depth", lerpf(47.0, 34.0, sun_height))

func _on_campaign_ended(_outcome: Global.Outcome) -> void:
	if Global.estate_room == room_kind:
		_arrive(false, yard)
