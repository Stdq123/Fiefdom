extends SceneTree

const CROP_SHADER := preload("res://resources/field-crop-wind.gdshader")

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	paused = true
	var state := root.get_node("Global")
	state.current_day = 1
	if not _expect(change_scene_to_file(state.ESTATE_SCENE) == OK, "Mount the ordinary estate scene."):
		quit(1)
		return
	await scene_changed
	await process_frame
	var crops := current_scene.get_node("World/TileMapLayer/CropsLayer") as TileMapLayer
	var wind := current_scene.get_node("World/Landscape/FoliageWind")
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
