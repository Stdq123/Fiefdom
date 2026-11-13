extends Panel

@onready var title_label = $TitleLabel
@onready var day_label = $VBoxContainer/DayLabel
@onready var money_label = $VBoxContainer/MoneyLabel
@onready var food_label = $VBoxContainer/FoodLabel
@onready var reputation_label = $VBoxContainer/ReputationLabel
@onready var rank_label = $VBoxContainer/RankLabel

@onready var add_money_btn = $VBoxContainer/AddMoneyButton
@onready var add_food_btn = $VBoxContainer/AddFoodButton
@onready var add_rep_btn = $VBoxContainer/AddRepButton
@onready var promote_btn = $VBoxContainer/PromoteButton
@onready var trigger_event_btn = $VBoxContainer/TriggerEventButton
@onready var add_retainer_btn = $VBoxContainer/AddRetainerButton
@onready var toggle_visibility_btn = $ToggleVisibilityButton

var is_visible: bool = true

func _ready() -> void:
	title_label.text = "DEBUG面板"

	add_money_btn.pressed.connect(_on_add_money)
	add_food_btn.pressed.connect(_on_add_food)
	add_rep_btn.pressed.connect(_on_add_reputation)
	promote_btn.pressed.connect(_on_promote)
	trigger_event_btn.pressed.connect(_on_trigger_event)
	add_retainer_btn.pressed.connect(_on_add_retainer)
	toggle_visibility_btn.pressed.connect(_on_toggle_visibility)

	update_debug_info()

func _process(_delta: float) -> void:
	if is_visible:
		update_debug_info()

func update_debug_info() -> void:
	day_label.text = "Day: %d" % Global.current_day
	money_label.text = "Money: %d" % Global.money
	food_label.text = "Food: %d" % Global.food_storage
	reputation_label.text = "Reputation: %d" % Global.reputation

	var rank_name = Global.rank_names.get(Global.current_rank, "Unknown")
	rank_label.text = "Rank: %s" % rank_name

func _on_add_money() -> void:
	Global.money += 1000
	GameEvents.money_changed.emit(Global.money)
	print("Debug: Added 1000 money")

func _on_add_food() -> void:
	Global.food_storage += 100
	GameEvents.food_changed.emit(Global.food_storage)
	print("Debug: Added 100 food")

func _on_add_reputation() -> void:
	Global.reputation += 500
	GameEvents.reputation_changed.emit(Global.reputation)
	print("Debug: Added 500 reputation")

func _on_promote() -> void:
	var current_idx = Global.current_rank
	if current_idx < Global.Rank.size() - 1:
		Global.current_rank = (current_idx + 1) as Global.Rank
		Global._update_max_well_fields()
		GameEvents.rank_changed.emit(Global.current_rank)
		print("Debug: Promoted to ", Global.rank_names[Global.current_rank])

func _on_trigger_event() -> void:
	# Set up conditions for tax reform event
	Global.current_day = maxi(1, Global.balance.days_per_year) * 2 + 1
	Global.current_rank = Global.Rank.DA_FU
	Global.king_storage = 30
	Global.player_inventory = 70
	Global.private_harvest_total = 70
	GameEvents.inventory_changed.emit(Global.player_inventory)

	print("Debug: Triggering tax reform event...")
	print("  - Day: %d (Year 3)" % Global.current_day)
	print("  - Rank: %s" % Global.rank_names[Global.current_rank])
	print("  - Public/Private ratio: %.0f%%" % [30.0 / (30.0 + 70.0) * 100])

	EventManager.invite_if_eligible()

func _on_add_retainer() -> void:
	var retainer = RetainerData.generate_random()
	Global.retainers.append(retainer)
	GameEvents.retainer_recruited.emit(retainer)
	print("Debug: Added retainer - %s (%s)" % [retainer.name, retainer.get_school_name()])

func _on_toggle_visibility() -> void:
	is_visible = not is_visible
	$VBoxContainer.visible = is_visible
	if is_visible:
		toggle_visibility_btn.text = "收起内容"
	else:
		toggle_visibility_btn.text = "展开内容"
