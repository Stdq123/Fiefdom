extends PanelContainer

const DATE_HOLD := 3.0
const RESULT_HOLD := 5.0
const FADE_TIME := 0.34
const RESULT_INK := Color("#e7d8b8")
const ALERT_INK := Color("#ffc197")

@onready var date_label: Label = %Date
@onready var result_label: Label = %Result
@onready var sky: TextureRect = %Sky

var _fade: Tween

func _ready() -> void:
	InterfaceFont.scale_reading_text(date_label)
	InterfaceFont.scale_reading_text(result_label)
	minimum_size_changed.connect(_fit_height, CONNECT_DEFERRED)
	for visibility in [GameEvents.modal_visibility_changed, GameEvents.settings_visibility_changed, GameEvents.management_visibility_changed]:
		visibility.connect(_dismiss_for_panel)
	GameEvents.campaign_ended.connect(dismiss.unbind(1))
	GameEvents.map_departing.connect(dismiss)

func present(result: String, alert: bool) -> void:
	dismiss()
	date_label.text = "第 %d 天 · %s · %s" % [Global.current_day, Global.get_current_solar_term(), Global.day_watch_label()]
	sky.texture = HUDIcons.icon(HUDIcons.SKY[HUDIcons.sky_index()])
	result_label.text = result
	result_label.visible = not result.is_empty()
	result_label.add_theme_color_override(&"font_color", ALERT_INK if alert else RESULT_INK)
	var half_width := 268.0 if result_label.visible else 170.0
	offset_left = -half_width
	offset_right = half_width
	modulate.a = 1.0
	show()
	_fit_height.call_deferred()
	_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_interval(RESULT_HOLD if result_label.visible else DATE_HOLD)
	_fade.tween_property(self, "modulate:a", 0.0, FADE_TIME).set_trans(Tween.TRANS_SINE)
	_fade.tween_callback(hide)

func dismiss() -> void:
	if _fade:
		_fade.kill()
		_fade = null
	hide()

func _fit_height() -> void:
	size.y = get_combined_minimum_size().y

func _dismiss_for_panel(opened: bool) -> void:
	if opened:
		dismiss()
