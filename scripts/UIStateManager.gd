extends Node
class_name UIStateManager

## UI状态管理器 - 负责更新UI显示的游戏状态
## 从UIManager中分离出来的状态管理逻辑

# UI元素引用
var day_label: Label
var inventory_label: Label
var king_label: Label
var stamina_label: Label
var rank_label: Label
var money_label: Label
var well_field_label: Label
var stamina_bar: ProgressBar

func setup(p_day_label: Label, p_inventory_label: Label, p_king_label: Label,
		   p_stamina_label: Label, p_rank_label: Label = null, p_money_label: Label = null,
		   p_well_field_label: Label = null, p_stamina_bar: ProgressBar = null) -> void:
	day_label = p_day_label
	inventory_label = p_inventory_label
	king_label = p_king_label
	stamina_label = p_stamina_label
	rank_label = p_rank_label
	money_label = p_money_label
	well_field_label = p_well_field_label
	stamina_bar = p_stamina_bar

## 更新所有UI元素
func update_all_ui() -> void:
	update_day_label()
	update_inventory_labels()
	update_stamina_display()
	update_rank_display()
	update_money_display()
	update_well_field_display()

## 更新天数标签
func update_day_label() -> void:
	if day_label:
		day_label.text = "第 %d 天" % Global.current_day

## 更新背包和国库标签
func update_inventory_labels() -> void:
	if inventory_label:
		inventory_label.text = "作物 %d · 粮食 %d" % [Global.player_inventory, Global.food_storage]
	if king_label:
		king_label.text = "国库 %d" % Global.king_storage

## 更新体力显示
func update_stamina_display() -> void:
	if stamina_label:
		stamina_label.text = "体力 %d / %d" % [Global.current_stamina, Global.max_stamina]
	if stamina_bar:
		stamina_bar.max_value = Global.max_stamina
		stamina_bar.value = Global.current_stamina

## 更新爵位显示
func update_rank_display() -> void:
	if rank_label:
		rank_label.text = Global.rank_names[Global.current_rank]

## 更新金钱显示
func update_money_display() -> void:
	if money_label:
		money_label.text = "铜钱 %d" % Global.money

## 更新井田显示
func update_well_field_display() -> void:
	if well_field_label:
		well_field_label.text = "井田 %d/%d" % [Global.well_fields.size(), Global.max_well_fields]

## 连接游戏事件信号
func connect_game_events() -> void:
	GameEvents.day_advanced.connect(_on_day_advanced)
	GameEvents.stamina_changed.connect(_on_stamina_changed)
	GameEvents.rank_promoted.connect(_on_rank_promoted)

func _on_day_advanced(new_day: int) -> void:
	update_day_label()

func _on_stamina_changed(new_stamina: int) -> void:
	update_stamina_display()

func _on_rank_promoted(new_rank: Global.Rank) -> void:
	update_rank_display()
	update_well_field_display()
