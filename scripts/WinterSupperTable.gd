extends Node2D

const SERVING_SOUND := preload("res://assets/audio/water-2.wav")
const ARRIVALS := [
	{"start": 0.50, "end": 0.67, "path": [Vector2(-71, 61), Vector2(-38, 34), Vector2(-40, -8), Vector2(-30, -20)]},
	{"start": 0.55, "end": 0.71, "path": [Vector2(-78, 70), Vector2(35, 34), Vector2(48, 9)]},
]
const FEET := [Vector2(-30, -20), Vector2(48, 9), Vector2(22, -17)]

@onready var guests: Node2D = $Guests
@onready var hint: Label = $Hint

var actors: Array[Node2D] = []
var motions: Array[NeighborMotion] = []
var routes: Array[Curve2D] = []
var focused := false
var recipe := ""
var steam := 0.0

func _ready() -> void:
	for index in FEET.size():
		var actor := Node2D.new()
		actor.name = ["阿绥", "林蓼", WinterSupper.HOST][index]
		actor.position = FEET[index]
		guests.add_child(actor)
		var motion := NeighborMotion.new()
		motion.position.y = -6.0
		actor.add_child(motion)
		motion.set_motion_sheet(WinterSupper.guest_art(index))
		actors.append(actor)
		motions.append(motion)
	for arrival: Dictionary in ARRIVALS:
		var route := Curve2D.new()
		for point: Vector2 in arrival.path:
			route.add_point(point)
		routes.append(route)
	var lighting = $"../Landscape".day_lighting
	lighting.place_lamp($Lanterns, Vector2(-44, -5), 0.72, 0.07)
	lighting.place_lamp($Lanterns, Vector2(48, -9), 0.72, 0.13)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.campaign_ended.connect(_refresh.unbind(1))
	GameEvents.winter_supper_prepared.connect(_on_prepared)
	GamepadInput.changed.connect(_refresh_hint)
	_refresh()

func _refresh() -> void:
	visible = Global.outcome == Global.Outcome.RUNNING and Global.is_winter_supper_day()
	$Footprint/Shape.set_deferred("disabled", not visible)
	set_process(visible)
	for motion in motions:
		motion.set_process(visible)
	if visible:
		recipe = Global.winter_supper_record().get("recipe", "")
		_sync_guests(true)
		_refresh_hint()
		queue_redraw()

func can_interact_from(foot: Vector2) -> bool:
	var at := to_local(foot)
	return is_visible_in_tree() and absf(at.x) < 40.0 and at.y >= 7.0 and at.y < 34.0

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh_hint()

func interact() -> void:
	GameEvents.winter_supper_requested.emit()

func _refresh_hint() -> void:
	hint.text = WinterSupper.PLACE + (" · " + GamepadInput.interact_key() if focused else "")
	hint.modulate = Color("#ffe6b6") if focused else Color("#e4c998")

func _on_prepared() -> void:
	_refresh()
	AudioManager.play_world_sfx(SERVING_SOUND, self, -12.0, 110.0)

func _process(delta: float) -> void:
	steam = fposmod(steam + delta, 2.8)
	_sync_guests()
	queue_redraw()

func _sync_guests(snap := false) -> void:
	for index in ARRIVALS.size():
		var arrival: Dictionary = ARRIVALS[index]
		var route := routes[index]
		var guest := actors[index]
		var motion := motions[index]
		guest.visible = Global.day_progress >= arrival.start
		var progress := smoothstep(arrival.start, arrival.end, Global.day_progress)
		var point := route.sample_baked(route.get_baked_length() * progress).round()
		var step := point - guest.position
		guest.position = point
		if snap or progress >= 1.0:
			motion.stand()
			motion.face(-point)
		elif not step.is_zero_approx():
			motion.walk(step)

func _draw() -> void:
	draw_rect(Rect2(-35, 1, 70, 11), Color("#2d3d3888"))
	draw_rect(Rect2(42, 5, 10, 7), Color("#4a3428"))
	draw_rect(Rect2(42, 3, 10, 4), Color("#a58057"))
	draw_rect(Rect2(-29, -1, 5, 10), Color("#4a3125"))
	draw_rect(Rect2(24, -1, 5, 10), Color("#4a3125"))
	draw_rect(Rect2(-34, -12, 68, 16), Color("#43312a"))
	draw_rect(Rect2(-33, -16, 66, 15), Color("#896044"))
	draw_rect(Rect2(-31, -16, 62, 2), Color("#b48a5a"))
	draw_rect(Rect2(-33, -2, 66, 3), Color("#6d4933"))
	draw_rect(Rect2(-11, -16, 22, 18), Color("#4e6569"))
	draw_rect(Rect2(-11, -15, 22, 2), Color("#879a89"))
	draw_rect(Rect2(-10, 0, 20, 2), Color("#d1b579"))
	draw_rect(Rect2(-6, -12, 12, 7), Color("#343027"))
	draw_rect(Rect2(-4, -9, 8, 2), Color("#be734e"))
	draw_rect(Rect2(-7, -19, 14, 9), Color("#51574b"))
	draw_rect(Rect2(-5, -11, 10, 2), Color("#44473d"))
	draw_rect(Rect2(-8, -21, 16, 3), Color("#b18d60"))
	draw_rect(Rect2(-5, -22, 10, 2), Color("#d0aa76"))
	draw_rect(Rect2(-2, -24, 4, 2), Color("#8b654a"))
	draw_rect(Rect2(-6, -17, 2, 5), Color("#8e8961"))
	draw_rect(Rect2(-10, -17, 3, 2), Color("#ad8454"))
	draw_rect(Rect2(7, -17, 3, 2), Color("#ad8454"))
	var filled := not recipe.is_empty() or Global.day_progress >= WinterSupper.EVENING
	for x in [-23, 22]:
		draw_rect(Rect2(x - 5, -11, 10, 6), Color("#504f44"))
		draw_rect(Rect2(x - 5, -12, 10, 3), Color("#b6b8a4"))
		draw_rect(Rect2(x - 4, -6, 9, 1), Color("#c79e72"))
		if filled:
			draw_rect(Rect2(x - 3, -11, 6, 2), Color("#efc17d") if recipe == WinterSupper.FISH else Color("#eadba3"))
	if filled:
		for index in 3:
			var rise := fposmod(steam + index * 0.9, 2.8) / 2.8
			var at := Vector2(-3.0 + floorf(rise * 9.0), -25.0 - floorf(rise * 16.0))
			draw_rect(Rect2(at, Vector2(3.0, 2.0)), Color(1.0, 0.92, 0.77, (1.0 - rise) * 0.66))
