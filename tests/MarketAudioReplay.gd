extends "res://tests/WestMarketReplay.gd"

const SOUNDS := "res://assets/audio/market/"
const RECEIVED := "coins-received.wav"
const PURCHASED := "purchase.wav"
const STORED := "grain-stored.wav"

var previous_release := false
var cues: Array[Dictionary] = []
var sampled: Array[String] = []

func _play() -> void:
	if DisplayServer.get_name() == "headless":
		await super._play()
		return
	tree.node_added.connect(_listen)
	await super._play()
	tree.node_added.disconnect(_listen)
	_expect(sampled.size() == 6, "Record six transactions across the three stalls.")
	_expect(cues.size() == (0 if previous_release else sampled.size()),
		"Opening counters, trying a sold-out offer and continuing the sale do not play a transaction cue.")

func _listen(node: Node) -> void:
	var sound := node as AudioStreamPlayer
	if sound and sound.stream and sound.stream.resource_path.begins_with(SOUNDS):
		cues.append({"name": sound.stream.resource_path.get_file(), "bus": sound.bus})

func _trade_sample(button: Button) -> Array[String]:
	var market := tree.current_scene
	if market.scene_file_path != state.WEST_MARKET_SCENE:
		return []
	var counter: Control = market.counter
	if button == counter.grain.sell_button:
		return ["grain-sale", RECEIVED]
	if button == counter.grain.convert_button:
		return ["grain-to-stores", STORED]
	if button == counter.grain.buy_button:
		return ["buy-grain", PURCHASED]
	if button == counter.market_produce:
		return ["buy-produce", PURCHASED]
	if button == counter.sell_silk:
		return ["silk-sale", RECEIVED]
	for row: Dictionary in counter.fish.rows.values():
		if button == row.sell:
			return ["fish-sale", RECEIVED]
	return []

func _button(button: Button) -> void:
	var sample: Array[String] = _trade_sample(button) if DisplayServer.get_name() != "headless" else []
	if sample.is_empty():
		await super._button(button)
		return
	await tree.create_timer(0.18).timeout
	var bus := AudioServer.get_bus_index(&"SFX")
	var position := AudioServer.get_bus_effect_count(bus)
	var recording := AudioEffectRecord.new()
	recording.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, recording)
	recording.set_recording_active(true)
	var earlier := cues.size()
	await super._button(button)
	await tree.create_timer(0.55).timeout
	recording.set_recording_active(false)
	var wave := recording.get_recording()
	AudioServer.remove_bus_effect(bus, position)
	sampled.append(sample[0])
	_check_mix(sample[0], sample[1], earlier, wave)
	if button == tree.current_scene.counter.market_produce:
		var copper: int = state.money
		var last_sound := cues.size()
		await _click(button.get_global_rect().get_center())
		_expect(button.disabled and state.money == copper and cues.size() == last_sound,
			"Trying to buy sold-out produce is silent and does not charge again.")

func _check_mix(label: String, sound: String, earlier: int, wave: AudioStreamWAV) -> void:
	var peak := 0
	_expect(wave != null and wave.get_length() >= 0.46, "Record the complete mixer interval for " + label)
	if wave != null:
		var samples := wave.data
		for index in range(0, samples.size() - 1, 2):
			peak = maxi(peak, absi(samples.decode_s16(index)))
		if not capture_dir.is_empty():
			_expect(wave.save_to_wav(capture_dir.path_join(label + ".wav")) == OK, "Save the actual SFX mix for " + label)
	if previous_release:
		_expect(cues.size() == earlier, "The previous pack has no transaction recording for " + label)
	else:
		_expect(cues.size() == earlier + 1 and cues.back() == {"name": sound, "bus": &"SFX"},
			"Play one material sound on the SFX bus for " + label)
		_expect(peak >= 1400 and peak < 18000, "The SFX mix is audible and has headroom for " + label)
	print("MARKET_AUDIO action=", label, " cue=", sound if not previous_release else "previous",
		" peak_dbfs=", snappedf(linear_to_db(maxf(float(peak), 1.0) / 32768.0), 0.01))
