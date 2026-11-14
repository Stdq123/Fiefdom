extends Node2D
class_name MarketStall

enum Kind { GRAIN, FISH, SILK }
signal opened(kind: Kind)

const ART := preload("res://assets/world/west-market-stalls.svg")
const KEEPER_ART := preload("res://assets/characters/market-keepers.svg")
const TITLES := ["粮摊", "鱼摊", "绸摊"]
const KEEPERS := ["谷伯", "渔生", "蔡娘"]
const APPROACH := Vector2(0, 24)
const FRAME := Vector2(84, 60)
const KEEPER_ROW := Vector2(72, 24)
const WORK_CYCLE := 6.4
enum KeeperPose { REST, TEND, BLINK }

@export var kind: Kind
@onready var sign: Label = $Sign
@onready var keeper: Sprite2D = $Keeper
@onready var counter_front: Sprite2D = $CounterFront

var focused := false
var pose_time := 0.0

func _ready() -> void:
	var column := FRAME.x * kind
	$Sprite2D.texture = _atlas(ART, Rect2(Vector2(column, 0), FRAME))
	counter_front.texture = _atlas(ART, Rect2(Vector2(column, FRAME.y), FRAME))
	if Global.has_rain():
		counter_front.self_modulate = Color("#d7e1dd")
	if Global.season_index() == Global.Season.WINTER:
		counter_front.draw.connect(_draw_awning_frost)
	keeper.texture = _atlas(KEEPER_ART, Rect2(Vector2(0, KEEPER_ROW.y * kind), KEEPER_ROW))
	pose_time = float(kind) * 1.7
	set_interaction_focused(false)

func _draw_awning_frost() -> void:
	var frost := Color("#c5cebf")
	counter_front.draw_rect(Rect2(-23, -50, 21, 1), frost)
	counter_front.draw_rect(Rect2(-20, -49, 9, 2), frost)
	counter_front.draw_rect(Rect2(9, -50, 11, 1), frost)
	counter_front.draw_rect(Rect2(8, -48, 5, 1), frost.darkened(0.17))

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
	var caption := "%s · %s" % [KEEPERS[kind], TITLES[kind]]
	sign.text = GamepadInput.interact_hint(caption) if focused else TITLES[kind]
	sign.modulate = Color("#ffe4a1") if focused else Color("#e5d9af")
	_update_keeper()

func interact() -> void:
	opened.emit(kind)
