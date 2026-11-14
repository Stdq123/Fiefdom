extends Control

const BOW_ARCHERY_LEVEL := 2
const SEASON_ORDER_PANEL := preload("res://scenes/SeasonOrderPanel.tscn")
const NEIGHBOR_JOURNAL := preload("res://scenes/NeighborJournal.tscn")
const FISH_LEDGER := preload("res://scripts/FishLedger.gd")
const MAP_GRID_ITEM := preload("res://scripts/MapGridItem.gd")

@onready var sections: HBoxContainer = %Sections
@onready var section_hint: Label = %SectionHint
@onready var close_button: Button = $CloseButton
@onready var retainer_panel: VBoxContainer = $HBoxContainer/LeftPanel
@onready var retainer_count: Label = %RetainerCount
@onready var empty_roster: Label = %EmptyRoster
@onready var retainer_list_container: VBoxContainer = $HBoxContainer/LeftPanel/ScrollContainer/VBoxContainer
@onready var map_grid_container: GridContainer = $HBoxContainer/RightPanel/封地概览/GridContainer
@onready var well_field_selector: OptionButton = $HBoxContainer/RightPanel/封地概览/WellFieldSelector
@onready var steward_note: Label = %StewardNote
@onready var steward_picker: OptionButton = %StewardPicker
@onready var apply_steward: Button = %ApplySteward
@onready var steward_preview: Label = %StewardPreview
@onready var seed_plan_picker: OptionButton = $HBoxContainer/RightPanel/封地概览/SeedPlan/SeedPicker
@onready var rotate_seed: CheckBox = $HBoxContainer/RightPanel/封地概览/SeedPlan/RotateSeed
@onready var apply_private_plan: Button = $HBoxContainer/RightPanel/封地概览/SeedPlan/ApplyPrivate
@onready var seed_timing: Label = $HBoxContainer/RightPanel/封地概览/SeedTiming
@onready var seed_plan_note: Label = $HBoxContainer/RightPanel/封地概览/SeedPlanNote
@onready var market_panel: VBoxContainer = $HBoxContainer/RightPanel/市场
@onready var food_label: Label = $HBoxContainer/RightPanel/市场/FoodLabel
@onready var irrigation_button: Button = $HBoxContainer/RightPanel/科技/TechContainer/IrrigationButton
@onready var bow_button: Button = $HBoxContainer/RightPanel/科技/TechContainer/BowButton
@onready var rank_progress_label: Label = $HBoxContainer/RightPanel/科技/RankLabel
@onready var tabs: TabContainer = $HBoxContainer/RightPanel
var section_buttons: Array[Button] = []
var previous_focus: Control
var season_order_panel: Control
var neighbor_journal: Control
var fish_ledger: Control
var silk_panel: VBoxContainer
var steward_field_id := -1

var retainer_item_scene = preload("res://scenes/RetainerItem.tscn")
var silk_panel_script = preload("res://scripts/SilkPanel.gd")
var ravine_panel_script = preload("res://scripts/RavineJournalPanel.gd")
var music_practice_script = preload("res://scripts/MusicPractice.gd")

# Six Arts UI References
@onready var stats_container: VBoxContainer = $HBoxContainer/RightPanel/君子六艺/StatsContainer
@onready var study_progress: Label = $HBoxContainer/RightPanel/君子六艺/StudyProgress
@onready var driving_record: Label = $HBoxContainer/RightPanel/君子六艺/DrivingRecord
@onready var read_button: Button = $HBoxContainer/RightPanel/君子六艺/Actions/ReadButton
@onready var music_button: Button = $HBoxContainer/RightPanel/君子六艺/Actions/MusicButton
@onready var driving_button: Button = $HBoxContainer/RightPanel/君子六艺/Actions/DrivingButton

func _ready() -> void:
	refresh_retainers()
	well_field_selector.item_selected.connect(_show_well_field)
	seed_plan_picker.add_item("选择续播方式")
	for seed_id: String in CropData.IDS:
		var crop := ItemManager.get_crop(seed_id)
		seed_plan_picker.add_icon_item(ItemManager.crop_picture(crop).texture, crop.crop_name)
		seed_plan_picker.set_item_metadata(seed_plan_picker.item_count - 1, seed_id)
	seed_plan_picker.add_item("按时令续播")
	seed_plan_picker.set_item_metadata(seed_plan_picker.item_count - 1, FieldSeedPlan.SEASONAL)
	seed_plan_picker.add_item("取消续播")
	seed_plan_picker.set_item_metadata(seed_plan_picker.item_count - 1, "")
	for picker in [seed_plan_picker, steward_picker]:
		var menu: PopupMenu = picker.get_popup()
		menu.add_theme_stylebox_override("panel", picker.get_theme_stylebox("panel", "PanelContainer"))
		menu.add_theme_stylebox_override("hover", picker.get_theme_stylebox("hover", "Button"))
		menu.add_theme_color_override("font_color", picker.get_theme_color("font_color", "Button"))
	seed_plan_picker.item_selected.connect(_refresh_seed_plan_preview.unbind(1))
	rotate_seed.toggled.connect(_refresh_seed_plan_preview.unbind(1))
	GameEvents.field_rotation_changed.connect(_refresh_seed_plan_preview)
	apply_private_plan.pressed.connect(_apply_private_seed_plan)
	steward_picker.item_selected.connect(_refresh_steward_preview.unbind(1))
	apply_steward.pressed.connect(_apply_steward_handover)
	_refresh_seed_choices()
	refresh_well_fields()
	GameEvents.farm_state_changed.connect(_refresh_field_tiles)
	GameEvents.crop_harvested.connect(_refresh_field_tiles.unbind(1))
	GameEvents.day_advanced.connect(_refresh_field_tiles.unbind(1))
	GameEvents.day_advanced.connect(_refresh_seed_choices.unbind(1))
	GameEvents.channels_changed.connect(_refresh_field_tiles)
	GameEvents.well_field_reclaimed.connect(refresh_well_fields.unbind(2))
	GameEvents.retainer_duty_changed.connect(_refresh_steward_choices.unbind(1))
	GameEvents.retainer_assigned.connect(_refresh_steward_choices.unbind(2))
	GameEvents.retainer_recruited.connect(_refresh_steward_choices.unbind(1))
	GameEvents.retainer_departed.connect(_refresh_steward_choices.unbind(1))
	GameEvents.food_changed.connect(_refresh_steward_preview.unbind(1))
	GameEvents.retainer_assigned.connect(_show_steward_assignment)
	GameEvents.tax_reform_choice_made.connect(_refresh_field_tiles.unbind(1))
	setup_six_arts()
	setup_tech()
	_refresh_rank_progress()
	GameEvents.rank_changed.connect(_refresh_rank_progress.unbind(1))
	GameEvents.reputation_changed.connect(_refresh_rank_progress.unbind(1))
	GameEvents.crop_harvested.connect(_refresh_rank_progress.unbind(1))
	GameEvents.day_advanced.connect(_refresh_rank_progress.unbind(1))
	silk_panel = silk_panel_script.new()
	silk_panel.name = "蚕桑"
	silk_panel.add_theme_constant_override("separation", 12)
	tabs.add_child(silk_panel)
	silk_panel.study_requested.connect(show_six_arts)
	var ravine_panel := ravine_panel_script.new() as VBoxContainer
	ravine_panel.name = "溪行手记"
	tabs.add_child(ravine_panel)
	season_order_panel = SEASON_ORDER_PANEL.instantiate()
	tabs.add_child(season_order_panel)
	season_order_panel.silk_requested.connect(show_silk)
	neighbor_journal = NEIGHBOR_JOURNAL.instantiate()
	tabs.add_child(neighbor_journal)
	fish_ledger = FISH_LEDGER.new()
	fish_ledger.name = "溪鱼簿"
	tabs.add_child(fish_ledger)
	market_panel.fish_book_button.pressed.connect(show_fish_ledger)
	_build_sections()
	tabs.tab_changed.connect(_refresh_section)
	GameEvents.management_section_requested.connect(_cycle_section)
	GamepadInput.changed.connect(_refresh_input_hints)
	visibility_changed.connect(_announce_visibility)
	_refresh_section(tabs.current_tab)
	_refresh_input_hints()
	_announce_visibility()

func _build_sections() -> void:
	var selection := ButtonGroup.new()
	var inactive := tabs.get_theme_stylebox("tab_unselected")
	var selected := tabs.get_theme_stylebox("tab_selected")
	for index in tabs.get_tab_count():
		var button := Button.new()
		button.name = tabs.get_tab_control(index).name
		button.text = tabs.get_tab_title(index)
		button.toggle_mode = true
		button.button_group = selection
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_stylebox_override("normal", inactive)
		button.add_theme_stylebox_override("pressed", selected)
		button.add_theme_stylebox_override("hover_pressed", selected)
		button.add_theme_color_override("font_color", Color("#d4dec7"))
		button.add_theme_color_override("font_pressed_color", Color("#ffdfa0"))
		button.add_theme_color_override("font_hover_pressed_color", Color("#ffdfa0"))
		button.pressed.connect(func(): tabs.current_tab = index)
		sections.add_child(button)
		section_buttons.append(button)
	var count := section_buttons.size()
	for index in count:
		var button := section_buttons[index]
		button.focus_neighbor_left = button.get_path_to(section_buttons[posmod(index - 1, count)])
		button.focus_neighbor_right = button.get_path_to(section_buttons[(index + 1) % count])
		button.focus_neighbor_top = NodePath(".")
	close_button.focus_next = close_button.get_path_to(section_buttons[0])
	section_buttons[0].focus_previous = section_buttons[0].get_path_to(close_button)

func _refresh_section(index: int) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var page := tabs.get_tab_control(index)
	retainer_panel.visible = page not in [neighbor_journal, fish_ledger]
	section_buttons[index].button_pressed = true
	if page == map_grid_container.get_parent():
		_refresh_field_tiles()
	if is_visible_in_tree() and (focus == null or focus in section_buttons):
		section_buttons[index].grab_focus()

func _cycle_section(step: int) -> void:
	if not is_visible_in_tree() or get_tree().paused:
		return
	var viewport := get_viewport()
	var focus := viewport.gui_get_focus_owner()
	if focus != null and not is_ancestor_of(focus):
		return
	if viewport.get_embedded_subwindows().any(func(window: Window): return not window.unfocusable):
		return
	tabs.current_tab = posmod(tabs.current_tab + step, section_buttons.size())
	section_buttons[tabs.current_tab].grab_focus()
	GamepadInput.snap_pointer_to_focus()

func _refresh_input_hints() -> void:
	section_hint.visible = GamepadInput.active
	close_button.text = "返回  B" if GamepadInput.active else "返回  Esc"

func show_season_orders() -> void:
	tabs.current_tab = tabs.get_tab_idx_from_control(season_order_panel)

func show_market() -> void:
	tabs.current_tab = tabs.get_tab_idx_from_control(market_panel)

func show_six_arts() -> void:
	tabs.current_tab = tabs.get_tab_idx_from_control(stats_container.get_parent())

func show_technology() -> void:
	tabs.current_tab = tabs.get_tab_idx_from_control(irrigation_button.get_parent().get_parent())

func show_silk() -> void:
	tabs.current_tab = tabs.get_tab_idx_from_control(silk_panel)

func show_estate(field_id := -1) -> void:
	tabs.current_tab = tabs.get_tab_idx_from_control(map_grid_container.get_parent())
	if field_id < 0:
		return
	var index := well_field_selector.get_item_index(field_id)
	if index < 0:
		return
	if well_field_selector.selected != index:
		well_field_selector.select(index)
		_show_well_field(index)
	var focus: Control = steward_picker if steward_picker.is_visible_in_tree() and not steward_picker.disabled else well_field_selector
	focus.grab_focus()
	GamepadInput.snap_pointer_to_focus.call_deferred()

func show_neighbors() -> void:
	tabs.current_tab = tabs.get_tab_idx_from_control(neighbor_journal)

func show_fish_ledger() -> void:
	tabs.current_tab = tabs.get_tab_idx_from_control(fish_ledger)

func _announce_visibility() -> void:
	var opened := is_visible_in_tree()
	GameEvents.management_visibility_changed.emit(opened)
	if opened:
		previous_focus = get_viewport().gui_get_focus_owner()
		section_buttons[tabs.current_tab].grab_focus()
		GamepadInput.snap_pointer_to_focus.call_deferred()
	elif is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()

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
	driving_button.text = "今日已练御" if driving_button.disabled else "指路去驾御"
	driving_record.visible = Global.best_driving_ms > 0
	driving_record.text = "驾御最快用时 %.1f 秒" % (Global.best_driving_ms / 1000.0)

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
	for child in retainer_list_container.get_children():
		retainer_list_container.remove_child(child)
		child.queue_free()

	retainer_count.text = "%d 人" % Global.retainers.size()
	retainer_count.visible = not Global.retainers.is_empty()
	empty_roster.visible = Global.retainers.is_empty()
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
			item.retainer_dropped.connect(Global.assign_retainer_plot)
			item.pressed.connect(_apply_seed_plan.bind(item))
			map_grid_container.add_child(item)
	_refresh_seed_plan_preview()
	_refresh_steward_choices()

func _refresh_steward_choices() -> void:
	var field_id := well_field_selector.get_selected_id()
	var previous := steward_picker.get_selected_metadata() as RetainerData
	var same_field := steward_field_id == field_id
	steward_field_id = field_id
	steward_picker.get_parent().visible = Global.field_steward_unlocked()
	steward_picker.clear()
	steward_picker.add_item("选择门客", Global.retainers.size())
	var current := 0
	var selected := 0
	if Global.field_steward_unlocked():
		for index in Global.retainers.size():
			var data: RetainerData = Global.retainers[index]
			if not Global.can_assign_duty(data, RetainerData.Duty.STEWARD):
				continue
			var option := steward_picker.item_count
			var role := data.duty_name()
			if data.duty == RetainerData.Duty.STEWARD:
				role = "井田 %d 管事" % (int(Global.stewarded_field(data).field_id) + 1)
			steward_picker.add_item("%s · %s" % [data.name, role], index)
			steward_picker.set_item_metadata(option, data)
			if same_field and data == previous:
				selected = option
			if current == 0 and _manages_selected_field(data):
				current = option
	steward_picker.select(selected if selected > 0 else current)
	steward_picker.disabled = steward_picker.item_count == 1
	_refresh_stewards()

func _manages_selected_field(data: RetainerData) -> bool:
	return (data.duty == RetainerData.Duty.STEWARD
		and Global.stewarded_field(data).field_id == well_field_selector.get_selected_id())

func _steward_fill_targets() -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	for item: MAP_GRID_ITEM in map_grid_container.get_children():
		var cell := item.grid_pos
		if Global.can_plan_field_seed(cell) and not Global.field_seed_plans.has(cell):
			targets.append(cell)
	return targets

func _refresh_steward_preview() -> void:
	steward_preview.visible = Global.field_steward_unlocked()
	var data := steward_picker.get_selected_metadata() as RetainerData
	var has_tilled_plot := map_grid_container.get_children().any(
		func(tile: MAP_GRID_ITEM) -> bool: return Global.tilled_cells.has(tile.grid_pos))
	var till_hint := "先翻田，再安排续播。"
	apply_steward.disabled = data == null
	apply_steward.text = "交给管事"
	if data == null:
		steward_preview.text = ("留任门客后可安排井田管事。" if steward_picker.disabled else
			"管事负责收割、浇水和按计划续播。")
		if not has_tilled_plot:
			steward_preview.text += " " + till_hint
		return
	var already_assigned := _manages_selected_field(data)
	var targets := _steward_fill_targets()
	var public_count := 0
	for cell in targets:
		public_count += int(Global.is_public_plot(cell))
	var private_count := targets.size() - public_count
	var ration := Global.night_ration_for_duty(RetainerData.Duty.STEWARD)
	var change := ration - Global.retainer_night_ration(data)
	var household := Global.retainer_food_cost()
	var ration_note := "全员每夜用粮 %d 份" % household
	if change != 0:
		ration_note = "全员每夜用粮 %d → %d 份" % [household, household + change]
	var field_number := well_field_selector.get_selected_id() + 1
	var assignment := "井田 %d" % field_number
	if already_assigned:
		apply_steward.text = "补齐续播"
		apply_steward.disabled = targets.is_empty()
		if apply_steward.disabled and apply_steward.has_focus():
			steward_picker.grab_focus()
	elif data.duty == RetainerData.Duty.STEWARD:
		assignment = "井田 %d → %s" % [int(Global.stewarded_field(data).field_id) + 1, assignment]
	var plans := PackedStringArray()
	if public_count > 0:
		plans.append("公田 %d 格续播%s" % [public_count, ItemManager.crop_label(Global.tribute_seed())])
	if private_count > 0:
		plans.append("私田 %d 格按时令续播" % private_count)
	var plan_note := "，".join(plans)
	if plan_note.is_empty():
		plan_note = "无可补齐的续播" if has_tilled_plot else till_hint
	steward_preview.text = "%s · %s · 粮仓 %d 份\n%s" % [assignment, ration_note, Global.food_storage, plan_note]

func _apply_steward_handover() -> void:
	var data := steward_picker.get_selected_metadata() as RetainerData
	var field := Global.get_well_field(well_field_selector.get_selected_id())
	var targets := _steward_fill_targets()
	if not _manages_selected_field(data):
		if not Global.assign_duty(data, RetainerData.Duty.STEWARD):
			return
		Global.assign_retainer_plot(data, field.center_pos)
	var public_seed := Global.tribute_seed()
	for cell in targets:
		Global.set_field_seed_plan(cell, public_seed if Global.is_public_plot(cell) else FieldSeedPlan.SEASONAL)
	_refresh_field_tiles()

func _refresh_stewards() -> void:
	_refresh_steward_preview()
	steward_note.hide()
	var id := well_field_selector.get_selected_id()
	var names := PackedStringArray()
	var has_field_keeper := false
	for retainer in Global.retainers:
		has_field_keeper = has_field_keeper or retainer.duty == RetainerData.Duty.FIELD
		if retainer.duty == RetainerData.Duty.STEWARD and Global.stewarded_field(retainer).field_id == id:
			names.append(retainer.name)
	if not names.is_empty():
		steward_note.text = "管事 %s · 收割、浇水，按安排续播" % "、".join(names)
		steward_note.show()
	elif not has_field_keeper and map_grid_container.get_children().any(
			func(item: MAP_GRID_ITEM) -> bool: return Global.field_seed_plans.has(item.grid_pos)):
		steward_note.text = "这块井田的续播在等照料门客或管事。"
		steward_note.show()

func _show_steward_assignment(data: RetainerData, _cell: Vector2i) -> void:
	if not is_visible_in_tree() or data.duty != RetainerData.Duty.STEWARD:
		return
	var id: int = Global.stewarded_field(data).field_id
	if id != well_field_selector.get_selected_id():
		var index := well_field_selector.get_item_index(id)
		well_field_selector.select(index)
		_show_well_field(index)

func _refresh_field_tiles() -> void:
	if is_visible_in_tree():
		for item: MAP_GRID_ITEM in map_grid_container.get_children():
			item.refresh_plot()
		_refresh_stewards()
		_refresh_seed_plan_preview()

func _apply_seed_plan(item: MAP_GRID_ITEM) -> void:
	if seed_plan_picker.selected == 0:
		return
	Global.set_field_seed_plan(item.grid_pos, _selected_seed_plan())
	item.refresh_plot()
	_refresh_stewards()
	_refresh_seed_plan_preview()

func _selected_seed_plan() -> String:
	var seed_id: String = seed_plan_picker.get_selected_metadata()
	return FieldSeedPlan.with_beans(seed_id) if rotate_seed.button_pressed else seed_id

func _refresh_seed_choices() -> void:
	for index in range(1, CropData.IDS.size() + 1):
		var crop := ItemManager.get_crop(seed_plan_picker.get_item_metadata(index))
		var label := "%s · %d 夜" % [crop.crop_name, Global.sowing_nights(crop)]
		if crop.favored_season == Global.season_index():
			label += " · 当令"
		if crop.is_water_crop:
			label += " · 需渠水"
		seed_plan_picker.set_item_text(index, label)

func _private_plan_targets(plan: String) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	for item: MAP_GRID_ITEM in map_grid_container.get_children():
		var cell := item.grid_pos
		if not Global.is_public_plot(cell) and Global.can_plan_field_seed(cell) and Global.field_seed_plans.get(cell, "") != plan:
			targets.append(cell)
	return targets

func _refresh_seed_plan_preview() -> void:
	var seed_id: String = "" if seed_plan_picker.selected == 0 else seed_plan_picker.get_selected_metadata()
	var crop := ItemManager.get_crop(seed_id)
	rotate_seed.visible = Global.field_rotation.signed_day > 0
	rotate_seed.disabled = not rotate_seed.visible or crop == null or not FieldSeedPlan.supports_rotation(crop)
	if rotate_seed.disabled:
		rotate_seed.set_pressed_no_signal(false)
	seed_timing.hide()
	if seed_plan_picker.selected == 0:
		apply_private_plan.disabled = true
		apply_private_plan.text = "安排私田"
		seed_plan_note.text = "可选固定作物或按时令续播，再点田格或批量安排私田。"
		return
	var plan := _selected_seed_plan()
	var targets := _private_plan_targets(plan)
	apply_private_plan.disabled = targets.is_empty()
	if seed_id.is_empty():
		apply_private_plan.text = "取消私田 · %d 格" % targets.size()
		seed_plan_note.text = "清除后续的播种安排，田里的作物继续生长。"
		return
	apply_private_plan.text = "安排私田 · %d 格" % targets.size()
	_show_seed_timing(plan, crop)
	if targets.is_empty():
		seed_plan_note.text = "点田格可调整单格。批量范围为当前井田的已翻私田。"
		return
	var open_plots := 0
	var after_harvest := 0
	var waiting_for_water := 0
	var changed_seed := 0
	var needs_canal := crop != null and crop.is_water_crop
	for cell in targets:
		var occupied := Global.active_crops.has(cell)
		if occupied:
			after_harvest += 1
		if needs_canal and Global.next_seed_for_plan(cell, plan) == seed_id and not Global.irrigation.supplies(cell):
			waiting_for_water += 1
		elif not occupied:
			open_plots += 1
		if Global.field_seed_plans.has(cell):
			changed_seed += 1
	var details := PackedStringArray()
	if open_plots > 0:
		details.append("%d 格空畦可播" % open_plots)
	if after_harvest > 0:
		details.append("%d 格收后补播" % after_harvest)
	if waiting_for_water > 0:
		details.append("%d 格待渠水" % waiting_for_water)
	if changed_seed > 0:
		details.append("含 %d 格改种" % changed_seed)
	seed_plan_note.text = " · ".join(details)

func _show_seed_timing(plan: String, crop: CropData) -> void:
	if plan == FieldSeedPlan.SEASONAL:
		seed_timing.text = "春菽 · 夏稻（无渠水种黍） · 秋稷 · 冬麦"
		seed_timing.show()
		return
	var tomorrow := Global.current_day + 1
	var nights := Global.sowing_nights(crop)
	var next_nights := Global.sowing_nights(crop, tomorrow)
	if FieldSeedPlan.is_rotation(plan):
		var beans := ItemManager.get_crop(FieldSeedPlan.BEANS)
		seed_timing.text = "菽 %d 夜 → %s %d 夜 · 收菽留肥，下茬多收一份" % [Global.sowing_nights(beans), crop.crop_name, nights]
		if nights != next_nights:
			seed_timing.text += "\n明日%s播%s需 %d 夜" % [Global.get_current_solar_term(tomorrow), crop.crop_name, next_nights]
		seed_timing.show()
	elif nights != next_nights:
		seed_timing.text = "明日%s播种需 %d 夜" % [Global.get_current_solar_term(tomorrow), next_nights]
		seed_timing.show()

func _apply_private_seed_plan() -> void:
	var plan := _selected_seed_plan()
	var targets := _private_plan_targets(plan)
	for cell in targets:
		Global.set_field_seed_plan(cell, plan)
	_refresh_field_tiles()
	if FieldSeedPlan.is_rotation(plan):
		seed_plan_note.text = "已安排 %d 格私田轮作" % targets.size()
	elif plan == FieldSeedPlan.SEASONAL:
		seed_plan_note.text = "已安排 %d 格私田按时令续播" % targets.size()
	else:
		seed_plan_note.text = ("已取消 %d 格私田的续播" if plan.is_empty() else "已安排 %d 格私田的续播") % targets.size()
