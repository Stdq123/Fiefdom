extends Node2D

signal approached()
signal cloth_set_down()

const LAYOUT := preload("res://scripts/WestMarketLayout.gd")
const ART := preload("res://assets/characters/market-dyer.png")
const OUTBOUND := Vector2(0.19, 0.275)
const COUNTER_REACH := 0.290
const SET_DOWN_AT := 0.299
const CLEAR_COUNTER := 0.319
const RETURNING := Vector2(0.535, 0.62)
const CLOSE_YARD := Vector2(0.6875, 0.74)
const STOW_CLOTH := Vector2(0.675, CLOSE_YARD.x)
const COUNTER_FOOT := Vector2(203, 159)
const SPEAKER := "阿苓"

@onready var body: NeighborMotion = $Body
@onready var bundle: MarketCarry = $Bundle
@onready var hint: Label = $Hint

var portrait: Texture2D
var route := Curve2D.new()
var _road_stop := 0.0
var _display: Sprite2D
var _table_position := Vector2.ZERO

func _ready() -> void:
	body.set_motion_sheet(ART, CharacterArt.STREET_COLUMNS, SPEAKER)
	portrait = CharacterArt.dialogue_portrait(SPEAKER, null, false)
	for foot: Vector2 in [LAYOUT.DYE_RACK_STOP, Vector2(296, 15), LAYOUT.DYE_JUNCTION,
			LAYOUT.SILK_JUNCTION, LAYOUT.SILK_LANE[1], LAYOUT.SILK_LANE[2], LAYOUT.DYE_DELIVERY]:
		route.add_point(foot)
	_road_stop = route.get_baked_length()
	route.add_point(COUNTER_FOOT)
	_follow_clock(false)

func set_counter_cloth(placed: Sprite2D) -> void:
	_display = placed
	_table_position = placed.position
	_follow_clock(false)

func _process(_delta: float) -> void:
	var carried := bundle.visible
	_follow_clock(true)
	if carried and not bundle.visible and is_instance_valid(_display) and _display.visible:
		cloth_set_down.emit()

func _follow_clock(animate: bool) -> void:
	var clock := Global.day_progress
	var raining := Global.has_rain()
	var leaving := clock >= OUTBOUND.x and clock < COUNTER_REACH
	var headed_back := clock >= RETURNING.x and clock < RETURNING.y
	var from_rack := smoothstep(OUTBOUND.x, OUTBOUND.y, clock) * _road_stop
	var arriving := lerpf(from_rack, route.get_baked_length(), smoothstep(OUTBOUND.y, COUNTER_REACH, clock))
	var clearing := smoothstep(SET_DOWN_AT, CLEAR_COUNTER, clock)
	var distance := lerpf(arriving, _road_stop, clearing) * (1.0 - smoothstep(RETURNING.x, RETURNING.y, clock))
	var cover := 1.0 if raining else smoothstep(CLOSE_YARD.x, CLOSE_YARD.y, clock)
	var point := route.sample_baked(distance).lerp(LAYOUT.DYE_EAVE, cover)
	var movement := point - position
	position = point
	if animate and movement.length_squared() > 0.0016:
		body.walk(movement)
	elif body.walking or not animate:
		body.stand()
		if not raining and (leaving or headed_back or clearing > 0.0 and clearing < 1.0):
			var direction := route.sample_baked(distance + 0.5) - route.sample_baked(distance - 0.5)
			body.face(direction if leaving else -direction)
		else:
			body.face(Vector2.LEFT if distance >= _road_stop and cover < 1.0 else Vector2.DOWN)
	_present_cloth(clock, raining)

func _present_cloth(clock: float, raining: bool) -> void:
	if _display:
		var stow := smoothstep(STOW_CLOTH.x, STOW_CLOTH.y, clock)
		_display.visible = not raining and clock >= SET_DOWN_AT and clock < STOW_CLOTH.y
		_display.position = _table_position + Vector2(-8, -4) * stow
		_display.modulate.a = 1.0 - smoothstep(0.35, 1.0, stow)
	bundle.visible = not raining and clock >= OUTBOUND.x and clock < SET_DOWN_AT
	if not bundle.visible:
		return
	bundle.rotation = 0.0
	bundle.scale.y = 1.0
	bundle.hold(0.0)
	if _display and clock >= COUNTER_REACH:
		var lower := smoothstep(COUNTER_REACH, SET_DOWN_AT, clock)
		bundle.position = bundle.position.lerp(to_local(_display.global_position), lower)
		bundle.position.y -= 3.0 * sin(PI * lower)
		bundle.rotation = _display.rotation * lower
		bundle.scale.y = lerpf(1.0, _display.scale.y, lower)

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
	_present_cloth(Global.day_progress, Global.has_rain())

func can_interact_from(foot: Vector2) -> bool:
	return global_position.distance_squared_to(foot) <= 22.0 * 22.0

func set_interaction_focused(active: bool) -> void:
	hint.visible = active
	if active:
		hint.text = GamepadInput.interact_hint(SPEAKER)

func interact() -> void:
	approached.emit()
