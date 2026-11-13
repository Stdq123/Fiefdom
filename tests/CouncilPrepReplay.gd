extends "res://tests/WestMarketReplay.gd"

const SECOND := Vector2i(12, 5)
const PRIVATE_WHEAT := Vector2i(6, 5)
const PRIVATE_MILLET := Vector2i(5, 6)
const LEFTOVER_WHEAT := Vector2i(4, 5)
const SNAPSHOT := {
	"save_version": 2, "current_day": 47, "current_rank": 1, "reputation": 320,
	"money": 140, "food_storage": 14, "king_storage": 29, "private_harvest_total": 68,
	"player_stats": {"LITERACY": {"level": 2, "xp": 130, "max_xp": 150}},
	"retainers": [{"name": "渠伯", "school": 2, "duty": 0, "loyalty": 90}],
	"well_fields": [
		{"center_pos": "5,5", "is_unlocked": true, "reclamation_progress": 4},
		{"center_pos": "12,5", "is_unlocked": true, "reclamation_progress": 4},
	],
	"active_crops": {
		"5,5": {"id": "millet", "age": 2, "growth_nights": 2},
		"12,5": {"id": "millet", "age": 0, "growth_nights": 3, "watered": true},
		"6,5": {"id": "wheat", "age": 2, "growth_nights": 2},
		"5,6": {"id": "millet", "age": 2, "growth_nights": 2},
		"4,5": {"id": "wheat", "age": 2, "growth_nights": 2},
	},
	"fertile_cells": ["6,5", "4,5"],
}

var world: Node2D
var ui: CanvasLayer
var book: Control
var legacy := false
var petition := false

func _continue() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await _button(tree.current_scene.continue_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await tree.process_frame
	world = tree.current_scene.get_node("World")
	ui = tree.current_scene.get_node("UI")
	book = ui.council_preparation
	state.balance.raid_first_day = 1000
	await tree.process_frame

func _open_book() -> void:
	await _button(ui.hud.council_prep_button)
	var ledger: Control = book.modal.get_node("Center/Ledger")
	_expect(tree.paused and book.modal.visible and tree.root.get_visible_rect().encloses(ledger.get_global_rect()),
		"The preparation ledger opens and fits the viewport.")

func _click_plot(cell: Vector2i) -> void:
	var layer: TileMapLayer = world.tile_map
	await _click(layer.get_global_transform_with_canvas() * layer.map_to_local(cell))

func _water_second() -> void:
	if world.field_action(SECOND) == world.FieldAction.WATER:
		await _click_plot(SECOND)

func _sleep() -> void:
	await _button(ui.sleep_button)
	await tree.create_timer(1.16).timeout

func _promote_through_study() -> void:
	await _open_book()
	_expect("还需 2 夜" in book.date_status.text and "当前中士" in book.rank_line.text
		and "任一六艺需 3 级 · 当前最高 2 级" in book.rank_status.text and book.arts_button.visible,
		"Before the third year the ledger shows the date and the missing rank qualification.")
	await _snapshot("01-study-needed")
	await _button(book.close_button)
	_expect(ui.hud.guide.heading.text == "晋升上士" and "当前最高 2 级" in ui.hud.guide.text,
		"The journal points from the finished field to the missing art level.")
	await _button(ui.hud.guide.six_arts)
	var management: Control = ui.panel_manager.management_panel_instance
	_expect(not tree.paused and management.stats_container.is_visible_in_tree(), "The arts shortcut reaches the actual arts tab.")
	await _button(management.read_button)
	_expect(state.player_stats.get_level(PlayerStats.Art.LITERACY) == 3 and state.eligible_for_promotion(),
		"Ordinary study reaches the art level needed for promotion.")
	await _button(management.get_node("CloseButton"))
	_expect(not ui.hud.guide.six_arts.visible and "过夜核定" in ui.hud.guide.text,
		"The journal switches to nightly confirmation as soon as the requirement is met.")
	await _sleep()
	_expect(state.current_day == 48 and state.current_rank == state.Rank.SHANG_SHI and not state.tax_council_waiting(),
		"Nightly promotion takes the player to the next rank.")
	await _open_book()
	_expect("还需 1 夜" in book.date_status.text and "过夜核定" in book.rank_status.text
		and not book.arts_button.visible, "The book shows the rank to be confirmed the next morning.")
	await _snapshot("02-next-morning-promotion")
	await _button(book.close_button)
	await _water_second()
	await _sleep()
	_expect(state.current_day == 49 and state.current_rank == state.Rank.DA_FU and state.king_storage == 29
		and state.private_harvest_total == 68 and not state.tax_council_waiting(),
		"The first eligible date and rank still require one more tribute.")
	print("COUNCIL_PREP_RANK day=", state.current_day, " rank=", state.rank_names[state.current_rank], " study=", state.player_stats.get_level(PlayerStats.Art.LITERACY))

func _save_route() -> void:
	await _button(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _button(button)
			break
	_expect(settings.save_status.text == "游戏已保存", "Save the chosen route using the normal settings button.")
	await _continue()

func _choose_what_to_harvest() -> void:
	await _open_book()
	_expect("29.90%" in book.contribution.text and "还差 1 份纳贡" in book.contribution_status.text
		and "29 份" in book.account.text and "68 份" in book.account.text,
		"The unrounded state is explicitly one unit below the contribution threshold.")
	_expect("30.61% · 纳贡已达标" in book.public_result.text and "29.13% · 还差 2 份纳贡" in book.mixed_result.text
		and "私仓 +5" in book.mixed_preview.text and state.tax_council_public_gap(1, 2) == 0,
		"The real harvest forecast includes fertile wheat and counts exactly 30 percent as enough.")
	print("COUNCIL_PREP_FORECAST tribute=29 private=68 gap=1 public_only=30.61 mixed=29.13")
	await _snapshot("03-first-third-year")
	await _key(KEY_ESCAPE)
	var copper: int = state.money
	await _click_plot(PRIVATE_WHEAT)
	await _click_plot(PRIVATE_MILLET)
	_expect(state.king_storage == 29 and state.private_harvest_total == 71 and state.player_inventory == 3
		and state.money == copper + 2 * ItemManager.get_crop("wheat").sell_price + ItemManager.get_crop("millet").sell_price
		and not state.tax_council_waiting(), "Two ordinary private harvests earn money and increase the cumulative private count.")
	await _open_book()
	_expect("还差 2 份纳贡" in book.contribution_status.text and "29.70% · 还差 1 份纳贡" in book.public_result.text,
		"The book accounts for the two private harvests before the public crop.")
	await _button(book.field_button)
	_expect(state.field_route_public_only and ui.directions.tracked_plot == PUBLIC and not tree.paused,
		"Only the mature public plot is marked by the preparation action.")
	await _save_route()
	_expect(state.current_day == 49 and state.field_route_public_only and ui.directions.tracked_plot == PUBLIC
		and state.private_harvest_total == 71, "Continue restores the public-only field route and current ledger.")
	await _snapshot("04-public-route-reloaded")
	await _click_plot(PUBLIC)
	_expect(state.king_storage == 30 and state.private_harvest_total == 71 and not state.tax_council_waiting()
		and not state.field_route_public_only and ui.directions.tracked_plot == null and world.is_crop_ripe(LEFTOVER_WHEAT),
		"After the public harvest the route clears even with ripe private wheat nearby.")
	await _open_book()
	_expect(not book.public_card.visible and book.field_button.text == "查看井田", "Without ripe public crops the ledger opens the field map.")
	await _button(book.field_button)
	_expect(ui.estate_map.modal.visible and ui.estate_map.category == ui.estate_map.Category.FIELDS,
		"The fallback opens the field tab through its ordinary entry.")
	await _key(KEY_ESCAPE)
	await _water_second()
	await _sleep()
	_expect(state.current_day == 50 and state.night_rations.last.served == 1 and world.is_crop_ripe(SECOND)
		and state.king_storage == 30 and not state.tax_council_waiting(), "The next dawn feeds the household and ripens the second public field.")
	print("COUNCIL_PREP_DELAY day=50 tribute=30 private=71 still_needed=1 served=", state.night_rations.last.served)

func _meet_and_choose() -> void:
	await _open_book()
	_expect("30.39% · 纳贡已达标" in book.public_result.text and "29.81% · 还差 1 份纳贡" in book.mixed_result.text,
		"On the new morning the ledger shows why the player can harvest public first.")
	await _snapshot("05-next-public-harvest")
	var controller = load("res://tests/GamepadReplay.gd").new()
	controller.tree = tree
	controller.pad = tree.root.get_node("GamepadInput")
	tree.root.notify_mouse_exited()
	await controller._click(book.field_button, true)
	_expect(controller.failures == 0 and state.field_route_public_only and ui.directions.tracked_plot == SECOND,
		"A controller can follow the public crop on the second field.")
	await _click_plot(SECOND)
	_expect(state.king_storage == 31 and state.private_harvest_total == 71 and state.tax_council_waiting()
		and not ui.hud.council_prep_button.visible and not state.field_route_public_only,
		"The predicted harvest summons the envoy and closes the preparation step.")
	await _button(ui.hud.opening_action)
	_expect(ui.directions.tracked_neighbor == state.TAX_ENVOY, "The journal now leads to the envoy.")
	await _snapshot("06-envoy-arrival")
	var decision := await Campaign.meet_tax_envoy(tree)
	if not _expect(decision != null and tree.paused, "Walk to the envoy and open the real council."):
		return
	await _button(decision.option_buttons[state.TaxReformChoice.TRADITIONAL])
	await _button(decision.confirm_button)
	await _continue()
	_expect(state.tax_reform_choice == state.TaxReformChoice.TRADITIONAL and state.tax_reform_day == 50
		and state.king_storage == 31 and state.private_harvest_total == 71 and world.is_crop_ripe(LEFTOVER_WHEAT)
		and ui.hud.route_progress.visible and not ui.hud.council_prep_button.visible,
		"Continue from the council save and proceed to the ending goals.")
	await _button(ui.hud.route_progress)
	await _snapshot("07-ending-goals")
	await _button(ui.route_goals.close_button)
	print("COUNCIL_PREP_DECISION day=", state.current_day, " tribute=", state.king_storage, " private=", state.private_harvest_total, " route=traditional")

func _old_save() -> void:
	await _continue()
	_expect(state.current_day == 49 and state.current_rank == state.Rank.DA_FU and not state.field_route_public_only
		and state.king_storage == 29 and state.private_harvest_total == 68, "A genuine previous save can open the new ledger.")
	await _open_book()
	_expect("还差 1 份纳贡" in book.contribution_status.text, "The old record calculates the same remaining contribution.")
	await _button(book.field_button)
	await _click_plot(PUBLIC)
	_expect(state.king_storage == 30 and state.private_harvest_total == 68 and state.tax_council_waiting(),
		"Following the public crop from an old save meets the existing invitation rule.")
	print("COUNCIL_PREP_OLD_SAVE day=", state.current_day, " tribute=", state.king_storage, " invited=", state.tax_council_waiting())

func _early_petition() -> void:
	var save := SNAPSHOT.duplicate(true)
	save.merge({"current_day": 42, "current_rank": 3, "king_storage": 35, "private_harvest_total": 68,
		"season_order_receipts": {"spring": {"day": 4}, "spring_seed_share": {"day": 27}},
		"crop_stock": {"wheat": 2}, "player_inventory": 2,
		"silk_workshop": {"built": true, "bolts": 1}}, true)
	var fixture := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify(save))
	fixture.close()
	await _continue()
	await _open_book()
	_expect("1/2" in book.petition_heading.text and "第 43 天" in book.petition_detail.text
		and not book.petition_button.visible and not EventManager.petition_tax_council(),
		"The first-year receipt cannot count, and the petition cannot start before winter.")
	await _button(book.orders_button)
	var management: Control = ui.panel_manager.management_panel_instance
	_expect(management.season_order_panel.is_visible_in_tree() and not tree.paused,
		"The preparation ledger leads to the same seasonal order book.")
	await _button(management.get_node("CloseButton"))
	await _sleep()
	await _open_book()
	_expect(state.current_day == 43 and not book.petition_button.visible and not EventManager.petition_tax_council(),
		"Winter alone cannot open the petition with one eligible receipt.")
	await _snapshot("01-one-receipt")
	await _button(book.orders_button)
	var orders: Control = management.season_order_panel
	_expect("交货后余 0 匹丝绸" in orders.status.text, "The winter order quotes the shared silk stock before the sale.")
	var food: int = state.food_storage
	await _button(orders.food_button)
	_expect(state.food_storage > food and state.crop_stock.count("wheat") == 0 and state.silk_workshop.bolts == 0
		and state.king_storage == 35 and state.private_harvest_total == 68 and state.silk_bolts_sold == 0
		and "本年已交 2/2" in orders.status.text and not state.tax_council_waiting(),
		"The real winter order settles privately, records the second receipt and leaves the petition optional.")
	await _button(management.get_node("CloseButton"))
	_expect(ui.hud.council_prep_button.text == "请议已就绪" and state.save_game() == OK,
		"The estate journal reports the opportunity and saves the receipts.")
	await _continue()
	await _open_book()
	_expect("2/2" in book.petition_heading.text and book.petition_button.visible,
		"The saved receipts restore the opportunity after continuing from the title.")
	await _snapshot("02-petition-ready")
	await _button(book.petition_button)
	if not _expect(state.tax_council_waiting() and not book.modal.visible and not tree.paused
		and not EventManager.petition_tax_council() and state.save_game() == OK,
		"The petition schedules exactly one audience and saves the pending appointment."):
		return
	await _continue()
	await _button(ui.hud.opening_action)
	_expect(ui.directions.tracked_neighbor == state.TAX_ENVOY, "The estate journal can guide the player to the early audience.")
	var decision := await Campaign.meet_tax_envoy(tree)
	if not _expect(decision != null and "交货回执" in decision.text_label.text
		and decision.option_buttons.size() == 3, "The envoy acknowledges the receipts and offers all three choices."):
		return
	await _snapshot("03-early-audience")
	await _button(decision.option_buttons[state.TaxReformChoice.REFORMED])
	await _button(decision.confirm_button)
	await _continue()
	_expect(state.current_day == 43 and state.tax_reform_day == 43 and state.tax_reform_choice == state.TaxReformChoice.REFORMED
		and state.king_storage == 35 and state.private_harvest_total == 68 and ui.hud.route_progress.visible,
		"Continuing after the choice restores the early decision and starts the normal ending goals.")
	print("COUNCIL_PREP_PETITION day=", state.tax_reform_day, " regular=", state.tax_council_start_day(),
		" receipts=", state.tax_council_petition_order_count(), " tribute=", state.king_storage)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_COUNCIL_PREP_CAPTURES")
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated council preparation profile."):
		tree.quit(1)
		return
	if petition:
		await _early_petition()
	elif legacy:
		await _old_save()
	else:
		var fixture := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		fixture.store_string(JSON.stringify(SNAPSHOT))
		fixture.close()
		await _continue()
		await _promote_through_study()
		if not failed:
			await _choose_what_to_harvest()
		if not failed:
			await _meet_and_choose()
	tree.paused = false
	tree.unload_current_scene()
	for stream in tree.root.get_node("AudioManager").get_children():
		if stream is AudioStreamPlayer:
			stream.stop()
	await tree.process_frame
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
