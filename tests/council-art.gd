extends SceneTree

var failed := false

func _initialize() -> void:
	review.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)

func review() -> void:
	var state = root.get_node("Global")
	var panel = load("res://scenes/EventPanel.tscn").instantiate()
	root.add_child(panel)
	var reform: int = state.TaxReformChoice.REFORMED
	var tribute: int = state.TaxReformChoice.TRADITIONAL
	var research: int = state.TaxReformChoice.DELAYED
	var cells := {reform: 0, tribute: 1, research: 2}
	# Changing the number and order of policies must keep each illustration on its own choice.
	for order: Array in [[reform, tribute, research], [tribute, reform]]:
		var rows := []
		for choice: int in order:
			rows.append({"choice_type": choice, "text": str(choice), "levy": "", "harvest": "",
				"household": "", "heading": "", "detail": ""})
		panel.setup({"title": "", "speaker": "", "text": "", "ledger": "", "choices": rows})
		check(panel.option_buttons.size() == order.size(), "Available choices")
		for choice: int in order:
			var picture: AtlasTexture = panel.option_buttons[choice].icon
			check(picture != null and picture.atlas != null and picture.atlas.get_size() == Vector2(432, 68)
				and picture.region == Rect2(cells[choice] * 144, 0, 144, 68), "Council illustration %d" % choice)
	var original: Dictionary = state.ending_record
	for outcome: int in [state.Outcome.TRADITIONAL, state.Outcome.REFORMED]:
		var choice := tribute if outcome == state.Outcome.TRADITIONAL else reform
		state.ending_record = {"outcome": outcome, "accounts": [{"label": "国库", "value": 1}],
			"memories": [], "date": ""}
		var archive = load("res://scenes/EstateEnding.tscn").instantiate()
		root.add_child(archive)
		archive.open_archive()
		var book: AtlasTexture = archive.volume_icon.texture
		var chosen: AtlasTexture = panel.option_buttons[choice].icon
		check(book != null and book.atlas == chosen.atlas and book.region == chosen.region,
			"Archive remembers the book chosen at council")
		archive.free()
	state.ending_record = original
	var dialog = load("res://scripts/UIDialogManager.gd")
	var sealed := load(dialog.TRIBUTE_RECEIPT) as Texture2D
	var open_basket := load(dialog.PRIVATE_HARVEST) as Texture2D
	check(sealed != null and open_basket != null and sealed != open_basket
		and sealed.get_size() == Vector2(96, 96) and open_basket.get_size() == Vector2(96, 96),
		"Public and private harvest portraits")
	panel.free()
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
