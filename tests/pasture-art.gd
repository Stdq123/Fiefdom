extends SceneTree

var failed := false

func _initialize() -> void:
	_check.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _check() -> void:
	var texture := load("res://assets/world/pasture-details.png") as Texture2D
	_expect(texture.get_size() == Vector2(84, 220), "Pasture art uses the 2× importer and logical cell sizes.")
	var sheet := texture.get_image()
	var variants := {}
	for row in 6:
		for column in 3:
			var cell := sheet.get_region(Rect2i(column * 28, row * 28, 28, 28))
			var outline := cell.get_used_rect()
			var tall := row == 1 or row == 2
			_expect(outline.position.x > 0 and outline.end.x < 28 and outline.end.y == 27
				and (outline.position.y < 8 if tall else outline.position.y >= 14),
				"Each grass variant fits its cell and has a consistent foot and seasonal height.")
			variants[hash(cell.get_data())] = true
	_expect(variants.size() == 18, "All grass clumps have distinct silhouettes or palettes.")

	var scene := load("res://scenes/SheepfoldPen.tscn") as PackedScene
	var pen := scene.instantiate()
	var shed := pen.get_node("Paddock/Shed") as Sprite2D
	var frost := shed.get_node("RoofFrost") as Sprite2D
	var overlay := frost.texture.get_image()
	var roof := shed.texture.get_image()
	_expect(frost.offset == shed.offset and overlay.get_size() == roof.get_size(),
		"The frost overlay and shed share an origin and size.")
	var area := overlay.get_used_rect()
	_expect(area.has_area() and area.end.y < 27, "Frost sits on the straw roof above the wall.")
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			_expect(overlay.get_pixel(x, y).a == 0.0 or roof.get_pixel(x, y).a > 0.0,
				"Frost pixels stay inside the straw silhouette.")
	pen.free()
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
