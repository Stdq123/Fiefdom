extends SceneTree

const Campaign := preload("res://tests/CampaignReplay.gd")
const TITLE := "res://scenes/Title.tscn"

var failed := false
var state: Node
var world: Node
var ui: Node
var gathering: Node2D

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, detail: String) -> bool:
	if not condition:
		failed = true
		push_error(detail)
	return condition

func _estate() -> void:
	world = current_scene.get_node("World")
	ui = current_scene.get_node("UI")
	gathering = world.get_node("SpringGathering")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	await process_frame

func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame

func _night() -> void:
	var tomorrow: int = state.current_day + 1
	ui.sleep_button.pressed.emit()
	Campaign.confirm_optional_tribute_warning(ui)
	for frame in range(240):
		if state.current_day == tomorrow and ui.fader.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return
		await process_frame
	_expect(false, "A full night must advance the estate one day.")

func _talk_to_host() -> Control:
	var host := gathering.get_node("Guests/商音") as Node2D
	await Campaign.walk_to(self, world.player, host.global_position + Vector2(0, 8))
	await _key(KEY_E)
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not _expect(dialog != null and dialog.name_label.text == "商音", "E near the bell rack speaks to the music host."):
		return null
	return dialog

func _start_recital() -> Control:
	var dialog := await _talk_to_host()
	if dialog == null:
		return null
	var button := dialog.options_container.get_child(0) as Button
	_expect(button.text == "合奏迎客曲", "A first performance or retry is offered.")
	await _click(button)
	var practice := ui.get_node_or_null("Control/MusicPractice") as Control
	_expect(practice != null and paused, "The performance opens and pauses the estate.")
	return practice

func _book() -> Control:
	await Campaign.walk_to(self, world.player, gathering.global_position + Vector2(0, 5))
	await _key(KEY_E)
	var dialog := ui.get_node_or_null("Control/DialoguePanel") as Control
	_expect(dialog != null and dialog.name_label.text == "谷雨曲簿", "E at the physical scorebook opens its record.")
	return dialog

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run spring-gathering in an isolated Godot smoke profile.")
		quit(1)
		return
	state = root.get_node("Global")
	change_scene_to_file(TITLE)
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	_estate()
	_expect(not gathering.visible and not gathering.is_in_group("interactable"), "The event and empty book stay out of the way on the opening day.")
	while state.current_day < 5 and not failed:
		await _night()
	_expect(ui.hud.gathering_label.visible and "明日谷雨亭集" in ui.hud.gathering_label.text, "Clear Brightness forecasts the next day's gathering.")
	await _night()
	_expect(state.current_day == 6 and state.is_gathering_day() and gathering.guests.get_child_count() == 3,
		"Grain Rain opens the pavilion gathering with three guests.")
	_expect(world.current_visitor() != null and world.current_visitor().name == "弋戎" and world.active_visitors.size() == 1,
		"The normal visitor still attends their original post.")
	if failed:
		quit(1)
		return
	var practice := await _start_recital()
	if practice == null:
		quit(1)
		return
	while not practice.finished:
		await process_frame
	_expect(practice.hits == 0 and state.gathering_recitals.is_empty(), "A missed performance leaves the scorebook empty.")
	await _key(KEY_ESCAPE)
	practice = await _start_recital()
	if practice == null:
		quit(1)
		return
	practice.elapsed = practice.BEAT_SECONDS - practice.HIT_WINDOW - 0.01
	practice._process(0.30)
	await _key(KEY_SPACE)
	_expect(practice.hits == 1 and practice.scored_beats[0] == 0, "A long frame cannot skip the first visible strike window.")
	await _key(KEY_ESCAPE)
	_expect(not paused and state.gathering_recitals.is_empty(), "Leaving during a performance resumes the map without awarding a record.")
	practice = await _start_recital()
	if practice == null:
		quit(1)
		return
	for beat in range(1, 5):
		var hit_at: float = practice.BEAT_SECONDS * beat - practice.HIT_WINDOW * 0.7
		while practice.elapsed < hit_at and not practice.finished:
			await process_frame
		if beat == 2:
			await _click(practice.strike_button)
		else:
			await _key(KEY_SPACE)
		await _key(KEY_SPACE)
	while not practice.finished:
		await process_frame
	_expect(practice.hits == 4 and state.gathering_score() == 4 and state.player_stats.stats["MUSIC"]["xp"] == 30,
		"Keyboard and mouse strikes score once per beat and earn one performance reward.")
	_expect(state.practice_days.is_empty(), "The recital has its own limit apart from regular practice.")
	await _key(KEY_ESCAPE)
	var dialog := await _talk_to_host()
	_expect(dialog != null and dialog.options_container.get_child_count() == 1, "The host thanks the player and closes repeats for this gathering.")
	await _key(KEY_ESCAPE)
	if not _expect(state.save_game() == OK and state.load_game() == OK, "Save and reload a festival day."):
		quit(1)
		return
	await scene_changed
	_estate()
	_expect(state.gathering_score() == 4 and "已入簿" in ui.hud.gathering_label.text, "The score and calendar status survive reload.")
	await _night()
	_expect(gathering.guests.get_child_count() == 0 and gathering.visible and not gathering.stall.visible and not ui.hud.gathering_label.visible,
		"The guests and rack depart on the following day while the record remains.")
	dialog = await _book()
	_expect(dialog != null and "第 1 年 · 谷雨 · 迎客曲 4/4" in dialog.text_label.text, "The book shows the completed performance after the festival.")
	await _key(KEY_ESCAPE)
	# Skip to the eve of the third gathering. That day's normal guest is Tao Xin.
	state.current_day = 5 + 2 * state.SOLAR_TERMS.size() * state.balance.days_per_solar_term
	await _night()
	var regular: Variant = world.current_visitor()
	_expect(regular != null and regular.name == "陶辛" and gathering.has_node("Guests/阿绥")
		and not gathering.has_node("Guests/陶辛"), "A visitor with another appointment is replaced by a different gathering guest.")
	_expect(state.gathering_score() == 0 and state.gathering_recitals.size() == 1, "A later gathering accepts a new performance and preserves the previous year's record.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
