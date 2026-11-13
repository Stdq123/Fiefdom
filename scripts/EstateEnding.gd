extends Control

signal film_finished()
signal close_requested()

enum Shot { FIELD, CEREMONY, RECORD }

const ENVOY := preload("res://assets/characters/envoy-motion.svg")
const PROPS := preload("res://assets/world/ending-ceremonies.svg")
const RECORD_STAND := preload("res://scripts/EstateRecordStand.gd")
const TRADITIONAL_SCORE := preload("res://assets/audio/music/ending-traditional.ogg")
const REFORMED_SCORE := preload("res://assets/audio/music/ending-reformed.ogg")
const UNITS := {"新增公田纳贡": "份", "进献丝绸": "匹", "新增计税收成": "份",
	"售出丝绸": "匹", "现有铜钱": "枚", "击退敌袭": "次", "国库": "份", "私田收成": "份", "铜钱": "枚"}
const FIELD_HOLD := 2.15
const PAN_SECONDS := 1.35
const WALK_SECONDS := 1.65
const CEREMONY_HOLD := 2.30

@onready var film: Control = %Film
@onready var place: Label = %ShotPlace
@onready var caption: Label = %ShotCaption
@onready var skip_button: Button = %SkipEnding
@onready var report: Control = %Report
@onready var shade: ColorRect = %ReportShade
@onready var date: Label = %EndingDate
@onready var heading: Label = %EndingHeading
@onready var epilogue: Label = %Epilogue
@onready var results: VBoxContainer = %Results
@onready var memories: VBoxContainer = %Memories
@onready var status: Label = %EndingStatus
@onready var continue_button: Button = %ContinueEstate
@onready var save_button: Button = %SaveEnding
@onready var restore_button: Button = %RestoreCampaign
@onready var title_button: Button = %ReturnToTitle
@onready var replay_button: Button = %ReplayEnding
@onready var score: AudioStreamPlayer = $Score

var estate: Node2D
var traditional := false
var stage: Node2D
var camera: Camera2D
var envoy: Node2D
var walk_sprite: NeighborMotion
var motion: Tween
var field_focus: Vector2
var ceremony_focus: Vector2
var walk_start: Vector2
var walk_end: Vector2
var presenter: Sprite2D
var accounts: Array = []
var has_route_totals := false
var archive_open := false
var shot := Shot.RECORD

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

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (archive_open or shot != Shot.RECORD):
		get_viewport().set_input_as_handled()
		if archive_open:
			close_requested.emit()
		else:
			_show_record()

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
		field_focus = estate.tile_map.to_global(estate.tile_map.map_to_local(field["center_pos"])) + Vector2(-4, -12)
	else:
		field_focus = estate.player.global_position
	var stage_at := RECORD_STAND.TRIBUTE_POINT if traditional else RECORD_STAND.TAX_POINT
	ceremony_focus = estate.to_global(stage_at + Vector2(0, -17))
	walk_start = Vector2(78, -6) if traditional else Vector2(-78, 9)
	walk_end = Vector2(24, 0) if traditional else Vector2(-29, 0)

	stage = Node2D.new()
	stage.name = "EndingCeremony"
	stage.y_sort_enabled = true
	stage.process_mode = Node.PROCESS_MODE_ALWAYS
	stage.position = stage_at
	estate.get_node("Scenery").add_child(stage)
	var artwork := Sprite2D.new()
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var props := AtlasTexture.new()
	props.atlas = PROPS
	props.region = Rect2(0 if traditional else 64, 0, 64, 44)
	props.filter_clip = true
	artwork.texture = props
	artwork.position = Vector2(12 if traditional else -1, -18)
	stage.add_child(artwork)
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
	walk_sprite.position.y = -10.0
	envoy.add_child(walk_sprite)
	walk_sprite.set_motion_sheet(ENVOY)

	camera = Camera2D.new()
	camera.name = "EndingCamera"
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	estate.add_child(camera)
	camera.make_current()
	score.stream = TRADITIONAL_SCORE if traditional else REFORMED_SCORE

func _play(from_handoff := false) -> void:
	if motion and motion.is_running():
		motion.kill()
	report.hide()
	shade.hide()
	film.show()
	envoy.position = walk_start
	walk_sprite.stand()
	walk_sprite.face(walk_end - walk_start)
	if from_handoff:
		_show_ceremony()
		camera.global_position = ceremony_focus
		camera.zoom = Vector2.ONE * 3.05
	else:
		_show_fields()
		camera.global_position = field_focus
		camera.zoom = Vector2.ONE * 2.65
	camera.force_update_scroll()
	if DisplayServer.get_name() != "headless":
		score.play()
	skip_button.grab_focus()
	motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if not from_handoff:
		motion.tween_property(camera, "global_position", field_focus + Vector2(12, -3), FIELD_HOLD)
		motion.tween_property(camera, "global_position", ceremony_focus, PAN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		motion.parallel().tween_property(camera, "zoom", Vector2.ONE * 3.05, PAN_SECONDS).set_trans(Tween.TRANS_SINE)
		motion.tween_callback(_show_ceremony)
	motion.tween_method(_walk_to_table, 0.0, 1.0, WALK_SECONDS)
	motion.tween_callback(_finish_handoff)
	motion.tween_interval(CEREMONY_HOLD)
	if from_handoff:
		motion.tween_callback(_show_fields)
		motion.tween_interval(FIELD_HOLD)
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

func _finish_handoff() -> void:
	walk_sprite.stand()
	walk_sprite.face(presenter.position - envoy.position)
	AudioManager.play_event_sound("present_ledger")
	caption.text = ("召简接过贡簿，准封地照旧耕种，续行旧礼。" if traditional else
		"召简收下新册。往后各户照册纳税，市上按实成交。")

func _show_record() -> void:
	if motion and motion.is_running():
		motion.kill()
	score.stop()
	if camera:
		camera.global_position = ceremony_focus
		camera.zoom = Vector2.ONE * 2.5
		camera.force_update_scroll()
		envoy.position = walk_end
		walk_sprite.stand()
		walk_sprite.face(walk_end - walk_start)
	shot = Shot.RECORD
	film.hide()
	shade.show()
	report.show()
	var primary := title_button if archive_open else continue_button
	primary.grab_focus()
	film_finished.emit()

func _populate_record() -> void:
	var record := Global.ending_record
	traditional = record["outcome"] == Global.Outcome.TRADITIONAL
	accounts = record["accounts"]
	has_route_totals = accounts.front().has("target")
	heading.text = "守礼安邦" if traditional else "税亩富民"
	var accent := Color("#edca83") if traditional else Color("#efb889")
	heading.add_theme_color_override("font_color", accent)
	date.text = record["date"]
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

func _add_result(label: String, count: String, accent: Color) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 17)
	row.add_child(name_label)
	var value := Label.new()
	value.text = count
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", accent)
	row.add_child(value)
	results.add_child(row)
