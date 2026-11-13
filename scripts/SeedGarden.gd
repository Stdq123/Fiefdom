extends Node2D

const PLACE := "亭西种圃"
const HOST := "林蓼"
const CAST := preload("res://assets/characters/autumn-guests.svg")
const STORAGE := preload("res://assets/world/estate-storage.svg")
const SHARING := preload("res://assets/world/autumn-sharing.svg")
const BED_WIDTH := 25
const SHARE_START := 3.0 / 16.0
const SHARE_END := 11.0 / 16.0
const WALK_TIME := 0.048
const PICKUP_TIME := 0.026
const RECIPIENTS := [
	{"start": 0.28, "leave": 0.46, "offset": Vector2(14, 15), "sheet": 0},
	{"start": 0.34, "leave": 0.51, "offset": Vector2(-16, 30), "sheet": 2},
]

@onready var courier: Node2D = $Courier
@onready var motion: NeighborMotion = $Courier/Motion
@onready var pouch: Sprite2D = $Courier/SeedPouch
@onready var recipients: Node2D = $Recipients
@onready var hint: Label = $Hint

var road := Curve2D.new()
var planted_day := 0
var stage := 0
var in_transit := false
var sharing_table := false
var packets_left := 0

static func sharing_day(planted: int) -> int:
	var ripe := planted + SeasonOrders.SEED_GROW_NIGHTS
	while Global.is_gathering_day(ripe):
		ripe += 1
	return ripe

static func visit_note(planted: int) -> String:
	var sharing := sharing_day(planted)
	if Global.current_day < sharing:
		return "第 %d 天巳时 · 林蓼来分种" % sharing
	if Global.current_day == sharing and Global.day_progress < SHARE_END:
		return "今日巳时到场 · 申时分完"
	return "分种已过 · 田边有木签"

static func portrait() -> Texture2D:
	return _frame(CAST, Rect2(0, 96, 32, 32))

static func _frame(atlas: Texture2D, area: Rect2) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = atlas
	frame.region = area
	frame.filter_clip = true
	return frame

func _ready() -> void:
	for point: Vector2 in EstateLayout.seed_garden_route():
		road.add_point(point)
	motion.set_motion_sheet(_frame(CAST, Rect2(0, 96, 128, 96)))
	pouch.texture = _frame(STORAGE, Rect2(0, 0, 16, 16))
	pouch.scale = Vector2(0.65, 0.65)
	for index in RECIPIENTS.size():
		var actor := Node2D.new()
		recipients.add_child(actor)
		var body := NeighborMotion.new()
		body.name = "Motion"
		body.texture_filter = TEXTURE_FILTER_NEAREST
		body.position.y = -11.0
		actor.add_child(body)
		body.set_motion_sheet(_frame(CAST, Rect2(0, RECIPIENTS[index].sheet * 96, 128, 96)))
		var bag := Sprite2D.new()
		bag.name = "Packet"
		bag.texture_filter = TEXTURE_FILTER_NEAREST
		bag.texture = _frame(SHARING, Rect2(1, 34, 19, 12))
		bag.scale = Vector2(0.65, 0.65)
		actor.add_child(bag)
	GameEvents.inventory_changed.connect(_refresh_clock.unbind(1))
	GameEvents.day_advanced.connect(_refresh_clock.unbind(1))
	GameEvents.estate_room_changed.connect(_refresh_clock.unbind(1))
	GameEvents.campaign_ended.connect(_refresh_clock.unbind(1))
	_refresh_clock()

func _refresh_clock() -> void:
	set_process(true)
	_sync(false)
	queue_redraw()

func _process(_delta: float) -> void:
	_sync(true)

func _sync(animate: bool) -> void:
	var next_day := Global.seed_garden_day()
	var growth := Global.current_day - next_day
	var next_stage := 0
	var sharing := sharing_day(next_day) if next_day > 0 else 0
	var today := Global.current_day == sharing
	var clock := Global.day_progress
	if next_day > 0 and growth > 0:
		if growth < SeasonOrders.SEED_GROW_NIGHTS:
			next_stage = 1
		elif Global.current_day < sharing or (today and clock < SHARE_END):
			next_stage = 2
		elif growth <= SeasonOrders.SEED_GROW_NIGHTS * 2:
			next_stage = 3
	if next_day != planted_day or stage != next_stage:
		var first_delivery := planted_day == 0 and next_day > 0
		planted_day = next_day
		stage = next_stage
		queue_redraw()
		if first_delivery:
			add_to_group("interactable")
			GameEvents.seed_garden_arrived.emit()
	var progress := Global.seed_garden_delivery_progress()
	in_transit = progress >= 0.0 and progress < 1.0
	var open := Global.outcome == Global.Outcome.RUNNING
	_sync_sharing(today and open, animate)
	if not today or not open:
		_sync_delivery(progress, open, animate)
	var delivery_pending := progress < 1.0 and SeasonOrders.SEED_ORDERS.any(
		func(id: String) -> bool: return Global.season_order_receipts.has(id))
	if not open or (not delivery_pending and (not today or clock >= SHARE_END + WALK_TIME)):
		set_process(false)

func _sync_delivery(progress: float, open: bool, animate: bool) -> void:
	# Lin Liao may already be standing in for a guest at the spring gathering.
	var at_gathering := get_parent().get_parent().has_node("SpringGathering/Guests/" + HOST)
	var show_courier := (in_transit or planted_day == Global.current_day) and not at_gathering
	courier.visible = show_courier and open and not Global.is_indoors()
	if not courier.visible:
		return
	courier.modulate.a = 1.0
	var fraction := clampf(progress, 0.0, 1.0)
	_walk_actor(courier, motion, fraction, Vector2.ZERO, Vector2.LEFT, in_transit and animate)
	pouch.visible = in_transit
	pouch.position.x = -8.0 if motion.flip_h else 8.0

func _sync_sharing(today: bool, animate: bool) -> void:
	var clock := Global.day_progress
	var at_table := today and clock >= SHARE_START + WALK_TIME and clock < SHARE_END
	var remaining := 0
	var outdoors := not Global.is_indoors()
	recipients.visible = today and outdoors and clock >= RECIPIENTS[0].start and clock < RECIPIENTS[-1].leave + WALK_TIME
	if today:
		_walk_visit(courier, motion, SHARE_START, SHARE_END, Vector2.ZERO, Vector2.RIGHT, animate)
		courier.visible = courier.visible and outdoors
		pouch.hide()
	if at_table:
		for index in RECIPIENTS.size():
			var guest: Dictionary = RECIPIENTS[index]
			var packed: bool = clock >= guest.start + WALK_TIME + PICKUP_TIME
			remaining += int(not packed)
			if not recipients.visible:
				continue
			var actor := recipients.get_child(index) as Node2D
			var body := actor.get_node("Motion") as NeighborMotion
			_walk_visit(actor, body, guest.start, guest.leave, guest.offset, -guest.offset, animate)
			var bag := actor.get_node("Packet") as Sprite2D
			bag.visible = packed
			bag.position = Vector2(-8.0 if body.flip_h else 8.0, -8.0)
	if sharing_table != at_table or packets_left != remaining:
		sharing_table = at_table
		packets_left = remaining
		queue_redraw()

func _walk_visit(actor: Node2D, body: NeighborMotion, start: float, leave: float, offset: Vector2,
		look_at: Vector2, animate: bool) -> void:
	var clock := Global.day_progress
	actor.visible = clock >= start and clock < leave + WALK_TIME
	if not actor.visible:
		return
	var fraction := minf(clampf((clock - start) / WALK_TIME, 0.0, 1.0),
		1.0 - clampf((clock - leave) / WALK_TIME, 0.0, 1.0))
	actor.modulate.a = smoothstep(0.0, 0.12, fraction)
	_walk_actor(actor, body, fraction, offset, look_at, animate and fraction < 1.0)

func _walk_actor(actor: Node2D, body: NeighborMotion, fraction: float, offset: Vector2,
		look_at: Vector2, animate: bool) -> void:
	var at := road.sample_baked(fraction * road.get_baked_length()) - position
	at += offset * smoothstep(0.88, 1.0, fraction)
	var movement := at - actor.position
	actor.position = at
	if animate and movement.length_squared() >= 0.0016:
		body.walk(movement)
	else:
		body.stand()
		var distance := fraction * road.get_baked_length()
		var ahead := road.sample_baked(distance + 2.0) - road.sample_baked(distance - 2.0)
		body.face(look_at if fraction >= 1.0 else ahead)

func can_interact_from(foot: Vector2) -> bool:
	return not Global.is_indoors() and planted_day > 0 and to_local(foot).distance_to(Vector2(0, 15)) <= 27.0

func set_interaction_focused(focused: bool) -> void:
	hint.visible = focused and planted_day > 0
	if hint.visible:
		hint.text = GamepadInput.interact_hint(PLACE)

func host_present() -> bool:
	return courier.visible and ((planted_day == Global.current_day and not in_transit) or sharing_table)

func interact() -> void:
	GameEvents.seed_garden_requested.emit()

func _draw() -> void:
	if planted_day == 0:
		return
	var winter := Global.season_index() == Global.Season.WINTER
	var growing := stage in [1, 2] and not winter
	for index in SeasonOrders.SEED_CROPS.size():
		var corner := Vector2(-29 + index * 33, -23)
		var bed := Rect2(corner, Vector2(BED_WIDTH, 25))
		draw_rect(Rect2(corner + Vector2(-3, 1), Vector2(BED_WIDTH + 6, 27)), Color("#3d4733"))
		draw_rect(bed.grow(2), Color("#8f7956" if not winter else "#b1b4a6"))
		draw_rect(bed, Color("#65503a" if not winter else "#7b7f70"))
		for row in [8, 19]:
			draw_line(corner + Vector2(2, row), corner + Vector2(BED_WIDTH - 3, row), Color("#a38356" if not winter else "#b9bcad"))
			if growing:
				_draw_row(SeasonOrders.SEED_CROPS[index], corner + Vector2(7 + (row % 3), row))
			elif stage == 3 and not winter:
				for stubble in [5, 11, 18]:
					draw_rect(Rect2(corner + Vector2(stubble, row - 2), Vector2(2, 2)), Color("#b09552"))
		draw_rect(Rect2(corner + Vector2(10, -8), Vector2(2, 9)), Color("#705437"))
		draw_rect(Rect2(corner + Vector2(7, -9), Vector2(8, 4)), Color("#cbad73"))
	draw_texture_rect_region(STORAGE, Rect2(-34, -10, 12, 12), Rect2(0, 0, 16, 16), Color("#cdb58c"))
	if sharing_table:
		draw_rect(Rect2(42, -4, 22, 11), Color("#4e4232"))
		draw_rect(Rect2(43, -7, 20, 9), Color("#a78454"))
		draw_rect(Rect2(44, -7, 18, 1), Color("#cead71"))
		draw_rect(Rect2(44, 2, 2, 5), Color("#654d3a"))
		draw_rect(Rect2(60, 2, 2, 5), Color("#654d3a"))
		for index in packets_left:
			draw_texture_rect_region(SHARING, Rect2(44 + 9 * index, -9, 9, 6), Rect2(1, 34, 19, 12))
	if stage >= 2 and Global.seed_garden_gift.is_empty():
		draw_texture_rect_region(SHARING, Rect2(-37, -4, 11, 7), Rect2(1, 34, 19, 12))

func _draw_row(crop_id: String, at: Vector2) -> void:
	var crop := ItemManager.get_crop(crop_id)
	var atlas := ItemManager.crop_atlas
	var cell: Vector2i = crop.stages_atlas_coords[stage]
	var rect := atlas.get_tile_texture_region(cell)
	for gap in [0, 10]:
		draw_texture_rect_region(atlas.texture, Rect2(at + Vector2(gap - 6, -9), Vector2(12, 12)), rect)
