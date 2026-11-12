extends Control

const BOW_ARCHERY_LEVEL := 2
const SEASON_ORDER_PANEL := preload("res://scenes/SeasonOrderPanel.tscn")
const NEIGHBOR_JOURNAL := preload("res://scenes/NeighborJournal.tscn")
const FISH_LEDGER := preload("res://scripts/FishLedger.gd")
const MAP_GRID_ITEM := preload("res://scripts/MapGridItem.gd")

@onready var retainer_list_container: VBoxContainer = $HBoxContainer/LeftPanel/ScrollContainer/VBoxContainer
# Updated path due to TabContainer
@onready var map_grid_container: GridContainer = $HBoxContainer/RightPanel/封地概览/GridContainer
@onready var well_field_selector: OptionButton = $HBoxContainer/RightPanel/封地概览/WellFieldSelector
@onready var seed_plan_picker: OptionButton = $HBoxContainer/RightPanel/封地概览/SeedPlan/SeedPicker
@onready var market_panel: VBoxContainer = $HBoxContainer/RightPanel/市场
@onready var food_label: Label = $HBoxContainer/RightPanel/市场/FoodLabel
@onready var irrigation_button: Button = $HBoxContainer/RightPanel/科技/TechContainer/IrrigationButton
@onready var bow_button: Button = $HBoxContainer/RightPanel/科技/TechContainer/BowButton
@onready var rank_progress_label: Label = $HBoxContainer/RightPanel/科技/RankLabel
@onready var tabs: TabContainer = $HBoxContainer/RightPanel
var season_order_panel: Control
var neighbor_journal: Control
var fish_ledger: Control

var retainer_item_scene = preload("res://scenes/RetainerItem.tscn")
var silk_panel_script = preload("res://scripts/SilkPanel.gd")
var ravine_panel_script = preload("res://scripts/RavineJournalPanel.gd")
var music_practice_script = preload("res://scripts/MusicPractice.gd")

# Six Arts UI References
@onready var stats_container: VBoxContainer = $HBoxContainer/RightPanel/君子六艺/StatsContainer
@onready var study_progress: Label = $HBoxContainer/RightPanel/君子六艺/StudyProgress
@onready var read_button: Button = $HBoxContainer/RightPanel/君子六艺/Actions/ReadButton
@onready var music_button: Button = $HBoxContainer/RightPanel/君子六艺/Actions/MusicButton
@onready var driving_button: Button = $HBoxContainer/RightPanel/君子六艺/Actions/DrivingButton

func _ready() -> void:
	visibility_changed.connect(_announce_visibility)
	_announce_visibility()
	refresh_retainers()
	well_field_selector.item_selected.connect(_show_well_field)
	seed_plan_picker.add_item("选种后点田格")
	for seed_id: String in CropData.IDS:
		var crop := ItemManager.get_crop(seed_id)
		seed_plan_picker.add_icon_item(ItemManager.crop_picture(crop).texture, crop.crop_name)
		seed_plan_picker.set_item_metadata(seed_plan_picker.item_count - 1, seed_id)
	seed_plan_picker.add_item("取消续播")
	seed_plan_picker.set_item_metadata(seed_plan_picker.item_count - 1, "")
	refresh_well_fields()
	GameEvents.farm_state_changed.connect(_refresh_field_tiles)
	GameEvents.crop_harvested.connect(_refresh_field_tiles.unbind(1))
	GameEvents.day_advanced.connect(_refresh_field_tiles.unbind(1))
	GameEvents.channels_changed.connect(_refresh_field_tiles)
	setup_six_arts()
	setup_tech()
	_refresh_rank_progress()
	GameEvents.rank_changed.connect(_refresh_rank_progress.unbind(1))
	GameEvents.reputation_changed.connect(_refresh_rank_progress.unbind(1))
	GameEvents.crop_harvested.connect(_refresh_rank_progress.unbind(1))
	GameEvents.day_advanced.connect(_refresh_rank_progress.unbind(1))
	var silk_panel := silk_panel_script.new() as VBoxContainer
	silk_panel.name = "蚕桑"
	silk_panel.add_theme_constant_override("separation", 12)
	$HBoxContainer/RightPanel.add_child(silk_panel)
	var ravine_panel := ravine_panel_script.new() as VBoxContainer
	ravine_panel.name = "溪行手记"
	$HBoxContainer/RightPanel.add_child(ravine_panel)
	season_order_panel = SEASON_ORDER_PANEL.instantiate()
	tabs.add_child(season_order_panel)
	neighbor_journal = NEIGHBOR_JOURNAL.instantiate()
	tabs.add_child(neighbor_journal)
	fish_ledger = FISH_LEDGER.new()
	fish_ledger.name = "溪鱼簿"
	tabs.add_child(fish_ledger)
	market_panel.fish_book_button.pressed.connect(show_fish_ledger)
	tabs.tab_changed.connect(func(index: int):
		$HBoxContainer/LeftPanel.visible = tabs.get_tab_control(index) not in [neighbor_journal, fish_ledger]
	)

func show_season_orders() -> void:
	tabs.current_tab = tabs.get_tab_idx_from_control(season_order_panel)

func show_market() -> void:
	tabs.current_tab = tabs.get_tab_idx_from_control(market_panel)

func show_neighbors() -> void:
	tabs.current_tab = tabs.get_tab_idx_from_control(neighbor_journal)

func show_fish_ledger() -> void:
	tabs.current_tab = tabs.get_tab_idx_from_control(fish_ledger)

func _announce_visibility() -> void:
	GameEvents.management_visibility_changed.emit(is_visible_in_tree())

func setup_tech() -> void:
	irrigation_button.pressed.connect(_on_unlock_irrigation)
	bow_button.pressed.connect(_on_unlock_bow)
	_refresh_tech()

func _on_unlock_irrigation() -> void:
	var literacy := Global.player_stats.get_level(PlayerStats.Art.LITERACY)
	if Global.tech_unlocked["irrigation"] or literacy < Irrigation.UNLOCK_LITERACY_LEVEL:
		return
	Global.tech_unlocked["irrigation"] = true
	GameEvents.irrigation_unlocked.emit()
	_refresh_tech()
	_refresh_study_progress()

func _refresh_tech() -> void:
	var unlocked: bool = Global.tech_unlocked["irrigation"]
	var literacy := Global.player_stats.get_level(PlayerStats.Art.LITERACY)
	irrigation_button.disabled = unlocked or literacy < Irrigation.UNLOCK_LITERACY_LEVEL
	if unlocked:
		irrigation_button.text = "水利已解锁 · 返回地图挖渠"
	elif irrigation_button.disabled:
		irrigation_button.text = "水利待研习 · 书 %d/%d 级" % [literacy, Irrigation.UNLOCK_LITERACY_LEVEL]
	else:
		irrigation_button.text = "解锁水利"

	var bow_unlocked: bool = Global.tech_unlocked["composite_bow"]
	var archery := Global.player_stats.get_level(PlayerStats.Art.ARCHERY)
	bow_button.disabled = bow_unlocked or archery < BOW_ARCHERY_LEVEL
	if bow_unlocked:
		bow_button.text = "复合弓已解锁"
	elif bow_button.disabled:
		bow_button.text = "复合弓待研习 · 射 %d/%d 级" % [archery, BOW_ARCHERY_LEVEL]
	else:
		bow_button.text = "解锁复合弓"

func _on_unlock_bow() -> void:
	var archery := Global.player_stats.get_level(PlayerStats.Art.ARCHERY)
	if not Global.tech_unlocked["composite_bow"] and archery >= BOW_ARCHERY_LEVEL:
		Global.tech_unlocked["composite_bow"] = true
		_refresh_tech()

func setup_six_arts() -> void:
	# Connect buttons
	var actions = $HBoxContainer/RightPanel/君子六艺/Actions
	if actions:
		actions.get_node("WorshipButton").pressed.connect(_on_worship_pressed)
	read_button.pressed.connect(_on_read_pressed)
	music_button.pressed.connect(_open_music_practice)
	driving_button.pressed.connect(_start_driving_practice)
	GameEvents.day_advanced.connect(_refresh_practice_buttons.unbind(1))
	GameEvents.silk_changed.connect(_refresh_study_progress)
	_refresh_practice_buttons()
	
	# Initial update
	update_stats_ui()
	
	# Connect signals
	Global.player_stats.xp_changed.connect(_on_xp_changed)

func update_stats_ui() -> void:
	if not stats_container: return
	
	for child in stats_container.get_children():
		stats_container.remove_child(child)
		child.queue_free()
		
	for i in range(6): # 0 to 5
		var stat = Global.player_stats.get_stat(i)
		var stat_name = Global.player_stats.get_art_name(i)
		
		var hbox = HBoxContainer.new()
		
		var name_label = Label.new()
		name_label.text = stat_name
		name_label.custom_minimum_size.x = 100
		hbox.add_child(name_label)
		
		var progress = ProgressBar.new()
		progress.max_value = stat["max_xp"]
		progress.value = stat["xp"]
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress.custom_minimum_size.y = 20
		progress.show_percentage = false
		hbox.add_child(progress)
		
		var level_label = Label.new()
		level_label.text = "%d 级" % stat.level
		hbox.add_child(level_label)
		
		stats_container.add_child(hbox)

func _on_read_pressed() -> void:
	Global.study_bamboo_slips()

func _on_worship_pressed() -> void:
	# Worship increases Rites (礼)
	Global.player_stats.add_xp(PlayerStats.Art.RITES, 10)
	print("Worshipping...")

func _on_xp_changed(_art_name: String, _xp: int, _max_xp: int) -> void:
	update_stats_ui()
	_refresh_practice_buttons()
	_refresh_rank_progress()
	_refresh_tech()

func _refresh_rank_progress() -> void:
	rank_progress_label.text = Global.promotion_summary()
	if Global.tax_reform_choice != Global.TaxReformChoice.REFORMED:
		rank_progress_label.text += "\n连续欠贡 %d 夜 · 声望到 %d 会削爵或失地" % [
			Global.days_without_contribution, Global.balance.rank_strip_threshold]

func _refresh_practice_buttons() -> void:
	read_button.disabled = not Global.can_practice_today(PlayerStats.Art.LITERACY)
	read_button.text = "今日已研读" if read_button.disabled else "研读简册 · +%d" % Global.balance.literacy_study_xp
	_refresh_study_progress()
	music_button.disabled = not Global.can_practice_today(PlayerStats.Art.MUSIC)
	driving_button.disabled = not Global.can_practice_today(PlayerStats.Art.DRIVING)
	music_button.text = "今日已奏乐" if music_button.disabled else "编钟练习"
	driving_button.text = "今日已驾御" if driving_button.disabled else "驾御练习"

func _refresh_study_progress() -> void:
	var literacy := Global.player_stats.get_stat(PlayerStats.Art.LITERACY)
	study_progress.text = "书 %d 级 · 本级经验 %d/%d\n每天可研读一次，与来客交谈也能积累书经验。" % [
		literacy.level, literacy.xp, literacy.max_xp]
	if not Global.silk_workshop.built:
		study_progress.text += "\n" + ("可到蚕桑页建蚕室。" if literacy.level >= SilkWorkshop.LITERACY_LEVEL else
			"书 %d 级可建蚕室。" % SilkWorkshop.LITERACY_LEVEL)
	if not Global.tech_unlocked["irrigation"]:
		study_progress.text += "\n" + ("可到科技页解锁水利。" if literacy.level >= Irrigation.UNLOCK_LITERACY_LEVEL else
			"书 %d 级可解锁水利。" % Irrigation.UNLOCK_LITERACY_LEVEL)

func _open_music_practice() -> void:
	if not music_button.disabled and not has_node("MusicPractice"):
		var practice := music_practice_script.new() as Panel
		practice.name = "MusicPractice"
		add_child(practice)

func _start_driving_practice() -> void:
	if not driving_button.disabled:
		hide()
		GameEvents.driving_practice_requested.emit()

func refresh_retainers() -> void:
	# Clear existing
	for child in retainer_list_container.get_children():
		retainer_list_container.remove_child(child)
		child.queue_free()
		
	# Add from Global
	for r in Global.retainers:
		var item = retainer_item_scene.instantiate()
		retainer_list_container.add_child(item)
		item.setup(r)
	
func refresh_well_fields() -> void:
	var previous_id := well_field_selector.get_selected_id()
	well_field_selector.clear()
	var selected := 0
	for field in Global.well_fields:
		if field["is_unlocked"]:
			var id: int = field["field_id"]
			if id == previous_id:
				selected = well_field_selector.item_count
			well_field_selector.add_item("井田 %d" % (id + 1), id)
	if well_field_selector.item_count > 0:
		well_field_selector.select(selected)
		_show_well_field(selected)

func _show_well_field(index: int) -> void:
	for child in map_grid_container.get_children():
		map_grid_container.remove_child(child)
		child.queue_free()
	var field := Global.get_well_field(well_field_selector.get_item_id(index))
	var center: Vector2i = field["center_pos"]
	for y in range(-1, 2):
		for x in range(-1, 2):
			var item := MAP_GRID_ITEM.new()
			item.grid_pos = center + Vector2i(x, y)
			item.retainer_dropped.connect(_on_retainer_assigned)
			item.pressed.connect(_apply_seed_plan.bind(item))
			map_grid_container.add_child(item)

func _refresh_field_tiles() -> void:
	if is_visible_in_tree():
		for item: MAP_GRID_ITEM in map_grid_container.get_children():
			item.refresh_plot()

func _apply_seed_plan(item: MAP_GRID_ITEM) -> void:
	if seed_plan_picker.selected == 0:
		return
	Global.set_field_seed_plan(item.grid_pos, seed_plan_picker.get_selected_metadata())
	item.refresh_plot()

func _on_retainer_assigned(grid_pos: Vector2i, data: RetainerData) -> void:
	print("Assigned ", data.name, " to ", grid_pos)
	# Notify World or Update Logic
	# For prototype, we just print. Ideally, we signal World to update the Retainer's target.
	# But ManagementPanel is UI. 
	# Let's emit a signal that Main/World can listen to.
	GameEvents.retainer_assigned.emit(data, grid_pos)
