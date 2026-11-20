extends SceneTree

const PAD := 42

var tree: SceneTree
var state: Node
var capture_dir := ""
var failed := false

func _initialize() -> void:
	_review.call_deferred(self)

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _settle() -> void:
	for frame in 5:
		await tree.process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame
	await _settle()

func _pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = PAD
		event.button_index = button
		event.pressed = pressed
		tree.root.window_input.emit(event)
		await tree.process_frame
	await _settle()

func _click(control: Button) -> void:
	if DisplayServer.get_name() == "headless":
		control.grab_focus()
		control.pressed.emit()
	else:
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = control.get_global_rect().get_center()
			event.global_position = event.position
			event.pressed = pressed
			tree.root.push_input(event, true)
			await tree.process_frame
	await _settle()

func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var frame := tree.root.get_texture().get_image()
	_expect(frame.save_png(capture_dir.path_join(name + ".png")) == OK, "Capture loaded UI in the private review directory.")

func _open(path: String) -> Control:
	var progress: float = state.day_progress
	tree.paused = true
	_expect(tree.change_scene_to_file(path) == OK, "Open the actual campaign scene at a staged day.")
	await tree.scene_changed
	var scene := tree.current_scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	for node_path in ["World/Landscape", "Landscape"]:
		var landscape := scene.get_node_or_null(node_path)
		if landscape:
			landscape.set_process(false)
	tree.paused = false
	await _key(KEY_I)
	var bag: Control = tree.current_scene.get_node("CampaignHUD").backpack
	_expect(is_instance_valid(bag) and tree.paused and state.day_progress == progress,
		"The existing backpack key opens the actual paused panel without advancing the fixture.")
	return bag

func _measure_labels(bag: Control) -> void:
	var clip: Rect2 = bag.get_node("Center/Window").get_global_rect()
	_expect(tree.root.get_visible_rect().encloses(clip), "The enlarged inventory fits the visible Windows game area.")
	for node in bag.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and not label.text.is_empty():
			_expect(label.get_visible_line_count() == label.get_line_count() and clip.grow(0.01).encloses(label.get_global_rect()),
				"Every line fits at the largest text size: " + label.name)

func _bounds(bag: Control) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for panel: Control in bag.items.get_children():
		rects.append(panel.get_global_rect())
	return rects

func _stage_stock() -> void:
	state.current_day = 5
	state.day_progress = 0.41
	state.crop_stock.add("millet", 3)
	state.crop_stock.add("beans", 1)
	state.crop_stock.add("mixed", 8765432)
	state.fish_collection["carp"] = {"first_day": 3, "first_site": 1, "stock": 2}
	state.fish_collection["perch"] = {"first_day": 4, "first_site": 1, "stock": 1}
	state.silk_workshop.leaves = 12
	state.silk_workshop.bolts = 2
	state.sheepfold.wool = 3
	state.travel_meal = "rice_fish"
	state.wild_herbs_packed = true
	state.money = 1234567

func _review(host: SceneTree) -> void:
	tree = host
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		push_error("Run backpack-reading only in an isolated smoke profile.")
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	var preferences := tree.root.get_node("Preferences")
	var events := tree.root.get_node("GameEvents")
	var args := OS.get_cmdline_user_args()
	var baseline := "baseline" in args
	if args.size() >= 2:
		capture_dir = args[1]
	_stage_stock()
	var bag := await _open(state.ESTATE_SCENE)
	if not is_instance_valid(bag):
		tree.quit(1)
		return
	var standard: int = bag.pockets[0].quantity.get_theme_font_size(&"font_size")
	_expect(preferences.set_reading_size(2) == OK, "Apply the largest reading size while the inventory is open.")
	await _settle()
	var enlarged: int = bag.pockets[0].quantity.get_theme_font_size(&"font_size")
	if baseline:
		_expect(enlarged == standard and not bag.items.get_node("millet").has_node("Inspect"),
			"The previous build keeps the same stock font and offers no inspectable pocket.")
		print("BACKPACK_READING_BASELINE quantity_font=", standard, "/", enlarged)
		await _capture("baseline")
	else:
		await _review_details(bag, standard, enlarged, events)
	print("BACKPACK_READING window=", tree.root.size, " renderer=", RenderingServer.get_current_rendering_method(),
		" driver=", RenderingServer.get_current_rendering_driver_name(), " baseline=", baseline)
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func _review_details(bag: Control, standard: int, enlarged: int, events: Node) -> void:
	_expect(enlarged == standard + 6 and "黍" in bag.detail_name.text and "3 份" in bag.detail_name.text,
		"The font preference updates a live panel that initially shows the first stocked crop.")
	await _key(KEY_DOWN)
	_expect(bag.crop_tab.has_focus(), "Down from the close button reaches the active shelf.")
	await _key(KEY_DOWN)
	_expect(bag.items.get_node("millet/Inspect").has_focus(), "Down from the shelf reaches the first stocked item.")
	_measure_labels(bag)
	await _capture("estate-crops")
	var beans := bag.items.get_node("beans/Inspect") as Button
	await _click(beans)
	_expect("菽" in bag.detail_name.text and "还差 1" in bag.detail_order.text
		and beans.accessibility_name.contains("菽"), "Clicking a stocked crop shows its own uses and the current order's gap.")
	var old_bounds := _bounds(bag)
	await _key(KEY_DOWN)
	_expect("混存作物" in bag.detail_name.text and "8765432" in bag.detail_name.text,
		"Keyboard arrows skip the empty slot and show the full older-stock quantity.")
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(bag.fish_tab.has_focus() and "鲤鱼" in bag.detail_name.text and "砾滩" in bag.detail_use.text,
		"A shoulder button turns to the fish shelf while the cropped art and source agree.")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect(bag.items.get_node("carp/Inspect").has_focus(), "The D-pad enters the selected shelf.")
	_measure_labels(bag)
	await _capture("estate-fish")
	await _click(bag.items.get_node("perch/Inspect"))
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect("桑叶" in bag.detail_name.text and "蚕" in bag.detail_use.text,
		"Selecting a craft stack identifies its workshop use.")
	state.silk_workshop.leaves = 0
	events.silk_changed.emit()
	await _settle()
	_expect(bag.craft_tab.has_focus() and "丝绸" in bag.detail_name.text and _bounds(bag) == old_bounds,
		"A depleted selected stack transfers the focus and keeps the same grid positions.")
	print("BACKPACK_READING_DETAILS quantity_font=", standard, "/", enlarged, " depletion_focus=", bag.craft_tab.has_focus(),
		" fixed_grid=", _bounds(bag) == old_bounds)
	await _capture("estate-materials")
	await _click(bag.items.get_node("wool/Inspect"))
	for shelf: Array in [
		[bag.crop_tab, "mixed", "混存作物"],
		[bag.fish_tab, "perch", "鳜鱼"],
		[bag.craft_tab, "wool", "羊毛"],
	]:
		await _pad(JOY_BUTTON_RIGHT_SHOULDER)
		_expect(shelf[0].has_focus() and shelf[2] in bag.detail_name.text, "Returning to a shelf remembers its item: " + shelf[1])
		await _pad(JOY_BUTTON_DPAD_DOWN)
		_expect(bag.items.get_node(shelf[1] + "/Inspect").has_focus(), "Down enters the remembered item: " + shelf[1])
	state.fish_collection.erase("perch")
	events.fish_changed.emit()
	await _pad(JOY_BUTTON_LEFT_SHOULDER)
	_expect(bag.fish_tab.has_focus() and "鲤鱼" in bag.detail_name.text,
		"A remembered item that depleted off the shelf falls back to the first available item.")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect(bag.items.get_node("carp/Inspect").has_focus(), "Down reaches the fallback item when the remembered stack is empty.")
	print("BACKPACK_READING_BOOKMARKS shelves=3 fallback=", bag.detail_name.text)
	await _pad(JOY_BUTTON_LEFT_SHOULDER)
	for id: String in CropData.IDS:
		if state.crop_stock.count(id) == 0:
			state.crop_stock.add(id, 1)
	events.inventory_changed.emit(state.crop_stock.count())
	await _settle()
	var harvests := 0
	for index in CropData.IDS.size():
		var icon: AtlasTexture = bag.pockets[index].icon.texture
		if bag.pockets[index].id == CropData.IDS[index] and icon and icon.region == Rect2(index * 32, 0, 32, 32):
			harvests += 1
	_expect(harvests == CropData.IDS.size(), "Each named crop is displayed with the correctly sliced harvest sprite.")
	await _click(bag.items.get_node("mulberry/Inspect"))
	_expect(bag.detail_icon.texture == bag.pockets[CropData.IDS.find("mulberry")].icon.texture,
		"The selected crop uses the same drawing in its pocket and in the enlarged detail.")
	_measure_labels(bag)
	await _capture("estate-harvests")
	print("BACKPACK_READING_HARVESTS sprites=", harvests, " detail=", bag.detail_name.text, " uniform_bounds=", _bounds(bag) == old_bounds)
	await _pad(JOY_BUTTON_B)
	_expect(tree.current_scene.get_node("CampaignHUD").backpack == null and not tree.paused,
		"Gamepad B closes only the backpack.")
	for row: Array in [[state.WEST_ROAD_SCENE, "road"], [state.WEST_MARKET_SCENE, "market"], [state.WILDERNESS_SCENE, "ravine"]]:
		bag = await _open(row[0])
		_measure_labels(bag)
		_expect(bag.eat_button.visible and bag.use_herbs_button.visible, "The inspect area fits above the original carried supplies.")
		await _capture(row[1])
		await _key(KEY_ESCAPE)
	_expect(not tree.paused and state.current_day == 5 and state.day_progress == 0.41 and state.saved_games().is_empty(),
		"Reading and closing inventory leaves the staged date, time, and save directory intact.")
