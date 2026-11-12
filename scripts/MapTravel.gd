extends CanvasLayer

signal finished

const COVER_COLOR := Color("#151e1a")
const CLOSE_SECONDS := 0.16
const OPEN_SECONDS := 0.22

var active := false
var cover: ColorRect
var _preloads: Dictionary[String, PackedScene] = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	cover = ColorRect.new()
	cover.name = "Cover"
	cover.color = Color(COVER_COLOR, 0.0)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.hide()
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process_input(false)

func prepare(path: String) -> void:
	if path.is_empty() or _preloads.has(path) or not ResourceLoader.exists(path, "PackedScene"):
		return
	var packed := ResourceLoader.load(path, "PackedScene") as PackedScene
	if packed:
		_preloads[path] = packed

func cross(path: String, arrival_path: NodePath, player_path: NodePath) -> void:
	relocate(_open_destination.bind(path, arrival_path, player_path))

func relocate(change_location: Callable) -> void:
	var tree := get_tree()
	if active or tree.paused or tree.current_scene == null or Global.outcome != Global.Outcome.RUNNING:
		return
	active = true
	set_process_input(true)
	_cross.call_deferred(tree.current_scene, change_location)

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func _cross(origin: Node, change_location: Callable) -> void:
	if not _can_depart(origin):
		_finish()
		return
	var original_mode := origin.process_mode
	# Suspend the departing map locally so the destination can manage its own modals.
	origin.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	cover.show()
	await _fade(1.0, CLOSE_SECONDS)
	var crossed := false
	if _can_depart(origin) and change_location.is_valid():
		crossed = await change_location.call()
	if is_instance_valid(origin) and get_tree().current_scene == origin:
		origin.process_mode = original_mode
		if not crossed and not get_tree().paused and Global.outcome == Global.Outcome.RUNNING:
			GameEvents.world_notice.emit("前方暂时无法通行")
	await _fade(0.0, OPEN_SECONDS)
	_finish()

func _can_depart(origin: Node) -> bool:
	return is_instance_valid(origin) and get_tree().current_scene == origin and not get_tree().paused \
		and Global.outcome == Global.Outcome.RUNNING

func _open_destination(path: String, arrival_path: NodePath, player_path: NodePath) -> bool:
	prepare(path)
	var packed: PackedScene = _preloads.get(path)
	if packed == null:
		return false
	var destination := packed.instantiate()
	if destination == null:
		return false
	var marker := destination.get_node_or_null(arrival_path) as Marker2D
	var player := destination.get_node_or_null(player_path) as Player
	var tree := get_tree()
	if marker == null or player == null or tree.change_scene_to_node(destination) != OK:
		destination.free()
		return false
	await tree.scene_changed
	if tree.current_scene != destination:
		return false
	player.arrive_at(marker)
	await tree.process_frame
	return true

func _fade(opacity: float, seconds: float) -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(cover, "color:a", opacity, seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished

func _finish() -> void:
	cover.hide()
	set_process_input(false)
	active = false
	finished.emit()
