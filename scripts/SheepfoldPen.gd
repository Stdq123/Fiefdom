extends Node2D

const BLEAT := preload("res://assets/world/sheepfold/sheep-bleat.ogg")
const TERRAIN := preload("res://scripts/EstateTerrain.gd")
const SHELTER := Vector2(-12, 7)
const FEEDING_SPOT := Vector2(3, 18)
const WALK_TO_FEED := 0.18
const AT_TROUGH := 0.23
const LEAVE_TROUGH := 0.43
const BACK_IN_SHELTER := 0.48
const ROUTE := [SHELTER, Vector2(-23, 30), Vector2(8, 40), Vector2(28, 27), Vector2(12, 20), SHELTER]
const PADDOCK := [Vector2(-43, 1), Vector2(42, 1), Vector2(44, 48),
	Vector2(37, 54), Vector2(13, 52), Vector2(9, 59), Vector2(-11, 59),
	Vector2(-15, 53), Vector2(-36, 55), Vector2(-44, 48)]
const LANE_WEST := [Vector2(-7, 65), Vector2(-7, 53), Vector2(-4, 44),
	Vector2(-1, 36), Vector2(3, 28), Vector2(10, 17)]
const LANE_EAST := [Vector2(7, 65), Vector2(8, 52), Vector2(9, 44),
	Vector2(11, 36), Vector2(16, 28), Vector2(22, 18)]
const SCUFFED_GROUND := [Vector2(-28, 2), Vector2(-15, 2), Vector2(-8, 7), Vector2(14, 9),
	Vector2(31, 9), Vector2(32, 17), Vector2(22, 22), Vector2(10, 19), Vector2(-4, 17),
	Vector2(-16, 16), Vector2(-25, 11)]
const YARD_SPRIGS := [Vector2(-36, 19), Vector2(-36, 43), Vector2(-25, 48), Vector2(-20, 34),
	Vector2(32, 34), Vector2(37, 24), Vector2(35, 48), Vector2(18, 47)]
const GRAVEL := [Vector2(-3, 57), Vector2(3, 52), Vector2(-2, 46), Vector2(4, 41),
	Vector2(6, 34), Vector2(12, 28)]

@onready var animal: SheepMotion = $Paddock/Sheep
@onready var landscape: Node2D = $"../Landscape"
@onready var ground: Node2D = $Paddock/Yard
@onready var hay: Sprite2D = $Paddock/Trough/Fodder
@onready var haystack: Node2D = $Paddock/Haystack
@onready var clipping: Sprite2D = $Paddock/Clipping
@onready var hint: Label = $Paddock/Hint

var pose_time := 0.0
var focused := false

func _ready() -> void:
	ground.draw.connect(_draw_yard)
	landscape.day_lighting.place_lamp($Paddock, Vector2(-32, 4), 0.70)
	GameEvents.sheepfold_changed.connect(_refresh)
	GameEvents.sheep_sheared.connect(_on_sheared)
	GameEvents.day_advanced.connect(_refresh_weather.unbind(1))
	_refresh_weather()
	_refresh()

func _refresh_weather() -> void:
	var timber := Color("#bdc8bf") if Global.has_rain() else Color.WHITE
	for fixture: Sprite2D in [$Paddock/Shed, $Paddock/RearFence, $Paddock/FrontFence, $Paddock/Trough]:
		fixture.self_modulate = timber
	$Paddock/Shed/RoofFrost.visible = Global.season_index() == Global.Season.WINTER
	ground.queue_redraw()

func _refresh() -> void:
	var flock := Global.sheepfold
	visible = flock.owned()
	set_process(visible)
	for shape: CollisionShape2D in $Paddock/Barriers.get_children():
		shape.set_deferred("disabled", not visible)
	if not visible:
		return
	animal.full_fleece = flock.wool_nights >= mini(3, Global.balance.sheep_wool_nights)
	hay.visible = flock.fodder > 0
	for bale: Sprite2D in haystack.get_children():
		bale.visible = bale.get_index() < flock.fodder
	var ready := Global.can_use_sheepfold(Sheepfold.Action.SHEAR)
	$Paddock/Wool.visible = ready
	_refresh_hint()
	_update_sheep(0.0)

func _process(delta: float) -> void:
	_update_sheep(delta)

func _update_sheep(delta: float) -> void:
	var foot := SHELTER
	var heading := Vector2.RIGHT
	var clock := Global.day_progress
	var pasture := Global.sheep_can_graze()
	var grazing := pasture and clock > 0.05 and clock < 0.76
	var at_trough := false
	var grazing_at_rest := false
	if grazing:
		var progress := inverse_lerp(0.05, 0.76, clock) * (ROUTE.size() - 1)
		var segment := mini(floori(progress), ROUTE.size() - 2)
		var step := progress - segment
		heading = ROUTE[segment + 1] - ROUTE[segment]
		foot = ROUTE[segment].lerp(ROUTE[segment + 1], smoothstep(0.0, 0.65, step))
		grazing_at_rest = step >= 0.65
	elif not pasture and hay.visible:
		var trip := smoothstep(WALK_TO_FEED, AT_TROUGH, clock) * (1.0 - smoothstep(LEAVE_TROUGH, BACK_IN_SHELTER, clock))
		foot = SHELTER.lerp(FEEDING_SPOT, trip)
		at_trough = clock >= AT_TROUGH and clock <= LEAVE_TROUGH
		if clock > LEAVE_TROUGH and clock < BACK_IN_SHELTER:
			heading = SHELTER - FEEDING_SPOT
	pose_time = fposmod(pose_time + delta, 4.0)
	var dip := 0.0
	if at_trough:
		dip = 0.78 + sin(pose_time * TAU) * 0.12
	elif grazing_at_rest:
		dip = 0.91 + sin(pose_time * TAU) * 0.08
	animal.present(foot, heading, dip, delta)

func _draw_yard() -> void:
	var season := Global.season_index()
	var wet := Global.has_rain()
	var grass := Color("#a8b7a7") if wet else Color("#d7ded1")
	var meadow := TERRAIN.meadow_texture(season)
	var boundary := PackedVector2Array(PADDOCK)
	var turf_edge := boundary.duplicate()
	turf_edge.append(boundary[0])
	var verge := PackedVector2Array()
	for point in turf_edge:
		verge.append(point + Vector2(0, 26).direction_to(point) * 6.0)
	TERRAIN.draw_tiled_band(ground, turf_edge, verge, grass, Color(grass, 0.0), meadow)
	TERRAIN.draw_loam(ground, boundary, grass, meadow)
	var dust: Color = landscape._track_dust()
	TERRAIN.draw_loam(ground, PackedVector2Array(SCUFFED_GROUND), Color(dust.darkened(0.27), 0.82), TERRAIN.TRACK_GRAIN)
	var west := PackedVector2Array(LANE_WEST)
	var east := PackedVector2Array(LANE_EAST)
	var shoulder := Color(dust.darkened(0.18), 0.55)
	for side in [-1, 1]:
		var rim := west if side < 0 else east
		var outer := rim.duplicate()
		for index in outer.size():
			outer[index].x += side * 3.0
		TERRAIN.draw_tiled_band(ground, rim, outer, shoulder, Color(dust, 0.0), TERRAIN.TRACK_GRAIN)
	TERRAIN.draw_tiled_band(ground, west, east, dust, dust.darkened(0.10), TERRAIN.TRACK_GRAIN)

	var shale := dust.lerp(Color("#a8afa5"), 0.47)
	for index in GRAVEL.size():
		var at: Vector2 = GRAVEL[index]
		var span := 3.0 + index % 3
		ground.draw_colored_polygon(PackedVector2Array([
			at, at + Vector2(span, -0.5), at + Vector2(span + 1, 1.5), at + Vector2(1, 2),
		]), shale.darkened(0.33))
		ground.draw_line(at, at + Vector2(span, -0.5), shale.lightened(0.10), 0.85)
	for index in YARD_SPRIGS.size():
		TERRAIN.draw_sprig(ground, YARD_SPRIGS[index], index * 17, season, wet)
	if season == Global.Season.WINTER:
		TERRAIN.draw_snow(ground, Rect2(-44, 37, 29, 17), 2)
		TERRAIN.draw_snow(ground, Rect2(13, 40, 31, 15), 1)
	elif wet:
		ground.draw_colored_polygon(PackedVector2Array([
			Vector2(13, 20), Vector2(25, 19), Vector2(30, 22), Vector2(21, 24), Vector2(11, 23),
		]), Color("#536c60a0"))
		ground.draw_line(Vector2(17, 21), Vector2(24, 20.5), Color("#adc0ab91"), 0.75)

func can_interact_from(foot: Vector2) -> bool:
	return visible and global_position.distance_squared_to(foot) <= 26.0 * 26.0

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh_hint()

func _refresh_hint() -> void:
	hint.visible = focused or clipping.visible
	if clipping.visible:
		hint.text = "羊毛 +1"
		return
	hint.text = GamepadInput.interact_hint("羊毛可剪" if $Paddock/Wool.visible else "西坡羊棚")

func interact() -> void:
	GameEvents.sheepfold_requested.emit()

func _on_sheared() -> void:
	AudioManager.play_world_sfx(BLEAT, animal, -15.0, 125.0)
	var landing := animal.position + Vector2(-13 if animal.flip_h else 13, 5)
	clipping.position = animal.position + animal.fleece_contact()
	clipping.modulate.a = 1.0
	clipping.show()
	var fall := create_tween().set_parallel(true)
	fall.tween_property(clipping, "position:x", landing.x, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall.tween_property(clipping, "position:y", clipping.position.y - 4.0, 0.08)
	fall.chain().tween_property(clipping, "position:y", landing.y, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.chain().tween_property(clipping, "modulate:a", 0.0, 0.25).set_delay(0.85)
	fall.chain().tween_callback(_finish_clipping)

func _finish_clipping() -> void:
	clipping.hide()
	_refresh_hint()
