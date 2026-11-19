extends SceneTree

var failed := false

func _initialize() -> void:
	_check.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _check() -> void:
	var sheet := load("res://assets/world/ravine-trail-gates.png") as Texture2D
	_expect(sheet.get_size() == Vector2(160, 240), "The 2× atlas preserves logical gate dimensions.")
	var gate_script: GDScript = load("res://scripts/RavineShortcutGate.gd")
	var image := sheet.get_image()
	var regions: Array = gate_script.APRON_REGIONS.duplicate()
	regions.append(gate_script.POST_REGION)
	for orientation: Array in gate_script.LEAF_REGIONS:
		regions.append_array(orientation)
	var illustrations := {}
	for rect: Rect2 in regions:
		var dry := image.get_region(Rect2i(rect))
		var frost := image.get_region(Rect2i(rect.position + Vector2(0, gate_script.FROST_ROW), rect.size))
		for art: Image in [dry, frost]:
			var outline := art.get_used_rect()
			_expect(outline.has_area() and outline.position.x > 0 and outline.position.y > 0
				and outline.end.x < rect.size.x and outline.end.y < rect.size.y,
				"Gate art and frost have transparent margins in their cells.")
			illustrations[hash(art.get_data())] = true
	_expect(illustrations.size() == 14, "Each threshold, post, orientation and gate pose has distinct seasonal art.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
