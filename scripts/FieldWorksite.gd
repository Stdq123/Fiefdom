extends Node2D

const TOOLS := "res://assets/world/fieldwork-tools.png"
const SOIL := "res://assets/world/fieldwork-soil.png"
const TOOL_CELL := 48.0
const SOIL_CELL := 52.0
const PEG := 4
const SOD := 5
const RIM := Rect2(-22, -21, 44, 42)
const KIT_AT := [Vector2(-6, 4), Vector2(7, 3), Vector2(1, 0), Vector2(13, 13)]
const KIT_SIZE := [24.0, 22.0, 25.0, 17.0]

static var _tools: Texture2D
static var _pieces: Dictionary[int, AtlasTexture] = {}

@onready var soil: Texture2D = load(SOIL)
var entrance := Vector2.DOWN
var stage := 0

static func tool_texture(index: int) -> AtlasTexture:
	if not _pieces.has(index):
		if not _tools:
			_tools = load(TOOLS)
		var piece := AtlasTexture.new()
		piece.atlas = _tools
		piece.region = Rect2(index * TOOL_CELL, 0, TOOL_CELL, TOOL_CELL)
		piece.filter_clip = true
		_pieces[index] = piece
	return _pieces[index]

func _draw() -> void:
	var wet := Global.has_rain()
	var frost := Global.season_index() == Global.Season.WINTER
	var light := Color("#b2afa3") if wet else Color.WHITE
	var cord := Color("#c3ae85") if wet else Color("#dfc38a")
	if stage > 0:
		var earth_light := Color("#a49a8c") if wet else (Color("#d2c8b5") if frost else Color.WHITE)
		var ground := Rect2(Vector2.ONE * (-SOIL_CELL * 0.5), Vector2.ONE * SOIL_CELL)
		var source := Rect2(0.0 if stage == 1 else SOIL_CELL, 0, SOIL_CELL, SOIL_CELL)
		draw_texture_rect_region(soil, ground, source, earth_light)
	if stage == 1:
		_piece(SOD, Vector2(-12, -5), 11.0, light)
		_piece(SOD, Vector2(-16, 5), 7.0, light)
	elif stage == 3:
		for offset: float in [-8.0, 8.0]:
			_cord(Vector2(offset, -21), Vector2(offset, 21), 1.0, cord)
			_cord(Vector2(-22, offset), Vector2(22, offset), 1.0, cord)

	_piece(stage, KIT_AT[stage], KIT_SIZE[stage], light)
	var outline := EstateLayout.field_boundary(RIM, entrance, EstateLayout.FIELD_ENTRANCE_WIDTH)
	for i in range(1, outline.size()):
		_cord(outline[i - 1], outline[i], 5.0, cord)
	for point in EstateLayout.corners(RIM):
		_peg(point, 10.0, light, frost)
	if entrance != Vector2.ZERO:
		_peg(outline[0], 8.0, light, frost)
		_peg(outline[-1], 8.0, light, frost)

func _cord(start: Vector2, end: Vector2, height: float, cord: Color) -> void:
	draw_line(start + Vector2.ONE, end + Vector2.ONE, Color("#453a2e61"), 0.7)
	var top := Vector2.UP * height
	var sag := Vector2.DOWN * minf(0.85, start.distance_to(end) * 0.025)
	var path := PackedVector2Array([start + top, start.lerp(end, 0.5) + top + sag, end + top])
	draw_polyline(path, Color("#554531"), 1.2)
	for i in path.size():
		path[i].y -= 0.5
	draw_polyline(path, cord, 0.7)

func _peg(foot: Vector2, height: float, light: Color, frost: bool) -> void:
	draw_rect(Rect2(foot + Vector2(-0.75, 0), Vector2(3.5, 1.0)), Color("#3e382a79"))
	_piece(PEG, foot + Vector2.UP * (height * 0.46), height, light)
	if frost:
		draw_line(foot + Vector2(-0.65, -height * 0.88), foot + Vector2(0.65, -height * 0.93), Color("#d7d7c1"), 0.7)

func _piece(index: int, at: Vector2, span: float, light: Color) -> void:
	var size := Vector2.ONE * span
	draw_texture_rect(tool_texture(index), Rect2(at - size * 0.5, size), false, light)
