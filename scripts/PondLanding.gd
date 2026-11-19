extends "res://scripts/FishingSpot.gd"

const CARPENTRY := preload("res://scripts/WoodenBridge.gd")
const RAILS := [Rect2(166, 701, 34, 3), Rect2(197, 704, 3, 20), Rect2(167, 724, 33, 3)]
var railing: StaticBody2D
var timber: Texture2D = load(CARPENTRY.TIMBER_PATH)

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
	_draw_timber(deck, Rect2(bounds.position, CARPENTRY.LANDING_DECK.size), CARPENTRY.LANDING_DECK)

func _draw_rail(art: Node2D, bounds: Rect2) -> void:
	var top := bounds.position - position - art.position + Vector2.UP * 9.0
	if bounds.size.x > bounds.size.y:
		_draw_timber(art, Rect2(top - Vector2(1, 1), Vector2(bounds.size.x + 3, 12)), CARPENTRY.LANDING_RAIL)
	else:
		_draw_timber(art, Rect2(top + Vector2(0, 1), Vector2(4, bounds.size.y + 2)), CARPENTRY.LANDING_RETURN)

func _draw_timber(layer: Node2D, dest: Rect2, region: Rect2) -> void:
	CARPENTRY.draw_timber(layer, timber, dest, region, Global.season_index() == Global.Season.WINTER,
		CARPENTRY.WET_WOOD if Global.has_rain() else Color.WHITE)

func _draw() -> void:
	if line_visible:
		_draw_line()
