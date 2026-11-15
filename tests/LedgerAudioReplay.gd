extends "res://tests/OpeningOrderReplay.gd"

const COUNCIL := preload("res://tests/TaxCouncilReplay.gd")
const FIRST_CUE := "res://assets/audio/ledger/first-tribute.wav"
const TRADITION_CUE := "res://assets/audio/ledger/council-tribute.wav"
const REFORM_CUE := "res://assets/audio/ledger/council-tax.wav"
const RESEARCH_CUE := "res://assets/audio/ledger/council-research.wav"
const CUES := [FIRST_CUE, TRADITION_CUE, REFORM_CUE, RESEARCH_CUE]

var audio_manager: Node
var rendered := false
var heard: Array[Dictionary] = []
var recordings: Dictionary[int, AudioEffectRecord] = {}
var first_sound_index := 0
var score: AudioStreamPlayer
var score_gain := 0.0
var score_position := 0.0
var music_volume := 0.0

func _listen(node: Node) -> void:
	var player := node as AudioStreamPlayer
	if player and player.stream and player.stream.resource_path in CUES:
		heard.append({"path": player.stream.resource_path, "bus": player.bus})

func _begin_recording() -> void:
	if not rendered:
		return
	score = audio_manager.bgm_player
	score_gain = score.volume_linear
	score_position = score.get_playback_position()
	music_volume = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))
	for name in [&"SFX", &"Master"]:
		var bus := AudioServer.get_bus_index(name)
		var record := AudioEffectRecord.new()
		record.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(bus, record)
		record.set_recording_active(true)
		recordings[bus] = record

func _end_recording(label: String, expected: String, before: int, expected_gain: float) -> void:
	if not rendered:
		return
	await tree.create_timer(0.16).timeout
	_expect(heard.size() == before + 1 and heard.back() == {"path": expected, "bus": &"SFX"},
		label + " plays one expected cue on SFX.")
	_expect(score == audio_manager.bgm_player and score.playing and score_gain > 0.28,
		"The same seasonal score stays active during " + label)
	var relative_gain := score.volume_linear / maxf(0.01, score_gain)
	_expect(absf(relative_gain - expected_gain) < 0.11, "Keep the intended music level under " + label)
	await tree.create_timer(1.02).timeout
	for bus: int in recordings:
		var record := recordings[bus]
		record.set_recording_active(false)
		var wave := record.get_recording()
		AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
		var bus_name := AudioServer.get_bus_name(bus)
		if not _expect(wave != null and wave.get_length() >= 0.98, "Record the live " + str(bus_name) + " mix."):
			continue
		var samples := wave.data
		var peak := 0
		for index in range(0, samples.size() - 1, 2):
			peak = maxi(peak, absi(samples.decode_s16(index)))
		_expect(peak >= 800 and peak < 28000, "Leave headroom and hear " + label + " on " + str(bus_name))
		if not capture_dir.is_empty():
			var path := capture_dir.path_join("%s-%s.wav" % [label, bus_name.to_lower()])
			_expect(wave.save_to_wav(path) == OK, "Save the live mix at " + path)
		print("LEDGER_AUDIO_MIX ", label, " bus=", bus_name, " peak_dbfs=", snappedf(linear_to_db(peak / 32768.0), 0.01))
	recordings.clear()
	_expect(score == audio_manager.bgm_player and score.get_playback_position() > score_position + 0.7
		and absf(score.volume_linear - score_gain) < 0.012
		and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")), music_volume),
		"The same music resumes at its usual gain and the Music setting is preserved.")
	print("LEDGER_AUDIO_CUE ", label, " day=", state.current_day, " gain=", snappedf(relative_gain, 0.01))

func _start_at_first_harvest(harvest: Dictionary, _worker: String) -> void:
	if harvest.first_tribute:
		first_sound_index = heard.size()
		_begin_recording()

func _opening() -> void:
	await _button(tree.current_scene.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	_bind_estate()
	GameEvents.harvest_receipt.connect(_start_at_first_harvest)
	await _harvest_first_crops()
	GameEvents.harvest_receipt.disconnect(_start_at_first_harvest)
	_expect(state.current_day == 3 and state.king_storage == 1 and state.crop_stock.count("millet") == 1,
		"A normal new game produces one public and one private harvest on day three.")
	await _end_recording("01-first-tribute", FIRST_CUE, first_sound_index, 0.70)
	await _snapshot("01-after-first-tribute")
	var after := heard.size()
	if await _continue(state.ESTATE_SCENE):
		_expect(state.king_storage == 1 and state.current_day == 3 and heard.size() == after,
			"Continuing restores the contribution without replaying the tribute cue.")

func _check_council(choice: int, fixture: String, label: String, expected: String, gain: float) -> void:
	if not _expect(state.load_game(fixture) == OK, "Open an eligible council checkpoint."):
		return
	await tree.scene_changed
	await tree.process_frame
	_bind_estate()
	for actor in world.retainer_instances.values():
		actor.set_physics_process(false)
	var panel := await Campaign.meet_tax_envoy(tree)
	if not _expect(panel != null and tree.paused and panel.option_buttons.has(choice), "Walk up to the real council meeting."):
		return
	var before := heard.size()
	await _button(panel.option_buttons[choice])
	_expect(heard.size() == before and state.tax_reform_choice == state.TaxReformChoice.NONE,
		"Previewing a choice is silent and leaves the council unresolved.")
	_begin_recording()
	await _button(panel.confirm_button)
	_expect(state.tax_reform_choice == choice and not tree.paused, "Confirm the actual council choice.")
	await _end_recording(label, expected, before, gain)
	var after := heard.size()
	var checkpoint: Dictionary = state.latest_saved_game(true)
	if not _expect(not checkpoint.is_empty() and state.load_game(checkpoint.path) == OK, "Reload the council autosave."):
		return
	await tree.scene_changed
	await tree.process_frame
	_expect(state.tax_reform_choice == choice and heard.size() == after, "Reload the decision without replaying its cue.")

func run_ledger_audio(game_tree: SceneTree, output := "") -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated ledger audio profile."):
		tree.quit(1)
		return
	capture_dir = output
	state = tree.root.get_node("Global")
	audio_manager = tree.root.get_node("AudioManager")
	rendered = DisplayServer.get_name() != "headless"
	audio_manager.child_entered_tree.connect(_listen)
	tree.root.notify_mouse_entered()
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _opening()
	if not failed:
		state.balance.raid_first_day = 10000
		var fixture := "user://ledger-audio-council.json"
		var file := FileAccess.open(fixture, FileAccess.WRITE)
		file.store_string(JSON.stringify(COUNCIL.SNAPSHOT))
		file.close()
		await _check_council(state.TaxReformChoice.TRADITIONAL, fixture, "02-traditional", TRADITION_CUE, 0.70)
		await _check_council(state.TaxReformChoice.REFORMED, fixture, "03-reformed", REFORM_CUE, 0.70)
		await _check_council(state.TaxReformChoice.DELAYED, fixture, "04-research", RESEARCH_CUE, 1.0)
	audio_manager.child_entered_tree.disconnect(_listen)
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
