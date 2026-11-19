extends CanvasLayer

signal finished

const COVER_COLOR := Color("#151e1a")
const CLOSE_SECONDS := 0.16
const OPEN_SECONDS := 0.22
const ARRIVAL_PLATE := preload("res://scenes/TravelArrival.tscn")
const ARRIVAL_HOLD := 0.95
const SESSION_PLATE := preload("res://scenes/SessionLoading.tscn")
const RESOURCE_BATCH_USEC := 5000
const RESOURCE_BATCH_LIMIT_USEC := 120000

var active := false
var cover: ColorRect
var arrival_plate: CenterContainer
var arrival_name: Label
var _arrival_tween: Tween
var _preloads: Dictionary[String, PackedScene] = {}
var _session_plate: CenterContainer
var _session_caption: Label
var _session_batch_usec := RESOURCE_BATCH_USEC

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
	arrival_plate = ARRIVAL_PLATE.instantiate()
	add_child(arrival_plate)
	arrival_name = arrival_plate.get_node("%Place")
	arrival_plate.get_node("%MapIcon").texture = HUDIcons.icon(HUDIcons.Symbol.MAP)
	for visibility in [GameEvents.modal_visibility_changed, GameEvents.settings_visibility_changed, GameEvents.management_visibility_changed]:
		visibility.connect(_dismiss_arrival_for_panel)
	GameEvents.campaign_ended.connect(_clear_arrival.unbind(1))
	get_tree().scene_changed.connect(_clear_arrival)
	_session_plate = SESSION_PLATE.instantiate()
	add_child(_session_plate)
	_session_caption = _session_plate.get_node("%Caption")
	InterfaceFont.scale_reading_text(_session_caption)
	set_process_input(false)

func prepare(path: String) -> void:
	if path.is_empty() or _preloads.has(path) or not ResourceLoader.exists(path, "PackedScene"):
		return
	var packed := ResourceLoader.load(path, "PackedScene") as PackedScene
	if packed:
		_preloads[path] = packed

func prepare_session(path: String, caption: String) -> bool:
	var tree := get_tree()
	var origin := tree.current_scene
	if active or origin == null:
		return false
	var packed: PackedScene = _preloads.get(path)
	if packed and _unprepared_neighbors(packed).is_empty():
		return true
	active = true
	set_process_input(true)
	_clear_arrival()
	cover.color.a = 1.0
	cover.show()
	_session_caption.text = caption
	_session_plate.show()
	_session_batch_usec = RESOURCE_BATCH_USEC
	# Draw the loading card before the first synchronous read.
	await tree.process_frame
	await tree.process_frame
	packed = await _prepare_in_batches(path)
	if packed:
		for neighbor in _unprepared_neighbors(packed):
			await _prepare_in_batches(neighbor)
	_session_plate.hide()
	_finish()
	return is_instance_valid(origin) and tree.current_scene == origin

func _prepare_in_batches(path: String) -> PackedScene:
	if _preloads.has(path):
		return _preloads[path]
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return null
	# Retain each dependency until the packed map owns it.
	var held: Array[Resource] = []
	var started := Time.get_ticks_usec()
	for dependency in ResourceLoader.get_dependencies(path):
		var target := dependency.get_slice("::", 0)
		if dependency.contains("::") and not ResourceLoader.exists(target):
			target = dependency.get_slice("::", 2)
		if ResourceLoader.has_cached(target):
			continue
		var resource := ResourceLoader.load(target)
		if resource:
			held.append(resource)
		if Time.get_ticks_usec() - started >= _session_batch_usec:
			var waiting := Time.get_ticks_usec()
			await get_tree().process_frame
			started = Time.get_ticks_usec()
			# Slow frame delivery can cost more than a small batch. Amortize that wait for this entry.
			_session_batch_usec = clampi(maxi(_session_batch_usec, (started - waiting) * 3),
				RESOURCE_BATCH_USEC, RESOURCE_BATCH_LIMIT_USEC)
	prepare(path)
	await get_tree().process_frame
	return _preloads.get(path)

func _unprepared_neighbors(packed: PackedScene) -> PackedStringArray:
	var neighbors := PackedStringArray()
	var scene_state := packed.get_state()
	var maps := Global.SAVE_SCENES.values()
	for node in scene_state.get_node_count():
		for property in scene_state.get_node_property_count(node):
			if scene_state.get_node_property_name(node, property) != &"destination":
				continue
			var destination: Variant = scene_state.get_node_property_value(node, property)
			if destination is String and destination in maps \
					and not _preloads.has(destination) and not neighbors.has(destination):
				neighbors.append(destination)
	return neighbors

func cross(path: String, arrival_path: NodePath, player_path: NodePath) -> void:
	relocate(_open_destination.bind(path, arrival_path, player_path), path)

func relocate(change_location: Callable, arrival_scene := "") -> void:
	var tree := get_tree()
	if active or tree.paused or tree.current_scene == null or Global.outcome != Global.Outcome.RUNNING:
		return
	active = true
	set_process_input(true)
	_cross.call_deferred(tree.current_scene, change_location, arrival_scene)

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func _cross(origin: Node, change_location: Callable, arrival_scene: String) -> void:
	_clear_arrival()
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
	if crossed and not get_tree().paused and Global.outcome == Global.Outcome.RUNNING:
		_show_arrival(arrival_scene)
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
	if marker == null or player == null:
		destination.free()
		return false
	GameEvents.map_departing.emit()
	if tree.change_scene_to_node(destination) != OK:
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

func _show_arrival(path: String) -> void:
	var location: Variant = Global.SAVE_SCENES.find_key(path)
	var place: String = "封地" if location == "estate" else Global.SAVE_LOCATION_NAMES.get(location, "")
	if place.is_empty():
		return
	arrival_name.text = place
	arrival_plate.modulate.a = 0.0
	arrival_plate.show()
	_arrival_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_arrival_tween.tween_property(arrival_plate, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE)
	_arrival_tween.tween_interval(ARRIVAL_HOLD)
	_arrival_tween.tween_property(arrival_plate, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE)
	_arrival_tween.tween_callback(arrival_plate.hide)

func _dismiss_arrival_for_panel(opened: bool) -> void:
	if opened:
		_clear_arrival()

func _clear_arrival() -> void:
	if _arrival_tween:
		_arrival_tween.kill()
		_arrival_tween = null
	arrival_plate.hide()

func _finish() -> void:
	cover.hide()
	cover.color.a = 0.0
	set_process_input(false)
	active = false
	finished.emit()
