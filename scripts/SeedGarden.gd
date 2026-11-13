extends Node2D

const PLACE := "亭西种圃"
const CAST := preload("res://assets/characters/autumn-guests.svg")
const STORAGE := preload("res://assets/world/estate-storage.png")
const TILES := preload("res://resources/game_tileset.tres")
const BED_WIDTH := 25

@onready var courier: Node2D = $Courier
@onready var motion: NeighborMotion = $Courier/Motion
@onready var pouch: Sprite2D = $Courier/SeedPouch
@onready var hint: Label = $Hint

var road := Curve2D.new()
var planted_day := 0
var stage := 0
var in_transit := false

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
	GameEvents.inventory_changed.connect(_refresh_clock.unbind(1))
	GameEvents.day_advanced.connect(_refresh_clock.unbind(1))
	GameEvents.estate_room_changed.connect(_refresh_clock.unbind(1))
	_refresh_clock()

func _refresh_clock() -> void:
	_sync(false)
	queue_redraw()
	set_process(Global.seed_garden_delivery_progress() < 1.0
		and SeasonOrders.SEED_ORDERS.any(func(id: String) -> bool: return Global.season_order_receipts.has(id)))

func _process(_delta: float) -> void:
	_sync(true)

func _sync(animate: bool) -> void:
	var next_day := Global.seed_garden_day()
	var growth := Global.current_day - next_day
	var next_stage := 0
	if growth > 0 and growth <= SeasonOrders.SEED_GROW_NIGHTS * 2:
		next_stage = 1 if growth < SeasonOrders.SEED_GROW_NIGHTS else 2
	if next_day != planted_day or stage != next_stage:
		var first_delivery := planted_day == 0 and next_day > 0
		planted_day = next_day
		stage = next_stage
		queue_redraw()
		if first_delivery:
			add_to_group("interactable")
			GameEvents.seed_garden_arrived.emit()
	var progress := Global.seed_garden_delivery_progress()
	var was_walking := in_transit
	in_transit = progress >= 0.0 and progress < 1.0
	# Lin Liao may already be standing in for a guest at the spring gathering.
	var at_gathering := get_parent().get_parent().has_node("SpringGathering/Guests/林蓼")
	courier.visible = (in_transit or planted_day == Global.current_day) and not Global.is_indoors() and not at_gathering
	if progress >= 1.0:
		set_process(false)
	if not courier.visible:
		return
	var distance := clampf(progress, 0.0, 1.0) * road.get_baked_length()
	var point := road.sample_baked(distance) - position
	var movement := point - courier.position
	courier.position = point
	if in_transit and animate and was_walking and not movement.is_zero_approx():
		motion.walk(movement)
	elif not in_transit or not animate or not was_walking:
		motion.stand()
		motion.face(Vector2.LEFT if not in_transit else road.sample_baked(distance + 2.0) - road.sample_baked(distance - 2.0))
	pouch.visible = in_transit
	pouch.position.x = -8.0 if motion.flip_h else 8.0

func can_interact_from(foot: Vector2) -> bool:
	return not Global.is_indoors() and planted_day > 0 and to_local(foot).distance_to(Vector2(0, 15)) <= 27.0

func set_interaction_focused(focused: bool) -> void:
	hint.visible = focused and planted_day > 0
	if hint.visible:
		hint.text = GamepadInput.interact_hint(PLACE)

func host_present() -> bool:
	return planted_day == Global.current_day and courier.visible and not in_transit

func interact() -> void:
	GameEvents.seed_garden_requested.emit()

func _draw() -> void:
	if planted_day == 0:
		return
	var winter := Global.season_index() == Global.Season.WINTER
	var growing := stage > 0 and not winter
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
		draw_rect(Rect2(corner + Vector2(10, -8), Vector2(2, 9)), Color("#705437"))
		draw_rect(Rect2(corner + Vector2(7, -9), Vector2(8, 4)), Color("#cbad73"))
	draw_texture_rect_region(STORAGE, Rect2(-34, -10, 12, 12), Rect2(0, 0, 16, 16), Color("#cdb58c"))

func _draw_row(crop_id: String, at: Vector2) -> void:
	var crop := ItemManager.get_crop(crop_id)
	var atlas := TILES.get_source(crop.atlas_source_id) as TileSetAtlasSource
	var cell: Vector2i = crop.stages_atlas_coords[stage]
	var rect := atlas.get_tile_texture_region(cell)
	var tint := atlas.get_tile_data(cell, 0).modulate
	for gap in [0, 10]:
		draw_texture_rect_region(atlas.texture, Rect2(at + Vector2(gap - 6, -9), Vector2(12, 12)), rect, tint)
