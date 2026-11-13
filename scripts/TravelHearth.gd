extends Node2D
class_name TravelHearth

const PLACE := "南路灶台"
const PORTRAIT := preload("res://assets/world/travel-hearth.svg")
const PACK_SOUND := preload("res://assets/audio/water-2.wav")

@onready var hint: Label = $Hint
@onready var glow: PointLight2D = $Glow

var fire_phase := 0.0

func _ready() -> void:
	GameEvents.inventory_changed.connect(_refresh_fire.unbind(1))
	GameEvents.travel_meal_changed.connect(_on_meal_changed)
	_refresh_fire()

func _refresh_fire() -> void:
	glow.enabled = Global.travel_hearth_open()
	set_process(glow.enabled)
	queue_redraw()

func _process(delta: float) -> void:
	fire_phase = fposmod(fire_phase + delta, 3.2)
	glow.energy = 0.38 + Global.dusk_amount() * 0.44 + sin(fire_phase / 3.2 * TAU * 3.0) * 0.05
	queue_redraw()

func _draw() -> void:
	if not glow.enabled:
		return
	var flicker := floori(fire_phase * 5.0) % 2
	draw_rect(Rect2(-2, -4, 11, 3), Color("#a85339"))
	draw_rect(Rect2(0, -7, 7, 5), Color("#e79050"))
	draw_rect(Rect2(3, -8 - flicker, 2, 5 + flicker), Color("#ffd18a"))
	for index in 3:
		var rise := fposmod(fire_phase + index * 1.06, 3.2) / 3.2
		var at := Vector2(1.0 + floorf(rise * 9.0), -24.0 - floorf(rise * 13.0))
		draw_rect(Rect2(at, Vector2(2.0 + floorf(rise * 3.0), 2.0)), Color(0.89, 0.84, 0.68, (1.0 - rise) * 0.65))

func can_interact_from(foot: Vector2) -> bool:
	var at := to_local(foot)
	return absf(at.x) < 39.0 and at.y >= 2.0 and at.y < 29.0

func set_interaction_focused(active: bool) -> void:
	hint.visible = active
	if active:
		hint.text = GamepadInput.interact_hint("灶台")

func interact() -> void:
	GameEvents.travel_hearth_interacted.emit()

func _on_meal_changed() -> void:
	if not Global.travel_meal.is_empty():
		AudioManager.play_world_sfx(PACK_SOUND, self, -12.0, 86.0)
