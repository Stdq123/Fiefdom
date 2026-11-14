extends Node2D

const PLANKS := Color("#b78c55")
const GRAIN := Color("#694b36")
const PLANK_WIDTH := 6.0
const MAX_POST_SPAN := 28.0

var deck: Rect2
var season := -1
var wet := false
var _posts := PackedFloat32Array()
var deck_art := Node2D.new()
var near_rail := Node2D.new()

func _init(footprint: Rect2) -> void:
	name = "CreekBridge"
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
	var span := deck.size.x - 4.0
	var sections := ceili(span / MAX_POST_SPAN)
	for index in range(sections + 1):
		_posts.append(roundf(deck.position.x + 2.0 + span * float(index) / sections))
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

func _wood(color: Color) -> Color:
	return color.lerp(Color("#5c5a48"), 0.25) if wet else color

func _draw_deck() -> void:
	var west := deck.position.x
	var east := deck.end.x
	var back := deck.position.y
	var front := deck.end.y
	_draw_supports(west, east, front)
	deck_art.draw_colored_polygon(PackedVector2Array([Vector2(west, front - 3), Vector2(east, front - 3),
		Vector2(east - 1, front + 5), Vector2(east - 9, front + 6),
		Vector2(west + 8, front + 6), Vector2(west + 1, front + 4)]), _wood(Color("#684831")))
	deck_art.draw_rect(Rect2(west + 2, front + 2, deck.size.x - 4, 2), _wood(Color("#8a603d")))
	deck_art.draw_rect(deck.grow(1.0), _wood(Color("#604431")))
	for index in ceili(deck.size.x / PLANK_WIDTH):
		var x := west + index * PLANK_WIDTH
		var width := minf(PLANK_WIDTH - 1.0, east - x)
		var grain := posmod(index * 17 + 3, 11)
		var plank := _wood(PLANKS.lightened((grain - 4.0) * 0.021))
		deck_art.draw_rect(Rect2(x, back, width, deck.size.y), plank)
		deck_art.draw_rect(Rect2(x, back + 1, 1, deck.size.y - 2), plank.lightened(0.16))
		deck_art.draw_rect(Rect2(x + 2, back + 5 + grain, 1, 7 + grain % 3), Color(GRAIN, 0.32))
		deck_art.draw_rect(Rect2(x + 3, front - 6 + grain % 3, 1, 3), Color(GRAIN, 0.48))
	deck_art.draw_rect(Rect2(west, front - 1, deck.size.x, 1), _wood(Color("#d0a66a")))
	for x: float in [west, east]:
		var cap := Rect2(x - 3.0, back - 1, 6.0, deck.size.y + 2)
		deck_art.draw_rect(cap, _stone(Color("#656656")))
		deck_art.draw_rect(Rect2(cap.position + Vector2(1, 1), Vector2(3, deck.size.y - 1)), _stone(Color("#aaa38b")))
		deck_art.draw_rect(Rect2(cap.position + Vector2(1, deck.size.y - 5), Vector2(4, 1)), _stone(Color("#585c4c")))
		if season == Global.Season.WINTER:
			deck_art.draw_line(cap.position + Vector2(1, 1), cap.position + Vector2(4, 1), Color("#c4cdc3"), 1.0)
	_draw_rail(deck_art, back)

func _stone(color: Color) -> Color:
	return color.lerp(Color("#4d6661"), 0.36) if wet else color

func _draw_supports(west: float, east: float, front: float) -> void:
	var under := Color("#182c2a")
	deck_art.draw_polygon(PackedVector2Array([Vector2(west + 1, front + 3), Vector2(east - 1, front + 3),
		Vector2(east + 6, front + 21), Vector2(west + 8, front + 18)]), PackedColorArray([
			Color(under, 0.76), Color(under, 0.76), Color(under, 0.08), Color(under, 0.08)]))
	for x: float in [west + 3, east - 10]:
		var footing := Vector2(x, front + 12)
		deck_art.draw_colored_polygon(PackedVector2Array([footing + Vector2(-3, 5), footing + Vector2(4, 1),
			footing + Vector2(13, 4), footing + Vector2(14, 10), footing + Vector2(-2, 10)]), Color(under, 0.55))
		deck_art.draw_colored_polygon(PackedVector2Array([footing + Vector2(-3, -3), footing + Vector2(9, -3),
			footing + Vector2(10, 5), footing + Vector2(8, 8), footing + Vector2(-2, 8),
			footing + Vector2(-4, 3)]), _stone(Color("#586354")))
		deck_art.draw_colored_polygon(PackedVector2Array([footing + Vector2(-3, -3), footing + Vector2(2, -5),
			footing + Vector2(10, -3), footing + Vector2(6, 1), footing + Vector2(-2, 2)]), _stone(Color("#888b73")))
		deck_art.draw_line(footing + Vector2(-2, 5), footing + Vector2(6, 5), _stone(Color("#727965")), 1.0)
		deck_art.draw_rect(Rect2(x, front - 4, 8, 17), _wood(Color("#48372d")))
		deck_art.draw_rect(Rect2(x + 1, front + 1, 3, 11), _wood(Color("#96754f")))
		deck_art.draw_rect(Rect2(x + 5, front + 5, 2, 7), _wood(Color("#604734")))
		deck_art.draw_rect(Rect2(x, front + 7, 7, 2), _wood(Color("#75624d")))

func _draw_near_rail() -> void:
	_draw_rail(near_rail, 0.0)

func _draw_rail(layer: Node2D, y: float) -> void:
	var dark := _wood(Color("#5c4232"))
	var face := _wood(Color("#98704a"))
	var top := _wood(Color("#c5a471"))
	layer.draw_rect(Rect2(deck.position.x + 1, y - 7, deck.size.x - 2, 4), dark)
	layer.draw_rect(Rect2(deck.position.x + 1, y - 7, deck.size.x - 2, 1), top)
	for x: float in _posts:
		layer.draw_rect(Rect2(x - 2, y - 10, 5, 13), dark)
		layer.draw_rect(Rect2(x - 1, y - 9, 2, 11), face)
		layer.draw_rect(Rect2(x - 2, y - 11, 5, 2), top)
		layer.draw_rect(Rect2(x - 2, y - 5, 5, 1), Color("#b29b6d"))
	if season == Global.Season.WINTER:
		var frost := Color("#bfccc1")
		for index in _posts.size():
			var x := _posts[index]
			layer.draw_rect(Rect2(x - 2, y - 11, 4, 1), frost)
			if index < _posts.size() - 1:
				layer.draw_rect(Rect2(x + 4, y - 8, _posts[index + 1] - x - 9, 1), frost)
