extends Sprite2D
class_name NeighborMotion

enum Facing { FRONT, BACK, PROFILE }

const STEP_LENGTH := 10.0
const NEIGHBOR_STEP_LENGTH := {
	"阿苓": 8.5,
	"阿绥": 8.2, "林蓼": 8.8, "禾伯": 7.2, "申禾": 10.5, "召简": 9.0,
	VisitorData.FIELD_KEEPER: 7.5, VisitorData.ROAD_KEEPER: 9.5, VisitorData.WATER_GUIDE: 9.0,
	VisitorData.SILK_MERCHANT: 8.7, VisitorData.RAVINE_GUIDE: 10.2,
	VisitorData.EAST_WATCHER: 11.0, VisitorData.MUSIC_HOST: 9.5,
}
const BLINK_PERIOD := 4.4
const BLINK_TIME := 0.14

var directional := false
var facing := Facing.FRONT
var walk_distance := 0.0
var walking := false
var idle_time := 0.0
var step_length := STEP_LENGTH
var _work_column := -1

static func walk_column(distance: float, passing_column := 0, stride := STEP_LENGTH) -> int:
	match floori(distance / stride) % 4:
		0: return 1
		1: return passing_column
		2: return 2
		_: return passing_column + 1 if passing_column > 0 else 0

func set_art(speaker: String, fallback: Texture2D) -> void:
	var sheet := CharacterArt.neighbor_motion(speaker)
	set_motion_sheet(sheet if sheet else fallback, CharacterArt.WORKER_COLUMNS if sheet else 1, speaker)

func set_festival_guest(index: int) -> void:
	set_motion_sheet(CharacterArt.festival_guest_motion(index), CharacterArt.STREET_COLUMNS, AutumnExhibit.GUESTS[index])

func set_motion_sheet(sheet: Texture2D, columns := CharacterArt.MOTION_COLUMNS, speaker := "") -> void:
	step_length = NEIGHBOR_STEP_LENGTH.get(speaker, STEP_LENGTH)
	idle_time = maxi(0, VisitorData.NEIGHBORS.find(speaker)) * 0.37
	walk_distance = 0.0
	walking = false
	directional = columns > 1
	texture = sheet
	hframes = columns
	vframes = CharacterArt.MOTION_ROWS if directional else 1
	_work_column = -1
	set_process(directional)
	face(Vector2.DOWN)

func face(toward: Vector2) -> void:
	if toward.is_zero_approx():
		return
	if absf(toward.x) > absf(toward.y):
		facing = Facing.PROFILE
		flip_h = toward.x < 0.0
	else:
		facing = Facing.BACK if toward.y < 0.0 else Facing.FRONT
		flip_h = false
	if directional and not walking:
		_show_idle()

func walk(movement: Vector2) -> float:
	var travelled := movement.length()
	if travelled < 0.04:
		stand()
		return 0.0
	face(movement)
	walking = true
	_work_column = -1
	walk_distance += travelled
	var passing_column := CharacterArt.PASS_COLUMN if hframes == CharacterArt.WORKER_COLUMNS else 0
	if hframes == CharacterArt.STREET_COLUMNS:
		passing_column = CharacterArt.MOTION_COLUMNS
	var phase := walk_column(walk_distance, passing_column, step_length)
	var step_height := -1.0 if phase == 1 or phase == 2 else 0.0
	if directional:
		frame_coords = Vector2i(phase, facing)
		offset = Vector2.ZERO
	else:
		offset = Vector2(0.0, step_height)
	return step_height

func carry_at(bundle: Node2D, hang: float) -> void:
	var bob := -0.75 if walking and frame_coords.x in [1, 2] else 0.0
	var side := -1.0 if flip_h else 1.0
	var across := 6.5 if facing == Facing.PROFILE else 8.0
	bundle.position = (position + Vector2(side * across, 5.0 + bob + hang)).snappedf(0.5)
	bundle.show_behind_parent = facing == Facing.BACK

func stand(lean := Vector2.ZERO, work_pose := -1, errand := false) -> void:
	walking = false
	walk_distance = 0.0
	_work_column = -1
	if hframes == CharacterArt.WORKER_COLUMNS and work_pose >= 0:
		_work_column = (CharacterArt.ERRAND_COLUMN if errand else CharacterArt.WORK_COLUMN) + work_pose
	offset = Vector2.ZERO if _work_column >= 0 else lean
	if directional:
		_show_idle()

func _process(delta: float) -> void:
	if not walking:
		idle_time = fposmod(idle_time + delta, BLINK_PERIOD)
		_show_idle()

func _show_idle() -> void:
	var blink := facing != Facing.BACK and idle_time >= BLINK_PERIOD - BLINK_TIME
	var column := _work_column if _work_column >= 0 else (3 if blink else 0)
	var pose := Vector2i(column, facing)
	if frame_coords != pose:
		frame_coords = pose
