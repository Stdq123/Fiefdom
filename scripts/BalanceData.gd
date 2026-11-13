extends Resource
class_name BalanceData

## 游戏平衡配置 - 统一管理所有平衡参数
## 修改此文件可调整游戏难度和经济平衡

# ==================== 作物配置 ====================
@export_group("Crop Settings")

## 作物基础价格倍率
@export var crop_price_multiplier: float = 1.0

## 作物生长速度倍率
@export var crop_growth_speed: float = 1.0

# 具体作物配置
@export var millet_price: int = 5
@export var millet_growth_days: int = 2

@export var sorghum_price: int = 7
@export var sorghum_growth_days: int = 3

@export var rice_price: int = 12
@export var rice_growth_days: int = 4

@export var wheat_price: int = 8
@export var wheat_growth_days: int = 3

@export var beans_price: int = 4
@export var beans_growth_days: int = 2

@export var mulberry_price: int = 15
@export var mulberry_growth_days: int = 5

@export var hemp_price: int = 6
@export var hemp_growth_days: int = 2

# ==================== 门客配置 ====================
@export_group("Retainer Settings")

## 门客初始忠诚度范围
@export var retainer_loyalty_min: int = 50
@export var retainer_loyalty_max: int = 100

## 门客初始效率范围
@export var retainer_efficiency_min: float = 0.8
@export var retainer_efficiency_max: float = 1.5

## 学派效率加成
@export var confucian_efficiency_bonus: float = 1.0
@export var mohist_efficiency_bonus: float = 1.2
@export var legalist_efficiency_bonus: float = 1.15
@export var agrarian_efficiency_bonus: float = 1.5
@export var military_efficiency_bonus: float = 1.3

## 儒家忠诚光环效果（每日增长百分比）
@export var confucian_loyalty_aura: float = 0.3

@export_range(0, 10) var specialist_food_per_night: int = 1
@export_range(0.5, 20.0, 0.1) var away_field_work_seconds: float = 3.0
@export_range(0, 10) var mohist_reel_bonus: int = 1
@export_range(0, 100) var confucian_teaching_reputation: int = 6
@export_range(0, 100) var confucian_teaching_rites_xp: int = 5

# ==================== 经济系统 ====================
@export_group("Economy Settings")

## 基础税率（0.0-1.0）
@export var base_tax_rate: float = 0.2

## 初税亩改革后税率（法家路线）
@export var reformed_tax_rate: float = 0.2

## 交易基础价格
@export var trade_base_price: int = 5
@export_range(1, 10000) var market_crop_price: int = 5
@export_range(1, 10000) var market_food_price: int = 5
@export_range(0, 10000) var season_order_copper_bonus: int = 6
@export_range(0, 100) var season_order_food_bonus: int = 2
@export_range(0, 10000) var fish_order_copper_bonus: int = 4
@export_range(0, 100) var fish_order_food_bonus: int = 2
@export_range(1, 100) var bean_millet_stamina: int = 32
@export_range(1, 100) var rice_fish_stamina: int = 18
@export_range(1, 100) var rice_fish_health: int = 28
@export_range(0, 100) var autumn_exhibit_rites: int = 30
@export_range(0, 100) var autumn_share_reputation: int = 15
@export_range(0, 100) var summer_raft_driving: int = 30
@export_range(1, 100) var winter_bean_rations: int = 3
@export_range(1, 100) var winter_fish_rations: int = 5
@export_range(0, 100) var winter_supper_rites: int = 20
@export_range(0, 10000) var road_rest_cost: int = 12
@export_range(1, 100) var road_rest_stamina: int = 18

## 招募门客所需声望
@export var recruit_reputation_requirement: int = 20

## 声望获得倍率
@export var reputation_gain_multiplier: float = 1.0

@export_group("Silk Production")
@export_range(1, 100) var mulberry_leaves_per_harvest: int = 4
@export_range(0, 10000) var silk_workshop_cost: int = 25
@export_range(1, 100) var silk_leaves_per_night: int = 2
@export_range(1, 30) var silk_batch_nights: int = 2
@export_range(1, 100) var silk_cocoons_per_batch: int = 2
@export_range(1, 100) var silk_thread_per_cocoon: int = 2
@export_range(1, 100) var silk_thread_per_bolt: int = 4
@export_range(0, 10000) var silk_sell_price: int = 35
@export_range(0, 1000) var silk_sample_bonus: int = 10
@export_range(0, 10000) var silk_offer_reputation: int = 30

# ==================== 惩罚系统 ====================
@export_group("Penalty Settings")

## 未贡献公共田的每日声望惩罚
@export var no_contribution_penalty: int = 8

## 连续未贡献天数阈值
@export var no_contribution_threshold: int = 5

## 削爵声望阈值
@export var rank_strip_threshold: int = -100

@export_group("Combat")
@export_range(1, 1000) var player_max_health: int = 100
@export_range(0, 1000) var health_recovery_at_night: int = 20
@export_range(1, 1000) var wild_dog_damage: int = 12
@export_range(1, 1000) var scout_arrow_damage: int = 15
@export_range(0.1, 3.0, 0.05) var dog_bite_windup := 0.55
@export_range(0.1, 3.0, 0.05) var scout_shot_windup := 0.75
@export_range(0.1, 4.0, 0.05) var raid_crop_windup := 1.2
@export_range(0.5, 5.0, 0.1) var raid_snare_seconds := 2.4
@export_range(0.1, 5.0, 0.05) var enemy_recovery := 1.65
@export_range(1, 10000) var raid_first_day: int = 9
@export_range(1, 10000) var raid_interval_days: int = 8
@export_range(1, 100) var wild_food_yield: int = 5
@export_range(1, 100) var wild_herb_healing: int = 18
@export_range(1, 100) var fishing_stamina_cost: int = 5
@export_range(1, 30) var herb_garden_regrowth_days: int = 3

# ==================== 井田系统 ====================
@export_group("Well-Field Settings")

## 井田最小间距限制
@export var well_field_min_distance: int = 4

## 开垦消耗
@export var reclamation_cost_copper: int = 70
@export var reclamation_cost_food: int = 30

## 每格水渠的建造费用
@export_range(0, 100) var irrigation_channel_cost: int = 4
@export_range(0, 100) var irrigation_field_gate_cost: int = 12

@export_group("Rank Progression")
@export var middle_rank_reputation: int = 100
@export var upper_rank_reputation: int = 180
@export var grandee_rank_reputation: int = 320
@export var minister_rank_reputation: int = 700
@export var upper_rank_art_level: int = 3
@export var minister_rank_art_level: int = 5

# ==================== 事件系统 ====================
@export_group("Event Settings")

## 公共田产出比例阈值（触发初税亩事件）
@export var public_field_ratio_threshold: float = 0.3

## 历史事件研究经费（每月）
@export var research_monthly_cost: int = 100

## 初税亩改革事件忠诚度变化
@export var tax_reform_legalist_loyalty_change: int = -50
@export var tax_reform_confucian_loyalty_change: int = 30
@export_range(1, 1000) var ending_traditional_tribute: int = 6
@export_range(1, 1000) var ending_reformed_private: int = 12
@export_range(0, 10000) var ending_reformed_wealth: int = 180
@export_range(1, 100) var ending_silk_target: int = 1
@export_range(1, 100) var ending_raids_min: int = 1

@export_group("Sheepfold")
@export_range(0, 10000) var sheep_price := 100
@export_range(1, 30) var sheep_wool_nights := 10
@export_range(0, 10000) var sheep_wool_price := 36
@export_range(0, 10000) var sheep_fodder_price := 6
@export_range(1, 30) var sheep_fodder_bundle := 3
@export_range(1, 12) var sheep_meadow_yield := 2
@export_range(1, 30) var sheep_coat_wool := 2

# ==================== 六艺系统 ====================
@export_group("Six Arts Settings")
@export_range(1, 500) var literacy_study_xp: int = 50

## 交互获得的经验值
@export var interaction_xp_gain: int = 10

## 交互获得声望
@export var interaction_reputation_gain: int = 5

# ==================== 时间系统 ====================
@export_group("Time Settings")

## 一年天数
@export var days_per_year: int = 24

## 节气数量
@export var solar_terms_count: int = 24

## 每个节气的天数
@export var days_per_solar_term: int = 1
@export_range(0, 3) var seasonal_growth_reduction := 1

## 从卯时到亥时所需的游玩秒数
@export_range(15.0, 600.0, 1.0) var daylight_seconds := 150.0

## 下雨并为旱作供水的节气
@export var rain_solar_term: String = "谷雨"
