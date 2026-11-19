extends SceneTree

const STEP := 1.0 / 60.0
const MINIMUM_HOLD := {"arrival": 3.0, "handoff": 3.5, "farewell": 5.15, "fields": 3.1}

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	paused = true
	var state := root.get_node("Global")
	for traditional: bool in [true, false]:
		var record := {
			"outcome": state.Outcome.TRADITIONAL if traditional else state.Outcome.REFORMED,
			"date": "第 2 年 · 冬至",
			"accounts": [{"label": "国库", "value": 42}],
			"memories": []
		}
		if traditional:
			record["farewell"] = {"speaker": "渠伯", "line": "明早你提桶，我去田边等你。"}
		state.ending_record = record
		if not _expect(change_scene_to_file(state.ESTATE_SCENE) == OK, "Mount the ending scenery."):
			quit(1)
			return
		await scene_changed
		var ending: Control = current_scene.get_node("CampaignHUD")._add_ending_panel()
		ending.present(current_scene.get_node("World"), false)
		_check_timeline(ending, true, traditional)
		ending._play()
		_check_timeline(ending, false, traditional)
		ending._play()
		ending.skip_button.pressed.emit()
		_expect(ending.report.visible and not ending.film.visible and not ending.motion.is_valid(),
			"Skipping a replay opens the report immediately and stops the film.")
		ending.queue_free()
		await process_frame
	_expect(state.saved_games().is_empty(), "Presenting the fixture must not create campaign saves.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_timeline(ending: Control, first_view: bool, has_guest: bool) -> void:
	var timeline: Tween = ending.motion
	timeline.pause()
	var durations: Dictionary[String, float] = {}
	var sequence: Array[String] = []
	var arrival_line := ""
	for frame in range(24 * 60):
		if ending.report.visible:
			break
		var phase: String
		match ending.shot:
			ending.Shot.FIELD:
				phase = "fields"
			ending.Shot.CEREMONY:
				if arrival_line.is_empty():
					arrival_line = ending.caption.text
				phase = "arrival" if ending.caption.text == arrival_line else "handoff"
			ending.Shot.FAREWELL:
				phase = "farewell"
		if sequence.is_empty() or phase != sequence.back():
			sequence.append(phase)
		durations[phase] = durations.get(phase, 0.0) + STEP
		timeline.custom_step(STEP)
	var expected: Array[String] = ["arrival", "handoff"]
	if has_guest:
		expected.append("farewell")
	if first_view:
		expected.append("fields")
	else:
		expected.push_front("fields")
	_expect(sequence == expected and ending.report.visible, "The film plays each shot and ends at the report.")
	for phase in expected:
		var seconds: float = durations.get(phase, 0.0)
		_expect(seconds >= MINIMUM_HOLD[phase], "%s subtitle only stayed visible for %.2f seconds." % [phase, seconds])

func _expect(ok: bool, detail: String) -> bool:
	if not ok:
		failed = true
		push_error(detail)
	return ok
