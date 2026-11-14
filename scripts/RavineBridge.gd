extends Node2D

const DECK := Rect2(RavineLayout.BRIDGE_DECK.position - RavineLayout.BRIDGE, RavineLayout.BRIDGE_DECK.size)
const RAIL_Y := 13.0
const POSTS := [-25.0, 0.0, 25.0]
const PLANKS := Color("#b78c55")
const GRAIN := Color("#694b36")

var season := -1
var wet := false

func _ready() -> void:
	position = RavineLayout.BRIDGE
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	$NearRail.draw.connect(_draw_near_rail)
	_refresh()

func _refresh() -> void:
	var today := Global.season_index()
	var rain := Global.has_rain()
	if today == season and rain == wet:
		return
	season = today
	wet = rain
	queue_redraw()
	$NearRail.queue_redraw()

func _wood(color: Color) -> Color:
	return color.lerp(Color("#5c5a48"), 0.25) if wet else color

func _draw() -> void:
	# The sill is part of the bridge. The shadow lies on the water below it.
	draw_colored_polygon(PackedVector2Array([Vector2(-24, 13), Vector2(24, 13),
		Vector2(23, 30), Vector2(-20, 27)]), Color("#152f3390"))
	for x in [-24, 17]:
		draw_rect(Rect2(x, 7, 8, 17), Color("#49382e"))
		draw_rect(Rect2(x + 1, 13, 3, 8), Color("#77644c"))
		draw_rect(Rect2(x - 2, 21, 12, 4), Color("#53655b"))
	draw_colored_polygon(PackedVector2Array([Vector2(-27, 10), Vector2(27, 10),
		Vector2(26, 18), Vector2(18, 19), Vector2(-19, 19), Vector2(-26, 17)]), _wood(Color("#684831")))
	draw_rect(Rect2(-25, 15, 50, 2), _wood(Color("#8a603d")))
	draw_rect(DECK.grow(1.0), _wood(Color("#604431")))
	for index in 9:
		var x := -27 + index * 6
		var grain := posmod(index * 17 + 3, 11)
		var plank := _wood(PLANKS.lightened((grain - 4.0) * 0.021))
		draw_rect(Rect2(x, -13, 5, 26), plank)
		draw_rect(Rect2(x, -12, 1, 24), plank.lightened(0.16))
		draw_rect(Rect2(x + 2, -8 + grain, 1, 7 + grain % 3), Color(GRAIN, 0.32))
		draw_rect(Rect2(x + 3, 7 + grain % 3, 1, 3), Color(GRAIN, 0.48))
	draw_rect(Rect2(-27, 12, 54, 1), _wood(Color("#d0a66a")))
	for side: float in [-1.0, 1.0]:
		var cap := Rect2(side * 27.0 - 3.0, -14.0, 6.0, 28.0)
		draw_rect(cap, Color("#656656"))
		draw_rect(Rect2(cap.position + Vector2(1, 1), Vector2(3, 25)), Color("#aaa38b"))
		draw_rect(Rect2(cap.position + Vector2(1, 21), Vector2(4, 1)), Color("#585c4c"))
	_draw_rail(self, -RAIL_Y)

func _draw_near_rail() -> void:
	_draw_rail($NearRail, 0.0)

func _draw_rail(layer: Node2D, y: float) -> void:
	var dark := _wood(Color("#5c4232"))
	var face := _wood(Color("#98704a"))
	var top := _wood(Color("#c5a471"))
	layer.draw_rect(Rect2(-26, y - 7, 52, 4), dark)
	layer.draw_rect(Rect2(-26, y - 7, 52, 1), top)
	for x: float in POSTS:
		layer.draw_rect(Rect2(x - 2, y - 10, 5, 13), dark)
		layer.draw_rect(Rect2(x - 1, y - 9, 2, 11), face)
		layer.draw_rect(Rect2(x - 2, y - 11, 5, 2), top)
		layer.draw_rect(Rect2(x - 2, y - 5, 5, 1), Color("#b29b6d"))
	if season == Global.Season.WINTER:
		var frost := Color("#bfccc1")
		layer.draw_rect(Rect2(-22, y - 8, 12, 1), frost)
		layer.draw_rect(Rect2(5, y - 8, 17, 1), frost)
		for x: float in POSTS:
			layer.draw_rect(Rect2(x - 2, y - 11, 4, 1), frost)
