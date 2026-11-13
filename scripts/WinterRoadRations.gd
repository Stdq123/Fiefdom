extends Node2D

const PLACE := "亭前路粮案"
const STORAGE := preload("res://assets/world/estate-storage.svg")
const STAY_AT_TABLE := 1.55
const VISIT_START := 0.085
const VISIT_LEAVE := 0.220
const VISIT_WALK := 0.028
const VISIT_DISTANCE := 68.0

@onready var approach: Marker2D = $Approach
@onready var table: Node2D = $Table
@onready var footprint: CollisionShape2D = $Table/Footprint/Shape
@onready var hint: Label = $Table/Hint
@onready var courier: Node2D = $Courier
@onready var motion: NeighborMotion = $Courier/Motion
@onready var bundle: Node2D = $Courier/Bundle

var route := Curve2D.new()
var table_open := false
var in_transit := false
var focused := false
var cake_on_tray := false

func _ready() -> void:
	for point: Vector2 in EstateLayout.winter_rations_route():
		route.add_point(point - position)
	motion.set_motion_sheet(WinterSupper.guest_art(0))
	table.draw.connect(_draw_table)
	GameEvents.inventory_changed.connect(_refresh.unbind(1))
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.estate_room_changed.connect(_refresh.unbind(1))
	GameEvents.travel_meal_changed.connect(_refresh)
	GamepadInput.changed.connect(_refresh_hint)
	_refresh()

func _refresh() -> void:
	_sync(false)

func _process(_delta: float) -> void:
	_sync(true)

func _sync(animate: bool) -> void:
	var day := Global.winter_road_rations_day()
	var progress := Global.winter_road_rations_progress()
	var outdoors := not Global.is_indoors()
	var open_now := day > 0 and outdoors
	if table_open != open_now:
		table_open = open_now
		table.visible = table_open
		footprint.set_deferred("disabled", not table_open)
		_refresh_hint()
		table.queue_redraw()
	var cake_available := table_open and Global.winter_road_rations_gift_available()
	if cake_on_tray != cake_available:
		cake_on_tray = cake_available
		table.queue_redraw()

	in_transit = progress >= 0.0 and progress < 1.0
	var unloading := day == Global.current_day and progress >= 1.0 and progress < STAY_AT_TABLE
	var clock := Global.day_progress
	var visit := day > 0 and Global.current_day == day + 1
	var visiting := visit and clock >= VISIT_START and clock < VISIT_LEAVE + VISIT_WALK
	courier.visible = outdoors and (in_transit or unloading or visiting)
	motion.set_process(courier.visible)
	bundle.visible = in_transit
	var length := route.get_baked_length()
	if courier.visible:
		var distance := length * clampf(progress, 0.0, 1.0)
		if visiting and not in_transit:
			var walk_in := smoothstep(VISIT_START, VISIT_START + VISIT_WALK, clock)
			var walk_out := smoothstep(VISIT_LEAVE, VISIT_LEAVE + VISIT_WALK, clock)
			distance = length - VISIT_DISTANCE * maxf(1.0 - walk_in, walk_out)
		_place_courier(distance, animate)

	var pending := Global.season_order_receipts.has(SeasonOrders.WINTER_WOVEN_GOODS) and progress < 1.0
	set_process(outdoors and (pending or unloading or (visit and clock < VISIT_LEAVE + VISIT_WALK)))

func _place_courier(distance: float, animate: bool) -> void:
	var point := route.sample_baked(distance)
	var movement := point - courier.position
	courier.position = point
	if animate and movement.length_squared() >= 0.0016:
		motion.walk(movement)
	else:
		motion.stand()
		var heading := route.sample_baked(distance + 2.0) - route.sample_baked(distance - 2.0)
		motion.face(-point if courier_at_table() else heading)
	bundle.position.x = -8.0 if motion.flip_h else 8.0

func courier_at_table() -> bool:
	return courier.visible and not in_transit and courier.position.distance_squared_to(route.get_point_position(route.point_count - 1)) < 4.0

func can_interact_from(foot: Vector2) -> bool:
	var at := to_local(foot)
	return table_open and absf(at.x) <= 22.0 and at.y >= 8.0 and at.y <= 29.0

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh_hint()

func _refresh_hint() -> void:
	hint.visible = table_open and focused
	hint.text = GamepadInput.interact_hint(PLACE)

func interact() -> void:
	GameEvents.winter_road_rations_interacted.emit()

func _draw_table() -> void:
	table.draw_rect(Rect2(-21, 0, 42, 6), Color("#313c3188"))
	for x in [-16, 12]:
		table.draw_rect(Rect2(x, -6, 4, 9), Color("#4f3d30"))
		table.draw_rect(Rect2(x + 1, -5, 1, 7), Color("#a48254"))
	table.draw_rect(Rect2(-19, -16, 38, 14), Color("#503d30"))
	table.draw_rect(Rect2(-18, -15, 36, 9), Color("#9e7e51"))
	table.draw_rect(Rect2(-17, -15, 34, 1), Color("#c4a672"))
	table.draw_rect(Rect2(-17, -5, 34, 1), Color("#775639"))

	# The folded cloth hangs over the front edge, with a lighter stitched hem.
	table.draw_rect(Rect2(-5, -15, 17, 13), Color("#83524a"))
	table.draw_rect(Rect2(-4, -14, 15, 8), Color("#a96353"))
	table.draw_rect(Rect2(-4, -5, 15, 2), Color("#c99169"))
	for x in [-2, 2, 6]:
		table.draw_rect(Rect2(x, -10, 2, 1), Color("#dfb785"))
	table.draw_texture_rect_region(STORAGE, Rect2(-19, -24, 16, 16), Rect2(0, 0, 16, 16), Color("#d8bd8b"))

	# Leave the little tray in place after the reserved cake is taken.
	table.draw_rect(Rect2(7, -16, 12, 8), Color("#674d34"))
	table.draw_rect(Rect2(8, -15, 10, 5), Color("#b0925e"))
	table.draw_rect(Rect2(9, -10, 8, 1), Color("#d3ad6d"))
	if cake_on_tray:
		table.draw_rect(Rect2(10, -17, 7, 5), Color("#99613c"))
		table.draw_rect(Rect2(10, -18, 6, 3), Color("#dfb277"))
		table.draw_rect(Rect2(12, -17, 1, 1), Color("#bd8c54"))
