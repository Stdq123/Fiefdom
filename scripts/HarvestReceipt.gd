extends PanelContainer

const HOLD_SECONDS := 1.15
const FADE_SECONDS := 0.35

@onready var seed_belt: Control = $"../SeedBelt"
@onready var caption: Label = $Caption

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
	if expiry and expiry.is_running():
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
	var heading := PackedStringArray(["收获 %d 格" % plots if plots > 1 else "收获"])
	if assisted > 0:
		heading.append("%s代收" % worker if plots == 1 else "门客代收 %d 格" % assisted)
	if rotated > 0:
		heading.append("轮作增收" if rotated == 1 else "轮作增收 %d 格" % rotated)
	if fertile > 0:
		heading.append("留肥" if fertile == 1 else "留肥 %d 格" % fertile)
	var totals := PackedStringArray()
	if tribute > 0:
		totals.append("国库 +%d" % tribute)
	if stock > 0:
		totals.append("%s +%d" % [harvest.crop if plots == 1 else "作物", stock])
	if copper > 0:
		totals.append("铜钱 +%d" % copper)
	if leaves > 0:
		totals.append("桑叶 +%d" % leaves)
	if levy > 0:
		totals.append("已扣税 %d" % levy)
	caption.text = " · ".join(heading) + "\n" + " · ".join(totals)
	caption.add_theme_color_override("font_color", Color("#efce80") if tribute > 0 else Color("#d2de9e"))
	modulate.a = 1.0
	reset_size()
	_position_receipt()
	show()
	expiry = create_tween()
	expiry.tween_interval(HOLD_SECONDS)
	expiry.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	expiry.tween_callback(hide)

func _position_receipt() -> void:
	var center := seed_belt.position.x + seed_belt.size.x * 0.5
	position = Vector2(center - size.x * 0.5, seed_belt.position.y - size.y - 7.0).round()

func _on_belt_visibility_changed() -> void:
	if not seed_belt.is_visible_in_tree():
		_clear_receipt()

func _clear_receipt() -> void:
	if expiry and expiry.is_running():
		expiry.kill()
	hide()
