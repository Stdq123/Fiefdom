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
	deck_art.draw_colored_polygon(PackedVector2Array([Vector2(west + 3, front), Vector2(east - 3, front),
		Vector2(east - 4, front + 17), Vector2(west + 7, front + 14)]), Color("#152f3390"))
	for x in [west + 3, east - 10]:
		deck_art.draw_rect(Rect2(x, front - 6, 8, 17), Color("#49382e"))
		deck_art.draw_rect(Rect2(x + 1, front, 3, 8), Color("#77644c"))
		deck_art.draw_rect(Rect2(x - 2, front + 8, 12, 4), Color("#53655b"))
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
		deck_art.draw_rect(cap, Color("#656656"))
		deck_art.draw_rect(Rect2(cap.position + Vector2(1, 1), Vector2(3, deck.size.y - 1)), Color("#aaa38b"))
		deck_art.draw_rect(Rect2(cap.position + Vector2(1, deck.size.y - 5), Vector2(4, 1)), Color("#585c4c"))
	_draw_rail(deck_art, back)

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
