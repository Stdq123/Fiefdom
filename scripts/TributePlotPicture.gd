extends Control
class_name TributePlotPicture

const SOIL := preload("res://assets/tileset.svg")
const TILE := Rect2(0, 0, 16, 16)

var soil_region := Rect2()
var crop_region := Rect2i()
var status := -1
var water := Global.CropWater.DRY
var rain := false
var rice := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func show_plot(plan: Dictionary) -> void:
	visible = not plan.is_empty()
	if not visible:
		return
	var cell: Vector2i = plan.cell
	var crop: Dictionary = Global.active_crops.get(cell, {})
	var tilled := not crop.is_empty() or Global.tilled_cells.has(cell)
	soil_region = Rect2(16, 16 if tilled else 0, 16, 16)
	status = plan.status
	rain = Global.has_rain()
	rice = false
	crop_region = Rect2i()
	if crop.is_empty():
		water = Global.CropWater.RAIN if rain else Global.CropWater.DRY
		if Global.irrigation.supplies(cell):
			water = Global.CropWater.CANAL
	else:
		var data: CropData = crop.data
		rice = data.is_water_crop
		water = Global.crop_water(cell, crop)
		var stage := 2 if status == Global.NightGrowth.READY else int(crop.age > 0)
		crop_region = ItemManager.crop_atlas.get_tile_texture_region(data.stages_atlas_coords[stage])
	queue_redraw()

func _draw() -> void:
	if not soil_region.has_area():
		return
	var scale_factor := maxf(1.0, floorf(minf(size.x, size.y) / 20.0))
	var zoom := Vector2.ONE * scale_factor
	var origin := (size * 0.5 - Vector2(8, 8.5) * scale_factor).floor()
	draw_set_transform(origin, 0.0, zoom)
	# The near edge sits below the same ochre public tile that players will find in the field.
	draw_rect(Rect2(0, 15, 16, 2), Color("#59432f"))
	draw_texture_rect_region(SOIL, TILE, soil_region)
	if rice and water == Global.CropWater.CANAL:
		FieldPlotArt.draw_paddy(self, TILE, rain)
	elif water in [Global.CropWater.RAIN, Global.CropWater.HAND, Global.CropWater.CANAL]:
		FieldPlotArt.draw_soil_moisture(self, TILE, rain and not rice)
	if not crop_region.has_area():
		return
	draw_texture_rect_region(ItemManager.crop_atlas.texture, TILE, crop_region)
	FieldPlotArt.draw_task_mark(self, Vector2(12, 12), status, FieldPlotArt.FARM_MARK_WIDTH)
