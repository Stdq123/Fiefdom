extends Node2D
class_name MarketStall

enum Kind { GRAIN, FISH, SILK }
signal opened(kind: Kind)

const ART := preload("res://assets/world/west-market-stalls.svg")
const KEEPER_ART := preload("res://assets/characters/market-keepers.svg")
const TITLES := ["粮摊", "鱼摊", "绸摊"]
const APPROACH := Vector2(0, 24)
const FRAME := Vector2(84, 60)
const KEEPER_ROW := Vector2(72, 24)
const WORK_CYCLE := 6.4
enum KeeperPose { REST, TEND, BLINK }

@export var kind: Kind
@onready var sign: Label = $Sign
@onready var keeper: Sprite2D = $Keeper

var focused := false
var pose_time := 0.0

func _ready() -> void:
	var column := FRAME.x * kind
	$Sprite2D.texture = _atlas(ART, Rect2(Vector2(column, 0), FRAME))
	$CounterFront.texture = _atlas(ART, Rect2(Vector2(column, FRAME.y), FRAME))
	keeper.texture = _atlas(KEEPER_ART, Rect2(Vector2(0, KEEPER_ROW.y * kind), KEEPER_ROW))
	pose_time = float(kind) * 1.7
	set_interaction_focused(false)

func _process(delta: float) -> void:
	pose_time = fposmod(pose_time + delta, WORK_CYCLE)
	_update_keeper()

func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	atlas.filter_clip = true
	return atlas

func _update_keeper() -> void:
	if pose_time >= WORK_CYCLE - 0.14:
		keeper.frame = KeeperPose.BLINK
	elif not focused and pose_time < 1.10:
		keeper.frame = KeeperPose.TEND
	else:
		keeper.frame = KeeperPose.REST

func can_interact_from(foot: Vector2) -> bool:
	var at := to_local(foot)
	return absf(at.x) <= 36.0 and at.y >= 5.0 and at.y <= 34.0

func set_interaction_focused(active: bool) -> void:
	focused = active
	sign.text = GamepadInput.interact_key() + "  " + TITLES[kind] if focused else TITLES[kind]
	sign.modulate = Color("#ffe4a1") if focused else Color("#e5d9af")
	_update_keeper()

func interact() -> void:
	opened.emit(kind)
