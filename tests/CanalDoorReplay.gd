extends "res://tests/CanalFlowReplay.gd"

const HALL_DITCH := Vector2i(-2, 0)
const SHED_DITCH := Vector2i(-2, 5)
const WEST_TURN := Vector2i(-2, 4)
const EAST_TURN := Vector2i(2, 5)
const NORTH_INLET := Vector2i(-8, -3)
const NORTH_RICE := Vector2i(-8, -4)
const PUBLIC := Vector2i(5, 5)
const PRIVATE := Vector2i(6, 5)

var legacy := false

func _seed_estate() -> void:
	var rice := {"id": "rice", "age": 0, "growth_nights": 3, "requires_channel": true}
	var millet := {"id": "millet", "age": 2, "growth_nights": 2}
	var save := FileAccess.open(state.SAVE_PATH, FileAccess.WRITE)
	save.store_string(JSON.stringify({
		"save_version": 2, "current_day": 13, "current_rank": state.Rank.ZHONG_SHI,
		"money": 420, "food_storage": 72, "king_storage": 12, "reputation": 100,
		"well_fields": [
			{"center_pos": "5,5", "is_unlocked": true, "reclamation_progress": 4},
			{"center_pos": "-8,-5", "is_unlocked": true, "reclamation_progress": 4},
		],
		"tech_unlocked": {"irrigation": true}, "first_channel_growth_day": 11, "channel_survey_day": 12,
		"silk_workshop": {"built": true}, "tilled_cells": ["-8,-4", "5,5", "6,5"],
		"active_crops": {"-8,-4": rice, "5,5": millet, "6,5": millet},
	}))
	save.close()

func _continue_estate() -> bool:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	if not _expect(tree.current_scene.name == "Main", "Continue the test estate through the title."):
		return false
	await _estate()
	return true

func _look_at_doors() -> void:
	await Campaign.walk_to(tree, world.player, Vector2(23, 102))
	await tree.create_timer(0.32).timeout

func _doors_visible() -> bool:
	return world.get_node("HallRest").visible and world.get_node("SilkShed").visible

func _survey_from(cell: Vector2i) -> void:
	await _button(ui.hud.survey_button)
	await _click(_point(cell))
	_expect(world.irrigation_overlay.survey_start == cell, "Anchor a canal survey on the connected ditch.")

func _save_at_settings() -> void:
	await _button(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	_expect(settings.save_status.text == "游戏已保存", "Save the estate through the Settings menu.")

func _old_excavation() -> void:
	await _look_at_doors()
	_expect(_doors_visible(), "Both doorways are present before digging.")
	await _capture("01-before-old-ditch")
	await _button(ui.channel_button)
	await _survey_from(state.irrigation.source_cell)
	await _click(_point(WEST_TURN))
	await _survey_from(WEST_TURN)
	await _key(KEY_R)
	await _click(_point(NORTH_INLET))
	await _key(KEY_ESCAPE)
	_expect(state.irrigation.channels.has(HALL_DITCH) and state.irrigation.channels.has(SHED_DITCH)
		and state.irrigation.supplies(NORTH_RICE), "The previous release accepts a connected ditch under both buildings.")
	_expect(not world.get_node("HallRest").visible and not world.get_node("SilkShed").visible,
		"The two entrances disappear after ordinary excavation.")
	await _capture("02-old-doors-missing")
	await _save_at_settings()
	print("CANAL_DOOR_BASELINE hall=", world.get_node("HallRest").visible, " shed=", world.get_node("SilkShed").visible,
		" wet_rice=", state.irrigation.supplies(NORTH_RICE), " channels=", state.irrigation.channels.size(), " save=", state.manual_save_path())

func _doorway(action: StringName, destination: int) -> bool:
	var travel := tree.root.get_node("MapTravel")
	Input.action_press(action)
	for frame in 35:
		await tree.physics_frame
		if travel.active:
			break
	Input.action_release(action)
	if not _expect(travel.active, "The threshold to room %d starts a transition from %s." % [destination, world.player.global_position]):
		return false
	await travel.finished
	await tree.process_frame
	return _expect(state.estate_room == destination, "Walk through the actual doorway.")

func _visit_room(facade_name: String, interior_name: String, destination: int, frame_name: String) -> bool:
	var facade: Node2D = world.get_node(facade_name)
	var interior: Node2D = world.get_node(interior_name)
	await Campaign.walk_to(tree, world.player, facade.get_node("Yard").global_position)
	if not await _doorway(&"ui_up", destination):
		return false
	await _capture(frame_name)
	await Campaign.walk_to(tree, world.player, interior.to_global(Vector2(0, 40)))
	return await _doorway(&"ui_down", state.EstateRoom.OUTDOORS)

func _use_both_rooms() -> void:
	await Campaign.walk_to(tree, world.player, Vector2(23, 61))
	if await _visit_room("HallRest", "HallInterior", state.EstateRoom.HALL, "05-enter-hall"):
		await Campaign.walk_to(tree, world.player, Vector2(45, 135))
		if await _visit_room("SilkShed", "SilkInterior", state.EstateRoom.SILK_SHED, "06-enter-shed"):
			await Campaign.walk_to(tree, world.player, Vector2(45, 135))

func _grow_and_harvest() -> void:
	await _look_at_doors()
	var age: int = state.active_crops[NORTH_RICE].age
	await _button(ui.sleep_button)
	await tree.create_timer(1.12).timeout
	_expect(state.active_crops[NORTH_RICE].age == age + 1, "The downstream rice advances normally over one night.")
	var tribute: int = state.king_storage
	var private_stock: int = state.player_inventory
	var money: int = state.money
	await _click(_point(PUBLIC))
	await _click(_point(PRIVATE))
	_expect(state.king_storage == tribute + 1 and state.player_inventory == private_stock + 1
		and state.money == money + ItemManager.get_crop("millet").sell_price,
		"Normal field clicks still credit public tribute and the private harvest.")
	print("CANAL_DOOR_CROPS day=", state.current_day, " rice_age=", state.active_crops[NORTH_RICE].age,
		" tribute=", state.king_storage - tribute, " private=", state.player_inventory - private_stock)

func _new_excavation() -> void:
	await _look_at_doors()
	await _button(ui.channel_button)
	var overlay: Node2D = world.irrigation_overlay
	var money: int = state.money
	for cell in [HALL_DITCH, SHED_DITCH]:
		await _pointer(_point(cell))
		_expect("屋基" in ui.hud.canal_preview.text and overlay.blocked_cell == cell,
			"The single-ditch preview identifies the foundation.")
		await _capture("01-hall-foundation" if cell == HALL_DITCH else "02-shed-foundation")
		await _click(_point(cell))
		_expect(state.money == money and not state.irrigation.channels.has(cell) and _doors_visible(),
			"Reject a ditch on the building without charging or removing access.")
	await _click(_point(EAST_TURN))
	await _survey_from(EAST_TURN)
	await _pointer(_point(NORTH_INLET))
	_expect("屋基" in ui.hud.canal_preview.text, "The first survey bend crosses the shed foundation.")
	await _click(_point(NORTH_INLET))
	_expect(overlay.survey_start == EAST_TURN and state.money == money - state.channel_cost()
		and state.irrigation.channels.size() == 1, "An obstructed line keeps its stake and pays for no extra cells.")
	await _capture("03-survey-blocked")
	await _key(KEY_R)
	await _pointer(_point(NORTH_INLET))
	_expect(overlay.preview_site == state.ChannelSite.AVAILABLE, "Turning the line clears the foundation.")
	await _click(_point(NORTH_INLET))
	await _key(KEY_ESCAPE)
	_expect(_doors_visible() and state.irrigation.supplies(NORTH_RICE) and overlay.footbridges.size() == 1,
		"The open bend waters the rice and leaves a road footbridge and both entrances.")
	await _capture("04-road-and-open-doors")
	print("CANAL_DOOR_BEND wet_rice=", state.irrigation.supplies(NORTH_RICE), " crossings=", overlay.footbridges.size())
	await _use_both_rooms()
	await _grow_and_harvest()

func _legacy_excavation() -> void:
	await _look_at_doors()
	_expect(_doors_visible() and state.irrigation.channels.has(HALL_DITCH) and state.irrigation.channels.has(SHED_DITCH)
		and state.irrigation.supplies(NORTH_RICE), "Continue the actual prior save with its connected ditch and both restored doors.")
	await _capture("07-legacy-open-doors")
	await _button(ui.channel_button)
	await _pointer(_point(HALL_DITCH))
	_expect("暗渠" in ui.hud.canal_preview.text, "Dig mode makes the old covered section identifiable.")
	await _pointer(_point(HALL_DITCH), true)
	_expect(world.irrigation_overlay.affected_fields.get(NORTH_RICE) == false and "1 格稻暂停" in ui.hud.canal_preview.text,
		"Filling the old covered section still previews the downstream crop loss.")
	await _capture("08-legacy-culvert-preview")
	await _key(KEY_ESCAPE)
	await _use_both_rooms()
	await _grow_and_harvest()
	print("CANAL_DOOR_LEGACY hall=", world.get_node("HallRest").visible, " shed=", world.get_node("SilkShed").visible,
		" wet_rice=", state.irrigation.supplies(NORTH_RICE), " channels=", state.irrigation.channels.size())

func run_doors(game_tree: SceneTree, baseline := false, capture_path := "") -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the canal doorway replay."):
		tree.quit(1)
		return
	state = tree.root.get_node("Global")
	state.balance.raid_first_day = 10000
	captures = capture_path
	tree.root.notify_mouse_entered()
	if not legacy:
		_seed_estate()
	if await _continue_estate():
		if baseline:
			await _old_excavation()
		elif legacy:
			await _legacy_excavation()
		else:
			await _new_excavation()
	tree.unload_current_scene()
	await tree.process_frame
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
