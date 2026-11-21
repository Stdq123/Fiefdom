extends SceneTree

const STEP := 1.0 / 60.0
const MINIMUM_HOLD := {"arrival": 3.0, "handoff": 3.5, "farewell": 5.15, "fields": 3.1}

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	paused = true
	var state := root.get_node("Global")
	var prefs := root.get_node("Preferences")
	_expect(prefs.set_reading_size(2) == OK, "Use the largest reading size.")
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
		record.memories = _settlement_notes(state) + ["旧档里的长记事也能从头读到末尾。".repeat(26)]
		var ending: Control = current_scene.get_node("CampaignHUD")._add_ending_panel()
		ending.present(current_scene.get_node("World"), false)
		_check_handoff(ending)
		_check_timeline(ending, true, traditional)
		await _check_reading(ending, traditional)
		ending.queue_free()
		await process_frame
	_expect(state.saved_games().is_empty(), "Presenting the fixture must not create campaign saves.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_handoff(ending: Control) -> void:
	ending.motion.pause()
	ending._walk_to_table(1.0)
	var volume: Sprite2D = ending.desk.volume
	ending._offer_volume(0.62)
	_expect(ending.presenter_hands.visible and volume.position == ending.desk.volume_home(),
		"The presenter reaches the binding before the ledger lifts from the desk.")
	ending._offer_volume(1.0)
	var held_at := volume.global_position
	_expect(ending.presenter.position == ending.presenter_at_desk and volume.get_parent() == ending.desk
		and volume.position.y < ending.desk.volume_home().y, "The presenter supports the raised ledger.")
	ending._receive_volume(0.28)
	_expect(volume.global_position.is_equal_approx(held_at) and volume.get_parent() == ending.envoy
		and ending.presenter_hands.visible and ending.palm.visible, "The envoy grips the ledger while it is supported.")
	ending._receive_volume(1.0)
	_expect(not ending.presenter_hands.visible and ending.presenter.position == ending.presenter_start,
		"The presenter releases the ledger and steps back after the transfer.")
	ending._play(true)
	_expect(volume.get_parent() == ending.desk and volume.position == ending.desk.volume_home()
		and not ending.presenter_hands.visible, "Restarting restores the ledger and the neutral pose.")

func _settlement_notes(state: Node) -> Array[String]:
	var stories = load("res://scripts/PavilionStories.gd")
	var day := 8
	for story: String in stories.IDS:
		state.pavilion_stories_heard[story] = day
		day += 4
	var field: Vector2i = state.well_fields[0].center_pos
	var channels: Array[Vector2i] = [field + Vector2i(-3, 0), field + Vector2i(-2, 0)]
	state.irrigation.add_channels(channels)
	state.irrigation.set_field_gate(field, field + Vector2i(-2, 0))
	state.silk_workshop.built = true
	var notes: Array[String] = state._ending_memories()
	var summary := "%d 块井田已经耕成，%d 位门客留任。" % [1, state.retainers.size()]
	var newest: Array = stories.IDS.duplicate()
	newest.reverse()
	_expect(notes.size() >= 3 and notes[0] == stories.STORIES[newest[0]].memory
		and notes[1] == stories.STORIES[newest[1]].memory and notes[2] == stories.STORIES[newest[2]].memory
		and stories.STORIES[newest[3]].memory not in notes, "Keep the three most recent stories in their reading order.")
	_expect(summary in notes and "渠水已送到 1 块井田。" in notes
		and "蚕室已能养蚕、缫丝和织绸。" in notes, "A full set of stories leaves room for the estate holdings.")
	print("ENDING_NOTES stored=", notes.size(), " holdings=", summary in notes, " irrigation=", state.irrigated_well_fields())
	return notes

func _check_reading(ending: Control, traditional: bool) -> void:
	await _settle_layout()
	var scroll: ScrollContainer = ending.report_scroll
	var notes := ending.get_node("%Notes") as Control
	_expect(scroll.scroll_vertical == 0 and ending.continue_button.has_focus(), "The first view opens at the top of the report.")
	_expect(notes.get_global_rect().position.y >= ending.results.get_global_rect().end.y
		and notes.size.x >= scroll.size.x - 32.0, "At the largest text size, the memories use the full reading width below the accounts.")
	var page := InputEventKey.new()
	page.pressed = true
	page.keycode = KEY_PAGEDOWN
	root.push_input(page, true)
	await _settle_layout()
	var reading_position := scroll.scroll_vertical
	_expect(reading_position > 0, "Page Down reads further into the settlement.")
	ending.replay_button.pressed.emit()
	_check_timeline(ending, false, traditional)
	await _settle_layout()
	_expect(scroll.scroll_vertical == reading_position and ending.replay_button.has_focus(),
		"Finishing a replay resumes both the previous scroll and replay focus.")
	scroll.scroll_vertical = reading_position
	ending.replay_button.pressed.emit()
	ending.skip_button.pressed.emit()
	await _settle_layout()
	_expect(ending.report.visible and not ending.film.visible and not ending.motion.is_valid(),
		"Skipping a replay opens the report immediately and stops the film.")
	_expect(scroll.scroll_vertical == reading_position and ending.replay_button.has_focus(),
		"Skipping a replay resumes both the previous scroll and replay focus.")
	print("ENDING_REPLAY route=", traditional, " before=", reading_position, " after=", scroll.scroll_vertical,
		" focus=", ending.replay_button.has_focus())

func _settle_layout() -> void:
	for frame in 5:
		await process_frame

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
