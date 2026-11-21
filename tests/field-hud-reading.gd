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

func _read_feedback(center: Vector2i, events: Node) -> void:
	var before := _snapshot()
	world.spawn_floating_text(center, "已浇水 · 过夜后生长", Color.WHITE)
	world.spawn_floating_text(center + Vector2i.LEFT, "体力不足 · 翻地需 2", Color.WHITE)
	world.spawn_floating_text(center, "已浇水 · 过夜后生长", Color.WHITE)
	var overlay := world.get_node_or_null("FloatingText")
	_expect(overlay != null, "The staged field feedback creates its display node.")
	if not overlay:
		return
	overlay._process(0.0)
	_expect(overlay.messages.size() == 2, "Repeating the same note on a plot refreshes its existing label.")
	var occupied: Array[Rect2] = [cursor.caption.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, cursor.caption.size)]
	for entry in overlay.messages:
		var label: Label = entry.label
		var bounds := label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, label.size)
		_expect(label.is_visible_in_tree() and label.get_theme_font_size(&"font_size") == 21 and label.size.y < 64.0,
			"Single-line feedback fits at the largest reading size.")
		_expect(hud.map_space_clear(bounds) and HintPlacement.is_clear(bounds, occupied),
			"Feedback clears the HUD, the cursor caption and neighboring notes.")
		occupied.append(bounds)
	events.modal_visibility_changed.emit(true)
	overlay._process(2.0)
	_expect(not overlay.is_visible_in_tree() and overlay.messages.size() == 2,
		"An open panel hides the notes and preserves their remaining lifetime.")
	events.modal_visibility_changed.emit(false)
	overlay._process(0.0)
	_expect(overlay.is_visible_in_tree(), "Returning to the map shows the pending notes.")
	overlay._process(2.0)
	_expect(overlay.messages.is_empty() and before == _snapshot(), "Feedback expires without changing the staged state.")

func _read_receipt(events: Node, prefs: Node, items: Node) -> void:
	var receipt: Control = hud.get_node("HarvestReceipt")
	var before := _snapshot()
	var public_crop := {"crop_id": "millet", "tribute": 1, "stock": 0, "copper": 0, "leaves": 0,
		"levy": 0, "rotated": false, "fertile": false}
	events.harvest_receipt.emit(public_crop, "")
	receipt.expiry.pause()
	await _settle()
	_expect(receipt.treasury.label.text == "国库 +1 · 黍" and not receipt.warehouse.visible
		and receipt.treasury.art.texture == items.crop_picture(items.get_crop("millet")).texture,
		"The public receipt uses its own crop art and names the treasury.")
	var private_crop := public_crop.duplicate()
	private_crop.merge({"crop_id": "beans", "tribute": 0, "stock": 2, "copper": 10, "fertile": true}, true)
	events.harvest_receipt.emit(private_crop, "渠伯")
	private_crop.merge({"crop_id": "sorghum", "stock": 3, "copper": 12345678901234567, "levy": 4321987654321,
		"leaves": 81234, "rotated": true, "fertile": false}, true)
	events.harvest_receipt.emit(private_crop, "")
	receipt.expiry.pause()
	await _settle()
	var larger_height := receipt.size.y
	var bounds := receipt.get_global_rect()
	_expect(receipt.visible and receipt.caption.text.begins_with("收获 3 格")
		and receipt.warehouse.label.text == "私仓 +5 · 稷 3、菽 2"
		and receipt.gains.label.text.contains("已扣税 4321987654321"),
		"A mixed receipt keeps the names, quantities, destination, and actual tax.")
	for line: Control in [receipt.treasury, receipt.warehouse, receipt.gains]:
		var label: Label = line.label
		_expect(label.get_theme_font_size(&"font_size") == 22 and bounds.encloses(label.get_global_rect())
			and label.get_visible_line_count() == label.get_line_count(), "All rows fit at the largest reading size.")
	_expect(root.get_visible_rect().encloses(bounds) and bounds.end.y < receipt.seed_belt.get_global_rect().position.y,
		"The mixed receipt stays above the seeds and inside the viewport.")
	_expect(prefs.set_reading_size(0) == OK, "Return to the standard reading size while the receipt is still open.")
	await _settle()
	_expect(receipt.gains.label.get_theme_font_size(&"font_size") == 16 and receipt.size.y < larger_height,
		"A visible receipt refits from large to standard text.")
	receipt._clear_receipt()
	events.harvest_receipt.emit(private_crop, "渠伯")
	_expect(receipt.plots == 1 and receipt.treasury_crops.is_empty() and not receipt.treasury.visible
		and receipt.warehouse.label.text == "私仓 +3 · 稷", "A new receipt clears the old totals and item groups.")
	receipt._clear_receipt()
	_expect(prefs.set_reading_size(2) == OK and _snapshot() == before, "Reading receipts changes neither the staged economy nor the fields.")

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
	var gauge: ProgressBar = hud.get_node("Vitals").stamina_bar
	_expect(gauge.planned_cost == 2 and gauge.value == state.current_stamina, "The gauge previews the same single-plot cost.")
	var action: int = world.field_action(center)
	var plots: Array[Vector2i] = world.field_batch_targets(center, action)
	var total: int = world.field_cost(action) * plots.size()
	cursor._show_field_preview(center, action, plots)
	_expect(total > 2 and gauge.planned_cost == total and gauge.value == state.current_stamina,
		"The batch marks its full cost without deducting it.")
	events.modal_visibility_changed.emit(true)
	_expect(gauge.planned_cost == 0, "An open panel clears the projected deduction immediately.")
	events.modal_visibility_changed.emit(false)
	var before_size: Vector2 = cursor.caption.size
	var money_font: int = hud.money_label.get_theme_font_size(&"font_size")
	_expect(prefs.set_reading_size(2) == OK, "Set the largest reading size in the isolated profile.")
	await _settle()
	await _read(center)
	_expect(cursor.label.get_theme_font_size(&"font_size") == font + 6 and cursor.caption.size.y > before_size.y
		and hud.money_label.get_theme_font_size(&"font_size") == money_font + 6,
		"The same cursor note remeasures after a live size change.")
	_read_feedback(center, events)
	state.current_stamina = 1
	events.stamina_changed.emit(state.current_stamina)
	note = await _read(center)
	_expect("公田 · 翻地" in note and "需 2 · 还差 1" in note and "左键" not in note,
		"Insufficient stamina keeps the action and shows the exact shortage.")
	_expect(gauge.planned_cost == 2 and gauge.value == 1 and "还差 1" in gauge.accessibility_description
		and hud.get_node("Vitals").get_node("%StaminaWarning").text == "不足",
		"The patterned preview distinguishes a shortage from the current reading.")
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
	_expect(gauge.planned_cost == 0, "A read-only field has no projected expenditure.")
	state.tax_reform_choice = state.TaxReformChoice.REFORMED
	state.tax_rate = 0.25
	pad.active = true
	note = await _read(center)
	_expect("私仓 +1" in note and "扣税" in note and "A · −3 体力" in note,
		"The same public cell uses the current tax rules and controller cue.")
	pad.active = false
	cursor._clear_pointer()
	_expect(gauge.planned_cost == 0, "Moving the pointer away clears the forecast.")
	await _read_receipt(events, prefs, items)

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
	var tooltip := PopupPanel.new()
	tooltip.theme_type_variation = &"TooltipPanel"
	tooltip.wrap_controls = true
	var plain_tip := Label.new()
	plain_tip.theme_type_variation = &"TooltipLabel"
	plain_tip.text = "先查看今晚的田务和用粮安排。".repeat(5)
	tooltip.add_child(plain_tip)
	hud.sleep_button.add_child(tooltip)
	tooltip.popup()
	await _settle()
	_expect(plain_tip.get_theme_font_size(&"font_size") == 22 and plain_tip.get_line_count() > 1
		and plain_tip.size.x <= 360.0 and tooltip.get_theme_stylebox(&"panel") is StyleBoxTexture,
		"A native text tooltip inherits the game style and wraps at the larger reading size.")
	var large_height := tooltip.size.y
	_expect(prefs.set_reading_size(0) == OK, "The isolated profile accepts the standard reading size.")
	await _settle()
	_expect(plain_tip.get_theme_font_size(&"font_size") == 16 and tooltip.size.y < large_height
		and plain_tip.get_line_count() == plain_tip.get_visible_line_count(),
		"A visible tooltip shrinks to fit all its text when the reading size is reduced.")
	tooltip.free()
	_expect(paused and state.current_day == 27 and state.saved_games().is_empty(), "The review remains on the same saved example.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
