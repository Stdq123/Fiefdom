extends SceneTree

var failed := false

func _initialize() -> void:
	review.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func review() -> void:
	var art = load("res://scripts/VillageInscription.gd")
	var layer := Node2D.new()
	root.add_child(layer)
	var boards: Texture2D = load(art.BOARDS)
	var trades: Texture2D = load(art.TRADE_SIGNS)
	check(art.LETTERING.multichannel_signed_distance_field and not art.LETTERING.allow_system_fallback,
		"The imported brush lettering scales on the board using only its bundled glyphs")
	check(boards.get_size() == Vector2(128, 96) and trades.get_size() == Vector2(64, 72), "Logical dimensions of site and trade signs")
	var inscriptions := ["东关", "柳湾·埠头", "西门·回封地", "井田 12", "南路亭",
		"井田 12 · 划畦\n余 1 夜", "粮摊", "鱼摊", "绸摊"]
	var cuts: Array[int] = []
	for style in inscriptions.size():
		var words: String = inscriptions[style]
		var signboard: Sprite2D = art.place(layer, Vector2(45, 19), style, words)
		var ink: Label = signboard.get_node("Caption")
		check(ink.text == words and ink.get_theme_font("font") == art.LETTERING, "Bundled Chinese lettering")
		for character in words:
			if character != "\n":
				check(art.LETTERING.has_char(character.unicode_at(0)), "Missing character " + character)
		var cut := signboard.texture.get_image()
		var fingerprint := hash(cut.get_data())
		check(cut.get_used_rect().has_area() and fingerprint not in cuts, "Complete, distinct sign face " + words)
		cuts.append(fingerprint)
		var points := (signboard.global_transform * signboard.get_rect()).grow(0.5)
		check(points.encloses(ink.get_global_rect()), "Writing stays on the board " + words)
		signboard.free()
	for heading in 8:
		var direction := Vector2.RIGHT.rotated(heading * PI / 4.0)
		var signboard: Sprite2D = art.place(layer, Vector2(6, 8), art.Form.BAMBOO, "竹涧小径", direction)
		var chip: Polygon2D = signboard.get_node("Arrow")
		var tail := chip.to_global((chip.polygon[0] + chip.polygon[-1]) * 0.5)
		var tip := chip.to_global(chip.polygon[3])
		check(tail.direction_to(tip).dot(direction) > 0.999, "True bearing on a stretched board")
		var writing: Label = signboard.get_node("Caption")
		check(not writing.get_global_rect().has_point(tip), "Arrow has room beside its place name")
		signboard.free()
	var survey: Sprite2D = art.place(layer, Vector2(-20, 10), art.Form.SURVEY, inscriptions[5], Vector2.ZERO, true)
	var status := layer.get_node("Status") as Label
	check(status.text == inscriptions[5] and (survey.global_transform * survey.get_rect()).encloses(status.get_global_rect()),
		"Worksite Status stays on the register in tile coordinates")
	var lamp := load("res://assets/world/bronze-path-lamps.png") as Texture2D
	check(lamp.get_size() == Vector2(32, 48), "Bronze path lamp atlas")
	var sheet := lamp.get_image()
	cuts.clear()
	for row in 2:
		for col in 2:
			var cell := sheet.get_region(Rect2i(col * 16, row * 24, 16, 24))
			var bounds := cell.get_used_rect()
			var print_id := hash(cell.get_data())
			check(bounds.has_area() and bounds.end.y == 23 and print_id not in cuts, "Lamp foot and window in every state")
			cuts.append(print_id)
	layer.free()
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
