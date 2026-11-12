extends Node2D

const FISHING_PANEL := preload("res://scripts/FishingPanel.gd")
const RAVINE_DIRECTIONS := preload("res://scripts/RavineDirections.gd")
const RAVINE_MAP := preload("res://scenes/RavineMap.tscn")
const LANDSCAPE := preload("res://scripts/Landscape.gd")
const RAFT_TRIAL := preload("res://scenes/RaftTrial.tscn")
const SETTINGS_PANEL := preload("res://scripts/SettingsPanel.gd")

@onready var raft_landing: RaftLanding = $RaftLanding
var ravine_map: Control
var settings: Panel

func _ready() -> void:
	if not MapTravel.active:
		$Player.arrive_at($WestArrival)
	GameEvents.fishing_requested.connect(_on_fishing_requested)
	raft_landing.trial_requested.connect(_open_raft_trial)
	var directions := RAVINE_DIRECTIONS.new()
	directions.name = "RavineDirections"
	directions.player = $Player
	add_child(directions)
	ravine_map = RAVINE_MAP.instantiate()
	$CampaignHUD.view.add_child(ravine_map)
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
	ravine_map.setup(directions, $Player, $Landscape, destinations)
	_setup_settings($CampaignHUD.view)
	$FishingUI/CreekTrapPanel.route_requested.connect(ravine_map.follow_place)
	var goal := Global.ravine_trip_target
	var saved_waypoint := Global.restored_ravine_waypoint
	Global.restored_ravine_waypoint = ""
	var continue_route := Callable()
	if destinations.has(goal):
		continue_route = directions.follow.bind(goal, destinations[goal])
	elif not Global.market_trip_target.is_empty():
		continue_route = ravine_map.follow_market.bind(Global.market_trip_target)
	elif not saved_waypoint.is_empty():
		continue_route = ravine_map.restore_waypoint.bind(saved_waypoint)
	if continue_route.is_valid():
		if MapTravel.active:
			MapTravel.finished.connect(continue_route, CONNECT_ONE_SHOT)
		else:
			continue_route.call_deferred()

func active_waypoint() -> String:
	return ravine_map.guide.destination_name

func _setup_settings(view: Control) -> void:
	var button := Button.new()
	button.name = "SettingsButton"
	button.text = "设置"
	button.tooltip_text = "系统设置  Esc"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	view.add_child(button)
	view.move_child(button, ravine_map.get_index())
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -246.0
	button.offset_right = -162.0
	button.offset_top = 16.0
	button.offset_bottom = 53.0
	button.pressed.connect(_open_settings)

	var shade := ColorRect.new()
	shade.color = Color(0.064, 0.101, 0.083, 0.68)
	shade.hide()
	view.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings = SETTINGS_PANEL.new()
	settings.name = "Settings"
	settings.save_resume_hint = "从竹涧西门继续"
	settings.hide()
	view.add_child(settings)
	settings.visibility_changed.connect(func():
		var open := settings.visible
		shade.visible = open
		get_tree().paused = open
		GameEvents.settings_visibility_changed.emit(open)
		if open:
			settings.close_button.grab_focus()
	)

func _open_settings() -> void:
	if not get_tree().paused and not MapTravel.active and Global.outcome == Global.Outcome.RUNNING:
		settings.show()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_open_settings()
		get_viewport().set_input_as_handled()

func _on_fishing_requested(spot: Node2D) -> void:
	if MapTravel.active or $FishingUI.has_node("FishingPanel") or not Global.cast_fishing_line():
		return
	var panel := FISHING_PANEL.new()
	panel.name = "FishingPanel"
	panel.spot = spot
	panel.angler = $Player
	panel.market_route = ravine_map.follow_market
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
