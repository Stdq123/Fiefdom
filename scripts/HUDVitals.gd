extends PanelContainer

@onready var health_bar: VitalMeter = %HealthBar
@onready var stamina_bar: VitalMeter = %StaminaBar
@onready var base_width := custom_minimum_size.x

func _ready() -> void:
	for label: Label in [$Stack/Health/Title, %HealthLabel, %HealthWarning, $Stack/Stamina/Title, %StaminaLabel, %StaminaWarning]:
		InterfaceFont.scale_reading_text(label)
	%HealthIcon.texture = HUDIcons.icon(HUDIcons.Symbol.HEALTH)
	%StaminaIcon.texture = HUDIcons.icon(HUDIcons.Symbol.STAMINA)
	GameEvents.health_changed.connect(_show_health)
	GameEvents.stamina_changed.connect(_show_stamina)
	GameEvents.modal_visibility_changed.connect(_on_overlay_open)
	GameEvents.settings_visibility_changed.connect(_on_overlay_open)
	GameEvents.management_visibility_changed.connect(_on_overlay_open)
	visibility_changed.connect(func(): _on_overlay_open(not is_visible_in_tree()))
	_show_health(Global.health)
	_show_stamina(Global.current_stamina)
	Preferences.reading_size_changed.connect(_fit_panel)
	_fit_panel()

func set_stamina_cost(cost: int) -> void:
	if stamina_bar.planned_cost != cost:
		stamina_bar.set_cost_preview(cost)
		_describe_meter(%StaminaLabel, %StaminaWarning, stamina_bar)

func _on_overlay_open(open: bool) -> void:
	if open:
		set_stamina_cost(0)

func _show_health(value: int) -> void:
	_show_reading(value, Global.balance.player_max_health, %HealthLabel, %HealthWarning, health_bar)

func _show_stamina(value: int) -> void:
	stamina_bar.set_cost_preview(0)
	_show_reading(value, Global.max_stamina, %StaminaLabel, %StaminaWarning, stamina_bar)

func _show_reading(amount: int, capacity: int, reading: Label, warning: Label, bar: VitalMeter) -> void:
	var capacity_changed := bar.max_value != capacity
	reading.text = "%d / %d" % [amount, capacity]
	bar.set_amount(amount, capacity)
	_describe_meter(reading, warning, bar)
	if capacity_changed:
		_fit_panel()

func _fit_panel() -> void:
	var health := _row_width(%HealthIcon, $Stack/Health/Title, %HealthLabel, %HealthWarning, int(health_bar.max_value))
	var stamina := _row_width(%StaminaIcon, $Stack/Stamina/Title, %StaminaLabel, %StaminaWarning, int(stamina_bar.max_value))
	var margins := get_theme_stylebox(&"panel").get_minimum_size().x
	custom_minimum_size.x = maxf(base_width, ceilf(maxf(health, stamina) + margins))
	offset_right = offset_left + custom_minimum_size.x

func _row_width(icon: Control, title: Label, reading: Label, warning: Label, capacity: int) -> float:
	var row := title.get_parent() as HBoxContainer
	var text := "%d / %d" % [capacity, capacity]
	return (icon.get_combined_minimum_size().x + title.get_combined_minimum_size().x
		+ row.get_theme_constant(&"separation") * 3 + _text_width(reading, text) + _text_width(warning, "偏低"))

func _text_width(label: Label, text: String) -> float:
	var font := label.get_theme_font(&"font")
	return ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label.get_theme_font_size(&"font_size")).x)

func _describe_meter(reading: Label, warning: Label, bar: VitalMeter) -> void:
	var amount := int(bar.value)
	var cost := bar.planned_cost
	var short := cost > amount
	warning.visible = short or (bar.max_value > 0 and amount * 3 < bar.max_value)
	warning.text = "不足" if short and amount > 0 else ("已尽" if amount == 0 else "偏低")
	var description := reading.text + ("，" + warning.text if warning.visible else "")
	if cost > 0:
		description += "，预估耗力 %d" % cost
		description += "，还差 %d" % (cost - amount) if short else "，余 %d" % (amount - cost)
	bar.accessibility_description = description
