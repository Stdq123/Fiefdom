extends Sprite2D
class_name NeighborMotion

enum Facing { FRONT, BACK, PROFILE }

const WALK_FRAMES := [1, 0, 2, 0]
const STEP_LENGTH := 10.0
const BLINK_PERIOD := 4.4
const BLINK_TIME := 0.14

var directional := false
var facing := Facing.FRONT
var walk_distance := 0.0
var walking := false
var idle_time := 0.0
var _work_pose := -1

func set_art(speaker: String, fallback: Texture2D) -> void:
	var sheet := CharacterArt.neighbor_motion(speaker)
	idle_time = VisitorData.NEIGHBORS.find(speaker) * 0.37 if sheet else 0.0
	_set_frames(sheet if sheet else fallback, CharacterArt.WORKER_COLUMNS if sheet else 1)

func set_motion_sheet(sheet: Texture2D, columns := CharacterArt.MOTION_COLUMNS) -> void:
	_set_frames(sheet, columns)

func _set_frames(art: Texture2D, columns: int) -> void:
	directional = columns > 1
	texture = art
	hframes = columns
	vframes = CharacterArt.MOTION_ROWS if directional else 1
	_work_pose = -1
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
	_work_pose = -1
	walk_distance = fposmod(walk_distance + travelled, STEP_LENGTH * WALK_FRAMES.size())
	var phase: int = WALK_FRAMES[floori(walk_distance / STEP_LENGTH)]
	var step_height := -1.0 if phase > 0 else 0.0
	if directional:
		frame_coords = Vector2i(phase, facing)
		offset = Vector2.ZERO
	else:
		offset = Vector2(0.0, step_height)
	return step_height

func stand(lean := Vector2.ZERO, work_pose := -1) -> void:
	walking = false
	walk_distance = 0.0
	_work_pose = work_pose if hframes == CharacterArt.WORKER_COLUMNS else -1
	offset = Vector2.ZERO if _work_pose >= 0 else lean
	if directional:
		_show_idle()

func _process(delta: float) -> void:
	if not walking:
		idle_time = fposmod(idle_time + delta, BLINK_PERIOD)
		_show_idle()

func _show_idle() -> void:
	var blink := facing != Facing.BACK and idle_time >= BLINK_PERIOD - BLINK_TIME
	var column := CharacterArt.MOTION_COLUMNS + _work_pose if _work_pose >= 0 else (3 if blink else 0)
	var pose := Vector2i(column, facing)
	if frame_coords != pose:
		frame_coords = pose
