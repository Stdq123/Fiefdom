extends Node

const FARMING_CROPS_ATLAS := 1
const TILESET := preload("res://resources/game_tileset.tres")
const SILK_SAMPLE := preload("res://assets/world/west-court-sample.svg")

var crops: Dictionary = {}

func _ready() -> void:
	_init_crops()

func _init_crops() -> void:
	var b = Global.balance

	# Millet (黍)
	var millet = CropData.new()
	millet.crop_name = "黍"
	millet.days_to_grow = ceil(b.millet_growth_days / b.crop_growth_speed)
	millet.sell_price = ceil(b.millet_price * b.crop_price_multiplier)
	var millet_stages: Array[Vector2i] = [Vector2i(0,2), Vector2i(1,2), Vector2i(2,2)]
	millet.stages_atlas_coords = millet_stages
	crops["millet"] = millet

	# Sorghum (稷)
	var sorghum = CropData.new()
	sorghum.crop_name = "稷"
	sorghum.days_to_grow = ceil(b.sorghum_growth_days / b.crop_growth_speed)
	sorghum.sell_price = ceil(b.sorghum_price * b.crop_price_multiplier)
	sorghum.favored_season = Global.Season.AUTUMN
	var sorghum_stages: Array[Vector2i] = [Vector2i(0,3), Vector2i(1,3), Vector2i(2,3)]
	sorghum.stages_atlas_coords = sorghum_stages
	crops["sorghum"] = sorghum

	# Rice (稻) - Water Crop
	var rice = CropData.new()
	rice.crop_name = "稻"
	rice.days_to_grow = ceil(b.rice_growth_days / b.crop_growth_speed)
	rice.sell_price = ceil(b.rice_price * b.crop_price_multiplier)
	rice.atlas_source_id = FARMING_CROPS_ATLAS
	var rice_stages: Array[Vector2i] = [Vector2i(11, 4), Vector2i(9, 4), Vector2i(7, 4)]
	rice.stages_atlas_coords = rice_stages
	rice.is_water_crop = true
	rice.favored_season = Global.Season.SUMMER
	crops["rice"] = rice

	# Wheat (麦)
	var wheat = CropData.new()
	wheat.crop_name = "麦"
	wheat.days_to_grow = ceil(b.wheat_growth_days / b.crop_growth_speed)
	wheat.sell_price = ceil(b.wheat_price * b.crop_price_multiplier)
	wheat.favored_season = Global.Season.WINTER
	wheat.atlas_source_id = FARMING_CROPS_ATLAS
	var wheat_stages: Array[Vector2i] = [Vector2i(5, 5), Vector2i(3, 5), Vector2i(1, 5)]
	wheat.stages_atlas_coords = wheat_stages
	crops["wheat"] = wheat

	# Beans (菽) - Restores Fertility
	var beans = CropData.new()
	beans.crop_name = "菽"
	beans.days_to_grow = ceil(b.beans_growth_days / b.crop_growth_speed)
	beans.sell_price = ceil(b.beans_price * b.crop_price_multiplier)
	var beans_stages: Array[Vector2i] = [Vector2i(0,6), Vector2i(1,6), Vector2i(2,6)]
	beans.stages_atlas_coords = beans_stages
	beans.restores_fertility = true
	crops["beans"] = beans

	# Mulberry (桑) - Perennial
	var mulberry = CropData.new()
	mulberry.crop_name = "桑"
	mulberry.days_to_grow = ceil(b.mulberry_growth_days / b.crop_growth_speed)
	mulberry.sell_price = ceil(b.mulberry_price * b.crop_price_multiplier)
	var mulberry_stages: Array[Vector2i] = [Vector2i(0,7), Vector2i(1,7), Vector2i(2,7)]
	mulberry.stages_atlas_coords = mulberry_stages
	mulberry.is_perennial = true
	mulberry.favored_season = Global.Season.SPRING
	crops["mulberry"] = mulberry

	# Hemp (麻)
	var hemp = CropData.new()
	hemp.crop_name = "麻"
	hemp.days_to_grow = ceil(b.hemp_growth_days / b.crop_growth_speed)
	hemp.sell_price = ceil(b.hemp_price * b.crop_price_multiplier)
	var hemp_stages: Array[Vector2i] = [Vector2i(0,8), Vector2i(1,8), Vector2i(2,8)]
	hemp.stages_atlas_coords = hemp_stages
	crops["hemp"] = hemp

func get_crop(id: String) -> CropData:
	return crops.get(id)

func crop_picture(crop: CropData) -> Dictionary:
	var atlas := TILESET.get_source(crop.atlas_source_id) as TileSetAtlasSource
	var mature: Vector2i = crop.stages_atlas_coords.back()
	var texture := AtlasTexture.new()
	texture.atlas = atlas.texture
	texture.region = Rect2(atlas.get_tile_texture_region(mature))
	texture.filter_clip = true
	return {"texture": texture, "tint": atlas.get_tile_data(mature, 0).modulate}

func crop_label(id: String) -> String:
	if id == CropStock.MIXED:
		return "混存作物"
	return get_crop(id).crop_name

func describe_crops(lots: Dictionary) -> String:
	var amounts := PackedStringArray()
	for id in CropStock.IDS:
		var quantity: int = lots.get(id, 0)
		if quantity > 0:
			amounts.append("%s %d" % [crop_label(id), quantity])
	return "、".join(amounts)

func season_item_label(id: String) -> String:
	if id == SeasonOrders.SILK_ITEM:
		return "丝绸"
	if CreekFish.SPECIES.has(id):
		return CreekFish.SPECIES[id].name
	return crop_label(id)

func season_item_picture(id: String) -> Dictionary:
	if id == SeasonOrders.SILK_ITEM:
		var cloth := AtlasTexture.new()
		cloth.atlas = SILK_SAMPLE
		cloth.region = Rect2(7, 5, 14, 13)
		cloth.filter_clip = true
		return {"texture": cloth, "tint": Color.WHITE}
	if CreekFish.SPECIES.has(id):
		return {"texture": CreekFish.portrait(id), "tint": Color.WHITE}
	return crop_picture(get_crop(id))

func describe_season_order(order: Dictionary) -> String:
	var goods := SeasonOrders.cargo(order)
	var amounts := PackedStringArray()
	for id: String in goods:
		amounts.append("%s %d" % [season_item_label(id), goods[id]])
	return "、".join(amounts)

func describe_season_order_progress(schedule: Dictionary) -> String:
	var amounts := PackedStringArray()
	var goods := SeasonOrders.cargo(schedule.order)
	for id: String in goods:
		var required: int = goods[id]
		amounts.append("%s %d/%d" % [season_item_label(id), mini(Global.season_order_stock_for(schedule, id), required), required])
	return "、".join(amounts)
