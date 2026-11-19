extends SceneTree

var failed := false

func _initialize() -> void:
	review.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func coverage(image: Image) -> float:
	var mask := BitMap.new()
	mask.create_from_image_alpha(image, 0.10)
	return float(mask.get_true_bit_count()) / (image.get_width() * image.get_height())

func review() -> void:
	var bridge = load("res://scripts/WoodenBridge.gd")
	var timber: Texture2D = load(bridge.TIMBER_PATH)
	check(timber.get_size() == Vector2(238, 172), "The two weather rows use logical drawing coordinates")
	var sheet := timber.get_image()
	for region: Rect2i in [Rect2i(bridge.ROAD_DECK), Rect2i(bridge.RAVINE_DECK), Rect2i(bridge.LANDING_DECK),
			Rect2i(bridge.ROAD_RAIL), Rect2i(bridge.RAVINE_RAIL), Rect2i(bridge.LANDING_RAIL), Rect2i(bridge.LANDING_RETURN)]:
		var dry := sheet.get_region(region)
		var winter := sheet.get_region(Rect2i(region.position + Vector2i(0, int(bridge.WINTER_ROW)), region.size))
		check(dry.get_used_rect().end.y == region.size.y and winter.get_used_rect().end.y == region.size.y,
			"Summer and winter timber meet the same footing " + str(region))
		check(hash(dry.get_data()) != hash(winter.get_data()), "Distinct frosted wood " + str(region))
	var oak_fill := coverage(sheet.get_region(Rect2i(bridge.ROAD_RAIL)))
	var rope_fill := coverage(sheet.get_region(Rect2i(bridge.RAVINE_RAIL)))
	check(rope_fill > 0.20 and oak_fill > rope_fill + 0.08 and oak_fill < 0.73,
		"Both railings leave visible space for a person, the hemp railing more than the wood")
	var bank = load("res://scripts/RavineBanks.gd")
	var fall: Texture2D = load(bank.FALL_ART_PATH)
	check(fall.get_size() == Vector2(416, 72), "Waterfall strip and downstream foam fit the atlas")
	sheet = fall.get_image()
	var frames: Array[int] = []
	var crest_y := -1
	for index in bank.FALL_FRAMES:
		var cell := sheet.get_region(Rect2i(Vector2i(index * int(bank.FALL_SIZE.x), 0), Vector2i(bank.FALL_SIZE)))
		var paint := cell.get_used_rect()
		if index == 0:
			crest_y = paint.position.y
		check(paint.position.y == crest_y and paint.end.y < cell.get_height() and coverage(cell) > 0.30,
			"Water stays under the rock lip and clear of the foam strip")
		var key := hash(cell.get_data())
		check(key not in frames, "Distinct waterfall animation frame " + str(index))
		frames.append(key)
	var foam_fill := coverage(sheet.get_region(Rect2i(bank.DRIFT_FOAM)))
	check(foam_fill > 0.10 and foam_fill < 0.65, "The downstream foam separates into flecks")
	var land = load("res://scripts/Landscape.gd")
	var state = root.get_node("Global")
	for plant: int in [land.Prop.TALL_BAMBOO, land.Prop.BAMBOO]:
		var leaf: AtlasTexture = land.painted_riverside_texture(plant, state.Season.SUMMER)
		var frost: AtlasTexture = land.painted_riverside_texture(plant, state.Season.WINTER)
		check(leaf.atlas.resource_path == land.BAMBOO_ART_PATH and leaf.atlas.get_size() == Vector2(72, 96) and
			frost.region.position == leaf.region.position + Vector2(0, 48), "Bamboo uses the matching frost clump")
		check(leaf.get_image().get_used_rect().end.y == frost.get_image().get_used_rect().end.y and
			hash(leaf.get_image().get_data()) != hash(frost.get_image().get_data()), "Frosted leaves keep their root")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
