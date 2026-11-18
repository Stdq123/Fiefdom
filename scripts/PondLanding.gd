extends "res://scripts/FishingSpot.gd"

const BRIDGE := preload("res://assets/world/creek-road-bridge.png")
const RAILS := [Rect2(166, 701, 34, 3), Rect2(197, 704, 3, 20), Rect2(167, 724, 33, 3)]
var railing: StaticBody2D

func _ready() -> void:
	position = EstateLayout.POND_LANDING
	site = CreekFish.Site.POND
	water = Vector2(34, -1)
	super._ready()
	hint.position += Vector2(-12, 3)
	var deck := Node2D.new()
	deck.name = "Deck"
	deck.z_index = -3
	deck.draw.connect(_draw_deck.bind(deck))
	add_child(deck)
	var basket := Node2D.new()
	basket.name = "Creel"
	basket.position = Vector2(-12, -6)
	basket.draw.connect(_draw_creel.bind(basket, Vector2.ZERO))
	add_child(basket)
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
	deck.draw_colored_polygon(PackedVector2Array([Vector2(bounds.position.x + 8, near - 2),
		Vector2(bounds.end.x, near - 2), Vector2(bounds.end.x + 5, near + 10),
		Vector2(bounds.end.x - 13, near + 15)]), Color("#17393493"))
	for x: float in [bounds.position.x + 7, bounds.end.x - 14]:
		_draw_timber(deck, Rect2(x, near + 2, 15, 11), Rect2(22, 62, 28, 22))
	_draw_timber(deck, Rect2(bounds.position, bounds.size + Vector2(0, 5)), Rect2(23, 18, 64, 44))

func _draw_rail(art: Node2D, bounds: Rect2) -> void:
	var top := bounds.position - position - art.position + Vector2.UP * 9.0
	if bounds.size.x > bounds.size.y:
		_draw_timber(art, Rect2(top - Vector2(1, 1), Vector2(bounds.size.x + 3, 14)), Rect2(8, 86, 38, 18))
	else:
		# The return rail runs away from the viewer between the two horizontal post caps.
		_draw_timber(art, Rect2(top + Vector2(0, 1), Vector2(4, bounds.size.y + 2)), Rect2(29, 18, 5, 30))
		var highlight := Color("#c1c5af") if Global.season_index() == Global.Season.WINTER else Color("#ad8e63")
		art.draw_line(top + Vector2(0.5, 2), top + Vector2(0.5, bounds.size.y), highlight, 1.0)

func _draw_timber(layer: Node2D, dest: Rect2, region: Rect2) -> void:
	if Global.season_index() == Global.Season.WINTER:
		region.position.x += 114.0
	var tint := Color("#bdc9c2") if Global.has_rain() else Color.WHITE
	layer.draw_texture_rect_region(BRIDGE, dest, region, tint)

func _draw() -> void:
	if line_visible:
		_draw_line()
