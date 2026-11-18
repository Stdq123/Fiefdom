extends Node2D

const SERVING_SOUND := preload("res://assets/audio/festival/supper-served.wav")
const ARRIVALS := [
	{"start": 0.50, "end": 0.67, "path": [Vector2(-38, 34), Vector2(-40, -8), Vector2(-30, -20)]},
	{"start": 0.55, "end": 0.71, "path": [Vector2(25, 48), Vector2(42, 30), Vector2(48, 9)]},
]
const FEET := [Vector2(-30, -20), Vector2(48, 9), Vector2(22, -17)]
const BOWL_TIMES := [0.0, 0.85, 1.55]

@onready var guests: Node2D = $Guests
@onready var hint: Label = $Hint
@onready var hearth_glow: PointLight2D = $HearthGlow
@onready var fire_sound: AudioStreamPlayer2D = $FireSound
@onready var bowl_art: Texture2D = load("res://assets/characters/festival-supper.png")
@onready var hearth_art: Texture2D = load("res://assets/world/winter-hearth.png")

var actors: Array[Node2D] = []
var motions: Array[NeighborMotion] = []
var serving_poses: Array[Sprite2D] = []
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
		motion.position.y = -13.0
		actor.add_child(motion)
		motion.set_festival_guest(index)
		var serving := Sprite2D.new()
		serving.position = motion.position
		serving.texture_filter = TEXTURE_FILTER_NEAREST
		serving.texture = bowl_art
		serving.hframes = 2
		serving.vframes = FEET.size()
		serving.hide()
		actor.add_child(serving)
		actors.append(actor)
		motions.append(motion)
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
	recipe = Global.winter_supper_record().get("recipe", "") if visible else ""
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
		if snap or progress >= 1.0:
			motion.stand()
			motion.face(-point)
		elif not step.is_zero_approx():
			motion.walk(step)
	for index in serving_poses.size():
		var at_table: bool = index >= ARRIVALS.size() or Global.day_progress >= ARRIVALS[index].end
		var serving := at_table and not recipe.is_empty()
		motions[index].visible = not serving
		serving_poses[index].visible = serving
		if serving:
			var beat: float = fposmod(steam + BOWL_TIMES[index], 2.8)
			serving_poses[index].frame_coords = Vector2i(int(beat >= 1.25 and beat < 2.3), index)

func _hearth_lit() -> bool:
	return not recipe.is_empty() or Global.day_progress >= WinterSupper.EVENING

func _draw_table() -> void:
	var meal := 0 if recipe.is_empty() else (2 if recipe == WinterSupper.FISH else 1)
	var fire := ember_frame + 1 if heated else 0
	var size := Vector2(96, 56)
	table.draw_texture_rect_region(hearth_art, Rect2(Vector2(-48, -44), size), Rect2(Vector2(meal, fire) * size, size))

func _draw_steam() -> void:
	if recipe.is_empty():
		return
	for index in 3:
		var rise := fposmod(steam + index * 0.90, 2.8) / 2.8
		var at := Vector2(index * 3.5 - 4 + sin(rise * TAU) * 1.8 + rise * 5.0, -24.0 - rise * 17.0)
		var curl := 1.4 * sin(rise * TAU + index)
		var plume := PackedVector2Array([at, at + Vector2(curl, -2), at + Vector2(curl + 1.2, -4), at + Vector2(0.5, -6)])
		steam_layer.draw_polyline(plume, Color(1.0, 0.94, 0.84, sin(rise * PI) * 0.5), 0.95, true)
