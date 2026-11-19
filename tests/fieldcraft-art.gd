extends SceneTree

var failed := false

func _initialize() -> void:
	review.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func review() -> void:
	# The survey, field marker and map use the same four cells of the double-density atlas.
	var worksite = load("res://scripts/FieldWorksite.gd")
	var water = load("res://scripts/IrrigationOverlay.gd")
	var marks: Array[int] = []
	for stage in range(worksite.SOD + 1):
		var mark: AtlasTexture = worksite.tool_texture(stage)
		check(mark.atlas.get_size() == Vector2(288, 48) and mark.region == Rect2(stage * 48, 0, 48, 48),
			"Tool atlas cell %d" % stage)
		var image := mark.get_image()
		check(image != null and image.get_used_rect().has_area(), "Visible survey tool %d" % stage)
		var fingerprint := hash(image.get_data())
		check(fingerprint not in marks, "Distinct survey tool %d" % stage)
		marks.append(fingerprint)
	var soil := load(worksite.SOIL) as Texture2D
	check(soil.get_size() == Vector2(104, 52), "Rough and tamped soil footprints")
	var timber := load(water.WATERWORKS) as Texture2D
	check(timber.get_size() == Vector2(128, 32), "Waterworks atlas")
	var sheet := timber.get_image()
	for region: Rect2 in [water.GATE_NS, water.GATE_EW, water.DECK_EW, water.DECK_NS]:
		var cell := Rect2i(floori(region.position.x / 32) * 32, 0, 32, 32)
		var art := sheet.get_region(cell).get_used_rect()
		art.position += cell.position
		check(art.has_area() and Rect2i(region).encloses(art), "Whole waterwork within crop %s" % region)
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
