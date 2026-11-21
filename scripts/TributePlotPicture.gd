extends Control
class_name TributePlotPicture

const TILE := Rect2(0, 0, 16, 16)

var soil_region := Rect2()
var crop_region := Rect2i()
var crop_ink := Color.WHITE
var status := -1
var water := Global.CropWater.DRY
var rain := false
var rice := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func show_plot(plan: Dictionary) -> void:
	visible = not plan.is_empty()
	if visible:
		_show_cell(plan.cell, plan.status)

func show_field_cell(cell: Vector2i) -> void:
	_show_cell(cell, Global.crop_night_status(cell))

func _show_cell(cell: Vector2i, task: int) -> void:
	var crop: Dictionary = Global.active_crops.get(cell, {})
	var tilled := not crop.is_empty() or Global.tilled_cells.has(cell)
	var atlas := FieldPlotArt.soil_atlas(cell, Global.is_public_plot(cell), tilled)
	soil_region = Rect2(Vector2(atlas) * TILE.size, TILE.size)
	status = task
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
		var coords := data.stages_atlas_coords[stage]
		var alternative := FieldPlotArt.crop_alternative(stage, status)
		crop_region = ItemManager.crop_atlas.get_tile_texture_region(coords)
		crop_ink = ItemManager.crop_atlas.get_tile_data(coords, alternative).modulate
	queue_redraw()

func _draw() -> void:
	if not soil_region.has_area():
		return
	var scale_factor := maxf(1.0, floorf(minf(size.x, size.y) / 20.0))
	var zoom := Vector2.ONE * scale_factor
	var origin := (size * 0.5 - Vector2(8, 8.5) * scale_factor).floor()
	draw_set_transform(origin, 0.0, zoom)
	draw_rect(Rect2(0, 15, 16, 2), Color("#59432f"))
	draw_texture_rect_region(FieldPlotArt.SOIL, TILE, soil_region)
	if rice and water == Global.CropWater.CANAL:
		FieldPlotArt.draw_paddy(self, TILE, rain)
	elif water in [Global.CropWater.RAIN, Global.CropWater.HAND, Global.CropWater.CANAL]:
		FieldPlotArt.draw_soil_moisture(self, TILE, rain and not rice)
	elif FieldPlotArt.needs_water(status):
		FieldPlotArt.draw_dry_soil(self, TILE)
	if not crop_region.has_area():
		return
	draw_texture_rect_region(ItemManager.crop_atlas.texture, TILE, crop_region, crop_ink)
	FieldPlotArt.draw_task_mark(self, Vector2(12, 12), status, FieldPlotArt.FARM_MARK_WIDTH)
