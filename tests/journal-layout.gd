extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _settle() -> void:
	for i in 5:
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var hud = load("res://scenes/EstateHUD.tscn").instantiate()
	root.add_child(hud)
	hud.guide.heading.text = "第一次纳贡"
	hud.guide.text = "水已到田，过夜后生长。\n还需供水 2 夜。"
	hud.opening_action.text = "去见渠伯 · 田边"
	hud.opening_action.show()
	hud.first_private_button.show()
	hud.handover_button.show()
	await _settle()
	var journal: Control = hud.get_node("Journal")
	var folded := journal.get_global_rect()
	var main_action: Rect2 = hud.opening_action.get_global_rect()
	var side_action: Rect2 = hud.first_private_button.get_global_rect()
	_expect(is_equal_approx(main_action.position.y, side_action.position.y) and not main_action.intersects(side_action),
		"Both field actions must fit on one row.")
	_expect(folded.encloses(hud.handover_button.get_global_rect()) and folded.encloses(hud.neighbors_button.get_global_rect()),
		"The two books must remain accessible with the visitor notes folded.")
	hud.visitor_label.text = "渠伯在田边。"
	hud.journal_details.button_pressed = true
	await _settle()
	var short_height := journal.size.y
	var notes: ScrollContainer = hud.visitor_notes
	var bar := notes.get_v_scroll_bar()
	_expect(hud.visitor_label.is_visible_in_tree() and not bar.visible and short_height > folded.size.y,
		"A short note should open at its natural height.")
	hud.visitor_label.text = "渠伯在田边。\n".repeat(12) + "陶辛在西廊。"
	await _settle()
	_expect(bar.is_visible_in_tree() and bar.max_value > bar.page and notes.size.y <= hud.VISITOR_NOTES_MAX_HEIGHT,
		"Long notes must scroll inside the open journal.")
	var bottom := Rect2(notes.get_global_rect().end - Vector2(10, 10), Vector2(3, 3))
	_expect(not hud.map_space_clear(bottom), "The expanded notes must occupy map space.")
	bar.grab_focus()
	_expect(bar.has_focus(), "The visible scrollbar must be reachable with the keyboard.")
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_END
		key.pressed = down
		root.push_input(key, true)
	await _settle()
	_expect(is_equal_approx(bar.value, bar.max_value - bar.page), "End must reach the last note.")
	hud.journal_details.button_pressed = false
	await _settle()
	_expect(journal.get_global_rect().is_equal_approx(folded) and hud.map_space_clear(bottom),
		"Folding the notes must return all their map space.")
	hud.visitor_label.text = "渠伯在田边。"
	hud.journal_details.button_pressed = true
	await _settle()
	_expect(is_equal_approx(journal.size.y, short_height) and notes.scroll_vertical == 0 and not bar.visible,
		"A shorter updated note must reopen at the top with no empty space.")
	hud.free()
	if failures.is_empty():
		print("SCENARIO_OK")
	quit(0 if failures.is_empty() else 1)
