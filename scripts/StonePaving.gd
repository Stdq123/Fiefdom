extends RefCounted

const TERRAIN := preload("res://scripts/EstateTerrain.gd")
const COURSE := 7.0
# The joint displacement and the bevel both extend slightly past a column's nominal edge.
const JOINT_PADDING := 4.0
const LIP := Vector2(0.45, 2.8)

var outline: PackedVector2Array
var _stones: Array[Dictionary] = []
var _split_fragments := PackedInt32Array()
var _curb: Array[Dictionary] = []

func _init(surface: PackedVector2Array, joint_origin: float, joins: Array[PackedVector2Array] = [],
		block_width := 17.0, curb_drop := LIP) -> void:
	outline = surface
	var area := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		area = area.expand(point)
	for row in range(floori(area.position.y / COURSE), ceili(area.end.y / COURSE)):
		var offset := joint_origin + posmod(row, 2) * floorf(block_width * 0.48)
		var span := _course_span(row * COURSE)
		if span.x > span.y:
			continue
		var left := maxf(area.position.x, span.x - JOINT_PADDING)
		var right := minf(area.end.x, span.y + JOINT_PADDING)
		for column in range(floori((left - offset) / block_width) - 1, ceili((right - offset) / block_width) + 1):
			var first := _joint(column, row, offset, block_width)
			var last := _joint(column + 1, row, offset, block_width) - Vector2(1.15, 0.0)
			var grain := posmod(column * 7 + row * 11, 19)
			var bed := first.y + COURSE - 0.9 - float(grain % 3) * 0.35
			var shape := PackedVector2Array([
				first + Vector2(0.8 + grain % 2, 0.0), last - Vector2(1.2, 0.0),
				last + Vector2(0.3, 1.5), Vector2(last.x - 0.3, bed - 0.9), Vector2(last.x - 1.8, bed),
				Vector2(first.x + 1.0, bed), first + Vector2(-0.3, 3.0),
			])
			var full := true
			for corner in shape:
				if not Geometry2D.is_point_in_polygon(corner, outline):
					full = false
					break
			if full:
				_stones.append({"shape": shape, "grain": grain, "full": true})
			else:
				var fragments := Geometry2D.intersect_polygons(shape, outline)
				for fragment in fragments:
					if not Geometry2D.triangulate_polygon(fragment).is_empty():
						if fragments.size() > 1:
							_split_fragments.append(_stones.size())
						_stones.append({"shape": fragment, "grain": grain, "full": false})
	_build_curb(joins, curb_drop)

func _course_span(top: float) -> Vector2:
	# Keep entire edges that meet this row, including the corners of diagonal lanes.
	var span := Vector2(INF, -INF)
	var bottom := top + COURSE
	var start := outline[-1]
	for end: Vector2 in outline:
		if maxf(start.y, end.y) >= top and minf(start.y, end.y) <= bottom:
			span.x = minf(span.x, minf(start.x, end.x))
			span.y = maxf(span.y, maxf(start.x, end.x))
		start = end
	return span

func _joint(column: int, row: int, offset: float, width: float) -> Vector2:
	return Vector2(offset + column * width + posmod(column * 11 + row * 13, 7) - 3, row * COURSE)

func _build_curb(joins: Array[PackedVector2Array], drop: Vector2) -> void:
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		if a.distance_to(b) < 0.15:
			continue
		var side := (b - a).orthogonal().normalized()
		if Geometry2D.is_point_in_polygon(a.lerp(b, 0.5) + side * 0.3, outline):
			side = -side
		if side.y < 0.32:
			continue
		var spans := ceili(a.distance_to(b) / 10.0)
		for span in spans:
			var start := a.lerp(b, float(span) / spans)
			var end := a.lerp(b, float(span + 1) / spans)
			var foot := start.lerp(end, 0.5) + side * 1.5
			var flush := joins.any(func(path: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(foot, path))
			_curb.append({"start": start, "end": end, "drop": drop * (0.28 if flush else 1.0)})

func draw(canvas: CanvasItem, loam: Color, winter: bool, wet: bool,
		stone_color := Color("#b6ad90"), stone_grain: Texture2D = null) -> void:
	var grout := loam.lerp(Color("#626658"), 0.78)
	var stone := stone_color.lerp(Color("#798782"), 0.36) if wet else stone_color
	if winter:
		stone = stone.lerp(Color("#b8c2b4"), 0.29)
	_draw_curb(canvas, stone, winter, stone_grain)
	canvas.draw_colored_polygon(outline, grout)
	_draw_slabs(canvas, grout, stone, stone_grain)

func _draw_slabs(canvas: CanvasItem, grout: Color, stone: Color, grain_texture: Texture2D) -> void:
	# The course gutters also separate the bevels and marks of neighboring stones.
	var faces := TERRAIN.SurfaceBatch.new()
	var bevels := TERRAIN.SurfaceBatch.new()
	var shines := PackedVector2Array()
	var shine_colors := PackedColorArray()
	var grain_marks := PackedVector2Array()
	var grain_colors := PackedColorArray()
	for index in _stones.size():
		var slab := _stones[index]
		var face: PackedVector2Array = slab.shape
		var grain: int = slab.grain
		var top := grout.lerp(stone, 0.48 + grain * 0.020)
		var side := top.darkened(0.21)
		var center := Vector2.ZERO
		for point in face:
			center += point
		center /= face.size()
		var bevel := PackedVector2Array()
		for point in face:
			bevel.append(point.lerp(center, 0.15) - Vector2(0.2, 0.27))
		# Fragments of one stone can touch. Keep their original layering.
		if index in _split_fragments:
			canvas.draw_colored_polygon(face, side)
			TERRAIN.draw_loam(canvas, bevel, top, grain_texture)
			continue
		faces.add_polygon(face, PackedColorArray([side]))
		bevels.add_polygon(bevel, PackedColorArray([top]))
		if slab.full:
			shines.append(bevel[0].lerp(bevel[1], 0.14))
			shines.append(bevel[0].lerp(bevel[1], 0.46 + (grain % 5) * 0.07))
			shine_colors.append(top.lightened(0.19))
			if grain % 4 == 0:
				grain_marks.append(center + Vector2(-2.0, 0.5))
				grain_marks.append(center + Vector2(2.0, 0.5))
				grain_colors.append(top.darkened(0.12))
	faces.draw(canvas)
	bevels.draw(canvas, grain_texture)
	if not shines.is_empty():
		canvas.draw_multiline_colors(shines, shine_colors, 0.7)
	if not grain_marks.is_empty():
		canvas.draw_multiline_colors(grain_marks, grain_colors, 0.65)

func _draw_curb(canvas: CanvasItem, stone: Color, winter: bool, stone_grain: Texture2D) -> void:
	for index in _curb.size():
		var section := _curb[index]
		var a: Vector2 = section.start
		var b: Vector2 = section.end
		var ledge: Vector2 = section.drop
		var foot := ledge + Vector2(0.0, 1.0)
		canvas.draw_colored_polygon(PackedVector2Array([a, b, b + foot, a + foot]), Color("#3b3e3335"))
		var riser := stone.darkened(0.46 + (index % 3) * 0.028)
		TERRAIN.draw_loam(canvas, PackedVector2Array([a, b, b + ledge, a + ledge]), riser, stone_grain)
		var lip_color := stone.lightened(0.18) if winter and index % 3 == 0 else stone.darkened(0.12)
		canvas.draw_line(a, b, lip_color, 0.95)
