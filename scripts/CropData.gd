extends Resource
class_name CropData

const IDS := ["millet", "sorghum", "rice", "wheat", "beans", "mulberry", "hemp"]

@export var crop_name: String
@export var days_to_grow: int
@export var sell_price: int
@export var atlas_source_id := 0
@export var stages_atlas_coords: Array[Vector2i]
@export var is_water_crop: bool = false
@export var is_perennial: bool = false
@export var restores_fertility: bool = false
@export var favored_season := -1

func sowing_nights(season: int, reduction: int) -> int:
	return maxi(1, days_to_grow - reduction) if season == favored_season else days_to_grow
