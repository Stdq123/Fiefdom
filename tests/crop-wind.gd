extends SceneTree

const CROP_SHADER := preload("res://resources/field-crop-wind.gdshader")

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	paused = true
	var state := root.get_node("Global")
	state.current_day = 1
	var cell: Vector2i = state.FIRST_FIELD_CENTER
	var seed: CropData = root.get_node("ItemManager").get_crop("sorghum")
	for plot: Vector2i in [cell, cell + Vector2i.RIGHT]:
		state.active_crops[plot] = {"data": seed, "id": "sorghum", "age": 3,
			"growth_nights": 3, "watered": true, "requires_channel": false}
	if not _expect(change_scene_to_file(state.ESTATE_SCENE) == OK, "Mount the ordinary estate scene."):
		quit(1)
		return
	await scene_changed
	await process_frame
	var world := current_scene.get_node("World")
	var crops: TileMapLayer = world.crops_layer
	var soil: TileMapLayer = world.tile_map
	_expect(crops.get_parent() == world and crops.y_sort_enabled and crops.z_index == world.player.z_index,
		"The original crop tiles sort with the actor layer.")
	_expect(crops.to_global(crops.map_to_local(cell)) == soil.to_global(soil.map_to_local(cell)),
		"Crop depth keeps the visible plants on the underlying ground grid.")
	var overlay: Node = world.irrigation_overlay
	var marks: Node2D = overlay.crop_marks
	var row: Node2D = overlay.crop_mark_rows.get(cell.y)
	_expect(marks.get_parent() == crops and marks.y_sort_enabled and row != null
		and row.marks.size() == 2 and row.position.y > crops.map_to_local(cell).y + crops.y_sort_origin,
		"A row of crop status glyphs sits directly after its crops in the actor sort.")
	state.active_crops.clear()
	overlay._refresh_crop_marks()
	_expect(overlay.crop_mark_rows.is_empty(), "Empty rows release their status glyphs.")
	var wind := world.get_node("Landscape/FoliageWind")
	var surface := crops.material as ShaderMaterial
	if not _expect(surface != null and surface.shader == CROP_SHADER, "The estate's existing crop layer uses the wind material."):
		quit(1)
		return
	var clear_strength: float = surface.get_shader_parameter(&"wind_strength")
	var term_days: int = state.balance.days_per_solar_term
	state.current_day = state.SOLAR_TERMS.find(state.balance.rain_solar_term) * term_days + 1
	wind._refresh_weather()
	var rain_strength: float = surface.get_shader_parameter(&"wind_strength")
	_expect(rain_strength > clear_strength and rain_strength == wind.material.get_shader_parameter(&"wind_strength"),
		"Rain makes crops and trees share the stronger gust.")
	state.current_day = state.Season.WINTER * SeasonOrders.TERMS_PER_SEASON * term_days + 1
	wind._refresh_weather()
	var winter_strength: float = surface.get_shader_parameter(&"wind_strength")
	_expect(winter_strength > 0.0 and winter_strength < clear_strength
		and winter_strength == wind.material.get_shader_parameter(&"wind_strength"), "Winter softens the shared breeze.")
	wind._process(0.5)
	_expect(wind.phase > 0.0 and surface.get_shader_parameter(&"wind_phase") == wind.material.get_shader_parameter(&"wind_phase"),
		"One clock keeps the plants in the same wind.")
	state.estate_room = state.EstateRoom.HALL
	wind._refresh_room()
	_expect(not wind.is_processing(), "Indoor views pause the outdoor wind.")
	state.estate_room = state.EstateRoom.OUTDOORS
	wind._refresh_room()
	_expect(wind.is_processing(), "The wind is ready when the estate returns outdoors.")
	_expect(state.saved_games().is_empty(), "The scene review does not write a campaign save.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _expect(ok: bool, detail: String) -> bool:
	if not ok:
		failed = true
		push_error(detail)
	return ok
