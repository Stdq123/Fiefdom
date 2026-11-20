extends SceneTree

const STALLS := [["GrainStall", "work-grain.wav"], ["FishStall", "work-fish.wav"], ["SilkStall", "work-silk.wav"]]

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the stall audio check with an isolated profile.")
		quit(1)
		return
	var state := root.get_node("Global")
	state.current_day = 1
	state.day_progress = 0.40
	paused = true
	if change_scene_to_file(state.WEST_MARKET_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	var market := current_scene
	market.set_process(false)
	market.dyer.set_process(false)
	var player := market.get_node("Player") as CharacterBody2D
	player.set_physics_process(false)
	for stall in market.get_node("Stalls").get_children():
		stall.set_process(false)
	paused = false
	var ears := player.get_node("MarketListener") as AudioListener2D
	_expect(ears.is_current(), "West Market listens from the walking character even where the camera is clamped.")
	var before := [state.current_day, state.money, state.food_storage, hash(state.crop_stock.lots)]
	for entry in STALLS:
		var stall := market.get_node("Stalls/" + entry[0])
		var sound: AudioStreamPlayer2D = stall.work_sound
		var variants := sound.stream as AudioStreamRandomizer
		var sample := variants.get_stream(0) as AudioStreamWAV
		_expect(sound.bus == &"Ambience" and AudioServer.get_bus_index(sound.bus) > 0
			and sample.resource_path.get_file() == entry[1] and sample.loop_mode == AudioStreamWAV.LOOP_DISABLED
			and sample.get_length() >= 0.45, "Each keeper has a distinct short material sound on Ambience.")
		player.global_position = stall.to_global(Vector2(0, 160))
		_set_down(stall)
		_expect(not sound.playing, "A distant keeper does not start a sound.")
		player.global_position = stall.to_global(Vector2(0, 38))
		_set_down(stall)
		_expect(sound.playing and sound.volume_linear > 0.0, "The keeper's set down pose starts the nearby foley.")
		sound.stop()
		stall._process(0.01)
		_expect(not sound.playing, "Additional frames of the same pose do not replay the sound.")
		player.conversation_open = true
		_set_down(stall)
		_expect(not sound.playing, "Browsing a counter keeps the work cue quiet.")
		player.conversation_open = false
		print("MARKET_FOLEY ", entry[0], " clip=", sample.resource_path.get_file(), " bus=", sound.bus)
	var silk := market.get_node("Stalls/SilkStall")
	player.global_position = silk.to_global(Vector2(0, 38))
	var dyer_script: GDScript = market.dyer.get_script()
	state.day_progress = dyer_script.SET_DOWN_AT - 0.004
	market.dyer._follow_clock(false)
	state.day_progress = dyer_script.SET_DOWN_AT + 0.004
	market.dyer._process(0.02)
	_expect(silk.work_sound.playing, "A carried bolt landing on the table uses the silk cue.")
	silk.work_sound.stop()
	market.dyer._follow_clock(false)
	market.dyer._process(0.02)
	_expect(not silk.work_sound.playing, "Starting with a previously displayed bolt does not replay delivery.")
	state.day_progress = 0.40
	_expect(before == [state.current_day, state.money, state.food_storage, hash(state.crop_stock.lots)]
		and state.saved_games().is_empty(), "The crafted audio check leaves goods, date and slots unchanged.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _set_down(stall: Node) -> void:
	var stall_script: GDScript = stall.get_script()
	stall.pose_time = stall_script.WORK_TIMES[stall.kind].y - 0.04
	stall._update_keeper()
	stall._process(0.05)
