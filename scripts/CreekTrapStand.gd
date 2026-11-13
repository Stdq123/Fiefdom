extends Node2D

@export var site := CreekFish.Site.POOL
@export var stake_offset := Vector2(15, -7)
@export var water_offset := Vector2(50, -4)
@onready var hint: Label = $Hint
@onready var art := load(CreekTrap.ART) as Texture2D

var focused := false
var deployed := false
var catch_ready := false
var float_phase := 0.0

func _ready() -> void:
	GameEvents.fish_changed.connect(_refresh)
	GameEvents.creek_trap_changed.connect(_refresh)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	_refresh()

func can_interact_from(point: Vector2) -> bool:
	var approach := to_local(point)
	var distance := minf(approach.length_squared(), approach.distance_squared_to(stake_offset))
	return visible and distance <= 23.0 * 23.0

func set_interaction_focused(active: bool) -> void:
	focused = active
	_update_hint()

func interact() -> void:
	GameEvents.creek_trap_requested.emit(site)

func _refresh() -> void:
	visible = Global.creek_traps_unlocked()
	deployed = Global.creek_trap_site() == site
	catch_ready = deployed and Global.current_day >= Global.creek_trap_catch().day
	_update_hint()
	set_process(visible and deployed)
	queue_redraw()

func _update_hint() -> void:
	hint.visible = focused or catch_ready
	hint.text = "竹笼可收" if catch_ready else ("查看竹笼" if deployed else "下竹笼")
	if focused:
		hint.text = GamepadInput.interact_hint(hint.text)

func _process(delta: float) -> void:
	float_phase = fposmod(float_phase + delta * 2.8, TAU)
	queue_redraw()

func _draw() -> void:
	if deployed:
		var pot := water_offset + Vector2(0, roundf(sin(float_phase)))
		var ripple := Color("#cce0b987") if catch_ready else Color("#b2d2c25c")
		for side in [-1, 1]:
			var at := pot + Vector2(side * (13.0 + sin(float_phase) * 2.0), 3)
			draw_line(at, at + Vector2(side * 5, 0), ripple, 1.0)
		var anchor := stake_offset + Vector2(2, -7)
		var rim := pot - Vector2(signf(pot.x) * 9, 2)
		var rope := PackedVector2Array([anchor, anchor.lerp(rim, 0.54) + Vector2(0, 3), rim])
		draw_polyline(rope, Color("#4e513f"), 2.0)
		draw_polyline(rope, Color("#d1b579"), 1.0)
		draw_texture_rect_region(art, Rect2(pot - Vector2(14, 10), Vector2(28, 20)), Rect2(20, 0, 28, 20))
		if catch_ready:
			draw_rect(Rect2(pot + Vector2(6, -4), Vector2(4, 2)), Color("#eed17c"))
	draw_texture_rect_region(art, Rect2(stake_offset + Vector2(-9, -16), Vector2(20, 20)), Rect2(0, 0, 20, 20))
