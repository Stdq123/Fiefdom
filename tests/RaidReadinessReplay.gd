extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const PUBLIC := Vector2i(5, 5)
const PRIVATE := Vector2i(6, 5)

var tree: SceneTree
var state: Node
var world: Node2D
var ui: CanvasLayer
var capture_dir := ""
var failed := false

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		failed = true
	return condition

func _click(point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var pointer := InputEventMouseMotion.new()
	pointer.position = point
	pointer.global_position = point
	tree.root.push_input(pointer, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = point
		event.global_position = point
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame

func _button(button: Button) -> void:
	await tree.process_frame
	var bounds := button.get_global_rect()
	if _expect(button.is_visible_in_tree() and not button.disabled and tree.root.get_visible_rect().encloses(bounds),
		"Use the visible control " + button.text):
		await _click(bounds.get_center())

func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)
	print("RAID_READY_FRAME ", name, " window=", tree.root.size, " image=", image.get_size())

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")

func _plot(cell: Vector2i) -> void:
	var tiles: TileMapLayer = world.tile_map
	await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))

func _tend_field(cell: Vector2i) -> void:
	if world.is_crop_ripe(cell):
		await _plot(cell)
	if not state.tilled_cells.has(cell):
		await _plot(cell)
	if not state.active_crops.has(cell):
		await _plot(cell)
	if world.is_crop_dry(cell):
		await _plot(cell)

func _sleep() -> void:
	await _button(ui.sleep_button)
	await tree.create_timer(1.16).timeout

func _reach_raid_eve() -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	_estate()
	var alert: Button = ui.hud.get_node_or_null("%RaidAlert")
	_expect(alert == null or not alert.visible, "The first morning shows the farm instructions without an enemy alert.")
	for day in range(1, state.balance.raid_first_day):
		if not _expect(state.current_day == day and state.outcome == state.Outcome.RUNNING, "Reach raid eve by normal overnights."):
			return false
		if day == state.balance.raid_first_day - 1:
			break
		await _tend_field(PUBLIC)
		await _tend_field(PRIVATE)
		await _sleep()
	return _expect(state.king_storage == 3 and state.player_inventory == 3 and state.raids_defeated == 0,
		"Earn public and private harvest through the first week of a fresh save.")

func _night_panel() -> Control:
	await _button(ui.hud.rations_button)
	return ui.get_node("Control/NightRationsPanel")

func _agree_rotation() -> bool:
	var keeper: Node2D = world.neighbor_actor("渠伯")
	await Campaign.walk_to(tree, world.player, keeper.global_position + Vector2(0, 15))
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_E
		event.keycode = KEY_E
		event.pressed = down
		tree.root.push_input(event, true)
		await tree.process_frame
	var dialog: Control = ui.get_node_or_null("Control/DialoguePanel")
	if not _expect(dialog != null and dialog.name_label.text == "渠伯", "Speak to Qu Bo on the eve of the raid."):
		return false
	for choice: Button in dialog.options_container.get_children():
		if choice.text == "约定试一回轮作":
			await _button(choice)
			break
	return _expect(state.field_rotation.promise_day == 8, "Agree to the rotation through the ordinary conversation.")

func _verify_baseline() -> void:
	var notice: Label = tree.current_scene.get_node("CampaignHUD").notice
	_expect("明日有敌袭" in notice.text, "The older package warns of the raid at daybreak.")
	if not await _agree_rotation():
		return
	var overwritten := "与渠伯约好轮作" in notice.text
	_expect(overwritten, "The rotation announcement replaces the warning during the same day.")
	await _capture("01-baseline-overwritten-warning")
	var panel := await _night_panel()
	_expect(panel.get_node_or_null("%RaidPlan") == null, "The previous night ledger has no raid note.")
	await _capture("02-baseline-night-ledger")
	await _button(panel.get_node("%Close"))
	await _sleep()
	_expect(state.current_day == 9 and state.raid_day == 9 and tree.get_nodes_in_group("estate_raiders").size() == 1,
		"Ordinary sleep starts the first raid when the old warning is no longer visible.")
	print("RAID_READY_BASELINE overwritten=", overwritten, " night_note=false next_raid=", state.raid_day)

func _verify_preparation(alert: Button) -> bool:
	if not _expect(alert.is_visible_in_tree() and "明日有敌袭" in alert.text, "The journal keeps the first raid forecast in view."):
		return false
	if not await _agree_rotation():
		return false
	var notice: Label = tree.current_scene.get_node("CampaignHUD").notice
	_expect("与渠伯约好轮作" in notice.text and alert.visible and "明日有敌袭" in alert.text,
		"Field dialogue and the raid forecast can be read at the same time.")
	await _capture("01-raid-eve")
	await _button(alert)
	var panel: Control = ui.get_node("Control/NightRationsPanel")
	var window := panel.get_node("Center/Window") as Control
	await tree.process_frame
	_expect(panel.raid_plan.is_visible_in_tree() and panel.raid_heading.text == "明日有敌袭"
		and "右键朝来敌射箭" in panel.raid_instructions.text and "过夜前可先收成熟作物" in panel.raid_instructions.text
		and "明早新熟" in panel.field_forecast.text and tree.root.get_visible_rect().encloses(window.get_global_rect()),
		"Preparation gives both farming and combat information in the visible night ledger.")
	await _capture("02-preparation")
	await _button(panel.get_node("%Close"))
	_expect(state.current_day == 8 and state.raid_day == 0 and alert.visible,
		"Reading and closing the preparation leaves day eight available for field work.")
	await _button(alert)
	panel = ui.get_node("Control/NightRationsPanel")
	await _button(panel.get_node("%Sleep"))
	await tree.create_timer(1.14).timeout
	return _expect(state.current_day == 9 and state.raid_day == 9 and alert.is_visible_in_tree()
		and "野狗来袭" in alert.text and "东路来敌 · 野狗" in ui.dawn_caption.text,
		"Confirming sleep presents the live threat at dawn.")

func _continue_at_raid() -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	_estate()
	return _expect(state.current_day == 9 and state.raid_day == 9 and ui.hud.raid_alert.is_visible_in_tree()
		and tree.get_nodes_in_group("estate_raiders").size() == 1, "The morning save restores the raid and its alert.")

func _defend() -> void:
	var raider := tree.get_first_node_in_group("estate_raiders") as Node2D
	await _button(ui.hud.raid_alert)
	var destination: Dictionary = ui.directions.destination()
	_expect(destination.get("title") == "野狗" and destination.get("point") == world.to_local(raider.global_position)
		and ui.hud.cancel_directions.visible, "Locate the live enemy through the journal action.")
	await _capture("03-marked-raider")
	var old_point: Vector2 = destination.point
	await tree.create_timer(0.30).timeout
	destination = ui.directions.destination()
	_expect(destination.point != old_point and destination.point == world.to_local(raider.global_position),
		"The waypoint follows the enemy's movement.")
	var art := raider.get_node("Sprite2D") as Sprite2D
	for shot in 4:
		if state.raid_day == 0:
			break
		var ear := Vector2(-6.5 if art.flip_h else 6.5, -6.5)
		var point := art.get_global_transform_with_canvas() * ear
		await _click(point, MOUSE_BUTTON_RIGHT)
		await tree.create_timer(0.40).timeout
	_expect(state.raids_defeated == 1 and state.raid_day == 0 and state.last_defense.get("losses") == 0
		and state.king_storage == 3 and state.player_inventory == 3 and world.is_crop_ripe(PUBLIC) and world.is_crop_ripe(PRIVATE),
		"Aiming at the moving dog's ear with right-click protects both harvests and records the defense.")
	_expect(not ui.hud.raid_alert.visible and not ui.hud.cancel_directions.visible and ui.directions.destination().is_empty(),
		"The alert and live marker clear after the fight.")
	await _capture("04-defense-result")
	print("RAID_READY_DEFENSE day=", state.current_day, " defeated=", state.raids_defeated, " losses=", state.last_defense.get("losses"),
		" tribute=", state.king_storage, " private=", state.player_inventory)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated first raid profile."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_RAID_CAPTURES")
	tree.root.notify_mouse_entered()
	seed(911)
	if await _reach_raid_eve():
		await tree.create_timer(3.55).timeout
		var alert: Button = ui.hud.get_node_or_null("%RaidAlert")
		if alert == null:
			await _verify_baseline()
		elif await _verify_preparation(alert) and await _continue_at_raid():
			await _defend()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
