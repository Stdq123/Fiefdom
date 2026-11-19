extends SceneTree

var failed := false
var state: Node
var world: Node
var hud: Control
var cursor: Node2D

func _initialize() -> void:
	_review.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _settle() -> void:
	for frame in 5:
		await process_frame

func _snapshot() -> Array:
	return [state.current_day, state.day_progress, state.current_stamina, state.health, state.money,
		state.king_storage, state.food_storage, hash(state.active_crops), hash(state.tilled_cells),
		hash(state.field_seed_plans), hash(state.player_inventory), world.player.position, state.saved_games().size()]

func _read(cell: Vector2i) -> String:
	var at: Vector2 = world.tile_map.get_global_transform_with_canvas() * world.tile_map.map_to_local(cell)
	var before := _snapshot()
	cursor.pointer_seen = true
	cursor.pointer = at
	cursor._process(0.0)
	await _settle()
	var bounds: Rect2 = cursor.caption.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, cursor.caption.size)
	_expect(cursor.caption.is_visible_in_tree() and hud.map_space_clear(bounds.grow(-0.01)),
		"The field note fits around the current HUD.")
	_expect(paused and before == _snapshot(), "Reading a plot preserves the staged field and player state.")
	return cursor.label.text

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the field HUD check with an isolated smoke profile.")
		quit(1)
		return
	paused = true
	state = root.get_node("Global")
	var events := root.get_node("GameEvents")
	var prefs := root.get_node("Preferences")
	var pad := root.get_node("GamepadInput")
	var items := root.get_node("ItemManager")
	state.current_day = 27
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	world = current_scene.get_node("World")
	var ui := current_scene.get_node("UI")
	hud = ui.hud
	cursor = world.tile_map.get_node("FieldCursor")
	var center: Vector2i = state.well_fields[0].center_pos
	var farm := center + Vector2i.LEFT
	var camera: Camera2D = world.player.camera
	camera.position_smoothing_enabled = false
	world.player.global_position = world.tile_map.to_global(world.tile_map.map_to_local(center)) - Vector2(36, -33)
	camera.force_update_scroll()
	await _settle()
	var font: int = cursor.label.get_theme_font_size(&"font_size")
	var note := await _read(center)
	_expect("公田 · 翻地" in note and "左键 · −2 体力" in note, "The first plot names its tool and cost.")
	var before_size: Vector2 = cursor.caption.size
	var money_font: int = hud.money_label.get_theme_font_size(&"font_size")
	_expect(prefs.set_reading_size(2) == OK, "Set the largest reading size in the isolated profile.")
	await _settle()
	await _read(center)
	_expect(cursor.label.get_theme_font_size(&"font_size") == font + 6 and cursor.caption.size.y > before_size.y
		and hud.money_label.get_theme_font_size(&"font_size") == money_font + 6,
		"The same cursor note remeasures after a live size change.")
	state.current_stamina = 1
	events.stamina_changed.emit(state.current_stamina)
	note = await _read(center)
	_expect("公田 · 翻地" in note and "需 2 · 还差 1" in note and "左键" not in note,
		"Insufficient stamina keeps the action and shows the exact shortage.")
	state.current_stamina = state.max_stamina
	events.stamina_changed.emit(state.current_stamina)
	state.active_crops[center] = {"id": "millet", "data": items.get_crop("millet"), "growth_nights": 2, "age": 2,
		"watered": true, "requires_channel": false}
	state.active_crops[farm] = {"id": "rice", "data": items.get_crop("rice"), "growth_nights": 4, "age": 2,
		"watered": false, "requires_channel": true}
	world.restore_crops_visuals()
	note = await _read(center)
	_expect("收获" in note and "国库 +1" in note and "−3 体力" in note, "Single public harvest previews the tribute.")
	note = await _read(farm)
	_expect("稻田断水" in note and "还需供水 2 夜" in note, "Dry rice reports the time with water still needed.")
	state.tax_reform_choice = state.TaxReformChoice.REFORMED
	state.tax_rate = 0.25
	pad.active = true
	note = await _read(center)
	_expect("私仓 +1" in note and "扣税" in note and "A · −3 体力" in note,
		"The same public cell uses the current tax rules and controller cue.")
	pad.active = false
	cursor._clear_pointer()

	state.money = 1234567
	state.food_storage = 876543
	state.king_storage = 234567
	state.reputation = -32145
	ui.update_ui()
	hud._toggle_ledger_details()
	await _settle()
	var calendar: Rect2 = hud.get_node("Calendar").get_global_rect()
	_expect(root.get_visible_rect().encloses(calendar) and not calendar.intersects(hud.get_node("Tools").get_global_rect()),
		"Long balances stay on the calendar without invading the toolbar.")
	for label: Label in [hud.money_label, hud.inventory_label, hud.king_label, hud.reputation_label]:
		_expect(calendar.encloses(label.get_global_rect()) and label.get_visible_line_count() == label.get_line_count(),
			"All digits fit on the shared right-hand plate.")
	var rice: Button = hud.seed_buttons["rice"]
	var card: Control = rice._make_custom_tooltip(rice.tooltip_text)
	hud.add_child(card)
	card.position = Vector2(464, 355)
	await _settle()
	var notes: Label = card.get_node("%Notes")
	_expect(root.get_visible_rect().encloses(card.get_global_rect()) and notes.get_theme_font_size(&"font_size") == 21
		and card.get_global_rect().encloses(notes.get_global_rect())
		and notes.get_visible_line_count() == notes.get_line_count(), "Seed notes wrap and use the current reading size.")
	_expect(paused and state.current_day == 27 and state.saved_games().is_empty(), "The review remains on the same saved example.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
