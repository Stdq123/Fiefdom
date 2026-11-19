extends Node2D

const TIMBER_PATH := "res://assets/world/creek-road-bridge.png"
const ROAD_DECK := Rect2(1, 1, 104, 61)
const ROAD_RAIL := Rect2(2, 65, 98, 14)
const RAVINE_DECK := Rect2(111, 1, 62, 40)
const RAVINE_RAIL := Rect2(112, 46, 58, 12)
const LANDING_DECK := Rect2(180, 1, 49, 37)
const LANDING_RAIL := Rect2(180, 43, 36, 12)
const LANDING_RETURN := Rect2(224, 43, 4, 24)
const WINTER_ROW := 86.0
const WET_WOOD := Color("#bdc9c2")

var deck: Rect2
var ravine_finish: bool
var season := -1
var wet := false
var deck_art := Node2D.new()
var far_rail := Node2D.new()
var near_rail := Node2D.new()
var timber: Texture2D = load(TIMBER_PATH)

func _init(footprint: Rect2, use_ravine_finish := false) -> void:
	name = "CreekBridge"
	ravine_finish = use_ravine_finish
	position = footprint.get_center()
	deck = Rect2(footprint.position - position, footprint.size)
	y_sort_enabled = true
	deck_art.name = "Deck"
	deck_art.z_index = -3
	far_rail.name = "FarRail"
	far_rail.position.y = deck.position.y
	near_rail.name = "NearRail"
	near_rail.position.y = deck.end.y

func _ready() -> void:
	add_child(deck_art)
	add_child(far_rail)
	add_child(near_rail)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	deck_art.draw.connect(_draw_deck)
	far_rail.draw.connect(_draw_rail.bind(far_rail, Color("#e5e3d7")))
	near_rail.draw.connect(_draw_rail.bind(near_rail, Color.WHITE))
	_refresh()

func _refresh() -> void:
	var today := Global.season_index()
	var rain := Global.has_rain()
	if today == season and rain == wet:
		return
	season = today
	wet = rain
	deck_art.queue_redraw()
	far_rail.queue_redraw()
	near_rail.queue_redraw()

func _draw_deck() -> void:
	var region := RAVINE_DECK if ravine_finish else ROAD_DECK
	var at := Vector2(-region.size.x * 0.5, deck.position.y - 1.0)
	var winter := season == Global.Season.WINTER
	draw_timber(deck_art, timber, Rect2(at + Vector2(2, 3), region.size), region, winter, Color("#21363145"))
	draw_timber(deck_art, timber, Rect2(at, region.size), region, winter, WET_WOOD if wet else Color.WHITE)

func _draw_rail(layer: Node2D, tint: Color) -> void:
	var region := RAVINE_RAIL if ravine_finish else ROAD_RAIL
	var at := Vector2(-region.size.x * 0.5, 1.0 - region.size.y)
	draw_timber(layer, timber, Rect2(at, region.size), region, season == Global.Season.WINTER,
		tint * WET_WOOD if wet else tint)

static func draw_timber(layer: Node2D, sheet: Texture2D, dest: Rect2, region: Rect2, winter: bool, tint: Color) -> void:
	if winter:
		region.position.y += WINTER_ROW
	layer.draw_texture_rect_region(sheet, dest, region, tint)
