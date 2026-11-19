extends Button

signal retainer_dropped(data: RetainerData, grid_pos: Vector2i)

var grid_pos: Vector2i
var picture: TributePlotPicture

func _ready() -> void:
	custom_minimum_size = Vector2(145, 76)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for mode in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var style := get_theme_stylebox(mode).duplicate() as StyleBox
		style.content_margin_left = 61
		style.content_margin_right = 10
		add_theme_stylebox_override(mode, style)
	add_theme_font_size_override("font_size", 16)
	InterfaceFont.scale_reading_text(self)
	picture = TributePlotPicture.new()
	add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	picture.offset_left = 7
	picture.offset_right = 55
	picture.offset_top = -24
	picture.offset_bottom = 24
	refresh_plot()

func refresh_plot() -> void:
	var public_plot := Global.is_public_plot(grid_pos)
	var crop: Dictionary = Global.active_crops.get(grid_pos, {})
	var tilled := Global.tilled_cells.has(grid_pos)
	picture.show_field_cell(grid_pos)
	var state := "空畦" if tilled else "未翻地"
	if not crop.is_empty():
		var stage := "（苗）"
		match picture.status:
			Global.NightGrowth.READY: stage = "（熟）"
			Global.NightGrowth.DRY: stage = "（待浇）"
			Global.NightGrowth.BLOCKED: stage = "（断水）"
		state = crop.data.crop_name + stage
	text = "%s · %s" % ["公田" if public_plot else "私田", state]
	add_theme_color_override("font_color", Color("#efce80") if public_plot else Color("#d5e3ce"))
	tooltip_text = "可安排续播" if tilled else "先到田里翻地"
	if not tilled and Global.can_plan_field_seed(grid_pos):
		tooltip_text = "选好续播后点田格，门客会先翻地"
	if not crop.is_empty() and crop.data.is_perennial:
		tooltip_text = "桑收后留根，可反复采叶"
	var plan: String = Global.field_seed_plans.get(grid_pos, "")
	var next_seed := ItemManager.get_crop(Global.next_seed_for_plan(grid_pos, plan))
	if next_seed:
		var waiting := next_seed.is_water_crop and not Global.irrigation.supplies(grid_pos)
		var deferred := Global.deferred_field_sowing.has(grid_pos)
		if FieldSeedPlan.is_order(plan):
			var note := " · 暂缓" if deferred else (" · 待渠水" if waiting else "")
			text += "\n备货 %s%s" % [next_seed.crop_name, note]
			tooltip_text = "管事为时令单种一茬。可在交货簿撤回未播的田格。"
			return
		if FieldSeedPlan.is_rotation(plan):
			var main_crop := ItemManager.get_crop(FieldSeedPlan.crop_id(plan))
			var next_label := "暂缓" if deferred else ("待渠水" if waiting else "下茬%s" % next_seed.crop_name)
			text += "\n菽 ↔ %s · %s" % [main_crop.crop_name, next_label]
		elif plan == FieldSeedPlan.SEASONAL:
			text += "\n时令续播 · %s" % ("暂缓" if deferred else next_seed.crop_name)
		else:
			var status := " · 暂缓" if deferred else (" · 待渠水" if waiting else "")
			text += "\n续播 %s%s" % [next_seed.crop_name, status]
		tooltip_text = "接通水渠后才会补播稻种" if waiting else "照料门客或管事会在空畦上补播"
		if plan == FieldSeedPlan.SEASONAL:
			tooltip_text = "按补播当天的时令和供水选种。当前作物照常生长。"
		if not tilled:
			tooltip_text = "门客先翻地，再按安排播种。" + ("稻种需要通水的水渠。" if waiting else "")
		if deferred:
			tooltip_text = "定下田制后按原安排续播，也可在这里提前恢复。"

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is RetainerData

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	retainer_dropped.emit(data, grid_pos)
	self_modulate = Color(1.4, 1.4, 1.4)
	create_tween().tween_property(self, "self_modulate", Color.WHITE, 0.25)
