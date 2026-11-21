extends PanelContainer

const HOLD_SECONDS := 1.15
const FADE_SECONDS := 0.35
const MAX_WIDTH := 560.0
const ICON_SIZE := 24.0
const ICON_GAP := 7

class ReceiptLine extends HBoxContainer:
	var art := TextureRect.new()
	var label := Label.new()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override(&"separation", ICON_GAP)
		art.custom_minimum_size = Vector2.ONE * ICON_SIZE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override(&"font_size", 16)
		add_child(label)
		InterfaceFont.scale_reading_text(label)
		hide()

@onready var seed_belt: Control = $"../SeedBelt"
@onready var caption: Label = $Lines/Caption

var treasury := ReceiptLine.new()
var warehouse := ReceiptLine.new()
var gains := ReceiptLine.new()
var treasury_crops: Dictionary[String, int] = {}
var warehouse_crops: Dictionary[String, int] = {}

var expiry: Tween
var plots := 0
var assisted := 0
var rotated := 0
var fertile := 0
var levy := 0
var tribute := 0
var stock := 0
var copper := 0
var leaves := 0

func _ready() -> void:
	InterfaceFont.scale_reading_text(caption)
	for line: ReceiptLine in [treasury, warehouse, gains]:
		$Lines.add_child(line)
	treasury.label.add_theme_color_override(&"font_color", Color("#efce80"))
	warehouse.label.add_theme_color_override(&"font_color", Color("#d2de9e"))
	gains.label.add_theme_color_override(&"font_color", Color("#e7dbbc"))
	Preferences.reading_size_changed.connect(func(): _fit_receipt.call_deferred())
	get_viewport().size_changed.connect(_fit_receipt)
	resized.connect(_position_receipt)
	seed_belt.item_rect_changed.connect(_position_receipt)
	seed_belt.visibility_changed.connect(_on_belt_visibility_changed)
	GameEvents.harvest_receipt.connect(_record_harvest)
	GameEvents.day_advanced.connect(_clear_receipt.unbind(1))

func _record_harvest(harvest: Dictionary, worker: String) -> void:
	if not seed_belt.is_visible_in_tree():
		return
	if not visible:
		plots = 0
		assisted = 0
		rotated = 0
		fertile = 0
		levy = 0
		tribute = 0
		stock = 0
		copper = 0
		leaves = 0
		treasury_crops.clear()
		warehouse_crops.clear()
	if expiry and expiry.is_valid():
		expiry.kill()
	plots += 1
	assisted += int(not worker.is_empty())
	rotated += int(harvest.rotated)
	fertile += int(harvest.fertile)
	levy += harvest.levy
	tribute += harvest.tribute
	stock += harvest.stock
	copper += harvest.copper
	leaves += harvest.leaves
	var id: String = harvest.get("crop_id", CropStock.MIXED)
	if id not in CropData.IDS:
		id = CropStock.MIXED
	if harvest.tribute > 0:
		treasury_crops[id] = treasury_crops.get(id, 0) + harvest.tribute
	if harvest.stock > 0:
		warehouse_crops[id] = warehouse_crops.get(id, 0) + harvest.stock
	var heading := PackedStringArray(["收获 %d 格" % plots if plots > 1 else "收获"])
	if assisted > 0:
		heading.append("%s代收" % worker if plots == 1 else "门客代收 %d 格" % assisted)
	if rotated > 0:
		heading.append("轮作增收" if rotated == 1 else "轮作增收 %d 格" % rotated)
	if fertile > 0:
		heading.append("留肥" if fertile == 1 else "留肥 %d 格" % fertile)
	caption.text = " · ".join(heading)
	_update_store(treasury, "国库", tribute, treasury_crops, HUDIcons.Symbol.TREASURY)
	_update_store(warehouse, "私仓", stock, warehouse_crops, HUDIcons.Symbol.GRAIN)
	var totals := PackedStringArray()
	if copper > 0:
		totals.append("铜钱 +%d" % copper)
	if leaves > 0:
		totals.append("桑叶 +%d" % leaves)
	if levy > 0:
		totals.append("已扣税 %d" % levy)
	gains.label.text = " · ".join(totals)
	gains.visible = not totals.is_empty()
	if gains.visible:
		gains.art.texture = HUDIcons.icon(HUDIcons.Symbol.COIN if copper > 0 or levy > 0 else HUDIcons.Symbol.MULBERRY)
	modulate.a = 1.0
	show()
	_fit_receipt()
	expiry = create_tween()
	expiry.tween_interval(HOLD_SECONDS)
	expiry.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	expiry.tween_callback(hide)

func _update_store(line: ReceiptLine, title: String, amount: int, crops: Dictionary, symbol: HUDIcons.Symbol) -> void:
	line.visible = amount > 0
	if not line.visible:
		return
	var goods := ItemManager.describe_crops(crops)
	line.art.texture = HUDIcons.icon(symbol)
	if crops.size() == 1:
		var id: String = crops.keys()[0]
		goods = ItemManager.crop_label(id)
		var data := ItemManager.get_crop(id)
		if data:
			line.art.texture = ItemManager.crop_picture(data).texture
	line.label.text = "%s +%d · %s" % [title, amount, goods]

func _fit_receipt() -> void:
	if not visible:
		return
	var width := minf(MAX_WIDTH, get_viewport_rect().size.x - 32.0) - get_theme_stylebox(&"panel").get_minimum_size().x
	_fit_line(caption, width)
	for line: ReceiptLine in [treasury, warehouse, gains]:
		if line.visible:
			_fit_line(line.label, width - ICON_SIZE - ICON_GAP)
	reset_size()
	_position_receipt()

func _fit_line(label: Label, width: float) -> void:
	var font := label.get_theme_font(&"font")
	var size_in_ink := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label.get_theme_font_size(&"font_size"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if size_in_ink.x > width else TextServer.AUTOWRAP_OFF
	label.custom_minimum_size.x = minf(ceilf(size_in_ink.x), width)

func _position_receipt() -> void:
	var center := seed_belt.position.x + seed_belt.size.x * 0.5
	position = Vector2(center - size.x * 0.5, seed_belt.position.y - size.y - 7.0).round()

func _on_belt_visibility_changed() -> void:
	if not seed_belt.is_visible_in_tree():
		_clear_receipt()

func _clear_receipt() -> void:
	if expiry and expiry.is_valid():
		expiry.kill()
	hide()
