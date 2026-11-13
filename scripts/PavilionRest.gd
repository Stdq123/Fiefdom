extends Node2D
class_name PavilionRest

const PLACE := "亭前晚坐"
const RAIN_PLACE := "亭东雨棚"
const START := (17.0 - Global.DAY_START_HOUR) / (Global.DAY_END_HOUR - Global.DAY_START_HOUR)
const SEATS := [Vector2(-25, 3), Vector2(12, -16), Vector2(-12, -13),
	Vector2(25, 0), Vector2(21, 22), Vector2(-22, 22)]
const RAIN_SEATS := [Vector2(-30, -8), Vector2(-10, -8), Vector2(10, -8),
	Vector2(30, -8), Vector2(29, 9), Vector2(-29, 9)]
const APPROACH := Vector2(0, 15)

@onready var hint: Label = $Hint
@onready var mats: Node2D = $Mats
@onready var dry_lamps: Node2D = $DryLamps
@onready var rain_lamps: Node2D = $RainLamps

func _ready() -> void:
	mats.draw.connect(_draw_mats)
	var lighting = $"../Landscape".day_lighting
	lighting.place_lamp(dry_lamps, Vector2(29, -11), 0.68, 0.09)
	lighting.place_lamp(rain_lamps, Vector2(-39, 11), 0.66, 0.07)
	lighting.place_lamp(rain_lamps, Vector2(39, 11), 0.66, 0.07)
	GameEvents.daylight_changed.connect(_refresh)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.raid_started.connect(_refresh)
	GameEvents.raid_defeated.connect(_refresh)
	GameEvents.campaign_ended.connect(_refresh.unbind(1))
	_refresh()

func _refresh() -> void:
	visible = Global.day_progress >= START and Global.raid_day == 0 \
		and Global.outcome == Global.Outcome.RUNNING
	var shelter := is_rain_shelter()
	var interaction_origin := gathering_approach() if shelter else gathering_center()
	if position != interaction_origin:
		position = interaction_origin
		mats.position = gathering_center() - position
		rain_lamps.position = mats.position
		mats.queue_redraw()
		queue_redraw()
	dry_lamps.visible = not shelter
	rain_lamps.visible = shelter
	if not visible:
		hint.hide()

func is_rain_shelter() -> bool:
	return Global.has_rain()

func gathering_name() -> String:
	return RAIN_PLACE if is_rain_shelter() else PLACE

func gathering_center() -> Vector2:
	return EstateLayout.PAVILION_SHELTER if is_rain_shelter() else EstateLayout.PAVILION_SEATS

func gathering_approach() -> Vector2:
	return EstateLayout.PAVILION_SHELTER_APPROACH if is_rain_shelter() else EstateLayout.PAVILION_SEATS + APPROACH

func seat_for(data: RetainerData) -> Vector2:
	var index := VisitorData.NEIGHBORS.find(data.name)
	if visible and data.duty != RetainerData.Duty.GUARD and index >= 0 and index < SEATS.size():
		var seats := RAIN_SEATS if is_rain_shelter() else SEATS
		return gathering_center() + seats[index]
	return Vector2.INF

func can_interact_from(foot: Vector2) -> bool:
	return is_visible_in_tree() and get_parent().to_local(foot).distance_to(gathering_approach()) < 13.0

func set_interaction_focused(focused: bool) -> void:
	hint.text = GamepadInput.interact_hint("今夜安排")
	hint.visible = focused

func interact() -> void:
	GameEvents.night_rations_requested.emit()

func _draw_mats() -> void:
	var seats := RAIN_SEATS if is_rain_shelter() else SEATS
	for seat: Vector2 in seats:
		var mat := Rect2(seat + Vector2(-9, -2), Vector2(18, 7))
		mats.draw_rect(mat, Color("#403b2b"))
		mats.draw_rect(mat.grow(-1), Color("#a58b60"))
		for stripe in range(2, 17, 3):
			mats.draw_rect(Rect2(mat.position + Vector2(stripe, 1), Vector2(1, 5)), Color("#786546"))

func _draw() -> void:
	draw_set_transform(gathering_center() - position)
	draw_rect(Rect2(-16, 0, 32, 4), Color("#27362d9c"))
	draw_rect(Rect2(-13, -4, 3, 7), Color("#4d372c"))
	draw_rect(Rect2(10, -4, 3, 7), Color("#4d372c"))
	draw_rect(Rect2(-15, -11, 30, 11), Color("#614638"))
	draw_rect(Rect2(-15, -11, 30, 8), Color("#a38156"))
	draw_rect(Rect2(-14, -10, 28, 1), Color("#c1a171"))
	for x in [-9, 7]:
		draw_rect(Rect2(x - 3, -7, 6, 4), Color("#664c3a"))
		draw_rect(Rect2(x - 3, -8, 6, 2), Color("#c6ad80"))
		draw_rect(Rect2(x - 2, -8, 4, 1), Color("#6e8380"))
	draw_rect(Rect2(-3, -15, 7, 9), Color("#805b4d"))
	draw_rect(Rect2(-1, -14, 2, 7), Color("#ae8062"))
	draw_rect(Rect2(-3, -16, 7, 2), Color("#cca36e"))
