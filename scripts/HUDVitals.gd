extends PanelContainer

@onready var health_bar: ProgressBar = %HealthBar
@onready var stamina_bar: ProgressBar = %StaminaBar

func _ready() -> void:
	for label: Label in [$Stack/Health/Title, %HealthLabel, %HealthWarning, $Stack/Stamina/Title, %StaminaLabel, %StaminaWarning]:
		InterfaceFont.scale_reading_text(label)
	%HealthIcon.texture = HUDIcons.icon(HUDIcons.Symbol.HEALTH)
	%StaminaIcon.texture = HUDIcons.icon(HUDIcons.Symbol.STAMINA)
	GameEvents.health_changed.connect(_show_health)
	GameEvents.stamina_changed.connect(_show_stamina)
	_show_health(Global.health)
	_show_stamina(Global.current_stamina)

func _show_health(value: int) -> void:
	_show_reading(value, Global.balance.player_max_health, %HealthLabel, %HealthWarning, health_bar)

func _show_stamina(value: int) -> void:
	_show_reading(value, Global.max_stamina, %StaminaLabel, %StaminaWarning, stamina_bar)

func _show_reading(amount: int, capacity: int, reading: Label, warning: Label, bar: ProgressBar) -> void:
	reading.text = "%d / %d" % [amount, capacity]
	bar.max_value = capacity
	bar.value = amount
	warning.visible = capacity > 0 and amount * 3 < capacity
	warning.text = "已尽" if amount == 0 else "偏低"
	bar.accessibility_description = reading.text + ("，" + warning.text if warning.visible else "")
