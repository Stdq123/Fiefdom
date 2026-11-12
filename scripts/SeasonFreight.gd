extends Node2D
class_name SeasonFreight

const LANDSCAPE := preload("res://scripts/Landscape.gd")
const CART_ART := preload("res://assets/world/season-order-cart.svg")
const DRIVER_ART := preload("res://assets/characters/freight-driver.svg")
const ROAD_STEP := preload("res://assets/audio/plank-1.wav")
const WEST_MARKET := preload("res://scripts/WestMarketLayout.gd")

static var market_road := _curve(WEST_MARKET.freight_path())
static var estate_road := _estate_curve()

@export var at_market := false

@onready var cart: Sprite2D = $Cart
@onready var cargo: Sprite2D = $Cargo
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
var side_cart := _frame(CART_ART, Rect2(0, 0, 84, 48))
var front_cart := _frame(CART_ART, Rect2(140, 0, 44, 48))
var side_cargo := _frame(CART_ART, Rect2(84, 0, 56, 26))
var front_cargo := _frame(CART_ART, Rect2(92, 0, 40, 26))
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
	if not previous_lot.is_empty() and (lot.is_empty() or _progress(previous_lot) < 1.0):
		lot = previous_lot
	var progress := _progress(lot)
	var delivery_day: int = lot.receipt.dispatch_day if not lot.is_empty() else -1
	var market_length := market_road.get_baked_length()
	var distance := clampf(progress, 0.0, 1.0) * (market_length + estate_road.get_baked_length())
	var at_origin := at_market and (progress < 0.0 or delivery_day < Global.current_day)
	var on_this_map := delivery_day == Global.current_day and progress >= 0.0 and (distance < market_length) == at_market
	visible = at_origin or on_this_map
	arrived = visible and not at_market and progress >= 1.0
	_set_parked(visible and (at_origin or arrived))
	if not visible:
		travelling = false
		return
	var has_cargo := not lot.is_empty() and delivery_day >= Global.current_day
	if has_cargo and shown_order != lot.order.id:
		_load_cargo(lot.order)
	cargo.visible = has_cargo
	var road := market_road if at_market else estate_road
	var offset := (0.0 if at_origin else distance) if at_market else distance - market_length
	_pose(road, offset, not parked)

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

func _pose(road: Curve2D, offset: float, moving: bool) -> void:
	var previous_offset := route_offset
	var moved := maxf(0.0, offset - previous_offset) if travelling else 0.0
	route_offset = offset
	travelling = moving
	position = road.sample_baked(offset)
	var heading := road.sample_baked(offset + 4.0) - road.sample_baked(offset - 4.0)
	var horizontal := absf(heading.x) >= absf(heading.y)
	var bob := 0.0
	if moved > 0.04 and moving:
		bob = driver.walk(heading.normalized() * moved)
		if floori(offset / 33.0) != floori(previous_offset / 33.0):
			AudioManager.play_world_sfx(ROAD_STEP, self, -18.0, 110.0)
	else:
		driver.stand()
		driver.face(Vector2.LEFT if at_market else Vector2.DOWN)
	cart.texture = side_cart if horizontal else front_cart
	cart.position.y = -19.0 + bob
	cargo.texture = side_cargo if horizontal else front_cargo
	cargo.position = Vector2(-6, -28 + bob) if horizontal else Vector2(0, -32 + bob)
	driver.position = Vector2(40, -6) if horizontal else Vector2(0, 9)
	sign.position = driver.position + Vector2(-34, -35)
	sign.visible = parked
	sign.text = GamepadInput.interact_hint("申禾") if focused else "申禾"

func can_interact_from(foot: Vector2) -> bool:
	return arrived and not Global.is_indoors() and global_position.distance_squared_to(foot) < 40.0 * 40.0

func set_interaction_focused(active: bool) -> void:
	focused = active

func interact() -> void:
	GameEvents.freight_arrival_interacted.emit(arrival_line, portrait)
