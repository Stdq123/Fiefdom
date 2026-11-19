extends "res://scripts/MapGate.gd"

const APRON_REGIONS := [Rect2(0, 0, 70, 56), Rect2(72, 0, 64, 62)]
const APRON_OFFSETS := [Vector2(-34, -28), Vector2(-32, -31)]
const POST_REGION := Rect2(139, 0, 20, 32)
const FROST_ROW := 120.0
const LEAF_REGIONS := [
	[Rect2(0, 65, 22, 54), Rect2(24, 65, 40, 54)],
	[Rect2(66, 65, 46, 54), Rect2(114, 65, 25, 54)],
]
const LEAF_OFFSETS := [
	[Vector2(-12, -46), Vector2(-6, -43)],
	[Vector2(-38, -43), Vector2(-12, -46)],
]

@export var gate_name := ""
@export var southbound := false

@onready var barrier: CollisionShape2D = $Barrier/Shape
@onready var sensor: CollisionShape2D = $CollisionShape2D
@onready var caption: Label = $Caption
@onready var apron: Sprite2D = $Apron
@onready var far_post: Sprite2D = $FarPost
@onready var near_post: Sprite2D = $NearPost
@onready var bamboo_leaf: Sprite2D = $BambooLeaf

func _ready() -> void:
	var across := Vector2(15, 0) if southbound else Vector2(2, 15)
	far_post.position = -across
	near_post.position = across
	if southbound:
		barrier.rotation = PI / 2.0
		sensor.rotation = PI / 2.0
	super._ready()
	body_exited.connect(_on_body_exited)
	GameEvents.ravine_journal_changed.connect(_refresh)
	GameEvents.day_advanced.connect(_refresh_art.unbind(1))
	_refresh()

func _refresh() -> void:
	var open := Global.ravine_shortcut_open()
	barrier.set_deferred("disabled", open)
	caption.text = gate_name if open else gate_name + " · 未开"
	_refresh_art()

func _refresh_art() -> void:
	var weather_row := Vector2(0, FROST_ROW) if Global.season_index() == Global.Season.WINTER else Vector2.ZERO
	var direction := int(southbound)
	var open := Global.ravine_shortcut_open()
	var pose := int(open)
	apron.region_rect = APRON_REGIONS[direction]
	apron.offset = APRON_OFFSETS[direction]
	far_post.region_rect = POST_REGION
	near_post.region_rect = POST_REGION
	bamboo_leaf.region_rect = LEAF_REGIONS[direction][pose]
	bamboo_leaf.offset = LEAF_OFFSETS[direction][pose]
	bamboo_leaf.position = far_post.position if open and not southbound else near_post.position
	var tint := Color("#b8c5bc") if Global.has_rain() else Color.WHITE
	for piece: Sprite2D in [apron, far_post, near_post, bamboo_leaf]:
		var region := piece.region_rect
		region.position += weather_row
		piece.region_rect = region
		piece.self_modulate = tint
	far_post.self_modulate *= Color("#e6e9dc")

func _on_body_entered(body: Node2D) -> void:
	if not Global.ravine_shortcut_open():
		if body is Player:
			caption.text = gate_name + " · 未开\n向蒲宁交还三处水迹"
		return
	super._on_body_entered(body)

func _on_body_exited(body: Node2D) -> void:
	if body is Player and not Global.ravine_shortcut_open():
		caption.text = gate_name + " · 未开"
