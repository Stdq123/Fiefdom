extends Node2D

const PORTER := preload("res://assets/characters/market-porter.svg")
const STORAGE := preload("res://assets/world/estate-storage.png")

@onready var body: NeighborMotion = $Body
@onready var sack: Sprite2D = $Sack
@onready var caption: Label = $Name
var road := Curve2D.new()

func _ready() -> void:
	for point: Vector2 in EstateLayout.watch_relief_route():
		road.add_point(point)
	body.set_motion_sheet(PORTER)
	var bag := AtlasTexture.new()
	bag.atlas = STORAGE
	bag.region = Rect2(0, 0, 16, 16)
	bag.filter_clip = true
	sack.texture = bag
	_sync_position(false)

func _process(_delta: float) -> void:
	_sync_position(true)

func _sync_position(animate: bool) -> void:
	var progress := Global.watch_relief_progress()
	var was_visible := visible
	visible = progress >= 0.0 and progress < 1.0 and not Global.is_indoors()
	if not visible:
		return
	var offset := progress * road.get_baked_length()
	var foot := road.sample_baked(offset)
	var movement := foot - position
	position = foot
	caption.visible = foot.y < EstateLayout.SOUTH_FORK.y - 28.0
	var lift := 0.0
	if animate and was_visible and movement.length_squared() > 0.0016:
		lift = body.walk(movement)
	else:
		body.stand()
		body.face(road.sample_baked(offset + 2.0) - road.sample_baked(offset - 2.0))
	var side := -8.0 if body.flip_h else 8.0
	sack.position = Vector2(side if body.facing == NeighborMotion.Facing.PROFILE else 4.0, -10.0 + lift)
