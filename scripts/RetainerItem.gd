extends Control

var data: RetainerData

@onready var name_label: Label = $HBoxContainer/InfoBox/NameLabel
@onready var job_label: Label = $HBoxContainer/InfoBox/JobLabel
@onready var icon: TextureRect = $HBoxContainer/Icon
@onready var duty_picker: OptionButton = $HBoxContainer/Duty
@onready var field_picker: OptionButton = $HBoxContainer/InfoBox/Field

func _ready() -> void:
	duty_picker.add_item("田间照料", RetainerData.Duty.FIELD)
	duty_picker.add_item("蚕桑缫丝", RetainerData.Duty.REEL)
	duty_picker.add_item("礼仪教习", RetainerData.Duty.TEACH)
	duty_picker.add_item("封地守卫", RetainerData.Duty.GUARD)
	duty_picker.add_item("田间收割", RetainerData.Duty.HARVEST)
	duty_picker.add_item("井田管事", RetainerData.Duty.STEWARD)
	duty_picker.item_selected.connect(_select_duty)
	field_picker.item_selected.connect(_select_field)
	GameEvents.retainer_duty_changed.connect(_on_duty_changed)
	GameEvents.retainer_assigned.connect(_on_duty_changed.unbind(1))
	GameEvents.well_field_reclaimed.connect(_refresh_duty.unbind(2))
	GameEvents.silk_changed.connect(_refresh_duty)

func setup(p_data: RetainerData) -> void:
	data = p_data
	name_label.text = data.name
	job_label.text = "%s · %s · 效率 %.2f" % [data.profession, data.get_school_name(), data.get_work_efficiency()]
	tooltip_text = "%s\n%s\n%s\n忠诚度 %.0f" % [data.name, job_label.text, data.get_school_ability(), data.loyalty]
	icon.texture = data.portrait if data.portrait else data.get_appearance_texture()
	_refresh_duty()

func _refresh_duty() -> void:
	if data == null:
		return
	for index in range(duty_picker.item_count):
		var duty := duty_picker.get_item_id(index) as RetainerData.Duty
		duty_picker.set_item_disabled(index, not Global.can_assign_duty(data, duty))
	duty_picker.select(duty_picker.get_item_index(data.duty))
	var tooltip := "每夜 %d 份口粮" % Global.retainer_night_ration(data)
	if data.duty == RetainerData.Duty.STEWARD:
		tooltip += " · 收割、浇水、按计划续播"
	elif not Global.field_steward_unlocked():
		tooltip += " · 第二块井田完工后可任管事"
	duty_picker.tooltip_text = tooltip
	field_picker.visible = data.duty == RetainerData.Duty.STEWARD
	custom_minimum_size.y = $HBoxContainer.get_combined_minimum_size().y + 16.0
	if field_picker.visible:
		field_picker.clear()
		for field in Global.well_fields:
			if field.is_unlocked:
				field_picker.add_item("井田 %d" % (field.field_id + 1), field.field_id)
		var field_id: int = Global.stewarded_field(data).field_id
		field_picker.select(field_picker.get_item_index(field_id))

func _select_duty(index: int) -> void:
	Global.assign_duty(data, duty_picker.get_item_id(index) as RetainerData.Duty)
	_refresh_duty()

func _on_duty_changed(retainer: RetainerData) -> void:
	if data == retainer:
		_refresh_duty()

func _select_field(index: int) -> void:
	var field := Global.get_well_field(field_picker.get_item_id(index))
	Global.assign_retainer_plot(data, field.center_pos)

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = data.name
	set_drag_preview(preview)
	return data
