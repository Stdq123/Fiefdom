extends Sprite2D
class_name NeighborMotion

signal foot_planted(at: Vector2, movement: Vector2)

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
# Centers under the planted soles of the shared worker and street poses.
const PLANTED_SOLES := [
	[Vector2(-4.0, 14.5), Vector2(4.0, 14.5)],
	[Vector2(3.5, 14.5), Vector2(-3.5, 14.5)],
	[Vector2(3.75, 12.5), Vector2(3.0, 13.0)],
]

var directional := false
var facing := Facing.FRONT
var walk_distance := 0.0
var walking := false
var idle_time := 0.0
var step_length := STEP_LENGTH
var hands_busy := false:
	set(value):
		hands_busy = value
		if value and _standing_pose:
			_standing_pose.clear()
var _work_column := -1
var _seated_art: SeatedPose
var _standing_pose: StandingPose

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
	if _seated_art:
		_seated_art.restore_standing()
	if _standing_pose:
		_standing_pose.clear()
	if columns == CharacterArt.WORKER_COLUMNS and sheet:
		if not _standing_pose:
			var wait := float(get_instance_id() % 7) * 0.13
			_standing_pose = StandingPose.new(self, wait)
	elif _standing_pose:
		material = null
		_standing_pose = null
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
	if _seated_art:
		_seated_art.restore_standing()
	if _standing_pose:
		_standing_pose.clear()
	var previous := frame_coords.x if walking else 0
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
		# A distant clock or route update can put the actor at a new stop in one tick.
		if phase != previous and phase in [1, 2] and travelled <= step_length:
			var sole: Vector2 = PLANTED_SOLES[facing][phase - 1]
			if flip_h:
				sole.x = -sole.x
			foot_planted.emit(to_global(sole), movement)
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
	if _seated_art:
		_seated_art.restore_standing()
	_stop_walking()
	if hframes == CharacterArt.WORKER_COLUMNS and work_pose >= 0:
		_work_column = (CharacterArt.ERRAND_COLUMN if errand else CharacterArt.WORK_COLUMN) + work_pose
	offset = Vector2.ZERO if _work_column >= 0 else lean
	if _standing_pose and (_work_column >= 0 or not offset.is_zero_approx()):
		_standing_pose.clear()
	if directional:
		_show_idle()

func sit(fabric: Color) -> void:
	if not directional:
		stand(Vector2(0, 2))
		return
	_stop_walking()
	if _standing_pose:
		_standing_pose.clear()
	offset = Vector2.ZERO
	_show_idle()
	if not _seated_art:
		_seated_art = SeatedPose.new(self)
		add_child(_seated_art, false, Node.INTERNAL_MODE_BACK)
	_seated_art.present(SeatedPose.Surface.MAT, fabric)

func _stop_walking() -> void:
	walking = false
	walk_distance = 0.0
	_work_column = -1

func _process(delta: float) -> void:
	if not walking:
		idle_time = fposmod(idle_time + delta, BLINK_PERIOD)
		_show_idle()
		if (_standing_pose and not hands_busy and _work_column < 0 and offset.is_zero_approx()
				and (not _seated_art or _seated_art.surface == SeatedPose.Surface.STANDING)):
			_standing_pose.advance(delta)

func _show_idle() -> void:
	var blink := facing != Facing.BACK and idle_time >= BLINK_PERIOD - BLINK_TIME
	var column := _work_column if _work_column >= 0 else (3 if blink else 0)
	var pose := Vector2i(column, facing)
	if frame_coords != pose:
		frame_coords = pose
