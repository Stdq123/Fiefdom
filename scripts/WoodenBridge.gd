extends Node2D

const RAVINE_ART := preload("res://assets/world/ravine-art.png")
const ROAD_ART := preload("res://assets/world/creek-road-bridge.png")
const RAVINE_DECK := Rect2(0, 0, 70, 66)
const RAVINE_RAIL := Rect2(0, 68, 70, 18)
const ROAD_DECK := Rect2(0, 0, 112, 84)
const ROAD_RAIL := Rect2(0, 86, 112, 18)

var deck: Rect2
var ravine_finish: bool
var season := -1
var wet := false
var deck_art := Node2D.new()
var near_rail := Node2D.new()

func _init(footprint: Rect2, use_ravine_finish := false) -> void:
	name = "CreekBridge"
	ravine_finish = use_ravine_finish
	position = footprint.get_center()
	deck = Rect2(footprint.position - position, footprint.size)
	y_sort_enabled = true
	deck_art.name = "Deck"
	deck_art.z_index = -3
	near_rail.name = "NearRail"
	near_rail.position.y = deck.end.y

func _ready() -> void:
	add_child(deck_art)
	add_child(near_rail)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	deck_art.draw.connect(_draw_deck)
	near_rail.draw.connect(_draw_near_rail)
	_refresh()

func _refresh() -> void:
	var today := Global.season_index()
	var rain := Global.has_rain()
	if today == season and rain == wet:
		return
	season = today
	wet = rain
	deck_art.queue_redraw()
	near_rail.queue_redraw()

func _draw_deck() -> void:
	if ravine_finish:
		_draw_section(deck_art, RAVINE_ART, Vector2(-35, -26), RAVINE_DECK)
	else:
		_draw_section(deck_art, ROAD_ART, Vector2(-56, -33), ROAD_DECK)

func _draw_near_rail() -> void:
	if ravine_finish:
		_draw_section(near_rail, RAVINE_ART, Vector2(-35, -13), RAVINE_RAIL)
	else:
		_draw_section(near_rail, ROAD_ART, Vector2(-56, -13), ROAD_RAIL)

func _draw_section(layer: Node2D, sheet: Texture2D, at: Vector2, region: Rect2) -> void:
	# Frost is painted in the next column, separated by two transparent pixels.
	if season == Global.Season.WINTER:
		region.position.x += region.size.x + 2.0
	var tint := Color("#bdc9c2") if wet else Color.WHITE
	layer.draw_texture_rect_region(sheet, Rect2(at, region.size), region, tint)
