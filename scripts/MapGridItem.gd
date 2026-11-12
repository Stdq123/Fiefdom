extends Button

signal retainer_dropped(grid_pos: Vector2i, data: RetainerData)

var grid_pos: Vector2i

func _ready() -> void:
	custom_minimum_size = Vector2(92, 62)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_constant_override("icon_max_width", 19)
	add_theme_constant_override("h_separation", 6)
	add_theme_font_size_override("font_size", 16)
	refresh_plot()

func refresh_plot() -> void:
	var public_plot := Global.is_public_plot(grid_pos)
	var crop: Dictionary = Global.active_crops.get(grid_pos, {})
	var tilled := Global.tilled_cells.has(grid_pos)
	var state := "空畦" if tilled else "未翻地"
	if not crop.is_empty():
		state = crop.data.crop_name + ("（熟）" if Global.field_crop_is_ripe(grid_pos) else "（苗）")
	text = "%s · %s" % ["公田" if public_plot else "私田", state]
	add_theme_color_override("font_color", Color("#efce80") if public_plot else Color("#d5e3ce"))
	tooltip_text = "可安排续播" if tilled else "先到田里翻地"
	if not crop.is_empty() and crop.data.is_perennial:
		tooltip_text = "桑收后留根，可反复采叶"
	var planned_id: String = Global.field_seed_plans.get(grid_pos, "")
	var seed := ItemManager.get_crop(planned_id)
	var display_crop: CropData = seed if crop.is_empty() else crop.data
	icon = ItemManager.crop_picture(display_crop).texture if display_crop else null
	if seed:
		var waiting := " · 待渠水" if seed.is_water_crop and not Global.irrigation.supplies(grid_pos) else ""
		text += "\n续播 %s%s" % [seed.crop_name, waiting]
		tooltip_text = "田间照料门客会在空畦上补播" if waiting.is_empty() else "接通水渠后才会补播稻种"

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is RetainerData

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	print("Dropped ", data.name, " on grid ", grid_pos)
	retainer_dropped.emit(grid_pos, data)
	self_modulate = Color(1.4, 1.4, 1.4)
	create_tween().tween_property(self, "self_modulate", Color.WHITE, 0.25)
