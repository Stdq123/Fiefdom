extends RefCounted

const Campaign := preload("res://tests/CampaignReplay.gd")
const FIRST := Vector2i(5, 5)
const SECOND := Vector2i(12, 5)
const PRIVATE := Vector2i(6, 5)
const SNAPSHOT := {
	"current_day": 53, "current_rank": 3, "money": 87, "food_storage": 28,
	"king_storage": 12, "private_harvest_total": 14, "player_inventory": 6, "raids_defeated": 1,
	"retainers": [
		{"name": "季青", "school": 1, "loyalty": 40, "duty": 2},
		{"name": "渠伯", "school": 4, "loyalty": 76},
		{"name": "石墨", "school": 2, "loyalty": 89},
	],
	"well_fields": [
		{"center_pos": "5,5", "is_unlocked": true, "reclamation_progress": 4},
		{"center_pos": "12,5", "is_unlocked": true, "reclamation_progress": 4},
	],
	"active_crops": {
		"5,5": {"id": "mulberry", "age": 3, "growth_nights": 3},
		"12,5": {"id": "millet", "age": 2, "growth_nights": 2},
		"6,5": {"id": "wheat", "age": 2, "growth_nights": 2},
		"4,5": {"id": "beans", "age": 0, "growth_nights": 2},
	},
	"fertile_cells": ["6,5"],
}

var tree: SceneTree
var state: Node
var world: Node
var ui: Node
var failures := 0
var capture_dir := ""

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failures += 1
		push_error(detail)
	return condition

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

func _button(button: Button) -> void:
	await _click(button.get_global_rect().get_center())

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		tree.root.push_input(event, true)
	await tree.process_frame
	await tree.process_frame

func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var picture := tree.root.get_texture().get_image()
	_expect(picture.save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)
	print("COUNCIL_FRAME ", name, " ", picture.get_size())

func _title() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame

func _estate() -> void:
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	for retainer in world.retainer_instances.values():
		retainer.set_physics_process(false)
	await tree.process_frame
	await tree.process_frame

func _panel() -> Control:
	return ui.get_node_or_null("Control/EventPanel") as Control

func _card(panel: Control, choice: int) -> Dictionary:
	for entry: Dictionary in panel.current_event_data["choices"]:
		if entry["choice_type"] == choice:
			return entry
	return {}

func _sleep() -> void:
	await _button(ui.sleep_button)
	await tree.create_timer(1.1).timeout

func _stores() -> Vector4i:
	return Vector4i(state.king_storage, state.player_inventory, state.money, state.silk_workshop.leaves)

func _harvest() -> void:
	var tiles: TileMapLayer = world.tile_map
	for cell in [FIRST, SECOND, PRIVATE]:
		await _click(tiles.get_global_transform_with_canvas() * tiles.map_to_local(cell))

func _layout(panel: Control, count: int) -> void:
	var panel_rect: Rect2 = panel.sheet.get_global_rect()
	_expect(tree.root.get_visible_rect().encloses(panel_rect) and panel_rect.encloses(panel.confirm_button.get_global_rect()),
		"The sheet and the final choice button fit inside the viewport.")
	var right := panel_rect.position.x
	for card: PanelContainer in panel.cards.values():
		var bounds := card.get_global_rect()
		_expect(panel_rect.encloses(bounds) and bounds.position.x >= right, "The route cards fit without overlapping.")
		right = bounds.end.x
	_expect(panel.cards.size() == count, "Exactly the available choices appear.")
	print("COUNCIL_LAYOUT window=", tree.root.size, " sheet=", panel.sheet.size, " cards=", count)

func _check_appointment() -> bool:
	var envoy: Node2D = world.tax_envoy
	if not _expect(state.tax_council_waiting() and envoy.visible and not tree.paused and _panel() == null,
		"An eligible old estate shows the envoy in the world and keeps play available."):
		return false
	_expect(ui.hud.opening_action.visible and "去见召简" in ui.hud.opening_action.text,
		"The journal points to the appointment.")
	await _key(KEY_M)
	var map: Control = ui.estate_map
	await _button(map.tabs.get_node("People"))
	var envoy_row: Button
	for row: Button in map.row_buttons:
		if map.row_buttons[row].title == state.TAX_ENVOY:
			envoy_row = row
			break
	if not _expect(envoy_row != null, "The person index lists the envoy at his real position."):
		return false
	await _button(envoy_row)
	_expect(map.target.title == state.TAX_ENVOY and map.target.point == world.to_local(envoy.global_position),
		"The map tracks the real envoy.")
	await _capture("00-envoy-on-map")
	await _key(KEY_ESCAPE)
	var day: int = state.current_day
	await _button(ui.sleep_button)
	_expect(state.current_day == day and not world.player.resting and ui.directions.tracked_neighbor == state.TAX_ENVOY,
		"Trying to sleep guides to the appointment before the date can change.")
	print("COUNCIL_APPOINTMENT day=", day, " envoy_at=", envoy.position, " paused=", tree.paused)
	return true

func _initial_choice() -> bool:
	if not await _check_appointment():
		return false
	var panel := await Campaign.meet_tax_envoy(tree)
	if not _expect(panel != null and tree.paused and panel.option_buttons.size() == 3,
		"Walk to the envoy and press E to open the ordinary three-choice council."):
		return false
	var notice: Label = tree.current_scene.get_node("CampaignHUD").notice
	_expect(not notice.visible, "World notices stay behind the open council.")
	var reform: int = state.TaxReformChoice.REFORMED
	var tradition: int = state.TaxReformChoice.TRADITIONAL
	var delayed: int = state.TaxReformChoice.DELAYED
	_layout(panel, 3)
	var reform_card := _card(panel, reform)
	var traditional_card := _card(panel, tradition)
	var delay_card := _card(panel, delayed)
	print("COUNCIL_CARD ", JSON.stringify(reform_card))
	_expect("公田 2 格" in panel.ledger.text and "粮仓 28 份" in panel.ledger.text and "铜钱 87" in panel.ledger.text,
		"The opening ledger uses the loaded estate's current resources.")
	_expect("收齐已熟 3 格" in reform_card.harvest and "国库 +0 · 私仓 +4" in reform_card.harvest
		and "铜钱 +28 · 桑叶 +4" in reform_card.harvest and "20%" in reform_card.levy
		and "季青将离开" in reform_card.household and "每夜用粮 2 份" in reform_card.household
		and "现有铜钱 87/180" in reform_card.detail,
		"The reform card forecasts this harvest, the leaving teacher, and the configured targets.")
	_expect("国库 +2 · 私仓 +3" in traditional_card.harvest and "铜钱 +24" in traditional_card.harvest
		and "每夜用粮 4 份" in traditional_card.household and "新增公田纳贡 0/6" in traditional_card.detail,
		"The traditional card reflects public tribute and the agrarian and rotation yields.")
	_expect("第 55 天首付 · 尚差 13 铜钱" in delay_card.detail and "第 77 天到期 · 共需 1200 铜钱" in delay_card.detail,
		"Research shows the actual first due date, shortfall, term, and total cost.")
	await _capture("01-three-options")
	var before := _stores()
	_expect(panel.confirm_button.disabled, "The final decision starts unavailable.")
	await _key(KEY_ENTER)
	await _key(KEY_ENTER)
	_expect(state.tax_reform_choice == state.TaxReformChoice.NONE and tree.paused
		and panel.selected_choice == reform and not panel.confirm_button.disabled,
		"Enter on the focused option previews it, even when pressed twice.")
	await _capture("02-reform-selected")
	await _button(panel.option_buttons[tradition])
	await _key(KEY_ESCAPE)
	_expect(panel.confirm_button.disabled and panel.selected_choice == state.TaxReformChoice.NONE
		and _stores() == before and state.retainers.size() == 3 and state.fertile_cells.has(PRIVATE)
		and state.is_public_plot(FIRST) and tree.paused, "Switching and clearing a preview leaves all game state intact.")
	await _button(panel.leave_button)
	if not _expect(_panel() == null and not tree.paused and notice.visible and state.tax_council_waiting() and _stores() == before,
		"Leaving the council returns to the court with the same appointment and resources."):
		return false
	await _capture("02a-return-to-court")
	if not _expect(state.save_game() == OK, "Save the unresolved appointment."):
		return false
	var pending: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.manual_save_path()))
	_expect(pending.get("tax_council_invited") == true, "The save contains the unresolved appointment.")
	await _title()
	await _button(tree.current_scene.continue_button)
	await _estate()
	panel = await Campaign.meet_tax_envoy(tree)
	if not _expect(panel != null and panel.confirm_button.disabled, "Continue keeps the envoy at the court with fresh previews."):
		return false
	await _button(panel.option_buttons[reform])
	await _button(panel.confirm_button)
	if not _expect(state.tax_reform_choice == reform and not tree.paused and state.retainer_food_cost() == 2
		and not state.is_public_plot(FIRST) and _stores() == before, "Confirm applies the reform exactly once."):
		return false
	var saved: Dictionary = state.latest_saved_game()
	_expect(saved.source == "初税亩自动存档" and saved.day == 53, "The actual choice writes the council checkpoint.")
	await _title()
	tree.current_scene.continue_button.pressed.emit()
	await tree.scene_changed
	await _estate()
	_expect(state.tax_reform_choice == reform and state.retainer_food_cost() == 2 and _panel() == null and not world.tax_envoy.visible,
		"The selected scheme and departing retainer persist after Continue.")
	await _harvest()
	_expect(_stores() - before == Vector4i(0, 4, 28, 4), "Harvesting under reform matches all four preview totals.")
	print("COUNCIL_REFORM harvest=", _stores() - before, " night_food=", state.retainer_food_cost())
	return true

func _research_and_tradition() -> void:
	await _title()
	var case_data := SNAPSHOT.duplicate(true)
	case_data["current_day"] = 48
	case_data["active_crops"]["6,5"]["age"] = 1
	case_data["active_crops"]["6,5"]["watered"] = true
	var path := "user://council-dawn-fixture.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(case_data))
	file.close()
	if not _expect(state.load_game(path) == OK, "Load the council-eve fixture."):
		return
	await tree.scene_changed
	await _estate()
	_expect(_panel() == null and not world.tax_envoy.visible, "The year requirement still applies before the third year.")
	await _sleep()
	var envoy: Node2D = world.tax_envoy
	if not _expect(_panel() == null and not tree.paused and state.current_day == 49
		and envoy.visible and envoy.position.x > envoy.waiting_place.x, "The envoy arrives along the road on the first eligible morning."):
		return
	await _capture("02b-envoy-arriving")
	var panel := await Campaign.meet_tax_envoy(tree)
	if not _expect(panel != null and tree.paused, "The ordinary council is available at the court."):
		return
	var delayed: int = state.TaxReformChoice.DELAYED
	var tradition: int = state.TaxReformChoice.TRADITIONAL
	var delay_card := _card(panel, delayed)
	_expect("收齐已熟 3 格" in delay_card.harvest and "第 51 天首付" in delay_card.detail,
		"The preview includes the private crop that ripened in the same dawn.")
	await _button(panel.option_buttons[delayed])
	await _button(panel.confirm_button)
	_expect(state.tax_reform_choice == delayed and state.money == 87, "Confirm research and pay at the scheduled date.")
	await _sleep()
	await _sleep()
	_expect(_panel() == null and state.tax_council_waiting() and world.tax_envoy.visible,
		"The unpaid fee brings the envoy back without opening a modal.")
	panel = await Campaign.meet_tax_envoy(tree)
	if not _expect(panel != null and tree.paused and state.current_day == 51 and state.research_choice_pending,
		"The first unpaid fee reopens the mandatory decision."):
		return
	_layout(panel, 2)
	_expect("还差 13 铜钱" in panel.text_label.text and not panel.option_buttons.has(delayed),
		"The final council identifies the actual shortfall and offers the two final choices.")
	print("COUNCIL_RESEARCH day=", state.current_day, " ", panel.text_label.text)
	await _capture("03-final-research-choice")
	var before := _stores()
	await _button(panel.option_buttons[tradition])
	await _button(panel.confirm_button)
	var teacher: RetainerData = state.retainers[0]
	_expect(state.tax_reform_choice == tradition and not tree.paused and state.zhou_li_score == "上上"
		and teacher.loyalty == 70.0 and state.retainer_food_cost() == 4, "Confirm the traditional route with its ordinary loyalty changes.")
	await tree.create_timer(1.55).timeout
	_expect(not envoy.visible and not envoy.is_in_group("interactable"), "The envoy walks out after the decision.")
	await _harvest()
	_expect(_stores() - before == Vector4i(2, 3, 24, 0), "Harvesting under tradition matches the preview totals.")
	print("COUNCIL_TRADITION harvest=", _stores() - before, " night_food=", state.retainer_food_cost())

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the council replay's profile."):
		tree.quit(1)
		return
	seed(1979)
	if tree.root.size.x < 900:
		tree.root.size = Vector2i(1280, 720)
	tree.root.notify_mouse_entered()
	capture_dir = OS.get_environment("FIEFDOM_COUNCIL_CAPTURES")
	state = tree.root.get_node("Global")
	state.balance.raid_first_day = 10000
	var file := FileAccess.open(state.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(SNAPSHOT))
	file.close()
	await _title()
	tree.current_scene.continue_button.pressed.emit()
	await tree.scene_changed
	await _estate()
	if await _initial_choice():
		await _research_and_tradition()
	tree.paused = false
	tree.unload_current_scene()
	for stream in tree.root.get_node("AudioManager").get_children():
		if stream is AudioStreamPlayer:
			stream.stop()
	await tree.process_frame
	if failures == 0:
		print("SCENARIO_OK")
	tree.quit(1 if failures else 0)
