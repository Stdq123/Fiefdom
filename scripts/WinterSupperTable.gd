extends Node2D

const SERVING_SOUND := preload("res://assets/audio/water-2.wav")
const ARRIVALS := [
	{"start": 0.50, "end": 0.67, "path": [Vector2(-38, 34), Vector2(-40, -8), Vector2(-30, -20)]},
	{"start": 0.55, "end": 0.71, "path": [Vector2(25, 48), Vector2(42, 30), Vector2(48, 9)]},
]
const FEET := [Vector2(-30, -20), Vector2(48, 9), Vector2(22, -17)]

@onready var guests: Node2D = $Guests
@onready var hint: Label = $Hint

var actors: Array[Node2D] = []
var motions: Array[NeighborMotion] = []
var routes: Array[Curve2D] = []
var table := Node2D.new()
var steam_layer := Node2D.new()
var focused := false
var recipe := ""
var steam := 0.0
var heated := false
var ember_frame := -1

func _ready() -> void:
	table.name = "HearthTable"
	steam_layer.name = "Steam"
	steam_layer.z_index = 1
	add_child(table)
	add_child(steam_layer)
	table.draw.connect(_draw_table)
	steam_layer.draw.connect(_draw_steam)
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
		for point in EstateLayout.festival_entrance():
			route.add_point(point)
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
		heated = _hearth_lit()
		ember_frame = 0 if heated else -1
		steam_layer.visible = heated
		table.queue_redraw()
		steam_layer.queue_redraw()

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
	var lit := _hearth_lit()
	var embers := int(steam * 4.0) % 4 if lit else -1
	if lit != heated or embers != ember_frame:
		heated = lit
		ember_frame = embers
		table.queue_redraw()
	steam_layer.visible = lit
	if lit:
		steam_layer.queue_redraw()

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

func _hearth_lit() -> bool:
	return not recipe.is_empty() or Global.day_progress >= WinterSupper.EVENING

func _draw_table() -> void:
	table.draw_colored_polygon(PackedVector2Array([Vector2(-37, 1), Vector2(34, 1),
		Vector2(45, 10), Vector2(36, 13), Vector2(-33, 10)]), Color("#2832328c"))
	for x in [-29, 24]:
		table.draw_rect(Rect2(x, -1, 5, 10), Color("#4a3125"))
		table.draw_rect(Rect2(x + 1, 2, 2, 6), Color("#816045"))
	table.draw_colored_polygon(PackedVector2Array([Vector2(-34, 0), Vector2(29, 0), Vector2(37, -8),
		Vector2(37, -3), Vector2(30, 5), Vector2(-34, 5)]), Color("#503a2c"))
	table.draw_colored_polygon(PackedVector2Array([Vector2(-35, -3), Vector2(28, -3),
		Vector2(37, -13), Vector2(-28, -13)]), Color("#a07850"))
	table.draw_line(Vector2(-33, -4), Vector2(28, -4), Color("#bd9565"), 1.0)
	for x in [-29, -16, 16, 26]:
		table.draw_rect(Rect2(x, -7 - posmod(x, 3), 7, 1), Color("#d7aa6b8a"))
	table.draw_colored_polygon(PackedVector2Array([Vector2(-13, 2), Vector2(9, 2), Vector2(14, -3),
		Vector2(14, -12), Vector2(9, -13), Vector2(-11, -13), Vector2(-13, -9)]), Color("#53534a"))
	table.draw_rect(Rect2(-11, -10, 21, 3), Color("#918270"))
	table.draw_rect(Rect2(-7, -7, 13, 7), Color("#343027"))
	if heated:
		table.draw_rect(Rect2(-5, -4, 9, 2), Color("#ba6645"))
		table.draw_rect(Rect2(-3 + ember_frame, -4, 3, 1), Color("#efad63"))
	table.draw_colored_polygon(PackedVector2Array([Vector2(-12, -21), Vector2(13, -21), Vector2(10, -13),
		Vector2(6, -11), Vector2(-6, -11), Vector2(-10, -14)]), Color("#555e4b"))
	table.draw_rect(Rect2(-8, -19, 2, 5), Color("#869074"))
	table.draw_rect(Rect2(-14, -20, 4, 3), Color("#ab925f"))
	table.draw_rect(Rect2(11, -20, 4, 3), Color("#948057"))
	table.draw_colored_polygon(PackedVector2Array([Vector2(-13, -21), Vector2(-8, -25), Vector2(7, -25),
		Vector2(13, -22), Vector2(9, -19), Vector2(-9, -19)]), Color("#b59563"))
	table.draw_rect(Rect2(-6, -24, 12, 1), Color("#d5b780"))
	table.draw_rect(Rect2(-2, -27, 4, 3), Color("#785d43"))
	for x in [-23, 23]:
		table.draw_rect(Rect2(x - 6, -10, 12, 5), Color("#654f3b"))
		table.draw_colored_polygon(PackedVector2Array([Vector2(x - 6, -9), Vector2(x - 3, -12),
			Vector2(x + 4, -12), Vector2(x + 6, -10), Vector2(x + 3, -7), Vector2(x - 3, -7)]), Color("#c2b298"))
		var topping := Color("#8c7760")
		if heated:
			topping = Color("#e9ae72") if recipe == WinterSupper.FISH else Color("#e4c998")
		table.draw_rect(Rect2(x - 3, -10, 6, 2), topping)

func _draw_steam() -> void:
	if not heated:
		return
	for index in 3:
		var rise := fposmod(steam + index * 0.90, 2.8) / 2.8
		var at := Vector2(float(index * 4 - 5) + roundf(sin(rise * TAU) * 2.0 + rise * 7.0), -27.0 - roundf(rise * 18.0))
		var tint := Color(1.0, 0.93, 0.80, (1.0 - rise) * 0.63)
		steam_layer.draw_rect(Rect2(at, Vector2(2 + index % 2, 2)), tint)
		steam_layer.draw_rect(Rect2(at + Vector2(2, -3), Vector2(3 + index % 2, 1)), Color(tint, tint.a * 0.65))
