extends RefCounted

var tree: SceneTree
var evidence := ""
var failed := false
var hud: Control
var state: Node
var prompt: Control

func run(scenario: SceneTree, directory := "") -> bool:
	tree = scenario
	evidence = directory
	tree.paused = true
	await _settle()
	state = tree.root.get_node("Global")
	var prefs := tree.root.get_node("Preferences")
	var events := tree.root.get_node("GameEvents")
	var workshop: SilkWorkshop = state.silk_workshop
	var feed: int = state.balance.silk_leaves_per_night
	workshop.built = true
	workshop.nights_left = 2
	workshop.leaves = 12
	workshop.cocoons = 5
	workshop.raw_silk = 7
	workshop.bolts = 2
	workshop.last_leaves_used = feed
	workshop.last_reeled = 1
	workshop.last_reel_thread = 2
	state.current_day = 12
	state.day_progress = 0.56
	state.estate_room = Global.EstateRoom.SILK_SHED
	_expect(prefs.set_reading_size(0) == OK, "Use the standard stock reading size.")
	if not _expect(tree.change_scene_to_file(state.ESTATE_SCENE) == OK, "Load the silk shed fixture."):
		return false
	await tree.scene_changed
	await _settle()
	var world := tree.current_scene.get_node("World")
	var ui := tree.current_scene.get_node("UI")
	var room := world.get_node("SilkInterior")
	hud = ui.hud
	if not _expect(room.is_visible_in_tree() and hud.workshop_status.is_visible_in_tree(), "Show the real shed and its stock panel."):
		return false
	var player: Player = world.player
	var tray := room.get_node("SilkwormTray") as Node2D
	player.arrive_at_position(tray.global_position + Vector2(0, 19), Vector2.UP)
	player._set_interaction_target(tray)
	prompt = player.interaction_prompt
	var ordinary: Array[String] = ["12 片", "5 只", "7 份", "2 匹"]
	_expect(hud.workshop_batch.text == "还需养 2 夜 · 每夜用 %d 片桑叶" % feed
		and hud.workshop_last_work.text == "昨夜 · " + workshop.last_work_summary(), "Show the batch forecast and work already done on separate lines.")
	var small_font: int = hud.workshop_stock.counts[0].get_theme_font_size(&"font_size")
	await _check_stock("01-batch-and-last-night", ordinary)

	workshop.nights_left = 1
	workshop.leaves = feed - 1
	workshop.cocoons = 123456789
	workshop.raw_silk = 234567890
	workshop.bolts = 345678901
	var large: Array[String] = ["%d 片" % workshop.leaves, "123456789 只", "234567890 份", "345678901 匹"]
	_expect(prefs.set_reading_size(2) == OK, "Increase the reading size without leaving the room.")
	events.silk_changed.emit()
	_expect(hud.workshop_stock.counts[0].get_theme_font_size(&"font_size") == small_font + 6
		and hud.workshop_batch.text == "还需养 1 夜 · 今夜缺 1 片桑叶"
		and "今夜缺 1 片桑叶" in tray.hint.text, "The large room panel and tray prompt agree about tonight's shortage.")
	await _check_stock("02-large-and-short", large)
	var count_rect: Rect2 = hud.workshop_stock.counts[3].get_global_rect()
	_expect(count_rect.position.y > hud.workshop_stock.counts[0].get_global_rect().position.y,
		"Extra-wide counts move to another row as whole cards.")

	workshop.nights_left = 0
	workshop.repeat_batches = true
	workshop.leaves = workshop.batch_leaf_cost(state.balance) - 1
	workshop.cocoons = 0
	workshop.raw_silk = 0
	workshop.bolts = 0
	workshop.last_leaves_used = 0
	workshop.last_reeled = 0
	workshop.last_reel_thread = 0
	events.silk_changed.emit()
	_expect(hud.workshop_batch.text == "续养还差 1 片桑叶" and not hud.workshop_last_work.visible,
		"An empty tray uses the whole batch requirement for automatic renewal.")
	workshop.leaves += 1
	events.silk_changed.emit()
	var renewed: Array[String] = ["%d 片" % workshop.leaves, "0 只", "0 份", "0 匹"]
	_expect(hud.workshop_batch.text == "今晚可续养 · 首夜用 %d 片桑叶" % feed, "The prepared tray reports tonight's renewal.")
	await _check_stock("03-prepared-tray", renewed)
	var snapshot := [workshop.leaves, workshop.cocoons, workshop.raw_silk, workshop.bolts, workshop.nights_left,
		state.current_day, state.day_progress, state.money, state.current_stamina, hash(state.active_crops)]
	ui.panel_manager.show_management_panel()
	ui.panel_manager.management_panel_instance.show_silk()
	await _settle()
	var ledger: Control = ui.panel_manager.management_panel_instance.silk_panel
	for index in renewed.size():
		_expect(ledger.stock.counts[index].text == renewed[index], "The management page reads the same inventory.")
	await _capture("04-ledger", null)
	_expect(tree.paused and state.saved_games().is_empty() and snapshot == [workshop.leaves, workshop.cocoons,
		workshop.raw_silk, workshop.bolts, workshop.nights_left, state.current_day, state.day_progress,
		state.money, state.current_stamina, hash(state.active_crops)], "Reading leaves the clock, economy and saves untouched.")
	return not failed

func _check_stock(sample: String, amounts: Array[String]) -> void:
	await _settle()
	prompt._refresh()
	var panel: Rect2 = hud.workshop_status.get_global_rect()
	var stock: SilkStock = hud.workshop_stock
	_expect(tree.root.get_visible_rect().encloses(panel) and panel.encloses(hud.workshop_batch.get_global_rect())
		and hud.workshop_batch.get_global_rect().position.y >= stock.get_global_rect().end.y
		and (not hud.workshop_last_work.visible or panel.encloses(hud.workshop_last_work.get_global_rect())),
		"The stock, tonight's status and the last shift stay in the screen's safe area.")
	for index in amounts.size():
		var count: Label = stock.counts[index]
		var icon := stock.get_child(index).get_child(0).get_child(0) as TextureRect
		_expect(count.text == amounts[index] and panel.encloses(count.get_global_rect())
			and panel.encloses(icon.get_global_rect()) and not icon.get_global_rect().intersects(count.get_global_rect())
			and (icon.texture as AtlasTexture).region.position.x == (index + 1) * SilkStock.ICON_SIZE,
			"Each count has its own original material drawing and stays inside the panel.")
	var reserved: Array[Rect2] = hud.map_obstacles()
	_expect(reserved.has(panel.grow(4.0)) and prompt.visible and not panel.intersects(prompt.get_global_rect()),
		"The tray prompt remains readable outside the stock panel.")
	await _capture(sample, stock)
	print("SILK_ROOM ", sample, " counts=", amounts, " panel=", panel, " saves=", state.saved_games().size())

func _capture(name: String, stock: SilkStock) -> void:
	if evidence.is_empty():
		return
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(evidence.path_join(name + ".png")) == OK, "Capture the fixed workshop view.")
	if not stock:
		return
	var icons: Array[TextureRect] = []
	for card in stock.get_children():
		var icon := card.get_child(0).get_child(0) as TextureRect
		icons.append(icon)
		icon.self_modulate.a = 0.0
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var without_icons := tree.root.get_texture().get_image()
	var changes: Array[int] = []
	for icon in icons:
		icon.self_modulate.a = 1.0
		var transform := tree.root.get_stretch_transform() * icon.get_global_transform_with_canvas()
		var region := Rect2i(transform * Rect2(Vector2.ZERO, icon.size))
		if not _expect(Rect2i(Vector2i.ZERO, frame.get_size()).encloses(region), "The icon lies inside the rendered game view."):
			continue
		var changed := 0
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var a := frame.get_pixel(x, y)
				var b := without_icons.get_pixel(x, y)
				if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.18:
					changed += 1
		changes.append(changed)
		_expect(changed >= 30, "The material is visible in the rendered stock panel.")
	print("SILK_ROOM_FRAME ", name, " pixels=", frame.get_size(), " icon_pixels=", changes)

func _settle() -> void:
	for frame in 8:
		await tree.process_frame

func _expect(ok: bool, message: String) -> bool:
	if not ok:
		failed = true
		push_error(message)
	return ok
