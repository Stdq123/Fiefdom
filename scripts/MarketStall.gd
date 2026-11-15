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
const SIDE_WOOD := [Color("#806347"), Color("#647264"), Color("#816053")]
const SIDE_AWNING := [Color("#ac794d"), Color("#668b82"), Color("#aa6b60")]
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

func _draw() -> void:
	var wood: Color = SIDE_WOOD[kind]
	var awning: Color = SIDE_AWNING[kind]
	if Global.has_rain():
		wood = wood.darkened(0.13)
		awning = awning.darkened(0.12)
	draw_colored_polygon(PackedVector2Array([Vector2(31, -6), Vector2(44, -12), Vector2(46, -9),
		Vector2(46, -6), Vector2(35, 0), Vector2(31, 0)]), Color("#514c3b"))
	draw_colored_polygon(PackedVector2Array([Vector2(35, -5), Vector2(45, -10), Vector2(45, -8),
		Vector2(36, -3)]), Color("#8c8066"))
	draw_colored_polygon(PackedVector2Array([Vector2(31, -34), Vector2(44, -41), Vector2(44, -11),
		Vector2(31, -4)]), wood.darkened(0.19))
	for y in [-29.0, -23.0, -17.0, -11.0]:
		draw_line(Vector2(32, y), Vector2(44, y - 6), wood.darkened(0.38), 1.2)
		draw_line(Vector2(37, y + 0.2), Vector2(42, y - 2.2), wood, 0.65)
	draw_colored_polygon(PackedVector2Array([Vector2(43, -40), Vector2(45, -41), Vector2(45, -11),
		Vector2(43, -10)]), wood.darkened(0.42))
	var roof := PackedVector2Array([Vector2(26, -52), Vector2(37, -59), Vector2(45, -53),
		Vector2(52, -43), Vector2(40, -35), Vector2(32, -45)])
	draw_colored_polygon(roof, awning.darkened(0.28))
	draw_polyline(PackedVector2Array([Vector2(34, -45), Vector2(44, -51), Vector2(48, -46),
		Vector2(38, -40)]), awning.darkened(0.12), 1.15)
	draw_colored_polygon(PackedVector2Array([Vector2(39, -37), Vector2(52, -44), Vector2(52, -40),
		Vector2(40, -32)]), awning.darkened(0.42))
	draw_line(Vector2(40, -37), Vector2(51, -43), awning.lightened(0.04), 1.0)
	if Global.season_index() == Global.Season.WINTER:
		draw_line(Vector2(33, -56), Vector2(37, -58), Color("#b7bca8"), 1.1)

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
