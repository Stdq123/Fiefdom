extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		quit(1)
		return
	paused = true
	var state := root.get_node("Global")
	state.silk_workshop.built = true
	state.silk_workshop.nights_left = 2
	state.silk_workshop.cocoons = 3
	state.silk_workshop.raw_silk = 6
	state.silk_workshop.bolts = 2
	state.estate_room = state.EstateRoom.SILK_SHED
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var world := current_scene.get_node("World")
	var room := world.get_node("SilkInterior") as Node2D
	var actor = world.player
	_expect(room.visible, "Load the restored workshop without advancing the day.")
	var before := _workshop(state)
	for name in ["SilkwormTray", "Reel", "Loom"]:
		var station := room.get_node(name) as Node2D
		var foot := room.to_global(Vector2(station.position.x, 20.0))
		actor.arrive_at_position(foot, Vector2.UP)
		_check_stroke(station, actor)
		var motion: Tween = station.movement
		motion.custom_step(0.6)
		_expect(not actor.silk_hands.visible and actor.sprite.frame_coords.x == 0
			and actor.global_position == foot and station.phase == 1.0, "The actor returns to standing at the same spot.")
	var reel := room.get_node("Reel") as Node2D
	actor.arrive_at_position(room.to_global(Vector2(0, 20)), Vector2.UP)
	reel._present_work()
	actor.position.x += 2.0
	actor._update_walk_sprite(Vector2.RIGHT, Vector2(2, 0))
	_expect(not actor.silk_hands.visible, "Walking immediately clears the hand pose.")
	reel.movement.custom_step(0.25)
	_expect(not actor.silk_hands.visible and reel.phase < 1.0, "The wheel can finish after the actor steps away.")
	reel.movement.custom_step(0.6)
	reel._present_work()
	room.hide()
	_expect(not actor.silk_hands.visible and reel.phase == 1.0 and not reel.movement.is_running(),
		"Leaving the room stops the brief visual action.")
	_expect(before == _workshop(state) and state.saved_games().is_empty(), "The fixture uses neither resources nor campaign saves.")
	current_scene.queue_free()
	await process_frame
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_stroke(station: Node2D, actor: Node2D) -> void:
	station._present_work()
	var motion: Tween = station.movement
	motion.custom_step(0.06)
	_expect(actor.silk_hands.station == station and actor.sprite.frame_coords == Vector2i(PlayerAttire.WORK_COLUMN, actor.Facing.BACK),
		"The standing actor reaches toward the active station.")
	motion.custom_step(0.08)
	var point: Vector2
	match station.action:
		SilkWorkshop.Action.START_BATCH: point = station.TRAY_HAND
		SilkWorkshop.Action.REEL: point = station._reel_handle()
		SilkWorkshop.Action.WEAVE: point = Vector2(8, station._beater_height())
	var hand: Vector2 = actor.silk_hands.to_global(actor.silk_hands.working_hand)
	_expect(hand.distance_to(station.to_global(point)) < 1.0
		and actor.sprite.frame_coords == Vector2i(PlayerAttire.WORK_COLUMN + 1, actor.Facing.BACK)
		and actor.silk_hands.sleeve == actor.tool_gesture.sleeve,
		"The active hand meets %s on the braced frame in the current sleeves." % station.name)

func _workshop(state: Node) -> Array:
	var silk = state.silk_workshop
	return [state.current_day, state.day_progress, state.current_stamina, state.money,
		silk.nights_left, silk.leaves, silk.cocoons, silk.raw_silk, silk.bolts]

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
