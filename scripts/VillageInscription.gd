extends Sprite2D
class_name VillageInscription

enum Form { OAK, BAMBOO, STONE, FIELD, EAVE, SURVEY, GRAIN, FISH, SILK }

const BOARDS := "res://assets/world/village-inscriptions.png"
const TRADE_SIGNS := "res://assets/world/market-trade-signs.png"
const LETTERING := preload("res://assets/fonts/MaShanZheng-Waymarks.woff2")
const BOARD_CELL := Vector2(64, 32)
const TRADE_CELL := Vector2(64, 24)
# Centre and usable width of the writing face, measured on each illustrated board.
const FACES := [
	Vector3(0.50, 0.39, 0.74), Vector3(0.50, 0.39, 0.70),
	Vector3(0.50, 0.50, 0.72), Vector3(0.50, 0.46, 0.72),
	Vector3(0.50, 0.60, 0.76), Vector3(0.50, 0.48, 0.72),
]
const TRADE_FACE := Vector3(0.615, 0.62, 0.53)
const HEIGHTS := [27.0, 26.0, 19.0, 18.0, 12.5, 28.0]
const ARROW := [Vector2(-3.75, -0.85), Vector2(0, -0.85), Vector2(0, -2.8),
	Vector2(3.8, 0), Vector2(0, 2.8), Vector2(0, 0.85), Vector2(-3.75, 0.85)]

var caption: Label

static func place(layer: Node2D, foot: Vector2, form: Form, inscription: String, bearing := Vector2.ZERO,
		bank_caption := false) -> VillageInscription:
	var board := VillageInscription.new()
	board.name = inscription.get_slice("\n", 0) + ("路牌" if bearing != Vector2.ZERO else "铭牌")
	board.position = foot
	board.centered = false
	var trade := form >= Form.GRAIN
	var cell := TRADE_CELL if trade else BOARD_CELL
	var index := Vector2i(0, form - Form.GRAIN) if trade else Vector2i(form % 2, floori(form / 2.0))
	var cut := AtlasTexture.new()
	cut.atlas = load(TRADE_SIGNS if trade else BOARDS)
	cut.region = Rect2(Vector2(index) * cell, cell)
	cut.filter_clip = true
	board.texture = cut
	board.offset = Vector2(-cell.x * 0.5, 1.0 - cell.y)
	layer.add_child(board)

	var ink := Label.new()
	board.caption = ink
	ink.name = "Status" if bank_caption else "Caption"
	ink.text = inscription
	ink.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ink.add_theme_font_override("font", LETTERING)
	ink.add_theme_font_size_override("font_size", 22)
	ink.add_theme_constant_override("line_spacing", -5)
	var color := Color("#35271b") if form in [Form.FIELD, Form.SURVEY] else Color("#f4dfb0")
	ink.add_theme_color_override("font_color", color)
	# Field marker callers read Status beside Boundary and Worksite in the tile layer.
	if bank_caption:
		layer.add_child(ink)
	else:
		board.add_child(ink)
	ink.reset_size()
	var density := 0.42
	if trade or form == Form.FIELD:
		density = 0.38
	elif form in [Form.EAVE, Form.SURVEY]:
		density = 0.34
	var writing := ink.size * density
	var face: Vector3 = TRADE_FACE if trade else FACES[form]
	var height: float = 17.0 if trade else HEIGHTS[form]
	if form == Form.SURVEY and not inscription.contains("\n"):
		height = 20.0
	var has_arrow := not bearing.is_zero_approx()
	var arrow_space := 10.0 if has_arrow else 0.0
	var width := ceilf((writing.x + arrow_space + 2.0) / face.z)
	if trade:
		width = maxf(38.0, width)
	board.scale = Vector2(width, height) / cell
	var center := board.offset * board.scale + Vector2(width * face.x, height * face.y)
	var text_center := center
	if has_arrow:
		var side := -1.0 if bearing.x < -0.01 else 1.0
		text_center.x -= side * arrow_space * 0.5
		board._engrave_arrow(center + Vector2(side * (writing.x + 2.0) * 0.5, 0), bearing, color)
	var top_left := text_center - writing * 0.5
	if bank_caption:
		ink.scale = Vector2.ONE * density
		ink.position = foot + top_left
	else:
		ink.scale = Vector2.ONE * density / board.scale
		ink.position = top_left / board.scale
	return board

func _engrave_arrow(center: Vector2, bearing: Vector2, color: Color) -> void:
	var heading := roundf(bearing.angle() / (PI * 0.25)) * PI * 0.25
	var shape := PackedVector2Array()
	for point: Vector2 in ARROW:
		shape.append((center + point.rotated(heading)) / scale)
	var arrow := Polygon2D.new()
	arrow.name = "Arrow"
	arrow.polygon = shape
	arrow.color = color
	add_child(arrow)
