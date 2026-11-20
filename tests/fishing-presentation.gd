extends SceneTree

var failed := false

func _initialize() -> void:
	_check.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _check() -> void:
	paused = true
	var state := root.get_node("Global")
	var preferences := root.get_node("Preferences")
	var before := [state.current_day, state.day_progress, state.current_stamina, state.last_fishing_day, hash(state.fish_collection)]
	var stage := Node2D.new()
	root.add_child(stage)
	var angler = load("res://scenes/Player.tscn").instantiate()
	stage.add_child(angler)
	var spot = load("res://scripts/FishingSpot.gd").new()
	stage.add_child(spot)
	var wardrobe = load("res://scripts/PlayerAttire.gd")
	var panel_script = load("res://scripts/FishingPanel.gd")
	var directions := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	var rows := [2, 2, 0, 1]
	for outfit: String in wardrobe.CATALOG:
		angler.sprite.texture = wardrobe.texture(outfit)
		angler.tool_gesture.sleeve = wardrobe.CATALOG[outfit].sleeve
		for i in directions.size():
			spot.water = directions[i] * 38.0
			angler.sprite.frame_coords = Vector2i(0, 1)
			angler.tool_gesture.carry_pail(Vector2.RIGHT, 0.0)
			var panel = panel_script.new()
			panel.spot = spot
			panel.angler = angler
			stage.add_child(panel)
			panel.set_process(false)
			panel.float_time = 0.9
			panel._present_cast()
			_expect(spot.hint.text.is_empty(), "The panel already names the fishing place.")
			_expect(angler.sprite.frame_coords == Vector2i(3, rows[i]) and angler.sprite.flip_h == (i == 1),
				"The body must face the water in the waiting pose.")
			_expect(not angler.tool_gesture.visible and panel.rod.sleeve == wardrobe.CATALOG[outfit].sleeve,
				"The rod must use the current sleeves and clear the old hand tool.")
			if outfit == wardrobe.CATALOG.keys()[0] and i == 0:
				_check_reading_size(panel, preferences)
			var waiting_tip: Vector2 = spot.rod_tip
			panel.phase_time = panel.wait_time - 0.16
			panel._present_cast()
			_expect(spot.nibble > 0.0 and not spot.submerged, "The first nibbles leave the red float above water.")
			panel.phase = panel.Phase.BITE
			panel.phase_time = 0.08
			panel.float_time = 1.5
			panel._present_cast()
			_expect(spot.nibble == 0.0 and spot.submerged and is_equal_approx(spot.bite_age, 0.08),
				"The nibble gives way to a submerged float and a brief splash in the bite pose.")
			panel.phase = panel.Phase.REELING
			panel.float_time = 1.8
			panel.holding = true
			panel._present_cast()
			_expect(angler.sprite.frame_coords.x == 4 and spot.rod_tip != waiting_tip and spot.submerged,
				"Hauling must brace the body and move the rod.")
			_expect(spot.to_global(spot.rod_tip).is_equal_approx(panel.rod.to_global(panel.rod.tip)),
				"The line must meet the moving tip in world coordinates.")
			if i % 2 == 0:
				panel._finish("展示结束")
			panel.free()
			_expect(not angler.has_node("FishingRod") and not spot.line_visible and not spot.hint.text.is_empty() and angler.tool_gesture.visible
				and angler.sprite.frame_coords == Vector2i(0, 1) and not angler.sprite.flip_h,
				"Finishing or closing the window must restore the original tool and body.")
	stage.free()
	_expect(before == [state.current_day, state.day_progress, state.current_stamina, state.last_fishing_day, hash(state.fish_collection)],
		"A presentation check must leave the day, stamina and fish untouched.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_reading_size(panel: Control, preferences: Node) -> void:
	var current: int = preferences.reading_size
	preferences.reading_size = 0
	preferences.reading_size_changed.emit()
	var route: Button = panel._add_route_button("TravelRoute", "去南池畔围炉", "冬至围炉")
	var labels := [panel.get_child(0).get_child(0), panel.status, panel.detail, panel.pull_button, panel.close_button, route]
	var standard := labels.map(func(control: Control): return control.get_theme_font_size(&"font_size"))
	for level in [1, 2]:
		preferences.reading_size = level
		preferences.reading_size_changed.emit()
		for i in labels.size():
			_expect(labels[i].get_theme_font_size(&"font_size") == standard[i] + 3 * level,
				"The cast and result use every reading size.")
	route.free()
	panel.route_actions.hide()
	preferences.reading_size = current
	preferences.reading_size_changed.emit()
