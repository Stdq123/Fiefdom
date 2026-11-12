extends Node2D

const FISHING_PANEL := preload("res://scripts/FishingPanel.gd")
const RAVINE_DIRECTIONS := preload("res://scripts/RavineDirections.gd")
const RAVINE_MAP := preload("res://scenes/RavineMap.tscn")
const LANDSCAPE := preload("res://scripts/Landscape.gd")
const RAFT_TRIAL := preload("res://scenes/RaftTrial.tscn")

@onready var raft_landing: RaftLanding = $RaftLanding

func _ready() -> void:
	GameEvents.fishing_requested.connect(_on_fishing_requested)
	raft_landing.trial_requested.connect(_open_raft_trial)
	var directions := RAVINE_DIRECTIONS.new()
	directions.name = "RavineDirections"
	directions.player = $Player
	add_child(directions)
	var map := RAVINE_MAP.instantiate()
	$CampaignHUD.view.add_child(map)
	var destinations: Dictionary[String, Vector2] = {
		"西门回封地": $ExitArea.position,
		"野果坳": $WildFruit.position,
		"木桥": LANDSCAPE.BRIDGE,
		"浅滩": LANDSCAPE.FORD,
		"望溪台": $WildHerbs.position,
		"柳湾": $WillowPool.position,
		"砾滩": $GravelShoal.position,
		SummerRaft.PLACE: raft_landing.position,
		CreekTrap.PLACES[CreekFish.Site.POOL]: $PoolTrap.position,
		CreekTrap.PLACES[CreekFish.Site.SHOAL]: $ShoalTrap.position,
	}
	map.setup(directions, $Player, destinations)
	$FishingUI/CreekTrapPanel.route_requested.connect(map.follow_place)
	var goal := Global.ravine_trip_target
	if destinations.has(goal):
		var continue_route := directions.follow.bind(goal, destinations[goal])
		if MapTravel.active:
			MapTravel.finished.connect(continue_route, CONNECT_ONE_SHOT)
		else:
			continue_route.call_deferred()

func _on_fishing_requested(spot: Node2D) -> void:
	if MapTravel.active or $FishingUI.has_node("FishingPanel") or not Global.cast_fishing_line():
		return
	var panel := FISHING_PANEL.new()
	panel.name = "FishingPanel"
	panel.spot = spot
	panel.angler = $Player
	$FishingUI.add_child(panel)

func _open_raft_trial() -> void:
	if get_tree().paused or MapTravel.active or Global.outcome != Global.Outcome.RUNNING:
		return
	var trial := RAFT_TRIAL.instantiate()
	trial.landing = raft_landing
	trial.player = $Player
	trial.trail_hud = $CampaignHUD.view
	trial.pool_hint = $WillowPool.hint
	add_child(trial)
