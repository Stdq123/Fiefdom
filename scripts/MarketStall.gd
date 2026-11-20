extends Node2D
class_name MarketStall

enum Kind { GRAIN, FISH, SILK }
signal opened(kind: Kind)

const ART_PATH := "res://assets/world/west-market-stalls.png"
const INSCRIPTION := preload("res://scripts/VillageInscription.gd")
const SHOP_SIGNS := [INSCRIPTION.Form.GRAIN, INSCRIPTION.Form.FISH, INSCRIPTION.Form.SILK]
const KEEPER_PATH := "res://assets/characters/market-keepers.png"
const TITLES := ["粮摊", "鱼摊", "绸摊"]
const KEEPERS := ["谷伯", "渔生", "蔡娘"]
const APPROACH := Vector2(0, 24)
const FRAME := Vector2(104, 64)
const WORK_CYCLE := 6.4
enum KeeperPose { REST, TEND, BLINK, REACH, SET_DOWN }
const KEEPER_CELL := Vector2(40, 32)
# Reach, show the goods, then lower them to the counter. Silk opens more slowly than a grain measure.
const WORK_TIMES := [Vector3(0.26, 0.84, 1.32), Vector3(0.34, 1.05, 1.54), Vector3(0.43, 1.27, 1.91)]
const WORK_SOUNDS := [
	preload("res://assets/audio/market/work-grain.wav"),
	preload("res://assets/audio/market/work-fish.wav"),
	preload("res://assets/audio/market/work-silk.wav"),
]
const WORK_GAIN: Array[float] = [0.37, 0.32, 0.31]

@export var kind: Kind
@onready var sign: Label = $Sign
@onready var keeper: Sprite2D = $Keeper
@onready var counter_back: Sprite2D = $Sprite2D
@onready var counter_front: Sprite2D = $CounterFront
@onready var work_sound: AudioStreamPlayer2D = $WorkSound

var focused := false
var pose_time := 0.0
var listener: Player

func _ready() -> void:
	var column := FRAME.x * kind
	var front_row := 2 if Global.season_index() == Global.Season.WINTER else 1
	var stall_art := load(ART_PATH) as Texture2D
	counter_back.texture = _atlas(stall_art, Rect2(Vector2(column, 0), FRAME))
	counter_front.texture = _atlas(stall_art, Rect2(Vector2(column, FRAME.y * front_row), FRAME))
	if Global.has_rain():
		counter_back.self_modulate = Color("#ccd9d8")
		counter_front.self_modulate = counter_back.self_modulate
	keeper.hframes = KeeperPose.size()
	keeper.texture = _atlas(load(KEEPER_PATH), Rect2(0, KEEPER_CELL.y * kind, KEEPER_CELL.x * keeper.hframes, KEEPER_CELL.y))
	var plaque := INSCRIPTION.place(self, Vector2(-18, -37), SHOP_SIGNS[kind], TITLES[kind])
	plaque.modulate = counter_back.self_modulate
	var variation := AudioStreamRandomizer.new()
	variation.add_stream(0, WORK_SOUNDS[kind])
	variation.random_pitch = 1.06
	variation.random_volume_offset_db = 1.0
	work_sound.stream = variation
	GameEvents.map_departing.connect(work_sound.stop)
	pose_time = float(kind) * 1.7
	set_interaction_focused(false)

func _process(delta: float) -> void:
	var previous := keeper.frame
	pose_time = fposmod(pose_time + delta, WORK_CYCLE)
	_update_keeper()
	if keeper.frame == KeeperPose.SET_DOWN and previous != KeeperPose.SET_DOWN:
		play_work_sound()

func play_work_sound() -> void:
	if (not is_instance_valid(listener) or listener.world_controls_blocked()
			or Global.outcome != Global.Outcome.RUNNING or work_sound.playing):
		return
	if listener.global_position.distance_to(work_sound.global_position) >= work_sound.max_distance:
		return
	var gain := WORK_GAIN[kind] * lerpf(1.0, 0.55, Global.dusk_amount())
	work_sound.volume_linear = gain * (0.66 if Global.has_rain() else 1.0)
	work_sound.play()

func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	atlas.filter_clip = true
	return atlas

func _update_keeper() -> void:
	var beat: Vector3 = WORK_TIMES[kind]
	if pose_time >= WORK_CYCLE - 0.14:
		keeper.frame = KeeperPose.BLINK
	elif focused or pose_time >= beat.z:
		keeper.frame = KeeperPose.REST
	elif pose_time < beat.x:
		keeper.frame = KeeperPose.REACH
	elif pose_time < beat.y:
		keeper.frame = KeeperPose.TEND
	else:
		keeper.frame = KeeperPose.SET_DOWN

func can_interact_from(foot: Vector2) -> bool:
	var at := to_local(foot)
	return absf(at.x) <= 36.0 and at.y >= 5.0 and at.y <= 34.0

func set_interaction_focused(active: bool) -> void:
	focused = active
	var caption := "%s · %s" % [KEEPERS[kind], TITLES[kind]]
	sign.text = GamepadInput.interact_hint(caption) if focused else TITLES[kind]
	sign.visible = focused
	sign.modulate = Color("#ffe4a1") if focused else Color("#e5d9af")
	_update_keeper()

func interact() -> void:
	opened.emit(kind)
