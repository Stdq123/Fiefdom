extends "res://scripts/FishingSpot.gd"

const BOARD := Color("#ab875d")
const TIMBER := Color("#604c38")
const RAILS := [Rect2(166, 701, 34, 3), Rect2(197, 704, 3, 20), Rect2(167, 724, 33, 3)]
var railing: StaticBody2D

func _ready() -> void:
	position = EstateLayout.POND_LANDING
	site = CreekFish.Site.POND
	water = Vector2(34, -1)
	super._ready()
	hint.position += Vector2(-12, -11)
	var deck := Node2D.new()
	deck.name = "Deck"
	deck.z_index = -3
	deck.draw.connect(_draw_deck.bind(deck))
	add_child(deck)
	railing = StaticBody2D.new()
	railing.name = "Railing"
	railing.collision_mask = 0
	visible = Global.pond_landing_day() > 0
	railing.process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED
	add_child(railing)
	for bounds: Rect2 in RAILS:
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = bounds.size
		collision.shape = shape
		collision.position = bounds.get_center() - position
		railing.add_child(collision)
		var rail := Node2D.new()
		rail.position = Vector2(0, bounds.end.y - position.y)
		rail.draw.connect(_draw_rail.bind(rail, bounds))
		add_child(rail)
	set_process(not visible)
	GameEvents.day_advanced.connect(_redraw_weather.unbind(1))

func _process(_delta: float) -> void:
	if Global.pond_landing_day() > 0:
		show()
		railing.process_mode = Node.PROCESS_MODE_INHERIT
		set_process(false)
		GameEvents.pond_landing_opened.emit()

func can_interact_from(foot: Vector2) -> bool:
	var on_deck := EstateLayout.POND_DECK.has_point(foot - global_position + position)
	return visible and not Global.is_indoors() and on_deck and super.can_interact_from(foot)

func _redraw_weather() -> void:
	for child in get_children():
		if child is Node2D:
			child.queue_redraw()
	queue_redraw()

func _draw_deck(deck: Node2D) -> void:
	var bounds := EstateLayout.POND_DECK
	bounds.position -= position
	var near := bounds.end.y
	var wet := Global.has_rain()
	deck.draw_colored_polygon(PackedVector2Array([Vector2(bounds.position.x + 8, near - 2),
		Vector2(bounds.end.x, near - 2), Vector2(bounds.end.x + 5, near + 10),
		Vector2(bounds.end.x - 13, near + 15)]), Color("#17393493"))
	for x: float in [bounds.position.x + 15, bounds.end.x - 7]:
		deck.draw_rect(Rect2(x, near - 4, 5, 12), Color("#514437"))
		deck.draw_rect(Rect2(x + 1, near - 3, 2, 9), Color("#807253"))
		deck.draw_rect(Rect2(x - 1, near + 5, 7, 2), Color("#647669"))
	deck.draw_rect(Rect2(bounds.position + Vector2(0, 2), bounds.size + Vector2(0, 3)), TIMBER.darkened(0.16))
	deck.draw_rect(bounds, TIMBER)
	for offset in range(0, int(bounds.size.x), 5):
		var x := bounds.position.x + offset
		var plank := BOARD.lightened((posmod(offset * 3, 11) - 3) * 0.019)
		if wet:
			plank = plank.darkened(0.19)
		var width := minf(4.0, bounds.end.x - x)
		deck.draw_rect(Rect2(x, bounds.position.y + 1, width, bounds.size.y - 2), plank)
		deck.draw_rect(Rect2(x, bounds.position.y + 3, 1, 8 + offset % 4), plank.lightened(0.21))
		deck.draw_rect(Rect2(x + 2, near - 6 - offset % 4, 1, 5), TIMBER.lightened(0.12))
	deck.draw_rect(Rect2(bounds.position.x, near - 1, bounds.size.x, 1), BOARD.lightened(0.26))
	deck.draw_rect(Rect2(bounds.position.x + 2, near + 2, bounds.size.x - 4, 2), BOARD.darkened(0.28))

func _draw_rail(art: Node2D, bounds: Rect2) -> void:
	var local := bounds.position - position - art.position
	var top := local - Vector2(0, 7)
	var beam := Rect2(top, bounds.size)
	var shade := TIMBER.darkened(0.15) if Global.has_rain() else TIMBER
	art.draw_rect(Rect2(beam.position + Vector2(0, 2), beam.size), shade)
	art.draw_rect(beam, BOARD.darkened(0.15))
	if bounds.size.x > bounds.size.y:
		art.draw_rect(Rect2(top, Vector2(bounds.size.x, 1)), BOARD.lightened(0.29))
	else:
		art.draw_rect(Rect2(top, Vector2(1, bounds.size.y)), BOARD.lightened(0.29))
	var last := bounds.size - Vector2(3, 3)
	for at: Vector2 in [local, local + last]:
		art.draw_rect(Rect2(at - Vector2(1, 9), Vector2(4, 12)), shade)
		art.draw_rect(Rect2(at - Vector2(0, 10), Vector2(3, 3)), BOARD.lightened(0.33))
		if Global.season_index() == Global.Season.WINTER:
			art.draw_rect(Rect2(at - Vector2(0, 10), Vector2(3, 1)), Color("#c0c8b4"))

func _draw() -> void:
	if line_visible:
		_draw_line()
