extends Control

var data: RetainerData

@onready var name_label: Label = $HBoxContainer/InfoBox/NameLabel
@onready var job_label: Label = $HBoxContainer/InfoBox/JobLabel
@onready var icon: TextureRect = $HBoxContainer/Icon
@onready var duty_picker: OptionButton = $HBoxContainer/Duty
@onready var field_picker: OptionButton = $HBoxContainer/InfoBox/Field

func _ready() -> void:
	for duty: RetainerData.Duty in [RetainerData.Duty.FIELD, RetainerData.Duty.REEL, RetainerData.Duty.TEACH,
			RetainerData.Duty.GUARD, RetainerData.Duty.HARVEST, RetainerData.Duty.STEWARD]:
		duty_picker.add_item(RetainerData.duty_label(duty), duty)
	var menu := duty_picker.get_popup()
	menu.add_theme_stylebox_override("panel", duty_picker.get_theme_stylebox("panel", "PanelContainer"))
	menu.add_theme_stylebox_override("hover", duty_picker.get_theme_stylebox("hover", "Button"))
	menu.add_theme_color_override("font_color", duty_picker.get_theme_color("font_color", "Button"))
	menu.about_to_popup.connect(_preview_duties)
	duty_picker.item_selected.connect(_select_duty)
	field_picker.item_selected.connect(_select_field)
	GameEvents.retainer_duty_changed.connect(_on_duty_changed)
	GameEvents.retainer_assigned.connect(_on_duty_changed.unbind(1))
	GameEvents.well_field_reclaimed.connect(_refresh_duty.unbind(2))
	GameEvents.field_rotation_changed.connect(_refresh_duty)
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
	duty_picker.text = data.duty_name()
	var tooltip := "每夜 %d 份口粮" % Global.retainer_night_ration(data)
	if data.duty == RetainerData.Duty.STEWARD:
		tooltip += " · 收割、浇水、按计划续播"
	elif not Global.field_steward_unlocked():
		tooltip += " · 记完轮作簿或第二块井田完工后可任管事"
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

func _preview_duties() -> void:
	var menu := duty_picker.get_popup()
	var meals_by_portion: Dictionary[int, Dictionary] = {}
	for index in duty_picker.item_count:
		var duty := duty_picker.get_item_id(index) as RetainerData.Duty
		var portions := Global.night_ration_for_duty(duty)
		var caption := "%s · %d 份" % [RetainerData.duty_label(duty), portions]
		var detail := ""
		if not duty_picker.is_item_disabled(index):
			if not meals_by_portion.has(portions):
				meals_by_portion[portions] = Global.night_rations_after_duty(data, duty)
			var meal := meals_by_portion[portions]
			if meal.served < meal.need:
				caption += " · 今夜可供 %d/%d 份" % [meal.served, meal.need]
				if not meal.departing.is_empty():
					caption += " · 离任 " + "、".join(meal.departing)
				var names := PackedStringArray(meal.missed.map(func(worker: RetainerData) -> String: return worker.name))
				detail = "缺餐 · %s\n再备 %d 份粮可供齐" % ["、".join(names), meal.missing - meal.converted - meal.bought]
			elif meal.copper > 0:
				caption += " · 今夜购粮 %d 铜钱" % meal.copper
		menu.set_item_text(index, caption)
		menu.set_item_tooltip(index, detail)

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
