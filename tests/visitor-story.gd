extends SceneTree

const Campaign := preload("res://tests/CampaignReplay.gd")

var failed := false
var state: Node
var world: Node
var ui: Node

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		push_error(detail)
		failed = true

func _refresh_estate() -> void:
	world = current_scene.get_node("World")
	ui = current_scene.get_node("UI")

func _sleep() -> void:
	ui.sleep_button.pressed.emit()
	await create_timer(1.1).timeout

func _press(code: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	root.push_input(key, true)

func _open() -> Control:
	_press(KEY_E)
	await process_frame
	return ui.get_node_or_null("Control/DialoguePanel")

func _approach(actor: Node2D) -> Control:
	await Campaign.walk_to(self, world.player, actor.global_position + Vector2(0, 23))
	return await _open()

func _option(dialog: Control, prefix: String) -> Button:
	for button: Button in dialog.options_container.get_children():
		if button.text.begins_with(prefix):
			return button
	return null

func _choose(dialog: Control, prefix: String) -> void:
	var button := _option(dialog, prefix)
	if button == null or button.disabled:
		push_error("Choice unavailable: " + prefix)
		failed = true
		return
	button.pressed.emit()
	await process_frame

func _save_reload() -> void:
	if state.save_game() != OK or state.load_game() != OK:
		push_error("Could not save and reload the current day.")
		quit(1)
		return
	await scene_changed
	_refresh_estate()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run visitor-story with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	seed(189)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	state = root.get_node("Global")
	_refresh_estate()
	var starter: Node2D = world.retainer_instances[state.retainers[0]]
	var dialog := await _approach(starter)
	if dialog == null:
		push_error("The starter retainer must be reachable by walking and pressing E.")
		quit(1)
		return
	_expect(dialog.name_label.text == "渠伯" and "纳贡" in dialog.text_label.text and "换粮" in dialog.text_label.text
		and world.player.conversation_open,
		"The starter explains tribute and private grain, and the conversation holds player input.")
	_press(KEY_ESCAPE)
	await process_frame
	_expect(not world.player.conversation_open, "Escape closes the conversation and releases the player.")

	var tribute := Vector2i(5, 5)
	var private_cell := Vector2i(6, 5)
	for cell in [tribute, private_cell]:
		for action in range(3):
			world.handle_interaction(cell)
	await _sleep()
	var first_visitor: Node2D = world.active_visitors.front()
	var first_stop := first_visitor.global_position
	dialog = await _approach(first_visitor)
	if dialog == null:
		push_error("The journal must lead to a walkable first visit.")
		quit(1)
		return
	_expect(dialog.name_label.text == "季青" and "南路亭" in dialog.context_label.text
		and "季青" in ui.hud.visitor_label.text and "国库" in dialog.text_label.text,
		"The first guest and the journal agree on the pavilion.")
	var first_portrait: Rect2 = dialog.portrait.texture.region
	_expect(dialog.portrait.texture.atlas.resource_path.ends_with("neighbor-portraits.svg")
		and _option(dialog, "送路粮") == null, "Ji Qing has a portrait and the errand waits for tribute.")
	await _choose(dialog, "交谈")
	var before: int = state.reputation
	await _save_reload()
	var current_guest: Node2D = world.active_visitors.front()
	_expect(current_guest.global_position == first_stop, "A same-day load restores the same guest at the same place.")
	dialog = await _approach(current_guest)
	if dialog == null:
		quit(1)
		return
	_expect(_option(dialog, "已交谈").disabled and state.reputation == before and state.visitor_encounters["季青"] == 2,
		"A same-day load keeps the conversation reward spent.")
	await _choose(dialog, "离开")

	world.handle_interaction(tribute)
	world.handle_interaction(private_cell)
	await _sleep()
	var mohist: Node2D = world.active_visitors.front()
	dialog = await _approach(mohist)
	if dialog == null:
		quit(1)
		return
	_expect(dialog.name_label.text == "石墨" and "水利" in dialog.text_label.text and "水源旁" in ui.hud.visitor_label.text
		and mohist.global_position.distance_to(first_stop) > 60.0, "Stone Ink takes a different, signposted stop.")
	await _choose(dialog, "交谈")
	world.handle_interaction(tribute)
	_expect(state.king_storage == 1 and state.player_inventory == 0, "The first harvest reaches the treasury and leaves the private crop available.")

	while state.current_day < 7:
		if not state.active_crops.has(tribute):
			world.handle_interaction(tribute)
		world.handle_interaction(tribute)
		await _sleep()
		if world.field_action(tribute) == world.FieldAction.HARVEST:
			world.handle_interaction(tribute)
		var guest: Node2D = world.active_visitors.front()
		if state.current_day == 7:
			break
		dialog = await _approach(guest)
		if dialog == null:
			quit(1)
			return
		await _choose(dialog, "交谈")

	dialog = await _approach(world.active_visitors.front())
	if dialog == null:
		quit(1)
		return
	_expect(dialog.name_label.text == "季青" and "赶着走" in dialog.text_label.text and _option(dialog, "送路粮").disabled,
		"The returning visitor remembers tribute and asks for a spare private crop.")
	await _choose(dialog, "离开")
	world.handle_interaction(private_cell)
	var previous_rep: int = state.reputation
	dialog = await _open()
	await _choose(dialog, "送路粮")
	_expect(state.road_provisions_delivered and state.player_inventory == 0
		and state.reputation == previous_rep + state.balance.interaction_reputation_gain,
		"The handoff consumes exactly one private crop and grants the stated favor once.")
	dialog = await _open()
	_expect(_option(dialog, "送路粮") == null and "木匣" in dialog.text_label.text
		and dialog.portrait.texture.region != first_portrait, "The completed favor changes the next conversation and the portrait expression.")
	await _choose(dialog, "招募")
	_expect(world.active_visitors.is_empty() and state.retainers.size() == 2 and state.retainers.back().name == "季青",
		"The recruited guest leaves the visitor slot for that day and becomes a resident.")
	var resident: Node2D = world.retainer_instances[state.retainers.back()]
	dialog = await _approach(resident)
	if dialog == null:
		quit(1)
		return
	_expect("门客" in dialog.context_label.text and "木匣" in dialog.text_label.text,
		"The same person carries the story into their resident dialogue.")
	await _choose(dialog, "离开")

	ui.manage_button.pressed.emit()
	await process_frame
	var management: Control = ui.panel_manager.management_panel_instance
	management.retainer_list_container.get_child(1).duty_picker.item_selected.emit(2)
	management.get_node("CloseButton").pressed.emit()
	await create_timer(2.6).timeout
	_expect(resident.global_position.distance_to(resident.home_position) < 12 and resident.global_position.distance_to(first_stop) > 100,
		"The assigned teacher walks to the courtyard.")
	_expect("堂前" in ui.hud.visitor_label.text, "The journal follows the new duty station.")
	await _save_reload()
	_expect(state.road_provisions_delivered and world.active_visitors.is_empty()
		and state.retainers.back().duty == state.retainers.back().Duty.TEACH, "Recruitment, duty and the finished errand survive reload.")
	dialog = await _approach(world.retainer_instances[state.retainers.back()])
	if dialog == null:
		quit(1)
		return
	_expect("教习" in dialog.context_label.text and "教礼" in dialog.text_label.text and _option(dialog, "送路粮") == null,
		"A restored teacher refers to the pavilion when explaining the lesson.")
	await _choose(dialog, "离开")
	var eligible: Array[String] = ["季青"]
	var visitor_data := load("res://scripts/VisitorData.gd")
	_expect(visitor_data.for_day(12, eligible).name != "季青", "A resident never occupies their former visitor slot.")

	var old_save := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	old_save.store_string('{"current_day":7,"king_storage":1,"visitor_encounters":["季青"]}')
	old_save.close()
	if state.load_game(state.SAVE_PATH) != OK:
		quit(1)
		return
	await scene_changed
	_refresh_estate()
	_expect(state.visitor_encounters["季青"] == 0 and not world.current_visitor().talked_today()
		and state.road_provisions_requested(), "The previous save format preserves a prior meeting and offers the new errand.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
