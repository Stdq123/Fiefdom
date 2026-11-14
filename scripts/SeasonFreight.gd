extends Node2D
class_name SeasonFreight

enum RouteSection { MARKET, WEST_ROAD, ESTATE }
enum CartView { SIDE, AWAY_CORNER, NEAR_CORNER, AWAY, NEAR }

const LANDSCAPE := preload("res://scripts/Landscape.gd")
const CART_ART := preload("res://assets/world/season-order-cart.svg")
const DRIVER_ART := preload("res://assets/characters/freight-driver.svg")
const WHEEL_SOUNDS := [preload("res://assets/audio/freight/wheel-1.wav"), preload("res://assets/audio/freight/wheel-2.wav")]
const ARRIVAL_SOUND := preload("res://assets/audio/freight/wagon-stop.wav")
const WHEEL_SPACING := 46.0
const HEARING_RANGE := 230.0
const CART_FRAME := Vector2(96, 64)
const SHAFT_ENDS := [Vector2(33, -11), Vector2(25, -23), Vector2(25, 1), Vector2(0, -28), Vector2(0, 9)]
const WEST_MARKET := preload("res://scripts/WestMarketLayout.gd")
const WEST_ROAD := preload("res://scripts/WestRoadLayout.gd")

static var market_road := _curve(WEST_MARKET.freight_path())
static var west_road := _curve(WEST_ROAD.ROAD)
static var estate_road := _estate_curve()
static var roads: Array[Curve2D] = [market_road, west_road, estate_road]
static var west_road_start := market_road.get_baked_length()
static var estate_start := west_road_start + west_road.get_baked_length()
static var route_length := estate_start + estate_road.get_baked_length()

@export var route_section := RouteSection.ESTATE

@onready var cart: Sprite2D = $Cart
@onready var cargo: Sprite2D = $Cargo
@onready var rim: Sprite2D = $Rim
@onready var driver: NeighborMotion = $Driver
@onready var sign: Label = $Sign
@onready var parked_shape: CollisionShape2D = $Stand/Shape

var current_lot: Dictionary
var previous_lot: Dictionary
var travelling := false
var arrived := false
var route_offset := 0.0
var focused := false
var shown_order := ""
var arrival_line := ""
var parked := false
var cart_views := _cart_frames(0.0)
var rim_views := _cart_frames(CART_FRAME.x)
var side_cargo := _frame(CART_ART, Rect2(0, 320, 48, 32))
var end_cargo := _frame(CART_ART, Rect2(48, 320, 48, 32))
var portrait := _frame(DRIVER_ART, Rect2(0, 96, 48, 48))

static func _estate_curve() -> Curve2D:
	var approach: Array = LANDSCAPE.ESTATE_TRACKS[0].slice(0, 9)
	approach.append_array(LANDSCAPE.ESTATE_SOUTH_LANE.slice(1))
	approach.append_array(EstateLayout.UNLOADING_LANE.slice(1))
	return _curve(approach)

static func _curve(points: Array) -> Curve2D:
	var curve := Curve2D.new()
	curve.bake_interval = 4.0
	for index in points.size():
		var at: Vector2 = points[index]
		var previous: Vector2 = points[maxi(0, index - 1)]
		var next: Vector2 = points[mini(points.size() - 1, index + 1)]
		var handle := previous.direction_to(next) * minf(at.distance_to(previous), at.distance_to(next)) * 0.24
		curve.add_point(at, -handle, handle)
	return curve

static func _frame(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	atlas.filter_clip = true
	return atlas

static func _cart_frames(column: float) -> Array[AtlasTexture]:
	var frames: Array[AtlasTexture] = []
	for view in CartView.size():
		frames.append(_frame(CART_ART, Rect2(Vector2(column, view * CART_FRAME.y), CART_FRAME)))
	return frames

static func _cart_view(heading: Vector2) -> CartView:
	var x := absf(heading.x)
	var y := absf(heading.y)
	if y <= x * 0.42:
		return CartView.SIDE
	if x <= y * 0.42:
		return CartView.AWAY if heading.y < 0.0 else CartView.NEAR
	return CartView.AWAY_CORNER if heading.y < 0.0 else CartView.NEAR_CORNER

func _ready() -> void:
	driver.set_motion_sheet(_frame(DRIVER_ART, Rect2(0, 0, 128, 96)))
	GameEvents.inventory_changed.connect(_refresh_lots.unbind(1))
	GameEvents.day_advanced.connect(_refresh_lots.unbind(1))
	_refresh_lots()

func _refresh_lots() -> void:
	var schedule := Global.season_order()
	current_lot = _lot(schedule)
	previous_lot = {}
	if schedule.start > 1 and schedule.start == Global.current_day:
		var former := _lot(Global.season_order(schedule.start - 1))
		if not former.is_empty() and former.receipt.dispatch_day == Global.current_day:
			previous_lot = former
	_sync_position()

func _lot(schedule: Dictionary) -> Dictionary:
	if Global.season_order_delivered_at(schedule) == 0:
		return {}
	return {"order": schedule.order, "receipt": Global.season_order_receipts[schedule.order.id]}

func _progress(lot: Dictionary) -> float:
	return SeasonOrders.transit_progress(lot.receipt, Global.current_day, Global.day_progress) if not lot.is_empty() else -1.0

func _process(_delta: float) -> void:
	_sync_position()

func _sync_position() -> void:
	var lot := current_lot
	if not previous_lot.is_empty():
		var previous_in_transit := _progress(previous_lot) < 1.0
		var current_reached_estate := _progress(lot) * route_length >= estate_start
		if lot.is_empty() or previous_in_transit or (route_section == RouteSection.ESTATE and not current_reached_estate):
			lot = previous_lot
	var progress := _progress(lot)
	var delivery_day: int = lot.receipt.dispatch_day if not lot.is_empty() else -1
	var distance := clampf(progress, 0.0, 1.0) * route_length
	var section := RouteSection.MARKET
	if distance >= estate_start:
		section = RouteSection.ESTATE
	elif distance >= west_road_start:
		section = RouteSection.WEST_ROAD
	var at_origin := route_section == RouteSection.MARKET and (progress < 0.0 or delivery_day < Global.current_day)
	var on_this_map := delivery_day == Global.current_day and progress >= 0.0 and section == route_section
	visible = at_origin or on_this_map
	arrived = visible and route_section == RouteSection.ESTATE and progress >= 1.0
	_set_parked(visible and (at_origin or arrived))
	if not visible:
		travelling = false
		return
	var has_cargo := not lot.is_empty() and delivery_day >= Global.current_day
	var same_trip: bool = travelling and has_cargo and shown_order == lot.order.id
	if has_cargo and shown_order != lot.order.id:
		_load_cargo(lot.order)
	var relayed := (shown_order == SeasonOrders.WATCH_RELIEF or shown_order == SeasonOrders.WINTER_WOVEN_GOODS
		or shown_order in SeasonOrders.SEED_ORDERS)
	cargo.visible = has_cargo and not (arrived and relayed)
	var start: float = [0.0, west_road_start, estate_start][route_section]
	_pose(roads[route_section], 0.0 if at_origin else distance - start, not parked, same_trip)

func _set_parked(active: bool) -> void:
	if parked != active:
		parked = active
		parked_shape.set_deferred("disabled", not active)

func _load_cargo(order: Dictionary) -> void:
	shown_order = order.id
	arrival_line = order.arrival
	for old in cargo.get_children():
		cargo.remove_child(old)
		old.queue_free()
	var goods := SeasonOrders.cargo(order)
	var middle := float(goods.size() - 1) / 2.0
	var index := 0
	for id: String in goods:
		var picture := ItemManager.season_item_picture(id)
		var produce := Sprite2D.new()
		produce.texture = picture.texture
		produce.self_modulate = picture.tint
		produce.position = Vector2((index - middle) * 14.0, -2)
		cargo.add_child(produce)
		index += 1

func _pose(road: Curve2D, offset: float, moving: bool, same_trip: bool) -> void:
	var previous_offset := route_offset
	var moved := maxf(0.0, offset - previous_offset) if travelling else 0.0
	route_offset = offset
	travelling = moving
	position = road.sample_baked(offset)
	var heading := road.sample_baked(offset + 4.0) - road.sample_baked(offset - 4.0)
	var bob := 0.0
	if moved > 0.04 and moving:
		bob = driver.walk(heading.normalized() * moved)
	else:
		driver.stand()
		driver.face((Vector2.LEFT if route_section == RouteSection.MARKET else Vector2.DOWN) if parked else heading)
	var view := _cart_view(heading)
	var end_on := view == CartView.AWAY or view == CartView.NEAR
	cart.texture = cart_views[view]
	rim.texture = rim_views[view]
	cart.flip_h = heading.x < 0.0 and not end_on
	rim.flip_h = cart.flip_h
	cart.position.y = -17.0 + bob
	rim.position.y = cart.position.y
	cargo.texture = end_cargo if end_on else side_cargo
	cargo.position = Vector2(0, -24 + bob)
	# Offsets share the axle anchor. At a stop the driver steps to the road side to receive the player.
	driver.position = SHAFT_ENDS[view] * Vector2(-1 if cart.flip_h else 1, 1) if moving else Vector2(40, -6)
	driver.z_index = -1 if moving and (view == CartView.AWAY_CORNER or view == CartView.AWAY) else 0
	sign.position = driver.position + Vector2(-34, -35)
	sign.visible = parked
	sign.text = GamepadInput.interact_hint("申禾") if focused else "申禾"
	if not same_trip or Global.is_indoors():
		return
	if arrived and moved < WHEEL_SPACING:
		AudioManager.play_world_sfx(ARRIVAL_SOUND, self, -12.0, HEARING_RANGE)
	elif moving and moved > 0.04 and moved < 12.0:
		var wheel := floori(offset / WHEEL_SPACING)
		if wheel > floori(previous_offset / WHEEL_SPACING):
			AudioManager.play_world_sfx(WHEEL_SOUNDS[wheel % WHEEL_SOUNDS.size()], self, -14.0, HEARING_RANGE)

func can_interact_from(foot: Vector2) -> bool:
	return arrived and not Global.is_indoors() and global_position.distance_squared_to(foot) < 40.0 * 40.0

func set_interaction_focused(active: bool) -> void:
	focused = active

func interact() -> void:
	GameEvents.freight_arrival_interacted.emit(arrival_line, portrait, shown_order)
