extends "res://scripts/WaterSurface.gd"

const BED := "res://assets/world/south-pond.png"
const PLANTS := "res://assets/world/pond-margin-plants.png"
const FOLIAGE_WIND := preload("res://scripts/FoliageWind.gd")
const BANK := Rect2(158, 624, 200, 152)
const LOTUS := Rect2(0, 0, 32, 25)
const CATTAIL := Rect2(32, 0, 24, 32)
const PLANT_ROW := 32.0
const LOTUS_FEET := [Vector2(304, 684), Vector2(209, 739)]
const CATTAIL_FEET := [Vector2(190, 742), Vector2(327, 735)]

var bed: Texture2D = load(BED)
var plant_sheet: Texture2D = load(PLANTS)
var lotus_plants: Array[Sprite2D] = []
var cattails: Array[Sprite2D] = []
var season := -1
var wet := false
var bed_cell := Rect2(Vector2.ZERO, BANK.size)

func _init() -> void:
	super(EstateLayout.corners(BANK), 0.0)

func set_weather(water: Color, rainy: bool) -> void:
	super.set_weather(water, rainy)
	wet = rainy
	var today := Global.season_index()
	if today != season:
		season = today
		bed_cell.position.x = BANK.size.x if season == Global.Season.WINTER else 0.0
		mask_to_water(bed, Rect2(bed_cell.position + Vector2(0, BANK.size.y), BANK.size), BANK)
	_dress_plants()

func draw_bed(ground: CanvasItem) -> void:
	var tint := Color.WHITE
	if season == Global.Season.SUMMER:
		tint = Color("#f1fff2")
	elif season == Global.Season.AUTUMN:
		tint = Color("#fff2db")
	if wet:
		tint *= Color("#d4e3df")
	ground.draw_texture_rect_region(bed, BANK, bed_cell, tint)

func place_bank_plants(layer: Node2D, wind: FOLIAGE_WIND) -> void:
	for foot: Vector2 in LOTUS_FEET:
		lotus_plants.append(_plant(layer, foot, LOTUS))
	lotus_plants[1].scale = Vector2(0.74, 0.74)
	lotus_plants[1].flip_h = true
	for foot: Vector2 in CATTAIL_FEET:
		var clump := _plant(layer, foot, CATTAIL)
		wind.attach(clump, FOLIAGE_WIND.STEM)
		cattails.append(clump)
	cattails[0].scale = Vector2(0.84, 0.84)
	cattails[1].flip_h = true
	_dress_plants()

func _plant(layer: Node2D, foot: Vector2, region: Rect2) -> Sprite2D:
	var plant := Sprite2D.new()
	plant.texture = plant_sheet
	plant.name = "PondLotus" if region == LOTUS else "PondCattail"
	plant.centered = false
	plant.region_enabled = true
	plant.region_filter_clip_enabled = true
	plant.region_rect = region
	plant.offset = Vector2(-region.size.x * 0.5, 1.0 - region.size.y)
	plant.position = foot
	layer.add_child(plant, true)
	return plant

func _dress_plants() -> void:
	for plant in lotus_plants:
		plant.visible = season != Global.Season.WINTER
		_dress(plant, LOTUS)
	for plant in cattails:
		_dress(plant, CATTAIL)

func _dress(plant: Sprite2D, region: Rect2) -> void:
	region.position.y += PLANT_ROW * season
	plant.region_rect = region
	plant.self_modulate = Color("#c6d4cd") if wet else Color.WHITE
