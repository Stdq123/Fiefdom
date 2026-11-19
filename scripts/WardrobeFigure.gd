extends Control
class_name WardrobeFigure

const STAND := -2
const WALK := -1
const WORK_WINDUP := 0.22
const DIRECTIONS := [Vector2.DOWN, Vector2.UP, Vector2.RIGHT]

@export var facing := Player.Facing.FRONT
@onready var actor: Node2D = $Actor
@onready var body: Sprite2D = $Actor/Body
@onready var tool: ToolGesture = $Actor/Tool

func _ready() -> void:
	resized.connect(_fit_figure)
	_fit_figure()

func _fit_figure() -> void:
	var zoom := maxf(1.0, floorf(minf(size.x / 49.0, size.y / 42.0)))
	actor.scale = Vector2.ONE * zoom
	var center := 0.39 if facing == Player.Facing.PROFILE else 0.50
	actor.position = (size * Vector2(center, 0.60)).round()

func dress(id: String) -> void:
	body.texture = PlayerAttire.texture(id)
	tool.sleeve = PlayerAttire.CATALOG[id].sleeve

func show_pose(motion: int, time: float) -> void:
	var column := 0
	if motion == WALK or motion == STAND:
		tool.clear()
		if motion == WALK:
			column = NeighborMotion.walk_column(time * Player.SPEED, PlayerAttire.PASS_COLUMN)
	else:
		tool.show_sample(motion as ToolGesture.Action, DIRECTIONS[facing], WORK_WINDUP, time * 0.65)
		var work := tool.work_pose()
		if work >= 0:
			column = PlayerAttire.WORK_COLUMN + work
	body.frame_coords = Vector2i(column, facing)
	body.offset = tool.body_lean if column == 0 else Vector2.ZERO
