extends Control

signal film_finished()
signal close_requested()
signal restore_requested()

enum Shot { FIELD, CEREMONY, FAREWELL, RECORD }

const ENVOY_HAND := "res://assets/characters/envoy-handoff.png"
const LEDGER_DESK := preload("res://scripts/RouteLedgerDesk.gd")
const COUNCIL_IMPLEMENTS := preload("res://scripts/CouncilImplements.gd")
const RECORD_STAND := preload("res://scripts/EstateRecordStand.gd")
const HUD_THEME := preload("res://resources/estate_hud_theme.tres")
const TRADITIONAL_SCORE := preload("res://assets/audio/music/ending-traditional.ogg")
const REFORMED_SCORE := preload("res://assets/audio/music/ending-reformed.ogg")
const UNITS := {"新增公田纳贡": "份", "进献丝绸": "匹", "新增计税收成": "份",
	"售出丝绸": "匹", "现有铜钱": "枚", "击退敌袭": "次", "国库": "份", "私田收成": "份", "铜钱": "枚"}
const FIELD_HOLD := 2.15
const PAN_SECONDS := 1.35
const WALK_SECONDS := 1.65
const RECEIPT_SECONDS := 0.56
const ENVOY_SLEEVE := Rect2(0, 0, 7, 5)
const ENVOY_PALM := Rect2(8, 0, 5, 5)
const CEREMONY_HOLD := 2.30
const FAREWELL_WALK := 1.15
const FAREWELL_HOLD := 4.25
const SCORE_FADE := 0.8
const SCORE_DB := -6.0
const REPORT_MARGIN := 16.0

@onready var film: Control = %Film
@onready var place: Label = %ShotPlace
@onready var caption: Label = %ShotCaption
@onready var skip_button: Button = %SkipEnding
@onready var report: Control = %Report
@onready var report_panel: PanelContainer = $Report/Panel
@onready var report_stack: VBoxContainer = $Report/Panel/Stack
@onready var report_header: VBoxContainer = %HeadingStack
@onready var report_scroll: ScrollContainer = %Read
@onready var report_body: VBoxContainer = %Body
@onready var report_footer: VBoxContainer = %Footer
@onready var shade: ColorRect = %ReportShade
@onready var estate_name: Label = %EndingEstate
@onready var date: Label = %EndingDate
@onready var heading: Label = %EndingHeading
@onready var volume_icon: TextureRect = %EndingVolume
@onready var epilogue: Label = %Epilogue
@onready var results: VBoxContainer = %Results
@onready var account_title: Label = %AccountTitle
@onready var account_key: Label = %AccountKey
@onready var memories: VBoxContainer = %Memories
@onready var farewell_row: PanelContainer = %Farewell
@onready var farewell_portrait: TextureRect = %FarewellPortrait
@onready var farewell_speaker: Label = %FarewellSpeaker
@onready var farewell_line: Label = %FarewellLine
@onready var status: Label = %EndingStatus
@onready var continue_button: Button = %ContinueEstate
@onready var save_button: Button = %SaveEnding
@onready var restore_button: Button = %RestoreCampaign
@onready var title_button: Button = %ReturnToTitle
@onready var replay_button: Button = %ReplayEnding
@onready var restore_confirmation: Control = %RestoreConfirmation
@onready var restore_detail: Label = %RestoreDetail
@onready var stay_button: Button = %StayAtEnding
@onready var load_before_ending: Button = %LoadBeforeEnding
@onready var score: AudioStreamPlayer = $Score

var estate: Node2D
var traditional := false
var stage: Node2D
var desk: LEDGER_DESK
var camera: Camera2D
var envoy: Node2D
var walk_sprite: NeighborMotion
var sleeve: Sprite2D
var palm: Sprite2D
var motion: Tween
var score_fade: Tween
var field_focus: Vector2
var ceremony_focus: Vector2
var walk_start: Vector2
var walk_end: Vector2
var presenter: Sprite2D
var guest: Node2D
var guest_sprite: NeighborMotion
var guest_start: Vector2
var guest_end: Vector2
var farewell: Dictionary = {}
var accounts: Array = []
var has_route_totals := false
var archive_open := false
var ending_saved := false
var shot := Shot.RECORD

func _ready() -> void:
	for label: Label in [caption, estate_name, date, epilogue, farewell_line, restore_detail]:
		InterfaceFont.scale_reading_text(label)
	var bar := report_scroll.get_v_scroll_bar()
	bar.theme = HUD_THEME
	bar.theme_type_variation = &"HudJournalBar"
	bar.focus_mode = Control.FOCUS_ALL
	for section: Control in [report_header, report_body, report_footer]:
		section.minimum_size_changed.connect(_fit_report_body, CONNECT_DEFERRED)
	resized.connect(_fit_report_body, CONNECT_DEFERRED)
	for button in [skip_button, continue_button, replay_button, restore_button, save_button, title_button]:
		button.theme = HUD_THEME
		button.theme_type_variation = &"HudButton"
	continue_button.theme_type_variation = &"HudPrimary"
	restore_button.pressed.connect(_confirm_restore)
	stay_button.pressed.connect(_close_restore)
	load_before_ending.pressed.connect(func():
		_close_restore()
		restore_requested.emit()
	)

func present(estate_world: Node2D, already_finished: bool) -> void:
	estate = estate_world
	_populate_record()
	$Film/Tone.color = Color("#b9825c24") if traditional else Color("#bf7d6a20")
	skip_button.pressed.connect(_show_record)
	replay_button.pressed.connect(_play)
	_build_stage()
	AudioManager.duck_music_for(self, 0.12)
	if already_finished:
		_show_record()
	else:
		_play(true)

func open_archive() -> void:
	archive_open = true
	_populate_record()
	for button in [continue_button, replay_button, save_button, restore_button]:
		button.hide()
	status.hide()
	title_button.text = "返回封地  Esc"
	title_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	title_button.custom_minimum_size.x = 158.0
	title_button.get_parent().alignment = BoxContainer.ALIGNMENT_END
	title_button.pressed.connect(func(): close_requested.emit())
	_show_record()

func refresh_restore() -> void:
	var checkpoint := Global.latest_saved_game(true)
	restore_button.disabled = checkpoint.is_empty()
	restore_button.tooltip_text = "本局没有可读取的通关前存档。" if checkpoint.is_empty() else Global.saved_game_caption(checkpoint)

func _confirm_restore() -> void:
	var checkpoint := Global.latest_saved_game(true)
	if checkpoint.is_empty():
		refresh_restore()
		status.text = "本局没有可读取的通关前存档。"
		return
	var consequence := ("已保存的结局可从标题的「选择存档」打开。" if ending_saved else
		"可先留在结算，点「保存结局」保留这次记录。")
	restore_detail.text = "%s\n\n读取后会回到呈交账册前。\n%s" % [
		Global.saved_game_caption(checkpoint), consequence]
	report.hide()
	restore_confirmation.show()
	_focus_action(stay_button)

func _close_restore() -> void:
	restore_confirmation.hide()
	report.show()
	_focus_action(restore_button)

func _focus_action(button: Button) -> void:
	button.grab_focus()
	if GamepadInput.active:
		await get_tree().process_frame
		if button.has_focus():
			GamepadInput.snap_pointer_to_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (restore_confirmation.visible or archive_open or shot != Shot.RECORD):
		get_viewport().set_input_as_handled()
		if restore_confirmation.visible:
			_close_restore()
		elif archive_open:
			close_requested.emit()
		else:
			_show_record()
	elif report.visible and event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		var bar := report_scroll.get_v_scroll_bar()
		if bar.visible:
			var step := 1 if event.keycode == KEY_PAGEDOWN else -1
			report_scroll.scroll_vertical += step * maxi(1, roundi(bar.page) - 24)
			get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if is_instance_valid(stage):
		stage.queue_free()
	if is_instance_valid(camera):
		camera.queue_free()

func _build_stage() -> void:
	estate.get_parent().get_node("UI").hide()
	for label in estate.find_children("*", "Label", true, false):
		label.hide()
	estate.tile_map.get_node("FieldCursor").hide()
	for actor in get_tree().get_nodes_in_group("interactable"):
		var hint := actor.get_node_or_null("InteractionHint") as CanvasItem
		if hint:
			hint.hide()

	var fields := Global.well_fields.filter(func(field: Dictionary) -> bool: return field["is_unlocked"])
	if not fields.is_empty():
		var field: Dictionary = fields.front() if traditional else fields.back()
		for candidate: Dictionary in fields:
			if candidate.field_id == farewell.get("field", -1):
				field = candidate
				break
		field_focus = estate.tile_map.to_global(estate.tile_map.map_to_local(field["center_pos"])) + Vector2(-4, -12)
	else:
		field_focus = estate.player.global_position
	var stage_at := RECORD_STAND.TRIBUTE_POINT if traditional else RECORD_STAND.TAX_POINT
	ceremony_focus = estate.to_global(stage_at + Vector2(0, -17))
	walk_start = Vector2(78, -6) if traditional else Vector2(-78, 9)
	walk_end = Vector2(21, 0) if traditional else Vector2(-23, 0)

	stage = Node2D.new()
	stage.name = "EndingCeremony"
	stage.y_sort_enabled = true
	stage.process_mode = Node.PROCESS_MODE_ALWAYS
	stage.position = stage_at
	estate.get_node("Scenery").add_child(stage)
	desk = LEDGER_DESK.new()
	stage.add_child(desk)
	desk.arrange(traditional)
	var player_sprite: Sprite2D = estate.player.get_node("Sprite2D")
	presenter = player_sprite.duplicate(0) as Sprite2D
	presenter.offset = player_sprite.position
	presenter.position = Vector2(-9, 18) if traditional else Vector2(5, 18)
	presenter.frame_coords = Vector2i(0, Player.Facing.BACK)
	presenter.flip_h = false
	stage.add_child(presenter)
	estate.player.hide()
	envoy = Node2D.new()
	envoy.name = "ZhaoJian"
	stage.add_child(envoy)
	walk_sprite = NeighborMotion.new()
	walk_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	walk_sprite.position.y = -13.0
	envoy.add_child(walk_sprite)
	walk_sprite.set_motion_sheet(load(CharacterArt.ENVOY_MOTION), CharacterArt.STREET_COLUMNS, "召简")
	sleeve = _envoy_detail(ENVOY_SLEEVE)
	sleeve.centered = false
	sleeve.offset.y = -2
	palm = _envoy_detail(ENVOY_PALM)
	palm.flip_h = traditional
	if not farewell.is_empty():
		_build_farewell_guest()

	camera = Camera2D.new()
	camera.name = "EndingCamera"
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	estate.add_child(camera)
	camera.make_current()
	score.stream = TRADITIONAL_SCORE if traditional else REFORMED_SCORE

func _envoy_detail(region: Rect2) -> Sprite2D:
	var detail := Sprite2D.new()
	detail.texture = load(ENVOY_HAND)
	detail.region_enabled = true
	detail.region_rect = region
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail.hide()
	envoy.add_child(detail)
	return detail

func _build_farewell_guest() -> void:
	guest_start = Vector2(-78, 22) if traditional else Vector2(84, 28)
	guest_end = Vector2(-44, 8) if traditional else Vector2(43, 13)
	guest = Node2D.new()
	guest.name = "FarewellGuest"
	guest.hide()
	stage.add_child(guest)
	guest_sprite = NeighborMotion.new()
	guest_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	guest_sprite.position.y = -10.0
	guest.add_child(guest_sprite)
	guest_sprite.set_art(farewell.speaker, null)
	var resident: Node2D = estate.neighbor_actor(farewell.speaker)
	if is_instance_valid(resident):
		resident.hide()

func _play(from_handoff := false) -> void:
	if motion:
		motion.kill()
	if score_fade:
		score_fade.kill()
	report.hide()
	shade.hide()
	film.show()
	if desk.volume.get_parent() != desk:
		desk.volume.reparent(desk, false)
	desk.volume.position = desk.volume_home()
	sleeve.hide()
	palm.hide()
	envoy.position = walk_start
	walk_sprite.stand()
	walk_sprite.face(walk_end - walk_start)
	presenter.frame_coords = Vector2i(0, Player.Facing.BACK)
	presenter.flip_h = false
	if guest:
		guest.hide()
		guest.position = guest_start
		guest_sprite.stand()
		guest_sprite.face(guest_end - guest_start)
	if from_handoff:
		_show_ceremony()
		camera.global_position = ceremony_focus
		camera.zoom = Vector2.ONE * 3.05
	else:
		_show_fields()
		camera.global_position = field_focus
		camera.zoom = Vector2.ONE * 2.65
	camera.force_update_scroll()
	score.volume_db = SCORE_DB
	if DisplayServer.get_name() != "headless":
		score.play()
	_focus_action(skip_button)
	motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if not from_handoff:
		motion.tween_property(camera, "global_position", field_focus + Vector2(12, -3), FIELD_HOLD)
		motion.tween_property(camera, "global_position", ceremony_focus, PAN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		motion.parallel().tween_property(camera, "zoom", Vector2.ONE * 3.05, PAN_SECONDS).set_trans(Tween.TRANS_SINE)
		motion.tween_callback(_show_ceremony)
	motion.tween_method(_walk_to_table, 0.0, 1.0, WALK_SECONDS)
	motion.tween_method(_receive_volume, 0.0, 1.0, RECEIPT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_callback(_finish_handoff)
	if guest:
		motion.tween_interval(CEREMONY_HOLD - RECEIPT_SECONDS - FAREWELL_WALK)
		motion.tween_callback(guest.show)
		motion.tween_method(_walk_guest, 0.0, 1.0, FAREWELL_WALK)
		motion.tween_callback(_show_farewell)
		motion.tween_interval(FAREWELL_HOLD)
	else:
		motion.tween_interval(CEREMONY_HOLD - RECEIPT_SECONDS)
	if from_handoff:
		motion.tween_callback(_show_fields)
		motion.tween_interval(FIELD_HOLD)
	var length := WALK_SECONDS + CEREMONY_HOLD + FIELD_HOLD
	if guest:
		length += FAREWELL_HOLD
	if not from_handoff:
		length += PAN_SECONDS
	if score.playing:
		var fade_at := minf(length, score.stream.get_length())
		score_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		score_fade.tween_property(score, "volume_db", -40.0, SCORE_FADE).set_delay(maxf(0.0, fade_at - SCORE_FADE))
	motion.tween_callback(_show_record)

func _show_fields() -> void:
	shot = Shot.FIELD
	place.text = "井田 · 谷入公仓" if traditional else "井田 · 按亩入册"
	if has_route_totals:
		caption.text = ("自定下守礼之议，公田新入国库 %d 份谷粟。" if traditional else
			"新法施行后，已有 %d 份收成记入税册。") % accounts[0]["value"]
	else:
		caption.text = "收下的公田谷粟，已送往堂前点验。" if traditional else "收过的各户田亩，已重新编入税册。"
	camera.global_position = field_focus
	camera.zoom = Vector2.ONE * 2.65
	camera.force_update_scroll()

func _show_ceremony() -> void:
	shot = Shot.CEREMONY
	place.text = "堂前 · 交谷帛" if traditional else "南路亭 · 交新税册"
	caption.text = ("使者召简来到堂前，点验公仓谷粟与送往王庭的丝帛。" if traditional else
		"使者召简来到南路亭，核对新税册和市上丝帛的成交。")

func _walk_to_table(progress: float) -> void:
	var next := walk_start.lerp(walk_end, progress)
	walk_sprite.walk(next - envoy.position)
	envoy.position = next

func _receive_volume(progress: float) -> void:
	if desk.volume.get_parent() != envoy:
		desk.volume.reparent(envoy, false)
		palm.move_to_front()
	var side := -1.0 if traditional else 1.0
	var grasp := smoothstep(0.0, 0.28, progress)
	var lift := smoothstep(0.2, 1.0, progress)
	var lean := Vector2(side * 3, -1) * (grasp - lift)
	walk_sprite.stand(lean)
	var hand := Vector2(side * 4, -7)
	var from_desk := desk.volume_home() - envoy.position
	desk.volume.position = Vector2(lerpf(from_desk.x, hand.x, lift * lift),
		lerpf(from_desk.y, hand.y, lift) - 2.5 * sin(PI * lift))
	# The hand reaches the near binding before the volume starts to rise.
	palm.position = Vector2(-side, -6).lerp(desk.volume.position + Vector2(-side * 3.5, 1.5), grasp)
	sleeve.position = Vector2(side * 3, -14) + lean
	var forearm := palm.position - sleeve.position
	sleeve.rotation = forearm.angle()
	sleeve.scale.x = forearm.length() / ENVOY_SLEEVE.size.x
	sleeve.flip_v = forearm.x < 0
	sleeve.visible = progress > 0
	palm.visible = sleeve.visible

func _finish_handoff() -> void:
	walk_sprite.stand()
	walk_sprite.face(presenter.position - envoy.position)
	AudioManager.play_event_sound("present_ledger")
	caption.text = ("召简接过贡簿，准封地照旧耕种，续行旧礼。" if traditional else
		"召简收下新册。往后各户照册纳税，市上按实成交。")

func _walk_guest(progress: float) -> void:
	var next := guest_start.lerp(guest_end, progress)
	guest_sprite.walk(next - guest.position)
	guest.position = next

func _show_farewell() -> void:
	shot = Shot.FAREWELL
	_face_farewell_guest()
	place.text = farewell.speaker
	caption.text = farewell.line

func _face_farewell_guest() -> void:
	guest_sprite.stand()
	guest_sprite.face(presenter.position - guest.position)
	presenter.frame_coords = Vector2i(0, Player.Facing.PROFILE)
	presenter.flip_h = guest.position.x < presenter.position.x

func _show_record() -> void:
	if motion:
		motion.kill()
	if score_fade:
		score_fade.kill()
	score.stop()
	if camera:
		camera.global_position = ceremony_focus
		camera.zoom = Vector2.ONE * 2.5
		camera.force_update_scroll()
		envoy.position = walk_end
		_receive_volume(1.0)
		walk_sprite.face(walk_end - walk_start)
	if guest:
		guest.show()
		guest.position = guest_end
		_face_farewell_guest()
	shot = Shot.RECORD
	film.hide()
	shade.show()
	report.show()
	report_scroll.set_deferred("scroll_vertical", 0)
	_fit_report_body.call_deferred()
	_focus_action(title_button if archive_open else continue_button)
	film_finished.emit()

func _fit_report_body() -> void:
	var fixed_height := report_panel.get_theme_stylebox("panel").get_minimum_size().y
	fixed_height += report_header.get_combined_minimum_size().y + report_footer.get_combined_minimum_size().y
	fixed_height += report_stack.get_theme_constant("separation") * 2.0
	var available := maxf(0.0, get_viewport_rect().size.y - REPORT_MARGIN * 2.0 - fixed_height)
	report_scroll.custom_minimum_size.y = minf(available, report_body.get_combined_minimum_size().y)

func _populate_record() -> void:
	var record := Global.ending_record
	traditional = record["outcome"] == Global.Outcome.TRADITIONAL
	accounts = record["accounts"]
	has_route_totals = accounts.front().has("target")
	account_title.text = "路线结算" if has_route_totals else "封地账目"
	account_key.visible = has_route_totals
	estate_name.text = Global.campaign_name
	heading.text = "守礼安邦" if traditional else "税亩富民"
	var choice := Global.TaxReformChoice.TRADITIONAL if traditional else Global.TaxReformChoice.REFORMED
	volume_icon.texture = COUNCIL_IMPLEMENTS.plate(choice)
	var accent := Color("#edca83") if traditional else Color("#b4d7c5")
	heading.add_theme_color_override("font_color", accent)
	date.text = record["date"]
	%Notes.visible = not record["memories"].is_empty()
	epilogue.text = ("公田与私田的旧约仍在。王庭收下贡簿，准这片封地继续行井田之制。" if traditional else
		"各户的田亩与收成有了新册。王庭准行新制，封地由此按亩纳税。")
	for account: Dictionary in accounts:
		var label: String = account["label"]
		var count := "%d / %d" % [account["value"], account["target"]] if has_route_totals else "%d" % account["value"]
		_add_result(label, "%s %s" % [count, UNITS[label]], accent)
	for memory: String in record["memories"]:
		var line := Label.new()
		line.text = memory
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 17)
		memories.add_child(line)
		InterfaceFont.scale_reading_text(line)
	var note: Variant = record.get("farewell")
	if (note is Dictionary and note.get("speaker") in VisitorData.NEIGHBORS
		and note.get("line") is String and not note.line.is_empty()):
		farewell = note
		farewell_portrait.texture = CharacterArt.dialogue_portrait(note.speaker, null, false)
		farewell_speaker.text = note.speaker
		farewell_line.text = note.line
		farewell_row.show()

func _add_result(label: String, count: String, accent: Color) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 17)
	row.add_child(name_label)
	var value := Label.new()
	value.text = count
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", accent)
	row.add_child(value)
	results.add_child(row)
	InterfaceFont.scale_reading_text(name_label)
	InterfaceFont.scale_reading_text(value)
