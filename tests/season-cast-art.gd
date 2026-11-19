extends SceneTree

var failed := false
var art

func _initialize() -> void:
	check_cast.call_deferred()

func expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func check_image(path: String, size: Vector2i, cell: Vector2i) -> void:
	var filename := "res://assets/characters/" + path + ".png"
	var tex: Texture2D = load(filename)
	expect(tex.get_size() == Vector2(size), "World size of " + path)
	expect("pixels" in tex and tex.get("pixels").get_size() == Vector2(size * 2), "Source density of " + path)
	var image := Image.new()
	expect(image.load_png_from_buffer(FileAccess.get_file_as_bytes(filename)) == OK, "Read " + path)
	for y in range(0, size.y, cell.y):
		var distinct := {}
		for x in range(0, size.x, cell.x):
			var frame := image.get_region(Rect2i(Vector2i(x, y) * 2, cell * 2))
			expect(frame.get_used_rect().has_area(), "Visible frame in " + path)
			distinct[hash(frame.get_data())] = true
		# The rear-facing blink matches the rear standing silhouette.
		var columns := floori(float(size.x) / cell.x)
		var rear_blink := columns == 6 and floori(float(y) / cell.y) % 3 == 1
		expect(distinct.size() == columns - int(rear_blink), "Distinct poses in %s row %d" % [path, y])

func check_cast() -> void:
	paused = true
	art = load("res://scripts/CharacterArt.gd")
	check_image("autumn-guests", Vector2i(192, 288), Vector2i(32, 32))
	check_image("envoy-motion", Vector2i(192, 96), Vector2i(32, 32))
	check_image("freight-driver", Vector2i(192, 192), Vector2i(32, 32))
	check_image("festival-supper", Vector2i(64, 96), Vector2i(32, 32))
	check_image("enemy-motion", Vector2i(288, 64), Vector2i(32, 32))
	var hand: Texture2D = load("res://assets/characters/envoy-handoff.png")
	expect(hand.get_size() == Vector2(13, 5) and hand.get("pixels").get_size() == Vector2(26, 10),
		"Detached cuff and palm for both books")
	var gait = load("res://scripts/NeighborMotion.gd").new()
	root.add_child(gait)
	for i in 3:
		gait.set_festival_guest(i)
		expect(gait.texture.region == Rect2(0, i * 96, 192, 96) and gait.get_rect().size == Vector2(32, 32),
			"One sheet per festival guest")
		for column: int in [1, 4, 2, 5]:
			gait.walk(Vector2.RIGHT * (0.5 if column == 1 else gait.step_length))
			expect(gait.frame_coords == Vector2i(column, gait.Facing.PROFILE), "Four different footfalls")
	gait.free()
	var faces := {}
	for speaker in art.TOWN_REGIONS:
		var portrait: AtlasTexture = art.dialogue_portrait(speaker, null, false)
		expect(portrait.region == art.TOWN_REGIONS[speaker] and not faces.has(portrait.region), "Named portrait " + speaker)
		faces[portrait.region] = true
	var visitor = load("res://scripts/VisitorData.gd")
	var retainer = load("res://scripts/RetainerData.gd")
	var row = load("res://scenes/RetainerItem.tscn").instantiate()
	root.add_child(row)
	for school in visitor.School.size():
		var guest = visitor.new()
		guest.school = school
		var hired = retainer.new()
		hired.visitor_appearance = school
		expect(guest.get_portrait().region == hired.get_portrait().region, "Visitor keeps their face after recruitment")
		faces[guest.get_portrait().region] = true
	for school in retainer.School.size():
		var hired = retainer.new("田客", "农夫", school)
		row.setup(hired)
		expect(row.icon.texture.region == hired.get_portrait().region, "Roster uses the matching school portrait")
		faces[hired.get_portrait().region] = true
	row.free()
	expect(faces.size() == 20, "Nine named people, five visiting schools and six local schools")
	var wagon: Texture2D = load("res://assets/world/freight-wagon.png")
	var stove: Texture2D = load("res://assets/world/winter-hearth.png")
	var packet: Texture2D = load("res://assets/world/seed-packet.png")
	expect(wagon.get_size() == Vector2(480, 352) and stove.get_size() == Vector2(288, 280)
		and packet.get_size() == Vector2(18, 12), "Cart, stove and hand parcel keep their world scale")
	var spokes := Image.new()
	spokes.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/world/freight-wagon.png"))
	for view in 3:
		var wheel := {}
		for phase in 4:
			var cell := Rect2i((phase + 1) * 192, view * 128, 192, 128)
			wheel[hash(spokes.get_region(cell).get_data())] = true
		expect(wheel.size() == 4, "Four phases for the visible wheel in view %d" % view)
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
