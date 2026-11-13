extends "res://tests/CouncilPrepReplay.gd"

const RESERVED := Vector2i(4, 5)
const RIPE_MILLET := Vector2i(6, 5)
const SILK_FIXTURE := {
	"save_version": 2, "current_day": 40, "current_rank": Global.Rank.DA_FU,
	"reputation": 325, "money": 140, "food_storage": 30, "king_storage": 22, "private_harvest_total": 48,
	"player_stats": {"LITERACY": {"level": 1, "xp": 65, "max_xp": 100}},
	"retainers": [{"name": "弋戎", "school": RetainerData.School.MILITARY, "duty": RetainerData.Duty.GUARD, "loyalty": 90}],
	"well_fields": [
		{"center_pos": "5,5", "is_unlocked": true, "reclamation_progress": 4},
		{"center_pos": "9,5", "is_unlocked": true, "reclamation_progress": 4},
	],
	"active_crops": {
		"5,5": {"id": "mulberry", "age": 5, "growth_nights": 5},
		"6,5": {"id": "millet", "age": 2, "growth_nights": 2},
		"5,6": {"id": "wheat", "age": 0, "growth_nights": 3},
	},
	"tilled_cells": ["4,5", "5,5", "6,5", "5,6"],
	"field_seed_plans": {"4,5": "beans"},
}

var mulberry_cell: Vector2i

func _silk_from_ledger() -> Control:
	await _open_book()
	await _button(book.silk_button)
	var management: Control = ui.panel_manager.management_panel_instance
	_expect(not tree.paused and management.visible and management.tabs.get_current_tab_control() == management.silk_panel,
		"The preparation ledger opens the real silk tab and hands back control.")
	return management.silk_panel

func _plant() -> bool:
	await _open_book()
	_expect(book.silk_stock.text == "备绸 · 0 / 1 匹" and book.silk_button.text == "准备丝绸"
		and "还需 9 夜" in book.date_status.text, "The ledger introduces silk before the tax date.")
	await _snapshot("01-prepare-silk")
	await _button(book.silk_button)
	var management: Control = ui.panel_manager.management_panel_instance
	var silk: Control = management.silk_panel
	_expect(silk.study_button.visible and silk.buttons[SilkWorkshop.Action.BUILD].disabled,
		"The silk page offers study when the workshop still needs literacy.")
	await _button(silk.study_button)
	_expect(management.stats_container.is_visible_in_tree(), "The study shortcut opens the Six Arts page.")
	await _button(management.read_button)
	await _button(management.get_node("CloseButton"))
	silk = await _silk_from_ledger()
	var purse: int = state.money
	await _button(silk.buttons[SilkWorkshop.Action.BUILD])
	_expect(state.silk_workshop.built and state.money == purse - state.balance.silk_workshop_cost,
		"Study and the ordinary construction action open the workshop.")
	_expect("缺 4 片桑叶" in silk.mulberry_note.text and silk.mulberry_button.text == "标出私田",
		"A ripe public mulberry cannot supply the silk batch.")
	await _button(silk.mulberry_button)
	if not _expect(ui.directions.tracked_plot is Vector2i and state.field_route_status == Global.MulberryRoute.PLANT
		and world.current_seed_id == "mulberry", "Mark an empty plot and select mulberry seed."):
		return false
	mulberry_cell = ui.directions.tracked_plot
	_expect(mulberry_cell != RESERVED and not state.is_public_plot(mulberry_cell) and not state.active_crops.has(mulberry_cell),
		"The suggested plot avoids existing crops, seed plans and public land.")
	await _click_plot(mulberry_cell)
	_expect(state.tilled_cells.has(mulberry_cell) and ui.directions.tracked_plot == mulberry_cell,
		"The same guide stays on the plot after tilling.")
	await _save_route()
	if not _expect(state.field_route_status == Global.MulberryRoute.PLANT and ui.directions.tracked_plot == mulberry_cell
		and world.current_seed_id == "mulberry" and state.field_seed_plans.get(RESERVED) == "beans",
		"Continue restores the planting route, seed and other plans."):
		return false
	await _snapshot("02-planting-route-resumed")
	await _click_plot(mulberry_cell)
	return _expect(state.active_crops.get(mulberry_cell, {}).get("id") == "mulberry" and ui.directions.tracked_plot == null,
		"Sowing through normal input clears the completed planting route.")

func _collect_leaves() -> bool:
	var nights: int = state.active_crops[mulberry_cell].growth_nights
	for night in nights:
		if state.field_crop_is_dry(mulberry_cell):
			var silk := await _silk_from_ledger()
			_expect(silk.mulberry_button.text == "指路浇桑", "A dry mulberry gives a watering shortcut.")
			await _button(silk.mulberry_button)
			_expect(ui.directions.tracked_plot == mulberry_cell and state.field_route_status == Global.MulberryRoute.WATER,
				"The watering guide chooses the mulberry over unrelated dry crops.")
			await _click_plot(mulberry_cell)
			_expect(state.active_crops[mulberry_cell].watered and ui.directions.tracked_plot == null,
				"Watering completes this route.")
		await _sleep()
	var silk := await _silk_from_ledger()
	_expect(silk.mulberry_button.text == "指路收桑" and "可采" in silk.mulberry_note.text,
		"The same entry now points to the ripe leaves.")
	await _snapshot("03-harvest-mulberry")
	await _button(silk.mulberry_button)
	_expect(ui.directions.tracked_plot == mulberry_cell and state.field_route_status == Global.MulberryRoute.HARVEST,
		"Harvest directions skip the ripe public mulberry and private millet.")
	await _click_plot(mulberry_cell)
	print("COUNCIL_SILK_LEAVES day=", state.current_day, " tile=", mulberry_cell, " leaves=", state.silk_workshop.leaves)
	return _expect(state.silk_workshop.leaves == state.balance.mulberry_leaves_per_harvest and state.king_storage == 22
		and state.private_harvest_total == 49 and world.is_crop_ripe(PUBLIC) and world.is_crop_ripe(RIPE_MILLET)
		and ui.directions.tracked_plot == null, "Only the new private mulberry supplies leaves and stock.")

func _weave() -> bool:
	var silk := await _silk_from_ledger()
	await _button(silk.buttons[SilkWorkshop.Action.START_BATCH])
	await _key(KEY_ESCAPE)
	for night in state.balance.silk_batch_nights:
		await _sleep()
	silk = await _silk_from_ledger()
	await _button(silk.bulk_buttons[SilkWorkshop.Action.REEL])
	await _button(silk.buttons[SilkWorkshop.Action.WEAVE])
	await _key(KEY_ESCAPE)
	await _open_book()
	await _snapshot("04-prepared-bolt")
	await _button(book.close_button)
	print("COUNCIL_SILK_WOVEN day=", state.current_day, " bolts=", state.silk_workshop.bolts)
	return _expect(book.silk_stock.text == "备绸 · 1 / 1 匹" and state.silk_workshop.bolts == 1
		and state.silk_bolts_offered == 0 and not state.tax_council_waiting(), "A real bolt is ready before the envoy arrives.")

func _offer_after_council() -> void:
	for day in range(state.current_day, state.tax_council_start_day()):
		await _sleep()
	var decision := await Campaign.meet_tax_envoy(tree)
	if not _expect(decision != null and tree.paused, "Walk to the scheduled envoy."):
		return
	await _button(decision.option_buttons[state.TaxReformChoice.TRADITIONAL])
	await _button(decision.confirm_button)
	await _continue()
	await _button(ui.hud.route_progress)
	var row: PanelContainer = ui.route_goals.rows.get_child(1)
	_expect("手中已有 1 匹" in row.get_node("%GoalDetail").text and row.get_node("%GoalCount").text.begins_with("0 / 1"),
		"The goal recognizes the stored bolt and waits for the offering.")
	await _snapshot("05-silk-goal")
	await _button(row.get_node("%GoalAction"))
	var silk: Control = ui.panel_manager.management_panel_instance.silk_panel
	await _button(silk.buttons[SilkWorkshop.Action.OFFER])
	_expect(state.silk_workshop.bolts == 0 and state.silk_bolts_offered == 1 and state.route_objectives()[1].value == 1,
		"The bolt woven before the council counts when offered after the decision.")
	print("COUNCIL_SILK_OFFERED day=", state.current_day, " goal=", state.route_objectives()[1].value)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated silk preparation profile."):
		tree.quit(1)
		return
	seed(1988)
	if capture_dir.is_empty():
		tree.root.size = Vector2i(1280, 720)
	tree.root.notify_mouse_entered()
	state = tree.root.get_node("Global")
	state.balance.raid_first_day = 1000
	var fixture := FileAccess.open(state.SAVE_PATH, FileAccess.WRITE)
	fixture.store_string(JSON.stringify(SILK_FIXTURE))
	fixture.close()
	await _continue()
	if await _plant() and await _collect_leaves() and await _weave():
		await _offer_after_council()
	tree.paused = false
	tree.unload_current_scene()
	for stream in tree.root.get_node("AudioManager").get_children():
		if stream is AudioStreamPlayer:
			stream.stop()
	await tree.process_frame
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
