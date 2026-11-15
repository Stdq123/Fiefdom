extends StaticBody2D

const HEIGHT := 13.0
const FOOTPRINT := Rect2(-13.5, -8.0, 29.0, 8.0)
const FRONT_LEFT := Vector2(-17, -HEIGHT)
const FRONT_RIGHT := Vector2(14, -HEIGHT)
const FAR_LEFT := Vector2(-12, -HEIGHT - 6)
const FAR_RIGHT := Vector2(19, -HEIGHT - 6)

var kind: MarketStall.Kind

func _init(display_kind: MarketStall.Kind, wet: bool) -> void:
	kind = display_kind
	collision_mask = 0
	modulate = Color("#cbd8d6") if wet else Color.WHITE

func _ready() -> void:
	var feet := CollisionShape2D.new()
	var base := RectangleShape2D.new()
	base.size = FOOTPRINT.size
	feet.name = "Feet"
	feet.position = FOOTPRINT.get_center()
	feet.shape = base
	add_child(feet)

static func draw_shadow(canvas: CanvasItem, at: Vector2, shade: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-15, -5), at + Vector2(14, -9),
		at + Vector2(27, -5), at + Vector2(22, 1), at + Vector2(7, 4), at + Vector2(-16, 1)]), shade)

func _draw() -> void:
	match kind:
		MarketStall.Kind.GRAIN:
			_draw_trestle(Color("#a47951"))
			_draw_basket(Vector2(-7, -16), 8, Color("#d3a85f"))
			_draw_basket(Vector2(7, -16), 5, Color("#bd965d"))
		MarketStall.Kind.FISH:
			_draw_trestle(Color("#827f69"))
			_draw_fish_tray()
		MarketStall.Kind.SILK:
			_draw_trestle(Color("#996747"))
			_draw_cloth()

func _draw_trestle(wood: Color) -> void:
	for x in [-13.0, 9.0]:
		draw_rect(Rect2(x + 5, -16, 3, 12), wood.darkened(0.47))
		draw_rect(Rect2(x, -11, 4, 11), wood.darkened(0.32))
		draw_rect(Rect2(x, -10, 1, 9), wood.lightened(0.05))
		draw_rect(Rect2(x - 1, -2, 6, 2), wood.darkened(0.39))
	draw_rect(Rect2(-12, -7, 25, 2), wood.darkened(0.36))
	var drop := Vector2(0, 3)
	draw_colored_polygon(PackedVector2Array([FRONT_LEFT, FRONT_RIGHT, FAR_RIGHT, FAR_LEFT]), wood.lightened(0.15))
	draw_colored_polygon(PackedVector2Array([FRONT_RIGHT, FAR_RIGHT, FAR_RIGHT + drop, FRONT_RIGHT + drop]), wood.darkened(0.43))
	draw_colored_polygon(PackedVector2Array([FRONT_LEFT, FRONT_RIGHT, FRONT_RIGHT + drop, FRONT_LEFT + drop]), wood.darkened(0.25))
	draw_line(FRONT_LEFT + Vector2(1, 0), FRONT_RIGHT, wood.lightened(0.14), 0.9)
	draw_line(FAR_LEFT + Vector2(2, 1), FAR_RIGHT - Vector2(2, -1), wood.lightened(0.22), 0.65)

func _draw_basket(at: Vector2, radius: float, wicker: Color) -> void:
	var rim := at - Vector2(0, radius * 0.70)
	var body := PackedVector2Array([rim + Vector2(-radius, 0), rim + Vector2(radius, 0),
		at + Vector2(radius - 1, -0.6), at + Vector2(radius - 3, 1.4), at + Vector2(2 - radius, 1.4),
		at + Vector2(0.9 - radius, -1)])
	draw_colored_polygon(body, wicker.darkened(0.33))
	draw_line(at + Vector2(2.5 - radius, -1.5), at + Vector2(radius - 1.6, -1.5), wicker.darkened(0.12), 1.0)
	draw_line(at + Vector2(2.0 - radius, -3.2), at + Vector2(radius - 1.2, -3.2), wicker.darkened(0.20), 0.8)
	var mouth := PackedVector2Array([rim + Vector2(-radius, 0), rim + Vector2(-radius + 2, -2.5),
		rim + Vector2(radius - 2.8, -2.7), rim + Vector2(radius, -0.5),
		rim + Vector2(radius - 2, 2), rim + Vector2(2.5 - radius, 2.2)])
	draw_colored_polygon(mouth, wicker.lightened(0.18))
	draw_colored_polygon(PackedVector2Array([rim + Vector2(-radius + 2, 0), rim + Vector2(-radius + 4, -1.65),
		rim + Vector2(radius - 3, -1.4), rim + Vector2(radius - 2, 0), rim + Vector2(radius - 3.8, 1.35),
		rim + Vector2(4 - radius, 1.3)]), Color("#aa7543"))
	for x in range(3 - roundi(radius), roundi(radius) - 2, 2):
		draw_rect(Rect2(rim + Vector2(x, (x % 3) * 0.52 - 0.7), Vector2(1.5, 0.85)), Color("#ebc978"))

func _draw_fish_tray() -> void:
	var far_left := Vector2(-6, -23)
	var far_right := Vector2(12, -22)
	var near_left := Vector2(-11, -16)
	var near_right := Vector2(10, -15)
	draw_colored_polygon(PackedVector2Array([far_left, far_right, near_right + Vector2(0, 2), near_left + Vector2(0, 2)]), Color("#475854"))
	draw_colored_polygon(PackedVector2Array([far_left, far_right, near_right, near_left]), Color("#81998b"))
	draw_colored_polygon(PackedVector2Array([far_left + Vector2(1, 1.4), far_right + Vector2(-1.2, 1),
		near_right + Vector2(-0.9, -1.2), near_left + Vector2(2, -1)]), Color("#496667"))
	_draw_fish(Vector2(0, -20), Color("#d0d9bf"))
	_draw_fish(Vector2(2, -17.25), Color("#92ad9f"))
	draw_line(near_left + Vector2(1.2, -0.4), near_right - Vector2(1.0, 0.4), Color("#9fb5a1"), 0.7)

func _draw_fish(at: Vector2, scales: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(-5, -0.1), at + Vector2(-2, -1.3),
		at + Vector2(2, -1.2), at + Vector2(5, -0.1), at + Vector2(7, -1.25), at + Vector2(7, 1.1),
		at + Vector2(5, 0.35), at + Vector2(1.25, 1.4), at + Vector2(-2, 1.2)]), scales)
	draw_rect(Rect2(at + Vector2(-3, -0.5), Vector2(0.9, 0.9)), Color("#465652"))

func _draw_cloth() -> void:
	var indigo := Color("#667da3")
	var rose := Color("#b87c83")
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -19), Vector2(5, -19),
		Vector2(3, -13), Vector2(-10, -13)]), indigo.lightened(0.19))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -13), Vector2(3, -13), Vector2(2, -4),
		Vector2(-4, -3), Vector2(-10, -4)]), indigo)
	draw_line(Vector2(-8, -12), Vector2(-8, -5), indigo.lightened(0.24), 1.2)
	draw_line(Vector2(1, -12), Vector2(0, -4.5), indigo.darkened(0.24), 1.0)
	draw_line(Vector2(-9, -5.3), Vector2(0.7, -4.85), Color("#a0b2bf"), 0.7)
	draw_colored_polygon(PackedVector2Array([Vector2(4, -20), Vector2(13, -20),
		Vector2(15, -18), Vector2(13, -15), Vector2(3, -15), Vector2(2, -16.6)]), rose.darkened(0.27))
	draw_colored_polygon(PackedVector2Array([Vector2(4, -20), Vector2(13, -20), Vector2(15, -18),
		Vector2(5, -17.8), Vector2(2, -16.6)]), rose.lightened(0.18))
	draw_line(Vector2(6, -18.5), Vector2(13.5, -18.5), rose.lightened(0.33), 0.8)
