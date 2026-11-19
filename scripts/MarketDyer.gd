extends Node2D

signal approached()

const LAYOUT := preload("res://scripts/WestMarketLayout.gd")
const ART := preload("res://assets/characters/market-dyer.png")
const OUTBOUND := Vector2(0.19, 0.275)
const RETURNING := Vector2(0.535, 0.62)
const CLOSE_YARD := Vector2(0.6875, 0.74)
const SPEAKER := "阿苓"

@onready var body: NeighborMotion = $Body
@onready var bundle: Sprite2D = $Bundle
@onready var hint: Label = $Hint

var portrait: Texture2D
var route := Curve2D.new()

func _ready() -> void:
	body.set_motion_sheet(ART, CharacterArt.STREET_COLUMNS, SPEAKER)
	portrait = CharacterArt.dialogue_portrait(SPEAKER, null, false)
	for foot: Vector2 in [LAYOUT.DYE_RACK_STOP, Vector2(296, 15), LAYOUT.DYE_JUNCTION,
			LAYOUT.SILK_JUNCTION, LAYOUT.SILK_LANE[1], LAYOUT.SILK_LANE[2], LAYOUT.DYE_DELIVERY]:
		route.add_point(foot)
	_follow_clock(false)

func _process(_delta: float) -> void:
	_follow_clock(true)

func _follow_clock(animate: bool) -> void:
	var clock := Global.day_progress
	var raining := Global.has_rain()
	var leaving := clock >= OUTBOUND.x and clock < OUTBOUND.y
	var headed_back := clock >= RETURNING.x and clock < RETURNING.y
	var trip := smoothstep(OUTBOUND.x, OUTBOUND.y, clock) - smoothstep(RETURNING.x, RETURNING.y, clock)
	var distance := trip * route.get_baked_length()
	var cover := 1.0 if raining else smoothstep(CLOSE_YARD.x, CLOSE_YARD.y, clock)
	var point := route.sample_baked(distance).lerp(LAYOUT.DYE_EAVE, cover)
	var movement := point - position
	position = point
	bundle.visible = leaving and not raining
	if animate and movement.length_squared() > 0.0016:
		body.walk(movement)
	elif body.walking or not animate:
		body.stand()
		if not raining and (leaving or headed_back):
			var direction := route.sample_baked(distance + 0.5) - route.sample_baked(distance - 0.5)
			body.face(direction if leaving else -direction)
		else:
			body.face(Vector2.LEFT if trip >= 1.0 else Vector2.DOWN)
	body.carry_at(bundle, 0.0)

func remark() -> String:
	if VisitorData.silk_sample_on_display(Global.current_day):
		return "蔡娘今早把你那匹样绸摊在柜上了。去看时把布边翻到亮处，连经线的影子都看得清。"
	if Global.has_rain():
		return "雨一落，我就把布收进檐下了。沿石街向西，转进南边的支巷，蔡娘的摊就在巷尾。"
	if bundle.visible:
		return "我正要把这匹新布送给蔡娘。顺着石街走，看见南边的岔路就拐弯。"
	if position.is_equal_approx(LAYOUT.DYE_DELIVERY):
		return "布送到了，蔡娘正等着看颜色晾干后深了几分。她就在前头的棚子里。"
	if Global.day_progress >= CLOSE_YARD.y:
		return "收完布，我还得刷一遍染缸。蔡娘的摊在石街南侧，顺着巷口的灯过去就到了。"
	return "布从染缸里提起来，还要借半日风。要看已经染好的，沿石街去南边的绸摊。"

func face_customer(foot: Vector2) -> void:
	body.stand()
	body.face(foot - global_position)
	body.carry_at(bundle, 0.0)

func can_interact_from(foot: Vector2) -> bool:
	return global_position.distance_squared_to(foot) <= 22.0 * 22.0

func set_interaction_focused(active: bool) -> void:
	hint.visible = active
	if active:
		hint.text = GamepadInput.interact_hint(SPEAKER)

func interact() -> void:
	approached.emit()
