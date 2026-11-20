extends Node2D

const FLIGHT_END := 0.76
const PETAL_INK := [Color("#e7b7ae"), Color("#f2d3bb"), Color("#c99183")]
const LEAF_INK := [Color("#cf9e55"), Color("#ac683e"), Color("#d1ad68")]

static var petal_shape := PackedVector2Array([Vector2(-1, 0), Vector2(-0.5, -0.7), Vector2(0.45, -0.68),
	Vector2(1, -0.13), Vector2(0.42, 0.64), Vector2(-0.46, 0.45)])
static var leaf_shape := PackedVector2Array([Vector2(-1.35, 0), Vector2(-0.28, -0.68), Vector2(0.62, -0.46),
	Vector2(1.45, -0.05), Vector2(0.43, 0.62), Vector2(-0.54, 0.48)])

class Crown:
	var tree: Sprite2D
	var blooms: bool

	func _init(sprite: Sprite2D, flowering: bool) -> void:
		tree = sprite
		blooms = flowering

var crowns: Array[Crown] = []
var petals := false
var elapsed := 0.0
var wind_phase := 0.0

func _init() -> void:
	name = "CanopyDrift"
	z_as_relative = false
	z_index = -1

func track(tree: Sprite2D, blooms: bool) -> void:
	crowns.append(Crown.new(tree, blooms))

func refresh() -> void:
	var season := Global.season_index()
	petals = season == Global.Season.SPRING
	visible = (petals or season == Global.Season.AUTUMN) and not Global.has_rain() and not Global.is_indoors()
	queue_redraw()

func advance(delta: float, breeze: float) -> void:
	elapsed = fposmod(elapsed + delta, 300.0)
	wind_phase = breeze
	queue_redraw()

func _draw() -> void:
	var view := (get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()).grow(48.0)
	var to_drift := global_transform.affine_inverse()
	var shape := petal_shape if petals else leaf_shape
	var inks := PETAL_INK if petals else LEAF_INK
	for crown: Crown in crowns:
		if (petals and not crown.blooms) or not is_instance_valid(crown.tree) or not crown.tree.is_visible_in_tree():
			continue
		var tree_to_drift := to_drift * crown.tree.global_transform
		var bounds := tree_to_drift * crown.tree.get_rect()
		if not view.intersects(bounds):
			continue
		var root := tree_to_drift.origin
		for slot in (3 if petals else 2):
			var phase := root.dot(Vector2(0.045, 0.068)) + slot * 2.39996
			var side := sin(phase) * 0.5 + 0.5
			var cycle := fposmod(elapsed / 5.0 + phase * 0.37, 1.0)
			var fall := minf(cycle / FLIGHT_END, 1.0)
			var opacity := smoothstep(0.0, 0.10, cycle) * (1.0 - smoothstep(FLIGHT_END, 1.0, cycle))
			var start := bounds.position + bounds.size * Vector2(0.62 + side * 0.19, 0.21 + slot * 0.06)
			var landing := Vector2(bounds.end.x + 9.0 + side * 16.0, root.y + 8.0 + slot * 4.0)
			var point := start.lerp(landing, fall)
			point.x += sin(phase + fall * TAU + wind_phase * 2.0) * sin(fall * PI) * 4.0
			var spin := phase + fall * (2.4 if petals else 3.9)
			var size := lerpf(0.9, 1.45, side)
			draw_set_transform(point, spin, Vector2.ONE * size)
			draw_colored_polygon(shape, Color(inks[posmod(floori(phase * 8.0), inks.size())], opacity * 0.9))
	draw_set_transform(Vector2.ZERO)
