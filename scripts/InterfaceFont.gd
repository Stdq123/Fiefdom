extends Node

const BODY := preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
const HUD_THEME := preload("res://resources/estate_hud_theme.tres")
const TOOLTIP_SIZE := 16
const TOOLTIP_WIDTH := 360.0

func _enter_tree() -> void:
	# Install the imported font at runtime, after it is available on a cold build.
	ThemeDB.get_default_theme().default_font = BODY
	ThemeDB.fallback_font = BODY
	get_tree().node_added.connect(_style_text_tooltip)

func scale_reading_text(target: Node, item: StringName = &"font_size") -> void:
	var standard: int = target.get_theme_font_size(item)
	var apply := func(): target.add_theme_font_size_override(item, Preferences.reading_font_size(standard))
	Preferences.reading_size_changed.connect(apply)
	target.tree_exiting.connect(func(): Preferences.reading_size_changed.disconnect(apply), CONNECT_ONE_SHOT)
	apply.call()

func _style_text_tooltip(node: Node) -> void:
	var label := node as Label
	if label == null or label.theme_type_variation != &"TooltipLabel":
		return
	var popup := label.get_parent() as PopupPanel
	if popup == null or popup.theme_type_variation != &"TooltipPanel":
		return
	popup.add_theme_stylebox_override(&"panel", HUD_THEME.get_stylebox(&"panel", &"HudRail"))
	popup.size_changed.connect(_keep_tooltip_in_window.bind(popup))
	label.add_theme_color_override(&"font_color", Color("#f4e4c3"))
	var fit := _fit_text_tooltip.bind(label, popup)
	Preferences.reading_size_changed.connect(fit)
	label.tree_exiting.connect(func(): Preferences.reading_size_changed.disconnect(fit), CONNECT_ONE_SHOT)
	fit.call()

func _fit_text_tooltip(label: Label, popup: PopupPanel) -> void:
	var font_size := Preferences.reading_font_size(TOOLTIP_SIZE)
	label.add_theme_font_size_override(&"font_size", font_size)
	var natural := BODY.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var width := minf(ceilf(natural), TOOLTIP_WIDTH)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if natural > TOOLTIP_WIDTH else TextServer.AUTOWRAP_OFF
	label.custom_minimum_size.x = width
	label.size.x = width
	if popup.visible:
		popup.reset_size.call_deferred()

func _keep_tooltip_in_window(popup: PopupPanel) -> void:
	if not popup.visible or not popup.is_embedded():
		return
	var bounds := (popup.get_parent() as Control).get_window().get_visible_rect()
	var last := (bounds.end - Vector2(popup.size)).max(bounds.position)
	var clamped := Vector2i(Vector2(popup.position).clamp(bounds.position, last))
	if popup.position != clamped:
		popup.position = clamped
