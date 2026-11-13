extends "res://scripts/MapGate.gd"

@export var gate_name := ""
@export var southbound := false

@onready var barrier: CollisionShape2D = $Barrier/Shape
@onready var sensor: CollisionShape2D = $CollisionShape2D
@onready var caption: Label = $Caption

func _ready() -> void:
	if southbound:
		barrier.rotation = PI / 2.0
		sensor.rotation = PI / 2.0
		caption.position += Vector2(-54, 14)
	super._ready()
	GameEvents.ravine_journal_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var open := Global.ravine_shortcut_open()
	barrier.set_deferred("disabled", open)
	caption.text = gate_name if open else gate_name + " · 未开"
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not Global.ravine_shortcut_open():
		GameEvents.world_notice.emit("交完三处水迹，蒲宁会指明这条小径。")
		return
	super._on_body_entered(body)

func _draw() -> void:
	var across := Vector2(15, 0) if southbound else Vector2(2, 15)
	for foot: Vector2 in [-across, across]:
		draw_rect(Rect2(foot + Vector2(-4, -1), Vector2(8, 4)), Color("#384734"))
		draw_rect(Rect2(foot + Vector2(-2, -16), Vector2(4, 17)), Color("#745c3e"))
		draw_rect(Rect2(foot + Vector2(-3, -16), Vector2(6, 3)), Color("#b5a273"))
	if not Global.ravine_shortcut_open():
		var rail := Vector2(0, -7)
		draw_line(rail - across, rail + across, Color("#514831"), 4.0)
		draw_line(rail - across - Vector2(0, 1), rail + across - Vector2(0, 1), Color("#a68b56"), 2.0)
