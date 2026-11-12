extends "res://tests/WestMarketReplay.gd"

const Gamepad := preload("res://tests/GamepadReplay.gd")
const SECTIONS := ["封地概览", "市场", "君子六艺", "科技", "蚕桑", "溪行手记", "时令单", "邻里手记", "溪鱼簿"]

var world: Node2D
var ui: CanvasLayer
var panel: Control
var controller := Gamepad.new()

func _selected(index: int) -> bool:
	var selected: Array[Button] = panel.section_buttons.filter(func(button: Button): return button.button_pressed)
	return panel.tabs.current_tab == index and selected == [panel.section_buttons[index]]

func _check_pages() -> void:
	var frame: Rect2 = panel.get_node("Frame").get_global_rect()
	var header: Rect2 = panel.sections.get_global_rect()
	for index in SECTIONS.size():
		var button: Button = panel.section_buttons[index]
		_expect(button.text == SECTIONS[index] and frame.encloses(button.get_global_rect()),
			"Every named section is visible within the management frame.")
		await _button(button)
		var page: Control = panel.tabs.get_current_tab_control()
		var bounds := page.get_global_rect()
		_expect(_selected(index) and frame.encloses(bounds) and bounds.position.y >= header.end.y + 8.0,
			"Direct navigation selects %s and fits its contents." % SECTIONS[index])
		var keeps_roster := index < SECTIONS.find("邻里手记")
		_expect(panel.retainer_panel.visible == keeps_roster, "The roster shares the working pages and leaves room for the ledgers.")
		if index == SECTIONS.find("邻里手记"):
			await _snapshot("04-neighbor-journal")

func _send_pointer(event: InputEventMouse, point: Vector2) -> void:
	event.position = point
	event.global_position = point
	tree.root.push_input(event, true)
	await tree.process_frame

func _drag_assignment() -> void:
	var row: Control = panel.retainer_list_container.get_child(0)
	var origin: Vector2 = row.get_node("HBoxContainer/Icon").get_global_rect().get_center()
	var plot: Button = panel.map_grid_container.get_child(8)
	var drop := plot.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	await _send_pointer(press, origin)
	var motion := InputEventMouseMotion.new()
	motion.relative = drop - origin
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	await _send_pointer(motion, drop)
	_expect(tree.root.gui_is_dragging(), "Dragging the retainer portrait starts a real GUI drag.")
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	await _send_pointer(press, drop)
	_expect(state.retainers[0].assigned_area == plot.grid_pos and not tree.root.gui_is_dragging(),
		"Dropping on a visible plot gives that plot priority.")
	print("MANAGEMENT_FIELD assigned=", state.retainers[0].assigned_area)

func _keyboard_trade() -> void:
	_expect(_selected(0) and panel.section_buttons[0].has_focus(), "The first opening focuses the selected section.")
	panel.close_button.grab_focus()
	await _key(KEY_TAB)
	_expect(panel.section_buttons[0].has_focus(), "Tab from the last control returns to the first section.")
	await _key(KEY_RIGHT)
	_expect(panel.section_buttons[1].has_focus() and _selected(0), "Right moves keyboard focus before activation.")
	await _key(KEY_ENTER)
	_expect(_selected(1), "Enter opens Market from the keyboard.")
	var before: int = state.food_storage
	await _button(panel.market_panel.convert_button)
	_expect(state.food_storage == before + 1 and state.player_inventory == 1, "The market turns one harvested crop into food.")
	await _snapshot("02-market")
	print("MANAGEMENT_MARKET food=", state.food_storage, " stock=", state.player_inventory)
	var kind: OptionButton = panel.market_panel.reserve_kind
	kind.grab_focus()
	await _key(KEY_ENTER)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	var reserve: Label = panel.market_panel.reserve_label
	var frame: Rect2 = panel.get_node("Frame").get_global_rect()
	_expect("立桩用粮" in reserve.text and frame.encloses(panel.market_panel.reserve_button.get_global_rect()),
		"The longer reclamation budget and its action fit below the trade controls.")
	print("MANAGEMENT_RESERVE kind=", kind.selected, " budget_lines=", reserve.text.get_slice_count("\n"))

func _controller_sections() -> void:
	var seed_before: String = world.current_seed_id
	await _button(panel.section_buttons[1])
	await _button(panel.market_panel.get_node("MarketHeader/NightRations"))
	await controller._tap(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(_selected(1) and ui.has_node("Control/NightRationsPanel"),
		"Shoulders leave management alone while the ration plan is on top.")
	await _key(KEY_ESCAPE)
	await _button(panel.section_buttons[0])
	await controller._tap(JOY_BUTTON_LEFT_SHOULDER)
	_expect(_selected(8) and not panel.retainer_panel.visible and panel.section_hint.visible
		and panel.close_button.text == "返回  B", "LB wraps to the fish ledger and updates the controller hints.")
	await controller._tap(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(_selected(0) and world.current_seed_id == seed_before, "RB wraps to the field without selecting another seed.")
	var duty: OptionButton = panel.retainer_list_container.get_child(0).duty_picker
	await controller._aim(duty.get_global_rect().get_center())
	await tree.create_timer(0.72).timeout
	_expect(tree.root.get_embedded_subwindows().any(func(window: Window): return window.unfocusable),
		"The virtual pointer can show the duty tooltip.")
	await controller._tap(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(_selected(1), "A passive tooltip leaves the shoulder shortcut available.")
	await controller._tap(JOY_BUTTON_LEFT_SHOULDER)
	await controller._click(duty)
	_expect(duty.get_popup().visible, "A opens the roster's duty menu.")
	await controller._tap(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(_selected(0) and duty.get_popup().visible, "A shoulder press leaves the open duty menu alone.")
	await _key(KEY_ESCAPE)
	_expect(panel.visible and not duty.get_popup().visible, "Escape returns from the duty menu to management.")
	for _step in 4:
		await controller._tap(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(_selected(4) and panel.section_buttons[4].has_focus()
		and controller.pad.cursor.position.distance_to(panel.section_buttons[4].get_global_rect().get_center()) < 2.0,
		"RB selects Silk and moves the pointer to the active section.")
	await _snapshot("03-silk-controller")
	await controller._tap(JOY_BUTTON_B)
	_expect(not panel.visible, "B closes management.")
	await controller._tap(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(world.current_seed_id != seed_before, "Outside management the same shoulder button cycles seeds.")
	print("MANAGEMENT_CONTROLLER selected=", panel.tabs.current_tab, " outside_seed=", world.current_seed_id)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	state = tree.root.get_node("Global")
	controller.tree = tree
	controller.pad = tree.root.get_node("GamepadInput")
	tree.root.notify_mouse_entered()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	await _harvest(world, ui)
	await _button(ui.manage_button)
	panel = ui.panel_manager.management_panel_instance
	if _expect(panel.section_buttons.size() == SECTIONS.size(), "The management bar has all nine sections."):
		await _snapshot("01-field")
		await _keyboard_trade()
		await _check_pages()
		await _key(KEY_ESCAPE)
		_expect(not panel.visible and ui.manage_button.has_focus(), "Esc returns focus to the management opener.")
		await _button(ui.hud.neighbors_button)
		_expect(_selected(7) and panel.section_buttons[7].has_focus(), "The neighbor shortcut opens and selects its section.")
		await _button(panel.section_buttons[0])
		await _drag_assignment()
		await _controller_sections()
		_expect(controller.failures == 0, "The controller could reach the duty picker.")
	tree.unload_current_scene()
	await tree.process_frame
	if not failed:
		print("MANAGEMENT_SECTIONS count=", SECTIONS.size())
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
