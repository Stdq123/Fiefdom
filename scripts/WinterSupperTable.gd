extends Node2D

const SERVING_SOUND := preload("res://assets/audio/festival/supper-served.wav")
const ARRIVALS := [
	{"start": 0.50, "end": 0.67, "path": [Vector2(-38, 34), Vector2(-40, -8), Vector2(-30, -20)]},
	{"start": 0.55, "end": 0.71, "path": [Vector2(25, 48), Vector2(42, 30), Vector2(48, 9)]},
]
const FEET := [Vector2(-30, -20), Vector2(48, 9), Vector2(22, -17)]
const BOWL_TIMES := [0.0, 0.85]
const SEATED_FABRICS := [Color("#a67442"), Color("#575365")]
const HOST := 2
const COOK_CYCLE := 4.2
const POUR_START := 1.08
const POUR_END := 1.46
const TABLE_BOWL := Vector2(22.5, -9.0)
# Each mark holds the time in seconds and the spoon bowl's position relative to the table.
const LADLE_TRACK := [
	Vector3(0.0, 6.0, -28.0),
	Vector3(0.18, 2.0, -23.0),
	Vector3(0.42, 4.0, -23.0),
	Vector3(0.75, 8.0, -29.5),
	Vector3(0.93, 15.5, -26.0),
	Vector3(POUR_START, 21.0, -16.0),
	Vector3(POUR_END, 21.0, -16.0),
	Vector3(1.82, 14.0, -24.5),
	Vector3(2.15, 9.0, -27.0),
	Vector3(COOK_CYCLE, 6.0, -28.0),
]

@onready var guests: Node2D = $Guests
@onready var hint: Label = $Hint
@onready var hearth_glow: PointLight2D = $HearthGlow
@onready var fire_sound: AudioStreamPlayer2D = $FireSound
@onready var bowl_art: Texture2D = load("res://assets/characters/festival-supper.png")
@onready var hearth_art: Texture2D = load("res://assets/world/winter-hearth.png")
@onready var mats := Node2D.new()
@onready var table := Node2D.new()
@onready var steam_layer := Node2D.new()

var actors: Array[Node2D] = []
var motions: Array[NeighborMotion] = []
var serving_poses: Array[Sprite2D] = []
var routes: Array[Curve2D] = []
var focused := false
var recipe := ""
var steam := 0.0
var scoop_time := 0.0
var heated := false
var ember_frame := -1

func _ready() -> void:
	mats.name = "ReedMats"
	mats.z_index = -1
	table.name = "HearthTable"
	steam_layer.name = "Steam"
	steam_layer.z_index = 1
	add_child(mats)
	add_child(table)
	add_child(steam_layer)
	mats.draw.connect(_draw_mats)
	table.draw.connect(_draw_table)
	steam_layer.draw.connect(_draw_steam)
	for index in FEET.size():
		var actor := Node2D.new()
		actor.name = ["阿绥", "林蓼", WinterSupper.HOST][index]
		actor.position = FEET[index]
		guests.add_child(actor)
		var motion := NeighborMotion.new()
		motion.position.y = -13.0
		actor.add_child(motion)
		motion.set_festival_guest(index)
		actors.append(actor)
		motions.append(motion)
		if index < ARRIVALS.size():
			var guest_art := AtlasTexture.new()
			guest_art.atlas = bowl_art
			guest_art.region = Rect2(0, index * 32, 64, 32)
			var serving := Sprite2D.new()
			serving.position = motion.position
			serving.texture_filter = TEXTURE_FILTER_NEAREST
			serving.texture = guest_art
			serving.hframes = 2
			serving.hide()
			actor.add_child(serving)
			var seated := SeatedPose.new(serving)
			serving.add_child(seated)
			seated.present(SeatedPose.Surface.MAT, SEATED_FABRICS[index])
			serving_poses.append(serving)
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
	var next_recipe: String = Global.winter_supper_record().get("recipe", "") if visible else ""
	if recipe != next_recipe:
		scoop_time = 0.0
	recipe = next_recipe
	_set_hearth_active(visible and _hearth_lit())
	if visible:
		_sync_guests(true)
		_refresh_hint()
		ember_frame = 0 if heated else -1
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
	AudioManager.play_world_sfx(SERVING_SOUND, self, -10.0, 120.0)

func _process(delta: float) -> void:
	steam = fposmod(steam + delta, 2.8)
	if not recipe.is_empty():
		scoop_time = fposmod(scoop_time + delta, COOK_CYCLE)
		table.queue_redraw()
	_sync_guests()
	var lit := _hearth_lit()
	if lit != heated:
		_set_hearth_active(lit)
	var embers := int(steam * 4.0) % 4 if lit else -1
	if embers != ember_frame:
		ember_frame = embers
		hearth_glow.energy = 0.40 + 0.025 * float(ember_frame)
		table.queue_redraw()
	if steam_layer.visible:
		steam_layer.queue_redraw()

func _set_hearth_active(lit: bool) -> void:
	heated = lit
	hearth_glow.enabled = lit
	steam_layer.visible = lit and not recipe.is_empty()
	if DisplayServer.get_name() == "headless":
		return
	if lit and not fire_sound.playing:
		fire_sound.play()
	elif not lit and fire_sound.playing:
		fire_sound.stop()

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
		var at_table: bool = Global.day_progress >= arrival.end
		if at_table:
			motion.face(-point)
			motion.sit(SEATED_FABRICS[index])
		elif snap:
			motion.stand()
			motion.face(-point)
		elif not step.is_zero_approx():
			motion.walk(step)
		var serving := at_table and not recipe.is_empty()
		motion.visible = not serving
		serving_poses[index].visible = serving
		if serving:
			var beat: float = fposmod(steam + BOWL_TIMES[index], 2.8)
			serving_poses[index].frame = int(beat >= 1.25 and beat < 2.3)
	motions[HOST].face(Vector2.DOWN if recipe.is_empty() else Vector2.LEFT)

func _hearth_lit() -> bool:
	return not recipe.is_empty() or Global.day_progress >= WinterSupper.EVENING

func _draw_mats() -> void:
	for index in ARRIVALS.size():
		SeatedPose.draw_reed_mat(mats, FEET[index])

func _draw_table() -> void:
	var meal := 0 if recipe.is_empty() else (2 if recipe == WinterSupper.FISH else 1)
	var fire := ember_frame + 1 if heated else 0
	var size := Vector2(96, 56)
	table.draw_texture_rect_region(hearth_art, Rect2(Vector2(-48, -44), size), Rect2(Vector2(meal, fire) * size, size))
	if not recipe.is_empty():
		_draw_ladle()

func _ladle_bowl() -> Vector2:
	for index in range(1, LADLE_TRACK.size()):
		var next: Vector3 = LADLE_TRACK[index]
		if scoop_time <= next.x:
			var previous: Vector3 = LADLE_TRACK[index - 1]
			return Vector2(previous.y, previous.z).lerp(Vector2(next.y, next.z),
				smoothstep(previous.x, next.x, scoop_time)).snappedf(0.5)
	return Vector2(LADLE_TRACK[0].y, LADLE_TRACK[0].z)

func _draw_ladle() -> void:
	var bowl := _ladle_bowl()
	var shoulder := FEET[HOST] + Vector2(-2.0, -11.5)
	var grip := (bowl + bowl.direction_to(shoulder + Vector2(1.5, -0.5)) * 11.5).snappedf(0.5)
	var elbow := shoulder.lerp(grip, 0.45) + Vector2(0.75, 2.0)
	var tilt := smoothstep(POUR_START, POUR_START + 0.08, scoop_time) * (1.0 - smoothstep(POUR_END - 0.10, POUR_END, scoop_time))
	table.draw_line(grip, bowl, Color("#493029"), 1.8, true)
	table.draw_line(grip + Vector2(0, -0.35), bowl + Vector2(0, -0.35), Color("#b88551"), 0.7, true)
	table.draw_set_transform(bowl, tilt * 0.6)
	table.draw_colored_polygon(PackedVector2Array([
		Vector2(-2.5, -0.5), Vector2(-1.5, -1.25), Vector2(1.5, -1.25), Vector2(2.5, -0.25),
		Vector2(1.25, 1.5), Vector2(-1.25, 1.5),
	]), Color("#6c4731"))
	table.draw_line(Vector2(-1.5, -0.5), Vector2(1.5, -0.5), Color("#d6a368"), 0.8, true)
	table.draw_set_transform_matrix(Transform2D.IDENTITY)
	ToolGesture.draw_sleeve(table, shoulder, elbow, grip, Color("#86754d"), false)
	if tilt > 0.5:
		var broth := Color("#e9ba7c") if recipe == WinterSupper.BEAN else Color("#d99665")
		var lip := bowl + Vector2(1.25, 1.25)
		table.draw_line(lip, TABLE_BOWL, broth.darkened(0.30), 1.35, true)
		var drop := lip.lerp(TABLE_BOWL, fposmod(scoop_time * 10.0, 1.0))
		table.draw_line(drop, drop.move_toward(TABLE_BOWL, 2.0), broth, 0.7, true)
		table.draw_line(TABLE_BOWL - Vector2(1.0, 0.0), TABLE_BOWL + Vector2(1.0, 0.0), broth, 0.7, true)

func _draw_steam() -> void:
	if recipe.is_empty():
		return
	for index in 3:
		var rise := fposmod(steam + index * 0.90, 2.8) / 2.8
		var at := Vector2(index * 3.5 - 4 + sin(rise * TAU) * 1.8 + rise * 5.0, -24.0 - rise * 17.0)
		var curl := 1.4 * sin(rise * TAU + index)
		var plume := PackedVector2Array([at, at + Vector2(curl, -2), at + Vector2(curl + 1.2, -4), at + Vector2(0.5, -6)])
		steam_layer.draw_polyline(plume, Color(1.0, 0.94, 0.84, sin(rise * PI) * 0.5), 0.95, true)
