extends Node2D

const SHADER := preload("res://resources/water-surface.gdshader")

var patches: Array[PackedVector2Array] = []
var glint := Color.WHITE
var clock := 0.0
var surface := ShaderMaterial.new()

func _init(outline: PackedVector2Array, speed: float, crossings: Array[Rect2] = []) -> void:
	patches.append(outline)
	for crossing in crossings:
		var visible_water: Array[PackedVector2Array] = []
		for patch in patches:
			visible_water.append_array(Geometry2D.clip_polygons(patch, EstateLayout.corners(crossing)))
		patches = visible_water
	surface.shader = SHADER
	surface.set_shader_parameter("current_speed", speed)
	material = surface

func set_weather(water: Color, wet: bool) -> void:
	glint = water.lerp(Color("#b6d2b6"), 0.72)
	surface.set_shader_parameter("raining", wet)
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	surface.set_shader_parameter("water_clock", clock)

func _draw() -> void:
	for patch in patches:
		draw_colored_polygon(patch, glint)

static func draw_shore(canvas: CanvasItem, outline: PackedVector2Array, silt: Color, water: Color,
		winter: bool, crossings: Array[Rect2] = []) -> void:
	var side := -1.0 if Geometry2D.is_polygon_clockwise(outline) else 1.0
	var frost := Color("#b4c7ba")
	var mark := 0
	var distance := 6.0
	for index in outline.size():
		var start := outline[index]
		var finish := outline[(index + 1) % outline.size()]
		var length := start.distance_to(finish)
		var along := start.direction_to(finish)
		var outward := Vector2(-along.y, along.x) * side
		while distance < length:
			var foot := start + along * distance
			var patch := posmod(mark * 37, 17)
			mark += 1
			distance += 8.0 + patch
			if crossings.any(func(crossing: Rect2) -> bool: return crossing.has_point(foot)):
				continue
			var at := (foot + outward * (2 + patch % 4)).round()
			var stone := silt.lightened(0.10 + (patch % 5) * 0.035)
			canvas.draw_rect(Rect2(at, Vector2(3 + patch % 5, 2)), stone)
			if patch % 3 == 0:
				canvas.draw_rect(Rect2(at + Vector2(1, -1), Vector2(2 + patch % 3, 1)), stone.lightened(0.15))
			var edge := (foot - outward * (1 + patch % 3)).round()
			var rim := frost if winter else water.lightened(0.18)
			canvas.draw_rect(Rect2(edge, Vector2(3 + patch % 5, 1)), Color(rim, 0.68))
		distance -= length
