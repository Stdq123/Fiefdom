extends Node2D

const BASIN_ART := "res://assets/world/stillwater-stone.png"
const INSCRIPTION := preload("res://scripts/VillageInscription.gd")
const TRICKLE := preload("res://assets/audio/spring-trickle.wav")
const BASIN_REGION := Rect2(1, 1, 32, 26)
const WATER := Color("#568e87")
const WATER_LIGHT := Color("#a5d4bc")
const REACH := 18.0
const SPRING_WATER := Vector2(-2.5, -0.8)
const SPRING_HEARING := 84.0
const CANAL_HEARING := 64.0

@onready var hint: Label = $Hint
@onready var basin: StaticBody2D = $Basin
@onready var glints: Node2D = $Basin/Glints
@onready var runoff: Node2D = $Runoff
@onready var hint_top := hint.position.y
@onready var player: Node2D = $"../Player"
var outlets: Array[Vector2i] = []
var ripple_phase := 0.0
var focused := false
var basin_art: Texture2D = load(BASIN_ART)
var trickle: AudioStreamPlayer2D

func _ready() -> void:
	INSCRIPTION.place(self, Vector2(-23, -6), INSCRIPTION.Form.STONE, "水源")
	GamepadInput.changed.connect(_refresh_hint)
	Preferences.bindings_changed.connect(_refresh_hint)
	GameEvents.day_advanced.connect(_refresh_appearance.unbind(1))
	basin.draw.connect(_draw_basin)
	glints.draw.connect(_draw_glints)
	runoff.draw.connect(_draw_runoff)
	trickle = AudioStreamPlayer2D.new()
	trickle.name = "Trickle"
	trickle.bus = &"Ambience"
	trickle.max_distance = 200.0
	trickle.volume_linear = 0.0
	trickle.process_mode = Node.PROCESS_MODE_ALWAYS
	var stream: AudioStreamWAV = TRICKLE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	trickle.stream = stream
	add_child(trickle)
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	_place_hint()

func refresh(at: Vector2) -> void:
	global_position = at
	outlets.clear()
	var network := Global.irrigation
	for direction: Vector2i in Irrigation.NEIGHBORS:
		var direct_gate: bool = network.field_gates.get(network.source_cell + direction * 2) == network.source_cell
		if network.channels.has(network.source_cell + direction) or direct_gate:
			outlets.append(direction)
	_refresh_hint()
	_refresh_appearance()

func animate_water(frame: int, cycle_frames := 23) -> void:
	ripple_phase = fposmod(2.0 * frame / maxi(1, cycle_frames), 1.0)
	glints.queue_redraw()

func update_water_sound(listener: Vector2, canal: Vector2, delta: float) -> void:
	var spring := to_global(SPRING_WATER)
	var spring_gain := 0.0
	var canal_gain := 0.0
	if listener.is_finite():
		spring_gain = 0.43 * (1.0 - smoothstep(12.0, SPRING_HEARING, listener.distance_to(spring)))
		if canal.is_finite():
			canal_gain = 0.29 * (1.0 - smoothstep(17.0, CANAL_HEARING, listener.distance_to(canal)))
	var level := maxf(spring_gain, canal_gain)
	if level > 0.0:
		var canal_mix := canal_gain / (spring_gain + canal_gain)
		var at := spring.lerp(canal, canal_mix) if canal_gain > 0.0 else spring
		var ease_to := minf(1.0, 9.0 * delta)
		trickle.global_position = at if is_zero_approx(trickle.volume_linear) else trickle.global_position.lerp(at, ease_to)
		trickle.pitch_scale = lerpf(trickle.pitch_scale, lerpf(1.0, 0.92, canal_mix), ease_to)
		if Global.has_rain():
			level *= 0.55
		elif Global.season_index() == Global.Season.WINTER:
			level *= 0.82
	trickle.volume_linear = move_toward(trickle.volume_linear, level, delta * 0.95)
	if DisplayServer.get_name() != "headless":
		if trickle.volume_linear > 0.0 and not trickle.playing:
			trickle.play()
		elif is_zero_approx(trickle.volume_linear) and trickle.playing:
			trickle.stop()

func _refresh_appearance() -> void:
	basin.queue_redraw()
	runoff.queue_redraw()
	glints.queue_redraw()

func can_interact_from(foot: Vector2) -> bool:
	return (not Global.is_indoors() and Global.outcome == Global.Outcome.RUNNING
		and foot.distance_squared_to(global_position) <= REACH * REACH)

func interact() -> void:
	GameEvents.water_source_interacted.emit()

func set_interaction_focused(active: bool) -> void:
	focused = active
	set_physics_process(active)
	_place_hint()
	_refresh_hint()

func _place_hint() -> void:
	var behind := focused and player.global_position.y < global_position.y - 5.0
	hint.position.y = hint_top - (15.0 if behind else 0.0)

func _refresh_hint() -> void:
	var caption := "水源 · 量水尺" if Global.channel_survey_day > 0 else "水源"
	hint.text = GamepadInput.interact_hint(caption) if focused else caption
	hint.visible = focused
	hint.z_index = 1 if focused else -1
	hint.modulate = Color("#ffdfa0") if focused else Color("#c4e2ce")

func _draw_basin() -> void:
	var wall := -basin.position
	var stone_tint := Color("#cbd5cb") if Global.has_rain() else Color.WHITE
	var region := basin_region()
	basin.draw_texture_rect_region(basin_art, Rect2(wall + Vector2(-16, -12), region.size), region, stone_tint)
	for direction: Vector2i in outlets:
		var axis := Vector2(direction)
		var edge := axis * _outlet_length(direction)
		basin.draw_line(wall + axis * 5.0, wall + edge, Color("#384e45"), 4.0)
		basin.draw_line(wall + axis * 5.0, wall + edge, WATER, 2.0)
		basin.draw_line(wall + edge - axis * 3.0, wall + edge - axis, Color("#77ada0"), 1.0)
	if Global.channel_survey_day > 0:
		basin.draw_rect(Rect2(wall + Vector2(8, -17), Vector2(4, 15)), Color("#44392e"))
		basin.draw_rect(Rect2(wall + Vector2(9, -16), Vector2(2, 13)), Color("#d8b276"))
		for mark in [-14, -11, -8, -5]:
			basin.draw_rect(Rect2(wall + Vector2(9, mark), Vector2(2, 1)), Color("#73583b"))

func _draw_glints() -> void:
	var spring := -basin.position + SPRING_WATER
	for wave in 2:
		var phase := fposmod(ripple_phase + wave * 0.5, 1.0)
		var radius := lerpf(1.25, 5.0, phase)
		var arc := PackedVector2Array()
		for point in 8:
			var angle := -1.9 + point * 0.54 + wave * 1.6
			arc.append(spring + Vector2.from_angle(angle) * Vector2(radius, radius * 0.38))
		glints.draw_polyline(arc, Color(WATER_LIGHT, 0.56 * (1.0 - phase)), 0.55)
	for direction: Vector2i in outlets:
		var axis := Vector2(direction)
		var phase := fposmod(ripple_phase + float(Irrigation.NEIGHBORS.find(direction)) * 0.24, 1.0)
		var at := -basin.position + axis * lerpf(5.3, _outlet_length(direction) - 1.6, phase)
		glints.draw_line(at, at + axis * 1.65, Color(WATER_LIGHT, 0.76 * sin(phase * PI)), 0.75)

func _outlet_length(direction: Vector2i) -> float:
	if direction.x != 0:
		return 13.0
	return 8.0 if direction.y < 0 else 12.0

static func basin_region() -> Rect2:
	var region := BASIN_REGION
	if Global.season_index() == Global.Season.WINTER:
		region.position.y += 49
	return region

static func portrait() -> AtlasTexture:
	var stone := AtlasTexture.new()
	stone.atlas = load(BASIN_ART)
	stone.region = basin_region()
	stone.filter_clip = true
	return stone

func _draw_runoff() -> void:
	var shadow := Color("#2a3a32")
	shadow.a = 0.35 if Global.has_rain() else 0.54
	var fade := Color(shadow, 0.0)
	runoff.draw_polygon(PackedVector2Array([Vector2(-11, 4), Vector2(12, 4), Vector2(20, 8),
		Vector2(20, 13), Vector2(9, 16), Vector2(-7, 14), Vector2(-13, 10)]),
		PackedColorArray([shadow, shadow, fade, fade, fade, fade, fade]))
	for direction: Vector2i in outlets:
		var axis := Vector2(direction)
		runoff.draw_line(axis * 5.0, axis * 15.0, Color("#455a48"), 5.0)
		runoff.draw_line(axis * 5.0, axis * 15.0, WATER, 3.0)
