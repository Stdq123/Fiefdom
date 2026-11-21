extends RefCounted

var tree: SceneTree
var state: Node
var ui: Node
var evidence := ""
var failed := false

func run(scenario: SceneTree, directory := "") -> bool:
	tree = scenario
	evidence = directory
	tree.paused = true
	await _settle()
	state = tree.root.get_node("Global")
	var prefs := tree.root.get_node("Preferences")
	var items := tree.root.get_node("ItemManager")
	var public_plot := Global.FIRST_FIELD_CENTER
	var night: int = state.balance.raid_first_day - 1
	state.current_day = night + 1
	state.day_progress = 0.0
	state.estate_room = Global.EstateRoom.OUTDOORS
	state.outcome = Global.Outcome.RUNNING
	state.tax_reform_choice = Global.TaxReformChoice.NONE
	state.raid_day = state.current_day
	state.raid_kind = state.raid_kind_on(state.current_day)
	state.food_storage = 0
	state.money = 0
	state.retainers.assign([RetainerData.new("渠伯"), RetainerData.new("季青"), RetainerData.new("石墨")])
	state.well_fields.assign([
		{"field_id": 0, "center_pos": public_plot, "is_unlocked": true, "reclamation_progress": 4},
		{"field_id": 1, "center_pos": public_plot + Vector2i(5, 0), "is_unlocked": true, "reclamation_progress": 4},
	])
	state.active_crops.clear()
	state.active_crops[public_plot] = {"data": items.get_crop("millet"), "id": "millet", "age": 2, "growth_nights": 2,
		"watered": false, "requires_channel": false}
	var work := {"day": night, "tilled": 12, "watered": 16, "harvested": 13, "sown": 11,
		"tribute": 1, "stock": 18, "copper": 102, "leaves": 9, "minutes": 96}
	state.last_dawn = {"day": night, "research_gap": 48, "tribute_penalty": 8,
		"completed_fields": [2], "field_wait": work, "away_field": work}
	state.last_field_night = {"day": night, "public_ripe": 1, "private_ripe": 2, "ready": 0, "growing": 5, "dry": 3, "blocked": 2}
	state.night_rations.enabled = false
	state.night_rations.last = {"day": night, "need": 6, "served": 2, "used": {"millet": 1}, "bought": 1, "copper": 12,
		"missed": PackedStringArray(["石墨", "季青"]), "departed": PackedStringArray(["田叔"])}
	_expect(prefs.set_reading_size(2) == OK, "Use the largest reading setting for the morning book.")
	if not _expect(tree.change_scene_to_file(state.ESTATE_SCENE) == OK, "Open the estate with the staged morning receipts."):
		return false
	await tree.scene_changed
	ui = tree.current_scene.get_node("UI")
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	await _settle()
	var snapshot := _snapshot()
	var book := await _open_book()
	if not _expect(book != null and book.show_previous and book.close_button.has_focus(), "Open yesterday's report from its HUD button."):
		return false
	var actions: Array[Button] = book._record_buttons()
	_expect(actions == [book.mark_raider, book.record_tribute, book.record_rations, book.find_harvest, book.plan_field],
		"From the top, find the live threat, public plot, ration forecast, ripe fields and the finished estate field.")
	var bounds: Rect2 = book.record_summary.get_global_rect()
	_expect(tree.root.get_visible_rect().encloses(book.window.get_global_rect())
		and bounds.end.y <= book.scroll.get_global_rect().position.y, "All action buttons fit above the scrolling receipt.")
	_expect(absf(book.mark_raider.get_global_rect().position.y - book.plan_field.get_global_rect().position.y) < 1.0,
		"The five actions share a row at the largest reading size.")
	for action in actions:
		_expect(bounds.encloses(action.get_global_rect()) and action.icon != null, "The entire action and icon stay in the fixed block.")
	_key(KEY_DOWN)
	await _settle()
	_expect(book.mark_raider.has_focus(), "Down from the header reaches the first available action.")
	_key(KEY_RIGHT)
	await _settle()
	_expect(book.record_tribute.has_focus(), "Right reaches the adjacent public plot action.")
	await _capture("01-morning-actions")
	var bar: VScrollBar = book.scroll.get_v_scroll_bar()
	bar.value = bar.max_value
	await _settle()
	_expect(bar.visible and book.scroll.scroll_vertical > 0 and bounds == book.record_summary.get_global_rect(),
		"The actions stay available while the player reads the bottom of a long receipt.")
	await _capture("02-scroll-with-actions")

	book.record_rations.grab_focus()
	_key(KEY_ENTER)
	await _settle()
	var focus := tree.root.gui_get_focus_owner()
	var ration_controls: Array[Control] = [book.delegate, book.accept_offer, book.find_fruit, book.sell_silk,
		book.priority_picker, book.get_node("%Market")]
	print("MORNING_RECORD_RATIONS page=", book.title.text, " focus=", focus.name if focus else "", " scroll=", book.scroll.scroll_vertical)
	_expect(not book.show_previous and book.scroll.scroll_vertical > 0 and focus in ration_controls
		and (not book.scroll.is_ancestor_of(focus) or book.scroll.get_global_rect().encloses(focus.get_global_rect())),
		"The ration shortcut opens tonight and focuses the available ration action.")
	await _capture("03-tonight-ration-forecast")
	book.page_button.pressed.emit()
	await _settle()
	book.mark_raider.pressed.emit()
	await _settle()
	_expect(not _book() and ui.directions.following_raid and not ui.directions.destination().is_empty(),
		"The raid shortcut closes the book and uses the existing map marker for the present raider.")
	book = await _open_book()
	book.record_tribute.pressed.emit()
	await _settle()
	_expect(not _book() and ui.directions.tracked_plot == public_plot and state.field_route_status == Global.TributeRoute.TEND,
		"The tribute shortcut follows the public field without replanting it.")
	book = await _open_book()
	book.find_harvest.pressed.emit()
	await _settle()
	_expect(not _book() and ui.directions.tracked_plot == public_plot and state.field_route_status == Global.NightGrowth.READY,
		"The harvest shortcut follows the currently ripe crop.")
	book = await _open_book()
	book.plan_field.pressed.emit()
	await _settle()
	var management: Control = ui.panel_manager.management_panel_instance
	_expect(not _book() and management != null and management.well_field_selector.get_selected_id() == 1,
		"The finished field opens the management page with field 2 selected.")
	ui.panel_manager.hide_management_panel()
	await _settle()
	_expect(snapshot == _snapshot() and state.saved_games().is_empty(), "All five actions preserve the campaign and the staged receipt.")

	book = await _open_book()
	state.raid_day = 0
	state.food_storage = 12
	state.active_crops.clear()
	book._refresh()
	await _settle()
	_expect(not book.mark_raider.visible and not book.record_rations.visible and not book.find_harvest.visible
		and "缺粮 4 份" in book.record_summary_text.text and "公田 1 格、私田 2 格" in book.record_summary_text.text,
		"Finished tasks leave the action row while the historic warnings and ripe counts remain readable.")
	await _capture("04-record-after-conditions-change")
	print("MORNING_RECORD_ACTIONS buttons=", actions.size(), " marked_raid=true routed_tribute=true routed_harvest=true selected_field=2 saves=", state.saved_games().size())
	return not failed

func _snapshot() -> Array:
	return [state.current_day, state.day_progress, state.food_storage, state.money, state.current_stamina,
		state.king_storage, state.reputation, hash(state.active_crops), hash(state.last_dawn), hash(state.night_rations.last)]

func _book() -> Control:
	return ui.get_node_or_null("Control/NightRationsPanel") as Control

func _open_book() -> Control:
	ui.hud.morning_button.grab_focus()
	ui.hud.morning_button.pressed.emit()
	await _settle()
	return _book()

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)

func _settle() -> void:
	for frame in 7:
		await tree.process_frame

func _capture(name: String) -> void:
	if evidence.is_empty():
		return
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(evidence.path_join(name + ".png")) == OK, "Capture the fixed morning book.")
	print("MORNING_RECORD_FRAME ", name, " pixels=", frame.get_size())

func _expect(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		push_error(message)
	return ok
