extends Control

var data: RetainerData

@onready var name_label: Label = $HBoxContainer/InfoBox/NameLabel
@onready var job_label: Label = $HBoxContainer/InfoBox/JobLabel
@onready var icon: TextureRect = $HBoxContainer/Icon
@onready var duty_picker: OptionButton = $HBoxContainer/Duty

func _ready() -> void:
	duty_picker.add_item("田间照料", RetainerData.Duty.FIELD)
	duty_picker.add_item("蚕桑缫丝", RetainerData.Duty.REEL)
	duty_picker.add_item("礼仪教习", RetainerData.Duty.TEACH)
	duty_picker.add_item("封地守卫", RetainerData.Duty.GUARD)
	duty_picker.add_item("田间收割", RetainerData.Duty.HARVEST)
	duty_picker.item_selected.connect(_select_duty)
	GameEvents.retainer_duty_changed.connect(_on_duty_changed)
	GameEvents.silk_changed.connect(_refresh_duty)

func setup(p_data: RetainerData) -> void:
	data = p_data
	name_label.text = data.name
	job_label.text = "%s · %s · 效率 %.2f" % [data.profession, data.get_school_name(), data.get_work_efficiency()]
	tooltip_text = "%s\n忠诚度 %.0f" % [data.get_school_ability(), data.loyalty]
	icon.texture = data.portrait if data.portrait else data.get_appearance_texture()
	_refresh_duty()

func _refresh_duty() -> void:
	if data == null:
		return
	for index in range(duty_picker.item_count):
		var duty := duty_picker.get_item_id(index) as RetainerData.Duty
		duty_picker.set_item_disabled(index, not Global.can_assign_duty(data, duty))
	duty_picker.select(duty_picker.get_item_index(data.duty))
	duty_picker.tooltip_text = "照料负责浇水和补播，每夜耗 1 粮，其他专职额外耗 %d 粮。" % [
		Global.balance.specialist_food_per_night]

func _select_duty(index: int) -> void:
	Global.assign_duty(data, duty_picker.get_item_id(index) as RetainerData.Duty)
	_refresh_duty()

func _on_duty_changed(retainer: RetainerData) -> void:
	if data == retainer:
		_refresh_duty()

func _get_drag_data(at_position: Vector2) -> Variant:
	print("Dragging retainer: ", data.name)
	
	# Create preview
	var preview = Label.new()
	preview.text = data.name
	set_drag_preview(preview)
	
	return data
