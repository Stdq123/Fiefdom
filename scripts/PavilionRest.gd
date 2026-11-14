extends Node2D
class_name PavilionRest

const PLACE := "亭前晚坐"
const RAIN_PLACE := "亭东雨棚"
const START := (17.0 - Global.DAY_START_HOUR) / (Global.DAY_END_HOUR - Global.DAY_START_HOUR)
const RAIN_START := (15.0 - Global.DAY_START_HOUR) / (Global.DAY_END_HOUR - Global.DAY_START_HOUR)
const SEATS := [Vector2(-25, 3), Vector2(12, -16), Vector2(-12, -13),
	Vector2(25, 0), Vector2(21, 22), Vector2(-22, 22)]
const RAIN_SEATS := [Vector2(-30, -10), Vector2(-11, -14), Vector2(10, -14),
	Vector2(30, -10), Vector2(30, 10), Vector2(-28, 10)]
const GUEST_SEAT := Vector2(8, 20)
const RAIN_GUEST_SEAT := Vector2(8, 13)
const APPROACH := Vector2(0, 15)

@onready var hint: Label = $Hint
@onready var mats: Node2D = $Mats
@onready var dry_lamps: Node2D = $DryLamps
@onready var rain_lamps: Node2D = $RainLamps
var focused := false

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
	var shelter := is_rain_shelter()
	visible = Global.day_progress >= rest_start() and Global.raid_day == 0 \
		and Global.outcome == Global.Outcome.RUNNING
	var approach := gathering_approach()
	if position != approach:
		position = approach
		mats.position = gathering_center() - position
		dry_lamps.position = mats.position
		rain_lamps.position = mats.position
	refresh_table()
	dry_lamps.visible = not shelter
	rain_lamps.visible = shelter

func refresh_table() -> void:
	mats.queue_redraw()
	queue_redraw()
	_refresh_hint()

func is_rain_shelter() -> bool:
	return Global.has_rain()

static func rest_start() -> float:
	return RAIN_START if Global.has_rain() else START

func gathering_name() -> String:
	return RAIN_PLACE if is_rain_shelter() else PLACE

func gathering_center() -> Vector2:
	return EstateLayout.PAVILION_SHELTER if is_rain_shelter() else EstateLayout.PAVILION_SEATS

func gathering_approach() -> Vector2:
	return (EstateLayout.PAVILION_SHELTER_APPROACH if is_rain_shelter() else EstateLayout.PAVILION_SEATS + APPROACH) \
		+ Vector2(-10, 0)

func seat_for(data: RetainerData) -> Vector2:
	var index := VisitorData.NEIGHBORS.find(data.name)
	if visible and data.duty != RetainerData.Duty.GUARD and index >= 0 and index < SEATS.size():
		var seats := RAIN_SEATS if is_rain_shelter() else SEATS
		return gathering_center() + seats[index]
	return Vector2.INF

func guest_seat() -> Vector2:
	return gathering_center() + (RAIN_GUEST_SEAT if is_rain_shelter() else GUEST_SEAT)

func can_interact_from(foot: Vector2) -> bool:
	return is_visible_in_tree() and global_position.distance_to(foot) < 13.0

func set_interaction_focused(focused: bool) -> void:
	self.focused = focused
	_refresh_hint()

func _refresh_hint() -> void:
	var story: String = get_parent().pavilion_story_id() if visible else ""
	var label := "灯下小谈" if not story.is_empty() else "今夜安排"
	hint.text = GamepadInput.interact_hint(label) if focused else label
	hint.visible = visible and (focused or not story.is_empty())

func interact() -> void:
	GameEvents.pavilion_table_requested.emit()

func _draw_mats() -> void:
	var seats := (RAIN_SEATS if is_rain_shelter() else SEATS).duplicate()
	var guest: Visitor = get_parent().current_visitor_actor()
	if is_instance_valid(guest) and guest.activity == VisitorData.VisitActivity.PAVILION_REST:
		seats.append(guest_seat() - gathering_center())
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
	if not get_parent().pavilion_story_id().is_empty():
		draw_rect(Rect2(-12, -10, 9, 5), Color("#4c3928"))
		draw_rect(Rect2(-11, -11, 8, 4), Color("#d8bd85"))
		draw_line(Vector2(-9, -11), Vector2(-9, -7), Color("#887047"), 1.0)
		draw_line(Vector2(-6, -11), Vector2(-6, -7), Color("#887047"), 1.0)
