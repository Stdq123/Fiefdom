extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const PUBLIC := Vector2i(5, 5)
const KEEPER := "渠伯"
const ROAD_KEEPER := "季青"

var tree: SceneTree
var state: Node
var world: Node
var ui: Node
var directions: Control
var capture_dir := ""
var failed := false
var legacy := false

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failed = true
		push_error(detail)
	return condition

func _button(parent: Node, title: String) -> Button:
	for button: Button in parent.find_children("*", "Button", true, false):
		if button.text == title:
			return button
	return null

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	tree.root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame
	await tree.process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.pressed = pressed
		key.keycode = code
		key.physical_keycode = code
		tree.root.push_input(key, true)
		await tree.process_frame
	await tree.process_frame

func _scroll(button: MouseButton) -> void:
	var at := tree.root.get_visible_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	tree.root.push_input(motion, true)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = button
	wheel.pressed = true
	wheel.position = at
	wheel.global_position = at
	tree.root.push_input(wheel, true)
	await tree.process_frame
	await tree.process_frame

func _use_estate() -> void:
	if tree.current_scene == null:
		await tree.scene_changed
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	directions = ui.directions
	await tree.process_frame

func _point_on_field(cell := PUBLIC) -> Vector2:
	var tiles: TileMapLayer = world.tile_map
	return tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell)

func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var picture := tree.root.get_texture().get_image()
	_expect(picture.save_png(capture_dir.path_join(name + ".png")) == OK, "Could not capture " + name)
	print("DIRECTION_FRAME ", name, " ", picture.get_size())

func _night() -> void:
	await _click(ui.sleep_button.get_global_rect().get_center())
	await tree.create_timer(1.12).timeout

func _save_and_continue() -> void:
	await _click(ui.settings_button.get_global_rect().get_center())
	var settings: Control = ui.panel_manager.settings_panel_instance
	_expect(not directions.visible and settings.visible, "Settings covers the active map directions.")
	await _click(_button(settings, "保存游戏").get_global_rect().get_center())
	_expect(settings.save_status.text == "游戏已保存", "The watered plot is saved through Settings.")
	await _click(_button(settings, "返回标题").get_global_rect().get_center())
	var confirmation := settings.get_node("TitleConfirmation") as ConfirmationDialog
	_expect(confirmation.visible, "Returning to the title asks for confirmation.")
	confirmation.confirmed.emit()
	await tree.scene_changed
	await tree.process_frame
	await _click(tree.current_scene.continue_button.get_global_rect().get_center())
	await _use_estate()

func _journal() -> Control:
	await _click(ui.hud.neighbors_button.get_global_rect().get_center())
	return ui.panel_manager.management_panel_instance.neighbor_journal

func _meet(speaker: String) -> Control:
	var actor: Node2D = world.neighbor_actor(speaker)
	if not _expect(is_instance_valid(actor), "Expected a person named " + speaker):
		return null
	await Campaign.walk_to(tree, world.player, actor.global_position + Vector2(0, 19))
	await tree.physics_frame
	await _key(KEY_E)
	return ui.get_node_or_null("Control/DialoguePanel") as Control

func _visit_while_crop_grows(speaker: String) -> Control:
	var invitation: Button = ui.hud.opening_action
	if not _expect(invitation.is_visible_in_tree() and ("去见" + speaker) in invitation.text,
		"The journal offers a way to find " + speaker + " while the public crop grows."):
		return null
	await _click(invitation.get_global_rect().get_center())
	_expect(directions.tracked_neighbor == speaker and directions.visible,
		"The invitation locates the present neighbor.")
	var dialog := await _meet(speaker)
	_expect(directions.tracked_neighbor.is_empty(), "Conversation clears the invitation's route.")
	return dialog

func _read_handover_dialogue(dialog: Control, gamepad: RefCounted) -> bool:
	if not _expect(dialog != null, "The first-day visit opens the keeper's conversation."):
		return false
	_expect("采邑由你照管" in dialog.text_label.text and "四周的收成归你" in dialog.text_label.text,
		"The keeper explains the handover and where both crops go.")
	await _capture("04b-new-estate-conversation")
	await _key(KEY_E)
	if not _expect(not is_instance_valid(dialog) and not world.player.conversation_open,
		"Pressing the interaction key again finishes the keeper's one-choice dialogue."):
		return false
	dialog = await _meet(KEEPER)
	if not _expect(dialog != null and _button(dialog, "离开").has_focus(), "The conversation owns focus on open."):
		return false
	await _key(KEY_ENTER)
	_expect(not is_instance_valid(dialog) and not world.player.conversation_open, "Enter activates the focused reply.")
	await gamepad._tap(JOY_BUTTON_X)
	dialog = ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialog != null and _button(dialog, "离开").has_focus(), "X opens the same conversation with its reply in focus."):
		return false
	await gamepad._tap(JOY_BUTTON_X)
	return _expect(not is_instance_valid(dialog) and not world.player.conversation_open,
		"X can finish the same conversation with the gamepad.")

func _greet_first_visitor(dialog: Control, gamepad: RefCounted) -> bool:
	if not _expect(dialog != null, "The day-two visitor can be met through E."):
		return false
	var greet := _button(dialog, "交谈")
	var leave := _button(dialog, "离开")
	_expect(leave.has_focus() and not greet.disabled and dialog.options_container.get_child(1).disabled
		and dialog.options_container.get_child(2).disabled, "The visitor starts on Leave with unavailable actions disabled.")
	var before: int = state.reputation
	await _key(KEY_E)
	_expect(is_instance_valid(dialog) and state.reputation == before, "The interaction key does not pick among multiple choices.")
	await _key(KEY_LEFT)
	_expect(greet.has_focus(), "Left skips both disabled visitor actions.")
	var card: Control = dialog.get_node("Panel")
	var speech: RichTextLabel = dialog.text_label
	_expect(tree.root.get_visible_rect().encloses(card.get_global_rect())
		and speech.size.y >= speech.get_content_height()
		and not speech.get_global_rect().intersects(dialog.options_container.get_global_rect())
		and card.get_global_rect().encloses(leave.get_global_rect()), "The portrait, speech and choices fit inside the dialogue card.")
	await _capture("04d-visitor-keyboard-options")
	await gamepad._tap(JOY_BUTTON_DPAD_RIGHT)
	_expect(leave.has_focus(), "The D-pad moves focus to the next available choice.")
	await gamepad._tap(JOY_BUTTON_X)
	_expect(is_instance_valid(dialog) and state.reputation == before, "X leaves the multi-choice conversation open.")
	await gamepad._tap(JOY_BUTTON_DPAD_LEFT)
	_expect(greet.has_focus() and greet.get_global_rect().has_point(gamepad.pad.cursor.position),
		"The D-pad selects the reply and puts the gamepad pointer on its button.")
	await _capture("04e-visitor-gamepad-options")
	await gamepad._tap(JOY_BUTTON_A)
	_expect(not is_instance_valid(dialog) and not world.player.conversation_open
		and state.reputation == before + state.balance.interaction_reputation_gain,
		"A confirms the selected conversation exactly once and returns to the field.")
	print("DIRECTION_DIALOGUE day=", state.current_day, " reputation=", before, "->", state.reputation)
	return not failed

func _private_crop_and_grain(spawn: Vector2) -> void:
	await Campaign.walk_to(tree, world.player, spawn)
	var cell: Vector2i = ui.hud.guide.opening_cell
	_expect(directions.mark == directions.Mark.PLOT and directions.caption.text == "私田"
		and not state.is_public_plot(cell), "The first private field has a visible marker outside the public center.")
	await _capture("08-first-private-plot")
	await _click(_point_on_field(cell))
	_expect(directions.mark == directions.Mark.BUTTON and ui.hud.guide.opening_seed_id == "beans"
		and "留肥" in ui.hud.guide.text, "The agreed rotation points to beans after tilling the private field.")
	await _capture("09-choose-beans")
	await _key(KEY_5)
	await _click(_point_on_field(cell))
	if not _expect(state.active_crops.has(cell) and state.active_crops[cell].id == "beans",
		"The marked field can be sown through the usual left click."):
		return
	var nights: int = state.active_crops[cell].growth_nights
	for night in nights:
		if world.is_crop_dry(cell):
			await _click(_point_on_field(cell))
		await _night()
	_expect("私田成熟" in ui.hud.guide.text and directions.mark == directions.Mark.PLOT,
		"The private cue comes back to the same crop when it is ready.")
	var before_food: int = state.food_storage
	await _click(_point_on_field(cell))
	_expect(state.king_storage == 1 and state.private_harvest_total == 1 and state.crop_stock.count("beans") == 1
		and state.fertile_cells.has(cell) and state.field_rotation.beans_day == state.current_day,
		"The private crop goes to the owner and fulfills the existing rotation step.")
	var trade: Button = ui.hud.opening_action
	if not _expect(trade.visible and trade.text == "用私田收成换口粮", "The journal points directly to the first crop exchange."):
		return
	await _capture("10-grain-invitation")
	await _click(trade.get_global_rect().get_center())
	var panel: Control = ui.panel_manager.management_panel_instance
	var market: Control = panel.market_panel
	_expect(market.is_visible_in_tree() and not market.convert_button.disabled and market.convert_button.has_focus(),
		"The existing market opens to a usable one-crop conversion.")
	await _capture("11-first-grain-trade")
	await _click(market.convert_button.get_global_rect().get_center())
	_expect(state.food_storage == before_food + 1 and state.crop_stock.count("beans") == 0
		and state.king_storage == 1, "One private crop becomes one ration while the tribute remains in the treasury.")
	print("DIRECTION_FIRST_RATION day=", state.current_day, " private=", state.private_harvest_total,
		" tribute=", state.king_storage, " grain=", before_food, "->", state.food_storage)
	await _click(panel.get_node("CloseButton").get_global_rect().get_center())
	_expect(not trade.visible and "晋升" in ui.hud.guide.heading.text,
		"The optional trade action clears with an empty stock, leaving promotion as the main direction.")
	await _night()
	_expect(state.food_storage == before_food and state.night_rations.last.served == 1,
		"The next night's ordinary settlement uses one ration.")

func _finish() -> void:
	tree.unload_current_scene()
	tree.root.get_node("AudioManager").bgm_player.stop()
	await tree.create_timer(0.18).timeout
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)

func _check_handover() -> void:
	_expect(ui.hud.arrival.visible and ui.hud.handover_button.visible and not tree.paused,
		"New Game shows the handover notice and leaves the first field playable.")
	var before: float = state.day_progress
	await _click(ui.hud.handover_button.get_global_rect().get_center())
	var handover: Control = ui.handover
	_expect(handover.modal.visible and tree.paused and state.day_progress - before < 0.01
		and handover.sketch.get_child_count() == 9 and handover.sketch.get_child(4).get_child(0).text == "公田",
		"The letter pauses daylight and places the public plot at the center.")
	await _capture("01b-handover-note")
	await _click(handover.find_keeper.get_global_rect().get_center())
	_expect(not handover.modal.visible and not tree.paused and directions.tracked_neighbor == KEEPER,
		"The letter can guide to the keeper before any work on the field.")
	await _capture("01c-meet-keeper-before-farming")
	await _click(ui.hud.cancel_directions.get_global_rect().get_center())
	_expect(directions.tracked_neighbor.is_empty() and directions.mark == directions.Mark.PLOT and state.active_crops.is_empty(),
		"Cancelling returns to the untouched public plot.")
	print("DIRECTION_HANDOVER day=", state.current_day, " keeper=true tiles=", handover.sketch.get_child_count())

func _continue_old_handover() -> void:
	await _click(tree.current_scene.continue_button.get_global_rect().get_center())
	await _use_estate()
	_expect(state.current_day == 1 and state.active_crops[PUBLIC].watered and ui.hud.handover_button.visible
		and not ui.hud.arrival.visible, "An old day-one save keeps its plot and can read the note without replaying arrival.")
	await _click(ui.hud.handover_button.get_global_rect().get_center())
	_expect(ui.handover.modal.visible and tree.paused, "The handover opens from an old save.")
	await _key(KEY_ESCAPE)
	_expect(not ui.handover.modal.visible and not tree.paused, "Esc returns to the saved first day.")
	var dialog := await _meet(KEEPER)
	if _expect(dialog != null and dialog.controls_hint.text == "E 继续", "The keeper's new dialogue controls are available in the old save."):
		await _key(KEY_E)
		_expect(not is_instance_valid(dialog) and not world.player.conversation_open,
			"The interaction key finishes the old save's conversation.")
	print("DIRECTION_LEGACY day=", state.current_day, " watered=", state.active_crops[PUBLIC].watered)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the directions replay's save directory."):
		await _finish()
		return
	capture_dir = OS.get_environment("FIEFDOM_DIRECTION_CAPTURES")
	tree.root.notify_mouse_entered()
	state = tree.root.get_node("Global")
	tree.change_scene_to_file("res://scenes/Title.tscn")
	await tree.scene_changed
	await tree.process_frame
	if legacy:
		await _continue_old_handover()
		await _finish()
		return
	await _click(tree.current_scene.new_button.get_global_rect().get_center())
	await _use_estate()
	var spawn: Vector2 = world.player.global_position
	_expect(directions.visible and directions.mark == directions.Mark.PLOT and directions.caption.text == "公田"
		and "WASD" in ui.hud.guide.text and not ui.hud.tribute_button.visible,
		"A new estate labels the public plot and explains movement before showing the larger tribute goal.")
	_expect(directions.plaque.position.y > directions.outline.end.y + directions.outline.size.y - 2.0,
		"The first caption leaves the adjacent private plot visible.")
	await _capture("01-first-public-plot")
	await _check_handover()
	var initial_outline: Vector2 = directions.outline.size
	await _scroll(MOUSE_BUTTON_WHEEL_UP)
	_expect(directions.mark == directions.Mark.PLOT and directions.outline.size.x > initial_outline.x
		and directions.outline.has_point(_point_on_field()), "The cue stays attached to the same plot at the close zoom.")
	await _scroll(MOUSE_BUTTON_WHEEL_DOWN)
	await Campaign.walk_to(tree, world.player, Vector2(spawn.x, 340))
	_expect(directions.mark == directions.Mark.EDGE and directions.edge_direction.y < -0.6
		and directions.plaque.position.y < 110.0 and tree.root.get_visible_rect().encloses(directions.plaque),
		"Walking south beyond the field gives a northward cue by the top of the screen.")
	await _capture("02-find-the-plot-from-the-pavilion")
	await Campaign.walk_to(tree, world.player, spawn)
	await _click(_point_on_field())
	await _click(ui.hud.seed_buttons["rice"].get_global_rect().get_center())
	_expect(directions.mark == directions.Mark.BUTTON and "先按 1" in ui.hud.guide.text, "Selecting dry rice points to the viable millet seed.")
	await _capture("03-select-a-dryland-seed")
	await _key(KEY_1)
	await _click(_point_on_field())
	_expect(state.active_crops.has(PUBLIC) and state.active_crops[PUBLIC]["id"] == "millet", "The map cue does not intercept clicks.")
	await _click(_point_on_field())
	_expect(directions.mark == directions.Mark.BUTTON and "水已到田" in ui.hud.guide.text, "A watered crop points to the sleep button.")
	await _capture("04-sleep-after-watering")
	var gamepad = load("res://tests/GamepadReplay.gd").new()
	gamepad.tree = tree
	gamepad.pad = tree.root.get_node("GamepadInput")
	var first_keeper_dialog := await _visit_while_crop_grows(KEEPER)
	if not await _read_handover_dialogue(first_keeper_dialog, gamepad):
		await _finish()
		return
	await _save_and_continue()
	_expect(state.current_day == 1 and state.active_crops[PUBLIC]["watered"] and directions.mark == directions.Mark.BUTTON
		and directions.tracked_neighbor.is_empty() and ui.hud.opening_action.visible and ui.hud.handover_button.visible
		and not ui.hud.arrival.visible, "Continue keeps the watered plot, bedtime cue and optional visit.")
	await _night()

	if world.is_crop_dry(PUBLIC):
		await _click(_point_on_field())
	await _capture("04c-day-two-visitor")
	var road_dialog := await _visit_while_crop_grows(ROAD_KEEPER)
	if not await _greet_first_visitor(road_dialog, gamepad):
		await _finish()
		return
	var journal := await _journal()
	if _expect(journal.roster.has_node(ROAD_KEEPER) and journal.roster.get_node(ROAD_KEEPER).visible, "The visit is recorded in the journal."):
		await _click(journal.roster.get_node(ROAD_KEEPER).get_global_rect().get_center())
		_expect(journal.locate_button.visible and not directions.visible, "A present visitor can be located from the open journal.")
		await _click(journal.locate_button.get_global_rect().get_center())
		_expect(directions.tracked_neighbor == ROAD_KEEPER and directions.visible, "Locating a visitor closes the journal and places the route.")
	await Campaign.walk_to(tree, world.player, spawn)
	if world.field_action(PUBLIC) == world.FieldAction.WATER:
		await _click(_point_on_field())
	await _night()
	_expect(state.current_day == 3 and directions.tracked_neighbor.is_empty() and not ui.hud.cancel_directions.visible,
		"A departing visitor clears the stale route.")
	journal = await _journal()
	await _click(journal.roster.get_node(ROAD_KEEPER).get_global_rect().get_center())
	_expect(not journal.locate_button.visible, "The journal offers no destination for someone away today.")
	await _click(ui.panel_manager.management_panel_instance.get_node("CloseButton").get_global_rect().get_center())

	await _click(_point_on_field())
	_expect(state.king_storage == 1 and directions.tracked_neighbor.is_empty() and ui.hud.tribute_button.visible
		and ui.hud.guide.heading.text == "第一茬私田" and directions.mark == directions.Mark.PLOT and directions.caption.text == "私田"
		and not ui.hud.handover_button.visible and ui.hud.opening_action.text == "找渠伯谈轮作",
		"The treasury receives the public harvest while the next cue stays on the private plot.")
	await _capture("05-first-tribute-and-keeper")
	await _click(ui.hud.opening_action.get_global_rect().get_center())
	_expect(directions.tracked_neighbor == KEEPER and directions.mark == directions.Mark.NEIGHBOR,
		"Choosing the rotation invitation directs the player to the keeper.")
	await _click(ui.hud.cancel_directions.get_global_rect().get_center())
	_expect(directions.tracked_neighbor.is_empty() and directions.mark == directions.Mark.PLOT and directions.caption.text == "私田",
		"Cancelling the optional visit returns the map to the private plot cue.")
	journal = await _journal()
	await _click(journal.roster.get_node(KEEPER).get_global_rect().get_center())
	_expect(journal.locate_button.visible, "The present keeper can be located again.")
	await _capture("06-locate-a-neighbor")
	await _click(journal.locate_button.get_global_rect().get_center())
	var keeper_dialog := await _meet(KEEPER)
	if _expect(keeper_dialog != null and directions.tracked_neighbor.is_empty(), "Reaching the keeper and pressing E clears the route."):
		await _capture("07-agree-to-rotate-crops")
		await _click(_button(keeper_dialog, "约定试一回轮作").get_global_rect().get_center())
	_expect(state.field_rotation.promise_day == 3, "The existing rotation story starts directly from the first harvest.")
	print("DIRECTION_OPENING day=", state.current_day, " tribute=", state.king_storage, " rotation=", state.field_rotation.promise_day)
	if not failed:
		await _private_crop_and_grain(spawn)
	await _finish()
