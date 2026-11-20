extends Node2D
class_name PavilionRest

signal story_changed(story_id: String, appointment_id: String, place: String)

const PLACE := "亭前晚坐"
const RAIN_PLACE := "亭东雨棚"
const STORY_LABEL := "灯下小谈"
const WAIT_LABEL := "亭边候席"
const START := (17.0 - Global.DAY_START_HOUR) / (Global.DAY_END_HOUR - Global.DAY_START_HOUR)
const RAIN_START := (15.0 - Global.DAY_START_HOUR) / (Global.DAY_END_HOUR - Global.DAY_START_HOUR)
const SEATS := [Vector2(-25, 3), Vector2(12, -16), Vector2(-12, -13),
	Vector2(25, 0), Vector2(21, 22), Vector2(-22, 22)]
const RAIN_SEATS := [Vector2(-30, -10), Vector2(-11, -14), Vector2(10, -14),
	Vector2(30, -10), Vector2(30, 10), Vector2(-28, 10)]
const GUEST_SEAT := Vector2(8, 20)
const RAIN_GUEST_SEAT := Vector2(8, 13)
const APPROACH := Vector2(0, 15)
const TABLE_FRONT_EDGE := Vector2(0, 4)

@onready var hint: Label = $Hint
@onready var mats: Node2D = $Mats
@onready var tabletop: Node2D = $Tabletop
@onready var dry_lamps: Node2D = $DryLamps
@onready var rain_lamps: Node2D = $RainLamps
var focused := false
var story_id := ""
var appointment_id := ""

func _ready() -> void:
	mats.draw.connect(_draw_mats)
	tabletop.draw.connect(_draw_tabletop)
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
	var approach := gathering_approach()
	if position != approach:
		position = approach
		mats.position = gathering_center() - position
		tabletop.position = mats.position + TABLE_FRONT_EDGE
		dry_lamps.position = mats.position
		rain_lamps.position = mats.position
	refresh_table()
	dry_lamps.visible = not shelter
	rain_lamps.visible = shelter

func refresh_table() -> void:
	var next_story: String = get_parent().pavilion_story_id()
	var next_appointment: String = get_parent().pavilion_appointment() if next_story.is_empty() else ""
	var changed := next_story != story_id or next_appointment != appointment_id
	story_id = next_story
	appointment_id = next_appointment
	visible = is_evening_open() or not appointment_id.is_empty()
	mats.queue_redraw()
	tabletop.queue_redraw()
	_refresh_hint()
	if changed:
		story_changed.emit(story_id, appointment_id, gathering_name())

func is_rain_shelter() -> bool:
	return Global.has_rain()

static func rest_start() -> float:
	return RAIN_START if Global.has_rain() else START

static func rest_watch() -> String:
	return "申时" if Global.has_rain() else "酉时"

func is_evening_open() -> bool:
	return Global.day_progress >= rest_start() and Global.raid_day == 0 and Global.outcome == Global.Outcome.RUNNING

func gathering_name() -> String:
	return RAIN_PLACE if is_rain_shelter() else PLACE

func gathering_center() -> Vector2:
	return EstateLayout.PAVILION_SHELTER if is_rain_shelter() else EstateLayout.PAVILION_SEATS

func gathering_approach() -> Vector2:
	return (EstateLayout.PAVILION_SHELTER_APPROACH if is_rain_shelter() else EstateLayout.PAVILION_SEATS + APPROACH) \
		+ Vector2(-10, 0)

func has_seat_for(data: RetainerData) -> bool:
	var index := VisitorData.NEIGHBORS.find(data.name)
	return data.duty != RetainerData.Duty.GUARD and index >= 0 and index < SEATS.size()

func seat_for(data: RetainerData) -> Vector2:
	if is_evening_open() and has_seat_for(data):
		var seats := RAIN_SEATS if is_rain_shelter() else SEATS
		return gathering_center() + seats[VisitorData.NEIGHBORS.find(data.name)]
	return Vector2.INF

func guest_seat() -> Vector2:
	return gathering_center() + (RAIN_GUEST_SEAT if is_rain_shelter() else GUEST_SEAT)

func can_interact_from(foot: Vector2) -> bool:
	return is_visible_in_tree() and global_position.distance_to(foot) < 13.0

func set_interaction_focused(focused: bool) -> void:
	self.focused = focused
	_refresh_hint()

func _refresh_hint() -> void:
	var label := STORY_LABEL if not story_id.is_empty() else "今夜安排"
	if not appointment_id.is_empty():
		label = WAIT_LABEL
	hint.text = GamepadInput.interact_hint(label) if focused else label
	hint.visible = visible and (focused or not story_id.is_empty() or not appointment_id.is_empty())

func interact() -> void:
	GameEvents.pavilion_table_requested.emit()

func _draw_mats() -> void:
	var seats := (RAIN_SEATS if is_rain_shelter() else SEATS).duplicate()
	if not appointment_id.is_empty() or not story_id.is_empty():
		seats.append(gathering_approach() - gathering_center())
	var guest: Visitor = get_parent().current_visitor_actor()
	if is_instance_valid(guest) and guest.activity == VisitorData.VisitActivity.PAVILION_REST:
		seats.append(guest_seat() - gathering_center())
	for seat: Vector2 in seats:
		SeatedPose.draw_reed_mat(mats, seat)

func _draw_tabletop() -> void:
	tabletop.draw_set_transform(-TABLE_FRONT_EDGE)
	tabletop.draw_rect(Rect2(-16, 0, 32, 4), Color("#27362d9c"))
	tabletop.draw_rect(Rect2(-13, -4, 3, 7), Color("#4d372c"))
	tabletop.draw_rect(Rect2(10, -4, 3, 7), Color("#4d372c"))
	tabletop.draw_rect(Rect2(-15, -11, 30, 11), Color("#614638"))
	tabletop.draw_rect(Rect2(-15, -11, 30, 8), Color("#a38156"))
	tabletop.draw_rect(Rect2(-14, -10, 28, 1), Color("#c1a171"))
	for x in [-9, 7]:
		tabletop.draw_rect(Rect2(x - 3, -7, 6, 4), Color("#664c3a"))
		tabletop.draw_rect(Rect2(x - 3, -8, 6, 2), Color("#c6ad80"))
		tabletop.draw_rect(Rect2(x - 2, -8, 4, 1), Color("#6e8380"))
	tabletop.draw_rect(Rect2(-3, -15, 7, 9), Color("#805b4d"))
	tabletop.draw_rect(Rect2(-1, -14, 2, 7), Color("#ae8062"))
	tabletop.draw_rect(Rect2(-3, -16, 7, 2), Color("#cca36e"))
	if not story_id.is_empty():
		tabletop.draw_rect(Rect2(-12, -10, 9, 5), Color("#4c3928"))
		tabletop.draw_rect(Rect2(-11, -11, 8, 4), Color("#d8bd85"))
		tabletop.draw_line(Vector2(-9, -11), Vector2(-9, -7), Color("#887047"), 1.0)
		tabletop.draw_line(Vector2(-6, -11), Vector2(-6, -7), Color("#887047"), 1.0)
