extends SceneTree

var failed := false

func _initialize() -> void:
	_check.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func same_region(left: Texture2D, right: Texture2D) -> bool:
	return left is AtlasTexture and right is AtlasTexture and left.atlas == right.atlas and left.region == right.region

func _check() -> void:
	paused = true
	var state := root.get_node("Global")
	var art = load("res://scripts/CharacterArt.gd")
	var visitor = load("res://scripts/VisitorData.gd")
	var retainer = load("res://scripts/RetainerData.gd")
	var row = load("res://scenes/RetainerItem.tscn").instantiate()
	root.add_child(row)
	var faces := {}
	for speaker: String in visitor.NEIGHBORS:
		var guest = visitor.new()
		guest.name = speaker
		var worker = retainer.new(speaker)
		var first: AtlasTexture = art.dialogue_portrait(speaker, null, false)
		var later: AtlasTexture = art.dialogue_portrait(speaker, null, true)
		row.setup(worker)
		expect(first.atlas.get_size() == Vector2(14 * 48, 48), "The two portraits per neighbor fit the atlas.")
		expect(first.region.size == Vector2(48, 48) and later.region.size == first.region.size, "Native portrait size.")
		expect(not faces.has(first.region) and not faces.has(later.region) and first.region != later.region, "Two distinct portrait cells for " + speaker)
		faces[first.region] = true
		faces[later.region] = true
		expect(same_region(row.icon.texture, first) and same_region(guest.get_portrait(), first), "First meeting in roster and conversation: " + speaker)
		expect(worker.get_appearance_texture().get_size() == Vector2(32, 32), "The map keeps its world sprite.")
	state.field_rotation.signed_day = 1
	state.road_provisions_delivered = true
	state.channel_survey_day = 1
	state.silk_sample_day = 1
	state.ravine_journal.garden_day = 1
	state.east_watch_day = 1
	state.gathering_recitals[1] = 4
	for speaker: String in visitor.NEIGHBORS:
		var guest = visitor.new()
		guest.name = speaker
		row.setup(retainer.new(speaker))
		var later: Texture2D = art.dialogue_portrait(speaker, null, true)
		expect(same_region(row.icon.texture, later) and same_region(guest.get_portrait(), later), "Remembered keepsake in the roster and conversation: " + speaker)
	for school in visitor.School.size():
		var guest = visitor.new()
		guest.school = school
		var resident = retainer.new("旅人甲")
		resident.visitor_appearance = school
		row.setup(resident)
		expect(same_region(row.icon.texture, guest.get_portrait()), "A visitor keeps their likeness after recruitment.")
	for school in retainer.School.size():
		row.setup(retainer.new("门客甲", "农夫", school))
		expect(same_region(row.icon.texture, art.retainer_portrait(school, -1)), "Resident school bust.")
	var custom = retainer.new(visitor.FIELD_KEEPER)
	custom.portrait = art.visitor_portrait(visitor.School.MERCHANT)
	row.setup(custom)
	expect(row.icon.texture == custom.portrait and custom.get_portrait() == custom.portrait, "Explicit resident portrait stays authoritative.")
	row.free()
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
